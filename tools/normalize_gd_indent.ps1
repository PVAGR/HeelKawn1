Param(
    [string[]]$Files
)

if (-not $Files -or $Files.Count -eq 0) {
    Write-Error "Usage: .\normalize_gd_indent.ps1 <file1.gd> [file2.gd ...]"
    exit 2
}

foreach ($f in $Files) {
    if (-not (Test-Path $f)) { Write-Warning "Missing: $f"; continue }
    $text = Get-Content -Raw -Encoding UTF8 $f
    if ($text -notmatch "`t") { Write-Host "Skipping (no tabs present): $f"; continue }
    if (-not [regex]::IsMatch($text, '^( +)', 'Multiline')) { Write-Host "No leading spaces to convert: $f"; continue }

    # Replace leading groups of 4 spaces with a tab, repeatedly to handle deep indents
    $lines = $text -split "`n"
    $changed = $false
    for ($i=0; $i -lt $lines.Length; $i++) {
        $line = $lines[$i]
        if ($line -match '^( +)') {
            $leading = $matches[1]
            # Only convert if file already contains tabs (we detected above) to avoid switching pure-space files
            $newLeading = $leading -replace ' {4}', "`t"
            if ($newLeading -ne $leading) {
                $lines[$i] = $newLeading + $line.Substring($leading.Length)
                $changed = $true
            }
        }
    }

    if ($changed) {
        $out = $lines -join "`n"
        Set-Content -LiteralPath $f -Value $out -Encoding UTF8
        Write-Host "Normalized: $f"
    } else {
        Write-Host "No changes needed: $f"
    }
}
