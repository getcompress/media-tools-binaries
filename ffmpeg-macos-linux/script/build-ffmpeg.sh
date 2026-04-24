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
OUT_DIR=$4
CPUS=$5
FFMPEG_SNAPSHOT=$6
FFMPEG_LIB_FLAGS=$7
FFMPEG_EXTRA_VERSION=$8

# load functions
. $SCRIPT_DIR/functions.sh

# version
if [ $FFMPEG_SNAPSHOT = "YES" ]; then
    VERSION="snapshot"
else
    # load version
    VERSION=$(cat "$SCRIPT_DIR/../version/ffmpeg")
    checkStatus $? "load version failed"
fi
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "ffmpeg"
checkStatus $? "create directory failed"
cd "ffmpeg/"
checkStatus $? "change directory failed"

# download ffmpeg source
download https://ffmpeg.org/releases/ffmpeg-$VERSION.tar.bz2 "ffmpeg.tar.bz2"
checkStatus $? "ffmpeg download failed"

# unpack ffmpeg
mkdir "ffmpeg"
checkStatus $? "create directory failed"
bunzip2 "ffmpeg.tar.bz2"
checkStatus $? "unpack failed (bunzip2)"
tar -xf ffmpeg.tar -C ffmpeg --strip-components=1
checkStatus $? "unpack failed (tar)"
cd "ffmpeg/"
checkStatus $? "change directory failed"

# prepare build
EXTRA_VERSION="https://www.martin-riedl.de"
if [ -n "$FFMPEG_EXTRA_VERSION" ]; then
    EXTRA_VERSION="$FFMPEG_EXTRA_VERSION"
fi
appendFlag LDFLAGS "-L${TOOL_DIR}/lib"
appendFlag CPPFLAGS "-I${TOOL_DIR}/include"

FFMPEG_CONFIGURE_FLAGS="--disable-autodetect --enable-zlib --enable-iconv --disable-lzma --disable-libxcb --disable-xlib --disable-sdl2"
if [ "$(uname)" = "Darwin" ]; then
    FFMPEG_CONFIGURE_FLAGS="$FFMPEG_CONFIGURE_FLAGS --enable-bzlib --enable-securetransport --enable-audiotoolbox --enable-videotoolbox --enable-avfoundation --enable-coreimage --enable-metal --enable-appkit"
fi

# --pkg-config-flags="--static" is required to respect the Libs.private flags of the *.pc files
./configure --prefix="$OUT_DIR" --pkg-config="$TOOL_DIR/bin/pkg-config" --pkg-config-flags="--static" --extra-version="$EXTRA_VERSION" \
    $FFMPEG_CONFIGURE_FLAGS \
    --enable-gray --enable-libxml2 $FFMPEG_LIB_FLAGS
checkStatus $? "configuration failed"

# start build
make -j $CPUS
checkStatus $? "build failed"

# install ffmpeg
make install
checkStatus $? "installation failed"
