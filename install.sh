#!/usr/bin/env bash
# Installe claude-pc-exec en natif (venv + systemd) sur un PC Linux.
# Usage : sudo ./install.sh <utilisateur>
set -euo pipefail

USER_RUN="${1:-$SUDO_USER}"
DEST=/opt/claude-pc-exec

[ -n "$USER_RUN" ] || { echo "Usage: sudo ./install.sh <utilisateur>"; exit 1; }
id "$USER_RUN" >/dev/null 2>&1 || { echo "Utilisateur '$USER_RUN' introuvable"; exit 1; }

echo ">> Copie vers $DEST"
mkdir -p "$DEST"
cp app.py requirements.txt .env.example "$DEST/"
[ -f "$DEST/.env" ] || cp .env.example "$DEST/.env"

echo ">> venv + dépendances"
python3 -m venv "$DEST/venv"
"$DEST/venv/bin/pip" -q install -r "$DEST/requirements.txt"

echo ">> Token (si non défini dans .env)"
if grep -q "remplacez_par" "$DEST/.env"; then
  TOK=$(openssl rand -hex 32)
  sed -i "s|EXEC_API_TOKEN=.*|EXEC_API_TOKEN=$TOK|" "$DEST/.env"
  echo "   Token généré : $TOK"
  echo "   >>> NOTE-LE, tu en as besoin pour Claude <<<"
fi

chown -R "$USER_RUN":"$USER_RUN" "$DEST"
chmod 600 "$DEST/.env"

echo ">> Service systemd"
sed "s/%i/$USER_RUN/" systemd/claude-pc-exec.service > /etc/systemd/system/claude-pc-exec.service
systemctl daemon-reload
systemctl enable --now claude-pc-exec

echo ">> Test"
sleep 1
curl -s http://127.0.0.1:5555/health && echo
echo ">> OK. Expose maintenant via tunnel (voir tunnel/tailscale-funnel.md)"
