# LAP Fitness — Current State (Phase 1)

> **What this is:** An honest, code-traced map of what the Flutter app in `lap_fitness/`
> actually does today. Every claim cites `file:line`. This is analysis only — no behavior
> was changed. Paths are relative to `lap_fitness/` unless noted.
>
> **Method:** Static code tracing of the runtime path
> (`main.dart` → `app/app.dart` → `app/router.dart` → screens → repositories → models),
> cross-checked by an independent adversarial correctness pass and a test-suite audit.
> Items that genuinely need a live Firebase project or a running device to confirm are
> collected in the last section. Observations and opinions are kept separate; opinions are
> tagged **[opinion]**.

---

## 1. How the app boots and routes

- `lib/main.dart:9-20` — initializes logging, then `Firebase.initializeApp(...)`. A failure
  is **logged and swallowed** (`main.dart:16-18`); the app still calls `runApp(...)` inside a
  `ProviderScope`. So if Firebase can't init, the UI still mounts and every Firebase call
  later fails at use-time rather than at startup.
- `lib/app/app.dart:14-20` — `MaterialApp.router` with `AppTheme.light()`/`AppTheme.dark()`
  and the go_router from `routerProvider`.
- `lib/app/router.dart:34-128` — the route table + a `redirect` gated on `authStateProvider`:
  - `initialLocation` is `/login` (`router.dart:44`).
  - While the first auth event is loading, redirect returns `null` (no decision) (`router.dart:49`).
  - Not logged in → forced to `/login` unless already on an auth route (`router.dart:60-62`).
  - Logged in but sitting on an auth route → sent to `/loading` (`router.dart:65`).
  - The router refreshes off a `ValueNotifier` driven by `authStateProvider` (`router.dart:39-41`),
    which is the fix for the old broken named-route sign-out behavior.

**Route map (`router.dart:19-32`, `68-123`):**

| Path | Screen | Notes |
|---|---|---|
| `/login` | `LoginPage` | initial location |
| `/register` | `RegisterPage` | |
| `/forgot-password` | `ForgotPasswordPage` | |
| `/loading` | `LoadingPage` | splash gate: profile-complete → `/home`, else `/onboarding` |
| `/onboarding` | `UserInfoPage(isOnboarding: true)` | |
| `/home` | `HomePage` (shell) | bottom-nav shell |
| `/home/edit-profile` | `UserInfoPage(isOnboarding: false)` | |
| `/settings` | `SettingsPage` | pushed over `/home` |
| `/settings/account` | `AccountSettingsPage` | |
| `/settings/privacy` | `PrivacySettingsPage` | `userId` read at build time from `authRepositoryProvider` (`router.dart:110-111`) |
| `/workout` | `WorkoutTracker` | |
| `/water` | `WaterTracker` | |

**Note — the bottom-nav tabs are NOT go_router routes.** The shell swaps child widgets with
local `setState` (`home_shell.dart:22-44`), so `/home/feed`, `/home/notes`, etc. from the
modernization plan do **not** exist as addressable routes. Only `/home/edit-profile` is a real
subroute. Deep-linking to a specific tab is therefore not possible.

---

## 2. Feature-by-feature inventory

Status legend: **Working** (does what it claims) · **Partial** (works but incomplete/buggy) ·
**Broken** (has a real defect on a normal path) · **Stub** (placeholder) · **Dead-end** (no
exit / dead code).

### 2.1 Auth — Login — **Working** (minor gap)
- `login_page.dart:27-58` — signs in via `AuthRepository.signIn`; on success the auth-state
  redirect carries the user to `/loading` (no manual nav). Errors map `user-not-found` /
  `wrong-password` to friendly dialogs; all other codes get a generic message (`:41-45`).
- **Gap:** `isLoading` is set true/false (`:28`, `:53`) but **never used in the UI** — no
  spinner, and the Sign-In button is not disabled during the request. Rapid double-taps fire
  duplicate sign-ins. Same pattern in Register.
