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

# $1 = script directory
# $2 = working directory
# $3 = tool directory
# $4 = CPUs

# load functions
. $SCRIPT_DIR/functions.sh

# load version
VERSION=$(cat "$SCRIPT_DIR/../version/openh264")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "openh264"
checkStatus $? "create directory failed"
cd "openh264/"
checkStatus $? "change directory failed"

# download source
download https://github.com/cisco/openh264/archive/v$VERSION.tar.gz "openh264.tar.gz"
checkStatus $? "download failed"

# unpack
tar -zxf "openh264.tar.gz"
checkStatus $? "unpack failed"
cd "openh264-$VERSION/"
checkStatus $? "change directory failed"

# build
make PREFIX="$TOOL_DIR" -j $CPUS
checkStatus $? "build failed"

# install
make install-static PREFIX="$TOOL_DIR"
checkStatus $? "installation failed"
