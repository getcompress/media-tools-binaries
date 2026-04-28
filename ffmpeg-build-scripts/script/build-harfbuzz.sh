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
VERSION=$(cat "$SCRIPT_DIR/../version/harfbuzz")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "harfbuzz"
checkStatus $? "create directory failed"
cd "harfbuzz/"
checkStatus $? "change directory failed"

# download source
download https://github.com/harfbuzz/harfbuzz/releases/download/$VERSION/harfbuzz-$VERSION.tar.xz "harfbuzz.tar.xz"
checkStatus $? "download failed"

# unpack
tar -xf "harfbuzz.tar.xz"
checkStatus $? "unpack failed"

# prepare python3 virtual environment / meson
prepareMeson

# prepare build
cd "harfbuzz-$VERSION/"
checkStatus $? "change directory failed"
meson build --prefix "$TOOL_DIR" --libdir=lib --default-library=static \
    -Dglib=disabled \
    -Dgobject=disabled \
    -Dcairo=disabled \
    -Dchafa=disabled \
    -Dicu=disabled \
    -Dgraphite2=disabled \
    -Dfreetype=enabled \
    -Dfontations=disabled \
    -Dgdi=disabled \
    -Ddirectwrite=disabled \
    -Dcoretext=disabled \
    -Dharfrust=disabled \
    -Dkbts=disabled \
    -Dwasm=disabled \
    -Draster=disabled \
    -Dvector=disabled \
    -Dsubset=disabled \
    -Dtests=disabled \
    -Dintrospection=disabled \
    -Ddocs=disabled \
    -Dutilities=disabled
checkStatus $? "configuration failed"

# build
ninja -v -j $CPUS -C build
checkStatus $? "build failed"

# install
ninja -v -C build install
checkStatus $? "installation failed"