- Links to `/forgot-password` (`:154`) and `/register` (`:206`) both work.

### 2.2 Auth — Register — **Working** (minor gap)
- `register_page.dart:39-69` — confirms passwords match (`:40-43`, `:79-82`), creates the
  account, maps `weak-password` / `email-already-in-use` to messages. On success the redirect
  → `/loading` → `/onboarding` (first-time). "Login now" pops back (`:230`).
- **Gap:** same unused `isLoading` (`:22`, `:44`, `:64`) — no progress indication.

### 2.3 Auth — Forgot Password — **Working**
- `forgot_pw_page.dart:29-60` — sends a reset email, shows a confirmation dialog, then
  `context.pop()` after 2s (`:43-45`). On `FirebaseAuthException` it shows the raw error
  message and **also** pops after 2s (`:56-58`).
- **[opinion]** Surfacing the raw `e.message` (`:52`) and auto-popping even on error is rough
  UX, but it functions.
- **Bug — the 2s auto-pop targets an ambiguous route.** After showing the dialog, a `Timer(2s)`
  calls `context.pop()` (`:43-45`, `:56-58`). If the user dismisses the dialog first
  (barrier-dismiss), the timer 2s later pops the **ForgotPassword page itself**, bouncing them
  back to login unexpectedly — the pop target depends on what's on top of the navigator at fire
  time.

### 2.4 Profile / Onboarding — **Partial**
- `user_info_page.dart` + `profile_repository.dart` + `user_profile.dart`.
- Onboarding captures age / gender / weight / height(ft+in) / target calories, prefilled by a
  live `watchProfile` subscription (`user_info_page.dart:46-59`), saved to `/users/{uid}` via
  `saveProfile` (`profile_repository.dart:25-27`).
- `isOnboarding` splits behavior: first-time saving → `context.go('/home')`; edit mode → pop
  (`user_info_page.dart:89-93`).
- **Gap — validation is only on gender.** The form's only validator is the gender dropdown
  (`user_info_page.dart:135-140`). Age/weight/height/calories have **no required validation**,
  so you can save with them blank.
- **Gap — completeness inconsistency.** Onboarding save always routes to `/home`
  (`:89-91`) even if the profile is incomplete, but `UserProfile.isComplete` requires
  age+gender+weight+calories (`user_profile.dart:29-33`) and the `LoadingPage` uses that to
  decide routing (`loading_page.dart:32-34`). Net effect: a user can finish onboarding with a
  half-filled profile and land on home this session, but on the **next** login the loading gate
  bounces them back to `/onboarding`.
- **Bug — live stream clobbers in-progress edits.** The edit form subscribes to `watchProfile`
  (a live `onValue` stream) and overwrites **all** controllers inside `setState` on every emit
  (`user_info_page.dart:46-59`). Any remote write to the profile (e.g. toggling `privateMode`
  from the privacy screen) re-emits and wipes out whatever the user was mid-typing.
- Data model persists **everything as strings** (`user_profile.dart:20-26`) for backward
  compatibility; `privateMode` is written separately so onboarding saves don't clobber it
  (`profile_repository.dart:29-31`, `user_profile.dart:48-57`).

### 2.5 Home shell / dashboard — **Working** (with dead assignment)
- `home_shell.dart` — a `Scaffold` with a 5-item `BottomNavigationBar`: Feed / Notes / Home /
  Meal Tracking / Calendar (`:24-38`). Default tab is index 2 ("Home") (`:22`).
- The "Home" tab does **not** render `WorkoutTracker` even though the section map says so
  (`:31`). For index 2 the `body` is overridden with a custom dashboard of tappable cards
  (`:74-231`) → edit-profile (`:99`), workout (`:146`), water (`:194`). The
  `'page': WorkoutTracker()` at `:31` is a **dead assignment** — never shown.
- Settings gear appears **only** on the Home tab (`:62-72`), so Settings is unreachable from
  Feed/Notes/Meals/Calendar tabs.
