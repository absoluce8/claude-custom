# PostToolUse hook : commit + push automatique de tout fichier modifié sous ./claude
$payload = [Console]::In.ReadToEnd() | ConvertFrom-Json
$file = $payload.tool_response.filePath ?? $payload.tool_input.file_path
if (-not $file) { exit 0 }

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$claudeDir = Join-Path $root 'claude'
$full = [IO.Path]::GetFullPath($file)
if (-not $full.StartsWith($claudeDir + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { exit 0 }

$git = Join-Path $env:LOCALAPPDATA 'Programs\Git\cmd\git.exe'
if (-not (Test-Path $git)) { $git = 'git' }
$env:GIT_TERMINAL_PROMPT = '0'
$rel = [IO.Path]::GetRelativePath($root, $full) -replace '\\', '/'

function Out-Message($msg) { @{ systemMessage = $msg } | ConvertTo-Json -Compress; exit 0 }

$out = & $git -C $root add -- $full 2>&1
if ($LASTEXITCODE -ne 0) { Out-Message "auto-commit: git add a échoué pour $rel ($out)" }

& $git -C $root diff --cached --quiet -- $full
if ($LASTEXITCODE -eq 0) { exit 0 }

$out = & $git -C $root commit -m "auto: update $rel" -- $full 2>&1
if ($LASTEXITCODE -ne 0) { Out-Message "auto-commit: commit a échoué pour $rel ($out)" }

$out = & $git -C $root push origin HEAD 2>&1
if ($LASTEXITCODE -ne 0) { Out-Message "auto-commit: $rel committé, mais le push a échoué ($out)" }

Out-Message "auto-commit: $rel committé et poussé"
