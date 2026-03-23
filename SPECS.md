# bubl Specs

## Product Summary

`bubl` is a weekly, semi-anonymous social product for sharing how something in your life is hitting you right now.

The core promise is:

- you post one weekly `bubl`
- your post lasts 7 days
- the app shows other people in something genuinely similar
- there are no public profiles, no follower graph, and no private chat

This project currently targets an iOS MVP backed by Supabase.

## Product Pillars

- Ephemeral by default: posts are weekly and expire automatically.
- Anonymous enough to feel safe: no public identity layer, no social graph.
- Small but relevant feed: better to show a few strong matches than a lot of noise.
- Emotional framing matters: the product is about what you are going through and how it feels, not just raw topic clustering.
- Trust over volume: if the matching feels wrong, the product breaks faster than if the feed feels a little sparse.

## Current MVP Scope

### Authentication

- Sign in with Apple
- Anonymous development sign-in
- Session restoration on app launch

### Posting

- One `bubl` per user per week
- 3-step post flow:
  - what are you living through this week?
  - how are you feeling about it?
  - choose category + subcategory
- Soft guardrails:
  - blocks contact info / links / direct identifiers
  - non-blocking crisis prompt if language looks high-risk

### Feed

- Shows your weekly `bubl`
- Shows related `bubls` from the same week
- Uses strict subcategory matching when a subcategory exists
- Uses embeddings + heuristic fallback for ranking within the same subcategory
- Shows empty / partial states intentionally

### Reactions and Safety

- Lightweight reactions only
- No free-form comments
- No chat
- Reporting flow for inappropriate content
- Backend flagging support

### Localization

- The UI is moving toward system-language-driven `es/en`
- The repo already contains localized resources and locale-aware UI decisions
- Current status: partial but active implementation

## Core User Flow

1. User opens app
2. Auth session is restored
3. If the user has not posted this week:
   - show CTA to create a `bubl`
4. User posts via the 3-step flow
5. App generates embedding for the newly created `bubl`
6. Show brief “personalizing your bubble” state
7. Refresh feed
8. Show:
   - your own `bubl`
   - people “in the same thing this week”

## Navigation Flows

### Primary app navigation

- App launch
  - `loading` -> restore session
  - `signedOut` -> onboarding
  - `signedIn` -> feed

### Signed-out flow

- Onboarding screen
- Apple sign-in or anonymous dev sign-in
- After success -> feed

### Signed-in flow

- Feed root
  - see your own weekly `bubl`
  - see related `bubls`
  - open post flow if you have not posted yet
  - long press a card to report
  - tap a card to react

### Post flow

- Step 1: activity / situation
- Step 2: emotional framing
- Step 3: category + subcategory
- Personalized loading state
- Return to feed

### Secondary modal flows

- Reaction sheet
- Report sheet
- Crisis alert during posting

The app is intentionally shallow in navigation depth. This is by design: the product should feel immediate, not menu-heavy.

## Auth / Session

### Current auth modes

- Sign in with Apple
- Anonymous development sign-in

### Session lifecycle

- On launch, `AuthManager.restoreSession()` tries to recover a valid session
- If recovery succeeds:
  - app enters `signedIn`
  - user bootstrap runs against `users`
- If recovery fails:
  - app enters `signedOut`

### User bootstrap

On sign-in, the app upserts a row into `users` with:

- `id`
- `locale`

This is currently used to keep a minimal public user record aligned with auth.

### Important implementation files

- [Hubman/Core/AuthManager.swift](/Users/patominer/Documents/Proyectos/Hubman/Hubman/Core/AuthManager.swift)
- [Hubman/ViewModels/HubmanViewModel.swift](/Users/patominer/Documents/Proyectos/Hubman/Hubman/ViewModels/HubmanViewModel.swift)
- [Hubman/Views/ContentView.swift](/Users/patominer/Documents/Proyectos/Hubman/Hubman/Views/ContentView.swift)

## Local Persistence

### Current local persistence scope

This app currently uses local persistence in a minimal way.

Implemented:

- Supabase runtime URL override via `UserDefaults`
- Supabase anon key override via `UserDefaults`
- locale derived from system settings
- auth/session persistence is handled by Supabase SDK internals

Not currently implemented:

- offline-first local cache for feed data
- draft persistence for partially written posts
- local queue / retry layer for failed post submissions

### Relevant implementation

