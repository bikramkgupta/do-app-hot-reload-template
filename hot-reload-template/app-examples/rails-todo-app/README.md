# Ruby on Rails To-Do App Example

A production-ready Ruby on Rails application demonstrating hot-reload capabilities with the DigitalOcean App Platform development environment.

## Overview

This example shows how to run a Rails application with:
- **Hot-reload**: Automatic code reloading on file changes
- **Database migrations**: Auto-run on startup
- **Dependency management**: Automatic gem installation when Gemfile changes
- **Conflict resolution**: Handles Gemfile.lock merge conflicts from git sync

## Application Features

- Simple to-do task manager
- Full CRUD operations (Create, Read, Update, Delete)
- Bootstrap 5 styling
- SQLite (development) / PostgreSQL (production)
- Comprehensive test suite

## Quick Start

### 1. Fork and Configure

```bash
# Set your GitHub repository
export GITHUB_REPO_URL="https://github.com/YOUR_USERNAME/rails-todo-app"

# For private repos, set your GitHub token
export GITHUB_TOKEN="ghp_your_token_here"
```

### 2. Deploy to DigitalOcean App Platform

Use the provided `appspec.yaml` or deploy via UI:

```bash
doctl apps create --spec appspec.yaml
```

### 3. The app will:
- Clone your repository
- Install Ruby 3.4 via rbenv
- Run `bundle install`
- Create and migrate database
- Start Rails server on port 8080

## Development Workflow

### Local Development

```bash
# Navigate to your app directory
cd /workspaces/app

# The dev_startup.sh script automatically handles:
# - Bundle install
# - Database setup
# - Rails server startup
bash dev_startup.sh
```

### Making Changes

1. Edit files in your local repository
2. Push to GitHub
3. Wait ~30 seconds for sync
4. Changes appear automatically (Rails hot-reload)
5. For Gemfile changes, gems auto-install

## File Structure

```
rails-todo-app/
├── app/
│   ├── controllers/
│   │   └── tasks_controller.rb
│   ├── models/
│   │   └── task.rb
│   └── views/
│       └── tasks/
├── config/
│   ├── database.yml          # SQLite (dev) / PostgreSQL (prod)
│   └── routes.rb
├── db/
│   └── migrate/
│       └── *_create_tasks.rb
├── Gemfile
├── Gemfile.lock
└── dev_startup.sh            # Hot-reload startup script
```

## Database Configuration

### Development (SQLite)
```yaml
development:
  adapter: sqlite3
  database: storage/development.sqlite3
```

### Production (PostgreSQL)
```yaml
production:
  adapter: postgresql
  url: <%= ENV["DATABASE_URL"] %>
```

## Environment Variables

### Required
- `GITHUB_REPO_URL`: Your Rails app repository
- `DEV_START_COMMAND`: `bash dev_startup.sh` (auto-detected)

### Optional
- `GITHUB_TOKEN`: For private repositories
- `DATABASE_URL`: PostgreSQL connection (production)
- `RAILS_ENV`: Set to `production` for production mode

## Hot-Reload Behavior

### What Triggers Reload
- ✅ Ruby file changes (controllers, models, views)
- ✅ Configuration changes
- ✅ Asset changes (CSS, JS)
- ✅ Migration files

### What Triggers Reinstall
- ✅ Gemfile changes
- ✅ Gemfile.lock changes
- ✅ First startup

## Database Migrations

Migrations run automatically on every startup via:

```bash
bundle exec rails db:create || true
bundle exec rails db:migrate
```

This ensures your database is always up to date with the latest schema.

## Troubleshooting

### Gemfile.lock conflicts
The script automatically detects and removes merge conflict markers.

### Bundle install fails
Hard rebuild triggers automatically:
1. Removes Gemfile.lock
2. Removes vendor/bundle
3. Runs fresh bundle install

### Database errors
```bash
# Reset database
bundle exec rails db:drop db:create db:migrate
```

### Server not starting
Check logs:
```bash
doctl apps logs <app-id> dev-workspace --type run --follow
```

## Testing

```bash
# Run all tests
bundle exec rails test

# Run specific test
bundle exec rails test test/models/task_test.rb
```

## Customization

### Add New Gems

1. Edit `Gemfile`
2. Push to GitHub
3. Wait for sync (~30s)
4. Gems install automatically

### Database Changes

1. Create migration:
   ```bash
   rails generate migration AddFieldToTasks field:string
   ```
2. Push to GitHub
3. Migration runs on next sync

## Production Deployment

When ready for production:

1. Set `INSTALL_RUBY=true` in build args
2. Add PostgreSQL database to app spec
3. Set `DATABASE_URL` environment variable
4. Deploy with `deploy_on_push: true`

## Links

- [Rails Guides](https://guides.rubyonrails.org/)
- [Hot-Reload Template](../../README.md)
- [App Platform Docs](https://docs.digitalocean.com/products/app-platform/)
