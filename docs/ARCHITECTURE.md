# Architecture

This app is one Rails process that owns the database, the JSON API, and the HTML page that boots React. Vite compiles the TypeScript. Rails decides which compiled file the page loads. There is no second backend and no separately deployed SPA.

This document follows two requests end to end:

1. The first page load, which shows how React gets mounted inside the monolith.
2. Creating a bond, which touches every layer: route, controller, strong params, service object, transaction, models, database constraints, serializer, and React.

## How vite_rails mounts React inside Rails

Three files connect Rails to Vite.

- `config/vite.json` sets `sourceCodeDir` to `app/frontend` and the dev server port to 3036.
- `vite.config.ts` loads two Vite plugins. `vite-plugin-ruby` reads `config/vite.json` and treats every file in `app/frontend/entrypoints/` as an entrypoint. `@vitejs/plugin-react` compiles JSX and enables fast refresh.
- `app/views/layouts/application.html.erb` calls three helpers from the `vite_rails` gem:

```erb
<%= vite_client_tag %>
<%= vite_react_refresh_tag %>
<%= vite_typescript_tag "application.tsx" %>
```

In development, those helpers print `<script>` tags that point at the Vite dev server, for example `http://localhost:3036/vite-dev/entrypoints/application.tsx`. The browser fetches the TypeScript from Vite, and Vite compiles it on request. Rails never touches the JavaScript.

In production, `bin/rails assets:precompile` runs `vite build`. Vite writes hashed files to `public/vite` plus a manifest. The same helpers then read the manifest and print `<script src="/vite/assets/application-3f9a1c.js">`. Puma or a CDN serves the static files. The view code does not change between environments.

`bin/dev` runs both processes through foreman, as listed in `Procfile.dev`:

```text
vite: bin/vite dev
web: bin/rails server -p 3000
```

## Request 1: the first page load

The user opens `http://localhost:3000/bonds/issuers/2`.

1. **Route.** `config/routes.rb` checks the `api` namespace first. The path does not start with `/api`, so the catch-all matches:

   ```ruby
   get "*path", to: "spa#show", constraints: ->(req) { !req.path.start_with?("/api") }
   ```

   The catch-all exists so a browser refresh on any React URL still gets the React shell. Without it, refreshing `/bonds/issuers/2` would return a Rails 404.

2. **Controller.** `SpaController#show` in `app/controllers/spa_controller.rb` is empty. Rails convention renders `app/views/spa/show.html.erb`, which is `<div id="root"></div>`, inside the application layout.

3. **Layout.** The layout adds `csrf_meta_tags`, which puts a per-session token in `<meta name="csrf-token">`, and the three Vite tags.

4. **React boots.** `app/frontend/entrypoints/application.tsx` finds `#root` and renders `<BrowserRouter><App /></BrowserRouter>`.

5. **Client routing.** `app/frontend/App.tsx` matches `/bonds/issuers/:id` and renders `IssuerDetail`. From here on, clicking a tab or link changes the URL with the History API. The browser does not ask Rails for a new page.

6. **Data.** `IssuerDetail` calls `useApi('/api/issuers/2')` from `app/frontend/lib/useApi.ts`, which calls `api.get` in `app/frontend/api/client.ts`. That request is Request 1b below, a normal JSON request to the same Rails process.

### Request 1b: GET /api/issuers/2

1. `resources :issuers, only: [:index, :show]` inside `namespace :api` maps the path to `Api::IssuersController#show`.
2. The controller in `app/controllers/api/issuers_controller.rb` loads the issuer and preloads its whole tree:

   ```ruby
   issuer = Issuer.includes(bonds: :debt_service_payments).find(params[:id])
   ```

3. ActiveRecord runs exactly three queries, no matter how many bonds the issuer has. This is from `log/development.log` for an issuer with five bonds:

   ```sql
   SELECT "issuers".* FROM "issuers" WHERE "issuers"."id" = 2 LIMIT 1
   SELECT "bonds".* FROM "bonds" WHERE "bonds"."issuer_id" = 2 ORDER BY "bonds"."maturity_on" ASC, "bonds"."id" ASC
   SELECT "debt_service_payments".* FROM "debt_service_payments" WHERE "debt_service_payments"."bond_id" IN (7, 8, 9, 10, 3) ORDER BY "debt_service_payments"."due_on" ASC
   ```

   The `ORDER BY` clauses come from the association scopes in `app/models/issuer.rb` and `app/models/bond.rb`.

4. `IssuerSerializer.detail` in `app/serializers/issuer_serializer.rb` builds a hash. It calls `BondSerializer.with_schedule` for each bond and `PaymentSerializer.call` for each payment. Because the data is preloaded, none of these calls touch the database.
5. `render json:` turns the hash into JSON.
6. Back in React, the response is typed as `IssuerDetail` from `app/frontend/types/bonds.ts`. That type mirrors the serializer by hand. Each serializer file names the TypeScript type it feeds.

## Request 2: creating a bond

The user fills in `app/frontend/pages/bonds/NewBondForm.tsx` and clicks **Create bond**.

### In the browser

1. The form holds strings. On submit, `dollarsToCents("2,500,000")` in `app/frontend/lib/format.ts` returns `250000000`, using string math so no float rounding touches money. `percentToFraction("4.25")` returns `"0.04250"`.
2. `api.post('/api/bonds', { bond })` sends JSON with an `X-CSRF-Token` header copied from the meta tag.

