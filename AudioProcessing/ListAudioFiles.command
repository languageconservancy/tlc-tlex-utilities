#!/bin/bash
#chmod a+x ListAudioFiles.command

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

cd "$SCRIPT_DIR"

OUTPUT_FILE="audio_files_list.csv"

echo "Scanning for mp3 and wav files..."
echo ""

# Create CSV header
echo "filename,fullpath" > "$OUTPUT_FILE"

# Find all .mp3 and .wav files recursively
find . -type f \( -iname "*.mp3" -o -iname "*.wav" \) | while IFS= read -r filepath; do
    # Get just the filename
    filename=$(basename "$filepath")
    # Get the full path (relative to script directory)
    fullpath=$(cd "$(dirname "$filepath")" && pwd)/$(basename "$filepath")
    
    # Escape quotes in case they exist in filenames
    filename_escaped=$(echo "$filename" | sed 's/"/""/g')
    fullpath_escaped=$(echo "$fullpath" | sed 's/"/""/g')
    
    # Write to CSV with proper quoting
    echo "\"$filename_escaped\",\"$fullpath_escaped\"" >> "$OUTPUT_FILE"
done

# Count the files found (subtract 1 for header)
file_count=$(($(wc -l < "$OUTPUT_FILE") - 1))

echo "Found $file_count audio files"
echo "Results saved to: $SCRIPT_DIR/$OUTPUT_FILE"
echo ""
echo "Done!"
