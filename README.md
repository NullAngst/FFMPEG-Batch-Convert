# FFMPEG-Batch-Convert

A set of Bash scripts for batch-converting a music library to high-quality OGG Vorbis format using FFmpeg. Designed to maintain a compressed mirror of your music collection — useful for remote backups, portable storage, or anywhere storage space is at a premium.

---

## Why This Exists

Lossless audio formats like FLAC and WAV produce large files. If you maintain a sizeable music library (hundreds of gigabytes to multiple terabytes), backing it up remotely or onto a smaller drive becomes impractical. These scripts convert your library to OGG Vorbis at quality level 10 — transparent quality that is indistinguishable from lossless to most listeners — while cutting file sizes significantly.

The workflow is:

1. **First run** — `music_convert.sh` converts your entire library.
2. **Ongoing** — `music_convert_update.sh` runs on a schedule (e.g. via cron) and only converts files that are new or have changed since the last run.
3. **Housekeeping** — `music_files_cleanup.sh` removes OGG files from the backup whose source files no longer exist (e.g. you replaced MP3 rips with FLAC rips and deleted the old folder).

---

## Scripts

### `music_convert.sh` — Full batch conversion

Converts every supported audio file found under `MUSIC_DIR` to OGG Vorbis and writes the results to `BACKUP_DIR`, preserving the original directory structure.

**Use this for:**
- The initial conversion of your library.
- Rebuilding the backup from scratch.

**Key behaviours:**
- Mirrors the source directory tree exactly in the backup location.
- Runs multiple FFmpeg jobs in parallel (configurable via `PARALLEL_JOBS`).
- Removes partial output files if a conversion fails, so a re-run will retry them cleanly.
- Prints a failure summary at the end if any files could not be converted.

---

### `music_convert_update.sh` — Incremental update

Scans the source library and only converts files that are either missing from the backup or newer than their existing backup counterpart. All output is written to a log file.

**Use this for:**
- Scheduled runs via cron to keep the backup up to date as you add or update music.

**Key behaviours:**
- Skips any file whose `.ogg` counterpart already exists and is not outdated.
- Runs conversions in parallel (configurable via `PARALLEL_JOBS`).
- Removes partial output files on failure so they are retried on the next run.
- Rotates the log file automatically once it exceeds `MAX_LOG_SIZE` (default: 10 MB), renaming the old log to `.log.old`.

**Example cron entry** (runs nightly at 2 AM):
```
0 2 * * * /path/to/music_convert_update.sh
```

---

### `music_files_cleanup.sh` — Orphan removal

Scans the backup directory for `.ogg` files that have no corresponding source file, then deletes them. Afterwards, it removes any empty directories left behind.

**Use this for:**
- After removing or reorganising source files (e.g. deleting an MP3 folder you replaced with a FLAC rip).
- Periodic housekeeping to keep the backup in sync with the source.

**Key behaviours:**
- Checks for source files with all common audio extensions, including both lowercase and uppercase variants (e.g. `.flac` and `.FLAC`), so files on case-sensitive filesystems are not incorrectly treated as orphans.
- Repeats the empty-directory sweep in a loop until no empty directories remain, ensuring nested empty folders are fully removed and not just their innermost children.

---

## Configuration

Each script has a configuration block at the top. Set these before running.

| Variable | Description | Scripts |
|---|---|---|
| `MUSIC_DIR` | Absolute path to your source music library. No trailing slash. | All |
| `BACKUP_DIR` | Absolute path to the converted backup destination. No trailing slash. | All |
| `OGG_QUALITY` | FFmpeg Vorbis quality, `-1` to `10`. `10` is highest quality. Default: `10`. | Convert scripts |
| `PARALLEL_JOBS` | Number of simultaneous FFmpeg processes. Match to your CPU core count. Default: `4`. | Convert scripts |
| `LOG_FILE` | Absolute path to the log file. | Update & cleanup scripts |
| `MAX_LOG_SIZE` | Log file size in bytes before rotation. Default: `10485760` (10 MB). | Update script |

---

## Supported Source Formats

The scripts will find and convert files with the following extensions (case-insensitive):

`mp3` `wav` `flac` `aac` `m4a` `m4b` `wma` `alac` `aiff` `aif` `ape` `opus`

---

## Requirements

- **FFmpeg** — must be installed and available on your `PATH`.
  - Debian/Ubuntu: `sudo apt install ffmpeg`
  - macOS (Homebrew): `brew install ffmpeg`
- **Bash 4.0+** — required for `mapfile` used in the cleanup script.
  - macOS ships with Bash 3 by default. Install a newer version via Homebrew: `brew install bash`
- **GNU `xargs`** — the `-P` (parallel) flag is used for concurrent jobs. This is standard on Linux. macOS users should install `findutils` via Homebrew: `brew install findutils`

---

## A Note on the Regex Fix

The original scripts used a `find -regex` pattern like `.+[mp3|wav|flac|...]$`. In a regular expression, square brackets denote a *character class* — a set of individual characters to match, not whole words. The pipe `|` inside brackets is treated as a literal pipe character, not an alternation operator. The result was that the pattern matched files whose names ended in any single character from that set (m, p, 3, w, a, v, etc.), which was almost certainly matching far more files than intended and missing others entirely.

The corrected approach uses `-iname "*.ext"` predicates joined with `-o` (OR), which is the standard, reliable, and case-insensitive way to filter by extension in `find`.
