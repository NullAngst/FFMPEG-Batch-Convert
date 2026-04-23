#!/bin/bash

# --- Configuration ---
# These paths MUST match the paths in your main conversion script.
MUSIC_DIR="/path/to/source"
BACKUP_DIR="/path/to/backup"
LOG_FILE="/path/to/cleanup_music.log"

# Define the list of possible source audio extensions (case-insensitive).
# This should match the extensions used in the main conversion script's find command.
POSSIBLE_EXTENSIONS=(flac wav mp3 m4a ogg aiff aif wma aac ape opus alac m4b)

echo "Starting orphan file cleanup..." | tee -a "$LOG_FILE"

# Find all .ogg files in the backup directory, separated by NULL characters.
find "$BACKUP_DIR" -type f -iname "*.ogg" -print0 | while IFS= read -r -d '' ogg_file; do

    # Derive the base source path from the backup .ogg path.
    # e.g., /backup/Artist/Album/Song.ogg -> /music/Artist/Album/Song
    relative_path="${ogg_file#$BACKUP_DIR/}"
    source_base_path="${MUSIC_DIR}/${relative_path%.*}"

    source_exists=false

    # FIX: Check both lowercase and uppercase variants of each extension so
    # that files like Song.FLAC or Song.Mp3 are not incorrectly treated as
    # orphans on case-sensitive filesystems.
    for ext in "${POSSIBLE_EXTENSIONS[@]}"; do
        if [ -f "${source_base_path}.${ext}" ] || \
           [ -f "${source_base_path}.${ext^^}" ] || \
           [ -f "${source_base_path}.${ext^}" ]; then
            source_exists=true
            break
        fi
    done

    if [ "$source_exists" = false ]; then
        echo "Removing orphan: $ogg_file" | tee -a "$LOG_FILE"
        rm "$ogg_file"
    fi

done

# FIX: Remove empty directories with a loop so that nested empties are fully
# cleaned up. A single pass of `find -empty -delete` leaves parent directories
# behind if their only contents were the just-deleted empty children.
echo "Cleaning up empty directories..." | tee -a "$LOG_FILE"
while true; do
    # Capture dirs that are currently empty
    mapfile -d '' empty_dirs < <(find "$BACKUP_DIR" -mindepth 1 -type d -empty -print0)
    [ "${#empty_dirs[@]}" -eq 0 ] && break
    for d in "${empty_dirs[@]}"; do
        rmdir "$d" && echo "Removed empty dir: $d" | tee -a "$LOG_FILE"
    done
done

echo "Orphan cleanup complete." | tee -a "$LOG_FILE"
