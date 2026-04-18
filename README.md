# Old Whale (meta repository)

This repository orchestrates **`oldwhale-frontend`** and **`oldwhale-backend`** as [Git submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules). Their code and history live in separate remotes; this repo only pins specific commits and holds shared tooling ([`docker-compose.yml`](docker-compose.yml), [`dev-stack.sh`](dev-stack.sh)).

- **`oldwhale-backend`** — Go API + PostgreSQL-only ([README](oldwhale-backend/README.md)).
- **`oldwhale-frontend`** — React + Vite ([README](oldwhale-frontend/README.md)).

## Clone

Clone the meta-repo **and** both sub-repositories in one step:

```bash
git clone --recurse-submodules git@github.com:vadimkushneer/oldwhale.git
```

If you already cloned without submodules, initialize them from the repo root:

```bash
./scripts/init-submodules.sh
```

Equivalent manual command:

```bash
git submodule update --init --recursive
```

## Working with submodules

- **Change app code:** commit and push inside `oldwhale-frontend/` or `oldwhale-backend/` as in a normal repository.
- **Update the pins in this meta-repo:** after pulling latest in a submodule (`cd oldwhale-frontend && git pull`), return to the repo root, run `git add oldwhale-frontend`, commit, and push `oldwhale` so others get the new pair of SHAs.
- **Pull everything:** from the root, `git pull` then `git submodule update --init --recursive` (or `git pull --recurse-submodules`).

## Run everything locally (Docker)

From **this directory** (parent of `oldwhale-backend` and `oldwhale-frontend`):

```bash
./dev-stack.sh
```

- **Frontend (Vite dev, in container):** [http://localhost:5173](http://localhost:5173)  
- **API:** [http://localhost:8080](http://localhost:8080) · **Swagger:** [http://localhost:8080/swagger](http://localhost:8080/swagger)  

Uses [docker-compose.yml](docker-compose.yml). Stop: `Ctrl+C` or `docker compose down`. Wipe DB volume: `docker compose down -v`.

**GitHub Pages** for the frontend: use [`oldwhale-frontend/.github/workflows/deploy-github-pages.yml`](oldwhale-frontend/.github/workflows/deploy-github-pages.yml) when that folder is its own Git remote (`npm run build:gh-pages` in CI, not `Dockerfile.dev`).
