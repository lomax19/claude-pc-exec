from flask import Flask, request, jsonify
import subprocess, os, hmac, logging, platform, sys

# Charge .env s'il est présent (rend `python app.py` autosuffisant sur Win/mac/Linux)
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

app = Flask(__name__)

TOKEN   = os.environ.get("EXEC_API_TOKEN", "")
HOST    = os.environ.get("EXEC_API_HOST", "127.0.0.1")   # 127.0.0.1 = derrière tunnel (recommandé)
PORT    = int(os.environ.get("EXEC_API_PORT", "5555"))
TIMEOUT = int(os.environ.get("EXEC_API_TIMEOUT", "30"))
MAXOUT  = int(os.environ.get("EXEC_API_MAXOUT", "100000"))  # tronque les sorties monstrueuses
WORKDIR = os.environ.get("EXEC_API_CWD", os.path.expanduser("~"))

if not TOKEN or len(TOKEN) < 32:
    raise RuntimeError("EXEC_API_TOKEN absent ou trop court (>= 32 hex). Arrêt.")

# Log d'audit : chaque commande exécutée est tracée (jamais le token)
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
log = logging.getLogger("exec-api")


def _authorized(req) -> bool:
    sent = req.headers.get("X-Token", "")
    return hmac.compare_digest(sent, TOKEN)   # comparaison temps constant


def _trunc(s: str) -> str:
    if len(s) > MAXOUT:
        return s[:MAXOUT] + f"\n...[tronqué à {MAXOUT} caractères]"
    return s


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok", "os": platform.system()})


@app.route("/exec", methods=["POST"])
def exec_cmd():
    if not _authorized(request):
        log.warning("401 depuis %s", request.remote_addr)
        return jsonify({"error": "unauthorized"}), 401

    data = request.get_json(silent=True) or {}
    cmd = data.get("cmd", "")
    if not cmd:
        return jsonify({"error": "no cmd"}), 400

    log.info("EXEC: %s", cmd if len(cmd) < 500 else cmd[:500] + "…")
    try:
        result = subprocess.run(
            cmd, shell=True, capture_output=True, text=True,
            timeout=TIMEOUT, cwd=WORKDIR,
        )
    except subprocess.TimeoutExpired:
        log.warning("TIMEOUT (%ss): %s", TIMEOUT, cmd[:200])
        return jsonify({"error": "timeout", "timeout": TIMEOUT}), 504

    return jsonify({
        "stdout": _trunc(result.stdout),
        "stderr": _trunc(result.stderr),
        "returncode": result.returncode,
    })


if __name__ == "__main__":
    log.info("exec-api démarre sur %s:%s (os=%s, cwd=%s)", HOST, PORT, platform.system(), WORKDIR)
    app.run(host=HOST, port=PORT)
