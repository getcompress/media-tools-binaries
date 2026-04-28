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
VERSION=$(cat "$SCRIPT_DIR/../version/libbluray")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "libbluray"
checkStatus $? "create directory failed"
cd "libbluray/"
checkStatus $? "change directory failed"

# download source
download https://download.videolan.org/pub/videolan/libbluray/$VERSION/libbluray-$VERSION.tar.bz2 "libbluray.tar.bz2"
checkStatus $? "download failed"

# unpack
bunzip2 "libbluray.tar.bz2"
checkStatus $? "unpack failed (bunzip2)"
tar -xf "libbluray.tar"
checkStatus $? "unpack failed (tar)"
cd "libbluray-$VERSION/"
checkStatus $? "change directory failed"

# prepare build
appendFlag CPPFLAGS "-Ddec_init=libbluray_dec_init"
appendFlag CPPFLAGS "-I${TOOL_DIR}/include"
appendFlag LDFLAGS "-L${TOOL_DIR}/lib"
export PKG_CONFIG_PATH="${TOOL_DIR}/lib/pkgconfig"
./configure --prefix="$TOOL_DIR" --enable-shared=no --disable-bdjava-jar
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
make install
checkStatus $? "installation failed"

# static pkg-config resolution on macOS needs the private dependency chain.
LIBBLURAY_PC="$TOOL_DIR/lib/pkgconfig/libbluray.pc"
if [ -f "$LIBBLURAY_PC" ]; then
    if grep -q '^Requires.private:' "$LIBBLURAY_PC"; then
        sed -i.original -e 's/^Requires.private:.*/& freetype2 fontconfig libxml-2.0/' "$LIBBLURAY_PC"
        checkStatus $? "modify libbluray pkg-config requires failed"
    else
        printf '\nRequires.private: freetype2 fontconfig libxml-2.0\n' >> "$LIBBLURAY_PC"
        checkStatus $? "append libbluray pkg-config requires failed"
    fi

    if [ "$(uname)" = "Darwin" ]; then
        if grep -q '^Libs.private:' "$LIBBLURAY_PC"; then
            sed -i.original -e 's/^Libs.private:.*/& -liconv/' "$LIBBLURAY_PC"
            checkStatus $? "modify libbluray pkg-config private libs failed"
        else
            printf 'Libs.private: -liconv\n' >> "$LIBBLURAY_PC"
            checkStatus $? "append libbluray pkg-config private libs failed"
        fi
    fi
fi
