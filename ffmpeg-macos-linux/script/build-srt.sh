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
VERSION=$(cat "$SCRIPT_DIR/../version/srt")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "srt"
checkStatus $? "create directory failed"
cd "srt/"
checkStatus $? "change directory failed"

# download source
download https://github.com/Haivision/srt/archive/refs/tags/v$VERSION.tar.gz "srt.tar.gz"
checkStatus $? "download failed"

# unpack
tar -zxf "srt.tar.gz"
checkStatus $? "unpack failed"

# prepare build
mkdir srt_build
checkStatus $? "create build directory failed"
cd srt_build
checkStatus $? "change build directory failed"
cmake $(cmakeTargetArgs) -DCMAKE_INSTALL_PREFIX:PATH=$TOOL_DIR -DENABLE_SHARED=OFF -DENABLE_APPS=OFF ../srt-$VERSION/
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
make install
checkStatus $? "installation failed"
