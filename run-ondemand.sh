#!/usr/bin/env bash
# Mode "a la demande" : lance le service + un quick tunnel cloudflared, affiche
# l'URL, et COUPE TOUT au Ctrl+C. Rien ne reste actif ensuite. Le plus sûr.
# Usage : ./run-ondemand.sh
set -euo pipefail
cd "$(dirname "$0")"

command -v cloudflared >/dev/null || {
  echo "cloudflared manquant. Installe-le : voir tunnel/quickstart-cloudflared.md"; exit 1; }

# venv + deps si absents
if [ ! -x venv/bin/python ]; then
  echo ">> Creation venv + dependances"
  python3 -m venv venv
  ./venv/bin/pip -q install -r requirements.txt
fi

# .env + token si absents
if [ ! -f .env ]; then cp .env.example .env; fi
if grep -q "remplacez_par" .env; then
  TOK=$(openssl rand -hex 32)
  sed -i.bak "s|EXEC_API_TOKEN=.*|EXEC_API_TOKEN=$TOK|" .env && rm -f .env.bak
fi
TOKEN=$(grep '^EXEC_API_TOKEN=' .env | cut -d= -f2)

LOG=$(mktemp)
cleanup() { echo; echo ">> Arret"; kill "${APP_PID:-}" "${CF_PID:-}" 2>/dev/null || true; rm -f "$LOG"; }
trap cleanup EXIT INT TERM

echo ">> Demarrage service (127.0.0.1:5555)"
./venv/bin/python app.py >/dev/null 2>&1 &
APP_PID=$!
sleep 2

echo ">> Ouverture du tunnel"
cloudflared tunnel --url http://localhost:5555 >"$LOG" 2>&1 &
CF_PID=$!

# Attendre l'URL trycloudflare
URL=""
for i in $(seq 1 30); do
  URL=$(grep -Eo 'https://[a-z0-9-]+\.trycloudflare\.com' "$LOG" | head -1 || true)
  [ -n "$URL" ] && break
  sleep 1
done
[ -n "$URL" ] || { echo "Tunnel non etabli. Log :"; cat "$LOG"; exit 1; }

cat <<INFO

============================================================
  PRET. A coller au debut d'une conversation Claude :
------------------------------------------------------------
  Mon PC est accessible via une API HTTP.
  URL : POST $URL/exec
  Header : X-Token: $TOKEN
  Body JSON : {"cmd":"la commande"}
  Utilise ton outil bash pour executer les commandes toi-meme.
============================================================
  Ctrl+C pour tout couper (service + tunnel).
============================================================

INFO
wait
