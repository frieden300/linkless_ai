@echo off
setlocal EnableDelayedExpansion
title Linkless AI - Developer Build Script

:: ============================================================
::  Linkless AI  -  Developer Builder (build_project.bat)
::  Builds the Flutter Windows Release executable and optionally
::  downloads & links the local AI models + llama-server engine.
:: ============================================================

echo.
echo   ██╗     ██╗███╗   ██╗██╗  ██╗██╗     ███████╗███████╗███████╗
echo   ██║     ██║████╗  ██║██║ ██╔╝██║     ██╔════╝██╔════╝██╔════╝
echo   ██║     ██║██╔██╗ ██║█████╔╝ ██║     █████╗  ███████╗███████╗
echo   ██║     ██║██║╚██╗██║██╔═██╗ ██║     ██╔══╝  ╚════██║╚════██║
echo   ███████╗██║██║ ╚████║██║  ██╗███████╗███████╗███████║███████║
echo   ╚══════╝╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝╚══════╝
echo.
echo  Developer Build Script  ^|  github.com/frieden300/linkless_ai
echo  ----------------------------------------------------------------
echo.

cd /d "%~dp0"
if errorlevel 1 (
    echo [ERROR] Could not access the project directory.
    exit /b 1
)

set "ROOT=%CD%"
set "RELEASE_DIR=%ROOT%\build\windows\x64\runner\Release"
set "MODELS_DIR=%ROOT%\models"
set "ENGINE_DIR=%ROOT%\llama-cpp"
set "ENGINE=%ENGINE_DIR%\llama-server.exe"

set "LLAMA_TAG=b5616"
set "BASE_GH=https://github.com/ggml-org/llama.cpp/releases/download/%LLAMA_TAG%"

set "PRO_URL=https://huggingface.co/FriedenNT/LinkLess-AI-Pro/resolve/main/Linkless-AI-Pro-Q4_K_M.gguf"
set "VL_URL=https://huggingface.co/FriedenNT/LinkLess-AI-VL/resolve/main/Linkless-AI-VL-Q4_K_M.gguf"
set "MMPROJ_URL=https://huggingface.co/FriedenNT/mmproj-Linkless-AI-VL/resolve/main/mmproj-Linkless-AI-VL-f16.gguf"

set "DEST_PRO=%MODELS_DIR%\Linkless-AI-Pro-Q4_K_M.gguf"
set "DEST_VL=%MODELS_DIR%\Linkless-AI-VL-Q4_K_M.gguf"
set "DEST_MMPROJ=%MODELS_DIR%\mmproj-Linkless-AI-VL-f16.gguf"

echo.
echo   LINKLESS AI - DEVELOPER BUILD
echo   ============================================================
echo.
echo [INFO] Repository: %ROOT%
echo.

:: ============================================================
:: STEP 1 - Verify project files and required tools
:: ============================================================

if not exist "%ROOT%\pubspec.yaml" (
    echo [ERROR] pubspec.yaml was not found.
    echo Place build_project.bat in the Flutter project root.
    goto :error
)

where flutter >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Flutter SDK was not found in PATH.
    echo.
    echo Install Flutter and add its bin directory to PATH:
    echo https://docs.flutter.dev/get-started/install/windows/desktop
    goto :error
)

where curl >nul 2>&1
if errorlevel 1 (
    echo [ERROR] curl was not found.
    echo Use a supported Windows 10 or Windows 11 installation.
    goto :error
)

where powershell >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Windows PowerShell was not found.
    goto :error
)

echo [INFO] Checking Flutter installation...
flutter --version
if errorlevel 1 (
    echo [ERROR] Flutter could not run successfully.
    goto :error
)

echo.
echo [INFO] Checking Windows desktop build support...
flutter doctor -v

echo.
echo [IMPORTANT] Flutter Windows desktop builds require Visual Studio
echo with the Desktop development with C++ workload installed.
echo Visual Studio Code alone is not sufficient.
echo.
echo If the build fails because of missing C++ tools, see:
echo https://docs.flutter.dev/platform-integration/windows/setup
echo.

:: ============================================================
:: STEP 2 - Fetch dependencies
:: ============================================================

