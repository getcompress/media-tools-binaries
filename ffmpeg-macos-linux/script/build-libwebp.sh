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
VERSION=$(cat "$SCRIPT_DIR/../version/libwebp")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "libwebp"
checkStatus $? "create directory failed"
cd "libwebp/"
checkStatus $? "change directory failed"

# download source
download https://github.com/webmproject/libwebp/archive/refs/tags/v$VERSION.tar.gz "libwebp.tar.gz"
checkStatus $? "download failed"

# unpack
tar -zxf "libwebp.tar.gz"
checkStatus $? "unpack failed"

# prepare build
mkdir libwebp_build
checkStatus $? "create build directory failed"
cd libwebp_build
checkStatus $? "change build directory failed"
cmake $(cmakeTargetArgs) -DCMAKE_INSTALL_PREFIX:PATH=$TOOL_DIR -DBUILD_SHARED_LIBS=OFF -DWEBP_BUILD_CWEBP=OFF -DWEBP_BUILD_DWEBP=OFF -DWEBP_BUILD_GIF2WEBP=OFF -DWEBP_BUILD_IMG2WEBP=OFF -DWEBP_BUILD_VWEBP=OFF -DWEBP_BUILD_WEBPINFO=OFF -DWEBP_BUILD_WEBPMUX=OFF -DWEBP_BUILD_EXTRAS=OFF ../libwebp-$VERSION/
checkStatus $? "configuration failed"

# build
cmakeBuild "$CPUS"
checkStatus $? "build failed"

# install
cmakeInstall
checkStatus $? "installation failed"
