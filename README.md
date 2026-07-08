# claude-pc-exec

Donne à Claude (claude.ai) un accès shell direct à un **PC connecté à internet**,
via une API HTTP sécurisée exposée par un tunnel HTTPS. Claude exécute les
commandes lui-même, plus besoin de copier-coller.

Variante « PC » de [claude-nas-exec](https://github.com/lomax19/claude-nas-exec) :
pas de Nginx/certbot/domaine requis, install native possible, et l'exposition
passe par **Tailscale Funnel** ou **Cloudflare Tunnel** (traverse le NAT, HTTPS auto).

## Architecture

```
Claude (claude.ai) → HTTPS → Tunnel (Funnel/Cloudflare) → 127.0.0.1:5555 → shell PC
```

Le service écoute en **127.0.0.1** : rien n'est exposé sur le LAN. Seul le tunnel
publie l'endpoint, protégé par un token en en-tête `X-Token`.

## Installation native (recommandée, sans Docker)

```bash
git clone https://github.com/lomax19/claude-pc-exec.git
cd claude-pc-exec
sudo ./install.sh <ton_utilisateur>
```

Le script : crée un venv dans `/opt/claude-pc-exec`, génère un token si absent,
installe et démarre le service systemd `claude-pc-exec`, teste `/health`.
**Note le token affiché.**

Puis expose via tunnel → voir [`tunnel/tailscale-funnel.md`](tunnel/tailscale-funnel.md).

## Installation Docker (option)

Si le PC a déjà Docker :

```bash
cp .env.example .env    # remplis EXEC_API_TOKEN (openssl rand -hex 32)
cd docker && docker compose up -d --build
```

## Exposition

| Méthode | Quand | Domaine requis |
|---|---|---|
| **Tailscale Funnel** | PC sur ton tailnet (recommandé) | Non |
| **Cloudflare Tunnel** | PC hors tailnet | Oui (sur Cloudflare) |

Détails : [`tunnel/`](tunnel/).

## Test

```bash
curl -s -X POST https://<ton-endpoint>/exec \
  -H "X-Token: TON_TOKEN" -H "Content-Type: application/json" \
  -d '{"cmd":"whoami"}'
```

## Utilisation avec Claude

Prompt de début de conversation :

```
Un PC est accessible via une API HTTP.
URL : POST https://<ton-endpoint>/exec
Header : X-Token: TON_TOKEN
Body JSON : {"cmd":"ta commande"}
Utilise bash_tool avec urllib pour exécuter les commandes.
```

## Endpoints

| Méthode | Chemin | Rôle |
|---|---|---|
| POST | `/exec` | exécute `cmd`, renvoie `stdout`/`stderr`/`returncode` |
| GET | `/health` | statut (pour Uptime Kuma) |

## Configuration (.env)

| Variable | Défaut | Rôle |
|---|---|---|
| `EXEC_API_TOKEN` | — | **obligatoire**, >= 32 hex |
| `EXEC_API_HOST` | `127.0.0.1` | laisser en localhost derrière tunnel |
| `EXEC_API_PORT` | `5555` | port d'écoute |
| `EXEC_API_TIMEOUT` | `30` | timeout commande (s) |
| `EXEC_API_MAXOUT` | `100000` | troncature sortie (caractères) |
| `EXEC_API_CWD` | `~` | répertoire de travail |

## Sécurité — à lire

Cet endpoint **exécute des commandes shell arbitraires**. Exposé via tunnel public,
c'est un RCE dont le token est **l'unique barrière**. Bonnes pratiques :

- Token fort obligatoire : `openssl rand -hex 32`
- Bind `127.0.0.1` + tunnel (jamais `0.0.0.0` exposé directement)
- Comparaison de token en temps constant (déjà dans `app.py`)
- Log d'audit de chaque commande (stdout du service : `journalctl -u claude-pc-exec`)
- Ne commite jamais `.env` (déjà dans `.gitignore`)
- Cloudflare Access ou ACL Tailscale en 2e couche si possible

## Structure

```
claude-pc-exec/
├── app.py                     # API Flask durcie (multiplateforme)
├── requirements.txt
├── install.sh                 # install native venv + systemd
├── systemd/claude-pc-exec.service
├── docker/                    # option Docker
│   ├── Dockerfile
│   └── docker-compose.yml
├── tunnel/                    # exposition HTTPS
│   ├── tailscale-funnel.md
│   └── cloudflared.md
├── .env.example
└── .gitignore
```
