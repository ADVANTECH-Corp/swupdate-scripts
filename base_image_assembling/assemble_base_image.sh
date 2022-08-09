#!/usr/bin/bash

function generate_mbr_dualslot()
{
	local PT_DISKLABEL=$1
	local PT_FILESIZE=$2

	if [ -z "${PT_DISKLABEL}" ]; then
		echo "Error: please specify an disk label for MBR!"
		exit 1
	fi

	if [ -z "${PT_FILESIZE}" ]; then
        echo "Error: please specify a file size for MBR!"
        exit 1
	fi

	truncate -s ${PT_FILESIZE} ${PT_DISKLABEL}

	sudo parted -s ${PT_DISKLABEL} mklabel msdos
	sudo parted ${PT_DISKLABEL} unit MiB mkpart primary fat32 100 220
	sudo parted ${PT_DISKLABEL} unit MiB mkpart primary ext4 220 3220
	sudo parted ${PT_DISKLABEL} unit MiB mkpart primary fat32 3220 3340
	sudo parted ${PT_DISKLABEL} unit MiB mkpart primary ext4 3340 6340
	sudo parted ${PT_DISKLABEL} unit MiB print

	# MBR is 512 bytes
	truncate -s 512 ${PT_DISKLABEL}
}

function generate_padding_file()
{
	local pad_base=$1
	local pad_filename=$2
	local pad_size=$3
	local output_pad_file=$4

	echo "pad_base: $pad_base"
	echo "pad_filename: $pad_filename"
	echo "pad_size: $pad_size"
	echo "output_pad_file: $output_pad_file"

	local pad_base_num=$(numfmt --from=iec ${pad_base})
	local pad_size_num=$(numfmt --from=iec ${pad_size})

	
	local pad_file_size=$(wc -c ${pad_filename} | cut -d" " -f1)

	local pad_start=`expr ${pad_base_num} + ${pad_file_size}`

	if [[ ${pad_start} -gt ${pad_size_num} ]]; then
		echo "pad_start:${pad_start} (pad_base:${pad_base_num} + pad file size:${pad_file_size}) > pad end: ${pad_size_num}" 
		return -1
	fi

	if [[ ${pad_start} -eq ${pad_size_num} ]]; then
    	echo "no need padding."
    	return 0
	fi 

	padding_size=`expr ${pad_size_num} - ${pad_start}`

	echo "${padding_size} need to add to pad to ${pad_size_num}"

	cp $pad_filename $output_pad_file
	truncate -s +${padding_size} ${output_pad_file}
}

function copy_images_to_boot_pt()
{
	local boot_pt=$1
	# slot can be SLOTA or SLOTB
	local slot=$2

	echo "boot_pt: $boot_pt"
	echo "slot: $slot"

	slot_upper=$(echo $slot | tr a-z A-Z)
	eval slot_boot_pt_files="\$${slot_upper}_BOOT_PT_FILES"
	mkfs.vfat $boot_pt
	mdir -i $boot_pt
	for each_file in $slot_boot_pt_files; do
		if [ ! -e ./${each_file} ]; then
			echo "./${each_file} not existed!"
			exit 1
		fi
		img_name=$(basename ${each_file})
		#mdel -i $boot_pt ${img_name}
		mcopy -i $boot_pt ./${each_file} ::${img_name}
	done
	mdir -i $boot_pt
}

function calculate_pt_size()
{
	local pt_info=$1

	local pt_start=$(echo $pt_info | cut -d: -f2)
	local pt_end=$(echo $pt_info | cut -d: -f3)

	local pt_start_num=$(numfmt --from=iec ${pt_start})
	local pt_end_num=$(numfmt --from=iec ${pt_end})


	if [[ ${pt_start_num} -gt ${pt_end_num} ]]; then
    	echo "partition start is greater than end!"
    	return -1
	fi 

	local pt_size_num=`expr ${pt_end_num} - ${pt_start_num}`
	echo "pt_size_num: $pt_size_num"

	#local pt_size=$(numfmt --to=iec ${pt_size_num})

	PT_SIZE=$pt_size_num

	echo "Calculated partition size: $PT_SIZE"
}

