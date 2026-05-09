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

checkStatus(){
    if [ $1 -ne 0 ]
    then
        echo "check failed: $2"
        exit 1
    fi
}

echoSection(){
    echo ""
    echo "$1"
}

currentTimeInSeconds(){
    TIME_GDATE=$(date +%s)
    if [ $? -eq 0 ]
    then
        echo $TIME_GDATE
    else
        echo 0
    fi
}

echoDurationInSections(){
    END_TIME=$(currentTimeInSeconds)
    echo "took $(($END_TIME - $1))s"
}

download(){
    URL=$1
    NAME=$2
    curl -o "$NAME" -L -f "$URL"
}

appendFlag(){
    VAR_NAME=$1
    FLAG=$2
    eval "CURRENT_VALUE=\${$VAR_NAME}"
    if [ -n "$CURRENT_VALUE" ]; then
        eval "$VAR_NAME=\"\$CURRENT_VALUE \$FLAG\""
    else
        eval "$VAR_NAME=\"\$FLAG\""
    fi
    export "$VAR_NAME"
}

isMsys(){
    [ "$(uname -o 2> /dev/null)" = "Msys" ]
}

windowsToolchainPrefix(){
    if ! isMsys; then
        return 1
    fi

    if [ -n "${MINGW_PREFIX:-}" ] && [ -d "$MINGW_PREFIX" ]; then
        printf '%s\n' "$MINGW_PREFIX"
        return
    fi

    TOOLCHAIN_CC=$(command -v gcc 2> /dev/null || command -v clang 2> /dev/null)
    if [ -z "$TOOLCHAIN_CC" ]; then
        return 1
    fi

    dirname "$(dirname "$TOOLCHAIN_CC")"
}

windowsArTool(){
    command -v ar 2> /dev/null || command -v llvm-ar 2> /dev/null
}

windowsRanlibTool(){
    command -v ranlib 2> /dev/null || command -v llvm-ranlib 2> /dev/null
}

printArchiveMembers(){
    ARCHIVE=$1
    AR_TOOL=$(windowsArTool)
    if [ -z "$AR_TOOL" ] || [ ! -f "$ARCHIVE" ]; then
        return
    fi

    echo "archive members: $ARCHIVE"
    "$AR_TOOL" t "$ARCHIVE" | sed -n '1,20p'
}

copyStaticArchiveOverImportLib(){
    SOURCE_ARCHIVE=$1
    TARGET_ARCHIVE=$2

    if [ ! -f "$SOURCE_ARCHIVE" ]; then
        echo "missing static archive for neutralization: $SOURCE_ARCHIVE"
        return 1
    fi

    echo "neutralize $TARGET_ARCHIVE <- $SOURCE_ARCHIVE"
    rm -f "$TARGET_ARCHIVE"
    checkStatus $? "remove runtime import library failed"
    cp -f "$SOURCE_ARCHIVE" "$TARGET_ARCHIVE"
    checkStatus $? "copy static archive over import library failed"
    chmod a+r "$TARGET_ARCHIVE"
    checkStatus $? "chmod neutralized import library failed"
    printArchiveMembers "$TARGET_ARCHIVE"
}

copyStaticArchiveOverImportLibIfPresent(){
    SOURCE_ARCHIVE=$1
    TARGET_ARCHIVE=$2

    if [ ! -f "$TARGET_ARCHIVE" ]; then
        echo "skip neutralize $TARGET_ARCHIVE; target not present"
        return
    fi

    copyStaticArchiveOverImportLib "$SOURCE_ARCHIVE" "$TARGET_ARCHIVE"
}

