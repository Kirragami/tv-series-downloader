#!/bin/bash
set -e

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check python3
if ! command_exists python3; then
  echo "Error: python3 is not installed. Please install it first."
  exit 1
fi

# Check if python3-venv module is available by trying to create a temp venv
tmp_venv_dir=$(mktemp -d)
if ! python3 -m venv "$tmp_venv_dir" >/dev/null 2>&1; then
  echo "Error: Your Python installation does not have the 'venv' module."
  echo "On Debian/Ubuntu, install it with:"
  echo "  sudo apt-get install python3-venv"
  rm -rf "$tmp_venv_dir"
  exit 1
fi
rm -rf "$tmp_venv_dir"

# Create venv if not exist
if [ ! -d "venv" ]; then
  echo "Creating Python virtual environment..."
  python3 -m venv venv
fi

# Check that activate script exists
if [ ! -f "venv/bin/activate" ]; then
  echo "Error: venv/bin/activate not found! Virtual environment not created properly."
  echo "Try deleting 'venv' folder and rerunning this script."
  exit 1
fi

# Input: Search query
if [ -z "$1" ]; then
  echo "Usage: ./run.sh \"search query\""
  exit 1
fi

QUERY="$1"
SEASON="$2"
EPISODE="$3"
ENCODED_QUERY=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$QUERY'''))")
API_URL="https://api.imdbapi.dev/advancedSearch/titles?query=${ENCODED_QUERY}&types=TV_SERIES"
# Fetch and extract the first ID

# Validate input
if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#TITLES[@]} )); then
  echo "Invalid choice"
  exit 1
fi

if [ "$IDS" == "null" ] || [ -z "$IDS" ]; then
  echo "No ID found for query: $QUERY"
  exit 1
fi

# Construct URL
URL="https://111movies.com/tv/${SELECTED_ID}/${SEASON}/${EPISODE}"

# Activate venv
source venv/bin/activate

# Upgrade pip
pip install --upgrade pip

# Install playwright if not installed
if ! python3 -c "import playwright" &>/dev/null; then
  echo "Installing Playwright package..."
  pip install playwright
fi

# Run playwright install to install browsers if not done before
if [ ! -d "venv/.playwright" ]; then
  echo "Installing Dependencies..."
  playwright install || {
    echo ""
    echo "Error: Playwright browser installation failed."
    echo "If you are on Linux, please ensure system dependencies are installed:"
    echo "  sudo apt-get install -y libnss3 libatk-1.0-0 libcups2 libxcomposite1 libxdamage1 libxrandr2 libgbm1 libasound2 libpangocairo-1.0-0 libxshmfence1"
    exit 1
  }
fi

echo "Fetching Available Series..."

mapfile -t IDS < <(curl -s "$API_URL" | jq -r '.titles[].id')
mapfile -t TITLES < <(curl -s "$API_URL" | jq -r '.titles[].primaryTitle')

# Run your Python script with all passed arguments
python3 m3u8-url-fetcher.py "$URL"

m3u8_URL=$(< /tmp/m3u8.txt)

echo "Starting Download..."

output_path="$HOME/Downloads/${SELECTED_TITLE} - S${SEASON}E${EPISODE}.mp4"
ffmpeg -i "$m3u8_URL" -c copy "$output_path"

 
# Deactivate venv (optional)
deactivate
