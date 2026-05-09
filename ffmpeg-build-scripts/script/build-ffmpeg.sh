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

FFMPEG_CONFIGURE_FLAGS="--disable-autodetect --enable-zlib --disable-lzma --disable-libxcb --disable-xlib --disable-sdl2"
FFMPEG_LDEXEFLAGS=""
FFMPEG_EXTRA_LIBS=""
FFMPEG_TOOLCHAIN_FLAGS=""

if isMsys; then
    FFMPEG_CONFIGURE_FLAGS="$FFMPEG_CONFIGURE_FLAGS --target-os=mingw32 --enable-w32threads"
    if [ -n "$FFMPEG_ARCH" ]; then
        FFMPEG_CONFIGURE_FLAGS="$FFMPEG_CONFIGURE_FLAGS --arch=$FFMPEG_ARCH"
    fi

    if [ "${MSYSTEM:-}" = "CLANGARM64" ]; then
        FFMPEG_CC="$(command -v clang)"
        FFMPEG_CXX="$(command -v clang++)"
        # Link with the C driver and provide static C++ runtimes explicitly.
        # clang++ can append its default C++ runtime after our flags.
        FFMPEG_LD="$FFMPEG_CC"
        FFMPEG_AR="$(command -v llvm-ar 2> /dev/null || command -v ar)"
        FFMPEG_RANLIB="$(command -v llvm-ranlib 2> /dev/null || command -v ranlib)"
        FFMPEG_NM="$(command -v llvm-nm 2> /dev/null || command -v nm)"
        FFMPEG_STRIP="$(command -v llvm-strip 2> /dev/null || command -v strip)"
        FFMPEG_WINDRES="$(command -v llvm-windres 2> /dev/null || command -v windres 2> /dev/null || true)"
    else
        FFMPEG_CC="$(command -v gcc)"
        FFMPEG_CXX="$(command -v g++)"
        # Link with the C driver and provide static C++/unwind runtimes
        # explicitly. g++ can append default runtime import libraries after
        # our flags, which reintroduces libstdc++-6.dll/libgcc_s_*.dll.
        FFMPEG_LD="$FFMPEG_CC"
        FFMPEG_AR="$(command -v ar)"
        FFMPEG_RANLIB="$(command -v ranlib)"
        FFMPEG_NM="$(command -v nm)"
        FFMPEG_STRIP="$(command -v strip)"
        FFMPEG_WINDRES="$(command -v windres 2> /dev/null || true)"
    fi

    FFMPEG_TOOLCHAIN_FLAGS="--cc=$FFMPEG_CC --cxx=$FFMPEG_CXX --ld=$FFMPEG_LD --ar=$FFMPEG_AR --ranlib=$FFMPEG_RANLIB --nm=$FFMPEG_NM --strip=$FFMPEG_STRIP"
    if [ -n "$FFMPEG_WINDRES" ]; then
        FFMPEG_TOOLCHAIN_FLAGS="$FFMPEG_TOOLCHAIN_FLAGS --windres=$FFMPEG_WINDRES"
    fi

    # Pick Windows toolchain runtimes explicitly. Without the -Bstatic bracket,
    # dependency metadata or the C++ link driver can choose import libraries
    # and leave ffmpeg.exe dependent on clean-install-missing DLLs.
    FFMPEG_EXTRA_LIBS=$(windowsStaticRuntimeExtraLibs)
    checkStatus $? "resolve Windows static runtime extra libs failed"
    FFMPEG_LDEXEFLAGS="$(windowsStaticRuntimeLdFlags) -Wl,--allow-multiple-definition -Wl,-Map,$OUT_DIR/ffmpeg-link.map"
else
    FFMPEG_CONFIGURE_FLAGS="$FFMPEG_CONFIGURE_FLAGS --enable-iconv"
fi

if [ "$(uname)" = "Darwin" ]; then
    FFMPEG_CONFIGURE_FLAGS="$FFMPEG_CONFIGURE_FLAGS --enable-bzlib --enable-securetransport --enable-audiotoolbox --enable-videotoolbox --enable-avfoundation --enable-coreimage --enable-metal --enable-appkit"
fi

# --pkg-config-flags="--static" is required to respect the Libs.private flags of the *.pc files
if [ -n "$FFMPEG_LDEXEFLAGS" ]; then
    ./configure --prefix="$OUT_DIR" --pkg-config="$TOOL_DIR/bin/pkg-config" --pkg-config-flags="--static" --extra-version="$EXTRA_VERSION" \
        --extra-ldexeflags="$FFMPEG_LDEXEFLAGS" \
        --extra-libs="$FFMPEG_EXTRA_LIBS" \
        $FFMPEG_TOOLCHAIN_FLAGS \
        $FFMPEG_CONFIGURE_FLAGS \
        --enable-gray --enable-libxml2 $FFMPEG_LIB_FLAGS
else
    ./configure --prefix="$OUT_DIR" --pkg-config="$TOOL_DIR/bin/pkg-config" --pkg-config-flags="--static" --extra-version="$EXTRA_VERSION" \
        $FFMPEG_TOOLCHAIN_FLAGS \
        $FFMPEG_CONFIGURE_FLAGS \
        --enable-gray --enable-libxml2 $FFMPEG_LIB_FLAGS
fi
checkStatus $? "configuration failed"

# start build
make -j $CPUS
checkStatus $? "build failed"

# install ffmpeg
make install
checkStatus $? "installation failed"
