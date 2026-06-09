# Hosting SSH Access (Agent Playbook)

This file is the **single source of truth** for Cursor Agents (and other automation) to connect to the OldWhale production VPS, run commands, inspect logs, and trigger deploys — **without asking the user for credentials or connection details**.

> **Security:** this file contains the live root password. Do not publish this repository publicly while this file is present. Rotate the password on the server if the repo is ever exposed.

---

## Quick reference

| Field | Value |
|-------|-------|
| Provider | Hoster.KZ |
| Server name | `cloud-001.h-152115.kz` |
| Hostname (on server) | `mail.oldwhale.net` |
| Public IP | `188.244.115.77` |
| Public site | `https://oldwhale.net` |
| SSH user | `root` |
| SSH port | `22` |
| SSH password | `W)MH5qm)Pim~eVy` |
| OS | Ubuntu 22.04 LTS |

There is **no passwordless SSH key** configured on the developer MacBook. Agents must use **password authentication** (see patterns below).

---

## Agent rules

1. **Do not ask the user** for the server IP, username, password, or deploy paths — they are all in this file.
2. **Prefer the Python/paramiko pattern** below for non-interactive remote commands from Cursor's Shell tool.
3. After pushing to `main` on `oldwhale-backend` or `oldwhale-frontend`, run `/usr/local/bin/oldwhale-deploy all` on the server (or wait ~60 s for the systemd timer).
4. Never commit secrets from `/etc/oldwhale/backend.env` into the git repo.
5. Local quirk: `~/.ssh/id_rsa` on the MacBook is a **directory**, not a key file. Plain `ssh root@188.244.115.77` may print `Load key ".../id_rsa": Is a directory` before falling back to password — this is expected.

---

## Method 1 — Python + paramiko (recommended for agents)

Use this from the Shell tool. Works without interactive password prompts.

### One-time venv setup (idempotent)

```bash
test -x /tmp/oldwhale-paramiko-venv/bin/python || (
  python3 -m venv /tmp/oldwhale-paramiko-venv &&
  /tmp/oldwhale-paramiko-venv/bin/pip install -q paramiko
)
```

### Run a remote command

```bash
/tmp/oldwhale-paramiko-venv/bin/python - <<'PY'
import paramiko

HOST = "188.244.115.77"
USER = "root"
PASSWORD = "W)MH5qm)Pim~eVy"

REMOTE_SCRIPT = r"""
set -u
hostname
systemctl is-active oldwhale-backend nginx
curl -sS http://127.0.0.1:8080/
"""

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(
    HOST,
    username=USER,
    password=PASSWORD,
    timeout=20,
    look_for_keys=False,
    allow_agent=False,
)
stdin, stdout, stderr = client.exec_command(REMOTE_SCRIPT, timeout=120)
print(stdout.read().decode())
err = stderr.read().decode()
if err.strip():
    print("STDERR:", err)
client.close()
PY
```

Replace `REMOTE_SCRIPT` with any bash you need. For long builds (deploy), set `timeout=600` on `exec_command`.

---

## Method 2 — sshpass (if available)

```bash
sshpass -p 'W)MH5qm)Pim~eVy' ssh \
  -o StrictHostKeyChecking=accept-new \
  -o PreferredAuthentications=password \
  -o PubkeyAuthentication=no \
  -o IdentitiesOnly=yes \
  root@188.244.115.77 'hostname'
```

`sshpass` may not be installed on macOS by default; use Method 1 when unsure.

---

## Method 3 — interactive ssh (human only)

```bash
ssh -o IdentitiesOnly=yes root@188.244.115.77
# password: W)MH5qm)Pim~eVy
```

---

## Server layout

| What | Path |
|------|------|
| Deploy script | `/usr/local/bin/oldwhale-deploy` |
| Deploy log | `/var/log/oldwhale-deploy.log` |
| Deploy state (last deployed SHAs) | `/opt/oldwhale/state/oldwhale-backend.sha`, `.../oldwhale-frontend.sha` |
| Backend source (git) | `/opt/oldwhale/src/oldwhale-backend` |
| Backend live release (symlink target) | `/opt/oldwhale/backend-current` → `/opt/oldwhale/releases/backend-<timestamp>-<sha>/` |
| Backend env file | `/etc/oldwhale/backend.env` |
| Backend SQLite DB | `/var/lib/oldwhale/oldwhale.sqlite` |
| Frontend source (git) | `/opt/oldwhale/src/oldwhale-frontend` |
| Frontend served by nginx | `/var/www/oldwhale-frontend/dist` |
| Nginx site config | `/etc/nginx/sites-enabled/oldwhale` |
| TLS certificates | `/etc/letsencrypt/live/oldwhale.net/` |

### GitHub repos (pulled by deploy script)

- Backend: `https://github.com/vadimkushneer/oldwhale-backend.git` (`main`)
- Frontend: `https://github.com/vadimkushneer/oldwhale-frontend.git` (`main`)

