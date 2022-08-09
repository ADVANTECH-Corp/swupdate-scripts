#!/usr/bin/bash

SOC_NAME=imx8mm

#############################################
# Used to generate base image.
#############################################
IMAGE_MBR="common/swu_dualslot_7.5G.pt"

IMAGES_HEADER="
${IMAGE_MBR}:0:33K
slota/imx-boot-imx8mmevk-sd.bin-flash_evk:33K:8M
"

IMAGES_SWUPDATE="
slota/Image:8M:38M
slota/imx8mm-evk.dtb:38M:42M
slota/swupdate-image-imx8mmevk.cpio.gz.u-boot:42M:100M
"

# SlotA boot partion files list, which will be copied into slotb boot partition.
SLOTA_BOOT_PT_FILES="
slota/imx8mm-evk.dtb
slota/Image
"
SLOTA_BOOT_PT="common/slota_boot_pt_120M.mirror:100M:220M"
SLOTA_ROOTFS="slota/imx-image-multimedia-imx8mmevk.ext4:220M:3220M"
SLOTA_IMAGES="
${SLOTA_BOOT_PT}
${SLOTA_ROOTFS}
"

# SlotB boot partion files list, which will be copied into slotb boot partition.
SLOTB_BOOT_PT_FILES="
slotb/imx8mm-evk.dtb
slotb/Image
"
SLOTB_BOOT_PT="common/slotb_boot_pt_120M.mirror:3220M:3340M"
SLOTB_ROOTFS="slotb/imx-image-multimedia-imx8mmevk.ext4:3340M:6340M"
SLOTB_IMAGES="
${SLOTB_BOOT_PT}
${SLOTB_ROOTFS}
"

#############################################
# Used to generate update image.
#############################################
UPDATE_BSP_VER="LF_v5.10.9_1.0.0"
UPDATE_CONTAINER_VER="1.0"
UPDATE_SLOT="b"
# Supported SSL modes are RSA-PKCS-1.5, RSA-PSS and DGST.
SSL_MODE=RSA-PKCS-1.5
UPDATE_BOOT_PT="./slotb_boot_pt_120M.mirror:0:120M"
UPDATE_ROOTFS="./imx-image-multimedia-imx8mmevk.ext4:0:3000M"
UPDATE_BOOT_PT_FILES="
./imx8mm-evk.dtb
./Image
"

UPDATE_IMAGES="
slotb_boot_pt_120M.mirror
imx-image-multimedia-imx8mmevk.ext4
imx-boot-imx8mmevk-sd.bin-flash_evk
emmc_bootpart.sh
"

