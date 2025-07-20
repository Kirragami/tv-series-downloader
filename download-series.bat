@echo off
setlocal enabledelayedexpansion

:: -- FFmpeg setup --
set "FFMPEG_DIR=ffmpeg"
set "FFMPEG_EXE=%FFMPEG_DIR%\ffmpeg.exe"
set "FFMPEG_ZIP=%FFMPEG_DIR%\ffmpeg.zip"
set "FFMPEG_URL=https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"

if not exist "%FFMPEG_EXE%" (
  echo FFmpeg not found locally, downloading...

  if not exist "%FFMPEG_DIR%" mkdir "%FFMPEG_DIR%"

  powershell -Command "Invoke-WebRequest -Uri '%FFMPEG_URL%' -OutFile '%CD%\%FFMPEG_ZIP%'"

  echo Extracting ffmpeg...
  powershell -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::ExtractToDirectory('%CD%\%FFMPEG_ZIP%', '%CD%\%FFMPEG_DIR%')"

  echo Searching for ffmpeg.exe inside extracted folder...
  for /f "delims=" %%f in ('dir /b /s "%FFMPEG_DIR%\ffmpeg.exe"') do (
    echo Moving %%f to %FFMPEG_EXE%
    move /y "%%f" "%FFMPEG_EXE%"
    goto :after_move
  )
  :after_move

  echo Cleaning up...
  del /q "%FFMPEG_ZIP%"
  for /d %%d in ("%FFMPEG_DIR%\ffmpeg-release-essentials*") do rd /s /q "%%d"
)

:: Now you can run ffmpeg with:
"%FFMPEG_EXE%" -i "%m3u8_URL%" -c copy "%output_path%"


:: Check if Python is installed
where python >nul 2>&1
if errorlevel 1 (
  echo Error: Python is not installed or not in PATH.
  exit /b 1
)

:: Check if Python venv module works by trying to create a temp venv
set "TMP_VENV=%TEMP%\tmp_venv_check"
rmdir /S /Q "%TMP_VENV%" 2>nul
python -m venv "%TMP_VENV%" >nul 2>&1
if errorlevel 1 (
  echo Error: Your Python installation does not have the 'venv' module.
  echo Please install it.
  exit /b 1
)
rmdir /S /Q "%TMP_VENV%"

:: Create venv if it does not exist
if not exist "venv\Scripts\activate.bat" (
  echo Creating Python virtual environment...
  python -m venv venv
)

:: Input: Search query (required)
if "%~1"=="" (
  echo Usage: run.bat "search query" season episode
  exit /b 1
)
set "QUERY=%~1"

:: Optional season and episode
set "SEASON=%~2"
set "EPISODE=%~3"

:: URL encode QUERY using PowerShell
for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "Add-Type -AssemblyName System.Web; [System.Web.HttpUtility]::UrlEncode('%QUERY%')"`) do set "ENCODED_QUERY=%%A"

:: IMDb API URL
set "API_URL=https://api.imdbapi.dev/advancedSearch/titles?query=%ENCODED_QUERY%&types=TV_SERIES"

echo Fetching Available Series...

:: Fetch IDs and Titles from API using PowerShell Invoke-RestMethod and parsing JSON
set idx=0
for /f "usebackq tokens=*" %%i in (`powershell -NoProfile -Command ^
  "Invoke-RestMethod '%API_URL%' | Select-Object -ExpandProperty titles | ForEach-Object { $_.id }"`) do (
  set /a idx+=1
  set "IDS[!idx!]=%%i"
)

set idx=0
for /f "usebackq tokens=*" %%i in (`powershell -NoProfile -Command ^
  "Invoke-RestMethod '%API_URL%' | Select-Object -ExpandProperty titles | ForEach-Object { $_.primaryTitle }"`) do (
  set /a idx+=1
  set "TITLES[!idx!]=%%i"
)

:: Display titles
echo Select a title:
for /l %%i in (1,1,%idx%) do (
  call echo %%i. !TITLES[%%i]!
)

:: Prompt user for choice
set /p choice=Enter a number: 

:: Validate choice
if not defined choice (
  echo Invalid choice: empty input.
  exit /b 1
)
for /f "delims=0123456789" %%x in ("%choice%") do (
  echo Invalid choice: not a number.
  exit /b 1
)
if %choice% lss 1 (
  echo Invalid choice: number less than 1.
  exit /b 1
)
if %choice% gtr %idx% (
  echo Invalid choice: number greater than available titles.
  exit /b 1
)

:: Assign selected ID and Title
call set "SELECTED_ID=%%IDS[%choice%]%%"
call set "SELECTED_TITLE=%%TITLES[%choice%]%%"

:: Check if ID is valid
if "%SELECTED_ID%"=="null" (
  echo No ID found for query: %QUERY%
  exit /b 1
)

:: Construct URL
set "URL=https://111movies.com/tv/%SELECTED_ID%/%SEASON%/%EPISODE%"
echo Constructed URL: %URL%

:: Activate venv
call venv\Scripts\activate.bat

:: Upgrade pip
pip install --upgrade pip

:: Install Playwright if not installed
python -c "import playwright" 2>nul
if errorlevel 1 (
  echo Installing Playwright package...
  pip install playwright
)

:: Install Playwright browsers if not installed
if not exist "venv\.playwright" (
  echo Installing Dependencies...
  playwright install
  if errorlevel 1 (
    echo.
    echo Error: Playwright browser installation failed.
    echo Please ensure system dependencies are installed.
    exit /b 1
  )
)

:: Run your Python script
python m3u8-url-fetcher.py "%URL%"

:: Read m3u8 URL from temp file
set /p m3u8_URL=<%TEMP%\m3u8.txt

if "%m3u8_URL%"=="" (
  echo ERROR: Failed to read m3u8 URL from temp file.
  exit /b 1
)

echo Starting Download...

:: Construct output path
set "output_path=%USERPROFILE%\Downloads\%SELECTED_TITLE% - S%SEASON%E%EPISODE%.mp4"
echo Saving video to: "%output_path%"

:: Run ffmpeg (assumes ffmpeg is in PATH)
"%FFMPEG_EXE%" -i "%m3u8_URL%" -c copy "%output_path%"

:: Deactivate venv (optional)
endlocal
