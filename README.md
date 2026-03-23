# bubl MVP (iOS + Supabase)

This repo now contains an MVP implementation of **bubl**:
- iOS 17+ SwiftUI app (MVVM + `@Observable`)
- Supabase schema + RLS + pg_cron + report flag trigger
- Ephemeral weekly feed by fixed category, closed reactions, reporting, localization (`en`, `es`, `pt`)

## iOS app structure

Requested architecture files are scaffolded under:
- `Hubman/App`
- `Hubman/Core`
- `Hubman/Features/*`
- `Hubman/Models`
- `Hubman/Localization/Localizable.xcstrings`

The current Xcode target is still bound to the legacy 4 source slots, so the same MVP logic is also mapped in:
- `Hubman/App/HubmanApp.swift`
- `Hubman/Views/ContentView.swift`
- `Hubman/ViewModels/HubmanViewModel.swift`
- `Hubman/Models/HubmanModels.swift`

## Backend files

- SQL migration: `supabase/migrations/20260318_bubl_mvp.sql`
- SQL migration: `supabase/migrations/202603181430_bubl_action_topic_tags.sql`
- SQL migration: `supabase/migrations/202603181620_embedding_debug.sql`
- SQL migration: `supabase/migrations/20260319_bubl_mvp_simplify.sql`
- SQL migration: `supabase/migrations/20260320_bubl_subcategory_topic_language.sql`
- SQL migration: `supabase/migrations/20260320_bubl_embedding_matches.sql`

## Setup

1. Add Supabase Swift SDK package in Xcode:
   - URL: `https://github.com/supabase/supabase-swift`
2. Add build settings (or Info.plist keys):
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
3. In Supabase project:
   - Enable `pg_cron`
   - Apply migration SQL
4. Enable Sign in with Apple for your Supabase Auth + Apple developer configuration.

## Notes

- Crisis keyword detection is client-side, non-blocking, and shows resource modal.
- Feed visibility uses `is_active=true`, `is_flagged=false`, current `week_id`, and `expires_at > now()`.
- Long press a bubl card to report.

## Demo Data Seed (100 bubls)

Use this script to create 100 synthetic users + 100 weekly bubls (includes the 3 scenarios you specified):

- `supabase/scripts/seed_bubls.mjs`

Run:

```bash
SUPABASE_URL="https://your-project.supabase.co" \
SUPABASE_SERVICE_ROLE_KEY="your-service-role-key" \
node supabase/scripts/seed_bubls.mjs
```

Optional:

```bash
BUBL_SEED_COUNT=100
```

Reset previous seeded users/bubls and recreate clean demo data:

```bash
RESET_SEED=1 SUPABASE_URL="https://your-project.supabase.co" SUPABASE_SERVICE_ROLE_KEY="your-service-role-key" node supabase/scripts/seed_bubls.mjs
```

Notes:
- Each seeded bubl expires in 7 days (`expires_at`), so it naturally disappears.
- The script now sets `category_id` directly for fixed-bubble feed testing.
- Re-run weekly only if you want a consistently populated demo/staging environment.