echo.
echo [1/4] Fetching Flutter dependencies...
flutter pub get
if errorlevel 1 (
    echo [ERROR] flutter pub get failed.
    goto :error
)

:: ============================================================
:: STEP 3 - Build Windows release
:: ============================================================

echo.
echo [2/4] Building Linkless AI for Windows (Release)...
flutter build windows --release
if errorlevel 1 (
    echo [ERROR] Flutter Windows release build failed.
    echo Review the build errors and flutter doctor -v output.
    goto :error
)

if not exist "%RELEASE_DIR%\linkless_ai.exe" (
    echo [ERROR] Expected executable was not found:
    echo %RELEASE_DIR%\linkless_ai.exe
    echo.
    echo Check the runner output directory for your Flutter version.
    goto :error
)

echo.
echo [OK] Flutter release build completed.
echo [OK] Executable: %RELEASE_DIR%\linkless_ai.exe

:: ============================================================
:: STEP 4 - Optional runtime asset setup
:: ============================================================

echo.
echo   ============================================================
echo   OPTIONAL RUNTIME ASSETS
echo   ============================================================
echo.
echo The compiled app can be built without downloading model files.
echo.
echo [Y] Download runtime assets and configure the local engine (Note: 1GB+ Download).
echo [N] Skip downloads; only verify the application build.
echo.
echo Runtime assets are stored in the repository root and are not
echo copied into the Release folder.
echo.

set "RUNTIME_CHOICE="
set /p "RUNTIME_CHOICE=Configure runtime assets now? (Y/N): "

if /i "!RUNTIME_CHOICE!"=="N" goto :build_only
if /i not "!RUNTIME_CHOICE!"=="Y" (
    echo [ERROR] Please enter Y or N.
    goto :error
)

:: ------------------------------------------------------------
:: Select model configuration
:: ------------------------------------------------------------

:choose_models
echo.
echo   CHOOSE YOUR MODEL CONFIGURATION
echo   ============================================================
echo.
echo [1] TEXT AGENT ONLY                         ~1.03 GB
echo     Pro model for text conversations, reasoning and coding.
echo     Does not download vision model files.
echo.
echo [2] TEXT AGENT + VISION AGENT               ~3.20 GB
echo     Pro text model                          ~1.03 GB
echo     VL vision-language model                 ~940 MB
echo     mmproj vision projector                  ~1.23 GB
echo.
echo The VL model and mmproj file work together for image input.
echo Approximate download sizes; additional disk space is required.
echo.

set "MODEL_CHOICE="
set /p "MODEL_CHOICE=Enter 1 or 2: "

if "!MODEL_CHOICE!"=="1" (
    set "INSTALL_VISION=0"
) else if "!MODEL_CHOICE!"=="2" (
    set "INSTALL_VISION=1"
) else (
    echo [ERROR] Invalid choice.
    goto :choose_models
)

echo.
if "!INSTALL_VISION!"=="0" (
    echo [INFO] Selected: Text Agent Only (~1.03 GB).
) else (
    echo [INFO] Selected: Text Agent + Vision Agent (~3.20 GB).
)

set "CONFIRM="
set /p "CONFIRM=Continue with this configuration? (Y/N): "
if /i "!CONFIRM!"=="N" goto :choose_models
if /i not "!CONFIRM!"=="Y" (
    echo [ERROR] Please enter Y or N.
    goto :error
)

:: ------------------------------------------------------------
:: Create root runtime directories
:: ------------------------------------------------------------

if not exist "%MODELS_DIR%" mkdir "%MODELS_DIR%"
if errorlevel 1 (
    echo [ERROR] Could not create the models directory.
    goto :error
)

if not exist "%ENGINE_DIR%" mkdir "%ENGINE_DIR%"
if errorlevel 1 (
    echo [ERROR] Could not create the llama-cpp directory.
    goto :error
)

:: ============================================================
:: STEP 5 - Download the selected models
:: ============================================================

echo.
echo [3/4] Downloading selected model assets...

call :download_model "%PRO_URL%" "%DEST_PRO%" "Linkless AI Pro (~1.03 GB)"
if errorlevel 1 goto :error

