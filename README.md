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

2. From the **repository root**, run **one command**. It initializes the submodules, **updates them to the latest `main`** on each remote (`git submodule update --init --recursive --remote`, using `branch = main` in [`.gitmodules`](.gitmodules)), then runs **`docker compose up --build`** (same as [`dev-stack.sh`](dev-stack.sh)):

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

Using `git clone --recurse-submodules ...` before `./start-local-dev.sh` is optional; the script runs `git submodule update --init --recursive --remote` (latest `main`, not only the pins stored in the meta-repo). Your local meta-repo may then show the submodule paths as **modified** until you commit new pins or discard—this is normal for local dev.

### Submodule only (no Docker), exact pins

If you already have the repo and only need the submodules at the **commits recorded in this meta-repo** (no pull of latest `main`):

```bash
./scripts/init-submodules.sh
```

Equivalent: `git submodule update --init --recursive` (no `--remote`).

## Working with submodules

Pins in the meta-repo point at **commits on `main`** in each sub-repo (not arbitrary branches). **[`start-local-dev.sh`](start-local-dev.sh)** always **pulls latest `main`** into both submodules before Docker; it does **not** leave you on the old pinned SHAs. To **record** those new SHAs in the meta-repo (so clones without `--remote` match), commit and push from the root after syncing.

- **Change app code:** commit and push inside `oldwhale-frontend/` or `oldwhale-backend/` on **`main`** (or merge via PR into `main`) as in a normal repository.

- **Record the current submodule SHAs in the meta-repo** (after `./start-local-dev.sh` or any `git submodule update --remote`):

  ```bash
  git add oldwhale-frontend oldwhale-backend
  git commit -m "chore: bump submodules to latest main"
  ```

  Add `git push` when you use your normal remote workflow. `--remote` uses the `branch = main` entries in [`.gitmodules`](.gitmodules).

- **Pull as a developer (match committed pins only):** `git pull` in the root, then `git submodule update --init --recursive` (or `git pull --recurse-submodules`). Use [`./scripts/init-submodules.sh`](scripts/init-submodules.sh) for the same without Docker.

## Advanced: stack without the bootstrap script

If submodules are already initialized, you can start Docker directly from the repo root:

```bash
./dev-stack.sh
```

**GitHub Pages** for the frontend: use [`oldwhale-frontend/.github/workflows/deploy-github-pages.yml`](oldwhale-frontend/.github/workflows/deploy-github-pages.yml) when that folder is its own Git remote (`npm run build:gh-pages` in CI, not `Dockerfile.dev`).