- [Hubman/ViewModels/HubmanViewModel.swift](/Users/patominer/Documents/Proyectos/Hubman/Hubman/ViewModels/HubmanViewModel.swift)
  - `SupabaseConfig.saveOverrides(...)`
  - runtime URL / anon key overrides
- [Hubman/Views/ContentView.swift](/Users/patominer/Documents/Proyectos/Hubman/Hubman/Views/ContentView.swift)
  - dev config UI

## API Integration

### Primary backend

- Supabase Postgres
- Supabase Auth
- Supabase Edge Functions
- Supabase RPCs

### Main API patterns in the app

- Auth:
  - restore session
  - Apple sign-in
  - sign-out
- Data:
  - `from("bubls")`
  - `from("users")`
  - `from("reports")`
  - reactions CRUD
- Functions:
  - `generate-embedding`
- RPC:
  - `match_bubls_by_embedding`

### Important integration behavior

- Most product data is fetched directly from Supabase from the client app
- Embeddings are generated through an Edge Function
- Vector nearest-neighbor lookup is done by RPC
- The app currently has a dev path for overriding Supabase URL and anon key at runtime

### Relevant files

- [Hubman/Core/SupabaseClient.swift](/Users/patominer/Documents/Proyectos/Hubman/Hubman/Core/SupabaseClient.swift)
- [Hubman/ViewModels/HubmanViewModel.swift](/Users/patominer/Documents/Proyectos/Hubman/Hubman/ViewModels/HubmanViewModel.swift)
- [Hubman/Core/EmbeddingService.swift](/Users/patominer/Documents/Proyectos/Hubman/Hubman/Core/EmbeddingService.swift)
- [supabase/functions/generate-embedding/index.ts](/Users/patominer/Documents/Proyectos/Hubman/supabase/functions/generate-embedding/index.ts)

## Feature Flags / Subscription Logic

### Current status

There is no real feature-flag system yet.

There is also no subscription, paywall, entitlements model, or premium feature gating in the current MVP.

### Practical implication

If product gating is added later, it should not be inferred from scattered UI conditionals.

Preferred future direction:

- one explicit feature-flag service
- one explicit entitlement/subscription service
- a small set of product capability checks like:
  - `canCreateMoreThanOneBublPerWeek`
  - `canSeeSecondaryExplorationSections`
  - `canAccessPremiumMatching`

### Current “pseudo-flag” behavior

The closest thing to a feature gate today is environment mode:

- production-like auth path
- development-only anonymous sign-in and runtime Supabase override

Those behaviors are currently UI-accessible rather than centrally managed.

## Error / Loading States

### Auth and onboarding

- onboarding sign-in errors surface inline
- app launch shows loading spinner while session restores

### Feed

- loading during refresh
- empty state if no related `bubls`
- partial state if only a few strong matches exist
- inline error copy if feed refresh fails

### Posting

- submit disabled until minimum content requirements are met
- blocking validation for unsafe identifying info
- crisis prompt is non-blocking but visible
- explicit submitting state on CTA
- explicit personalization/loading state before first feed render

### Reactions / Reports

- reactions show inline error copy
- reports favor completion UX over perfect transactional feedback

### Relevant files

- [Hubman/Views/ContentView.swift](/Users/patominer/Documents/Proyectos/Hubman/Hubman/Views/ContentView.swift)
- [Hubman/ViewModels/HubmanViewModel.swift](/Users/patominer/Documents/Proyectos/Hubman/Hubman/ViewModels/HubmanViewModel.swift)
- [Hubman/Features/Reactions/ReactionsViewModel.swift](/Users/patominer/Documents/Proyectos/Hubman/Hubman/Features/Reactions/ReactionsViewModel.swift)

## Permissions

### Current platform permissions

The app currently relies on very few platform permissions.

Implemented / required:

- Sign in with Apple capability
- network access to Supabase

Not currently used:

- camera
- microphone
- photos library
- contacts
- notifications
- location

### Safety / content permissions

The app also has “soft permissions” at product level:

- no personal contact info in posts
- no public identity graph
- no direct private messaging

These are product constraints, not iOS permission dialogs, but they are important to the system design.

## Matching Model

### Current Matching Layers

1. `category_id`
2. `subcategory_id`
3. inferred `topic_id`
4. embedding similarity inside the same subcategory
5. heuristic token/topic fallback if vector ranking is missing

### Important Current Product Rule

If a post has a subcategory, the feed should stay strict to that subcategory.

Example:

