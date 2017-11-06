Param(
    [string]$gamePath # the path to your XCOM 2 installation ending in "XCOM 2"
)

Start-Process `
    -WorkingDirectory "$gamePath/Binaries/Win64/Launcher" `
    -FilePath "ModLauncherWPF.exe" `
    -ArgumentList "-allowconsole", "-log", "-autodebug", "-NoStartupMovies" `
    -Wait