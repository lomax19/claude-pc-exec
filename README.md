# claude-pc-exec

Donne à **Claude** (claude.ai) un accès shell à **ton PC**, pour qu'il exécute les
commandes lui-même au lieu de te faire copier-coller. Le PC expose une petite API
HTTP protégée par token, publiée en HTTPS par un tunnel qui traverse ta box (pas
de port à ouvrir).

Marche sur **Windows, macOS et Linux**. Tu n'as besoin de rien d'autre qu'un PC
et une connexion internet.

```
Claude (claude.ai) → HTTPS → tunnel → 127.0.0.1:5555 → shell de ton PC
```

Le service écoute en **127.0.0.1** : rien n'est exposé sur ton réseau local, seul
le tunnel publie l'endpoint, et le token en en-tête `X-Token` est la clé d'accès.

---

## Démarrage rapide (le plus simple, n'importe quel PC)

### 1. Récupérer le repo

```bash
git clone https://github.com/lomax19/claude-pc-exec.git
cd claude-pc-exec
```
(Pas de git ? Bouton **Code → Download ZIP**, puis dézippe.)

### 2. Installer et lancer le service

**Windows** (PowerShell, dans le dossier du repo) :
```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

**Linux** :
```bash
sudo ./install.sh <ton_utilisateur>
```

**macOS / lancement manuel universel** (marche partout) :
```bash
python3 -m venv venv && ./venv/bin/pip install -r requirements.txt
cp .env.example .env
# mets un token dans .env :  openssl rand -hex 32
./venv/bin/python app.py
```

Les installeurs **génèrent un token automatiquement et l'affichent** → note-le, il
te faut pour Claude.

### 3. Exposer en HTTPS (aucun compte, aucun domaine)

Installe [cloudflared](tunnel/quickstart-cloudflared.md), puis :
```bash
cloudflared tunnel --url http://localhost:5555
```
Il affiche une URL `https://xxxx.trycloudflare.com`. Ton endpoint = cette URL + `/exec`.

### 4. Tester

```bash
curl -s -X POST https://xxxx.trycloudflare.com/exec \
  -H "X-Token: TON_TOKEN" -H "Content-Type: application/json" \
  -d '{"cmd":"whoami"}'
```

### 5. Dire à Claude d'utiliser ton PC

Colle ça au début d'une conversation Claude :
```
Mon PC est accessible via une API HTTP.
URL : POST https://xxxx.trycloudflare.com/exec
Header : X-Token: TON_TOKEN
Body JSON : {"cmd":"la commande"}
Utilise ton outil bash (via urllib/curl) pour exécuter les commandes toi-même.
```

---

## Options d'exposition

| Méthode | Prérequis | URL fixe | Persistant | Pour qui |
|---|---|---|---|---|
| **Quick tunnel cloudflared** | rien | non (change à chaque run) | non | débuter / tester → [guide](tunnel/quickstart-cloudflared.md) |
| **Cloudflare Tunnel nommé** | un domaine sur Cloudflare | oui | oui | usage durable → [guide](tunnel/cloudflared.md) |
| **Tailscale Funnel** | compte Tailscale | oui | oui | déjà sur Tailscale → [guide](tunnel/tailscale-funnel.md) |

---

## Endpoints

| Méthode | Chemin | Rôle |
|---|---|---|
| POST | `/exec` | exécute `cmd`, renvoie `stdout` / `stderr` / `returncode` |
| GET | `/health` | statut (monitoring) |

## Configuration (`.env`)

| Variable | Défaut | Rôle |
|---|---|---|
| `EXEC_API_TOKEN` | — | **obligatoire**, >= 32 hex (`openssl rand -hex 32`) |
| `EXEC_API_HOST` | `127.0.0.1` | laisser en localhost derrière tunnel |
| `EXEC_API_PORT` | `5555` | port d'écoute |
| `EXEC_API_TIMEOUT` | `30` | timeout par commande (s) |
| `EXEC_API_MAXOUT` | `100000` | troncature des sorties (caractères) |
| `EXEC_API_CWD` | `~` | répertoire de travail |

---

## /!\ Sécurité — à lire avant de déployer

Cet endpoint **exécute des commandes shell arbitraires sur ton PC**. Une fois
exposé par un tunnel, c'est un accès distant complet dont **le token est l'unique
barrière**. Quiconque possède ton URL **et** ton token peut tout faire sur la
machine.

- Utilise un vrai token : `openssl rand -hex 32` (les installeurs le font).
- **Ne partage jamais** ton URL + ton token ensemble, ne les commite pas
  (`.env` est déjà dans `.gitignore`).
- Garde `EXEC_API_HOST=127.0.0.1` (rien sur ton LAN, le tunnel suffit).
- Coupe le tunnel quand tu ne t'en sers pas (le quick tunnel s'arrête avec Ctrl+C).
- Le service journalise chaque commande reçue : Linux `journalctl -u
  claude-pc-exec`, Windows la tâche planifiée, mac le terminal.
- Pour durcir : Cloudflare Access (tunnel nommé) ou ACL Tailscale devant l'endpoint.

Si un accès shell distant permanent te gêne, utilise le **quick tunnel à la
demande** : lancé seulement quand tu bosses avec Claude, coupé après.

---

## Désinstaller

- **Windows** : `Unregister-ScheduledTask -TaskName claude-pc-exec -Confirm:$false` puis supprime `%LOCALAPPDATA%\claude-pc-exec`.
- **Linux** : `sudo systemctl disable --now claude-pc-exec && sudo rm -r /etc/systemd/system/claude-pc-exec.service /opt/claude-pc-exec`.
- **macOS / manuel** : Ctrl+C sur le process, supprime le dossier.

## Structure

```
claude-pc-exec/
├── app.py                     # API Flask durcie (Win/mac/Linux, lit .env seul)
├── requirements.txt
├── install.sh                 # install Linux (venv + systemd)
├── install.ps1                # install Windows (venv + tache planifiee)
├── systemd/claude-pc-exec.service
├── docker/                    # option Docker
│   ├── Dockerfile
│   └── docker-compose.yml
├── tunnel/
│   ├── quickstart-cloudflared.md   # <- le plus simple, aucun prerequis
│   ├── cloudflared.md              # tunnel nomme (URL fixe)
│   └── tailscale-funnel.md
├── .env.example
└── .gitignore
```

Variante NAS/serveur avec reverse proxy : [claude-nas-exec](https://github.com/lomax19/claude-nas-exec).