if "!INSTALL_VISION!"=="1" (
    call :download_model "%VL_URL%" "%DEST_VL%" "Linkless AI VL (~940 MB)"
    if errorlevel 1 goto :error

    call :download_model "%MMPROJ_URL%" "%DEST_MMPROJ%" "Vision projector (~1.23 GB)"
    if errorlevel 1 goto :error
) else (
    echo [INFO] Vision model downloads skipped.
)

:: ============================================================
:: STEP 6 - Select and install llama.cpp backend
:: ============================================================

echo.
echo [4/4] Detecting the best available inference backend...

set "GPU_NAME="
for /f "usebackq delims=" %%G in (`powershell -NoProfile -Command "(Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name) -join ', '" 2^>nul`) do (
    set "GPU_NAME=%%G"
)

if defined GPU_NAME echo [INFO] Display adapter(s): !GPU_NAME!

set "BACKEND=CPU"

where nvidia-smi >nul 2>&1
if not errorlevel 1 (
    nvidia-smi >nul 2>&1
    if not errorlevel 1 set "BACKEND=CUDA"
)

if "!BACKEND!"=="CPU" (
    if exist "%SystemRoot%\System32\vulkan-1.dll" (
        set "BACKEND=VULKAN"
    )
)

echo [INFO] Initial backend: !BACKEND!

:: Reuse a working existing engine only when it matches the intended
:: setup strategy. Otherwise install the selected backend.
::
:: To ensure a fresh backend choice, replace an existing engine
:: using the Y/N prompt below.

if exist "%ENGINE%" (
    echo.
    echo [INFO] An existing llama-server.exe was found.
    "%ENGINE%" --version >nul 2>&1
    if not errorlevel 1 (
        echo [INFO] Existing engine passed its version check.
        echo.
        set "REUSE_ENGINE="
        set /p "REUSE_ENGINE=Reuse existing engine instead of replacing it? (Y/N): "
        if /i "!REUSE_ENGINE!"=="Y" (
            set "BACKEND=Existing"
            goto :runtime_ready
        )
        if /i not "!REUSE_ENGINE!"=="N" (
            echo [ERROR] Please enter Y or N.
            goto :error
        )
    ) else (
        echo [WARN] Existing engine failed its version check.
    )
    call :cleanup_engine
)

if "!BACKEND!"=="CUDA" (
    call :install_cuda
    if errorlevel 1 (
        echo [WARN] CUDA installation failed; attempting Vulkan.
        call :cleanup_engine
        set "BACKEND=VULKAN"
    )
)

if "!BACKEND!"=="VULKAN" (
    call :install_vulkan
    if errorlevel 1 (
        echo [WARN] Vulkan installation failed; attempting CPU.
        call :cleanup_engine
        set "BACKEND=CPU"
    )
)

if "!BACKEND!"=="CPU" (
    call :install_cpu
    if errorlevel 1 goto :error
)

:runtime_ready

:: ============================================================
:: STEP 7 - Create junctions in the Release directory
:: ============================================================

echo.
echo [INFO] Configuring runtime paths for the compiled application...

call :create_junction "%RELEASE_DIR%\models" "%MODELS_DIR%"
if errorlevel 1 goto :error

call :create_junction "%RELEASE_DIR%\llama-cpp" "%ENGINE_DIR%"
if errorlevel 1 goto :error

goto :prepare_release

:: ============================================================
:: BUILD ONLY
:: ============================================================

:build_only
echo.
echo [INFO] Runtime asset setup was skipped.
echo [INFO] The application was compiled, but local inference may not
echo        work until the required model files and engine are available.
goto :prepare_release

:: ============================================================
:: PREPARE RELEASE DIRECTORY
:: ============================================================

:prepare_release
echo.
echo [INFO] Checking optional release setup script...

