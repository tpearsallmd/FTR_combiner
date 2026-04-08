# Build Instructions

1. Update policies to allow PS2EXE to run

    `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`

2. Run conversion to .exe

    `Invoke-ps2exe .\ftr-combiner-gui.ps1 .\ftr-combiner.exe -noConsole`
