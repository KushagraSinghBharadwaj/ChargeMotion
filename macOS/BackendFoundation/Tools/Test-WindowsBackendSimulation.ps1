$ErrorActionPreference = 'Stop'

$passed = 0
$failed = 0

function Test-Case {
    param(
        [string]$Name,
        [string]$Expected,
        [string]$Actual
    )

    if ($Expected -eq $Actual) {
        Write-Host "[PASS] $Name" -ForegroundColor Green
        $script:passed++
    }
    else {
        Write-Host "[FAIL] $Name - Expected: $Expected | Actual: $Actual" -ForegroundColor Red
        $script:failed++
    }
}

function Get-WallpaperRole {
    param([string]$PowerState)

    switch ($PowerState) {
        'charging' { return 'charging' }
        'fullyCharged' { return 'charging' }
        'externalPowerNotCharging' { return 'charging' }
        'onBattery' { return 'battery' }
        default { return 'none' }
    }
}

function Get-PlaybackState {
    param(
        [string]$Role,
        [bool]$ManualPause,
        [bool]$MediaExists
    )

    if (!$MediaExists) { return 'missingMedia' }
    if ($ManualPause) { return 'paused' }
    if ($Role -eq 'none') { return 'stopped' }

    return 'playing'
}

Write-Host "`nCHARGEMOTION WINDOWS BACKEND SIMULATION" -ForegroundColor Cyan
Write-Host "======================================="

Test-Case 'Charging selects charging wallpaper' `
    'charging' (Get-WallpaperRole 'charging')

Test-Case 'Battery selects battery wallpaper' `
    'battery' (Get-WallpaperRole 'onBattery')

Test-Case 'Fully charged selects charging wallpaper' `
    'charging' (Get-WallpaperRole 'fullyCharged')

Test-Case 'External power selects charging wallpaper' `
    'charging' (Get-WallpaperRole 'externalPowerNotCharging')

Test-Case 'Unknown power state selects no wallpaper' `
    'none' (Get-WallpaperRole 'unknown')

Test-Case 'Manual pause pauses playback' `
    'paused' (Get-PlaybackState 'charging' $true $true)

Test-Case 'Missing media is detected' `
    'missingMedia' (Get-PlaybackState 'charging' $false $false)

Test-Case 'Battery wallpaper plays normally' `
    'playing' (Get-PlaybackState 'battery' $false $true)

Test-Case 'Unknown power state stops playback' `
    'stopped' (Get-PlaybackState 'none' $false $true)

Write-Host "`n======================================="
Write-Host "RESULTS" -ForegroundColor Cyan
Write-Host "Passed: $passed" -ForegroundColor Green
Write-Host "Failed: $failed" -ForegroundColor Red

if ($failed -gt 0) {
    exit 1
}

Write-Host "`nAll simulation tests passed." -ForegroundColor Green
