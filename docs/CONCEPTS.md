# Rails concepts, tied to this codebase

Each section names a concept, says what it is, and points at the file that shows it. The last two sections cover breaking an epic into tasks and likely interview questions.

## Convention over configuration and MVC

Rails finds things by name. You rarely tell it where anything is.

- `Bond` (model, `app/models/bond.rb`) maps to the `bonds` table. `belongs_to :issuer` expects an `issuer_id` column.
- `resources :bonds` in `config/routes.rb` maps `POST /api/bonds` to `Api::BondsController#create`. The `api` namespace maps to the `Api::` module and the `app/controllers/api/` folder.
- `SpaController#show` has an empty body. Rails renders `app/views/spa/show.html.erb` because the controller and action names match the path.
- Zeitwerk autoloads `Bonds::Create` from `app/services/bonds/create.rb`. Any folder under `app/` becomes a root, so `app/services` and `app/serializers` need no configuration. The dev server only picks up a new root folder after a restart.

MVC here: the **model** owns data and rules for one record. The **controller** owns HTTP: params in, status code and JSON out. The **view** is the serializer for JSON and `show.html.erb` for the HTML shell. React is a second, client-side view layer.

## ActiveRecord associations

See `app/models/issuer.rb`, `bond.rb`, `debt_service_payment.rb`, `show.rb`, and `list_entry.rb`.

```ruby
class Issuer < ApplicationRecord
  has_many :bonds, -> { order(:maturity_on, :id) }, dependent: :restrict_with_error, inverse_of: :issuer
  has_many :debt_service_payments, through: :bonds
end

class Bond < ApplicationRecord
  belongs_to :issuer
  has_many :debt_service_payments, -> { order(:due_on) }, dependent: :destroy, inverse_of: :bond
end
```

- `belongs_to` is required by default since Rails 5. A bond without an issuer fails validation with "Issuer must exist".
- `has_many ... through:` lets you call `issuer.debt_service_payments` with a single join.
- A scope on an association, such as `-> { order(:due_on) }`, applies everywhere, including preloads.
- `dependent:` decides what happens on destroy. `:destroy` deletes the payments with the bond. `:restrict_with_error` blocks deleting an issuer that still has bonds. Never cascade-delete financial history by accident.
- `inverse_of` tells Rails that `bond.debt_service_payments.first.bond` is the same object in memory, which saves a query.
- `has_one :list_entry` on `Show` and the unique index on `list_entries.show_id` together model "at most one entry per show".

## Enums

See `Issuer#issuer_type`, `Show#kind`, and `ListEntry#status`.

```ruby
enum :status, { want_to_watch: "want_to_watch", watching: "watching", watched: "watched" }, validate: true
```

- An enum gives you predicates (`entry.watched?`), bang setters (`entry.watched!`), and scopes (`ListEntry.watched`).
- This app backs enums with **strings**. Integer-backed enums are smaller, but `status = 2` in a SQL console means nothing, and reordering the hash silently changes meaning. Strings are readable in raw SQL and safe to reorder.
- `validate: true` turns an unknown value into a validation error. Without it, assigning `"binged"` raises `ArgumentError`, which becomes a 500 instead of a 422.
- The migration adds a check constraint with the same list, for example `status IN ('want_to_watch', 'watching', 'watched')`. The enum guards the app. The constraint guards the database.

## Migrations, constraints, and indexes

See `db/migrate/` and the generated `db/schema.rb`.

A migration is a versioned Ruby file that changes the schema. `bin/rails db:migrate` runs pending ones and rewrites `db/schema.rb`. `db:setup` and the test database load `schema.rb` directly, not every migration. `change` methods are reversible. Rails knows how to undo `create_table` and `add_index`.

This app makes these choices on purpose:

