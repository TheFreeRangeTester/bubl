# Project Specs

This document describes the currently implemented product behavior in the active runtime path of the app.
In this repository, the primary shipped flow is still driven by `Hubman/Views/ContentView.swift`, `Hubman/ViewModels/HubmanViewModel.swift`, and `Hubman/Models/HubmanModels.swift`.
Files under `Hubman/Features/...` exist, but they do not always represent the path currently used at runtime.

## FEAT-1 Authentication and session bootstrap
**Priority**: High
**Status**: Done
**Related Components**: `Hubman/ViewModels/HubmanViewModel.swift`, `Hubman/Views/ContentView.swift`, `Hubman/App/HubmanApp.swift`

Acceptance Criteria:
- The app restores an existing Supabase session on launch and routes signed-in users to the feed.
- The active onboarding screen in `Hubman/Views/ContentView.swift` supports Sign in with Apple and a development anonymous sign-in path.
- Signing in upserts the current user into `users` with the current locale.
- Signing out clears the local session and returns the app to the onboarding flow.

## FEAT-2 Weekly bubl creation flow
**Priority**: High
**Status**: Done
**Related Components**: `Hubman/Views/ContentView.swift`, `Hubman/ViewModels/HubmanViewModel.swift`, `Hubman/Models/HubmanModels.swift`, `supabase/migrations/20260319_bubl_mvp_simplify.sql`

Acceptance Criteria:
- Users create a bubl in a three-step flow: situation, feeling, then category and subcategory selection.
- Step 1 requires at least 10 characters and trims the activity text to 140 characters.
- Step 2 requires at least 12 characters and trims the feeling text to 220 characters.
- The final step shows a preview card built from the current draft before posting.
- The system allows only one active bubl per user per ISO week and converts duplicate insert failures into a user-facing weekly-limit error.
- Posting stores `category_id`, `subcategory_id`, `topic_id`, `language_code`, `cluster_label`, `week_id`, and a seven-day expiration when the current schema is available.

## FEAT-3 Posting guardrails and crisis prompt
**Priority**: High
**Status**: Done
**Related Components**: `Hubman/ViewModels/HubmanViewModel.swift`, `Hubman/Views/ContentView.swift`, `supabase/migrations/20260319_bubl_mvp_simplify.sql`

Acceptance Criteria:
- The active post flow blocks submissions that contain hashtags, links, email addresses, or phone numbers before insert.
- The database trigger `validate_bubl_content_trigger` rejects posts that contain external links, email addresses, phone numbers, or `@` handles.
- The post flow shows a crisis-help prompt when the feeling text matches supported crisis keywords.
- The crisis prompt does not prevent submission by itself.
- The post flow returns a validation error if required text fields are incomplete.

## FEAT-4 Weekly bubble feed
**Priority**: High
**Status**: Done
**Related Components**: `Hubman/Views/ContentView.swift`, `Hubman/ViewModels/HubmanViewModel.swift`, `Hubman/Models/HubmanModels.swift`

Acceptance Criteria:
- The feed loads the current user's active, unflagged bubl for the current ISO week as the bubble anchor.
- Related bubls are fetched only from the same week and exclude the current user's own rows.
- Expired, inactive, or flagged bubls are excluded from the feed.
- The UI shows distinct states for locked, empty, and partial bubbles.
- The active feed toolbar in `Hubman/Views/ContentView.swift` exposes a `Reset week` action.
- The `Reset week` action calls `deleteMyBublThisWeek(currentUserID:)` in `Hubman/ViewModels/HubmanViewModel.swift`, which deletes the current user's current-week row from `bubls` and clears the local feed state.

## FEAT-5 Subcategory-based matching
**Priority**: High
**Status**: Done
**Related Components**: `Hubman/ViewModels/HubmanViewModel.swift`, `Hubman/Models/HubmanModels.swift`, `supabase/migrations/20260320_bubl_embedding_matches.sql`

Acceptance Criteria:
- The feed uses `subcategory_id` as the canonical subcategory when available and falls back to `cluster_label` for legacy rows.
- When the anchor bubl has a subcategory, matching stays in strict subcategory mode before considering any broader fallback categories.
- The embedding RPC only returns candidates from the same week and same subcategory as the anchor bubl.
- The feed does not mix other subcategories into the primary bubble just to fill more slots.

## FEAT-6 Topic inference for fine ranking
**Priority**: Medium
**Status**: Done
**Related Components**: `Hubman/ViewModels/HubmanViewModel.swift`, `Hubman/Models/HubmanModels.swift`