- **[opinion]** Hardcoded `Colors.white` background + brand app bar (`:49-52`) ignore the dark
  theme wired up in `app_theme.dart`; the shell will look wrong in dark mode.
- **Bug — a frozen `DateTime.now()` in the section list.** `_sections` is `static final`, so
  `NotesPage(selectedDate: DateTime.now())` (`home_shell.dart:29`) captures the timestamp **once**
  at first class access. Notes created from the Notes tab get `selected_date` = app-launch time,
  which drifts wrong across midnight or long-running sessions.

### 2.6 Social Feed — **Partial**
- `feed_page.dart` + `feed_repository.dart` + `post.dart`. One **global** node `/feedData`
  shared by all users (`database_refs.dart:16`).
- Posts stream in via `onChildAdded` (replays existing + pushes new) and `onChildRemoved`
  (`feed_repository.dart:17-30`, `feed_page.dart:48-79`); posting and deleting work
  (`feed_page.dart:81-101`). Delete is UI-gated to the author (`:98`) and confirmed by a dialog
  (`:124-148`).
- **Private mode** only swaps `displayName` for a **fresh random uuid on every post**
  (`feed_page.dart:85`) — so an anonymous user shows as a different random string per post, and
  the underlying `userId` is still stored in plaintext (`post.dart:44-53`).
- **Dead model fields:** `Post.liked` and `Post.comments` exist (`post.dart:28-29`) but there is
  **no like or comment UI anywhere**, and `addPost` never sets them (`feed_repository.dart:40-49`).
- **Missing states:** no empty state (blank list when there are no posts), no loading indicator,
  no error state (errors are only logged, `feed_page.dart:67-68`, `76-77`).
- **Bug — one malformed node kills the whole feed.** `onPostAdded` casts
  `event.snapshot.value as Map` unconditionally (`feed_repository.dart:18-20`); a single null /
  non-map child throws, the error reaches the `onError` handler which only logs
  (`feed_page.dart:67`), and the subscription is then **cancelled** — the feed stops receiving
  any further posts until the page is rebuilt.
- **Bug — deleting a legacy post can wipe several from the list.** The removal stream matches on
  `postId` (`feed_page.dart:74`), and legacy posts without a `postId` default to `''`
  (`post.dart:31-42`). Removing one empty-`postId` post runs `removeWhere` and drops **all**
  empty-`postId` posts from the local list at once.
- **No timestamps:** `Post` has no `createdAt` (the modernization plan called for one); posts
  can't be sorted or dated in the UI.

### 2.7 Notes — **Partial** (real typing bug)
- `notes_page.dart` + `notes_repository.dart` + `note.dart`. Notes live at
  `/users/{uid}/notes/{key}` (`database_refs.dart:14`). Add via FAB (`notes_page.dart:195-199`),
  edit title/content inline (writes to DB on **every keystroke**, `:144`, `:167`), delete
  (`:176-187`).
- **Bug — title field resets the cursor while typing.** The title `TextEditingController` is
  **recreated on every build** inside `itemBuilder` (`notes_page.dart:111-113`). Each keystroke
  → `updateNoteName` writes → `watchNotes` stream re-emits → `setState` rebuild → new controller
  seeded from the DB value with the caret forced to the end. Typing mid-string jumps the cursor;
  it also **leaks a `TextEditingController` per rebuild** (`notes_page.dart:111`).
- **Bug — content can bind to the wrong note after a delete.** The content field uses
  `initialValue: note.content` with **no controller and no `Key` on the grid items**
  (`notes_page.dart:103-193`, `:166`). `initialValue` only applies on first build, and without
  keys Flutter preserves `EditableText` state **by position, not identity**. Type into note B's
  content, delete note A (`notesList.removeAt(index)`, `:183`) → indices shift and B's in-progress
  text can render under a different note.
- **[opinion]** Writing to Firebase on every keystroke (no debounce) is chatty and racy against
  the re-emitting stream.
