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
VERSION=$(cat "$SCRIPT_DIR/../version/libxml2")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "libxml2"
checkStatus $? "create directory failed"
cd "libxml2/"
checkStatus $? "change directory failed"

# download source
VERSION_WITHOUT_PATCH=$(echo "$VERSION" | cut -d. -f1-2)
download https://download.gnome.org/sources/libxml2/$VERSION_WITHOUT_PATCH/libxml2-$VERSION.tar.xz "libxml2.tar.xz"
checkStatus $? "download failed"

# unpack
tar -xf "libxml2.tar.xz"
checkStatus $? "unpack failed"
cd "libxml2-$VERSION/"
checkStatus $? "change directory failed"

# check for pre-generated configure file
if [ -f "configure" ]; then
    echo "use existing configure file"
else
    ACLOCAL_PATH=$TOOL_DIR/share/aclocal NOCONFIGURE=YES ./autogen.sh
    checkStatus $? "autogen failed"
fi

# prepare build
LIBXML2_CONFIGURE_FLAGS="--prefix=$TOOL_DIR --enable-shared=no --without-python"
if isMsys; then
    appendFlag CPPFLAGS "-I${TOOL_DIR}/include"
    appendFlag LDFLAGS "-L${TOOL_DIR}/lib"

    LIBXML2_CONFIGURE_HELP=$(./configure --help)
    checkStatus $? "read libxml2 configure help failed"
    if printf '%s\n' "$LIBXML2_CONFIGURE_HELP" | grep -q -- '--with-iconv-prefix'; then
        LIBXML2_CONFIGURE_FLAGS="$LIBXML2_CONFIGURE_FLAGS --with-iconv-prefix=$TOOL_DIR"
    elif printf '%s\n' "$LIBXML2_CONFIGURE_HELP" | grep -Eq -- '--with-iconv.*(DIR|dir)'; then
        LIBXML2_CONFIGURE_FLAGS="$LIBXML2_CONFIGURE_FLAGS --with-iconv=$TOOL_DIR"
    elif printf '%s\n' "$LIBXML2_CONFIGURE_HELP" | grep -q -- '--with-iconv'; then
        LIBXML2_CONFIGURE_FLAGS="$LIBXML2_CONFIGURE_FLAGS --with-iconv"
    else
        echo "libxml2 configure does not expose an iconv option"
        exit 1
    fi
fi

./configure $LIBXML2_CONFIGURE_FLAGS
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
make install
checkStatus $? "installation failed"
