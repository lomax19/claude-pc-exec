# Exposition via Tailscale Funnel (recommandé)

Prérequis : Tailscale installé et connecté sur le PC, HTTPS + Funnel activés
dans les ACL du tailnet (Admin console → Settings → Feature previews : HTTPS,
puis autoriser `funnel` dans la policy pour ce node).

Le service écoute en 127.0.0.1:5555. Funnel le publie en HTTPS public.

    # certificat HTTPS auto pour ce node
    sudo tailscale cert   # (généralement automatique)

    # publie 127.0.0.1:5555 en HTTPS public, chemin /exec
    tailscale funnel --bg 5555

    # vérifier
    tailscale funnel status

URL publique obtenue :
    https://<nom-machine>.<tailnet>.ts.net/exec

Test :
    curl -s -X POST https://<nom-machine>.<tailnet>.ts.net/exec \
      -H "X-Token: TON_TOKEN" -H "Content-Type: application/json" \
      -d '{"cmd":"whoami"}'

Arrêter l'exposition :
    tailscale funnel --bg off

Note sécurité : Funnel = exposition publique mondiale. Le token est la seule
barrière. Garde EXEC_API_HOST=127.0.0.1 pour ne rien exposer en LAN, et un
token openssl rand -hex 32.