- Date filtering works: when opened for a specific day (`showAllNotes:false`), it queries by
  `selected_date` range (`notes_repository.dart:14-29`).

### 2.8 Calendar — **Partial** (first-render misalignment)
- `calendar_page.dart` — month title with prev/next arrows (`:24-47`) and a 7-col day grid
  (`:51-100`). Tapping a day opens `NotesPage` filtered to that date via a raw
  `Navigator.push` (`:67-80`).
- **Bug — the initial month is misaligned.** Day placement uses `_selectedDate.weekday` as the
  leading offset (`:55-61`, `:74`, `:89`), which is only correct when `_selectedDate` is the 1st
  of the month. It starts as `DateTime.now()` (today, e.g. the 5th) (`:13`), so the very first
  render offsets by **today's** weekday, not the 1st's. Pressing prev/next resets `_selectedDate`
  to day 1 (`:29-31`, `:42-44`) and fixes it — so the bug only shows on the initial view.
- **Missing affordances:** no highlight of today or the selected day, and **no indicator of which
  days actually have notes** — so the calendar doesn't visibly "filter notes by day," you have to
  tap blindly.

### 2.9 Workout tracker — **Partial** (ephemeral; nothing persists)
- `workout_tracker_page.dart` — a stopwatch (start/pause/reset, `:30-57`), a set counter
  ("Next Set", `:59-64`), a rep value set from a text field (`:72-82`), and an exercise dropdown
  that swaps an image (`:111-150`).
- **Nothing is saved.** All state is local `setState` and is lost the moment you leave the screen
  (no repository, no Firebase). This matches the modernization plan's "local state" note.
- **Dead / inert pieces:** `_currentWorkout` is tracked (`:14`, `:131`) but **never displayed**;
  the dropdown has no initial `value` so it renders blank until tapped; `_nextRep(int)` is defined
  but **never called** (`:66-70`); the timer is not connected to sets/reps; there's no "finish
  workout" action.
- **[opinion]** As shipped this is a demo/toy: you can run a timer, but there's no workout log or
  history, which is what a "rep/timer tracker" implies.

### 2.10 Water intake — **Working** (but not date-aware)
- `water_tracker_page.dart` + `water_repository.dart`. Now correctly **per-user** at
  `/users/{uid}/waterIntake` (`database_refs.dart:20-22`) — the old global-node bug is fixed.
  Increment/decrement persist immediately (`water_tracker_page.dart:39-53`), and a live stream
  keeps the count in sync (`:28-30`).
- **Gap — single cumulative counter, never resets.** There is no per-day scoping; the number
  grows forever and never rolls over at midnight. "Cups today" is really "cups ever."
- **Bug — rapid taps lose increments.** `_incrementWaterIntake` does a local `_waterIntake++`
  then writes (`water_tracker_page.dart:39-44`), while the live `watchIntake` stream separately
  overwrites `_waterIntake` with the server value on every emit (`:28-30`). Tapping `+` several
  times quickly lets a re-emitted **stale** server value overwrite the optimistic local count
  between taps, and the next `++` starts from the stale field — net under-counting.

### 2.11 Meal / macro tracker — **Partial**
- `meal_tracking_page.dart` + `meals_repository.dart` + `meal.dart`. Meals live at
  `/meals/{uid}/{key}` (`database_refs.dart:18`). Add (name + protein/fat/carbs), delete (swipe
  or trash icon), and running totals for calories/protein/fat/carbs (`meal_tracking_page.dart:84-97`,
  `156-164`). Calories are derived from macros (4/9/4, `meal.dart:20-21`).
- **Gap — no date scoping.** The page presents totals "for the day" (`:91`, `:155`) but sums
  **every meal ever logged** (`watchMeals` returns all rows, `meals_repository.dart:15-23`). There
  is no date field on `Meal` and no daily reset, so totals climb indefinitely.
- **Gap — no link to the calorie target.** The profile captures a target-calorie value, but the
  meal tracker never reads it or compares against it — there's no "X of Y calories" feedback.
