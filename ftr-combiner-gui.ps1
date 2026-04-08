<#
.SYNOPSIS
    Combines multiple FTR .trm audio recording files into a single file.

.DESCRIPTION
    FTR (For The Record) recording systems split court sessions into many
    small .trm files. This GUI tool merges them into one file in the correct
    playback order so the full session can be processed by audio transcription
    tools without handling each segment individually.

    File ordering is determined by the .trs session metadata file when present
    (authoritative), or by the timestamp embedded in each filename as a fallback.

.NOTES
    Requires: Windows PowerShell 5.1 or PowerShell 7+ on Windows
    UI framework: Windows Forms (Windows only)
#>
#Requires -Version 5.0
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

#region ── Helpers ───────────────────────────────────────────────────────────

function Get-OrderedTrmFiles {
<#
    .SYNOPSIS
        Returns .trm file paths from a folder in the correct playback order.
    .DESCRIPTION
        Reads the .trs XML metadata file to get the authoritative MediaFiles
        sequence. Falls back to alphabetical sort of filenames, which works
        because FTR embeds a YYYYMMDD-HHMM timestamp at the start of each name.
    .PARAMETER FolderPath
        Path to the folder containing .trm (and optionally .trs) files.
    .OUTPUTS
        System.String[] — ordered array of full file paths.
#>
    param([string]$FolderPath)

    # Prefer .trs file ordering (authoritative MediaFiles sequence)
    $trsFile = Get-ChildItem -Path $FolderPath -Filter "*.trs" | Select-Object -First 1
    if ($trsFile) {
        try {
            $xml = [xml](Get-Content -Path $trsFile.FullName -Encoding Unicode)
            $names = $xml.ContentFile.MediaFiles.MediaFile |
                     ForEach-Object { $_.Name }
            $ordered = @()
            foreach ($name in $names) {
                $fullPath = Join-Path $FolderPath $name
                if (Test-Path $fullPath) { $ordered += $fullPath }
            }
            if ($ordered.Count -gt 0) { return $ordered }
        } catch { }
    }

    # Fallback: sort by timestamp embedded in filename (YYYYMMDD-HHMM_HEXID)
    return Get-ChildItem -Path $FolderPath -Filter "*.trm" |
           Sort-Object { $_.BaseName } |
           Select-Object -ExpandProperty FullName
}

function Format-FileSize {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N1} MB" -f ($Bytes / 1MB) }
    return "{0:N0} KB" -f ($Bytes / 1KB)
}

