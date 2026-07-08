# Install Windows de claude-pc-exec (venv + token + tache planifiee au demarrage).
# Lancer dans PowerShell depuis le dossier du repo :
#   powershell -ExecutionPolicy Bypass -File .\install.ps1
$ErrorActionPreference = "Stop"
$Dest = "$env:LOCALAPPDATA\claude-pc-exec"

Write-Host ">> Copie vers $Dest"
New-Item -ItemType Directory -Force -Path $Dest | Out-Null
Copy-Item app.py, requirements.txt, .env.example $Dest -Force
if (-not (Test-Path "$Dest\.env")) { Copy-Item .env.example "$Dest\.env" }

Write-Host ">> venv + dependances"
python -m venv "$Dest\venv"
& "$Dest\venv\Scripts\pip.exe" -q install -r "$Dest\requirements.txt"

Write-Host ">> Token"
$envContent = Get-Content "$Dest\.env"
if ($envContent -match "remplacez_par") {
    $bytes = New-Object 'System.Byte[]' 32
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $tok = -join ($bytes | ForEach-Object { $_.ToString("x2") })
    (Get-Content "$Dest\.env") -replace "EXEC_API_TOKEN=.*", "EXEC_API_TOKEN=$tok" | Set-Content "$Dest\.env"
    Write-Host "   Token genere : $tok"
    Write-Host "   >>> NOTE-LE, il te faut pour Claude <<<" -ForegroundColor Yellow
}

Write-Host ">> Tache planifiee (au demarrage de session)"
$pythonw = "$Dest\venv\Scripts\pythonw.exe"
$action  = New-ScheduledTaskAction -Execute $pythonw -Argument "$Dest\app.py" -WorkingDirectory $Dest
$trigger = New-ScheduledTaskTrigger -AtLogOn
Register-ScheduledTask -TaskName "claude-pc-exec" -Action $action -Trigger $trigger -Force | Out-Null
Start-ScheduledTask -TaskName "claude-pc-exec"

Start-Sleep -Seconds 2
Write-Host ">> Test"
try { Invoke-RestMethod -Uri "http://127.0.0.1:5555/health" | ConvertTo-Json } catch { Write-Host "  (demarre dans un instant)" }
Write-Host ">> OK. Expose maintenant via tunnel : voir tunnel\quickstart-cloudflared.md"
