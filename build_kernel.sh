#!/bin/bash
# kernel build script by thehacker911
# base from my s6 kernel https://github.com/HRTKernel/Hacker_Kernel_SM-G92X_MM/blob/master/build_kernel.sh

#helper
backup_file() { cp $1 $1~; }

replace_string() {
  if [ -z "$(grep "$2" $1)" ]; then
      sed -i "s;${3};${4};" $1;
  fi;
}

replace_section() {
  line=`grep -n "$2" $1 | cut -d: -f1`;
  sed -i "/${2}/,/${3}/d" $1;
  sed -i "${line}s;^;${4}\n;" $1;
}

remove_section() {
  sed -i "/${2}/,/${3}/d" $1;
}

insert_line() {
  if [ -z "$(grep "$2" $1)" ]; then
    case $3 in
      before) offset=0;;
      after) offset=1;;
    esac;
    line=$((`grep -n "$4" $1 | cut -d: -f1` + offset));
    sed -i "${line}s;^;${5}\n;" $1;
  fi;
}

replace_line() {
  if [ ! -z "$(grep "$2" $1)" ]; then
    line=`grep -n "$2" $1 | cut -d: -f1`;
    sed -i "${line}s;.*;${3};" $1;
  fi;
}

remove_line() {
  if [ ! -z "$(grep "$2" $1)" ]; then
    line=`grep -n "$2" $1 | cut -d: -f1`;
    sed -i "${line}d" $1;
  fi;
}

prepend_file() {
  if [ -z "$(grep "$2" $1)" ]; then
    echo "$(cat $patch/$3 $1)" > $1;
  fi;
}

insert_file() {
  if [ -z "$(grep "$2" $1)" ]; then
    case $3 in
      before) offset=0;;
      after) offset=1;;
    esac;
    line=$((`grep -n "$4" $1 | cut -d: -f1` + offset));
    sed -i "${line}s;^;\n;" $1;
    sed -i "$((line - 1))r $patch/$5" $1;
  fi;
}

append_file() {
  if [ -z "$(grep "$2" $1)" ]; then
    echo -ne "\n" >> $1;
    cat $patch/$3 >> $1;
    echo -ne "\n" >> $1;
  fi;
}

replace_file() {
  cp -pf $patch/$3 $1;
  chmod $2 $1;
}

#base
export ARCH=arm64
export BUILD_CROSS_COMPILE=$TOOLCHAIN_DIR/$TOOLCHAIN
export BUILD_JOB_NUMBER=`grep processor /proc/cpuinfo|wc -l`
export KBUILD_BUILD_USER=thehacker911
export KBUILD_BUILD_HOST=gmail.com
export LOCALVERSION=-`echo $KERNEL_NAME`

KERNEL_DIR=$(pwd)
BUILD_USER="$USER"
KERNEL_NAME=hacker-kernel-g973f
TOOLCHAIN_DIR=/home/$BUILD_USER/kernel/toolchains
TOOLCHAIN=aarch64-linux-android-4.9/bin/aarch64-linux-android-
BOARD_KERNEL_PAGESIZE=4096
DTB_PADDING=0
DTBTOOL=$BUILD_KERNEL_DIR/tools/dtbtool
DTCTOOL=$KERNEL_DIR/tools/mkdtimage
CONFIG_DIR=arch/arm64/configs
KERNEL_DEFCONFIG=hacker_defconfig

OUTPUT_DIR=$KERNEL_DIR/arch/arm64/boot
DTS_DIR=$KERNEL_DIR/arch/arm64/boot/dts/exynos
DTB_DIR=$OUTPUT_DIR/dtb

SEANDROIDENFORCE()
{
	echo -n "SEANDROIDENFORCE" >> image-new.img
}

###build
CLEAN()
{
	echo ""
	echo "=============================================="
	echo "START: MAKE CLEAN"
	echo "=============================================="
	echo ""
	
	if ! [ -d $KERNEL_DIR/arch/$ARCH/boot/dts ] ; then
		echo "No cleaning files: "$KERNEL_DIR/arch/$ARCH/boot/dts""
	else
		echo "Cleaning files in: "$KERNEL_DIR/arch/$ARCH/boot/dts/*.dtb""
		make clean
		rm $KERNEL_DIR/arch/$ARCH/boot/boot.img-zImage
		find . -name "*.dtb" -exec rm {} \;
		find . -type f -name "*~" -exec rm -f {} \;
		find . -type f -name "*orig" -exec rm -f {} \;
		find . -type f -name "*rej" -exec rm -f {} \;
		find . -name "*.ko" -exec rm {} \;
	fi
	
	echo ""
	echo "=============================================="
	echo "END: MAKE CLEAN"
	echo "=============================================="
	echo ""
}

BUILD_CONFIG()
{
	cp $KERNEL_DEFCONFIG $CONFIG_DIR/$CONFIG_DIR
	remove_line $CONFIG_DIR/$CONFIG "# CONFIG_CPU_FREQ_GOV_ONDEMAND is not set";
	insert_line $CONFIG_DIR/$CONFIG "CONFIG_CPU_FREQ_GOV_ONDEMAND=y" after "CONFIG_CPU_FREQ_GOV_SCHEDUTIL=y";
	
}


BUILD_KERNEL()
{
	CLEAN
	echo ""
	echo "=============================================="
	echo "START: BUILD_KERNEL"
	echo "=============================================="
	echo ""


	BUILD_CONFIG
	export ANDROID_MAJOR_VERSION=q


	make -j$BUILD_JOB_NUMBER ARCH=$ARCH \
			CROSS_COMPILE=$BUILD_CROSS_COMPILE \
			$KERNEL_DEFCONFIG || exit -1

	make -j$BUILD_JOB_NUMBER ARCH=$ARCH \
			CROSS_COMPILE=$BUILD_CROSS_COMPILE || exit -1

	
	echo ""
	echo "================================="
	echo "END: BUILD_KERNEL"
	echo "================================="
	echo ""
}

BUILD_RAMDISK()
{
	mv $KERNEL_DIR/arch/$ARCH/boot/Image $KERNEL_DIR/arch/$ARCH/boot/boot.img-zImage
	rm -f $KERNEL_DIR/ramdisk/split_img/boot.img-zImage
	mv -f $KERNEL_DIR/arch/$ARCH/boot/boot.img-zImage $KERNEL_DIR/ramdisk/split_img/boot.img-zImage
	cd $KERNEL_DIR/Ramdisk
	./repackimg.sh --nosudo
	SEANDROIDENFORCE
	mv image-new.img $KERNEL_DIR/zip/boot.img

}

BUILD_ZIP()
{
	cd $KERNEL_DIR/zip
	zip -r $KERNEL_NAME.zip META-INF
}

# MAIN FUNCTION
rm -rf ./build.log
(
	START_TIME=`date +%s`

	BUILD_KERNEL
	BUILD_RAMDISK
	BUILD_ZIP

	END_TIME=`date +%s`
	
	let "ELAPSED_TIME=$END_TIME-$START_TIME"
	echo "Total compile time was $ELAPSED_TIME seconds"

) 2>&1	| tee -a ./build.log

# Credits:
# Samsung
# google
# osm0sis
# cyanogenmod
# kylon 
