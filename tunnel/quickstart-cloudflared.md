# Exposition la plus simple : Cloudflare Quick Tunnel (aucun compte, aucun domaine)

C'est la voie recommandée si tu n'as "qu'un PC" et rien d'autre. Une commande,
une URL HTTPS gratuite en https://xxxx.trycloudflare.com. Idéale pour tester ou
un usage ponctuel.

## 1. Installer cloudflared

Windows :
    winget install --id Cloudflare.cloudflared
    # ou télécharge cloudflared-windows-amd64.exe depuis les releases GitHub Cloudflare

macOS :
    brew install cloudflared

Linux :
    curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared
    chmod +x cloudflared && sudo mv cloudflared /usr/local/bin/

## 2. Lancer le tunnel (le service exec doit tourner sur 127.0.0.1:5555)

    cloudflared tunnel --url http://localhost:5555

cloudflared affiche une URL du type :
    https://random-words-1234.trycloudflare.com

Ton endpoint Claude est alors :
    https://random-words-1234.trycloudflare.com/exec

## 3. Tester

    curl -s -X POST https://random-words-1234.trycloudflare.com/exec \
      -H "X-Token: TON_TOKEN" -H "Content-Type: application/json" \
      -d "{\"cmd\":\"whoami\"}"

## Limites du quick tunnel
- L'URL CHANGE à chaque redémarrage de cloudflared (éphémère).
- Pas de garantie de disponibilité (usage léger).
- Pour une URL FIXE + persistance : tunnel nommé (voir cloudflared.md) ou
  Tailscale Funnel (voir tailscale-funnel.md).

## Sécurité
L'URL est publique et devinable par personne, mais le token EST la seule
barrière : quiconque a l'URL + le token exécute des commandes sur ton PC.
Garde un token openssl rand -hex 32 et ne le partage pas.
