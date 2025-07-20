@echo on
setlocal enabledelayedexpansion

:: Function to check if a command exists
:: Usage: call :command_exists python
:: Returns ERRORLEVEL 0 if exists, 1 if not

:: Check if ffmpeg.exe exists in project directory

:: Use ffmpeg.exe from project directory
set "FFMPEG_EXE=%CD%\ffmpeg\bin\ffmpeg.exe"


:: Check python3 existence

:: Check if python venv module exists by trying to create a temp venv
set "tmp_venv_dir=%TEMP%\tmp_venv_check"
if exist "%tmp_venv_dir%" rmdir /s /q "%tmp_venv_dir%"
python -m venv "%tmp_venv_dir%" >nul 2>&1
if errorlevel 1 (
  echo Error: Your Python installation does not have the 'venv' module.
  echo Please install the venv module.
  rmdir /s /q "%tmp_venv_dir%"
  exit /b 1
)
rmdir /s /q "%tmp_venv_dir%"

:: Create venv if it doesn't exist
if not exist "venv" (
  echo Creating Python virtual environment...
  python -m venv venv
  if errorlevel 1 (
    echo Failed to create virtual environment.
    exit /b 1
  )
)

:: Check that activate script exists
if not exist "venv\Scripts\activate.bat" (
  echo Error: venv\Scripts\activate.bat not found! Virtual environment not created properly.
  echo Try deleting the 'venv' folder and rerunning this script.
  exit /b 1
)

:: Activate venv
call venv\Scripts\activate.bat

:: Upgrade pip
python -m pip install --upgrade pip

:: Check if playwright is installed, if not install it
python -c "import playwright" 2>nul
if errorlevel 1 (
  echo Installing Playwright package...
  pip install playwright
)

:: Check if playwright browsers installed by looking for .playwright folder
if not exist "venv\.playwright" (
  echo Installing Dependencies...
  playwright install
  if errorlevel 1 (
    echo.
    echo Error: Playwright browser installation failed.
    echo On Windows, ensure system dependencies are installed properly.
    exit /b 1
  )
)

:: Check input arguments
if "%~1"=="" (
  echo Usage: %~nx0 "search query" [season] [episode]
  exit /b 1
)

set "QUERY=%~1"
set "SEASON=%~2"
set "EPISODE=%~3"

:: URL encode the query via python
for /f "usebackq delims=" %%A in (`python -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "%QUERY%"`) do set "ENCODED_QUERY=%%A"

set "API_URL=https://api.imdbapi.dev/advancedSearch/titles?query=%ENCODED_QUERY%&types=TV_SERIES"

echo Fetching Available Series...

:: Fetch JSON response to a temp file
curl -s "%API_URL%" -o temp_response.json
if errorlevel 1 (
  echo Failed to fetch data from API
  exit /b 1
)

:: Extract titles and ids using PowerShell (since jq is not default on Windows)
for /f "usebackq tokens=*" %%I in (`powershell -command ^
  "Get-Content temp_response.json | ConvertFrom-Json | select -ExpandProperty titles | ForEach-Object { $_.id + '|' + $_.primaryTitle }"`) do (
    set /a count+=1
    set "entry[!count!]=%%I"
)

if %count%==0 (
  echo No titles found for query: %QUERY%
  del temp_response.json
  exit /b 1
)

echo Select a title:
for /l %%i in (1,1,%count%) do (
  for /f "tokens=1* delims=|" %%a in ("!entry[%%i]!") do (
    echo %%i. %%b
  )
)

:ask_choice
set /p choice=Enter a number: 
rem Validate input is a number between 1 and count
for /f "delims=0123456789" %%x in ("%choice%") do (
  echo Invalid choice. Please enter a valid number.
  goto ask_choice
)
if %choice% lss 1 (
  echo Invalid choice. Number too small.
  goto ask_choice
)
if %choice% gtr %count% (
  echo Invalid choice. Number too large.
  goto ask_choice
)

for /f "tokens=1* delims=|" %%a in ("!entry[%choice%]!") do (
  set "SELECTED_ID=%%a"
  set "SELECTED_TITLE=%%b"
)

del temp_response.json

set "URL=https://111movies.com/tv/%SELECTED_ID%/%SEASON%/%EPISODE%"

:: Run your python script with the constructed URL
python m3u8-url-fetcher.py "%URL%"

:: Read the m3u8 URL from the temp file (assuming it writes to C:\temp\m3u8.txt)
:: Adjust path if needed
set "TMP_M3U8=%TEMP%\m3u8.txt"
if not exist "%TMP_M3U8%" (
  echo m3u8 URL file not found.
  exit /b 1
)
set /p m3u8_URL=<"%TMP_M3U8%"

echo Starting Download...

set "OUTPUT_PATH=%USERPROFILE%\Downloads\%SELECTED_TITLE% - S%SEASON%E%EPISODE%.mp4"

"%FFMPEG_EXE%" -i "%m3u8_URL%" -c copy "%OUTPUT_PATH%"

:: Deactivate virtual environment (optional)
call venv\Scripts\deactivate.bat

endlocal
