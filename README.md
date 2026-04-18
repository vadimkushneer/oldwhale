# Old Whale (meta repository)

This repository orchestrates **`oldwhale-frontend`** and **`oldwhale-backend`** as [Git submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules). Their code and history live in separate remotes; this repo pins specific commits and holds shared tooling ([`docker-compose.yml`](docker-compose.yml), [`dev-stack.sh`](dev-stack.sh), [`start-local-dev.sh`](start-local-dev.sh)).

- **`oldwhale-backend`** — Go API + PostgreSQL-only ([README](oldwhale-backend/README.md)).
- **`oldwhale-frontend`** — React + Vite ([README](oldwhale-frontend/README.md)).

## Prerequisites

- **Git**
- **Docker** with **Compose V2** (`docker compose` — not only the legacy `docker-compose` binary)
- Enough disk space for images and a **GitHub account with [SSH keys set up](https://docs.github.com/en/authentication/connecting-to-github-with-ssh)** — [`.gitmodules`](.gitmodules) uses `git@github.com:...` URLs for the submodules, so `git submodule update` needs SSH access to GitHub unless you change those URLs locally.

## Quick start (new developers)

1. Clone this repository (a plain clone is enough; submodules are fetched by the script):

   ```bash
   git clone git@github.com:vadimkushneer/oldwhale.git
   cd oldwhale
   ```

2. From the **repository root**, run **one command**. It initializes/checks out **`oldwhale-frontend`** and **`oldwhale-backend`**, then runs **`docker compose up --build`** (same as [`dev-stack.sh`](dev-stack.sh)):

   ```bash
   ./start-local-dev.sh
   ```

Leave that process running. Open [http://localhost:5173](http://localhost:5173) for the Vite app, [http://localhost:8080](http://localhost:8080) for the API, and [http://localhost:8080/swagger](http://localhost:8080/swagger) for Swagger. Uses [`docker-compose.yml`](docker-compose.yml).

- **Stop:** `Ctrl+C` in the terminal, or from another shell in the same directory: `docker compose down`.
- **Wipe the local database volume:** `docker compose down -v`.

### One-liner (clone and start in one paste)

If you prefer a single line after creating a parent directory:

```bash
git clone git@github.com:vadimkushneer/oldwhale.git && cd oldwhale && ./start-local-dev.sh
```

Using `git clone --recurse-submodules ...` before `./start-local-dev.sh` is optional; the script always runs `git submodule update --init --recursive`.

### Submodule only (no Docker)

If you already have the repo and only need the submodules checked out:

```bash
./scripts/init-submodules.sh
```

Equivalent: `git submodule update --init --recursive`.

## Working with submodules

- **Change app code:** commit and push inside `oldwhale-frontend/` or `oldwhale-backend/` as in a normal repository.
- **Update the pins in this meta-repo:** after pulling latest in a submodule (`cd oldwhale-frontend && git pull`), return to the repo root, run `git add oldwhale-frontend`, commit, and push `oldwhale` so others get the new pair of SHAs.
- **Pull everything:** from the root, `git pull` then `git submodule update --init --recursive` (or `git pull --recurse-submodules`).

## Advanced: stack without the bootstrap script

If submodules are already initialized, you can start Docker directly from the repo root:

```bash
./dev-stack.sh
```

**GitHub Pages** for the frontend: use [`oldwhale-frontend/.github/workflows/deploy-github-pages.yml`](oldwhale-frontend/.github/workflows/deploy-github-pages.yml) when that folder is its own Git remote (`npm run build:gh-pages` in CI, not `Dockerfile.dev`).