function Combine-TrmFiles {
<#
    .SYNOPSIS
        Concatenates an ordered list of .trm files into a single output file.
    .DESCRIPTION
        Streams each source file into the output in 1 MB chunks, updating the
        progress bar and status label as each file is written. Cleans up the
        partial output file if an error occurs mid-combine.
    .PARAMETER SourceFiles
        Ordered array of full paths to the .trm files to combine.
    .PARAMETER OutputPath
        Full path for the combined output .trm file.
    .PARAMETER ProgressBar
        Windows Forms ProgressBar control to update during the operation.
    .PARAMETER StatusLabel
        Windows Forms Label control to display the current filename being written.
#>
    param(
        [string[]]$SourceFiles,
        [string]$OutputPath,
        [System.Windows.Forms.ProgressBar]$ProgressBar,
        [System.Windows.Forms.Label]$StatusLabel
    )

    $total = ($SourceFiles | ForEach-Object { (Get-Item $_).Length } | Measure-Object -Sum).Sum
    $written = 0
    $bufferSize = 1MB

    $outStream = [System.IO.File]::OpenWrite($OutputPath)
    try {
        $buffer = New-Object byte[] $bufferSize
        foreach ($file in $SourceFiles) {
            $StatusLabel.Text = "Combining: $([System.IO.Path]::GetFileName($file))"
            $StatusLabel.Refresh()
            $inStream = [System.IO.File]::OpenRead($file)
            try {
                $read = 0
                while (($read = $inStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                    $outStream.Write($buffer, 0, $read)
                    $written += $read
                    if ($total -gt 0) {
                        $ProgressBar.Value = [int][Math]::Min(100, ($written / $total * 100))
                    }
                    [System.Windows.Forms.Application]::DoEvents()
                }
            } finally {
                $inStream.Close()
            }
        }
    } finally {
        $outStream.Close()
    }
}

#endregion

#region ── Build UI ──────────────────────────────────────────────────────────

$form = New-Object System.Windows.Forms.Form
$form.Text = "FTR TRM File Combiner"
$form.Size = New-Object System.Drawing.Size(640, 500)
$form.MinimumSize = New-Object System.Drawing.Size(520, 440)
$form.StartPosition = "CenterScreen"
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

# ── Folder row ───────────────────────────────────────────────────────────────
$lblFolder = New-Object System.Windows.Forms.Label
$lblFolder.Text = "Source Folder:"
$lblFolder.Location = New-Object System.Drawing.Point(12, 16)
$lblFolder.AutoSize = $true

$txtFolder = New-Object System.Windows.Forms.TextBox
$txtFolder.Location = New-Object System.Drawing.Point(12, 34)
$txtFolder.Size = New-Object System.Drawing.Size(510, 23)
$txtFolder.Anchor = "Top,Left,Right"
$txtFolder.ReadOnly = $true

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "Browse…"
$btnBrowse.Location = New-Object System.Drawing.Point(530, 33)
$btnBrowse.Size = New-Object System.Drawing.Size(82, 25)
$btnBrowse.Anchor = "Top,Right"

# ── File list ────────────────────────────────────────────────────────────────
$lblFiles = New-Object System.Windows.Forms.Label
$lblFiles.Text = "Files to combine (in order):"
$lblFiles.Location = New-Object System.Drawing.Point(12, 70)
$lblFiles.AutoSize = $true

$lstFiles = New-Object System.Windows.Forms.ListBox
$lstFiles.Location = New-Object System.Drawing.Point(12, 88)
$lstFiles.Size = New-Object System.Drawing.Size(600, 240)
$lstFiles.Anchor = "Top,Left,Right,Bottom"
$lstFiles.HorizontalScrollbar = $true

# ── Output row ───────────────────────────────────────────────────────────────
$lblOutput = New-Object System.Windows.Forms.Label
$lblOutput.Text = "Output File:"
$lblOutput.Anchor = "Bottom,Left"
$lblOutput.AutoSize = $true

$txtOutput = New-Object System.Windows.Forms.TextBox
$txtOutput.Anchor = "Bottom,Left,Right"
$txtOutput.ReadOnly = $true

$btnOutputBrowse = New-Object System.Windows.Forms.Button
$btnOutputBrowse.Text = "Save As…"
$btnOutputBrowse.Anchor = "Bottom,Right"
$btnOutputBrowse.Size = New-Object System.Drawing.Size(82, 25)

# ── Progress ─────────────────────────────────────────────────────────────────
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Anchor = "Bottom,Left,Right"
$progressBar.Minimum = 0
$progressBar.Maximum = 100

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "Select a folder to begin."
$lblStatus.Anchor = "Bottom,Left,Right"
$lblStatus.AutoSize = $false

# ── Combine button ────────────────────────────────────────────────────────────
$btnCombine = New-Object System.Windows.Forms.Button
$btnCombine.Text = "Combine Files"
$btnCombine.Anchor = "Bottom,Right"
$btnCombine.Size = New-Object System.Drawing.Size(110, 30)
$btnCombine.Enabled = $false
$btnCombine.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
$btnCombine.ForeColor = [System.Drawing.Color]::White
$btnCombine.FlatStyle = "Flat"

# ── Layout via TableLayoutPanel ──────────────────────────────────────────────
$table = New-Object System.Windows.Forms.TableLayoutPanel
$table.Dock = "Fill"
$table.ColumnCount = 1
$table.RowCount = 8
$table.Padding = New-Object System.Windows.Forms.Padding(8)

[void]$table.RowStyles.Add((New-Object System.Windows.Forms.RowStyle("AutoSize")))   # lblFolder
[void]$table.RowStyles.Add((New-Object System.Windows.Forms.RowStyle("AutoSize")))   # folder row
[void]$table.RowStyles.Add((New-Object System.Windows.Forms.RowStyle("AutoSize")))   # lblFiles
[void]$table.RowStyles.Add((New-Object System.Windows.Forms.RowStyle("Percent", 100))) # lstFiles
[void]$table.RowStyles.Add((New-Object System.Windows.Forms.RowStyle("AutoSize")))   # lblOutput
[void]$table.RowStyles.Add((New-Object System.Windows.Forms.RowStyle("AutoSize")))   # output row
[void]$table.RowStyles.Add((New-Object System.Windows.Forms.RowStyle("AutoSize")))   # progress
[void]$table.RowStyles.Add((New-Object System.Windows.Forms.RowStyle("AutoSize")))   # status + button

# Folder label
$table.Controls.Add($lblFolder, 0, 0)

# Folder input panel
$folderPanel = New-Object System.Windows.Forms.TableLayoutPanel
$folderPanel.Dock = "Fill"
$folderPanel.ColumnCount = 2
$folderPanel.RowCount = 1
$folderPanel.AutoSize = $true
[void]$folderPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle("Percent", 100)))
[void]$folderPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle("AutoSize")))
$folderPanel.Controls.Add($txtFolder, 0, 0)
$folderPanel.Controls.Add($btnBrowse, 1, 0)
$table.Controls.Add($folderPanel, 0, 1)