copyStaticArchiveOverImportLibsUnderPrefix(){
    PREFIX=$1
    SOURCE_NAME=$2
    TARGET_NAME=$3
    REQUIRED=$4
    CANDIDATE_LIST=$(mktemp 2> /dev/null || mktemp -t ffmpeg-import-libs)
    checkStatus $? "create import library candidate list failed"

    find "$PREFIX" \( -type f -o -type l \) -name "$TARGET_NAME" -print > "$CANDIDATE_LIST"
    checkStatus $? "collect import library candidates failed"

    if [ ! -s "$CANDIDATE_LIST" ]; then
        rm -f "$CANDIDATE_LIST"
        checkStatus $? "remove import library candidate list failed"
        if [ "$REQUIRED" = "required" ]; then
            copyStaticArchiveOverImportLib "$PREFIX/lib/$SOURCE_NAME" "$PREFIX/lib/$TARGET_NAME"
        else
            echo "skip neutralize $TARGET_NAME; target not present under $PREFIX"
        fi
        return
    fi

    while IFS= read -r TARGET_ARCHIVE
    do
        SOURCE_ARCHIVE="$(dirname "$TARGET_ARCHIVE")/$SOURCE_NAME"
        if [ ! -f "$SOURCE_ARCHIVE" ]; then
            SOURCE_ARCHIVE="$PREFIX/lib/$SOURCE_NAME"
        fi
        copyStaticArchiveOverImportLib "$SOURCE_ARCHIVE" "$TARGET_ARCHIVE"
    done < "$CANDIDATE_LIST"

    rm -f "$CANDIDATE_LIST"
    checkStatus $? "remove import library candidate list failed"
}

replaceLibgccSWithStaticArchive(){
    PREFIX=$1

    GCC_LIBGCC=$(gcc -print-libgcc-file-name)
    checkStatus $? "locate libgcc.a failed"
    GCC_LIB_DIR=$(dirname "$GCC_LIBGCC")
    GCC_LIBGCC_EH="$GCC_LIB_DIR/libgcc_eh.a"
    TARGET_ARCHIVE="$PREFIX/lib/libgcc_s.a"
    BUILD_DIR="$PREFIX/lib"
    TMP_ARCHIVE_NAME="libgcc_s.a.static-tmp"
    TMP_ARCHIVE="$BUILD_DIR/$TMP_ARCHIVE_NAME"
    MRI_SCRIPT="$BUILD_DIR/libgcc_s.a.mri"
    CANDIDATE_LIST=$(mktemp 2> /dev/null || mktemp -t ffmpeg-libgcc-s)
    checkStatus $? "create libgcc_s candidate list failed"
    AR_TOOL=$(windowsArTool)
    RANLIB_TOOL=$(windowsRanlibTool)

    if [ -z "$AR_TOOL" ]; then
        echo "ar is required to rebuild static libgcc_s.a"
        return 1
    fi
    if [ -z "$RANLIB_TOOL" ]; then
        echo "ranlib is required to rebuild static libgcc_s.a"
        return 1
    fi
    if [ ! -f "$GCC_LIBGCC" ]; then
        echo "missing static libgcc archive: $GCC_LIBGCC"
        return 1
    fi
    if [ ! -f "$GCC_LIBGCC_EH" ]; then
        echo "missing static libgcc_eh archive: $GCC_LIBGCC_EH"
        return 1
    fi

    if [ "$(dirname "$GCC_LIBGCC")" = "$BUILD_DIR" ]; then
        MRI_LIBGCC=$(basename "$GCC_LIBGCC")
    else
        MRI_LIBGCC=$(cygpath -m "$GCC_LIBGCC")
        checkStatus $? "convert libgcc path for ar MRI failed"
    fi
    if [ "$(dirname "$GCC_LIBGCC_EH")" = "$BUILD_DIR" ]; then
        MRI_LIBGCC_EH=$(basename "$GCC_LIBGCC_EH")
    else
        MRI_LIBGCC_EH=$(cygpath -m "$GCC_LIBGCC_EH")
        checkStatus $? "convert libgcc_eh path for ar MRI failed"
    fi

    find "$PREFIX" \( -type f -o -type l \) -name "libgcc_s.a" -print > "$CANDIDATE_LIST"
    checkStatus $? "collect libgcc_s candidates failed"
    if [ ! -s "$CANDIDATE_LIST" ]; then
        printf '%s\n' "$TARGET_ARCHIVE" > "$CANDIDATE_LIST"
        checkStatus $? "create default libgcc_s candidate failed"
    fi

    rm -f "$TMP_ARCHIVE" "$MRI_SCRIPT"
    cat > "$MRI_SCRIPT" <<EOF
CREATE $TMP_ARCHIVE_NAME
ADDLIB $MRI_LIBGCC_EH
ADDLIB $MRI_LIBGCC
SAVE
END
EOF

    echo "ar MRI working directory: $BUILD_DIR"
    echo "ar MRI temporary archive: $TMP_ARCHIVE_NAME"
    echo "ar MRI ADDLIB libgcc_eh: $MRI_LIBGCC_EH"
    echo "ar MRI ADDLIB libgcc: $MRI_LIBGCC"
    echo "ar MRI script:"
    cat "$MRI_SCRIPT"

    (cd "$BUILD_DIR" && "$AR_TOOL" -M < "$MRI_SCRIPT")
    checkStatus $? "rebuild static libgcc_s.a failed"
    rm -f "$MRI_SCRIPT"
    checkStatus $? "remove libgcc_s MRI script failed"

    while IFS= read -r TARGET_ARCHIVE
    do
        echo "neutralize $TARGET_ARCHIVE <- $GCC_LIBGCC_EH + $GCC_LIBGCC"
        rm -f "$TARGET_ARCHIVE"
        checkStatus $? "remove libgcc_s import library failed"
        cp -f "$TMP_ARCHIVE" "$TARGET_ARCHIVE"
        checkStatus $? "replace libgcc_s.a with static archive failed"
        "$RANLIB_TOOL" "$TARGET_ARCHIVE"
        checkStatus $? "index static libgcc_s.a failed"
        chmod a+r "$TARGET_ARCHIVE"
        checkStatus $? "chmod static libgcc_s.a failed"
        printArchiveMembers "$TARGET_ARCHIVE"
    done < "$CANDIDATE_LIST"

    rm -f "$TMP_ARCHIVE" "$CANDIDATE_LIST"
    checkStatus $? "remove libgcc_s temporary files failed"
}

