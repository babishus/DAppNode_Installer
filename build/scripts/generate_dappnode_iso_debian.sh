#!/bin/sh
set -e

#echo "Downloading debian ISO image: debian-firmware-testing-amd64-netinst-2020-06-22.iso..."
#if [ ! -f /images/debian-firmware-testing-amd64-netinst-2020-06-22.iso ]; then
#    wget http://vdo.dappnode.io/debian-firmware-testing-amd64-netinst-2020-06-22.iso \
#        -O /images/debian-firmware-testing-amd64-netinst-2020-06-22.iso
#fi
#echo "Done!"

#ISO_NAME=firmware-testing-amd64-netinst.iso
#ISO_URL=https://cdimage.debian.org/cdimage/unofficial/non-free/cd-including-firmware/weekly-builds/amd64/iso-cd/

#ISO_NAME=firmware-bullseye-DI-alpha3-amd64-netinst.iso
#ISO_URL=https://cdimage.debian.org/cdimage/unofficial/non-free/cd-including-firmware/bullseye_di_alpha3+nonfree/amd64/iso-cd/

ISO_NAME=firmware-bullseye-DI-alpha3-amd64-netinst.iso
ISO_URL=https://cdimage.debian.org/cdimage/unofficial/non-free/cd-including-firmware/bullseye_di_alpha3+nonfree/amd64/iso-cd/

echo "Downloading debian ISO image: firmware-bullseye-DI-alpha2-amd64-netinst.iso..."
if [ ! -f /images/${ISO_NAME} ]; then
    wget ${ISO_URL}/${ISO_NAME} \
        -O /images/${ISO_NAME}
fi
echo "Done!"

echo "Clean old files..."
rm -rf dappnode-isoº
rm -rf DappNode-debian-*

echo "Extracting the iso..."
xorriso -osirrox on -indev /images/${ISO_NAME} \
    -extract / dappnode-iso

echo "Obtaining the isohdpfx.bin for hybrid ISO..."
dd if=/images/${ISO_NAME} bs=432 count=1 \
    of=dappnode-iso/isolinux/isohdpfx.bin

cd dappnode-iso

echo "Downloading third-party packages..."
sed '1,/^\#\!ISOBUILD/!d' ../dappnode/scripts/dappnode_install_pre.sh >/tmp/vars.sh
source /tmp/vars.sh
mkdir -p /images/bin/docker
cd /images/bin/docker
[ -f ${DOCKER_PKG} ] || wget ${DOCKER_URL}
[ -f ${DOCKER_CLI_PKG} ] || wget ${DOCKER_CLI_URL}
[ -f ${CONTAINERD_PKG} ] || wget ${CONTAINERD_URL}
[ -f docker-compose-Linux-x86_64 ] || wget ${DCMP_URL}
cd -

echo "Creating necessary directories and copying files..."
mkdir dappnode
cp -r ../dappnode/* dappnode/
cp -vr /images/bin dappnode/

echo "Customizing preseed..."
mkdir -p /tmp/makeinitrd
cd install.amd
cp initrd.gz /tmp/makeinitrd/
if [[ ${UNATTENDED} == "true" ]]; then
   cp ../../dappnode/scripts/preseed_unattended.cfg /tmp/makeinitrd/preseed.cfg
else
    cp ../../dappnode/scripts/preseed.cfg /tmp/makeinitrd/preseed.cfg
fi
cd /tmp/makeinitrd
gunzip initrd.gz
cpio -id -H newc <initrd
cat initrd | cpio -t >/tmp/list
echo "preseed.cfg" >>/tmp/list
rm initrd
cpio -o -H newc </tmp/list >initrd
gzip initrd
cd -
mv /tmp/makeinitrd/initrd.gz ./initrd.gz
cd ..

echo "Configuring the boot menu for DappNode..."
cp ../boot/grub.cfg boot/grub/grub.cfg
cp ../boot/theme_1 boot/grub/theme/1
cp ../boot/isolinux.cfg isolinux/isolinux.cfg
cp ../boot/menu.cfg isolinux/menu.cfg
cp ../boot/txt.cfg isolinux/txt.cfg
cp ../boot/splash.png isolinux/splash.png

echo "Fix md5 sum..."
md5sum $(find ! -name "md5sum.txt" ! -path "./isolinux/*" -type f) >md5sum.txt

echo "Generating new iso..."
xorriso -as mkisofs -isohybrid-mbr isolinux/isohdpfx.bin \
    -c isolinux/boot.cat -b isolinux/isolinux.bin -no-emul-boot -boot-load-size 4 \
    -boot-info-table -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot \
    -isohybrid-gpt-basdat -o /images/DAppNode-debian-bullseye-amd64.iso .