Acceptance Criteria:
- The app infers a `topic_id` from the activity and feeling text when a bubl is posted.
- Topic inference supports multiple category families, including work, study, health, relationships, creativity, life, and hobbies.
- The inferred topic is stored with new posts when the current schema is available.
- The feed uses inferred topic and token overlap as heuristic ranking signals when embeddings are absent or tied.

## FEAT-7 Embedding generation and vector ranking
**Priority**: High
**Status**: Done
**Related Components**: `Hubman/ViewModels/HubmanViewModel.swift`, `supabase/functions/generate-embedding/index.ts`, `supabase/migrations/20260320_bubl_embedding_matches.sql`

Acceptance Criteria:
- Publishing a bubl triggers the `generate-embedding` Supabase Edge Function with the combined activity and feeling text.
- The Edge Function generates embeddings with OpenAI `text-embedding-3-small` and stores the vector on the `bubls` row.
- The feed loads candidate embedding matches from `match_bubls_by_embedding`.
- Embedding-ranked candidates are ordered ahead of purely heuristic candidates when a vector match exists.
- The feed drops embedding matches that are too distant from the best result instead of always filling all available slots.

## FEAT-8 Post-personalization loading state
**Priority**: Medium
**Status**: Done
**Related Components**: `Hubman/Views/ContentView.swift`, `Hubman/ViewModels/HubmanViewModel.swift`

Acceptance Criteria:
- After the user taps Post, the app shows a dedicated personalization state instead of dismissing immediately.
- The personalization state remains visible while the post submission and embedding generation complete.
- The post sheet dismisses only after the share flow returns success.
- The feed refresh runs after a successful post so the user lands on the updated weekly bubble.

## FEAT-9 Reactions without comments or chat
**Priority**: Medium
**Status**: Done
**Related Components**: `Hubman/Views/ContentView.swift`, `Hubman/ViewModels/HubmanViewModel.swift`, `Hubman/Models/HubmanModels.swift`, `supabase/migrations/20260319_bubl_mvp_simplify.sql`

Acceptance Criteria:
- Tapping a related bubl opens a reaction sheet instead of a comment thread.
- Reactions are limited to predefined reaction kinds from `ReactionKind`.
- The active reaction sheet implementation lives inside `Hubman/Views/ContentView.swift`.
- The reaction sheet loads existing reactions for the selected bubl and shows counts per reaction kind.
- Submitting a reaction upserts one reaction per `bubl_id,user_id` pair and reloads the sheet state.
- The product copy explicitly states that there is no comments system or private chat in this flow.

## FEAT-10 Reporting and moderation gating
**Priority**: High
**Status**: Done
**Related Components**: `Hubman/Views/ContentView.swift`, `Hubman/Models/HubmanModels.swift`, `supabase/migrations/20260318_bubl_mvp.sql`

Acceptance Criteria:
- Long-pressing a feed card opens a report flow for the selected bubl.
- The active report flow implementation lives inside `Hubman/Views/ContentView.swift`.
- The report flow inserts a `reports` row with reporter ID, reported bubl ID, and a selected reason.
- The report flow shows a confirmation state even if the insert request fails.
- The database flags a bubl after three reports through the `reports_flag_bubl_trigger` trigger.
- Flagged bubls are excluded from the main feed by both row-level policies and feed queries.

## FEAT-11 Localization by system language
**Priority**: Medium
**Status**: In Progress
**Related Components**: `Hubman/Views/ContentView.swift`, `Hubman/Models/HubmanModels.swift`, `Hubman/ViewModels/HubmanViewModel.swift`, `Hubman/Localization/Localizable.xcstrings`

Acceptance Criteria:
- The app chooses English or Spanish UI copy based on the current system language.
- Category and subcategory labels switch between English and Spanish at runtime.
- The post flow, feed shell, reporting flow, and personalization state contain bilingual UI strings.
- The app does not expose an in-app language picker and relies on system language selection.

## FEAT-12 Current-week seed and embedding backfill tooling
**Priority**: Medium
**Status**: Done
**Related Components**: `supabase/scripts/seed_bubls.mjs`, `supabase/scripts/backfill_bubl_embeddings.mjs`, `supabase/functions/generate-embedding/index.ts`

Acceptance Criteria:
- The seed script creates demo bubls for the current ISO week by default.
- `RESET_SEED=1` clears only the current week's seeded bubls and preserves previous-week seed data.
- The seed script uses stable seed identities so reruns do not require creating a new set of seed users each time.
- The backfill script finds current-week bubls with missing embeddings and calls `generate-embedding` for each row.
- The backfill script can be limited by week, row count, and concurrency through environment variables.
