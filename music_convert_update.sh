#!/bin/bash

# --- Configuration ---
# Ensure you use absolute paths

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

# Optional: Log file for cron job output.
LOG_FILE="/path/to/logfile.log"

# Maximum log size in bytes before it is rotated (default: 10MB).
MAX_LOG_SIZE=$((10 * 1024 * 1024))

# --- Log Rotation ---
if [ -f "$LOG_FILE" ] && [ "$(stat -c%s "$LOG_FILE" 2>/dev/null || stat -f%z "$LOG_FILE")" -ge "$MAX_LOG_SIZE" ]; then
    mv "$LOG_FILE" "${LOG_FILE}.old"
fi

# --- Setup ---
mkdir -p "$BACKUP_DIR"

# Temp file to collect failures across parallel jobs
FAIL_LOG=$(mktemp)
trap 'rm -f "$FAIL_LOG"' EXIT

echo "-------------------------------------------" | tee -a "$LOG_FILE"
echo "Starting incremental backup scan on $(date)" | tee -a "$LOG_FILE"
echo "Source:      $MUSIC_DIR"                     | tee -a "$LOG_FILE"
echo "Destination: $BACKUP_DIR"                    | tee -a "$LOG_FILE"

# --- Conversion Process ---
# FIX: Use -iname predicates instead of a broken character-class regex.
# The original FIND_REGEX '.+[mp3|wav|flac|...]$' was a character class that
# matched single chars (m, p, 3, |, w …), not full extensions.
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
    LOG_FILE="$5"
    FAIL_LOG="$6"

    relative_path="${input_file#$MUSIC_DIR/}"
    output_file="${BACKUP_DIR}/${relative_path%.*}.ogg"

    # --- INCREMENTAL CHECK ---
    # Skip if the output already exists AND is not older than the source.
    if [ -f "$output_file" ] && [ ! "$input_file" -nt "$output_file" ]; then
        exit 0
    fi

    mkdir -p "$(dirname "$output_file")"

    echo "Converting: $input_file" | tee -a "$LOG_FILE"

    if ! ffmpeg -i "$input_file" -c:a libvorbis -q:a "$OGG_QUALITY" -vn -y \
            -loglevel error "$output_file" < /dev/null; then
        echo "FAILED: $input_file" | tee -a "$LOG_FILE" >> "$FAIL_LOG"
        # Remove a partial/corrupt output file on failure
        rm -f "$output_file"
    fi

' _ {} "$MUSIC_DIR" "$BACKUP_DIR" "$OGG_QUALITY" "$LOG_FILE" "$FAIL_LOG"

# Report any failures
if [ -s "$FAIL_LOG" ]; then
    echo "WARNING: The following files failed to convert:" | tee -a "$LOG_FILE"
    cat "$FAIL_LOG" | tee -a "$LOG_FILE"
fi

echo "Incremental backup scan complete on $(date)" | tee -a "$LOG_FILE"
echo "-------------------------------------------" | tee -a "$LOG_FILE"
