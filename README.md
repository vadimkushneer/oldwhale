# Old Whale (meta repository)

[README на русском](README.ru.md)

This repository orchestrates **`oldwhale-frontend`** and **`oldwhale-backend`** as [Git submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules). Their code and history live in separate remotes. The meta-repo **pins specific commits** (gitlinks); each pin is expected to be a commit on the submodule’s **`main`** branch — see `branch = main` in [`.gitmodules`](.gitmodules). Shared tooling lives at the root ([`docker-compose.yml`](docker-compose.yml), [`dev-stack.sh`](dev-stack.sh), [`start-local-dev.sh`](start-local-dev.sh)).

- **`oldwhale-backend`** — Go API + PostgreSQL-only ([README](oldwhale-backend/README.md)).
- **`oldwhale-frontend`** — React + Vite ([README](oldwhale-frontend/README.md)).

## Prerequisites

- **Git**
- **Docker** with **Compose V2** (`docker compose` — not only the legacy `docker-compose` binary)
- Enough disk space for images and a **GitHub account** — [`.gitmodules`](.gitmodules) uses `git@github.com:...` URLs for the submodules, so submodule clone/fetch normally uses **SSH**. Either [add an SSH key to GitHub](https://docs.github.com/en/authentication/connecting-to-github-with-ssh) or use the **HTTPS workaround** below (no repo changes).

### Optional: use HTTPS for GitHub instead of SSH (local only)

The repository can stay on SSH URLs. On a machine where you prefer **HTTPS** (no `ssh` key, or `Permission denied (publickey)`), configure Git **once** for your user:

```bash
git config --global url."https://github.com/".insteadOf "git@github.com:"
```

After that, any Git operation that would use `git@github.com:owner/repo.git` will use `https://github.com/owner/repo.git` instead. Clone the meta-repo with HTTPS if you like:

```bash
git clone https://github.com/vadimkushneer/oldwhale.git
cd oldwhale
```

Set this **before** the first successful submodule init. If a previous run failed halfway, from the repo root remove empty or partial submodule folders (`oldwhale-frontend`, `oldwhale-backend`), then run `./start-local-dev.sh` again.

**Private repositories** still require authentication over HTTPS ([credential helper](https://docs.github.com/en/get-started/git-basics/caching-your-github-credentials-in-git) and a [personal access token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens), or [`gh auth login`](https://cli.github.com/)).

To stop rewriting GitHub SSH URLs later, open your global config and remove the `url … insteadOf` entry, or run `git config --global --get-regexp '^url\.'` to see the exact key name, then `git config --global --unset-all <key>`.

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

Pins always point at **commits on `main`** in each sub-repo (not arbitrary branches). [`start-local-dev.sh`](start-local-dev.sh) checks out exactly the **commits recorded in this repo** so everyone gets the same snapshot; it does not follow moving `main` unless you bump the pins below.

- **Change app code:** commit and push inside `oldwhale-frontend/` or `oldwhale-backend/` on **`main`** (or merge via PR into `main`) as in a normal repository.
- **Bump pins to the latest `main` in both sub-repos** (from the meta-repo root):

  ```bash
  git submodule update --init --recursive --remote
  git add oldwhale-frontend oldwhale-backend
  git commit -m "chore: bump submodules to latest main"
  git push
  ```

  `--remote` uses the `branch = main` entries in [`.gitmodules`](.gitmodules). If only one submodule moved, you can pass a path: `git submodule update --remote oldwhale-frontend`.

- **Manual bump** (equivalent): `cd oldwhale-frontend && git fetch origin && git checkout main && git pull`, same for backend, then from root `git add` both submodules, commit, push.

- **Pull as a developer:** `git pull` in the root, then `git submodule update --init --recursive` to match the new pins (or `git pull --recurse-submodules`).

## Advanced: stack without the bootstrap script

If submodules are already initialized, you can start Docker directly from the repo root:

```bash
./dev-stack.sh
```

**GitHub Pages** for the frontend: use [`oldwhale-frontend/.github/workflows/deploy-github-pages.yml`](oldwhale-frontend/.github/workflows/deploy-github-pages.yml) when that folder is its own Git remote (`npm run build:gh-pages` in CI, not `Dockerfile.dev`).