- `Hobbies > Gaming` should not quietly mix in `Hobbies > Food`
- if there are only 1-2 strong matches, show 1-2 strong matches

### Ranking Intent

- prioritize high-trust matches
- avoid “same broad category but wrong vibe”
- tolerate low density better than low relevance

## Data Model Snapshot

### `bubls`

Important fields:

- `activity_text`
- `feeling_text`
- `category_id`
- `subcategory_id`
- `topic_id`
- `language_code`
- `cluster_label` (legacy compatibility)
- `week_id`
- `expires_at`
- `embedding`

### Other relevant tables

- `users`
- `reactions`
- `reports`
- `seed_clusters`

## Important Architectural Reality

The repo contains a “cleaner” feature-based structure and also a legacy compiled path.

Right now, the active target behavior is still primarily wired through:

- `Hubman/App/HubmanApp.swift`
- `Hubman/Views/ContentView.swift`
- `Hubman/ViewModels/HubmanViewModel.swift`
- `Hubman/Models/HubmanModels.swift`

The feature folders under `Hubman/Features/*` are useful reference structure, but when changing behavior you must verify whether the active target is actually compiling that code path.

## Key Files by Concern

### App shell / theme

- [Hubman/App/HubmanApp.swift](/Users/patominer/Documents/Proyectos/Hubman/Hubman/App/HubmanApp.swift)
- [Hubman/App/BublApp.swift](/Users/patominer/Documents/Proyectos/Hubman/Hubman/App/BublApp.swift)

Use these for:

- app entrypoint
- shared palette (`BublPalette`)
- global typography helpers

## File / Module References

If you want a quick mental map, use this logical grouping:

### App

- [Hubman/App/HubmanApp.swift](/Users/patominer/Documents/Proyectos/Hubman/Hubman/App/HubmanApp.swift)
- [Hubman/App/BublApp.swift](/Users/patominer/Documents/Proyectos/Hubman/Hubman/App/BublApp.swift)

### Views

- [Hubman/Views/ContentView.swift](/Users/patominer/Documents/Proyectos/Hubman/Hubman/Views/ContentView.swift)
- [Hubman/Features/Feed/FeedView.swift](/Users/patominer/Documents/Proyectos/Hubman/Hubman/Features/Feed/FeedView.swift)
- [Hubman/Features/Feed/BublCardView.swift](/Users/patominer/Documents/Proyectos/Hubman/Hubman/Features/Feed/BublCardView.swift)
- [Hubman/Features/Onboarding/OnboardingView.swift](/Users/patominer/Documents/Proyectos/Hubman/Hubman/Features/Onboarding/OnboardingView.swift)
- [Hubman/Features/Post/Step1View.swift](/Users/patominer/Documents/Proyectos/Hubman/Hubman/Features/Post/Step1View.swift)
- [Hubman/Features/Post/Step2View.swift](/Users/patominer/Documents/Proyectos/Hubman/Hubman/Features/Post/Step2View.swift)
- [Hubman/Features/Reactions/ReactionSheetView.swift](/Users/patominer/Documents/Proyectos/Hubman/Hubman/Features/Reactions/ReactionSheetView.swift)
- [Hubman/Features/Report/ReportView.swift](/Users/patominer/Documents/Proyectos/Hubman/Hubman/Features/Report/ReportView.swift)

### ViewModels

- [Hubman/ViewModels/HubmanViewModel.swift](/Users/patominer/Documents/Proyectos/Hubman/Hubman/ViewModels/HubmanViewModel.swift)
- [Hubman/Features/Feed/FeedViewModel.swift](/Users/patominer/Documents/Proyectos/Hubman/Hubman/Features/Feed/FeedViewModel.swift)
- [Hubman/Features/Post/PostViewModel.swift](/Users/patominer/Documents/Proyectos/Hubman/Hubman/Features/Post/PostViewModel.swift)
- [Hubman/Features/Reactions/ReactionsViewModel.swift](/Users/patominer/Documents/Proyectos/Hubman/Hubman/Features/Reactions/ReactionsViewModel.swift)

### Services / Core

- [Hubman/Core/AuthManager.swift](/Users/patominer/Documents/Proyectos/Hubman/Hubman/Core/AuthManager.swift)
- [Hubman/Core/SupabaseClient.swift](/Users/patominer/Documents/Proyectos/Hubman/Hubman/Core/SupabaseClient.swift)
- [Hubman/Core/EmbeddingService.swift](/Users/patominer/Documents/Proyectos/Hubman/Hubman/Core/EmbeddingService.swift)

