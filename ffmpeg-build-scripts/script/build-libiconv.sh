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
VERSION=$(cat "$SCRIPT_DIR/../version/libiconv")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "libiconv"
checkStatus $? "create directory failed"
cd "libiconv/"
checkStatus $? "change directory failed"

# download source
download https://ftp.gnu.org/pub/gnu/libiconv/libiconv-$VERSION.tar.gz "libiconv.tar.gz"
checkStatus $? "download failed"

# unpack
tar -zxf "libiconv.tar.gz"
checkStatus $? "unpack failed"
cd "libiconv-$VERSION/"
checkStatus $? "change directory failed"

# prepare build
# shared version is required for some library builds (like zvbi)
./configure --prefix="$TOOL_DIR" --enable-static=yes
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
make install
checkStatus $? "installation failed"