# Files label
$table.Controls.Add($lblFiles, 0, 2)

# Files list
$lstFiles.Dock = "Fill"
$table.Controls.Add($lstFiles, 0, 3)

# Output label
$table.Controls.Add($lblOutput, 0, 4)

# Output input panel
$outputPanel = New-Object System.Windows.Forms.TableLayoutPanel
$outputPanel.Dock = "Fill"
$outputPanel.ColumnCount = 2
$outputPanel.RowCount = 1
$outputPanel.AutoSize = $true
[void]$outputPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle("Percent", 100)))
[void]$outputPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle("AutoSize")))
$outputPanel.Controls.Add($txtOutput, 0, 0)
$outputPanel.Controls.Add($btnOutputBrowse, 1, 0)
$table.Controls.Add($outputPanel, 0, 5)

# Progress bar
$progressBar.Dock = "Fill"
$table.Controls.Add($progressBar, 0, 6)

# Status + Combine button panel
$bottomPanel = New-Object System.Windows.Forms.TableLayoutPanel
$bottomPanel.Dock = "Fill"
$bottomPanel.ColumnCount = 2
$bottomPanel.RowCount = 1
$bottomPanel.AutoSize = $true
[void]$bottomPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle("Percent", 100)))
[void]$bottomPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle("AutoSize")))
$lblStatus.Dock = "Fill"
$bottomPanel.Controls.Add($lblStatus, 0, 0)
$bottomPanel.Controls.Add($btnCombine, 1, 0)
$table.Controls.Add($bottomPanel, 0, 7)

$form.Controls.Add($table)

#endregion

#region ── Script-level state ────────────────────────────────────────────────
$script:orderedFiles = @()
#endregion

#region ── Event Handlers ────────────────────────────────────────────────────

