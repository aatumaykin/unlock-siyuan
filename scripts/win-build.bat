REM ponytail: no vendored source — clone upstream, apply .patches, build.
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
for %%I in ("%SCRIPT_DIR%\..") do set "PROJECT_ROOT=%%~fI"
set "BUILD_DIR=%PROJECT_ROOT%\build\siyuan"
set "INITIAL_DIR=%cd%"

REM Read version from VERSION file (single source of truth).
for /f "tokens=2 delims==" %%V in ('findstr "UPSTREAM_VERSION" "%PROJECT_ROOT%\VERSION"') do set "UPSTREAM_VERSION=%%V"
for /f "tokens=2 delims==" %%V in ('findstr "PATCH_REVISION" "%PROJECT_ROOT%\VERSION"') do set "PATCH_REVISION=%%V"

REM Allow SIYUAN_VERSION override.
if not "%SIYUAN_VERSION%"=="" set "UPSTREAM_VERSION=%SIYUAN_VERSION%"
set "VERSION_TAG=%UPSTREAM_VERSION%-%PATCH_REVISION%"

set "TARGET=all"

echo Usage: .\win-build.bat [--target=^<target^>]
echo   --target: amd64, arm64, appx-amd64, appx-arm64, or all (default: all)
echo   Building: v%UPSTREAM_VERSION% (unlock %PATCH_REVISION%) ^> %VERSION_TAG%
echo.

:parse_args
if "%1"=="" goto :end_parse_args
if "%1"=="--target" (
    if not "%2"=="amd64" if not "%2"=="arm64" if not "%2"=="appx-amd64" if not "%2"=="appx-arm64" if not "%2"=="all" (
        echo Error: Invalid target '%2' & exit /b 1
    )
    set "TARGET=%2" & shift & shift & goto :parse_args
) else ( shift & goto :parse_args )
:end_parse_args

if "%TARGET%"=="amd64" ( set BUILD_AMD64=1 ) else if "%TARGET%"=="arm64" ( set BUILD_ARM64=1 ) ^
else if "%TARGET%"=="appx-amd64" ( set BUILD_APPX_AMD64=1 ) else if "%TARGET%"=="appx-arm64" ( set BUILD_APPX_ARM64=1 ) ^
else ( set BUILD_AMD64=1& set BUILD_ARM64=1& set BUILD_APPX_AMD64=1& set BUILD_APPX_ARM64=1 )

echo Cloning upstream and applying patches
if exist "%PROJECT_ROOT%\build" rmdir /S /Q "%PROJECT_ROOT%\build" 1>nul
git clone --branch v%UPSTREAM_VERSION% --depth=1 https://github.com/siyuan-note/siyuan.git "%BUILD_DIR%"
if errorlevel 1 ( echo Clone failed & exit /b !errorlevel! )
for %%P in ("%PROJECT_ROOT%\.patches\*.patch") do (
    git -C "%BUILD_DIR%" apply "%%P"
    if errorlevel 1 ( echo Failed to apply %%~nxP & exit /b !errorlevel! )
    echo   ✓ %%~nxP
)

echo.
echo Building UI
cd /d "%BUILD_DIR%\app"
if errorlevel 1 ( exit /b !errorlevel! )
call pnpm install & if errorlevel 1 ( exit /b !errorlevel! )
call pnpm run build & if errorlevel 1 ( exit /b !errorlevel! )

echo.
echo Building Kernel
cd /d "%BUILD_DIR%\kernel"
if errorlevel 1 ( exit /b !errorlevel! )
go version
set GO111MODULE=on
set GOPROXY=https://mirrors.aliyun.com/goproxy/
set CGO_ENABLED=1
set GOOS=windows
goversioninfo -platform-specific=true -icon=resource/icon.ico -manifest=resource/goversioninfo.exe.manifest

if defined BUILD_AMD64 (
    echo. & echo Building Kernel amd64
    set GOARCH=amd64
    go build --tags fts5 -v -o "%BUILD_DIR%\app\kernel\SiYuan-Kernel.exe" -ldflags "-s -w -H=windowsgui" .
    if errorlevel 1 ( exit /b !errorlevel! )
)
if defined BUILD_ARM64 (
    echo. & echo Building Kernel arm64
    set GOARCH=arm64
    set "CC=D:/Program Files/llvm-mingw-20240518-ucrt-x86_64/bin/aarch64-w64-mingw32-gcc.exe"
    go build --tags fts5 -v -o "%BUILD_DIR%\app\kernel-arm64\SiYuan-Kernel.exe" -ldflags "-s -w -H=windowsgui" .
    if errorlevel 1 ( exit /b !errorlevel! )
)

if defined BUILD_AMD64 goto electron
if defined BUILD_ARM64 goto electron
goto :skipelectron
:electron
echo. & echo Building Electron App
cd /d "%BUILD_DIR%\app"
if errorlevel 1 ( exit /b !errorlevel! )
if defined BUILD_AMD64 (
    echo. & echo Building Electron App amd64
    copy "%BUILD_DIR%\app\elevator\elevator-amd64.exe" "%BUILD_DIR%\app\kernel\elevator.exe"
    call pnpm run dist & if errorlevel 1 ( exit /b !errorlevel! )
)
if defined BUILD_ARM64 (
    echo. & echo Building Electron App arm64
    copy "%BUILD_DIR%\app\elevator\elevator-arm64.exe" "%BUILD_DIR%\app\kernel-arm64\elevator.exe"
    call pnpm run dist-arm64 & if errorlevel 1 ( exit /b !errorlevel! )
)
:skipelectron

if defined BUILD_APPX_AMD64 goto appx
if defined BUILD_APPX_ARM64 goto appx
goto :skipappx
:appx
echo. & echo Building Appx
cd /d "%BUILD_DIR%"
if defined BUILD_APPX_AMD64 (
    echo. & echo Building Appx amd64
    cd . > "%BUILD_DIR%\app\build\win-unpacked\resources\ms-store"
    if errorlevel 1 ( exit /b !errorlevel! )
    call electron-windows-store --input-directory "%BUILD_DIR%\app\build\win-unpacked" --output-directory "%BUILD_DIR%\app\build" --package-version 1.0.0.0 --package-name SiYuan --manifest "%BUILD_DIR%\app\appx\AppxManifest.xml" --assets "%BUILD_DIR%\app\appx\assets" --make-pri true
    rmdir /S /Q "%BUILD_DIR%\app\build\pre-appx" 1>nul
)
if defined BUILD_APPX_ARM64 (
    echo. & echo Building Appx arm64
    cd . > "%BUILD_DIR%\app\build\win-arm64-unpacked\resources\ms-store"
    if errorlevel 1 ( exit /b !errorlevel! )
    call electron-windows-store --input-directory "%BUILD_DIR%\app\build\win-arm64-unpacked" --output-directory "%BUILD_DIR%\app\build" --package-version 1.0.0.0 --package-name SiYuan-arm64 --manifest "%BUILD_DIR%\app\appx\AppxManifest-arm64.xml" --assets "%BUILD_DIR%\app\appx\assets" --make-pri true
    rmdir /S /Q "%BUILD_DIR%\app\build\pre-appx" 1>nul
)
:skipappx

echo. & echo ============================== & echo       Build successful! & echo ==============================
cd /d "%INITIAL_DIR%"
