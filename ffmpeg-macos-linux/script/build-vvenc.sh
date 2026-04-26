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
VERSION=$(cat "$SCRIPT_DIR/../version/vvenc")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "vvenc"
checkStatus $? "create directory failed"
cd "vvenc/"
checkStatus $? "change directory failed"

# download source
download https://github.com/fraunhoferhhi/vvenc/archive/refs/tags/v$VERSION.tar.gz "vvenc.tar.gz"
checkStatus $? "download failed"

# unpack
tar -zxf "vvenc.tar.gz"
checkStatus $? "unpack failed"

# prepare build
mkdir "build"
checkStatus $? "create directory failed"
cd "build/"
checkStatus $? "change directory failed"
cmake $(cmakeTargetArgs) -DCMAKE_INSTALL_PREFIX:PATH=$TOOL_DIR -DBUILD_SHARED_LIBS=OFF ../vvenc-$VERSION
checkStatus $? "configuration failed"

# build
cmakeBuild "$CPUS"
checkStatus $? "build failed"

# install
cmakeInstall
checkStatus $? "installation failed"