### In Rails

3. **Routing.** `resources :bonds, only: :create` maps `POST /api/bonds` to `Api::BondsController#create`. The namespace sets `defaults: { format: :json }`.

4. **CSRF check.** `ApplicationController` inherits `protect_from_forgery` from `ActionController::Base`. Rails compares the header with the session token. A cross-site form post would not have the token and would be rejected. The test environment turns this check off, which is the Rails default.

5. **Strong params.** `bond_params` in `app/controllers/api/bonds_controller.rb` calls:

   ```ruby
   params.expect(bond: [:issuer_id, :series_name, :cusip, :par_amount_cents, :coupon_rate, :issued_on, :maturity_on])
   ```

   `params.expect` is new in Rails 8. It raises `ActionController::ParameterMissing` if `bond` is missing or has the wrong shape, and it drops any key not in the list. A client cannot set `id` or `created_at`.

6. **Service object.** The controller calls `Bonds::Create.call(bond_params)` in `app/services/bonds/create.rb`:

   ```ruby
   Bond.transaction do
     bond.save!
     schedule_for(bond).each do |row|
       bond.debt_service_payments.create!(row.to_h)
     end
   end
   ```

   `save!` and `create!` raise `ActiveRecord::RecordInvalid` on failure. An exception inside `transaction` rolls back every insert in the block, so a bond can never exist without its schedule.

7. **Pure calculation.** `Bonds::ScheduleGenerator` in `app/services/bonds/schedule_generator.rb` takes the terms and returns `Row` value objects. It does no I/O. Principal is `par / years`, with the remainder on the last payment so the principal sums to par exactly. Interest is the outstanding balance times the coupon rate, rounded half-to-even to whole cents.

8. **Model validations.** `Bond` in `app/models/bond.rb` validates presence, CUSIP format and uniqueness, positive par, a coupon between 0 and 1, and maturity after issue.

9. **Database constraints.** `db/migrate/20261008120100_create_bonds.rb` repeats the critical rules in Postgres: `NOT NULL` columns, a unique index on `cusip`, and check constraints on par, coupon, and dates. Validations give friendly messages. Constraints stop data that skips validations, such as `insert_all`, a console session, or two requests racing past the uniqueness check.

10. **Serializer.** `BondSerializer.with_schedule(bond)` returns the bond, its outstanding principal, and every payment. Money stays integer cents. `coupon_rate` goes out as the string `"0.0425"` because a JSON number would be parsed as a float.

11. **Response.** `render json: ..., status: :created` sends a 201.

### When something fails

`Api::BaseController` in `app/controllers/api/base_controller.rb` uses `rescue_from` to turn exceptions into one JSON shape:

| Exception | Status | Body |
| --- | --- | --- |
| `ActiveRecord::RecordInvalid` | 422 | `{ errors: record.errors.to_hash }` |
| `ActiveRecord::RecordNotFound` | 404 | `{ errors: { base: ["Issuer not found"] } }` |
| `ActionController::ParameterMissing` | 400 | `{ errors: { bond: ["is required"] } }` |
| `ActiveRecord::RecordNotUnique` | 422 | `{ errors: { base: ["already exists"] } }` |

Controllers stay free of `if save ... else render errors` branches. They call the bang method and let the base class handle the failure path.

`client.ts` turns any non-2xx response into an `ApiError` that carries the `errors` hash. `NewBondForm` maps server field names to form field names (`par_amount_cents` to `par_dollars`) and shows each message under its field. See `docs/screenshots/02-new-bond-validation-error.png`.

### Back in the browser

12. On success, the form navigates to `/bonds/issuers/:issuer_id?bond=:id`. `IssuerDetail` fetches the issuer (Request 1b) and expands the new bond's accordion. See `docs/screenshots/03-issuer-detail-new-bond-schedule.png`.

## Marking a payment paid

**Mark paid** in `IssuerDetail` sends `PATCH /api/debt_service_payments/:id` with `{ debt_service_payment: { paid_on: "2026-10-08" } }`. The controller permits only `paid_on`, so amounts cannot change through the API. The response includes the new `status`, which the model derives:

```ruby
def status(today = Date.current)
  if paid_on then :paid
  elsif due_on < today then :overdue
  else :upcoming
  end
end
```

`status` is not a column. A stored status would go stale at midnight when an upcoming payment becomes overdue, and something would have to update it. Deriving it from `paid_on` and the date means it is always correct.

The React page replaces the one payment in local state and recomputes the bond's outstanding principal. It does not refetch the issuer.

## Where each concern lives

| Concern | Location |
| --- | --- |
| URL to controller | `config/routes.rb` |
| HTTP boundary: params, status codes, error JSON | `app/controllers/api/` |
| Business rules for one record | `app/models/` |
| Multi-record workflows and calculations | `app/services/` |
| JSON shape | `app/serializers/` |
| Data integrity | `db/migrate/` and `db/schema.rb` |
| JSON shape, as the frontend sees it | `app/frontend/types/` |
| HTTP from the browser | `app/frontend/api/client.ts` |
| Screens | `app/frontend/pages/` |