if exist "%ROOT%\setup_release.bat" (
    set "COPY_SETUP="
    set /p "COPY_SETUP=Copy setup_release.bat into Release folder? (Y/N): "

    if /i "!COPY_SETUP!"=="Y" (
        copy /y "%ROOT%\setup_release.bat" "%RELEASE_DIR%\setup_release.bat" >nul
        if errorlevel 1 (
            echo [WARN] Could not copy setup_release.bat.
        ) else (
            echo [OK] setup_release.bat copied to Release folder.
        )
    ) else if /i not "!COPY_SETUP!"=="N" (
        echo [WARN] Invalid choice; skipping optional copy.
    )
) else (
    echo [INFO] setup_release.bat not found locally; skipping copy.
)

echo.
echo   ============================================================
echo   DEVELOPER BUILD FINISHED
echo   ============================================================
echo.
echo Executable:
echo   %RELEASE_DIR%\linkless_ai.exe
echo.
if defined BACKEND (
    echo Inference backend: !BACKEND!
) else (
    echo Inference backend: Not configured in this run
)
echo.
echo Repository runtime folders:
echo   %MODELS_DIR%
echo   %ENGINE_DIR%
echo.
echo Release directory:
echo   %RELEASE_DIR%
echo.
echo Note: Junctions are local development conveniences.
echo Verify the final packaged release has real runtime files and
echo does not depend on junction targets outside the release folder.
echo.
pause
exit /b 0

:: ============================================================
:: DOWNLOAD MODEL HELPER
:: ============================================================

:download_model
set "DOWNLOAD_URL=%~1"
set "DOWNLOAD_DEST=%~2"
set "DOWNLOAD_LABEL=%~3"

if exist "%DOWNLOAD_DEST%" (
    for %%F in ("%DOWNLOAD_DEST%") do (
        if %%~zF GTR 0 (
            echo [SKIP] %DOWNLOAD_LABEL% already exists.
            exit /b 0
        )
    )
    echo [WARN] Existing file is empty; downloading again.
    del /f /q "%DOWNLOAD_DEST%" 2>nul
)

echo.
echo [DOWNLOAD] %DOWNLOAD_LABEL%

curl -fL --retry 3 --retry-delay 2 --progress-bar ^
    -o "%DOWNLOAD_DEST%" "%DOWNLOAD_URL%"

if errorlevel 1 (
    echo [ERROR] Download failed: %DOWNLOAD_LABEL%
    del /f /q "%DOWNLOAD_DEST%" 2>nul
    exit /b 1
)

if not exist "%DOWNLOAD_DEST%" exit /b 1

for %%F in ("%DOWNLOAD_DEST%") do (
    if %%~zF LEQ 0 (
        echo [ERROR] Downloaded file is empty.
        del /f /q "%DOWNLOAD_DEST%" 2>nul
        exit /b 1
    )
)

echo [OK] Download completed.
exit /b 0

:: ============================================================
:: CUDA INSTALLER
:: ============================================================

:install_cuda
echo.
echo [ENGINE] Downloading NVIDIA CUDA 12.4 build...

set "LLAMA_ZIP=llama-%LLAMA_TAG%-bin-win-cuda-cu12.4-x64.zip"
set "CUDART_ZIP=cudart-llama-bin-win-cu12.4-x64.zip"

curl -fL --retry 3 --progress-bar ^
    -o "%ENGINE_DIR%\%LLAMA_ZIP%" "%BASE_GH%/%LLAMA_ZIP%"
if errorlevel 1 exit /b 1

curl -fL --retry 3 --progress-bar ^
    -o "%ENGINE_DIR%\%CUDART_ZIP%" "%BASE_GH%/%CUDART_ZIP%"
if errorlevel 1 exit /b 1

powershell -NoProfile -Command ^
    "$ErrorActionPreference='Stop'; Expand-Archive -LiteralPath '%ENGINE_DIR%\%LLAMA_ZIP%' -DestinationPath '%ENGINE_DIR%' -Force; Expand-Archive -LiteralPath '%ENGINE_DIR%\%CUDART_ZIP%' -DestinationPath '%ENGINE_DIR%' -Force"
if errorlevel 1 exit /b 1

del /f /q "%ENGINE_DIR%\%LLAMA_ZIP%" "%ENGINE_DIR%\%CUDART_ZIP%" 2>nul

if not exist "%ENGINE%" exit /b 1

