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
VERSION=$(cat "$SCRIPT_DIR/../version/libvorbis")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "libvorbis"
checkStatus $? "create directory failed"
cd "libvorbis/"
checkStatus $? "change directory failed"

# download source
download https://ftp.osuosl.org/pub/xiph/releases/vorbis/libvorbis-$VERSION.tar.gz "libvorbis.tar.gz"
checkStatus $? "download failed"

# unpack
tar -zxf "libvorbis.tar.gz"
checkStatus $? "unpack failed"
cd "libvorbis-$VERSION/"
checkStatus $? "change directory failed"

# prepare build
./configure --prefix="$TOOL_DIR" --enable-shared=no
checkStatus $? "configuration failed"

if [ "$(uname)" = "Darwin" ]; then
    echo "remove obsolete Darwin linker flag from generated build files"
    find . \( -name Makefile -o -name libtool \) -type f -print | while read -r build_file; do
        sed -i.original -e 's/[[:space:]]-force_cpusubtype_ALL//g' "$build_file"
        checkStatus $? "remove obsolete Darwin linker flag failed"
    done
fi

# build
make -j $CPUS
checkStatus $? "build failed"

# install
make install
checkStatus $? "installation failed"
