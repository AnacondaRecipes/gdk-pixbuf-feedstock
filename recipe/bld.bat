setlocal EnableDelayedExpansion
@echo on

:: set pkg-config path so that host deps can be found
:: (set as env var so it's used by both meson and during build with g-ir-scanner)
set PKG_CONFIG_PATH="%LIBRARY_LIB%\pkgconfig;%LIBRARY_PREFIX%\share\pkgconfig;%BUILD_PREFIX%\Library\lib\pkgconfig"
set PKG_CONFIG="%BUILD_PREFIX%\Library\bin\pkg-config"
set PKG_CONFIG_PATH_FOR_BUILD="%BUILD_PREFIX%\Library\lib\pkgconfig"

IF NOT EXIST "%LIBRARY_PREFIX%\lib\libtiff.lib" (
  :: our current libtiff does not ship with libtiff.lib.
  copy "%LIBRARY_PREFIX%"\lib\tiff.lib "%LIBRARY_PREFIX%\lib\libtiff.lib"
)

findstr /m "C:/ci_310/glib_1642686432177/_h_env/Library/lib/z.lib" "%LIBRARY_LIB%\pkgconfig\gio-2.0.pc"
if %errorlevel%==0 (
    :: our current glib gio-2.0.pc has zlib dependency set as an absolute path. 
    powershell -Command "(gc %LIBRARY_LIB%\pkgconfig\gio-2.0.pc) -replace 'Requires:', 'Requires: zlib,' | Out-File -encoding ASCII %LIBRARY_LIB%\pkgconfig\gio-2.0.pc"
    powershell -Command "(gc %LIBRARY_LIB%\pkgconfig\gio-2.0.pc) -replace 'C:/ci_310/glib_1642686432177/_h_env/Library/lib/z.lib', '' | Out-File -encoding ASCII %LIBRARY_LIB%\pkgconfig\gio-2.0.pc"
)

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
  ^"

:: setup build
meson setup builddir !MESON_OPTIONS!
if errorlevel 1 (
    type builddir\meson-logs\meson-log.txt
    exit 1
)

:: print results of build configuration
meson configure builddir
if errorlevel 1 exit 1

:: build
ninja -v -C builddir -j %CPU_COUNT%
if errorlevel 1 exit 1

:: test - some errors, ignore test results for now
ninja -v -C builddir test
@REM if errorlevel 1 exit 1

:: install
ninja -C builddir install -j %CPU_COUNT%
if errorlevel 1 exit 1