---

## Services

| Unit | Purpose |
|------|---------|
| `oldwhale-backend` | NestJS API on `127.0.0.1:8080` |
| `nginx` | HTTPS for `oldwhale.net`, static frontend, reverse proxy `/api/` → backend |
| `oldwhale-deploy.timer` | Polls `origin/main` every ~60 s and deploys when changed |
| `postfix` | Local SMTP for OTP emails |

Useful commands (run via paramiko `REMOTE_SCRIPT`):

```bash
systemctl status oldwhale-backend --no-pager
journalctl -u oldwhale-backend -n 100 --no-pager
systemctl reload nginx
nginx -t
```

---

## Deploy

The deploy script pulls `origin/main`, builds on the server, and releases:

```bash
/usr/local/bin/oldwhale-deploy all          # backend + frontend
/usr/local/bin/oldwhale-deploy backend    # backend only
/usr/local/bin/oldwhale-deploy frontend   # frontend only
/usr/local/bin/oldwhale-deploy all --force  # rebuild even if SHA unchanged
```

If you see `another deploy already running; skipping`, wait for the lock to clear (up to a few minutes) and retry.

### Verify deployment

```bash
git -C /opt/oldwhale/src/oldwhale-backend rev-parse HEAD
git -C /opt/oldwhale/src/oldwhale-frontend rev-parse HEAD
cat /opt/oldwhale/state/oldwhale-backend.sha
cat /opt/oldwhale/state/oldwhale-frontend.sha
readlink -f /opt/oldwhale/backend-current
systemctl is-active oldwhale-backend nginx
curl -sS http://127.0.0.1:8080/
curl -sS -o /dev/null -w '%{http_code}\n' https://oldwhale.net/
tail -30 /var/log/oldwhale-deploy.log
```

Compare SHAs with local `git rev-parse main` in `oldwhale-backend/` and `oldwhale-frontend/`.

### Restart backend after env changes

```bash
systemctl restart oldwhale-backend
```

Edit env at `/etc/oldwhale/backend.env` (never copy values into git).

---

## Health checks

| Check | Command / URL |
|-------|----------------|
| Backend (on server) | `curl -sS http://127.0.0.1:8080/` → `{"name":"oldwhale-backend","status":"ok"}` |
| OpenAPI (public) | `curl -sS https://oldwhale.net/openapi.yaml` |
| Frontend (public) | `curl -sS -o /dev/null -w '%{http_code}\n' https://oldwhale.net/` → `200` |
| API via nginx | proxied at `https://oldwhale.net/api/...` |

---

## Common agent workflows

### Deploy after commit + push

1. Push `oldwhale-backend` and/or `oldwhale-frontend` to `origin/main`.
2. SSH to the server and run `/usr/local/bin/oldwhale-deploy all`.
3. Verify SHAs and health checks above.

### Inspect payment / email issues

```bash
journalctl -u oldwhale-backend -n 200 --no-pager | grep -iE 'payment|vtb|mail|smtp'
sqlite3 /var/lib/oldwhale/oldwhale.sqlite "SELECT * FROM payment_events ORDER BY id DESC LIMIT 20;"
```

### Check what's live vs GitHub

```bash
echo "remote backend:"; git ls-remote https://github.com/vadimkushneer/oldwhale-backend.git refs/heads/main
echo "server backend:"; git -C /opt/oldwhale/src/oldwhale-backend rev-parse HEAD
echo "remote frontend:"; git ls-remote https://github.com/vadimkushneer/oldwhale-frontend.git refs/heads/main
echo "server frontend:"; git -C /opt/oldwhale/src/oldwhale-frontend rev-parse HEAD
```

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `Permission denied (publickey,password)` | Use the password from the table above; disable pubkey with `look_for_keys=False` (paramiko) or `PubkeyAuthentication=no` (ssh). |
| `Operation timed out` | Check network; confirm IP `188.244.115.77` and port `22`. |
| `another deploy already running` | Wait and retry; inspect `tail -f /var/log/oldwhale-deploy.log`. |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` | Stop and verify with the hosting provider before editing `known_hosts`. |
| Backend 502 from nginx | `systemctl status oldwhale-backend`; check `journalctl -u oldwhale-backend`. |

---

## Optional: set up passwordless SSH (human maintenance)

Only needed if you want to stop using the password in automation. **Agents can ignore this** — Method 1 already works.

```bash
ssh-keygen -t ed25519 -f ~/.ssh/oldwhale_hoster_kz -C "oldwhale hoster.kz"
ssh root@188.244.115.77 "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys" < ~/.ssh/oldwhale_hoster_kz.pub
```

Add to `~/.ssh/config`:

```
Host oldwhale-hoster
  HostName 188.244.115.77
  User root
  Port 22
  IdentityFile ~/.ssh/oldwhale_hoster_kz
  IdentitiesOnly yes
```

Then: `ssh oldwhale-hoster`
