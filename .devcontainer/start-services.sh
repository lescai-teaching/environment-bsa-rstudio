#!/usr/bin/env bash
set -euo pipefail

config_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
log_file="${TMPDIR:-/tmp}/jupyterlab-start.log"

# A stuck service command must fail visibly instead of blocking setup forever.
timeout 30s sudo -n rstudio-server start

# Detach all terminal streams so the lifecycle hook can finish while Jupyter runs.
# Codespaces expects port 8888; silently falling back to 8889 hides startup errors.
nohup jupyter lab --config="${config_dir}/jupyter_server_config.py" \
    --ip=0.0.0.0 --port=8888 --ServerApp.port_retries=0 --no-browser \
    --NotebookApp.token='' --NotebookApp.password='' \
    >"${log_file}" 2>&1 </dev/null &
jupyter_pid=$!

# Allow up to 30 seconds for startup, then expose failure in the lifecycle log.
if ! python - <<'PY'
import time
import urllib.error
import urllib.request

pending = {8787, 8888}
deadline = time.monotonic() + 30
while pending and time.monotonic() < deadline:
    for port in pending.copy():
        try:
            with urllib.request.urlopen(f"http://127.0.0.1:{port}/", timeout=1):
                pending.remove(port)
        except urllib.error.HTTPError as error:
            # A login challenge also proves that the HTTP server is responding.
            if error.code in (401, 403):
                pending.remove(port)
        except (OSError, urllib.error.URLError):
            pass
    if pending:
        time.sleep(0.5)
if pending:
    raise SystemExit(f"Services did not respond on ports: {sorted(pending)}")
PY
then
    tail -n 80 "${log_file}" >&2
    exit 1
fi

if ! kill -0 "${jupyter_pid}" 2>/dev/null; then
    cat "${log_file}" >&2
    exit 1
fi
echo "RStudio (8787) and JupyterLab (8888) are responding."
