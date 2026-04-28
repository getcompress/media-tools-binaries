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
# ffmpeg-build-scripts/LICENSE for details.

# handle arguments
echo "arguments: $@"
SCRIPT_DIR=$1
SOURCE_DIR=$2
TOOL_DIR=$3
CPUS=$4

# load functions
. $SCRIPT_DIR/functions.sh

# load version
VERSION=$(cat "$SCRIPT_DIR/../version/zimg")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "zimg"
checkStatus $? "create directory failed"
cd "zimg/"
checkStatus $? "change directory failed"

# download source
download https://github.com/sekrit-twc/zimg/archive/refs/tags/release-$VERSION.tar.gz "zimg.tar.gz"
checkStatus $? "download failed"

# unpack
tar -zxf "zimg.tar.gz"
checkStatus $? "unpack failed"
cd "zimg-release-$VERSION/"
checkStatus $? "change directory failed"

# prepare build
./autogen.sh
checkStatus $? "autogen failed"
./configure --prefix="$TOOL_DIR" --enable-shared=no
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
make install
checkStatus $? "installation failed"

# post-installation
# build fails on some OS, because of missing linking to libm
sed -i.original -e 's/lzimg/lzimg -lm/g' $TOOL_DIR/lib/pkgconfig/zimg.pc
