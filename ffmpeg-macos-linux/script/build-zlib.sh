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
VERSION=$(cat "$SCRIPT_DIR/../version/zlib")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "zlib"
checkStatus $? "create directory failed"
cd "zlib/"
checkStatus $? "change directory failed"

# download source
download https://www.zlib.net/fossils/zlib-$VERSION.tar.gz "zlib.tar.gz"
checkStatus $? "download failed"

# unpacking
tar -zxf "zlib.tar.gz"
checkStatus $? "unpacking failed"
cd "zlib-$VERSION/"
checkStatus $? "change directory failed"

if isMsys; then
	echo "run windows specific build"

	# windows build
	make -j $CPUS -f win32/Makefile.gcc
	checkStatus $? "build failed"

	# install
	make -j $CPUS -f win32/Makefile.gcc install INCLUDE_PATH=$TOOL_DIR/include LIBRARY_PATH=$TOOL_DIR/lib BINARY_PATH=$TOOL_DIR/bin
	checkStatus $? "installation failed"
else
	# prepare build
	./configure --prefix="$TOOL_DIR" --static
	checkStatus $? "configuration failed"

	# build
	make -j $CPUS
	checkStatus $? "build failed"

	# install
	make install
	checkStatus $? "installation failed"
fi