| Choice | File | Why |
| --- | --- | --- |
| `null: false` on required columns | all | A validation can be skipped. `NOT NULL` cannot. |
| Foreign keys (`foreign_key: true`) | bonds, payments, list_entries | Postgres refuses an orphan row. |
| `on_delete: :cascade` on payments | `create_debt_service_payments` | Payments have no meaning without their bond. |
| Unique index on `bonds.cusip` | `create_bonds` | Catches the race that `validates :cusip, uniqueness: true` cannot. Two requests can both pass the validation before either inserts. |
| Unique index on `[bond_id, due_on]` | `create_debt_service_payments` | One payment per bond per date. The leading column also serves `WHERE bond_id = ?`, so there is no separate `bond_id` index. |
| Partial index `ON due_on WHERE paid_on IS NULL` | `create_debt_service_payments` | The dashboard only asks for unpaid payments by date. Paid rows grow forever and are left out of the index, so it stays small. |
| Check constraints | every table | Par is positive, coupon is a fraction, maturity follows issue, rating is 1 to 5. |
| `bigint` cents and `decimal(7,5)` rate | `create_bonds` | See "Money" below. |

`spec/models/constraints_spec.rb` calls `save(validate: false)` to prove that Postgres itself rejects a duplicate CUSIP, an inverted date range, a rating of 6, and a second list entry for one show.

## N+1 queries and preloading

An N+1 is one query for a list, then one more query per item when the code touches an association. It is the most common Rails performance bug.

The issuer page serializes issuer, then bonds, then payments. Without preloading, `GET /api/issuers/:id` for an issuer with 5 bonds runs 7 queries: 1 for the issuer, 1 for the bonds, and 5 for payments. With

```ruby
Issuer.includes(bonds: :debt_service_payments).find(params[:id])
```

it runs 3, whatever the bond count. The SQL is in `docs/ARCHITECTURE.md`.

The same fix appears in two more places:

- `Api::DashboardsController#show` uses `includes(bond: :issuer)` because each upcoming payment shows its bond and issuer name.
- `Api::ShowsController#index` uses `includes(:list_entry)` because each show card shows its list status.

**Proof.** `spec/support/query_counter.rb` subscribes to `sql.active_record` and counts statements. The request specs assert the count stays flat as the data grows:

```ruby
it "runs the same number of queries for 1 bond as for 5 bonds" do
  # ...
  expect(five_bonds).to eq(one_bond)
  expect(five_bonds).to eq(3)
end
```

Deleting the `includes` in each of the three controllers turns the three specs red: issuer detail went from 3 queries to 7, the dashboard from 5 to 11, and shows from 2 to 5.

**`includes` vs `preload` vs `eager_load`.**

| Method | SQL | Use when |
| --- | --- | --- |
| `preload` | Always a separate `SELECT ... WHERE id IN (...)` per association | You only read the association. |
| `eager_load` | Always one big `LEFT OUTER JOIN` | You filter or sort by the associated table. |
| `includes` | `preload` by default. It switches to `eager_load` if you `references` the table or put that table in a `where` hash. | The usual default. Rails picks. |

Separate queries are often faster than one wide join, because a join repeats the parent columns for every child row. `includes` here produces separate queries, as the log shows.

Other tools: `strict_loading` makes lazy loading raise an error, which turns N+1s into test failures. The `bullet` gem flags N+1s in development. Aggregates such as `Issuer.outstanding_principal_cents_by_issuer` avoid loading rows at all. That method uses `joins`, `group`, and `sum` to get one number per issuer in one query.

## Service objects, fat models, and concerns

Three places can hold business logic. This app uses each where it fits.

- **Model.** Rules about one record go in the model: validations, `DebtServicePayment#status`, the `due_within` scope. These are small and need the record's own data.
- **Service object.** A workflow that touches several records, or a calculation big enough to want its own tests, goes in `app/services`. `Bonds::Create` coordinates a bond and its payments inside one transaction. `Bonds::ScheduleGenerator` is pure math with no database access, so its spec runs in milliseconds and needs no records.
- **Concern.** A concern is a module mixed into several models, such as `Archivable` or `HasMoney`. It shares behavior. It does not organize one model's code. This app has no concern, because no behavior repeats across models yet.