- Minor: light validation — rejects empty name or all-zero macros (`:63-65`), silently (no message).

### 2.12 Settings (menu) — **Working**
- `settings_page.dart:19-44` — routes to Profile (→ `/home/edit-profile`), Privacy, Account, and
  Sign Out. Sign-out just flips auth state and lets the redirect return to `/login` (`:38-41`).

### 2.13 Account settings — **Broken** (success path throws)
- `account_settings_page.dart` — change email (`:32-59`), change password (`:61-86`), delete
  account with confirm dialog (`:88-117`).
- **Bug — null-check crash on the success path.** After a successful email or password change the
  code calls `_formKey.currentState!.reset()` (`:52`, `:79`), but `_formKey` (`:17`) is **never
  attached to any `Form`** — the actual forms use `_emailFormKey` and `_passwordFormKey`
  (`:143-144`, `:190-191`). So `_formKey.currentState` is `null` and the `!` throws. The backend
  change still goes through, but the UI hits an exception right after showing the success snackbar.
- **Caveat (needs live auth):** `updatePassword` / `verifyBeforeUpdateEmail` require a *recent*
  login; on an older session Firebase throws `requires-recent-login`. That path is caught and shown
  via `errorText` for password (`:80-85`) — no re-auth flow exists to recover.
- **Bug (P1) — delete-account has no error handling and orphans data.** `_deleteAccount`
  (`:88-117`) calls `deleteAccount()` → `currentUser!.delete()` with **no try/catch** (`:114`).
  `delete()` throws `requires-recent-login` for any user who didn't just authenticate — the common
  case — so the delete silently fails with an unhandled async error and **zero user feedback**
  (unlike password/email, which catch it). Even on success, the user's RTDB data
  (`/users/{uid}`, `/meals/{uid}`, their feed posts) is **never removed** — orphaned indefinitely.
- **Bug — `setState` after `await` with no `mounted` guard.** Both catch blocks set
  `_emailError` / `_passwordError` via `setState` without checking `mounted` (`:54-57`, `:81-85`);
  navigating away mid-request throws on a disposed `State`.

### 2.14 Privacy settings — **Working**
- `privacy_settings_page.dart:30-40` — loads `privateMode` and writes it on toggle. Functions,
  but there's **no saved-confirmation feedback** and no explanation of what "private mode" does
  (it only affects the feed display name).

### 2.15 Test coverage — **partial, and blind to the real bugs**
- The suite (`test/`) is strong on **model round-trips** (`Post`, `Meal`, `Note`, `UserProfile`)
  and on **router redirect logic** (`test/app/router_test.dart` drives the real redirect off a
  faked auth stream), plus **screen-render smoke tests**.
- **Near-zero coverage of repository / stream / query logic.** Every repository is replaced by a
  fake in `test/support/fakes.dart`; the real RTDB snapshot-parsing, day-filter query, and
  `onChildAdded`/`onValue` mapping code is **never executed**. `RegisterPage`,
  `ForgotPasswordPage`, and the `LoadingPage` gate have no direct tests.
- **The fakes structurally cannot catch the reactive bugs.** They emit a single `Stream.value(...)`
  instead of a live multi-emission stream, **no-op all writes** (so a write never round-trips back
  through the read stream), and **drop query semantics** (the notes `day` filter is ignored
  entirely). As a result, **none of the bugs above** — notes cursor-reset, meals summing all days,
  the account-settings null crash, calendar misalignment, water never resetting — would be caught
  by the current tests. A green CI badge here means "models serialize and screens render," not
  "features behave."

---

## 3. End-to-end user flows

