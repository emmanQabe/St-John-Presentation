$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = Join-Path $root 'index.html'
$out = Join-Path $root 'index-standalone.html'

$html = [IO.File]::ReadAllText($src)
$pattern = 'Assets/[^"'')]+?(?=["'')])'
$refs = [regex]::Matches($html, $pattern) | ForEach-Object { $_.Value.Trim() } | Sort-Object -Unique
$transparent = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aF9sAAAAASUVORK5CYII='
$missing = New-Object System.Collections.Generic.List[string]

function Get-MimeType([string]$path) {
  switch ([IO.Path]::GetExtension($path).ToLowerInvariant()) {
    '.png' { return 'image/png' }
    '.jpg' { return 'image/jpeg' }
    '.jpeg' { return 'image/jpeg' }
    '.gif' { return 'image/gif' }
    '.svg' { return 'image/svg+xml' }
    '.webp' { return 'image/webp' }
    default { return 'application/octet-stream' }
  }
}

foreach ($rel in $refs) {
  $full = Join-Path $root $rel
  if (-not (Test-Path -LiteralPath $full)) {
    $full = Join-Path $root ($rel -replace '/', '\')
  }
  if (-not (Test-Path -LiteralPath $full)) {
    $html = $html.Replace($rel, $transparent)
    $missing.Add($rel)
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
if ($missing.Count -gt 0) {
  Write-Warning ("Missing asset references replaced with transparent placeholders: {0}" -f ($missing -join ', '))
}
