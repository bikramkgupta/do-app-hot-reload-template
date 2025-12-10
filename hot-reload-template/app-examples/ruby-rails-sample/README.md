# Ruby on Rails Sample App (Hot Reload)

Minimal Rails 8.1 task tracker for demonstrating hot-reload on DigitalOcean App Platform using `hot-reload-template`.

## Features
- Ruby 3.4.7 via rbenv (from template build args)
- CRUD tasks with Bootstrap UI
- SQLite for dev/test (no external DB needed)
- `/health` JSON endpoint for App Platform health checks
- `dev_startup.sh` handles bundle install, migrations, and server start on port 8080

## Run locally
```bash
bundle install
bin/rails db:prepare   # creates + migrates (SQLite)
bin/rails s -b 0.0.0.0 -p 3000
```

## Deploy for hot-reload
Use the provided `appspec.yaml` with the template Dockerfile.

Key env/build args (already set in `appspec.yaml`):
- `GITHUB_REPO_URL` = https://github.com/bikram20/do-app-platform-ai-dev-workflow
- `GITHUB_REPO_FOLDER` = hot-reload-template/app-examples/ruby-rails-sample
- `INSTALL_RUBY=true` (others false)
- `RUBY_VERSIONS="3.4.7"`, `DEFAULT_RUBY="3.4.7"`
- `DEV_START_COMMAND=bash dev_startup.sh`
- Health check: `/health` on port `8080`

CLI deploy (hot-reload testing):
```bash
doctl apps create --spec appspec.yaml
```

## Tests
```bash
bundle exec rails test
```