removeWindowsImportLibraries(){
    PREFIX=$1

    find "$PREFIX" \( -type f -o -type l \) -name 'libclang_rt*.dll.a' -print -exec rm -f {} \;
    checkStatus $? "remove clang runtime import libraries failed"
}

printWindowsRuntimeLibraryState(){
    PREFIX=$1

    echo "remaining Windows runtime-sensitive libraries under $PREFIX:"
    find "$PREFIX" \
        \( -name 'libwinpthread.a' -o -name 'libwinpthread.dll.a' \
        -o -name 'libpthread.a' -o -name 'libpthread.dll.a' \
        -o -name 'libstdc++.a' -o -name 'libstdc++.dll.a' \
        -o -name 'libgcc*.a' \
        -o -name 'libc++.a' -o -name 'libc++.dll.a' \
        -o -name 'libc++abi.a' -o -name 'libc++abi.dll.a' \
        -o -name 'libunwind.a' -o -name 'libunwind.dll.a' \
        -o -name 'libiconv.a' -o -name 'libiconv.dll.a' \
        -o -name 'libcharset.a' -o -name 'libcharset.dll.a' \
        -o -name 'libclang_rt*.a' \) -print | sort || true
}

neutralizeWindowsToolchainImportLibs(){
    if ! isMsys; then
        return
    fi

    PREFIX=$(windowsToolchainPrefix)
    checkStatus $? "resolve Windows toolchain prefix failed"

    echo "neutralize Windows toolchain runtime import libraries in $PREFIX"

    if [ "${MSYSTEM:-}" = "CLANGARM64" ]; then
        copyStaticArchiveOverImportLibsUnderPrefix "$PREFIX" "libc++.a" "libc++.dll.a" "required"
        copyStaticArchiveOverImportLibsUnderPrefix "$PREFIX" "libc++abi.a" "libc++abi.dll.a" "required"
        copyStaticArchiveOverImportLibsUnderPrefix "$PREFIX" "libunwind.a" "libunwind.dll.a" "required"
    else
        copyStaticArchiveOverImportLibsUnderPrefix "$PREFIX" "libstdc++.a" "libstdc++.dll.a" "required"
        replaceLibgccSWithStaticArchive "$PREFIX"
    fi

    copyStaticArchiveOverImportLib "$PREFIX/lib/libwinpthread.a" "$PREFIX/lib/libwinpthread.dll.a"
    copyStaticArchiveOverImportLib "$PREFIX/lib/libwinpthread.a" "$PREFIX/lib/libpthread.a"
    copyStaticArchiveOverImportLib "$PREFIX/lib/libwinpthread.a" "$PREFIX/lib/libpthread.dll.a"
    copyStaticArchiveOverImportLibIfPresent "$PREFIX/lib/libiconv.a" "$PREFIX/lib/libiconv.dll.a"
    copyStaticArchiveOverImportLibIfPresent "$PREFIX/lib/libcharset.a" "$PREFIX/lib/libcharset.dll.a"
    removeWindowsImportLibraries "$PREFIX"
    printWindowsRuntimeLibraryState "$PREFIX"

    echo "Windows toolchain runtime import libs neutralized"
}

