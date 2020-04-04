$mainAccountId = "302126813"
$steamPath = ""  # steam location
$csgoProfileLocation = Join-Path "730" "local"
$csgoCfgName = "cfg"
$csgoCfgDownloadUrl = "https://thagki9.com/csgo/cfg.zip"

try {
    $properties = Get-ItemProperty -Path HKCU:\Software\Valve\Steam
    $steamPath = $properties.SteamPath
}
catch {
    Write-Error "Steam doesn't exist in Registry"
}

if ($steamPath -eq "") {
    $steamPath = Read-Host -Prompt "Steam path"
}

$steamProfileFolder = Join-Path $steamPath "userdata"
Write-Host "Steam user data folder: $steamProfileFolder"
$mainProfileFolder = Join-Path (Join-Path $steamProfileFolder $mainAccountId) $csgoProfileLocation
$mainProfilePath = Join-Path $mainProfileFolder $csgoCfgName

if (Test-Path $mainProfilePath) {
    Write-Host "Main account profile exists"
}
else {
    Write-Host "Main account profile doesn't exist"
    $downloadPath = Join-Path $env:TEMP "CSGOCFG-$(Get-Date -Format "yyyy-MM-dd").zip"
    Write-Host "Profile will be download to $downloadPath"
    Invoke-WebRequest -Uri $csgoCfgDownloadUrl -OutFile $downloadPath
    Write-Host "Profile downloaded"

    New-Item -ItemType Directory -Path $mainProfilePath -ErrorAction SilentlyContinue
    Expand-Archive -Path $downloadPath -DestinationPath $mainProfilePath
}

Get-ChildItem $steamProfileFolder | ForEach-Object {
    $profileId = $_.Name
    if ($profileId -eq $mainAccountId) {
        return
    }

    $profileFolder = Join-Path (Join-Path $steamProfileFolder $profileId) $csgoProfileLocation
    $profilePath = Join-Path $profileFolder $csgoCfgName
    if (Test-Path $profilePath) {
        Write-Verbose "User $profileId already exists"
        return
    } 

    New-Item -ItemType Directory -Path $profileFolder -ErrorAction SilentlyContinue
    New-Item -ItemType SymbolicLink -Path $profilePath -Value $mainProfile
}

    