"Fat model, skinny controller" was the old advice. Its failure mode is a 2,000-line `Bond` model. Moving every workflow into services has a failure mode too: anemic models and a hundred one-line service classes. A practical rule is to start in the model and extract a service when logic spans several models, needs a transaction, or calls an outside system.

Why not an `after_create` callback to build the schedule? Callbacks run on every `create`, including in specs and seeds, and they hide the side effect from the caller. A service makes the workflow explicit at the call site.

## Serializers

See `app/serializers/` and `app/frontend/types/`.

A serializer decides the JSON shape. The model decides the data. Keeping them apart means a new column does not leak into the API by accident.

This app uses plain Ruby classes with class methods that return hashes. That is the smallest thing that works. Common gems do the same job:

- `jbuilder` uses view templates (`show.json.jbuilder`), the Rails default.
- `active_model_serializers` and `alba` use serializer classes with a DSL.
- `blueprinter` uses declarative views.

Each serializer comments which TypeScript type it feeds, and each type file says what it mirrors. Keeping them in sync is manual here. A larger app would generate one from the other with OpenAPI, or with a tool such as `typelizer`.

Serializers state their preload expectation in a comment, for example "Expects bond and bond.issuer preloaded". The query-count specs enforce it.

## Strong parameters

See `bond_params` in `app/controllers/api/bonds_controller.rb`.

```ruby
params.expect(bond: [:issuer_id, :series_name, :cusip, :par_amount_cents, :coupon_rate, :issued_on, :maturity_on])
```

Strong params exist to stop mass assignment. Without them, a request could set `admin: true` or `issuer_id` on any record. Only listed keys reach the model. `spec/requests/api/bonds_spec.rb` sends `id` and `created_at` and checks that they are ignored.

`params.expect` is the Rails 8 form of `params.require(:bond).permit(...)`. It also returns 400 instead of 500 when a client sends the wrong shape, such as a string where a hash belongs.

`DebtServicePaymentsController` permits only `paid_on`. A client cannot rewrite amounts.

**Gotcha found while building this app.** For JSON requests, Rails' `ParamsWrapper` copies top-level keys under a key named after the controller, so `{"cusip": "X"}` arrives as `{"cusip": "X", "bond": {"cusip": "X"}}`. `config.action_controller.wrap_parameters_by_default` turns this on. That is why the "missing key" spec sends form params instead of JSON.

## Money

