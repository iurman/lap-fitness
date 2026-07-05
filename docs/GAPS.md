# LAP Fitness — Gap Analysis & Roadmap (Phase 2)

> **What this is:** A prioritized gap analysis built on `docs/CURRENT_STATE.md`. Gaps are grouped
> into three buckets — **Functionality**, **User flow**, **UI/UX** — each with why it matters,
> severity (P0–P3), rough effort (S/M/L), and dependencies. A phased, milestone-based roadmap
> follows. No code was changed to produce this (the only edits so far are the safe quick-wins
> already shipped: dead-asset removal + web-build verification).
>
> **Severity:** P0 = crash / data corruption on a normal path · P1 = core feature broken or
> unverifiable security · P2 = degraded / confusing / partial · P3 = polish / hygiene.
> **Effort:** S ≈ <½ day · M ≈ ½–2 days · L ≈ multi-day / needs design.
> Every gap has a stable **ID** so the roadmap and dependencies can reference it. `file:line`
> citations point at the evidence in the code; see `CURRENT_STATE.md` for full traces.

---

## A. Functionality gaps (missing / incomplete / broken behavior)

| ID | Gap | Why it matters | Sev | Effort | Deps |
|----|-----|----------------|-----|--------|------|
| **F1** | Account-settings null-crash: `_formKey.currentState!.reset()` on the success path, but `_formKey` is never attached to a `Form` (`account_settings_page.dart:17,52,79`). | A **successful** email/password change immediately throws a null-check exception. Normal path, guaranteed crash. | **P0** | S | — |
| **F2** | Delete-account has no `try/catch` and no data cleanup (`account_settings_page.dart:88-117`, `auth_repository.dart:44`). | `requires-recent-login` (the common case) throws unhandled with zero feedback; on success the user's `/users/{uid}`, `/meals/{uid}`, and feed posts are orphaned forever. | **P1** | M | U8, F14 |
| **F3** | Meals are never date-scoped; totals sum **every meal ever** logged as "today" (`meal_tracking_page.dart:91-97`, `meals_repository.dart:15-23`, `meal.dart` has no timestamp). | The tracker's headline number is simply wrong after day one — the core value prop of a macro tracker. | **P1** | M | — |
| **F4** | Water counter never resets daily **and** rapid taps lose increments (local `++` races the re-emitting stream) (`water_tracker_page.dart:28-53`). | "Cups today" is really "cups ever"; fast tapping under-counts. Two distinct defects in one screen. | **P1** | M (reset) + S (race) | — |
| **F5** | Notes editing is broken: title `TextEditingController` rebuilt every frame → cursor jumps + leak; content has no key → binds to the wrong note after a delete; writes on every keystroke (`notes_page.dart:111-113,144,166,183`). | You cannot reliably edit a note title mid-string, and deleting a note can smear another note's unsaved text. | **P1** | M | — |
| **F14** | RTDB **security rules are absent from the repo** — no `firebase.json`/`.firebaserc`/`database.rules.json` anywhere. | All data protection lives in the console, un-versioned and untestable. We cannot prove user A can't read user B's data or delete others' posts. | **P1** | M | — |
| **F6** | Feed stream dies permanently on one malformed node (`event.snapshot.value as Map`, `feed_repository.dart:18-20`; error only logged, `feed_page.dart:67`). | A single bad record silently stops the whole feed from updating until the page is rebuilt. | **P2** | S | — |
| **F7** | Feed delete matches on `postId`; legacy posts default to `postId=''`, so deleting one removes **all** empty-`postId` posts from the list (`feed_page.dart:74`, `post.dart:31-42`). | Deleting your own legacy post can visually wipe several posts at once. | **P2** | S | — |
| **F11** | Profile edit form is clobbered by its own live `watchProfile` stream on every emit (`user_info_page.dart:46-59`). | A background write (e.g. privacy toggle) erases whatever the user is mid-typing. | **P2** | S | — |
| **F12** | Onboarding validates only gender; can save an incomplete profile, land on home, then get bounced back to onboarding next login (`user_info_page.dart:135-140,89-91`, `user_profile.dart:29-33`, `loading_page.dart:32-34`). | Confusing "why am I back at onboarding?" loop; incomplete data downstream. | **P2** | S | — |
| **F17** | Login/Register track `isLoading` but never use it — no spinner, button stays enabled during the request (`login_page.dart:25,28,53`; `register_page.dart:22,44,64`). | Double-taps fire duplicate sign-ins / account creations; the app feels dead on slow networks. | **P2** | S | X3 |
| **F10** | Workout tracker persists nothing (pure local state), has dead code (`_nextRep` never called, `_currentWorkout` never shown) and an unbound dropdown that renders blank (`workout_tracker_page.dart:14,66,111`). | A "rep/timer tracker" with no history or saved sessions is a demo, not a feature. | **P2** | L | — |
| **F13** | "Private mode" only swaps `displayName` for a **fresh random uuid per post**; real `userId`/`userEmail` still stored on every post (`feed_page.dart:85`, `post.dart:44-53`). | The privacy promise is misleading — the same user looks like many anonymous strangers, and identity is still persisted. | **P2** | M | F14 |
| **F8** | Feed `Post.liked` / `Post.comments` exist but there is **no like/comment UI** and `addPost` never sets them (`post.dart:28-29`, `feed_repository.dart:40-49`). | Either an unfinished feature or dead model surface; misleads future work. | **P3** | L (build) / S (remove) | — |
| **F9** | Feed has no `createdAt`; posts can't be sorted or dated (`post.dart`). | No chronological ordering or timestamps in a social feed. | **P3** | S | F8 |
| **F15** | Meals never compare against the profile's calorie target (`meal_tracking_page.dart`; target captured in `user_profile.dart` but unused). | "X of Y calories today" is the obvious payoff of capturing a target; it's missing. | **P3** | S | F3 |
| **F16** | `firebase_analytics` is a dependency but never imported/used anywhere in `lib/`. | Dead dependency and a missed signal source; decide to wire basic events or drop it. | **P3** | S | — |

