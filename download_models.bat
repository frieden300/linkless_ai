@echo off
setlocal EnableDelayedExpansion
title Linkless AI — Model Downloader

:: ============================================================
::  Linkless AI  •  Bootstrap / Model Downloader
::  Run once after cloning the repo.
::  Downloads:
::    1. Linkless-AI-Pro  (text model, ~1 GB)
::    2. Linkless-AI-VL   (vision model, ~940 MB)
::    3. mmproj file      (vision projector, ~1.27 GB)
::    4. llama.cpp binaries (llama-server + DLLs, ~180 MB)
:: ============================================================

echo.
echo  ██╗     ██╗███╗   ██╗██╗  ██╗██╗     ███████╗███████╗███████╗
echo  ██║     ██║████╗  ██║██║ ██╔╝██║     ██╔════╝██╔════╝██╔════╝
echo  ██║     ██║██╔██╗ ██║█████╔╝ ██║     █████╗  ███████╗███████╗
echo  ██║     ██║██║╚██╗██║██╔═██╗ ██║     ██╔══╝  ╚════██║╚════██║
echo  ███████╗██║██║ ╚████║██║  ██╗███████╗███████╗███████║███████║
echo  ╚══════╝╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝╚══════╝
echo.
echo  Model Downloader  ^|  github.com/viraj/linkless_ai
echo  ────────────────────────────────────────────────────────────────
echo.

:: ── Check for required tools ────────────────────────────────
where curl >nul 2>&1
if errorlevel 1 (
    echo [ERROR] curl not found. Please install curl or use Windows 10 v1803+.
    pause & exit /b 1
)

:: ── Create directories ───────────────────────────────────────
if not exist "models"     mkdir models
if not exist "llama-cpp"  mkdir llama-cpp

:: ════════════════════════════════════════════════════════════
::  SECTION 1 — GGUF MODEL WEIGHTS  (Hugging Face Hub)
::  TODO: Replace the URLs below with your actual HF repo URLs
::  after uploading. Format:
::    https://huggingface.co/<username>/<repo>/resolve/main/<file>
:: ════════════════════════════════════════════════════════════

set HF_USER=YOUR_HF_USERNAME
set HF_REPO_PRO=Linkless-AI-Pro
set HF_REPO_VL=Linkless-AI-VL

set PRO_URL=https://huggingface.co/%HF_USER%/%HF_REPO_PRO%/resolve/main/Linkless-AI-Pro-Q4_K_M.gguf
set VL_URL=https://huggingface.co/%HF_USER%/%HF_REPO_VL%/resolve/main/Linkless-AI-VL-Q4_K_M.gguf
set MMPROJ_URL=https://huggingface.co/%HF_USER%/%HF_REPO_VL%/resolve/main/mmproj-Linkless-AI-VL-f16.gguf

:: ── Download Pro (text) model ────────────────────────────────
set DEST_PRO=models\Linkless-AI-Pro-Q4_K_M.gguf
if exist "%DEST_PRO%" (
    echo [SKIP] %DEST_PRO% already exists.
) else (
    echo [1/3] Downloading Linkless-AI-Pro text model (~1 GB) ...
    curl -L --progress-bar -o "%DEST_PRO%" "%PRO_URL%"
    if errorlevel 1 (
        echo [ERROR] Failed to download Pro model. Check the URL in this script.
        del /f /q "%DEST_PRO%" 2>nul
        goto :error
    )
    echo [OK]  Linkless-AI-Pro downloaded.
)

:: ── Download Vision (VL) model ───────────────────────────────
set DEST_VL=models\Linkless-AI-VL-Q4_K_M.gguf
if exist "%DEST_VL%" (
    echo [SKIP] %DEST_VL% already exists.
) else (
    echo [2/3] Downloading Linkless-AI-VL vision model (~940 MB) ...
    curl -L --progress-bar -o "%DEST_VL%" "%VL_URL%"
    if errorlevel 1 (
        echo [ERROR] Failed to download VL model. Check the URL in this script.
        del /f /q "%DEST_VL%" 2>nul
        goto :error
    )
    echo [OK]  Linkless-AI-VL downloaded.
)

:: ── Download mmproj ──────────────────────────────────────────
set DEST_MMPROJ=models\mmproj-Linkless-AI-VL-f16.gguf
if exist "%DEST_MMPROJ%" (
    echo [SKIP] %DEST_MMPROJ% already exists.
) else (
    echo [3/3] Downloading mmproj vision projector (~1.27 GB) ...
    curl -L --progress-bar -o "%DEST_MMPROJ%" "%MMPROJ_URL%"
    if errorlevel 1 (
        echo [ERROR] Failed to download mmproj. Check the URL in this script.
        del /f /q "%DEST_MMPROJ%" 2>nul
        goto :error
    )
    echo [OK]  mmproj downloaded.
)

:: ════════════════════════════════════════════════════════════
::  SECTION 2 — llama.cpp BINARIES  (GitHub Releases)
::  Pinned to the same build used during development.
::  TODO: Replace tag/URL if you upgrade llama.cpp.
:: ════════════════════════════════════════════════════════════

set LLAMA_TAG=b5616
set LLAMA_ZIP=llama-%LLAMA_TAG%-bin-win-cuda-cu12.4-x64.zip
set LLAMA_URL=https://github.com/ggml-org/llama.cpp/releases/download/%LLAMA_TAG%/%LLAMA_ZIP%
set LLAMA_ZIP_PATH=llama-cpp\%LLAMA_ZIP%

if exist "llama-cpp\llama-server.exe" (
    echo [SKIP] llama-server.exe already exists.
) else (
    echo [4/4] Downloading llama.cpp binaries (CUDA build, ~180 MB) ...
    curl -L --progress-bar -o "%LLAMA_ZIP_PATH%" "%LLAMA_URL%"
    if errorlevel 1 (
        echo [ERROR] Failed to download llama.cpp. Check your internet or the tag in this script.
        del /f /q "%LLAMA_ZIP_PATH%" 2>nul
        goto :error
    )

    echo       Extracting ...
    :: Use PowerShell's Expand-Archive (available on all Win 10+)
    powershell -NoProfile -Command ^
        "Expand-Archive -Path '%LLAMA_ZIP_PATH%' -DestinationPath 'llama-cpp' -Force"
    if errorlevel 1 (
        echo [ERROR] Extraction failed.
        goto :error
    )
    del /f /q "%LLAMA_ZIP_PATH%"
    echo [OK]  llama.cpp binaries extracted to llama-cpp\
)

:: ════════════════════════════════════════════════════════════
::  DONE
:: ════════════════════════════════════════════════════════════
echo.
echo  ────────────────────────────────────────────────────────────────
echo  [OK] All files are ready!
echo.
echo  Next steps:
echo    1. Launch Linkless AI  (linkless_ai.exe from the Release)
echo    2. Open Settings -^> set the llama-server path to:
echo       llama-cpp\llama-server.exe
echo    3. The app will auto-detect the models in the models\ folder.
echo  ────────────────────────────────────────────────────────────────
echo.
pause
exit /b 0

:error
echo.
echo  [FAILED] Download incomplete. Please check the errors above.
echo  If the Hugging Face URLs are placeholders, update them in this
echo  script after uploading your models to HF Hub.
echo.
pause
exit /b 1
