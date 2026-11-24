param(
    [Parameter(Mandatory=$true)]
    [string]$ZipPath,

    [Parameter(Mandatory=$true)]
    [string]$Version,

    [switch]$RedistributionApproved
)

$ErrorActionPreference = "Stop"

$repo = "stephanteig/snospawn-resourcepack"
$packId = "e4916c88-2ae1-4e2d-92a9-caf61d840e35"

if (-not $RedistributionApproved) {
    throw "Confirm redistribution permissions before publishing."
}

if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    throw "Version must use X.Y.Z format."
}

$tag = "v$Version"

if (-not (Test-Path -LiteralPath $ZipPath -PathType Leaf)) {
    throw "ZIP file not found: $ZipPath"
}

$ZipPath = (Resolve-Path -LiteralPath $ZipPath).Path

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "GitHub CLI is not installed."
}

gh auth status
if ($LASTEXITCODE -ne 0) {
    throw "GitHub authentication failed."
}

Add-Type -AssemblyName System.IO.Compression.FileSystem

Write-Host "Validating resource pack..." -ForegroundColor Cyan

$archive = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)

try {
    $entry = $archive.GetEntry("pack.mcmeta")

    if (-not $entry) {
        throw "Missing pack.mcmeta in ZIP root."
    }

    $reader = [System.IO.StreamReader]::new($entry.Open())

    try {
        $metadata = $reader.ReadToEnd() | ConvertFrom-Json
    }
    finally {
        $reader.Dispose()
    }

    if (-not $metadata.pack) {
        throw "Invalid pack.mcmeta."
    }

    if (-not ($archive.Entries | Where-Object {
        $_.FullName -like "assets/*" -and $_.Name
    })) {
        throw "Missing assets directory."
    }

    foreach ($item in $archive.Entries) {
        if ($item.Name) {
            $stream = $item.Open()
            try {
                $stream.CopyTo([System.IO.Stream]::Null)
            }
            finally {
                $stream.Dispose()
            }
        }
    }

    Write-Host "Pack metadata:"
    $metadata | ConvertTo-Json -Depth 10

    Write-Host "Potential credit and license files:"
    $archive.Entries | Where-Object {
        $_.FullName -match "license|credit|copyright|readme|permission"
    } | Select-Object FullName
}
finally {
    $archive.Dispose()
}

$sha1 = (Get-FileHash -LiteralPath $ZipPath -Algorithm SHA1).Hash.ToLower()

Write-Host "SHA-1: $sha1" -ForegroundColor Green

$confirmation = Read-Host "Have you verified version compatibility and documented all required credits? (yes/no)"
if ($confirmation -ne "yes") {
    throw "Publication cancelled."
}

gh release view $tag --repo $repo 2>$null | Out-Null

if ($LASTEXITCODE -eq 0) {
    throw "Release $tag already exists. Choose a new version."
}

$temp = Join-Path ([System.IO.Path]::GetTempPath()) ("snospawn-" + [guid]::NewGuid())

New-Item -ItemType Directory -Path $temp | Out-Null

try {
    $asset = Join-Path $temp "snospawn.zip"
    $downloaded = Join-Path $temp "verified.zip"

    Copy-Item -LiteralPath $ZipPath -Destination $asset

    $title = "Snøspawn Resource Pack V$Version"

    if ($Version -eq "1.0.0") {
        $title = "Snøspawn Resource Pack V1.0"
    }

    $notes = @"
Official Snøspawn resource pack.

Target Minecraft version: 26.3
Resource pack: Optional
SHA-1: $sha1
"@

    gh release create $tag $asset `
        --repo $repo `
        --title $title `
        --notes $notes

    if ($LASTEXITCODE -ne 0) {
        throw "Release creation or upload failed."
    }

    $downloadUrl = "https://github.com/$repo/releases/download/$tag/snospawn.zip"
    $releaseUrl = "https://github.com/$repo/releases/tag/$tag"

    Write-Host "Verifying public download..." -ForegroundColor Cyan

    $verified = $false

    for ($attempt = 1; $attempt -le 5; $attempt++) {
        try {
            Invoke-WebRequest `
                -Uri $downloadUrl `
                -OutFile $downloaded `
                -UseBasicParsing

            $downloadHash = (
                Get-FileHash $downloaded -Algorithm SHA1
            ).Hash.ToLower()

            if ($downloadHash -ne $sha1) {
                throw "Downloaded SHA-1 does not match."
            }

            $verified = $true
            break
        }
        catch {
            Write-Warning "Verification attempt $attempt failed."
            Start-Sleep -Seconds 3
        }
    }

    if (-not $verified) {
        throw "Release was created, but public download verification failed."
    }

    $config = @"
resource-pack=$downloadUrl
resource-pack-sha1=$sha1
resource-pack-id=$packId
resource-pack-prompt={"text":"Last ned Snøspawns offisielle resource pack for den komplette juleopplevelsen!","color":"gold"}
require-resource-pack=false
"@

    Write-Host ""
    Write-Host "PUBLICATION SUCCESSFUL" -ForegroundColor Green
    Write-Host "Repository: https://github.com/$repo"
    Write-Host "Release: $releaseUrl"
    Write-Host "Download: $downloadUrl"
    Write-Host "SHA-1: $sha1"
    Write-Host "Resource pack ID: $packId"
    Write-Host "Download verification: PASSED"

    Write-Host ""
    Write-Host "SERVER.PROPERTIES" -ForegroundColor Cyan
    Write-Host $config

    $configPath = Join-Path $PSScriptRoot "server.properties"

    [System.IO.File]::WriteAllText(
        $configPath,
        $config,
        [System.Text.UTF8Encoding]::new($false)
    )

    Write-Host ""
    Write-Host "Configuration saved to: $configPath"
}
finally {
    Remove-Item -LiteralPath $temp -Recurse -Force
}