## B. User-flow gaps (dead-ends, missing screens, navigation, empty/error/loading states)

| ID | Gap | Why it matters | Sev | Effort | Deps |
|----|-----|----------------|-----|--------|------|
| **U3** | No empty / loading / error states on Feed, Notes, Meals (errors only logged; blank lists otherwise) (`feed_page.dart:67`, `notes_page.dart`, `meal_tracking_page.dart`). | First-run users see blank screens; failures are invisible. Reads as "broken" even when working. | **P2** | M | — |
| **U1** | Settings (and therefore Sign-Out) is reachable **only** via the gear on the Home tab (`home_shell.dart:62-72`). | From Feed/Notes/Meals/Calendar there's no way to reach settings or sign out without switching tabs first. | **P2** | S | — |
| **U6** | Loading gate is one-shot: any transient profile-read error routes an existing user to onboarding (`loading_page.dart:35-37`). | A blip sends established users through first-time onboarding. | **P2** | S | — |
| **U4** | Calendar shows no note indicators and no today/selected highlight (`calendar_page.dart`). | You can't tell which days have notes — the "filter notes by day" feature is invisible; you tap blindly. | **P2** | M | — |
| **U8** | No re-authentication flow for sensitive actions (email/password/delete all hit `requires-recent-login` with no recovery) (`account_settings_page.dart`). | Users simply can't change credentials or delete their account once their session ages. | **P2** | M | F2 |
| **U2** | Bottom-nav tabs are `setState` swaps, not routes; `/home/feed` etc. don't exist (`home_shell.dart:22-44`). | No deep-linking to a tab, no per-tab back stack, inconsistent with go_router elsewhere. | **P3** | M | — |
| **U5** | Calendar → Notes uses a raw `Navigator.push` outside the router (`calendar_page.dart:67`). | Inconsistent navigation model; pushed page sits outside go_router's stack. | **P3** | S | U2 |
| **U7** | Forgot-password's 2s `Timer` auto-pop targets an ambiguous route after a manual dialog dismiss (`forgot_pw_page.dart:43-45,56-58`). | Can bounce the user off the page unexpectedly. | **P3** | S | — |
| **U9** | Workout & Water are reachable only from Home-tab dashboard cards (`home_shell.dart:146,194`). | Low discoverability; no nav affordance for two whole features. | **P3** | S | U1/U2 |

