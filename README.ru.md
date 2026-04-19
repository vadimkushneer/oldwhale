# Old Whale (метарепозиторий)

*English: [README.md](README.md)*

Этот репозиторий объединяет **`oldwhale-frontend`** и **`oldwhale-backend`** в виде [подмодулей Git](https://git-scm.com/book/ru/v2/%D0%98%D0%BD%D1%81%D1%82%D1%80%D1%83%D0%BC%D0%B5%D0%BD%D1%82%D1%8B-Git-%D0%9F%D0%BE%D0%B4%D0%BC%D0%BE%D0%B4%D1%83%D0%BB%D0%B8). Их код и история коммитов хранятся в отдельных удалённых репозиториях; здесь зафиксированы конкретные коммиты подмодулей и общая инфраструктура ([`docker-compose.yml`](docker-compose.yml), [`dev-stack.sh`](dev-stack.sh), [`start-local-dev.sh`](start-local-dev.sh)).

- **`oldwhale-backend`** — HTTP API на Go, только PostgreSQL ([README](oldwhale-backend/README.md)).
- **`oldwhale-frontend`** — React + Vite ([README](oldwhale-frontend/README.md)).

## Требования

- **Git**
- **Docker** с **Compose V2** (команда `docker compose` — недостаточно только устаревшего исполняемого файла `docker-compose`)
- Достаточно места на диске для образов и **учётная запись GitHub** — в [`.gitmodules`](.gitmodules) для подмодулей указаны URL вида `git@github.com:...`, поэтому клонирование/обновление подмодулей обычно идёт по **SSH**. Либо [добавьте SSH-ключ в GitHub](https://docs.github.com/ru/authentication/connecting-to-github-with-ssh), либо используйте **локальный обход через HTTPS** (ниже), без правок репозитория.

### По желанию: HTTPS вместо SSH для GitHub (только на вашей машине)

В самом репозитории по-прежнему можно хранить SSH-URL. Если вы предпочитаете **HTTPS** (нет ключа `ssh` или ошибка `Permission denied (publickey)`), один раз настройте Git для своего пользователя:

```bash
git config --global url."https://github.com/".insteadOf "git@github.com:"
```

После этого любые обращения к `git@github.com:owner/repo.git` будут заменяться на `https://github.com/owner/repo.git`. Метарепозиторий можно клонировать по HTTPS:

```bash
git clone https://github.com/vadimkushneer/oldwhale.git
cd oldwhale
```

Сделайте это **до** первого успешного `git submodule update`. Если прошлая попытка оборвалась на полпути, из корня удалите пустые или неполные каталоги подмодулей (`oldwhale-frontend`, `oldwhale-backend`) и снова запустите `./start-local-dev.sh`.

**Приватные репозитории** по-прежнему требуют аутентификации по HTTPS ([сохранение учётных данных](https://docs.github.com/ru/get-started/git-basics/caching-your-github-credentials-in-git), [личный токен](https://docs.github.com/ru/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens) или [`gh auth login`](https://cli.github.com/)).

Чтобы позже отключить подмену URL, отредактируйте глобальный конфиг и удалите блок `url … insteadOf`, либо выполните `git config --global --get-regexp '^url\.'`, найдите нужный ключ и снимите его через `git config --global --unset-all <ключ>`.

## Быстрый старт (для новых разработчиков)

1. Клонируйте этот репозиторий (достаточно обычного `git clone`; подмодули подтянет скрипт):

   ```bash
   git clone git@github.com:vadimkushneer/oldwhale.git
   cd oldwhale
   ```

2. Из **корня репозитория** выполните **одну команду**. Она инициализирует и проверит **`oldwhale-frontend`** и **`oldwhale-backend`**, затем запустит **`docker compose up --build`** (то же самое, что [`dev-stack.sh`](dev-stack.sh)):

   ```bash
   ./start-local-dev.sh
   ```

Оставьте процесс запущенным. Откройте [http://localhost:5173](http://localhost:5173) — приложение Vite, [http://localhost:8080](http://localhost:8080) — API, [http://localhost:8080/swagger](http://localhost:8080/swagger) — Swagger. Используется [`docker-compose.yml`](docker-compose.yml).

- **Остановка:** `Ctrl+C` в терминале или из другой оболочки в том же каталоге: `docker compose down`.
- **Удаление локального тома с данными БД:** `docker compose down -v`.

### Одна строка (клонирование и запуск одной вставкой)

Если удобнее одна команда в терминале:

```bash
git clone git@github.com:vadimkushneer/oldwhale.git && cd oldwhale && ./start-local-dev.sh
```

Перед `./start-local-dev.sh` необязательно выполнять `git clone --recurse-submodules ...`: скрипт всегда запускает `git submodule update --init --recursive`.

### Только подмодули (без Docker)

Если репозиторий уже есть и нужно лишь проверить подмодули в рабочем каталоге:

```bash
./scripts/init-submodules.sh
```

Эквивалент вручную: `git submodule update --init --recursive`.

## Работа с подмодулями

- **Изменение кода приложений:** коммит и push внутри `oldwhale-frontend/` или `oldwhale-backend/`, как в обычном репозитории.
- **Обновление закреплённых коммитов в метарепозитории:** после получения последних изменений в подмодуле (`cd oldwhale-frontend && git pull`) перейдите в корень метарепозитория, выполните `git add oldwhale-frontend`, сделайте коммит и отправьте изменения в `oldwhale`, чтобы у остальных зафиксировалась новая пара SHA.
- **Обновить всё:** из корня метарепозитория: `git pull`, затем `git submodule update --init --recursive` (или `git pull --recurse-submodules`).

## Дополнительно: стек без сценария первичного запуска

Если подмодули уже инициализированы, Docker можно поднять напрямую из корня:

```bash
./dev-stack.sh
```

**GitHub Pages** для фронтенда: используйте [`oldwhale-frontend/.github/workflows/deploy-github-pages.yml`](oldwhale-frontend/.github/workflows/deploy-github-pages.yml), когда этот каталог — отдельный Git-удалённый репозиторий (`npm run build:gh-pages` в CI, не `Dockerfile.dev`).
