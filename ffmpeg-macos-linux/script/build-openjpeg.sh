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
VERSION=$(cat "$SCRIPT_DIR/../version/openjpeg")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "openjpeg"
checkStatus $? "create directory failed"
cd "openjpeg/"
checkStatus $? "change directory failed"

# download source
download https://github.com/uclouvain/openjpeg/archive/refs/tags/v$VERSION.tar.gz "openjpeg.tar.gz"
checkStatus $? "download failed"

# unpack
tar -zxf "openjpeg.tar.gz"
checkStatus $? "unpack failed"

# prepare build
mkdir openjpeg_build
checkStatus $? "create build directory failed"
cd openjpeg_build
checkStatus $? "change build directory failed"
cmake $(cmakeTargetArgs) \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=$TOOL_DIR \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_STATIC_LIBS=ON \
    -DBUILD_CODEC=OFF \
    -DBUILD_JPIP=OFF \
    -DBUILD_JPIP_SERVER=OFF \
    -DBUILD_JAVA=OFF \
    -DBUILD_VIEWER=OFF \
    -DBUILD_MJ2=OFF \
    -DBUILD_JPWL=OFF \
    -DBUILD_DOC=OFF \
    -DBUILD_TESTING=OFF \
    -Wno-dev \
    ../openjpeg-$VERSION/
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
make install
checkStatus $? "installation failed"

# post-installation
# modify pkg-config file for usage with ffmpeg (it seems that the flag for threads is missing)
sed -i.original -e 's/lopenjp2/lopenjp2 -lpthread/g' $TOOL_DIR/lib/pkgconfig/libopenjp2.pc