"%ENGINE%" --version >nul 2>&1
if errorlevel 1 exit /b 1

echo [OK] CUDA engine passed the version check.
exit /b 0

:: ============================================================
:: VULKAN INSTALLER
:: ============================================================

:install_vulkan
echo.
echo [ENGINE] Downloading Vulkan build...

set "LLAMA_ZIP=llama-%LLAMA_TAG%-bin-win-vulkan-x64.zip"

curl -fL --retry 3 --progress-bar ^
    -o "%ENGINE_DIR%\%LLAMA_ZIP%" "%BASE_GH%/%LLAMA_ZIP%"
if errorlevel 1 exit /b 1

powershell -NoProfile -Command ^
    "$ErrorActionPreference='Stop'; Expand-Archive -LiteralPath '%ENGINE_DIR%\%LLAMA_ZIP%' -DestinationPath '%ENGINE_DIR%' -Force"
if errorlevel 1 exit /b 1

del /f /q "%ENGINE_DIR%\%LLAMA_ZIP%" 2>nul

if not exist "%ENGINE%" exit /b 1

"%ENGINE%" --version >nul 2>&1
if errorlevel 1 exit /b 1

echo [OK] Vulkan engine passed the version check.
exit /b 0

:: ============================================================
:: CPU INSTALLER
:: ============================================================

:install_cpu
echo.
echo [ENGINE] Downloading universal x64 CPU build...

set "LLAMA_ZIP=llama-%LLAMA_TAG%-bin-win-cpu-x64.zip"

curl -fL --retry 3 --progress-bar ^
    -o "%ENGINE_DIR%\%LLAMA_ZIP%" "%BASE_GH%/%LLAMA_ZIP%"
if errorlevel 1 exit /b 1

powershell -NoProfile -Command ^
    "$ErrorActionPreference='Stop'; Expand-Archive -LiteralPath '%ENGINE_DIR%\%LLAMA_ZIP%' -DestinationPath '%ENGINE_DIR%' -Force"
if errorlevel 1 exit /b 1

del /f /q "%ENGINE_DIR%\%LLAMA_ZIP%" 2>nul

if not exist "%ENGINE%" exit /b 1

"%ENGINE%" --version >nul 2>&1
if errorlevel 1 (
    echo [WARN] CPU engine failed verification.
    echo Check the Microsoft Visual C++ Redistributable:
    echo https://aka.ms/vs/17/release/vc_redist.x64.exe
    exit /b 1
)

echo [OK] CPU engine passed the version check.
exit /b 0

:: ============================================================
:: ENGINE CLEANUP
:: ============================================================

:cleanup_engine
del /f /q "%ENGINE_DIR%\*.zip" 2>nul
del /f /q "%ENGINE_DIR%\*.exe" 2>nul
del /f /q "%ENGINE_DIR%\*.dll" 2>nul
exit /b 0

:: ============================================================
:: CREATE JUNCTION
:: ============================================================

:create_junction
set "LINK_PATH=%~1"
set "TARGET_PATH=%~2"

if not exist "%TARGET_PATH%" (
    echo [ERROR] Junction target does not exist:
    echo %TARGET_PATH%
    exit /b 1
)

if exist "%LINK_PATH%" (
    echo [INFO] Path already exists:
    echo %LINK_PATH%
    echo [INFO] Leaving it unchanged to avoid deleting user data.
    echo [WARN] Verify that it points to:
    echo %TARGET_PATH%
    exit /b 0
)

mklink /J "%LINK_PATH%" "%TARGET_PATH%" >nul
if errorlevel 1 (
    echo [ERROR] Failed to create directory junction.
    echo Link:   %LINK_PATH%
    echo Target: %TARGET_PATH%
    exit /b 1
)

echo [OK] Created junction:
echo      %LINK_PATH%
echo      ^> %TARGET_PATH%
exit /b 0

:: ============================================================
:: FAILURE
:: ============================================================

:error
echo.
echo   ============================================================
echo   DEVELOPER BUILD FAILED
echo   ============================================================
echo.
echo Review the error above and fix the reported issue.
echo Your source files have not been intentionally modified.
echo.
pause
exit /b 1
