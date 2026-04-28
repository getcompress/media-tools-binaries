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

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "x264"
checkStatus $? "create directory failed"
cd "x264/"
checkStatus $? "change directory failed"

# download source
download https://code.videolan.org/videolan/x264/-/archive/master/x264-master.tar.gz "x264-master.tar.gz"
checkStatus $? "download failed"

# unpack
tar -zxf "x264-master.tar.gz"
checkStatus $? "unpack failed"
cd "x264-master/"
checkStatus $? "change directory failed"

# CLANGARM64 has no 'gcc'/'cc' alias; tell x264 configure to use clang
if isMsys && [ "${MSYSTEM:-}" = "CLANGARM64" ]; then
    export CC=clang
    export CXX=clang++
fi

# prepare build
./configure --prefix="$TOOL_DIR" --enable-static --disable-cli
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
make install
checkStatus $? "installation failed"
