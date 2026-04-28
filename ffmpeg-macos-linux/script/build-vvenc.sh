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

# GCC 15.2.0 on MINGW64 has an ICE in the pro_and_epilogue RTL pass when
# vvenc is compiled with LTO (config/i386/i386.cc:7447). vvenc sets
# INTERPROCEDURAL_OPTIMIZATION per-target in its cmake files, which appends
# -flto to COMPILE_OPTIONS *after* CMAKE_CXX_FLAGS, so -fno-lto in cmake
# flags cannot win the ordering race. Patch the cmake sources directly.
find "vvenc-$VERSION" \( -name "CMakeLists.txt" -o -name "*.cmake" \) \
    -exec sed -i.original \
        -e 's/INTERPROCEDURAL_OPTIMIZATION[[:space:]]*TRUE/INTERPROCEDURAL_OPTIMIZATION FALSE/g' \
        -e 's/INTERPROCEDURAL_OPTIMIZATION[[:space:]]*ON/INTERPROCEDURAL_OPTIMIZATION FALSE/g' \
    {} \;

# prepare build
mkdir "build"
checkStatus $? "create directory failed"
cd "build/"
checkStatus $? "change directory failed"
cmake $(cmakeTargetArgs) $(cmakePolicyCompatArgs) \
    -DCMAKE_INSTALL_PREFIX:PATH=$TOOL_DIR \
    -DBUILD_SHARED_LIBS=OFF \
    -DVVENC_LIBRARY_ONLY=ON \
    -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF \
    ../vvenc-$VERSION
checkStatus $? "configuration failed"

# build
cmakeBuild "$CPUS"
checkStatus $? "build failed"

# install
cmakeInstall
checkStatus $? "installation failed"