$btnBrowse.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = "Select the folder containing .trm files"
    $dlg.ShowNewFolderButton = $false
    if ($txtFolder.Text -and (Test-Path $txtFolder.Text)) {
        $dlg.SelectedPath = $txtFolder.Text
    }
    if ($dlg.ShowDialog() -eq "OK") {
        $txtFolder.Text = $dlg.SelectedPath
        $lstFiles.Items.Clear()
        $txtOutput.Text = ""
        $btnCombine.Enabled = $false
        $progressBar.Value = 0

        $script:orderedFiles = Get-OrderedTrmFiles -FolderPath $dlg.SelectedPath
        if ($script:orderedFiles.Count -eq 0) {
            $lblStatus.Text = "No .trm files found in the selected folder."
            return
        }

        $totalBytes = 0L
        foreach ($f in $script:orderedFiles) {
            $item = Get-Item $f
            $totalBytes += $item.Length
            $lstFiles.Items.Add("$($item.Name)  ($(Format-FileSize $item.Length))")
        }

        # Suggest output filename based on first file's base name up to the date-time part
        $firstName = [System.IO.Path]::GetFileNameWithoutExtension($script:orderedFiles[0])
        # Strip trailing _HEXID to get a clean base
        $suggestedBase = $firstName -replace '_[0-9a-f]{16}$', ''
        $suggestedOut = Join-Path $dlg.SelectedPath ($suggestedBase + "_combined.trm")
        $txtOutput.Text = $suggestedOut

        $trsPresent = (Get-ChildItem $dlg.SelectedPath -Filter "*.trs").Count -gt 0
        $orderSource = if ($trsPresent) { "order from .trs" } else { "order by filename" }
        $lblStatus.Text = "$($script:orderedFiles.Count) files  •  $(Format-FileSize $totalBytes) total  •  $orderSource"
        $btnCombine.Enabled = $true
    }
})

$btnOutputBrowse.Add_Click({
    $dlg = New-Object System.Windows.Forms.SaveFileDialog
    $dlg.Title = "Save Combined TRM File"
    $dlg.Filter = "FTR Media files (*.trm)|*.trm|All files (*.*)|*.*"
    $dlg.DefaultExt = "trm"
    if ($txtOutput.Text) {
        $dlg.InitialDirectory = [System.IO.Path]::GetDirectoryName($txtOutput.Text)
        $dlg.FileName = [System.IO.Path]::GetFileName($txtOutput.Text)
    }
    if ($dlg.ShowDialog() -eq "OK") {
        $txtOutput.Text = $dlg.FileName
    }
})

$btnCombine.Add_Click({
    if ($script:orderedFiles.Count -eq 0) { return }
    $outputPath = $txtOutput.Text.Trim()
    if (-not $outputPath) {
        [System.Windows.Forms.MessageBox]::Show(
            "Please specify an output file path.", "Output Required",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        return
    }

    # Warn if output would overwrite a source file
    $resolvedOut = [System.IO.Path]::GetFullPath($outputPath)
    foreach ($f in $script:orderedFiles) {
        if ([System.IO.Path]::GetFullPath($f) -eq $resolvedOut) {
            [System.Windows.Forms.MessageBox]::Show(
                "The output file cannot be the same as one of the source files.",
                "Invalid Output", [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
            return
        }
    }

    $btnCombine.Enabled = $false
    $btnBrowse.Enabled = $false
    $progressBar.Value = 0

    try {
        Combine-TrmFiles -SourceFiles $script:orderedFiles -OutputPath $outputPath `
            -ProgressBar $progressBar -StatusLabel $lblStatus

        $progressBar.Value = 100
        $outSize = Format-FileSize (Get-Item $outputPath).Length
        $lblStatus.Text = "Done! Combined file: $outSize  →  $([System.IO.Path]::GetFileName($outputPath))"

        $result = [System.Windows.Forms.MessageBox]::Show(
            "Combined file created successfully:`n$outputPath`n`nOpen containing folder?",
            "Success", [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Information)
        if ($result -eq "Yes") {
            Start-Process explorer.exe -ArgumentList "/select,`"$outputPath`""
        }
    } catch {
        $lblStatus.Text = "Error: $_"
        [System.Windows.Forms.MessageBox]::Show(
            "An error occurred while combining files:`n$_", "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        if (Test-Path $outputPath) { Remove-Item $outputPath -Force }
    } finally {
        $btnCombine.Enabled = $true
        $btnBrowse.Enabled = $true
    }
})

#endregion

[void]$form.ShowDialog()
