#!/bin/bash
#chmod a+x NormalizeAndTrimForMacOS.command

# Check and install dependencies
echo "Checking dependencies..."

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Check and install sox
if ! command -v sox &> /dev/null; then
    echo "sox not found. Installing sox..."
    brew install sox
else
    echo "sox is already installed."
fi

# Check and install ffmpeg
if ! command -v ffmpeg &> /dev/null; then
    echo "ffmpeg not found. Installing ffmpeg..."
    brew install ffmpeg
else
    echo "ffmpeg is already installed."
fi

echo "All dependencies are ready."
echo ""

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

cd "$SCRIPT_DIR"

mkdir norm
mkdir trim

#i=1;
for file in *.wav; do
  filename=${file%.*};
#  x=$((i/50+1));
#  mkdir "./trim/$x";
  sox "$file" "norm/$file" norm -3;
  ffmpeg -i "norm/$file" -af silenceremove=start_periods=1:start_silence=0.1:start_threshold=-42dB,areverse,silenceremove=start_periods=1:start_silence=0.1:start_threshold=-42dB,areverse "trim/$filename.mp3"
#  ((i++));
done

for file in *.mp3; do
  filename=${file%.*};
#  x=$((i/50+1));
#  mkdir "./trim/$x";
  sox "$file" "norm/$file" norm -3;
  ffmpeg -i "norm/$file" -af silenceremove=start_periods=1:start_silence=0.1:start_threshold=-42dB,areverse,silenceremove=start_periods=1:start_silence=0.1:start_threshold=-42dB,areverse "trim/$filename.mp3"
#  ((i++));
done