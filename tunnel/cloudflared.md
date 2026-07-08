# Exposition via Cloudflare Tunnel (alternative universelle)

Pour un PC hors tailnet. Nécessite un domaine géré sur Cloudflare.

Install cloudflared (Linux) :
    curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared
    chmod +x /usr/local/bin/cloudflared

Auth + tunnel nommé :
    cloudflared tunnel login
    cloudflared tunnel create claude-pc-exec
    # Route un sous-domaine vers le service local :
    cloudflared tunnel route dns claude-pc-exec exec.ton-domaine.com

~/.cloudflared/config.yml :
    tunnel: claude-pc-exec
    credentials-file: /root/.cloudflared/<UUID>.json
    ingress:
      - hostname: exec.ton-domaine.com
        service: http://127.0.0.1:5555
      - service: http_status:404

Lancer (ou en service) :
    cloudflared tunnel run claude-pc-exec
    # persistant : cloudflared service install

URL : https://exec.ton-domaine.com/exec

Test :
    curl -s -X POST https://exec.ton-domaine.com/exec \
      -H "X-Token: TON_TOKEN" -H "Content-Type: application/json" \
      -d '{"cmd":"whoami"}'

Astuce : ajoute une Cloudflare Access policy devant l'hostname pour une 2e
couche d'auth en plus du token.