## C. UI/UX gaps (polish, consistency, accessibility, responsiveness, feedback)

| ID | Gap | Why it matters | Sev | Effort | Deps |
|----|-----|----------------|-----|--------|------|
| **X1** | Dark mode is broken on hardcoded-color screens (`home_shell.dart:49`, `login_page.dart:70`, `register_page.dart:87`) even though `AppTheme.dark()` is wired (`app.dart:17`). | Users on system dark mode get white flashes / unreadable contrast. Half-finished theming. | **P2** | M | X4 |
| **X3** | No loading/disabled feedback on primary buttons app-wide (login, register, save, post). | Taps feel unresponsive; encourages double-submits (see F17). | **P2** | M | F17 |
| **X6** | Fixed-size layouts overflow small screens: `Image.asset(width:400,height:400)` (`login_page.dart:77`, `register_page.dart:94`), fixed `width:400` (`account_settings_page.dart:127`). | Overflow errors / cut-off UI on small or landscape devices and narrow web windows. | **P3** | M | — |
| **X5** | Accessibility gaps: `GestureDetector` "buttons" without semantics, fields with only `hintText` (no labels), small touch targets, no error announcements (`login_page.dart`, `register_page.dart`, `home_shell.dart`). | Screen-reader users can't operate core flows; fails basic a11y. | **P3** | M | — |
| **X2** | Inconsistent component usage: tappable `Container`/`GestureDetector` instead of real buttons, inline `TextStyle` scattered, many screens ignore the theme's typography. | Visual drift and maintenance cost; theme exists but isn't consistently used. | **P3** | M | X4 |
| **X4** | 14 files carry `// ignore_for_file:` lint suppressions (mostly const lints). | Hygiene debt hidden under a green `flutter analyze`; also entangled with the theming/const work in X1/X2. | **P3** | S | — |
| **X7** | Inconsistent feedback: privacy toggle shows no confirmation (`privacy_settings_page.dart`), meal validation fails silently (`meal_tracking_page.dart:63-65`), forgot-password shows raw `e.message` (`forgot_pw_page.dart:52`). | Users don't know whether actions succeeded or why they failed. | **P3** | S | — |
| **X8** | Home dashboard visual design is ad-hoc (giant fonts, oversized brand image, hand-rolled cards) (`home_shell.dart:74-231`). | Inconsistent with the rest of the app; feels unpolished. | **P3** | M | X1 |

---

## D. Prioritized roadmap (shippable milestones)

Milestones are ordered so each one is independently shippable and lowers risk before the next.
Effort in parentheses is per-gap; a milestone is the sum.

### Milestone 1 — Stop the bleeding (correctness & crashes)
*Goal: the app never crashes or corrupts data on a normal path.* Cheap, high-impact bug fixes.
- **F1** account null-crash (S) — **P0, do first**
- **F6** feed stream null-guard (S)
- **F7** feed delete by push key, not `postId` (S)
- **F5** notes editing: add item keys + persistent controllers + commit-on-blur/debounce (M)
- **F11** profile edit: load once instead of live-subscribing in edit mode (S)
- **F4 (race half)** water optimistic-update fix (S)
- **F17** login/register: use `isLoading`, disable button, block double-submit (S)
> Ships as: *"bugfix: eliminate crash and data-integrity defects."* No new features, all low-risk.

