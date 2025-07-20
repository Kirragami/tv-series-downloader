@echo off
setlocal enabledelayedexpansion

:: Check Python executable
where python >nul 2>&1
if errorlevel 1 (
  echo Python is not installed or not in PATH.
  exit /b 1
)

:: Create virtual environment if not exists
if not exist "venv\Scripts\activate.bat" (
  echo Creating virtual environment...
  python -m venv venv
)

:: Activate venv
call venv\Scripts\activate.bat

:: Upgrade pip
echo Upgrading pip...
python -m pip install --upgrade pip >nul

:: Check if playwright package is installed
python -c "import playwright" 2>nul
if errorlevel 1 (
  echo Installing Playwright package...
  pip install playwright
)

:: Check if Playwright browsers are installed (check folder)
if not exist "venv\.playwright" (
  echo Installing Playwright browsers...
  playwright install
  if errorlevel 1 (
    echo Playwright browser installation failed.
    exit /b 1
  )
)

:: Check if ffmpeg binary exists locally
if not exist "ffmpeg\bin\ffmpeg.exe" (
  echo ffmpeg not found locally. Downloading...

  powershell -Command ^
    "Invoke-WebRequest -Uri 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip' -OutFile 'ffmpeg.zip'"

  if errorlevel 1 (
    echo Failed to download ffmpeg.
    exit /b 1
  )

  echo Extracting ffmpeg...
  powershell -Command "Expand-Archive -Path ffmpeg.zip -DestinationPath ."

  if errorlevel 1 (
    echo Failed to extract ffmpeg.
    exit /b 1
  )

  :: Move extracted folder to 'ffmpeg' folder (adjust name if needed)
  move /Y ffmpeg-release-essentials\* ffmpeg\
  rmdir /S /Q ffmpeg-release-essentials
  del ffmpeg.zip
)

:: Run your python script
python m3u8-url-fetcher.py "%URL%"

:: Read m3u8 URL from temp file (adjust path if needed)
set /p m3u8_URL=<C:\Windows\Temp\m3u8.txt

:: Build output path
set "output_path=%USERPROFILE%\Downloads\%SELECTED_TITLE% - S%SEASON%E%EPISODE%.mp4"
echo Saving video to: "%output_path%"

:: Run local ffmpeg executable
ffmpeg\bin\ffmpeg.exe -i "%m3u8_URL%" -c copy "%output_path%"

:: Deactivate virtual env (end script)
endlocal

