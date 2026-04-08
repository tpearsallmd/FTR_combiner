# FTR Combiner

A simple Windows utility that merges multiple For The Record (FTR) audio recording files from a single court session into one combined file, making it easy to process the full session with audio transcription tools.

## Background

FTR recording systems commonly split a single court session across many small `.trm` files. Processing these individually is tedious and error-prone. FTR Combiner reads the session's file order from the FTR metadata (`.trs` file) and concatenates the `.trm` files into a single output file in the correct sequence, ready for transcription.

## Requirements

- Windows 10 or later

## Usage

1. Run `ftr-combiner.exe`
2. Click **Browse** and select the folder containing your `.trm` files
3. The tool will display the files in the correct playback order
4. Choose an output location (a suggested filename is pre-filled)
5. Click **Combine Files**

The combined `.trm` file can then be loaded into any transcription tool that supports the FTR format.

## File Ordering

FTR Combiner determines the correct file order using the following logic:

- **Primary:** reads the `.trs` metadata file in the source folder, which contains the authoritative sequence of media files for the session
- **Fallback:** if no `.trs` file is present, files are sorted by the timestamp embedded in their filenames (`YYYYMMDD-HHMM_...`)

## Running from Source

If you prefer to run the PowerShell script directly instead of the compiled executable:

```powershell
.\ftr-combiner-gui.ps1
```

You may need to allow script execution for the current session first:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

## Building the Executable

The `.exe` is compiled from the PowerShell script using [ps2exe](https://github.com/MScholtes/PS2EXE).

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
Invoke-ps2exe .\ftr-combiner-gui.ps1 .\ftr-combiner.exe -noConsole
```