### Models

- [Hubman/Models/HubmanModels.swift](/Users/patominer/Documents/Proyectos/Hubman/Hubman/Models/HubmanModels.swift)
- [Hubman/Models/Bubl.swift](/Users/patominer/Documents/Proyectos/Hubman/Hubman/Models/Bubl.swift)
- [Hubman/Models/Reaction.swift](/Users/patominer/Documents/Proyectos/Hubman/Hubman/Models/Reaction.swift)
- [Hubman/Models/Report.swift](/Users/patominer/Documents/Proyectos/Hubman/Hubman/Models/Report.swift)

### Localization

- [Hubman/Localization/Localizable.xcstrings](/Users/patominer/Documents/Proyectos/Hubman/Hubman/Localization/Localizable.xcstrings)

### Backend

- [supabase/functions/generate-embedding/index.ts](/Users/patominer/Documents/Proyectos/Hubman/supabase/functions/generate-embedding/index.ts)
- [supabase/migrations/20260318_bubl_mvp.sql](/Users/patominer/Documents/Proyectos/Hubman/supabase/migrations/20260318_bubl_mvp.sql)
- [supabase/migrations/202603181430_bubl_action_topic_tags.sql](/Users/patominer/Documents/Proyectos/Hubman/supabase/migrations/202603181430_bubl_action_topic_tags.sql)
- [supabase/migrations/202603181620_embedding_debug.sql](/Users/patominer/Documents/Proyectos/Hubman/supabase/migrations/202603181620_embedding_debug.sql)
- [supabase/migrations/20260319_bubl_mvp_simplify.sql](/Users/patominer/Documents/Proyectos/Hubman/supabase/migrations/20260319_bubl_mvp_simplify.sql)
- [supabase/migrations/20260320_bubl_subcategory_topic_language.sql](/Users/patominer/Documents/Proyectos/Hubman/supabase/migrations/20260320_bubl_subcategory_topic_language.sql)
- [supabase/migrations/20260320_bubl_embedding_matches.sql](/Users/patominer/Documents/Proyectos/Hubman/supabase/migrations/20260320_bubl_embedding_matches.sql)
- [supabase/scripts/seed_bubls.mjs](/Users/patominer/Documents/Proyectos/Hubman/supabase/scripts/seed_bubls.mjs)
- [supabase/scripts/backfill_bubl_embeddings.mjs](/Users/patominer/Documents/Proyectos/Hubman/supabase/scripts/backfill_bubl_embeddings.mjs)

### Main active UI flow

- [Hubman/Views/ContentView.swift](/Users/patominer/Documents/Proyectos/Hubman/Hubman/Views/ContentView.swift)

This is the most important file for:

- onboarding shell
- main feed layout
- post flow UI
- personalization/loading state
- report/reaction UI in the legacy active path

### Main active product logic

- [Hubman/ViewModels/HubmanViewModel.swift](/Users/patominer/Documents/Proyectos/Hubman/Hubman/ViewModels/HubmanViewModel.swift)

This file currently holds a lot of real product behavior:

- auth helpers
- guardrails
- topic inference
- subcategory definitions
- post submission
- embedding generation trigger
- feed refresh
- ranking logic
- debug logging

If feed behavior changes, this is usually the first file to inspect.

### Main active models

- [Hubman/Models/HubmanModels.swift](/Users/patominer/Documents/Proyectos/Hubman/Hubman/Models/HubmanModels.swift)

Important for:

- `BublCategory`
- active `Bubl` decoding shape
- canonical `category/subcategory/topic/language` handling

### Auth / Supabase client

- [Hubman/Core/AuthManager.swift](/Users/patominer/Documents/Proyectos/Hubman/Hubman/Core/AuthManager.swift)
- [Hubman/Core/SupabaseClient.swift](/Users/patominer/Documents/Proyectos/Hubman/Hubman/Core/SupabaseClient.swift)

Important for:

- session lifecycle
- Apple sign-in
- anon dev sign-in
- client configuration

### Embeddings

- [Hubman/Core/EmbeddingService.swift](/Users/patominer/Documents/Proyectos/Hubman/Hubman/Core/EmbeddingService.swift)
- [supabase/functions/generate-embedding/index.ts](/Users/patominer/Documents/Proyectos/Hubman/supabase/functions/generate-embedding/index.ts)
- [supabase/migrations/20260320_bubl_embedding_matches.sql](/Users/patominer/Documents/Proyectos/Hubman/supabase/migrations/20260320_bubl_embedding_matches.sql)
- [supabase/scripts/backfill_bubl_embeddings.mjs](/Users/patominer/Documents/Proyectos/Hubman/supabase/scripts/backfill_bubl_embeddings.mjs)

