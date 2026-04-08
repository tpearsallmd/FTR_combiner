# FTR Combiner

A simple Windows utility that merges multiple For The Record (FTR) audio recording files from a single court session into one combined file, making it easy to process the full session with audio transcription tools.

## Background

FTR recording systems commonly split a single court session across many small `.trm` files. Processing these individually is tedious and error-prone. FTR Combiner reads the session's file order from the FTR metadata (`.trs` file) and concatenates the `.trm` files into a single output file in the correct sequence, ready for transcription.

## Requirements

- Windows 10 or Windows 11
- **Windows PowerShell 5.1** (built into Windows 10/11 — no installation needed), **or PowerShell 7+** on Windows

> No compiled executable is distributed in this repo. Running the PowerShell script directly is the simplest option; building an `.exe` is optional and covered below.

## Usage

### Option 1 — Run the script directly (recommended)

Open PowerShell and run:

```powershell
.\ftr-combiner-gui.ps1
```

If your execution policy blocks scripts, allow it for the current session first:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\ftr-combiner-gui.ps1
```

### Option 2 — Build a standalone executable

If you prefer a double-clickable `.exe`, compile it yourself using [ps2exe](https://github.com/MScholtes/PS2EXE):

```powershell
# Install ps2exe if you haven't already
Install-Module ps2exe -Scope CurrentUser

# Allow scripts for this session, then compile
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
Invoke-ps2exe .\ftr-combiner-gui.ps1 .\ftr-combiner.exe -noConsole
```

The resulting `ftr-combiner.exe` can be run on any Windows 10/11 machine without PowerShell being visible to the user.

## Using the tool

1. Click **Browse** and select the folder containing your `.trm` files
2. The tool displays the files in the correct playback order
3. Choose an output location (a suggested filename is pre-filled)
4. Click **Combine Files**

The combined `.trm` file can then be loaded into any transcription tool that supports the FTR format.

## File Ordering

FTR Combiner determines the correct file order using the following logic:

- **Primary:** reads the `.trs` metadata file in the source folder, which contains the authoritative sequence of media files for the session
- **Fallback:** if no `.trs` file is present, files are sorted by the timestamp embedded in their filenames (`YYYYMMDD-HHMM_...`)