```
                         app launch (main.dart)
                                  │
                    router redirect on authState (router.dart:46)
                                  │
                    ┌─────────────┴─────────────┐
              not logged in                 logged in
                    │                            │
                 /login ──"Register now"──▶ /register ──(success)──┐
                    │                            │                 │
         "Forgot Password?"                 "Login now"            │
                    │                        (pop back)            │
             /forgot-password                                      │
             (send email, pop)                                     │
                    │                                              ▼
                    └──────────(sign in success)──────────▶  /loading  (splash gate)
                                                                   │
                                          profile.isComplete ?  ───┴───  no
                                                yes │                     │
                                                    ▼                     ▼
                                                 /home             /onboarding
                                              (shell, tab 2)    (UserInfoPage first-time)
                                                    │                     │
                                                    │◀────(save → go home)┘
                                                    │
          ┌───────────────┬────────────┬───────────┼───────────┬──────────────┐
          ▼               ▼            ▼            ▼            ▼              ▼
     Feed tab        Notes tab    Home tab     Meals tab   Calendar tab   (gear, tab2 only)
   (global feed)  (notes grid) (dashboard)  (macro log)  (month grid)     /settings
                                    │                          │              │
                       ┌────────────┼───────────┐         tap a day     ┌─────┼─────────┐
                       ▼            ▼            ▼         ▶ NotesPage    ▼     ▼         ▼
                 /home/edit-    /workout      /water     (filtered,   profile privacy  account
                  profile     (ephemeral)  (per-user)    Navigator.   (edit)  (toggle) (email/pw/
                                                          push)                          delete)
                                                                                          │
                                                    Sign Out (settings) ──▶ auth flips ──▶ /login
```

**Flow observations:**
- **Sign-out** is reachable **only** from `/settings`, which is reachable **only** via the gear
  on the Home tab (`home_shell.dart:62-72`). From any other tab there is no path to settings or
  sign-out without first switching to the Home tab.
- **`/workout` and `/water`** are reachable only from the Home-tab dashboard cards
  (`home_shell.dart:146`, `:194`) — there's no bottom-nav entry for them. Their own app bars have a
  back arrow (`workout_tracker_page.dart:98-103`; Water has an app bar but **no** explicit
  back/leading, `water_tracker_page.dart:57-61` — relies on the default push back button, which is
  present because it was `context.push`'d).
- **Calendar → NotesPage** uses a raw `Navigator.push` (`calendar_page.dart:67`) rather than
  go_router, so that pushed NotesPage is outside the router's stack (works, but inconsistent with
  the rest of the app).
- **No dead-end traps found** for navigation per se — every screen has a back affordance or a
  redirect. The "dead-ends" are functional: the workout tracker leads nowhere (no save), and the
  feed's like/comment affordances don't exist.
- **Loading gate is one-shot:** `LoadingPage` reads the profile once and routes; on any error it
  defaults to `/onboarding` (`loading_page.dart:35-37`), so a transient read failure sends an
  existing user back through onboarding.

---

## 4. Firebase Realtime Database data model (as actually used)

Derived entirely from `core/firebase/database_refs.dart` and the repositories.

### Per-user data under `/users/{uid}`
| Path | Shape | Written by | Read by |
|---|---|---|---|
| `/users/{uid}` | `age, gender, weight, heightFeet, heightInches, calories` (**all strings**), `privateMode` (bool) | `profile_repository.dart:25-31` | `profile_repository.dart:11-22` |
| `/users/{uid}/notes/{pushKey}` | `name, content` (strings), `created_at, selected_date` (ISO-8601 strings, or `''`) | `notes_repository.dart:31-47` | `notes_repository.dart:14-29` |
| `/users/{uid}/waterIntake` | scalar `int` (cups) | `water_repository.dart:18-19` | `water_repository.dart:11-16` |

### Per-user data under a **separate** top-level namespace
| Path | Shape | Written by | Read by |
|---|---|---|---|
| `/meals/{uid}/{pushKey}` | `name` (string), `protein, fat, carbs` (numbers) | `meals_repository.dart:25-26` | `meals_repository.dart:15-23` |

