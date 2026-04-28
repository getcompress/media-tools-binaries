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

# $1 = script directory
# $2 = working directory
# $3 = tool directory
# $4 = CPUs

# load functions
. $SCRIPT_DIR/functions.sh

# load version
VERSION=$(cat "$SCRIPT_DIR/../version/freetype")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "freetype"
checkStatus $? "create directory failed"
cd "freetype/"
checkStatus $? "change directory failed"

# download source
download https://download.savannah.gnu.org/releases/freetype/freetype-$VERSION.tar.gz "freetype.tar.gz"
if [ $? -ne 0 ]; then
    echo "download failed; start download from mirror server"
    download https://sourceforge.net/projects/freetype/files/freetype2/$VERSION/freetype-$VERSION.tar.gz/download "freetype.tar.gz"
    checkStatus $? "download failed"
fi

# unpack
tar -zxf "freetype.tar.gz"
checkStatus $? "unpack failed"
cd "freetype-$VERSION/"
checkStatus $? "change directory failed"

# prepare build
appendFlag CPPFLAGS "-I${TOOL_DIR}/include"
appendFlag LDFLAGS "-L${TOOL_DIR}/lib"
./configure --prefix="$TOOL_DIR" --enable-shared=no \
    --with-zlib=yes \
    --with-bzip2=no \
    --with-png=no \
    --with-harfbuzz=no \
    --with-brotli=no
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
make install
checkStatus $? "installation failed"
