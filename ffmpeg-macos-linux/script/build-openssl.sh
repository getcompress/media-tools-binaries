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
VERSION=$(cat "$SCRIPT_DIR/../version/openssl")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "openssl"
checkStatus $? "create directory failed"
cd "openssl/"
checkStatus $? "change directory failed"

# download source
download https://github.com/openssl/openssl/releases/download/openssl-$VERSION/openssl-$VERSION.tar.gz "openssl.tar.gz"
checkStatus $? "download failed"

# unpack
tar -zxf "openssl.tar.gz"
checkStatus $? "unpack failed"
cd "openssl-$VERSION/"
checkStatus $? "change directory failed"

# prepare build
# use custom lib path, because for any reason on linux amd64 installs otherwise in lib64 instead
./config --prefix="$TOOL_DIR" --openssldir="$TOOL_DIR/openssl" --libdir="$TOOL_DIR/lib" no-shared
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
## install without documentation
make install_sw
checkStatus $? "installation failed (install_sw)"
make install_ssldirs
checkStatus $? "installation failed (install_ssldirs)"
