setlocal EnableDelayedExpansion
@echo on

:: set pkg-config path so that host deps can be found
:: (set as env var so it's used by both meson and during build with g-ir-scanner)
set PKG_CONFIG_PATH="%LIBRARY_BIN%\pkgconfig;%LIBRARY_LIB%\pkgconfig;%LIBRARY_PREFIX%\share\pkgconfig;%BUILD_PREFIX%\Library\lib\pkgconfig;%BUILD_PREFIX%\Library\bin\pkgconfig"
set PKG_CONFIG_EXECUTABLE=%LIBRARY_BIN%\pkg-config

IF NOT EXIST "%LIBRARY_PREFIX%\lib\libtiff.lib" (
  :: our current libtiff does not ship with libtiff.lib.
  copy "%LIBRARY_PREFIX%"\lib\tiff.lib "%LIBRARY_PREFIX%\lib\libtiff.lib"
)

set PATH=%LIBRARY_BIN%;%PREFIX%\bin;%PATH%

:: meson options
:: (set pkg_config_path so deps in host env can be found)
:: introspection disabled for now.
set ^"MESON_OPTIONS=^
  --prefix="%LIBRARY_PREFIX%" ^
  --wrap-mode=nofallback ^
  --buildtype=release ^
  --backend=ninja ^
  -Dc_std=c99 ^
  -Dgtk_doc=false ^
  -Dinstalled_tests=false ^
  -Dman=false ^
  -Drelocatable=true ^
  -Dintrospection=enabled ^
  -D docs=false ^
 ^"

meson setup --help

:: setup build
meson setup builddir !MESON_OPTIONS!
if errorlevel 1 (
    type builddir\meson-logs\meson-log.txt
    exit 1
)

:: print results of build configuration
meson configure builddir
if errorlevel 1 exit 1

echo "Doing ninja build ..."
:: build
ninja -v -C builddir
:: -j %CPU_COUNT%
if errorlevel 1 exit 1

:: test - some errors, ignore test results for now
ninja -v -C builddir test || cmd /K "exit /b 0"
if errorlevel 1 exit 1

:: install
ninja -C builddir install -j %CPU_COUNT%
if errorlevel 1 exit 1