Important for:

- generating embeddings
- nearest-neighbor matching
- backfilling seeded/demo data

### Seed / demo environment

- [supabase/scripts/seed_bubls.mjs](/Users/patominer/Documents/Proyectos/Hubman/supabase/scripts/seed_bubls.mjs)

Important behavior:

- seeds current ISO week by default
- `RESET_SEED=1` clears current-week seed bubls only
- preserves prior-week seed data so weekly filtering can be validated

### Schema / backend rules

- [supabase/migrations/20260318_bubl_mvp.sql](/Users/patominer/Documents/Proyectos/Hubman/supabase/migrations/20260318_bubl_mvp.sql)
- [supabase/migrations/202603181430_bubl_action_topic_tags.sql](/Users/patominer/Documents/Proyectos/Hubman/supabase/migrations/202603181430_bubl_action_topic_tags.sql)
- [supabase/migrations/202603181620_embedding_debug.sql](/Users/patominer/Documents/Proyectos/Hubman/supabase/migrations/202603181620_embedding_debug.sql)
- [supabase/migrations/20260319_bubl_mvp_simplify.sql](/Users/patominer/Documents/Proyectos/Hubman/supabase/migrations/20260319_bubl_mvp_simplify.sql)
- [supabase/migrations/20260320_bubl_subcategory_topic_language.sql](/Users/patominer/Documents/Proyectos/Hubman/supabase/migrations/20260320_bubl_subcategory_topic_language.sql)
- [supabase/migrations/20260320_bubl_embedding_matches.sql](/Users/patominer/Documents/Proyectos/Hubman/supabase/migrations/20260320_bubl_embedding_matches.sql)

Use these to understand:

- table structure
- RLS assumptions
- weekly feed mechanics
- canonical fields
- embedding RPCs

## Current UX Decisions

### Feed framing

- “Your bubble” is the primary lens
- the feed is framed as “what people in the same thing are saying this week”
- sparse feeds are acceptable if relevance stays high

### Partial feed state

If only a few good matches exist, show a partial-state explanation rather than filling with low-trust noise.

### Personalization transition

After posting, the app briefly shows a loading state while generating the embedding so the first feed render can be more accurate.

## Current Design Direction

The active visual direction is shifting toward a peacock/turquoise palette:

- turquoise / aqua base
- lime highlights
- deep violet ornament details
- deep petrol ink instead of near-black

This should feel:

- more alive
- more memorable
- less like a generic wellness app

## Known Constraints / Caveats

- The legacy compiled path is still the source of truth for many interactions.
- Some localization is still mixed between:
  - hardcoded copy
  - locale-aware inline logic
  - `Localizable.xcstrings`
- Embedding ranking depends on:
  - deployed `generate-embedding` function
  - valid environment secrets
  - embeddings actually existing on candidate rows
- For development, `generate-embedding` may currently be deployed with relaxed JWT checks; that should be revisited before production.

## Production Caution

If `generate-embedding` is deployed without JWT verification for development convenience, do not treat that as production-safe.

Before production:

- restore proper auth verification
- validate ownership/permissions explicitly
- keep service-role usage protected server-side

## Current “Good Next Steps”

1. Continue UI/UX polish of the main loop
2. Finish localization cleanup for remaining visible strings
3. Tune embedding-distance thresholds for sparse clusters
4. Eventually add a secondary section like:
   - “Other things in gaming this week”
   But keep it visually separate from the primary bubble feed

## How To Work In This Repo

When touching this project, use this order:

1. Check whether the behavior lives in the legacy active path or in `Features/*`
2. Verify the matching / product rule in `Hubman/ViewModels/HubmanViewModel.swift`
3. Verify the UI framing in `Hubman/Views/ContentView.swift`
4. Check schema or seed assumptions in `supabase/migrations/*` and `supabase/scripts/*`
5. If embeddings are involved, verify:
   - new bubl has non-null embedding
   - candidates have non-null embedding
   - RPC `match_bubls_by_embedding(...)` returns rows

## Source of Truth

If `README.md` and implementation drift, trust:

1. the active code path
2. the active migrations
3. the current product decisions encoded in `ContentView.swift` and `HubmanViewModel.swift`
