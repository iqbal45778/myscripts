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

# The name of the device for which the kernel is built
MODEL="Redmi Note 5 Pro"

# Avoid hardcoding things
KERNEL=PREDATOR
DEFCONFIG=predator_defconfig
DEVICE=whyred
CIPROVIDER=CircleCI
PARSE_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
PARSE_ORIGIN="$(git config --get remote.origin.url)"
COMMIT_POINT="$(git log --pretty=format:'%h : %s' -1)"

# Export custom KBUILD
export KBUILD_BUILD_USER=iqbal
export KBUILD_BUILD_HOST=Predator_Nusantara🇮🇩
export OUTFILE=${OUTDIR}/arch/arm64/boot/Image.gz-dtb

# Kernel groups
CI_CHANNEL=-1001488385343

# Set default local datetime
DATE=$(TZ=Asia/Jakarta date +"%Y%m%d-%T")
BUILD_DATE=$(TZ=Asia/Jakarta date +"%Y%m%d-%H%M")

# Kernel revision
KERNELRELEASE=whyred

# Function to replace defconfig versioning
setversioning() {
        # For staging branch
            KERNELNAME="${KERNEL}-${KERNELRELEASE}-EAS-OldCam-${BUILD_DATE}"

    # Export our new localversion and zipnames
    export KERNELTYPE KERNELNAME
    export TEMPZIPNAME="${KERNELNAME}-unsigned.zip"
    export ZIPNAME="${KERNELNAME}.zip"
}

# Send to channel
tg_channelcast() {
    "${TELEGRAM}" -c "${CI_CHANNEL}" -H \
    "$(
		for POST in "${@}"; do
			echo "${POST}"
		done
    )"
}
tg_post_build() {
	#Post MD5Checksum alongwith for easeness
	MD5CHECK=$(md5sum "$1" | cut -d' ' -f1)

	#Show the Checksum alongwith caption
	curl --progress-bar -F document=@"$1" "$BOT_BUILD_URL" \
	-F chat_id="$2"  \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=html" \
	-F caption="$3 | <b>MD5 Checksum : </b><code>$MD5CHECK</code>"  
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
    git clone https://github.com/PREDATOR-project/AnyKernel3.git -b BangBroz-oldcam anykernel3
    kernelstringfix
    export CROSS_COMPILE="${KERNELDIR}/gcc/bin/aarch64-elf-"
    export CROSS_COMPILE_ARM32="${KERNELDIR}/gcc32/bin/arm-eabi-"
    make O=out ARCH=arm64 ${DEFCONFIG}
    make -j$(nproc --all) O=out ARCH=arm64

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
    cp "${OUTDIR}"/arch/arm64/boot/Image.gz-dtb "${ANYKERNEL}"/

    # Zip the kernel, or fail
    cd "${ANYKERNEL}" || exit
    zip -r9 "${TEMPZIPNAME}" *

    # Sign the zip before sending it to Telegram
    curl -sLo zipsigner-3.0.jar https://raw.githubusercontent.com/baalajimaestro/AnyKernel2/master/zipsigner-3.0.jar
    java -jar zipsigner-3.0.jar ${TEMPZIPNAME} ${ZIPNAME}

    # Ship it to the CI channel
    "${TELEGRAM}" -f "$ZIPNAME" -c "${CI_CHANNEL}"

    # Go back for any extra builds
    cd ..
}

# Ship China firmware builds
setnewcam() {
    export CAMLIBS=NewCam
    # Pick DSP change
    sed -i 's/CONFIG_XIAOMI_NEW_CAMERA_BLOBS=n/CONFIG_XIAOMI_NEW_CAMERA_BLOBS=y/g' arch/arm64/configs/${DEFCONFIG}
    echo -e "Newcam ready"
}

# Ship China firmware builds
clearout() {
    # Pick DSP change
    rm -rf out
    mkdir -p out
}

#Setver 2 for newcam
setver2() {
    KERNELNAME="${KERNEL}-${KERNELRELEASE}-EAS-NewCam-${BUILD_DATE}"
    export KERNELTYPE KERNELNAME
    export TEMPZIPNAME="${KERNELNAME}-unsigned.zip"
    export ZIPNAME="${KERNELNAME}.zip"
}

# Fix for CI builds running out of memory
fixcilto() {
    sed -i 's/CONFIG_LTO=y/# CONFIG_LTO is not set/g' arch/arm64/configs/${DEFCONFIG}
    sed -i 's/CONFIG_LD_DEAD_CODE_DATA_ELIMINATION=y/# CONFIG_LD_DEAD_CODE_DATA_ELIMINATION is not set/g' arch/arm64/configs/${DEFCONFIG}
}

## Start the kernel buildflow ##
setversioning
fixcilto
tg_channelcast "<b>CI Build Triggered</b>" \
        "Compiler: <code>${COMPILER_STRING}</code>" \
        "Model: ${MODEL}" \
	"Device: ${DEVICE}" \
	"Kernel: <code>${KERNEL}, ${KERNELRELEASE}</code>" \
	"Linux Version: <code>$(make kernelversion)</code>" \
	"Branch: <code>${PARSE_BRANCH}</code>" \
	"Commit point: <code>${COMMIT_POINT}</code>" \
	"Clocked at: <code>$(date +%Y%m%d-%H%M)</code>"
START=$(date +"%s")
makekernel || exit 1
shipkernel
setnewcam
setver2
makekernel || exit 1
shipkernel
END=$(date +"%s")
DIFF=$(( END - START ))
tg_channelcast "Build for ${DEVICE} with ${COMPILER_STRING} <b>succeed</b> took $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)!"
