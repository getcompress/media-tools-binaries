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

# download source — fossils holds older releases; fall back to primary URL for new ones
download https://www.zlib.net/fossils/zlib-$VERSION.tar.gz "zlib.tar.gz"
if [ $? -ne 0 ]; then
    echo "fossils download failed; trying primary zlib.net URL"
    download https://www.zlib.net/zlib-$VERSION.tar.gz "zlib.tar.gz"
    checkStatus $? "download failed"
fi

# unpacking
tar -zxf "zlib.tar.gz"
checkStatus $? "unpacking failed"
cd "zlib-$VERSION/"
checkStatus $? "change directory failed"

if isMsys; then
	echo "run windows specific build"

	ZLIB_CC="$(command -v gcc 2> /dev/null || command -v clang 2> /dev/null)"
	if [ -z "$ZLIB_CC" ]; then
		echo "no suitable C compiler found for Windows zlib build"
		exit 1
	fi
	ZLIB_AR="$(command -v ar 2> /dev/null || command -v llvm-ar 2> /dev/null)"
	if [ -z "$ZLIB_AR" ]; then
		echo "no suitable archiver found for Windows zlib build"
		exit 1
	fi

	echo "use CC=$ZLIB_CC"
	echo "use AR=$ZLIB_AR"

	# build the static archive only; FFmpeg links against libz.a and this avoids
	# the extra shared/example targets from win32/Makefile.gcc.
	make -j $CPUS -f win32/Makefile.gcc libz.a CC="$ZLIB_CC" AR="$ZLIB_AR"
	checkStatus $? "build failed"

	# install
	make -j $CPUS -f win32/Makefile.gcc install CC="$ZLIB_CC" AR="$ZLIB_AR" INCLUDE_PATH=$TOOL_DIR/include LIBRARY_PATH=$TOOL_DIR/lib BINARY_PATH=$TOOL_DIR/bin
	checkStatus $? "installation failed"

	# win32/Makefile.gcc does not install a pkg-config file; create one so that
	# Rust crates (e.g. libz-sys used by rav1e) can find zlib via pkg-config
	# instead of falling back to bundled C source compilation.
	mkdir -p "$TOOL_DIR/lib/pkgconfig"
	ZLIB_VER=$(sed -n 's/^#define ZLIB_VERSION "\(.*\)"/\1/p' "$TOOL_DIR/include/zlib.h" | head -1)
	cat > "$TOOL_DIR/lib/pkgconfig/zlib.pc" << PCEOF
prefix=$TOOL_DIR
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: zlib
Description: zlib compression library
Version: ${ZLIB_VER}
Libs: -L\${libdir} -lz
Cflags: -I\${includedir}
PCEOF
	checkStatus $? "create zlib.pc failed"
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
