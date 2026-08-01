# Agent notes

## Cursor Cloud specific instructions

This repo is a Rails engine gem (`sent_emails`). There is no app server to boot for day-to-day work.

### Setup

- Ruby and system packages come from `.cursor/Dockerfile`.
- `bundle install` runs automatically via `.cursor/environment.json`.
- Postgres is started by the environment `start` command for optional PG specs.

### Common commands

```bash
bundle exec rspec
bundle exec standardrb
DB=postgresql bundle exec rspec
gem build sent_emails.gemspec
```

Default tests use SQLite (`spec/dummy`). Set `DB=postgresql` (and the `POSTGRES_*` env vars from the Dockerfile) to exercise Postgres-specific query paths.

### Notes

- `Gemfile.lock` is intentionally gitignored so CI can resolve across Ruby/Rails matrix versions.
- Override Rails with `RAILS_VERSION` (default `8.1`), e.g. `RAILS_VERSION=7.2 bundle update`.
