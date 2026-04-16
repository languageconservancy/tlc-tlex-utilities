#!/bin/bash
#chmod a+x ListAudioFiles.command

# Check for ffmpeg (needed for ffprobe to get audio duration)
if ! command -v ffprobe &> /dev/null; then
    echo "ffprobe not found. Installing ffmpeg..."
    if ! command -v brew &> /dev/null; then
        echo "Homebrew not found. Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    brew install ffmpeg
fi

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

cd "$SCRIPT_DIR"

OUTPUT_FILE="audio_files_list.csv"

echo "Scanning for mp3 and wav files..."
echo ""

# Create CSV header
echo "filename,fullpath,filesize_bytes,duration_seconds" > "$OUTPUT_FILE"

# Find all .mp3 and .wav files recursively
find . -type f \( -iname "*.mp3" -o -iname "*.wav" \) | while IFS= read -r filepath; do
    # Get just the filename
    filename=$(basename "$filepath")
    # Get the full path (relative to script directory)
    fullpath=$(cd "$(dirname "$filepath")" && pwd)/$(basename "$filepath")
    
    # Get file size in bytes
    filesize=$(stat -f%z "$filepath")
    
    # Get audio duration using ffprobe
    duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$filepath" 2>/dev/null)
    if [ -z "$duration" ]; then
        duration="N/A"
    fi
    
    # Escape quotes in case they exist in filenames
    filename_escaped=$(echo "$filename" | sed 's/"/""/g')
    fullpath_escaped=$(echo "$fullpath" | sed 's/"/""/g')
    
    # Write to CSV with proper quoting
    echo "\"$filename_escaped\",\"$fullpath_escaped\",$filesize,$duration" >> "$OUTPUT_FILE"
done

# Count the files found (subtract 1 for header)
file_count=$(($(wc -l < "$OUTPUT_FILE") - 1))

echo "Found $file_count audio files"
echo "Results saved to: $SCRIPT_DIR/$OUTPUT_FILE"
echo ""
echo "Done!"