windowsStaticRuntimeExtraLibs(){
    if ! isMsys; then
        return 1
    fi

    if [ "${MSYSTEM:-}" = "CLANGARM64" ]; then
        printf '%s\n' "-Wl,-Bstatic -Wl,--start-group -lc++ -lc++abi -lunwind -lwinpthread -Wl,--end-group -Wl,-Bdynamic"
    else
        printf '%s\n' "-Wl,-Bstatic -Wl,--start-group -lstdc++ -lgcc_eh -lgcc -lwinpthread -Wl,--end-group -Wl,-Bdynamic"
    fi
}

windowsStaticRuntimeLdFlags(){
    WINDOWS_STATIC_RUNTIME_EXTRA_LIBS=$(windowsStaticRuntimeExtraLibs) || return 1

    if [ "${MSYSTEM:-}" = "CLANGARM64" ]; then
        printf '%s\n' "-static $WINDOWS_STATIC_RUNTIME_EXTRA_LIBS"
    else
        printf '%s\n' "-static -static-libgcc -static-libstdc++ $WINDOWS_STATIC_RUNTIME_EXTRA_LIBS"
    fi
}

applyTargetEnv(){
    if [ "$(uname)" != "Darwin" ]; then
        return
    fi

    appendFlag LDFLAGS "-Wl,-search_paths_first"

    if [ -n "$TARGET_ARCH" ]; then
        appendFlag CFLAGS "-arch $TARGET_ARCH"
        appendFlag CXXFLAGS "-arch $TARGET_ARCH"
        appendFlag OBJCFLAGS "-arch $TARGET_ARCH"
        appendFlag OBJCXXFLAGS "-arch $TARGET_ARCH"
        appendFlag LDFLAGS "-arch $TARGET_ARCH"
    fi

    if [ -n "$MACOSX_DEPLOYMENT_TARGET" ]; then
        appendFlag CFLAGS "-mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET"
        appendFlag CXXFLAGS "-mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET"
        appendFlag OBJCFLAGS "-mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET"
        appendFlag OBJCXXFLAGS "-mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET"
        appendFlag LDFLAGS "-mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET"
        export MACOSX_DEPLOYMENT_TARGET
    fi
}

cmakeTargetArgs(){
    if [ "$(uname)" != "Darwin" ]; then
        return
    fi

    if [ -n "$TARGET_ARCH" ]; then
        printf '%s ' "-DCMAKE_OSX_ARCHITECTURES=$TARGET_ARCH"
    fi
    if [ -n "$MACOSX_DEPLOYMENT_TARGET" ]; then
        printf '%s ' "-DCMAKE_OSX_DEPLOYMENT_TARGET=$MACOSX_DEPLOYMENT_TARGET"
    fi
}

