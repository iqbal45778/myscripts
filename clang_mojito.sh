#!/usr/bin/env bash
#
# Copyright (C) 2019 nysascape
#
# Licensed under the Raphielscape Public License, Version 1.d (the "License");
# you may not use this file except in compliance with the License.
#
# Probably the 3rd bad apple coming
# Enviroment variables

# Export KERNELDIR as en environment-wide thingy
# We start in scripts, so like, don't clone things
KERNELDIR="$(pwd)"
SCRIPTS=${KERNELDIR}/kernelscripts
OUTDIR=${KERNELDIR}/out
COMPILER_TYPES=gcc

# Pick your poison
if [[ "${COMPILER_TYPES}" =~ "clang" ]]; then
        git clone https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 -b android15-release --depth=1  "${KERNELDIR}/clang"
      	git clone https://github.com/mvaisakh/gcc-arm64 -b gcc-master --depth=1 "${KERNELDIR}/gcc"
        git clone https://github.com/kdrag0n/arm-eabi-gcc --depth=1 "${KERNELDIR}/gcc32"
        COMPILER_STRING='google clang 17'
        COMPILER_TYPE='google clang 17'
else
        # Default to GCC from Arter
        git clone https://github.com/kdrag0n/aarch64-elf-gcc -b 9.x --depth=1 "${KERNELDIR}/gcc"
        git clone https://github.com/kdrag0n/arm-eabi-gcc --depth=1 "${KERNELDIR}/gcc32"
        COMPILER_STRING='GCC'
	COMPILER_TYPE='GCC'
fi    

export COMPILER_STRING COMPILER_TYPE KERNELDIR SCRIPTS OUTDIR

git clone https://github.com/fabianonline/telegram.sh/ telegram

# Export Telegram.sh
TELEGRAM=${KERNELDIR}/telegram/telegram

export TELEGRAM JOBS
