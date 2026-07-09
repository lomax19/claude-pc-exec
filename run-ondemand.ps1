# Mode "a la demande" Windows : lance le service + un quick tunnel cloudflared,
# affiche l'URL, et COUPE TOUT a la fermeture (Ctrl+C / fenetre fermee).
# Usage : powershell -ExecutionPolicy Bypass -File .\run-ondemand.ps1
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Get-Command cloudflared -ErrorAction SilentlyContinue)) {
    Write-Host "cloudflared manquant. Voir tunnel\quickstart-cloudflared.md"; exit 1
}

if (-not (Test-Path "venv\Scripts\python.exe")) {
    Write-Host ">> Creation venv + dependances"
    python -m venv venv
    & "venv\Scripts\pip.exe" -q install -r requirements.txt
}

if (-not (Test-Path ".env")) { Copy-Item .env.example .env }
if ((Get-Content .env) -match "remplacez_par") {
    $bytes = New-Object 'System.Byte[]' 32
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $tok = -join ($bytes | ForEach-Object { $_.ToString("x2") })
    (Get-Content .env) -replace "EXEC_API_TOKEN=.*", "EXEC_API_TOKEN=$tok" | Set-Content .env
}
$token = ((Get-Content .env | Where-Object { $_ -match "^EXEC_API_TOKEN=" }) -split "=", 2)[1]

$log = [System.IO.Path]::GetTempFileName()
$app = $null; $cf = $null
try {
    Write-Host ">> Demarrage service (127.0.0.1:5555)"
    $app = Start-Process "venv\Scripts\pythonw.exe" -ArgumentList "app.py" -PassThru -WindowStyle Hidden
    Start-Sleep -Seconds 2

    Write-Host ">> Ouverture du tunnel"
    $cf = Start-Process "cloudflared" -ArgumentList "tunnel --url http://localhost:5555" -PassThru -RedirectStandardError $log -WindowStyle Hidden

    $url = $null
    for ($i = 0; $i -lt 30; $i++) {
        $m = Select-String -Path $log -Pattern "https://[a-z0-9-]+\.trycloudflare\.com" -ErrorAction SilentlyContinue
        if ($m) { $url = $m.Matches[0].Value; break }
        Start-Sleep -Seconds 1
    }
    if (-not $url) { Write-Host "Tunnel non etabli. Log :"; Get-Content $log; exit 1 }

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "  PRET. A coller au debut d'une conversation Claude :"
    Write-Host "------------------------------------------------------------"
    Write-Host "  Mon PC est accessible via une API HTTP."
    Write-Host "  URL : POST $url/exec"
    Write-Host "  Header : X-Token: $token"
    Write-Host "  Body JSON : {""cmd"":""la commande""}"
    Write-Host "  Utilise ton outil bash pour executer les commandes toi-meme."
    Write-Host "============================================================"
    Write-Host "  Ferme cette fenetre / Ctrl+C pour tout couper."
    Write-Host "============================================================"
    Write-Host ""
    Wait-Process -Id $cf.Id
}
finally {
    Write-Host ">> Arret"
    if ($app) { Stop-Process -Id $app.Id -ErrorAction SilentlyContinue }
    if ($cf)  { Stop-Process -Id $cf.Id  -ErrorAction SilentlyContinue }
    Remove-Item $log -ErrorAction SilentlyContinue
}