cmakePolicyCompatArgs(){
    SRT_CMAKE_POLICY_MINIMUM_VERSION="3.5"

    command -v cmake > /dev/null 2>&1 || return
    CMAKE_MAJOR_VERSION=$(cmake --version | head -n 1 | sed -n 's/cmake version \([0-9]\+\).*/\1/p')
    [ -n "$CMAKE_MAJOR_VERSION" ] || return

    if [ "$CMAKE_MAJOR_VERSION" -ge 4 ]; then
        # CMake 4 drops compatibility for projects declaring a minimum below 3.5.
        printf '%s' "-DCMAKE_POLICY_VERSION_MINIMUM=$SRT_CMAKE_POLICY_MINIMUM_VERSION"
    fi
}

cmakeBuild(){
    cmake --build . --parallel "$1"
}

cmakeInstall(){
    cmake --install .
}

useToolPkgConfig(){
    TOOL_DIR=$1

    export PKG_CONFIG="${TOOL_DIR}/bin/pkg-config"
    export PKG_CONFIG_LIBDIR="${TOOL_DIR}/lib/pkgconfig:${TOOL_DIR}/share/pkgconfig"
    unset PKG_CONFIG_PATH

    export CMAKE_PREFIX_PATH="$TOOL_DIR"
}

verifyToolPkgConfigModule(){
    TOOL_DIR=$1
    MODULE_NAME=$2

    PKG_CONFIG_BIN="${TOOL_DIR}/bin/pkg-config"
    if [ ! -x "$PKG_CONFIG_BIN" ]; then
        echo "pkg-config was not prepared at $PKG_CONFIG_BIN"
        return 1
    fi

    PKG_CONFIG_LIBDIR="${TOOL_DIR}/lib/pkgconfig:${TOOL_DIR}/share/pkgconfig" \
        "$PKG_CONFIG_BIN" --exists "$MODULE_NAME"
}

pruneToolDynamicLibraries(){
    TOOL_DIR=$1

    if [ "$(uname)" != "Darwin" ]; then
        return
    fi

    if [ ! -d "${TOOL_DIR}/lib" ]; then
        return
    fi

    find "${TOOL_DIR}/lib" -type f \( -name "*.dylib" -o -name "*.so" -o -name "*.so.*" \) -print -exec rm -f {} \;
}

pruneHomebrewDynamicLibraries(){
    if [ "$(uname)" != "Darwin" ]; then
        return
    fi

    if [ "$ALLOW_PRUNE_HOMEBREW_DYLIBS" != "YES" ]; then
        echo "skip Homebrew dylib pruning"
        return
    fi

    for BREW_OPT_DIR in /usr/local/opt /opt/homebrew/opt
    do
        if [ ! -d "$BREW_OPT_DIR" ]; then
            continue
        fi

        for FORMULA in gettext libpng xz libx11
        do
            if [ ! -d "$BREW_OPT_DIR/$FORMULA/lib" ]; then
                continue
            fi

            find -L "$BREW_OPT_DIR/$FORMULA/lib" -maxdepth 1 -name "*.dylib" \( -type f -o -type l \) -print | while IFS= read -r DYLIB
            do
                DYLIB_DIR=$(dirname "$DYLIB")
                DYLIB_NAME=$(basename "$DYLIB")
                STATIC_ARCHIVE="${DYLIB_DIR}/${DYLIB_NAME%%.*}.a"

                if [ -f "$STATIC_ARCHIVE" ]; then
                    echo "$DYLIB"
                    rm -f "$DYLIB"
                else
                    echo "keep $DYLIB; no matching static archive at $STATIC_ARCHIVE"
                fi
            done
        done
    done

    for BREW_LIB_DIR in /usr/local/lib /opt/homebrew/lib
    do
        if [ ! -d "$BREW_LIB_DIR" ]; then
            continue
        fi

        find "$BREW_LIB_DIR" -maxdepth 1 \( \
            -name "libintl*.dylib" -o \
            -name "libpng*.dylib" -o \
            -name "liblzma*.dylib" -o \
            -name "libX11*.dylib" \
        \) \( -type f -o -type l \) -print | while IFS= read -r DYLIB
        do
            DYLIB_DIR=$(dirname "$DYLIB")
            DYLIB_NAME=$(basename "$DYLIB")
            STATIC_ARCHIVE="${DYLIB_DIR}/${DYLIB_NAME%%.*}.a"

            if [ -f "$STATIC_ARCHIVE" ]; then
                echo "$DYLIB"
                rm -f "$DYLIB"
            else
                echo "keep $DYLIB; no matching static archive at $STATIC_ARCHIVE"
            fi
        done
    done
}

