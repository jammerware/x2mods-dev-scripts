Param(
    [string]$mod, # your mod's name - this shouldn't have spaces or special characters, and it's usually the name of the first directory inside your mod's source dir
    [string]$srcDirectory, # the path that contains your mod's .XCOM_sln
    [string]$sdkPath, # the path to your SDK installation ending in "XCOM 2 War of the Chosen SDK"
    [string]$gamePath, # the path to your XCOM 2 installation ending in "XCOM 2"
    [bool]$forceFullBuild = $false # force the script to rebuild the base game's scripts, even if they're already built
)

function WriteModMetadata([string]$mod, [string]$sdkPath, [int]$publishedId, [string]$title, [string]$description) {
    Set-Content "$sdkPath/XComGame/Mods/$mod/$mod.XComMod" "[mod]`npublishedFileId=$publishedId`nTitle=$title`nDescription=$description`nRequiresXPACK=true"
}

function StageDirectory ([string]$directoryName, [string]$srcDirectory, [string]$targetDirectory) {
    Write-Host "Staging mod $directoryName from source ($srcDirectory/$directoryName) to staging ($targetDirectory/$directoryName)..."

    if (Test-Path "$srcDirectory/$directoryName") {
        Copy-Item "$srcDirectory/$directoryName" "$targetDirectory/$directoryName" -Recurse -WarningAction SilentlyContinue
        Write-Host "Staged."
    }
    else {
        Write-Host "Mod doesn't have any $directoryName."
    }
}

function CheckErrorCode([string] $message) {
    if ($LASTEXITCODE -ne 0) {
        throw $message;
    }
}

# Helper for invoking the make cmdlet. Captures stdout/stderr and rewrites error and warning lines to fix up the
# source paths. Since make operates on a copy of the sources copied to the SDK folder, diagnostics print the paths
# to the copies. If you try to jump to these files (e.g. by tying this output to the build commands in your editor)
# you'll be editting the copies, which will then be overwritten the next time you build with the sources in your mod folder
# that haven't been changed.
function Launch-Make([string] $makeCmd, [string] $makeFlags, [string] $sdkPath, [string] $modSrcRoot) {
    # Create a ProcessStartInfo object to hold the details of the make command, its arguments, and set up
    # stdout/stderr redirection.
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $makeCmd
    $pinfo.RedirectStandardOutput = $true
    $pinfo.RedirectStandardError = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = $makeFlags

    # Create an object to hold the paths we want to rewrite: the path to the SDK 'Development' folder
    # and the 'modSrcRoot' (the directory that holds the .x2proj file). This is needed because the output
    # is read in an action block that is a separate scope and has no access to local vars/parameters of this
    # function.
    $developmentDirectory = Join-Path -Path $sdkPath 'Development'
    $messageData = New-Object psobject -property @{
        developmentDirectory = $developmentDirectory;
        modSrcRoot = $modSrcRoot
    }

    # We need another object for the Exited event to set a flag we can monitor from this function.
    $exitData = New-Object psobject -property @{ exited = $false }

    # An action for handling data written to stdout. The make cmdlet writes all warning and error info to
    # stdout, so we look for it here.
    $outAction = {
        $outTxt = $Event.SourceEventArgs.Data
        # Match warning/error lines
        if ($outTxt -Match "Error|Warning") {
            # And just do a regex replace on the sdk Development directory with the mod src directory.
            # The pattern needs escaping to avoid backslashes in the path being interpreted as regex escapes, etc.
            $pattern = [regex]::Escape($event.MessageData.developmentDirectory)
            # n.b. -Replace is case insensitive
            $replacementTxt = $outtxt -Replace $pattern, $event.MessageData.modSrcRoot
            Write-Host $replacementTxt
        } else {
            Write-Host $outTxt
        }
    }

    # An action for handling data written to stderr. The make cmdlet doesn't seem to write anything here,
    # or at least not diagnostics, so we can just pass it through.
    $errAction = {
        $errTxt = $Event.SourceEventArgs.Data
        Write-Host $errTxt
    }

    # Set the exited flag on our exit object on process exit.
    $exitAction = {
        $event.MessageData.exited = $true
    }

    # Create the process and register for the various events we care about.
    $process = New-Object System.Diagnostics.Process
    Register-ObjectEvent -InputObject $process -EventName OutputDataReceived -Action $outAction -MessageData $messageData | Out-Null
    Register-ObjectEvent -InputObject $process -EventName ErrorDataReceived -Action $errAction | Out-Null
    Register-ObjectEvent -InputObject $process -EventName Exited -Action $exitAction -MessageData $exitData | Out-Null
    $process.StartInfo = $pinfo

    # All systems go!
    $process.Start() | Out-Null
    $process.BeginOutputReadLine()
    $process.BeginErrorReadLine()

    # Wait for the process to exit. This is horrible, but using $process.WaitForExit() blocks
    # the powershell thread so we get no output from make echoed to the screen until the process finishes.
    # By polling we get regular output as it goes.
    while (!$exitData.exited) {
        Start-Sleep -m 50
    }

    # Explicitly set LASTEXITCODE from the process exit code so the rest of the script
    # doesn't need to care if we launched the process in the background or via "&".
    $global:LASTEXITCODE = $process.ExitCode
}

