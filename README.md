# Ruby on Rails POC

A Rails monolith that serves a React + TypeScript + MUI frontend through `vite_rails`. It has two sections:

- **Bonds** tracks municipal bonds, their debt service schedules, and which payments are due, paid, or overdue.
- **Watchlist** is a Netflix-style list of shows with a status and a 1 to 5 rating.

Read [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) to follow one request from the browser to the database and back. Read [`docs/CONCEPTS.md`](docs/CONCEPTS.md) for the Rails concepts this app demonstrates, each tied to a file, plus interview questions.

## Stack

| Layer          | Choice                                               |
| -------------- | ---------------------------------------------------- |
| Ruby           | 4.0.5                                                |
| Rails          | 8.1.4                                                |
| Database       | PostgreSQL 17 in Docker, host port 5433              |
| Frontend       | React 19, TypeScript, MUI 9, React Router 7          |
| Bundler for JS | Vite 8 through `vite_rails`, dev server on port 3036 |
| Tests          | RSpec, FactoryBot, request specs                     |

## Prerequisites

- Ruby 4.0.5 and Bundler.
- Node 24 and npm.
- Docker Desktop, running.

Port 5433 must be free. The compose file maps Postgres there so it does not collide with a local Postgres on 5432.

## Set up and run

Run these from the project root.

```sh
bundle install
npm install
docker compose up -d --wait   # Postgres on localhost:5433, user/password debt_ledger
bin/rails db:setup            # creates dev and test databases, loads schema, runs db/seeds.rb
bin/dev                       # starts Rails on :3000 and Vite on :3036 through foreman
```

Open <http://localhost:3000>. The root redirects to `/bonds`.

`bin/dev` installs `foreman` the first time if it is missing. `Procfile.dev` lists the two processes it runs.

To reset the data to the seed state, run `bin/rails db:reset`. The seeds are idempotent, so `bin/rails db:seed` on its own is also safe to rerun.

If `bundle install` fails with `Permission denied` on `rdoc_plugin.rb`, the `Gemfile` pin `gem "rdoc", "7.0.4"` is missing. Homebrew Ruby ships rdoc 7.0.4 as a read-only default gem, and a newer rdoc cannot overwrite its plugin file.

## Run the tests

```sh
bundle exec rspec        # model, service, and request specs against debt_ledger_test
npm run typecheck        # TypeScript, no emit
```

The specs need the compose Postgres running. They do not need `bin/dev`.

| Spec file                                        | What it proves                                                                    |
| ------------------------------------------------ | --------------------------------------------------------------------------------- |
| `spec/services/bonds/schedule_generator_spec.rb` | Level-principal math, rounding remainder, stub final period                       |
| `spec/services/bonds/create_spec.rb`             | Bond and schedule save together or not at all                                     |
| `spec/models/debt_service_payment_spec.rb`       | Derived `paid`, `upcoming`, `overdue` status and the `due_within` scope           |
| `spec/models/constraints_spec.rb`                | Postgres rejects bad data even when validations are skipped                       |
| `spec/requests/api/*_spec.rb`                    | HTTP contract, error shapes, strong params, and flat query counts (the N+1 guard) |

## API

All endpoints live under `/api` and speak JSON. Errors always have the shape `{ "errors": { "field": ["message"] } }`.

| Method and path                        | Purpose                                                                  |
| -------------------------------------- | ------------------------------------------------------------------------ |
| `GET /api/dashboard?days=90`           | Unpaid payments due in the window, plus outstanding principal per issuer |
| `GET /api/issuers`                     | Issuers, for the new-bond form                                           |
| `GET /api/issuers/:id`                 | One issuer with every bond and its schedule                              |
| `POST /api/bonds`                      | Create a bond. The server generates its schedule                         |
| `PATCH /api/debt_service_payments/:id` | Set `paid_on`                                                            |
| `GET /api/shows`                       | Every show with its list entry, or `null`                                |
| `POST /api/list_entries`               | Add a show to My List                                                    |
| `PATCH /api/list_entries/:id`          | Change status or rating                                                  |
| `DELETE /api/list_entries/:id`         | Remove from My List                                                      |

## Project layout

```text
app/
  controllers/api/      JSON endpoints; base_controller.rb maps exceptions to error JSON
  controllers/spa_controller.rb   renders the empty <div id="root"> for React
  models/               ActiveRecord models, enums, validations, scopes
  serializers/          plain Ruby classes that turn models into JSON hashes
  services/bonds/       ScheduleGenerator (pure math) and Create (transaction)
  frontend/             React app, compiled by Vite
    entrypoints/application.tsx   the one Vite entrypoint the layout loads
    types/              TypeScript mirrors of the serializers
    api/client.ts       fetch wrapper, CSRF token, typed ApiError
    pages/bonds/, pages/watchlist/
db/migrate/             schema with constraints and indexes
db/seeds.rb             demo data
spec/                   RSpec suite
compose.yaml            Postgres
docs/screenshots/       browser screenshots from the verification run
```
