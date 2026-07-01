$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = Join-Path $root 'index.html'
$out = Join-Path $root 'index-standalone.html'

$html = [IO.File]::ReadAllText($src)
$assetPattern = '(?<=\")(Assets/[^\"\r\n]+)(?=\")|(?<=\x27)(Assets/[^\x27\r\n]+)(?=\x27)'
$transparent = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aF9sAAAAASUVORK5CYII='
$missingAssets = New-Object System.Collections.Generic.List[string]
$missingFonts = New-Object System.Collections.Generic.List[string]
$userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36'

function Get-MimeType([string]$pathOrUrl) {
  $clean = ($pathOrUrl -split '\?')[0]
  switch ([IO.Path]::GetExtension($clean).ToLowerInvariant()) {
    '.png' { return 'image/png' }
    '.jpg' { return 'image/jpeg' }
    '.jpeg' { return 'image/jpeg' }
    '.gif' { return 'image/gif' }
    '.svg' { return 'image/svg+xml' }
    '.webp' { return 'image/webp' }
    '.woff2' { return 'font/woff2' }
    '.woff' { return 'font/woff' }
    '.ttf' { return 'font/ttf' }
    '.otf' { return 'font/otf' }
    default { return 'application/octet-stream' }
  }
}

function Get-RemoteBytes([string]$url) {
  $response = Invoke-WebRequest -Uri $url -UseBasicParsing -Headers @{ 'User-Agent' = $userAgent }
  return $response.Content
}

function Inline-RemoteFonts([string]$content) {
  $importPattern = '@import\s+url\((["'']?)(?<url>https://fonts\.googleapis\.com/[^)"'']+)\1\)\s*;'
  $imports = [regex]::Matches($content, $importPattern)
  foreach ($import in $imports) {
    $importLine = $import.Value
    $cssUrl = $import.Groups['url'].Value
    try {
      $fontCss = (Invoke-WebRequest -Uri $cssUrl -UseBasicParsing -Headers @{ 'User-Agent' = $userAgent }).Content
      $fontUrls = [regex]::Matches($fontCss, 'url\((["'']?)(?<url>https://fonts\.gstatic\.com/[^)"'']+)\1\)') |
        ForEach-Object { $_.Groups['url'].Value } |
        Sort-Object -Unique

      foreach ($fontUrl in $fontUrls) {
        try {
          $fontBytes = Get-RemoteBytes $fontUrl
          if ($fontBytes -is [string]) {
            $fontBytes = [Text.Encoding]::ASCII.GetBytes($fontBytes)
          }
          $fontData = 'data:{0};base64,{1}' -f (Get-MimeType $fontUrl), ([Convert]::ToBase64String($fontBytes))
          $fontCss = $fontCss.Replace($fontUrl, $fontData)
        }
        catch {
          $missingFonts.Add($fontUrl)
        }
      }

      $content = $content.Replace($importLine, $fontCss)
    }
    catch {
      $missingFonts.Add($cssUrl)
      $content = $content.Replace($importLine, '')
    }
  }

  return $content
}

$html = Inline-RemoteFonts $html

$assetRefs = [regex]::Matches($html, $assetPattern) |
  ForEach-Object { $_.Value.Trim() } |
  Sort-Object -Unique

foreach ($rel in $assetRefs) {
  $full = Join-Path $root $rel
  if (-not (Test-Path -LiteralPath $full)) {
    $full = Join-Path $root ($rel -replace '/', '\')
  }
  if (-not (Test-Path -LiteralPath $full)) {
    $html = $html.Replace($rel, $transparent)
    $missingAssets.Add($rel)
    continue
  }
  if ((Get-Item -LiteralPath $full).PSIsContainer) {
    continue
  }

  $bytes = [IO.File]::ReadAllBytes($full)
  $b64 = [Convert]::ToBase64String($bytes)
  $mime = Get-MimeType $full
  $dataUrl = 'data:{0};base64,{1}' -f $mime, $b64
  $html = $html.Replace($rel, $dataUrl)
}

[IO.File]::WriteAllText($out, $html, [Text.UTF8Encoding]::new($false))

$item = Get-Item $out
Write-Output ("Wrote: {0}" -f $item.FullName)
Write-Output ("Size: {0} bytes" -f $item.Length)
if ($missingAssets.Count -gt 0) {
  Write-Warning ("Missing asset references replaced with transparent placeholders: {0}" -f ($missingAssets -join ', '))
}
if ($missingFonts.Count -gt 0) {
  Write-Warning ("Font resources could not be embedded and were removed from the standalone file: {0}" -f ($missingFonts -join ', '))
}
