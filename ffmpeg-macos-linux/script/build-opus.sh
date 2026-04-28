#!/bin/sh

# SPDX-License-Identifier: AGPL-3.0-or-later
#
# This file is part of the GetCompress media-tools-binaries repository and is
# distributed under the GNU Affero General Public License, version 3 or any
# later version.
#
# It is derived from Martin Riedl's FFmpeg build script project:
# https://git.martin-riedl.de/ffmpeg/build-script.git
#
# Upstream attribution and the Apache-2.0 license text are preserved in this
# repository for upstream-origin material. See NOTICE and
# ffmpeg-macos-linux/LICENSE for details.

# handle arguments
echo "arguments: $@"
SCRIPT_DIR=$1
SOURCE_DIR=$2
TOOL_DIR=$3
CPUS=$4

# load functions
. $SCRIPT_DIR/functions.sh

# load version
VERSION=$(cat "$SCRIPT_DIR/../version/opus")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "opus"
checkStatus $? "create directory failed"
cd "opus/"
checkStatus $? "change directory failed"

# download source
download https://downloads.xiph.org/releases/opus/opus-$VERSION.tar.gz "opus.tar.gz"
if [ $? -ne 0 ]; then
    echo "download failed; start download from gitlab server"
    download https://gitlab.xiph.org/xiph/opus/-/archive/v$VERSION/opus-v$VERSION.tar.gz "opus.tar.gz"
    checkStatus $? "download failed"
fi

# unpack
tar -zxf "opus.tar.gz"
checkStatus $? "unpack failed"
cd opus*$VERSION/
checkStatus $? "change directory failed"

# check for pre-generated configure file
if [ -f "configure" ]; then
    echo "use existing configure file"
else
    ./autogen.sh
    checkStatus $? "autogen failed"
fi

# prepare build
OPUS_CONFIGURE_FLAGS="--prefix=$TOOL_DIR --enable-shared=no --disable-extra-programs --disable-doc"

# Upstream Opus enables ARM rtcd on AArch64, but its runtime CPU detection
# layer does not provide a Windows ARM64 backend. On MSYS2 CLANGARM64 this
# fails in celt/arm/armcpu.c with the upstream-recommended fix: disable rtcd.
if isMsys && [ "${MSYSTEM:-}" = "CLANGARM64" ]; then
    OPUS_CONFIGURE_FLAGS="$OPUS_CONFIGURE_FLAGS --disable-rtcd"
fi

./configure $OPUS_CONFIGURE_FLAGS
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
make install
checkStatus $? "installation failed"
