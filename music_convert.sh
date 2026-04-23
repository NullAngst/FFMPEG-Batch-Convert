#!/bin/bash

# --- Configuration ---
# Set the source directory for your music collection.
# IMPORTANT: Do not include a trailing slash.
MUSIC_DIR="/path/to/source"

# Set the destination directory for the converted files.
# IMPORTANT: Do not include a trailing slash.
BACKUP_DIR="/path/to/backup"

# Set the FFmpeg audio quality level for OGG Vorbis.
# The scale is -1 to 10, where 10 is the highest quality.
OGG_QUALITY=10

# Number of parallel ffmpeg jobs. A good default is your CPU core count.
# Set to 1 to disable parallelism.
PARALLEL_JOBS=4

# --- Setup ---
mkdir -p "$BACKUP_DIR"

# Track failures
FAIL_LOG=$(mktemp)
trap 'rm -f "$FAIL_LOG"' EXIT

echo "Starting batch conversion..."
echo "Source:      $MUSIC_DIR"
echo "Destination: $BACKUP_DIR"
echo "-------------------------------------------"

# --- Conversion Process ---
# FIX: Use a proper alternation pattern (-iregex with \| or a grouped expression).
# The original used a character class [...] which only matched single characters.
find "$MUSIC_DIR" -type f \( \
    -iname "*.mp3"  -o -iname "*.wav"  -o -iname "*.flac" \
    -o -iname "*.aac"  -o -iname "*.m4a"  -o -iname "*.m4b" \
    -o -iname "*.wma"  -o -iname "*.alac" -o -iname "*.aiff" \
    -o -iname "*.aif"  -o -iname "*.ape"  -o -iname "*.opus" \
\) -print0 | xargs -0 -P "$PARALLEL_JOBS" -I{} bash -c '

    input_file="$1"
    MUSIC_DIR="$2"
    BACKUP_DIR="$3"
    OGG_QUALITY="$4"
    FAIL_LOG="$5"

    relative_path="${input_file#$MUSIC_DIR/}"
    output_file="${BACKUP_DIR}/${relative_path%.*}.ogg"

    mkdir -p "$(dirname "$output_file")"

    echo "Converting: $input_file"

    if ! ffmpeg -i "$input_file" -c:a libvorbis -q:a "$OGG_QUALITY" -vn -y \
            -loglevel error "$output_file" < /dev/null; then
        echo "FAILED: $input_file" >> "$FAIL_LOG"
        # Remove a partial/corrupt output file on failure
        rm -f "$output_file"
    fi

' _ {} "$MUSIC_DIR" "$BACKUP_DIR" "$OGG_QUALITY" "$FAIL_LOG"

echo "-------------------------------------------"

# Report any failures
if [ -s "$FAIL_LOG" ]; then
    echo "WARNING: The following files failed to convert:"
    cat "$FAIL_LOG"
    echo "-------------------------------------------"
    exit 1
else
    echo "Batch conversion complete!"
fi