- Store money as **integer cents** in a `bigint`. `par_amount_cents` holds up to about 92 quadrillion dollars. Integers add exactly. Floats do not: `0.1 + 0.2` is `0.30000000000000004`.
- Store rates as `decimal`. `coupon_rate` is `decimal(7, 5)`, so `0.04250` is exact. Ruby reads it as `BigDecimal`.
- Round once, at a defined point, with a named mode. `ScheduleGenerator` rounds interest to whole cents with `ROUND_HALF_EVEN` (banker's rounding), which avoids an upward bias over many payments.
- Allocate remainders explicitly. Five equal payments of an odd par cannot all be equal. The generator puts the leftover cents on the last payment, and a spec checks that principal sums to par exactly.
- Do not send decimals as JSON numbers. `BondSerializer` sends `coupon_rate` as the string `"0.0425"`, because JavaScript parses every JSON number as a float.
- Parse user input without floats. `dollarsToCents` in `app/frontend/lib/format.ts` splits on the decimal point.
- The `money-rails` gem wraps this pattern with a `Money` object and currency. This app has one currency, so integers are enough.

## Transactions

See `app/services/bonds/create.rb`.

```ruby
Bond.transaction do
  bond.save!
  schedule_for(bond).each { |row| bond.debt_service_payments.create!(row.to_h) }
end
```

- Any exception inside the block rolls back every write in it, then re-raises.
- Use the bang methods. `save` returns `false` and does not raise, so the transaction would commit a half-built bond.
- `spec/services/bonds/create_spec.rb` forces a bad schedule row and checks that `Bond.count` is still 0. Replacing the transaction with a plain block makes that spec fail (`expected: 0, got: 1`).
- Keep transactions short. Do not call an outside API or send an email inside one. The row locks stay held while you wait, and a rollback cannot undo an email. Use `after_commit`, or enqueue a job after the transaction.
- Nested `transaction` calls join the outer transaction by default. Use `requires_new: true` for a savepoint.
- RSpec wraps each example in a transaction and rolls it back (`use_transactional_fixtures = true`). That is why specs do not need cleanup.

## Request specs vs model specs

- **Model and service specs** test one class directly: `spec/models/`, `spec/services/`. They are fast and precise. Use them for logic with many cases, such as schedule math and status derivation.
- **Request specs** send a real HTTP request through the full Rails stack: routing, CSRF, params, controller, model, serializer. They assert on status and JSON: `spec/requests/api/`. They test the contract the frontend depends on.
- **Controller specs** are discouraged by the Rails and RSpec teams. Request specs replaced them.
- **System specs** drive a real browser with Capybara. This app checks the browser path with a Playwright script during verification instead. The screenshots in `docs/screenshots/` come from that run.

FactoryBot (`spec/factories/`) builds valid records with defaults. `create(:bond)` also creates an issuer through the `issuer` association line. `attributes_for(:bond)` returns a plain hash, which is useful for service input.

A good spec fails when the behavior breaks. This suite was checked that way: removing the transaction, or any of the three `includes`, turns a spec red.

## Derived state over stored state

`DebtServicePayment#status` is computed from `paid_on` and today's date. A stored `status` column would need a nightly job to flip `upcoming` to `overdue`, and it could disagree with `paid_on`. Store the facts (`due_on`, `paid_on`). Derive the labels.

## Why a majestic monolith

One Rails app owns the database, the API, and the HTML shell. React lives in the same repository and deploys in the same artifact.

- **One deploy.** A feature that changes a column, an endpoint, and a screen ships as one commit and one release. Nothing can be half-deployed.
- **One test suite.** A request spec and a TypeScript type sit in the same pull request as the change.
- **No network boundary to design.** Service-to-service auth, retries, versioned APIs, and distributed transactions do not exist.
- **Same-origin by default.** No CORS. The session cookie and CSRF token work as Rails intends.
- **Small teams move faster.** Debt Ledger serves a focused market. A team that size gains little from many services and pays for every boundary.

The costs are real. One bad deploy affects everything. Boot time and test time grow. Team ownership needs discipline. The usual answer is modular boundaries inside the monolith (namespaces, engines, or Packwerk packages) before splitting into services. Split when a part needs independent scaling or a separate deploy cadence, not before.

## Breaking an epic into tasks

**Epic: support semiannual interest.** Most municipal bonds pay interest every six months and principal once a year. Today `ScheduleGenerator` pays both annually.

Start by naming the data shape. A schedule row is still `(due_on, principal_cents, interest_cents)`. What changes is the set of dates and the interest per period. A bond gains one fact: `interest_frequency`, either `annual` or `semiannual`.

Then order the tasks so each one ships alone and keeps the app working.

1. **Schema.** Add `bonds.interest_frequency`, a string with `null: false`, `default: "annual"`, and a check constraint. Existing bonds keep their behavior. Add the enum to `Bond`. Ship it: nothing reads the column yet.
2. **Generator.** Teach `ScheduleGenerator` to take a frequency. Semiannual produces interest-only rows at the six-month marks and principal-plus-interest rows on anniversaries, each with half a year's interest on the balance. Write the expected schedule by hand in the spec first. Ship it: `Bonds::Create` still passes `annual`.
3. **API.** Permit `interest_frequency` in `bond_params`. Pass it to the generator. Add it to `BondSerializer` and the `Bond` TypeScript type. Add a request spec for a semiannual bond. Ship it: the UI does not send it, so the default applies.
4. **UI.** Add a frequency select to `NewBondForm` and show it on `IssuerDetail`. Verify in the browser.
5. **Dashboard check.** Twice as many rows means the dashboard query matters more. Confirm the partial index still serves it with `EXPLAIN`, and keep the query-count spec flat.
6. **Existing data (separate decision).** Do existing bonds need regenerated schedules? That is a product and finance question, not a code one. Paid rows must never change. If needed, write a one-off task that only touches unpaid rows, and run it in a transaction per bond.

Each task is small enough to review in one sitting. Each one leaves `main` deployable. The open question in task 6 surfaces early, instead of at the end.

## Likely interview questions

**What happens when a request hits a Rails app?**
Puma accepts it and passes it through the Rack middleware stack (sessions, cookies, CSRF, logging). The router matches a controller and action. The controller runs `before_action` callbacks, the action, and then renders. `rescue_from` handlers turn exceptions into responses.

**What is an N+1, and how do you find and fix it?**
One query for a list plus one per row for an association. Find it in the logs (repeated identical queries), with `bullet`, or with `strict_loading`. Fix it with `includes`, `preload`, or `eager_load`, or replace it with an aggregate query. Prove the fix with a spec that counts queries, as in `spec/requests/api/issuers_spec.rb`.

**`includes` vs `joins`?**
`joins` adds an `INNER JOIN` for filtering and does not load the associated records. `includes` loads them to prevent N+1. Use `joins` to filter, `includes` to read, or both.

**Why both a model validation and a database constraint?**
Validations give clear messages to users. Constraints guarantee integrity when validations are bypassed or when two requests race. Uniqueness validation alone cannot stop a race.

**When would you use a service object?**
When logic spans several models, needs a transaction, or calls an outside system. Single-record rules stay in the model.

**Callbacks: good or bad?**
Fine for a record's own derived data, such as normalizing a CUSIP to uppercase. Risky for side effects across models or the outside world, because they fire implicitly on every save, including in specs and imports. Prefer an explicit service for workflows.

**How do you store money?**
Integer cents in a `bigint`, or `decimal` with a fixed scale. Never floats. Round once with a named rounding mode. Allocate remainders explicitly.

**`save` vs `save!`?**
`save` returns `false`. `save!` raises `RecordInvalid`. Use `save!` inside transactions so a failure rolls back.

**How would you make the dashboard faster with 10 million payments?**
Check `EXPLAIN ANALYZE` first. The partial index on unpaid `due_on` already fits the main query. Then paginate, and cache the per-issuer totals or keep them in a summary table updated in the same transaction as payments.

**What does `params.expect` protect against?**
Mass assignment. Only whitelisted keys reach the model. It also turns a malformed shape into a 400.

**How does React get into a Rails app here?**
`vite_rails` helpers in the layout print script tags. In development those point at the Vite dev server. In production they point at hashed files from `vite build`. Rails renders an empty `#root`. React and React Router take over from there.

**How do you keep the TypeScript types in sync with the API?**
Here, by hand, with each serializer naming its TypeScript type and request specs pinning the JSON. At scale, generate types from an OpenAPI spec or from the serializers.

**Why a monolith over microservices?**
One deploy, one test suite, no network boundary, and no distributed transactions. Split out a service only when a component needs independent scaling, isolation, or release cadence. Use modular boundaries inside the monolith first.

**What is a migration, and what is `schema.rb`?**
A migration is a versioned change script. `schema.rb` is the current state that Rails generates from the database. New environments load `schema.rb`. They do not replay every migration.

**What are the trade-offs of integer-backed vs string-backed enums?**
Integers are smaller and faster to compare. Strings are readable in SQL and safe to reorder. Either way, add a check constraint.