### Global (shared across all users)
| Path | Shape | Written by | Read by |
|---|---|---|---|
| `/feedData/{pushKey}` | `key, userId, postId, body, userEmail, displayName` (strings), `liked` (bool), `comments` (list) | `feed_repository.dart:34-52` | `feed_repository.dart:17-30` |

**Structural notes:**
- **Inconsistent per-user placement:** notes and water live under `/users/{uid}/…`, but meals
  live under a **separate** top-level `/meals/{uid}` (`database_refs.dart:14-22`). Same "per-user"
  intent, two different roots.
- **`/feedData` is fully global.** Every post carries the author's real `userEmail` and `userId`
  in the record (`post.dart:44-53`) even when private mode is on (private mode only changes the
  separate `displayName`). Client-side delete is author-gated (`feed_page.dart:98`), but nothing
  in the *client* stops reading/writing others' data — that depends entirely on server rules
  (see §5).
- **Redundant keys in feed:** each post stores both the Firebase push `key` and a client uuid
  `postId` (`post.dart:22-24`). Deletes use `key` (`feed_repository.dart:52`) while the removed
  stream matches on `postId` (`feed_repository.dart:25-30`, `feed_page.dart:71-78`).
- **Types are stringly:** profile numeric fields are stored as strings; note dates are ISO
  strings. Models defensively coerce with `.toString()` / `tryParse` on read
  (`user_profile.dart:35-46`, `note.dart:30-35`, `meal.dart:33-36`), so malformed legacy data
  degrades to defaults rather than crashing.

---

## 5. Cannot verify without a live Firebase project / running device

These are **assumptions** pending a live backend or device — flagged so we don't treat them as
confirmed:

1. **RTDB security rules — not in the repo at all.** There is **no `firebase.json`, `.firebaserc`,
   or `database.rules.json`** anywhere in the tree (verified by find over the whole repo). The live
   rules exist only in the Firebase console — un-versioned, un-reviewable, and impossible to test
   offline. So the entire per-user vs global security model (whether users can read/write other
   users' `/users/{uid}`, or delete others' `/feedData` posts bypassing the client-side author gate
   at `feed_page.dart:98`) is **unverifiable from this repo**. *(Roadmapped: bring rules in-repo
   with a local emulator + `@firebase/rules-unit-testing` tests, encoding the current per-user-private
   / shared-feed / delete-own-only model.)*
2. **Existing production data shapes.** The models assume legacy string-typed fields
   (`user_profile.dart:20-26`). Whether real stored data matches (or contains other keys) needs a
   live DB dump.
3. **Account-settings crash.** The `_formKey.currentState!` null-check on the success path
   (`account_settings_page.dart:52`, `:79`) is a strong static inference; confirming it throws at
   runtime needs a device + a successful email/password change.
4. **`requires-recent-login`.** Password/email/delete flows likely require a recent login on real
   sessions (`auth_repository.dart:36-44`); the exact error and whether it's user-recoverable
   needs a live account.
5. **Password-reset & verify-before-update emails** actually delivering
   (`auth_repository.dart:33-42`) — needs a real Firebase Auth project.
6. **Firebase Analytics.** `firebase_analytics` is a dependency (`pubspec.yaml`) but is **never
   imported or used** anywhere in `lib/` (confirmed by grep). No events are logged; confirming
   "no analytics" is code-based, but confirming the dashboard is empty needs the console.
7. **Dark mode rendering.** `AppTheme.dark()` is wired (`app.dart:17`), but several screens
   hardcode light colors (e.g. `home_shell.dart:49`, `login_page.dart:70`). How badly they break
   in dark mode needs a device with system dark mode on.
8. **Firebase init failure path.** `main.dart:16-18` swallows init errors; how the app behaves
   with no Firebase (which screens error, which just hang) needs a runtime with Firebase
   misconfigured.

---

## 6. Repo / infra observations

