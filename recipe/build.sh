#!/bin/bash

set -xeo pipefail

if [[ "$(uname)" = Darwin ]] ; then
    # The -dead_strip_dylibs option breaks g-ir-scanner in this package: the
    # scanner links a test executable to find paths to dylibs, but with this
    # option the linker strips them out. The resulting error message is
    # "ERROR: can't resolve libraries to shared libraries: ...".
    export LDFLAGS="$(echo $LDFLAGS |sed -e "s/-Wl,-dead_strip_dylibs//g")"
    export LDFLAGS_LD="$(echo $LDFLAGS_LD |sed -e "s/-dead_strip_dylibs//g")"
fi

# Needed for jpeg on Linux/GCC7:
export CPPFLAGS="$CPPFLAGS -I$PREFIX/include"

meson_options_common=(
    --buildtype=release
    --prefix="$PREFIX"
    --backend=ninja
    -Ddocs=false
    -Dgio_sniffing=false
    -Dinstalled_tests=false
    -Dlibdir=lib
    -Drelocatable=true
    -Dintrospection=enabled
)

meson_options_build=("${meson_options_common[@]}")
meson_options_host=("${meson_options_common[@]}")

if [[ ${target_platform} == osx-* ]] || [[ ${target_platform} == linux-aarch64 ]] ; then
    # Disable X11 since our default Mac environment doesn't provide it (and
    # apparently the build scripts assume that it will be there).
    #
    # Disable manpages since the macOS xsltproc doesn't want to load
    # docbook.xsl remotely in --nonet mode.

    # Also disable X11 if building for linux-aarch64.
    meson_options_host+=(-Dx11=false -Dman=false)
fi

if [[ "$build_platform" == osx-* ]] ; then
    meson_options_build+=(-Dx11=false -Dman=false)
fi

mkdir forgebuild
cd forgebuild

export PKG_CONFIG="$BUILD_PREFIX/bin/pkg-config"
export PKG_CONFIG_PATH_FOR_BUILD="$BUILD_PREFIX/lib/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:$PREFIX/lib/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:$BUILD_PREFIX/lib/pkgconfig"

meson "${meson_options_host[@]}" ${MESON_ARGS} --prefix=$PREFIX .. 
ninja -j$CPU_COUNT -v
ninja install

cd $PREFIX
rm -rf share/gtk-doc
find . -name '*.la' -delete
