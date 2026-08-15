# Positive Elijoe Bet

Portable Windows desktop admin app for the **Positive Elijoe Bet** platform.
Built with Flutter (Windows), data via Supabase PostgREST + Auth, and one
site endpoint for full user deletion.

## Features

- **Dashboard** – live counters: total users, active subscriptions, revenue,
  total payments, published predictions by category (FREE / VIP / VVIP),
  plus the 10 most recent transactions.
- **Predictions** – full CRUD: create, edit, delete, publish/unpublish,
  set category, status, odds, booking code, confidence and analysis.
- **Results** – mark predictions Won / Lost / Void with optional payout odds.
- **News & Tips** – create, edit, publish/unpublish, delete articles.
- **Plans** – manage prediction_plans: name, price, duration days, description.
- **Teams** – manage teams table (rank, points, form).
- **Subscriptions** – list, revoke (mark cancelled), delete stale ones.
- **Payments** – list with user + plan join, filter by status, **purge
  abandoned/pending payments** older than 15–120 minutes.
- **Users** – list, search, ban / unban, **delete** (needs the site endpoint,
  since deleting `auth.users` requires the service role).
- **Notifications** – broadcast push notifications to all users or an
  audience (published=1 pushes to the PWA; pending=0 drafts).
- **Settings** – view / update `site_settings` row (id=1).

## Requirements

- Flutter 3.22+ (only needed for local dev; CI builds the app for you)
- A Supabase project with the **Positive Elijoe Bet** schema + RLS policies
- Paystack keys configured in the website
- The site endpoint `api/admin-users.php` uploaded to the website root so the
  app can hard-delete users

## Build

The GitHub Actions workflow builds a portable Windows zip automatically on
every push to `main` (and can be run manually from the Actions tab). The
binary is fully self-contained — copy the zip to any Windows PC and run.

Repository secrets required:

| Secret            | Value                                                  |
|-------------------|--------------------------------------------------------|
| `SUPABASE_URL`    | `https://<project>.supabase.co`                        |
| `SUPABASE_ANON_KEY` | Supabase anon (publishable) key                     |
| `ADMIN_API_BASE`  | Website origin, e.g. `https://semdev.site.je`          |

## Local development

```bash
flutter pub get
flutter run -d windows --dart-define=SUPABASE_URL=https://<project>.supabase.co --dart-define=SUPABASE_ANON_KEY=<anon-key> --dart-define=ADMIN_API_BASE=https://semdev.site.je
```

Only `admin` role accounts (not banned) can sign in. See `auth.php` /
`is_admin()` on the site for the matching rule.

## Website endpoint (user deletion)

`auth.users` rows cannot be deleted with an anon token even under RLS, so the
app calls `POST api/admin-users.php` (guarded by `require_admin()`) with:

```json
{ "action": "delete_user", "user_id": "<uuid>" }
```

Upload `api/admin-users.php` to the site (see that file's header) and set the
`ADMIN_API_BASE` secret to your site origin.