function print_help()
{
	echo "$0 - generate update image"
	echo "-o specify output image name. Default is swu_<SLOT>_rescue_<soc>_<storage>_<date>.sdcard"
	echo "-d enable double slot copy. Default is single slot copy."
	echo "-e enable emmc. Default is sd."
	echo "-b soc name. Currently, imx8mm and imx6ull are supported."
	echo "-h print this help."
}

WRK_DIR="$(pwd)"
#CUR_DATE=$(date "+%Y%m%d-%H%M%S")
CUR_DATE=$(date "+%Y%m%d")

SUPPORTED_SOC="
imx8mm
imx6ull
"

TMP_BIN_FILE="./tmp.bin"

OUTPUT_IMAGE_NAME=""
DOUBLESLOT_FLAG=false
COPY_MODE="singlecopy"
STORAGE_EMMC_FLAG=false
STORAGE_DEVICE="sd"

while getopts "o:deb:h" arg; do
	case $arg in
		o)
			OUTPUT_IMAGE_NAME=$OPTARG
			;;
		d)
			DOUBLESLOT_FLAG=true
			COPY_MODE="doublecopy"
			;;
		e)
			STORAGE_EMMC_FLAG=true
			STORAGE_DEVICE="emmc"
			;;
		b)
			SOC=$OPTARG
			;;
		h)
			print_help
			exit 0
			;;
		?)
			echo "Error: unkonw argument!"
			exit 1
			;;
	esac
done

if [ -z "${SOC}" ]; then
	echo "No SOC specified!"
	exit 1
else
	VALID_SOC_FLAG=false
	for each_item in $SUPPORTED_SOC; do
		if [ x${each_item} == x${SOC} ]; then
			VALID_SOC_FLAG=true
		fi
	done
	if [ x${VALID_SOC_FLAG} == x"${false}" ]; then
		echo "Not supported SoC: ${SOC}"
	fi
fi

SOC_ASSEMBLE_SETTING_FILE="cfg_${SOC}.cfg"
source ${WRK_DIR}/${SOC_ASSEMBLE_SETTING_FILE}

if [ -z "${OUTPUT_IMAGE_NAME}" ]; then
	echo "No output image name specified! Use default name!"
	OUTPUT_IMAGE_NAME=swu_${COPY_MODE}_rescue_${SOC_NAME}_${STORAGE_DEVICE}_${CUR_DATE}.sdcard
fi
echo "Output image name is: $OUTPUT_IMAGE_NAME"
if test -e ./$OUTPUT_IMAGE_NAME; then
	echo -n "Delete existing $OUTPUT_IMAGE_NAME..."
	rm ./$OUTPUT_IMAGE_NAME
	echo "DONE"
fi

echo -n ">>>> Check MBR file..."
if [ ! -e ${IMAGE_MBR} ]; then
	echo -n "\nNo MBR file, will generate MBR..."
	MBR_FILENAME=$(basename ${IMAGE_MBR})
	MBR_FILEDIR=$(dirname ${IMAGE_MBR})
	cd $MBR_FILEDIR
	generate_mbr_dualslot $MBR_FILENAME 7500M
	cd -
fi
echo "DONE"

echo -n ">>>> Check slota boot partition mirror..."
BOOT_PT=$(echo $SLOTA_BOOT_PT | cut -d: -f1)
if [ ! -e ${BOOT_PT} ]; then
	echo -n "\nNo slata boot partition mirror, generate..."
	cd $BOOT_PT_DIR
	PT_SIZE=''
	calculate_pt_size $SLOTA_BOOT_PT
	truncate -s ${PT_SIZE} ${BOOT_PT}
	cd -
fi
echo "DONE"

echo -n ">>>> Check slotb boot partition mirror..."
BOOT_PT=$(echo $SLOTA_BOOT_PT | cut -d: -f1)
if [ ! -e ${BOOT_PT} ]; then
	echo -n "\nNo slatb boot partition mirror, generate..."
	PT_SIZE=''
	calculate_pt_size $SLOTA_BOOT_PT
	truncate -s ${PT_SIZE} ${BOOT_PT}
