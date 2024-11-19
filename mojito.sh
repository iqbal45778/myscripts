#!/usr/bin/env bash
# Copyright (C) 2019-2020 Jago Gardiner (nysascape)
#
# Licensed under the Raphielscape Public License, Version 1.d (the "License");
# you may not use this file except in compliance with the License.
#
# CI build script

# Needed exports
export TELEGRAM_TOKEN=1157809262:AAHNbCHG-XcjgpGuDflcTX8Z_OJiXcjdDr0
export ANYKERNEL=$(pwd)/anykernel3

# Avoid hardcoding things
KERNEL=PERF-STABLE
DEFCONFIG=vendor/mojito_defconfig
CIPROVIDER=CircleCI
PARSE_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
PARSE_ORIGIN="$(git config --get remote.origin.url)"
COMMIT_POINT="$(git log --pretty=format:'%h : %s' -1)"

# Get total RAM
RAM_INFO=$(free -m)
TOTAL_RAM=$(echo "$RAM_INFO" | awk '/^Mem:/{print $2}')
TOTAL_RAM_GB=$(awk "BEGIN {printf \"%.0f\", $TOTAL_RAM/1024}")
export TOTAL_RAM_GB

# Get all cores of CPU
PROCS=$(nproc --all)
export PROCS

# Get CPU name
export CPU_NAME="$(lscpu | sed -nr '/Model name/ s/.*:\s*(.*) */\1/p')"

# Get distro name
DISTRO=$(source /etc/os-release && echo ${NAME})

# Export custom KBUILD
export OUTFILE=${OUTDIR}/arch/arm64/boot/Image.gz
export OUTFILE=${OUTDIR}/arch/arm64/boot/dtb.img
export OUTFILE=${OUTDIR}/arch/arm64/boot/dtbo.img
export KBUILD_BUILD_HOST=android
export CLANG_PATH=${KERNELDIR}/clang/clang-r498229b
export PATH=${CLANG_PATH}/bin:${PATH}
export ARCH=arm64
export DATE=$(TZ=Asia/Jakarta date)
# Kernel groups
CI_CHANNEL=-1001488385343

# Kernel revision
KERNELRELEASE=surya

# Clang is annoying
PATH="${KERNELDIR}/clang/clang-r498229b/bin:${PATH}"

# Set date and time
DATE=$(TZ=Asia/Jakarta date)

# Set date and time for zip name
ZIP_DATE=$(TZ=Asia/Jakarta date +"%Y%m%d-%H%M")

# Function to replace defconfig versioning
setversioning() {

# For staging branch
            KERNELNAME="${KERNEL}-${KERNELRELEASE}-KSU-${ZIP_DATE}"
	    
    # Export our new localversion and zipnames
    export KERNELTYPE KERNELNAME
    export TEMPZIPNAME="${KERNELNAME}.zip"
    export ZIPNAME="${KERNELNAME}.zip"
}

# Send to channel
tg_channelcast() {
    "${TELEGRAM}" -c "${CI_CHANNEL}" -H \
    "$(2
		for POST in "${@}"; do
			echo "${POST}"
		done
    )"
}

# Fix long kernel strings
kernelstringfix() {
    git config --global user.name "predator112"
    git config --global user.email "mi460334@gmail.com"
    git add .
    git commit -m "stop adding dirty"
}

# Make the kernel
makekernel() {
    # Clean any old AnyKernel
    rm -rf ${ANYKERNEL}
    git clone https://github.com/Aex-Mod/AnyKernel3 -b surya anykernel3
    kernelstringfix
    make O=out ARCH=arm64 ${DEFCONFIG}
    if [[ "${COMPILER_TYPE}" =~ "clang"* ]]; then
        make -j$(nproc --all) CC=clang CROSS_COMPILE="${KERNELDIR}/gcc/bin/aarch64-elf-" CROSS_COMPILE_ARM32="${KERNELDIR}/gcc32/bin/arm-eabi" O=out ARCH=arm64
    else
	    make -j$(nproc --all) O=out ARCH=arm64 CROSS_COMPILE="${KERNELDIR}/gcc/bin/aarch64-elf-" CROSS_COMPILE_ARM32="${KERNELDIR}/gcc32/bin/arm-eabi-"
    fi

    # Check if compilation is done successfully.
    if ! [ -f "${OUTFILE}" ]; then
	    END=$(date +"%s")
	    DIFF=$(( END - START ))
	    echo -e "Kernel compilation failed, See buildlog to fix errors"
	    tg_channelcast "Build for ${DEVICE} <b>failed</b> in $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)! Check ${CIPROVIDER} for errors!"
	    exit 1
    fi
}

# Ship the compiled kernel
shipkernel() {
    # Copy compiled kernel
    cp "${OUTDIR}"/arch/arm64/boot/Image.gz "${ANYKERNEL}"/
    cp "${OUTDIR}"/arch/arm64/boot/dtb.img "${ANYKERNEL}"/
    cp "${OUTDIR}"/arch/arm64/boot/dtbo.img "${ANYKERNEL}"/
   
    # Zip the kernel, or fail
    cd "${ANYKERNEL}" || exit
    zip -r9 "${TEMPZIPNAME}" *

    # Ship it to the CI channel
    "${TELEGRAM}" -f "$ZIPNAME" -c "${CI_CHANNEL}"

    # Go back for any extra builds
    cd ..
}

## Start the kernel buildflow ##
setversioning
tg_channelcast "Docker OS: <code>$DISTRO</code>" \
        "Compiler: <code>${COMPILER_STRING}</code>" \
	"Device: <code>Redmi Note 10 (sunny/mojito)</code>" \
	"Linux Version: <code>$(make kernelversion)</code>" \
        "Date: <code>$DATE</code>" \
	"Branch: <code>${PARSE_BRANCH}</code>" \
        "Host RAM Count: <code>${TOTAL_RAM_GB}</code>" \
        "Pipeline Host: <code>${KBUILD_BUILD_HOST}</code>" \
        "Host CPU Name: <code>${CPU_NAME}</code>" \
        "Host Core Count: <code>${PROCS} core(s)</code>" \
	"Commit point: <code>${COMMIT_POINT}</code>"
START=$(date +"%s")
makekernel || exit 1
shipkernel
END=$(date +"%s")
DIFF=$(( END - START ))
tg_channelcast "Build for Redmi Note 10 with ${COMPILER_STRING} <b>succeed</b> took $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)!"