validateToolLinkageMetadata(){
    TOOL_DIR=$1

    if [ "$(uname)" != "Darwin" ]; then
        return
    fi

    if [ ! -d "$TOOL_DIR" ]; then
        return
    fi

    HOST_LINKAGE_MATCHES=$(
        find "$TOOL_DIR" -type f \( -name "*.pc" -o -name "*.la" \) \
            -exec grep -nE '(/usr/local/opt|/opt/homebrew/opt|/usr/local/Cellar|/opt/homebrew/Cellar|\.dylib)' {} + 2> /dev/null
    )

    if [ -n "$HOST_LINKAGE_MATCHES" ]; then
        echo "tool metadata contains host-specific or dynamic linkage:"
        echo "$HOST_LINKAGE_MATCHES"
        return 1
    fi
}

findConfigAuxFile(){
    FILE_NAME=$1

    for CANDIDATE in \
        /usr/share/automake*/$FILE_NAME \
        /usr/share/libtool/build-aux/$FILE_NAME \
        /opt/homebrew/Cellar/libtool/*/share/libtool/build-aux/$FILE_NAME \
        /usr/local/Cellar/libtool/*/share/libtool/build-aux/$FILE_NAME
    do
        if [ -f "$CANDIDATE" ]; then
            echo "$CANDIDATE"
            return 0
        fi
    done

    return 1
}

refreshConfigAuxFiles(){
    TARGET_DIR=$1

    CONFIG_GUESS_SOURCE=$(findConfigAuxFile "config.guess")
    checkStatus $? "find config.guess failed"
    CONFIG_SUB_SOURCE=$(findConfigAuxFile "config.sub")
    checkStatus $? "find config.sub failed"

    cp "$CONFIG_GUESS_SOURCE" "$TARGET_DIR/config.guess"
    checkStatus $? "copy config.guess failed"
    cp "$CONFIG_SUB_SOURCE" "$TARGET_DIR/config.sub"
    checkStatus $? "copy config.sub failed"
    chmod +x "$TARGET_DIR/config.guess" "$TARGET_DIR/config.sub"
    checkStatus $? "chmod config.guess/config.sub failed"
}

prepareMeson(){
    # On Windows/MSYS2 the venv activate path differs (Scripts/ vs bin/) and
    # pip-installed meson doesn't integrate cleanly; use the pacman-provided
    # meson instead and skip the virtualenv machinery entirely.
    if isMsys; then
        MESON_VERSION=$(meson -v 2>/dev/null)
        if [ -n "$MESON_VERSION" ]; then
            echo "using system meson $MESON_VERSION"
            return 0
        fi
        echo "meson not found in PATH; install it via MSYS2 pacman (e.g. mingw-w64-x86_64-meson)"
        exit 1
    fi

    python3 -m virtualenv .venv
    if [ $? -ne 0 ]; then
        echo "python virtualenv module not available, try built-in venv"
        python3 -m venv .venv
    fi

    if [ $? -ne 0 ]; then
        echo "python create virtual environment failed"

        # check, if meson is natively available
        MESON_VERSION=$(meson -v 2> /dev/null)
        checkStatus $? "meson was also not found: please install python correctly with virtualenv"
        echo "using meson $MESON_VERSION"
    else
        . .venv/bin/activate
        checkStatus $? "python activate virtual environment failed"
        pip install meson
        checkStatus $? "python meson installation failed"
    fi
}
