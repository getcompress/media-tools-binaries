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
VERSION=$(cat "$SCRIPT_DIR/../version/libvmaf")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "libvmaf"
checkStatus $? "create directory failed"
cd "libvmaf/"
checkStatus $? "change directory failed"

# download source
download https://github.com/Netflix/vmaf/archive/refs/tags/v$VERSION.tar.gz "libvmaf.tar.gz"
checkStatus $? "download failed"

# unpack
tar -zxf "libvmaf.tar.gz"
checkStatus $? "unpack failed"

# prepare python3 virtual environment / meson
prepareMeson

# prepare build
cd "vmaf-$VERSION/libvmaf/"
checkStatus $? "change directory failed"
MESON_ARGS="--prefix \"$TOOL_DIR\" --libdir=lib --buildtype release --default-library static"
if isMsys; then
    MESON_ARGS="$MESON_ARGS -Denable_tests=false"
fi
eval "meson build $MESON_ARGS"
checkStatus $? "configuration failed"

# build
ninja -v -j $CPUS -C build
checkStatus $? "build failed"

# install
ninja -v -C build install
checkStatus $? "installation failed"

# post-installation
# static linking fails because c++ dependency is missing in pc file (pkg-config file)
# https://github.com/Netflix/vmaf/issues/788
sed -i.original -e 's/lvmaf/lvmaf -lstdc++/g' $TOOL_DIR/lib/pkgconfig/libvmaf.pc
checkStatus $? "modify pkg-config .pc file failed"
if isMsys; then
    sed -i.original -e 's/lvmaf -lstdc++/lvmaf -lstdc++ -lpthread/g' $TOOL_DIR/lib/pkgconfig/libvmaf.pc
    checkStatus $? "modify Windows pkg-config .pc file failed"
fi