- **Dead assets (fixed on this branch).** Four images were declared in `pubspec.yaml` but never
  referenced in any Dart code: `lap.png`, `post.png`, `profile.png`, `profile_me.png`. Git history
  shows `post/profile/profile_me` were used by the **original MVP** feed & calendar; the
  modernization refactor deleted the widgets but left the files and pubspec lines. `lap.png` was
  never referenced (only `lap2.png` is used), and `profile.png`/`profile_me.png` were byte-identical
  duplicates. **All four files and their pubspec entries have been removed** as part of this audit's
  quick-win cleanup; `flutter pub get` still resolves.
- **Web is already scaffolded.** `lap_fitness/web/` exists (`index.html`, `manifest.json`,
  `icons/`, `favicon.png`), `.metadata` lists web as a supported platform, and
  `firebase_options.dart` carries a `web` config. Web is a viable target today.
- **This environment can't *run* the app.** `firebase_options.dart:34-38` throws `UnsupportedError`
  on Linux (and Windows); only web/macOS/iOS/Android are configured. Verifying runtime behavior here
  means `flutter build web` / running the web build, not a native run.
- **Lint "zero issues" is partly achieved by suppression.** 14 files carry `// ignore_for_file:`
  headers, almost all suppressing `prefer_const_constructors` / `prefer_const_literals`. Real
  hygiene debt sitting under a green `flutter analyze`. *(Roadmapped for de-suppression.)*
- **CI is solid.** `.github/workflows/ci.yml` runs `dart format --set-exit-if-changed`,
  `flutter analyze`, and `flutter test --coverage` on push/PR, Flutter pinned to 3.44.4.
- **Committed Firebase config.** `firebase_options.dart` commits client API keys and a public
  `databaseURL`. These are client identifiers, not secrets (normal for FlutterFire), but it
  underscores that **all** data protection rests on the (currently absent-from-repo) RTDB rules.

## 7. One-line status summary

| Feature | Status |
|---|---|
> **Note:** the "Original status" column is the as-audited state. **M1** = fixed in Milestone 1
> (see `GAPS.md` §D); remaining work is tracked by gap ID there.

| Feature | Original status | Now |
|---|---|---|
| Login | Working (no loading indicator) | **M1**: spinner + double-submit guard (F17) |
| Register | Working (no loading indicator) | **M1**: spinner + double-submit guard (F17) |
| Forgot password | Working (ambiguous 2s auto-pop) | unchanged (U7 → M4) |
| Profile / onboarding | Partial (weak validation, completeness inconsistency, live stream clobbers edits) | **M1**: edit no longer clobbered (F11); validation/completeness → M2 (F12) |
| Home shell / dashboard | Working (dead `WorkoutTracker` assignment; frozen `DateTime.now()`; not dark-mode aware) | unchanged (→ M4/M5) |
| Social feed | Partial (dead fields, no empty/loading state, weak "privacy", stream dies on bad node, delete wipes empty-`postId` posts) | **M1**: stream-death (F6) + mass-delete (F7) fixed; rest → M5/M3 |
| Notes | Partial (title cursor-reset + controller leak, wrong-note content binding, writes per keystroke) | **M1**: keyed `_NoteCard` fixes cursor/leak/wrong-note binding (F5) |
| Calendar | Partial (first-render misalignment, no note indicators) | unchanged (→ M4) |
| Workout tracker | Partial (ephemeral; nothing persists; dead code) | unchanged (F10 → M5) |
| Water intake | Working per-user, but never resets daily + rapid taps lose increments | **M1**: rapid-tap race fixed via transaction (F4); daily reset → M2 |
| Meal tracker | Partial (no date scoping; ignores calorie target) | unchanged (F3/F15 → M2) |
| Settings menu | Working | unchanged |
| Account settings | Broken (null-crash on success path; delete unhandled + orphans data) | **M1**: null-crash fixed (F1), delete crash-guarded (F2 partial); full re-auth/cleanup → M3 |
| Privacy settings | Working (no feedback; unclear meaning) | unchanged (X7 → M5) |

---

*End of Phase 1. Stopping here for review before Phase 2 (gap analysis).*
