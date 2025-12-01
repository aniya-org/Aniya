param(
    [Parameter(Mandatory = $true)]
    [string]$BundlePath
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -Path $BundlePath)) {
    Write-Error "Bundle path '$BundlePath' does not exist. Pass the folder that contains aniya.exe."
}

$bundleFullPath = Resolve-Path $BundlePath
$exePath = Join-Path $bundleFullPath "aniya.exe"

if (-not (Test-Path -Path $exePath)) {
    Write-Error "Could not find aniya.exe under '$bundleFullPath'. Build the Windows bundle first (e.g. flutter build windows)."
}

$schemes = @('aniyomi', 'tachiyomi', 'mangayomi', 'dar', 'cloudstreamrepo')

foreach ($scheme in $schemes) {
    $keyPath = "HKCU:\Software\Classes\$scheme"
    New-Item -Path $keyPath -Force | Out-Null
    New-ItemProperty -Path $keyPath -Name "URL Protocol" -Value "" -PropertyType String -Force | Out-Null
    Set-ItemProperty -Path $keyPath -Name "(default)" -Value "URL:$scheme handler"

    $commandKey = Join-Path $keyPath "shell\open\command"
    New-Item -Path $commandKey -Force | Out-Null
    $command = '"' + $exePath + '" "%1"'
    Set-ItemProperty -Path $commandKey -Name "(default)" -Value $command
}

Write-Host "Registered desktop deep link handler for schemes: $($schemes -join ', ')."
Write-Host "Executable: $exePath"
Write-Host "To remove, delete the keys under HKCU:\Software\Classes for each scheme."