### Milestone 2 — Make the trackers actually track (data model)
*Goal: daily trackers reflect the day.* This is where the product currently lies to the user.
- **F3** meals: add a per-meal timestamp, query/sum by selected day (M)
- **F4 (reset half)** water: date-scope the counter with a daily rollover (M)
- **F15** meals vs. calorie target: show "X of Y today" using the profile target (S)
- **F12** onboarding: require the core fields, block saving an incomplete profile (S)
> Ships as: *"feat: date-scoped meal and water tracking with calorie target."* Note: introduces a
> data-shape change — decide migration vs. treat old flat values as legacy (mirrors the water-node
> migration already done).

### Milestone 3 — Security & trust
*Goal: data protection is provable and destructive actions are safe.* Encodes the **2A** model you chose.
- **F14** bring RTDB rules in-repo (`database.rules.json` + `firebase.json` + `.firebaserc`), wire the
  Firebase Emulator Suite, add `@firebase/rules-unit-testing` tests to CI proving per-user isolation,
  feed read-all/write-authed, and author-only deletes (M)
- **F2** delete-account: catch `requires-recent-login`, surface it, and delete the user's RTDB data (M)
- **U8** add a re-authentication flow feeding F2 + email/password changes (M)
- **F13** privacy mode: stable per-user pseudonym and stop persisting identifying fields on private
  posts (or explicitly document the limitation) — now enforceable via the new rules (M)
> Ships as: *"feat(security): versioned, emulator-tested RTDB rules + safe account deletion."*
> Depends on Milestone 1 being stable. F13/F2 lean on F14's rules.

### Milestone 4 — Flow & states (no dead-ends)
*Goal: every screen communicates state and nothing traps the user.*
- **U3** empty / loading / error states for Feed, Notes, Meals (M)
- **U1** make Settings + Sign-Out reachable from every tab (shell-level action) (S)
- **U6** loading gate: distinguish "read failed" from "no profile," add a retry (S)
- **U4** calendar: highlight today/selected and mark days that have notes (M)
- **U7** forgot-password: fix the pop target / dismissal handling (S)
- **U9** surface Workout & Water in navigation (S)
- **U2 + U5** *(optional, larger)* migrate the bottom nav to `StatefulShellRoute` so tabs are real,
  deep-linkable routes and Calendar→Notes uses the router (M)
> Ships as: *"feat(ux): empty/error/loading states, reachable settings, richer calendar."*

### Milestone 5 — Polish, platform & finish features
*Goal: looks and feels finished; web shipped.*
- **X4** remove the 14 lint suppressions (`dart fix --apply` + green analyze) (S) — do early, it
  unblocks the theming work
- **X1** fix dark mode on the hardcoded-color screens (M)
- **X3** consistent button loading/disabled feedback (M)
- **X2 / X8** consistent components + dashboard redesign against the theme (M)
- **X5** accessibility pass (semantics, labels, touch targets) (M)
- **X6** responsive layouts (drop fixed 400px sizings) (M)
- **X7** consistent success/error feedback (S)
- **F9** feed timestamps + ordering (S); **F8** decide likes/comments — build or delete the dead
  fields (L / S); **F10** workout persistence + history (L); **F16** wire or drop analytics (S)
- **Web delivery:** the release web build already succeeds — add a deploy target (e.g. Firebase
  Hosting) so the web version is actually shipped (S–M)
> Ships as incremental polish PRs; safe to interleave once Milestones 1–3 are done.

### Sequencing notes
- **Do Milestone 1 before everything** — it's the crash/corruption floor and is nearly all S-effort.
- **Milestones 2 and 3 are independent** and can run in parallel by different concerns (data model vs.
  security), but both should sit on top of a stable Milestone 1.
- **X4 (de-suppression) should land at the start of Milestone 5** because X1/X2 touch the same files.
- **U2 (real tab routes)** is the one genuinely optional, larger architectural item — everything in
  Milestone 4 works without it; it's a quality-of-architecture upgrade, not a fix.

---

*End of Phase 2. Awaiting your review before any build work begins.*
