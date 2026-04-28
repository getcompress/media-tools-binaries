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

if isMsys; then
    echo "skip nasm build on Windows (provided by pacman)"
    exit 0
fi

# load version
VERSION=$(cat "$SCRIPT_DIR/../version/nasm")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "nasm"
checkStatus $? "create directory failed"
cd "nasm/"
checkStatus $? "change directory failed"

# download source
mkdir "nasm"
checkStatus $? "create directory failed"
download http://www.nasm.us/pub/nasm/releasebuilds/$VERSION/nasm-$VERSION.tar.gz nasm.tar.gz
if [ $? -ne 0 ]; then
    echo "download failed; start download from github server"
    download https://github.com/netwide-assembler/nasm/archive/refs/tags/nasm-$VERSION.tar.gz nasm.tar.gz
    checkStatus $? "download failed"
fi

# unpack
tar -zxf "nasm.tar.gz" -C nasm --strip-components=1
checkStatus $? "unpack failed"
cd "nasm/"
checkStatus $? "change directory failed"

# prepare build
if [ -f "configure" ]; then
    echo "configure file found; continue"
else
    echo "run autogen first"
    ./autogen.sh
    checkStatus "autogen failed"
fi
./configure --prefix="$TOOL_DIR"
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# manpage build might fail -> create dummy file (manpage is not used)
if [ ! -f "nasm.1" ]; then
    touch "nasm.1"
fi
if [ ! -f "ndisasm.1" ]; then
    touch "ndisasm.1"
fi

# install
make install
checkStatus $? "installation failed"
