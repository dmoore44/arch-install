# confirm you can access the internet
if [[ ! $(curl -I http://www.google.com/ | head -n 1) =~ "200 OK" ]]; then
  echo "Your Internet seems broken. Press Ctrl-C to abort or enter to continue."
  read
fi

# make 2 partitions on the disk.
parted -s /dev/sda mktable msdos
parted -s /dev/sda mkpart primary 0% 100m
parted -s /dev/sda mkpart primary 100m 100%

# make filesystems
# /
mkfs.ext4 /dev/sda1
# /home
mkfs.btrfs /dev/sda2

# set up /mnt
mount /dev/sda1 /mnt
mkdir /mnt/home
mount /dev/sda2 /mnt/home

# install base packages (take a coffee break if you have slow internet)
pacstrap /mnt base 

# install gptfdisk and syslinux
arch-chroot /mnt pacman -S gptfdisk 
arch-chroot /mnt pacman -S syslinux

# generate fstab
genfstab -p /mnt >>/mnt/etc/fstab

# chroot
arch-chroot /mnt /bin/bash <<EOF

# set static IP
cp /etc/netctl/examples/ethernet-static /etc/netctl/net-config
cat > /etc/netctl/net-config << EOL
CONNECTION='ethernet'
DESCRIPTION='A basic static ethernet connection using iproute'
INTERFACE='enp0s3'
IP='static'
ADDR='143.231.189.185'
ROUTES=('143.231.189.0/24 via 143.231.189.1')
GATEWAY='143.231.189.1'
DNS=('143.231.249.194')
EOL

# set initial hostname
echo "blackarch" >/etc/hostname

# set initial timezone to America/New_York
ln -s /usr/share/zoneinfo/America/New_York /etc/localtime

# set initial locale
locale >/etc/locale.conf
echo "en_US.UTF-8 UTF-8" >>/etc/locale.gen
locale-gen

# no modifications to mkinitcpio.conf should be needed
mkinitcpio -p linux

# install syslinux bootloader
syslinux-install_update -i -a -m

# update syslinux config with correct root disk
sed 's/root=\S+/root=\/dev\/sda2/' < /boot/syslinux/syslinux.cfg > /boot/syslinux/syslinux.cfg.new
mv /boot/syslinux/syslinux.cfg.new /boot/syslinux/syslinux.cfg

# set root password to "root"
echo root:root | chpasswd

# end section sent to chroot
EOF

# unmount
umount -R /mnt

echo "Done! Unmount the CD image from the VM, then type 'reboot'."