# alias params for clarity in the script (we don't want the person invoking this script to have to type the name -modNameCanonical)
$modNameCanonical = $mod
# we're going to ask that people specify the folder that has their .XCOM_sln in it as the -srcDirectory argument, but a lot of the time all we care about is
# the folder below that that contains Config, Localization, Src, etc...
$modSrcRoot = "$srcDirectory/$modNameCanonical"

# clean
$stagingPath = "{0}/XComGame/Mods/{1}/" -f $sdkPath, $modNameCanonical
Write-Host "Cleaning mod project at $stagingPath...";
if (Test-Path $stagingPath) {
    Remove-Item $stagingPath -Recurse -WarningAction SilentlyContinue;
}
Write-Host "Cleaned."

# copy source to staging
StageDirectory "Config" $modSrcRoot $stagingPath
StageDirectory "Content" $modSrcRoot $stagingPath
StageDirectory "Localization" $modSrcRoot $stagingPath
StageDirectory "Src" $modSrcRoot $stagingPath
New-Item "$stagingPath/Script" -ItemType Directory

# read mod metadata from the x2proj file
Write-Host "Reading mod metadata from $modSrcRoot/$modNameCanonical.x2proj..."
[xml]$x2projXml = Get-Content -Path "$modSrcRoot/$modNameCanonical.x2proj"
$modProperties = $x2projXml.Project.PropertyGroup
$modPublishedId = $modProperties.SteamPublishedId
$modTitle = $modProperties.Name
$modDescription = $modProperties.Description
Write-Host "Read."

# write mod metadata - used by Firaxis' "make" tooling
Write-Host "Writing mod metadata..."
WriteModMetadata -mod $modNameCanonical -sdkPath $sdkPath -publishedId $modPublishedId -title $modTitle -description $modDescription
Write-Host "Written."

# mirror the SDK's SrcOrig to its Src
Write-Host "Mirroring SrcOrig to Src..."
Robocopy.exe "$sdkPath/Development/SrcOrig" "$sdkPath/Development/Src" *.uc *.uci /S /E /DCOPY:DA /COPY:DAT /PURGE /MIR /NP /R:1000000 /W:30
Write-Host "Mirrored."

# copying the mod's scripts to the script staging location
Write-Host "Copying the mod's scripts to Src..."
Copy-Item "$stagingPath/Src/*" "$sdkPath/Development/Src/" -Force -Recurse -WarningAction SilentlyContinue
Write-Host "Copied."

if ($forceFullBuild) {
    # if a full build was requested, clean all compiled scripts too
    Write-Host "Full build requested. Cleaning all compiled scripts from $sdkPath/XComGame/Script..."
    Remove-Item "$sdkPath\XComGame\Script\*.u"
    Write-Host "Cleaned."
}
else {
    # clean mod's compiled script
    Write-Host "Cleaning existing mod's compiled script from $sdkPath/XComGame/Script..."

    if (Test-Path "$sdkPath\XComGame\Script\$modNameCanonical.u") {
        Remove-Item "$sdkPath\XComGame\Script\$modNameCanonical.u"
    }

    Write-Host "Cleaned."
}

# build the base game scripts
Write-Host "Compiling base game scripts..."
# This could be replaced with a Launch-Make call as well for highlanders.
& "$sdkPath/binaries/Win64/XComGame.com" make -nopause -unattended
Write-Host "Compiled."
CheckErrorCode "Failed to compile the base game scripts. This probably isn't a problem with your mod. Have you been monkeying around with SrcOrig, perchance?"

# build the mod's scripts
Write-Host "Compiling mod scripts..."
Launch-Make "$sdkPath/binaries/Win64/XComGame.com" "make -nopause -mods $modNameCanonical $stagingPath" $sdkPath $modSrcRoot
CheckErrorCode "Failed to compile mod scripts."
Write-Host "Compiled."

# build the mod's shader cache
if (Test-Path -Path "$stagingPath/Content/*" -Include *.upk, *.umap) {
    Write-Host "Precompiling mod shaders..."
    &"$sdkPath/binaries/Win64/XComGame.com" precompileshaders -nopause platform=pc_sm4 DLC=$modNameCanonical
    CheckErrorCode "Failed to precompile mod shaders."
    Write-Host "Precompiled."
}
else {
    Write-Host "Mod doesn't have any shader content. Skipping shader precompilation."
}

# copy compiled mod scripts to the staging area
Write-Host "Copying the compiled mod scripts to staging..."
Copy-Item "$sdkPath/XComGame/Script/$modNameCanonical.u" "$stagingPath/Script" -Force -WarningAction SilentlyContinue
Write-Host "Copied."

# copy all staged files to the actual game's mods folder
$productionPath = "$gamePath/XCom2-WarOfTheChosen/XComGame/Mods/"
Write-Host "Copying all staging files to production..."
if (-Not (Test-Path $productionPath)) {
    New-Item $productionPath -ItemType Directory
}
Copy-Item $stagingPath $productionPath -Force -Recurse -WarningAction SilentlyContinue
Write-Host "Copied."

# we made it!
Write-Host "*** SUCCESS! ***"
Write-Host "$modNameCanonical ready to run."