fi
echo "DONE"

echo -n ">>>> Check slota link..."
if test ! -d ./slota; then
	echo "ERROR: need to link slata to yocto image deploy directory!"
	exit 1
fi
echo "DONE"

echo -n ">>>> Check slotb link..."
if test ! -d ./slotb; then
	echo "ERROR: need to link slatb to yocto image deploy directory!"
	exit 1
fi
echo "DONE"

# assemble images
touch $OUTPUT_IMAGE_NAME

# 1. assemble header
echo ">>>> Making header..."
for each_item in $IMAGES_HEADER; do
	img_file=$(echo $each_item | cut -d: -f1)
	pad_start=$(echo $each_item | cut -d: -f2)
	pad_end=$(echo $each_item | cut -d: -f3)
	touch $TMP_BIN_FILE
	generate_padding_file $pad_start $img_file $pad_end $TMP_BIN_FILE
	if [ $? != 0 ]; then
		rm -f $TMP_BIN_FILE
		exit 1
	fi
	cat $TMP_BIN_FILE >> $OUTPUT_IMAGE_NAME
	rm -f $TMP_BIN_FILE
done
echo "DONE"

# 2. assemble swupdate
echo ">>>> Making swupdate..."
for each_item in $IMAGES_SWUPDATE; do
	img_file=$(echo $each_item | cut -d: -f1)
	pad_start=$(echo $each_item | cut -d: -f2)
	pad_end=$(echo $each_item | cut -d: -f3)
	touch $TMP_BIN_FILE
	generate_padding_file $pad_start $img_file $pad_end $TMP_BIN_FILE
	if [ $? != 0 ]; then
		rm -f $TMP_BIN_FILE
		exit 1
	fi
	cat $TMP_BIN_FILE >> $OUTPUT_IMAGE_NAME
	rm -f $TMP_BIN_FILE
done
echo "DONE"

# 3. assemble slota
echo ">>>> Making slota..."
BOOT_PT_PATH=$(echo $SLOTA_BOOT_PT | cut -d: -f1)
copy_images_to_boot_pt $BOOT_PT_PATH slota
PT_SIZE=''
ROOTFS_IMG=$(echo $SLOTA_ROOTFS | cut -d: -f1)
if [ ! -e $ROOTFS_IMG ]; then
	echo "SLOTA ROOTFS image not found!"
	exit -1
fi
calculate_pt_size $SLOTA_ROOTFS
truncate -s $PT_SIZE $ROOTFS_IMG
e2fsck -f $ROOTFS_IMG
resize2fs $ROOTFS_IMG
for each_item in $SLOTA_IMAGES; do
	item_path=$(echo $each_item | cut -d: -f1)
	cat $item_path >> $OUTPUT_IMAGE_NAME
done
echo "DONE"

# 4. assemble slotb
if [ x$DOUBLESLOT_FLAG == x"true" ]; then
	echo ">>>> Making slotb..."
	BOOT_PT_PATH=$(echo $SLOTB_BOOT_PT | cut -d: -f1)
	copy_images_to_boot_pt $BOOT_PT_PATH slotb
	PT_SIZE=''
	ROOTFS_IMG=$(echo $SLOTB_ROOTFS | cut -d: -f1)
	if [ ! -e $ROOTFS_IMG ]; then
		echo "SLOTB ROOTFS image not found!"
		exit -1
	fi
	calculate_pt_size $SLOTB_ROOTFS
	truncate -s $PT_SIZE $ROOTFS_IMG
	e2fsck -f $ROOTFS_IMG
	resize2fs $ROOTFS_IMG
	for each_item in $SLOTB_IMAGES; do
		item_path=$(echo $each_item | cut -d: -f1)
		cat $item_path >> $OUTPUT_IMAGE_NAME
	done
	echo "DONE"
fi

echo "==========================================================================="
echo "Create base image $OUTPUT_IMAGE_NAME successfully"
echo "==========================================================================="
