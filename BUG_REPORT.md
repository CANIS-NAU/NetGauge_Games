# NetGauge Games – Bug Report

**Reviewed:** branch `claude-save-progress`, commit `237aaa8`, **plus the uncommitted working tree** (modified: `lib/flutter_bridge.dart`, `lib/game_catalog.dart`, `lib/main.dart`, `lib/settings.dart`; untracked: `lib/game_progress.dart`, `test/game_progress_test.dart`). Nothing was fixed or committed.
**Not reviewed as code on this branch:** `firestore.rules` and the hardening work (they live on `security-hardening-claude`; no `firestore.rules` exists on this branch).
**Tooling results:** `flutter analyze` → 103 infos/warnings, 0 errors (mostly unused imports/variables; not repeated here). `flutter test` → 206 pass, 1 fail (`test/widget_test.dart`, the known counter smoke test).
**Verification legend:** *Confirmed* = traced in the code, and where noted proven by a small probe. *Unconfirmed* = follows from the code but depends on device/runtime behaviour I could not run.

## Summary

| Severity | Count |
|---|---|
| Critical | 0 |
| High | 8 |
| Medium | 33 |
| Low | 47 |
| **Total** | **88** |

| Area | High | Medium | Low |
|---|---|---|---|
| 1. Auth / accounts (A) | 0 | 3 | 3 |
| 2. User data & Firestore writes (D) | 0 | 4 | 4 |
| 3. Session saving & game bridge (S) | 5 | 8 | 9 |
| 4. POI / location logic (P) | 0 | 2 | 3 |
| 5. Speed test / NDT7 (N) | 1 | 5 | 6 |
| 6. Maps & H3 (M) | 0 | 2 | 4 |
| 7. Surveys (V) | 1 | 3 | 3 |
| 8. Badges (B) | 0 | 1 | 2 |
| 9. Settings / theme / notifications (T) | 0 | 2 | 2 |
| 10. UI / layout (UI) | 1 | 1 | 4 |
| 11. Tests (TT) | 0 | 2 | 2 |
| 12. Platform config, assets, dead code (X) | 0 | 0 | 5 |

Most-impactful items to look at first: **S-1** (sessions saved twice → inflated stats and badges), **S-2** (finished games can always be "continued"), **S-3** (a new account's default favorite opens a broken game), **S-4** (location streams stack up and never stop), **N-1** (upload speed is capped at ~6.5 Mbps by the test itself), **S-5** (location-off hangs games), **V-1** (survey marked done even if the answers never saved), **S-6** (swapped lat/lng in measurement geohash, medium), **UI-1** (home map preview locked to Switzerland).

Checked and **not** bugs (to save you time): `latency: minRTT ?? 0` does *not* throw an int→double `TypeError` (Dart infers `0.0`; probed); the app-level bottom `SafeArea` in `main.dart` does not double the padding of the per-screen `SafeArea`s; `directionHint`'s `%` handles negative bearings correctly (Dart's `%` is non-negative).

---

## 1. Auth / accounts

### A-1 (medium) Logging out removes the auth `StreamBuilder`, so later sign-outs are not noticed
- **Where:** `lib/settings.dart:109-115` (`pushAndRemoveUntil(... (route) => false)`), `lib/main.dart:~80-108` (the `StreamBuilder` is the `home:` route).
- **Problem:** `pushAndRemoveUntil` removes *every* route, including the `home` route that hosts the `StreamBuilder<User?>`. After the first manual logout nothing observes auth changes any more.
- **Scenario:** user logs out (screen shows `LoginPage`, a plain route), logs in again → `LoginPage._login` `pushReplacement`s a bare `HomePage`. Second logout: the `StreamBuilder` that would call `clearData()` and `DailyReminderService.cancel()` is gone, so the previous user's data stays in `UserDataProvider` and the reminder keeps firing. Even on the first logout `clearData()` may never run because the `StreamBuilder` is unmounted in the same frame the stream emits null (timing-dependent, *unconfirmed*).
- **Fix:** keep the auth gate in the tree (`Navigator.popUntil(isFirst)` and let the `StreamBuilder` swap pages), or call `clearData()`/`DailyReminderService.cancel()` explicitly in `logout()`.

### A-2 (medium) Concurrent `fetchUserData()` calls can create duplicate onboarding documents (unconfirmed timing)
- **Where:** `lib/user_data_manager.dart:496-511` (check-then-`add` of the `ABC_Onboarding` doc), callers `lib/main.dart:~86`, `lib/login_page.dart:38-39, 58`, `lib/login_page.dart:307-310`, `lib/flutter_bridge.dart:124`.
- **Problem:** `fetchUserData` has no in-flight guard. For a brand-new account or guest, the `StreamBuilder` post-frame call and the login page's own call both see "no onboarding doc" and both `add()` one.
- **Scenario:** tap "Continue as Guest" → two `ABC_Onboarding/user/user` docs for `guest_<uid>`; `.limit(1)` queries then update an arbitrary one.
- **Fix:** memoize the in-flight future (`_fetching ??= _doFetch().whenComplete(...)`), and use a deterministic doc ID for the onboarding doc.

### A-3 (medium) Registration overwrites the profile with the wrong shape (and possibly a differently-cased email)
- **Where:** `lib/login_page.dart:292-306`.
- **Problem:** `signUpNewUser` does `.set({...})` **without `merge`**, writing `distanceTraveled` (app reads `totalDistanceTraveled`), no `favoriteGames`, `demographicsSurveyTaken`, `isGuest`, and `'email': email` as typed (all other code uses `accountIdFor(user)` = Firebase's `user.email`). It races with the `StreamBuilder`-triggered `fetchUserData`, which may already have created the full document via `createUserDocument`; the non-merge `set` then wipes those fields.
- **Scenario:** register as `Shelby@NAU.edu`. If Firebase normalizes the address to lower case (*unconfirmed*), `UserDataProvider.email` (read from the doc field) is mixed-case while `fetchSessionData`/`accountIdFor` use lower case → measurements and sessions are written under one key and read from another.
- **Fix:** remove the duplicate creation (`createUserDocument` already exists) or use `SetOptions(merge: true)` with `accountIdFor(user)`.

### A-4 (low) `_login` reads a legacy `userData/{uid}` collection and ignores the result
- **Where:** `lib/login_page.dart:36, 313-330`.
- **Problem:** The app stores profiles in `userAccountData`; `getCurrentUserData()` reads the old `userData` collection and discards the result. Any non-`FirebaseAuthException` (e.g. `permission-denied` once rules are tightened) escapes the `catch`, so no error is shown and the exception is unhandled.
- **Fix:** delete the call.

### A-5 (low) Login/registration edge cases
- **Where:** `lib/login_page.dart:41-47, 70-75, 259-266` (`pushReplacement(HomePage)` after the `StreamBuilder` already swapped pages), `:119-142, :149-153` (error text rendered twice at `:119` and `:171`; `.trim()` applied to passwords), `:255-270` (non-Auth exception in the registration handler leaves the dialog open although the user is already signed in).
- **Scenario:** if `LoginPage` is still mounted when `pushReplacement` runs, it replaces the `StreamBuilder` route (see A-1). A password with a trailing space cannot be entered consistently across other clients.
- **Fix:** rely on the auth stream for navigation; do not trim passwords; catch generic errors.

### A-6 (low) `clearData()` leaves stale per-account state; in-flight fetches can resurrect the old account
- **Where:** `lib/user_data_manager.dart:660-665` (does not reset `_collectedSessions`, `_collectedMeasurements`, `_isLoading`, `_awardingBadges`); `lib/user_data_manager.dart:458-525` (no check that the signed-in user is still the one the fetch started for).
- **Scenario:** user A logs out while `fetchUserData` is awaiting Firestore → after user B logs in, A's result can overwrite `_userData`; `badgeStats` for B briefly uses A's sessions.
- **Fix:** reset all fields; capture the account ID at the start of a fetch and drop the result if `accountIdFor(currentUser)` changed.

---

## 2. User data & Firestore writes

### D-1 (medium) `_userData!` null dereference and unhandled `.update()` failures in the totals updaters
- **Where:** `lib/user_data_manager.dart:380, 406` (`_userData!` with no null check); `:343-346, 365-368, 386-389, 412-416` (un-awaited `.update()` with no `catchError`).
- **Problem:** `updateDistanceTraveled` guards `_userData == null`, but `updateTotalLocationPoints`/`updateRadiusGyration` do not. They are called from `SessionManager.saveCurrentSession` (`lib/session_manager.dart:167-168`) **before** the session document is written.
- **Scenario:** the player starts a game before `fetchUserData` finishes (slow network) or after `clearData()`; game ends with ≥1 location point → `NoSuchMethodError` inside `saveCurrentSession` → the session is never written to Firestore. Separately, `update()` on a profile that does not exist (older/legacy account or guest doc not yet created) fails with NOT_FOUND as an unhandled async error.
- **Fix:** null-check consistently, wrap in try/catch, `await` them, and use `set(..., merge: true)` or `FieldValue.increment` instead of absolute values.

### D-2 (medium) `vpn_used` on every in-game measurement is always `false`
- **Where:** `lib/user_data_manager.dart:241` (`vpnStatus` reads `_userData['isVPN']`, which is never written: the writer is commented out at `:486-494` and `createUserDocument` has it commented out), used at `lib/flutter_bridge.dart:136, 351`.
- **Scenario:** player on a VPN takes a measurement in Space Explorers → `collected_measurements` doc says `vpn_used: false`. The session doc gets the real value (`SessionManager.vpnStatus`), so the two disagree. This is research-data quality.
- **Fix:** use `await SessionManager().checkVPN()` (or cache `SessionManager.vpnStatus`) when building `checkData`.

### D-3 (medium) Firestore writes are awaited with no timeout, so they block until the device is online (unconfirmed on device)
- **Where:** `lib/session_manager.dart:196-200`, `lib/flutter_bridge.dart:368-375`, `lib/speed_test_page.dart:187-192`.
- **Problem:** Firestore `add()`/`set()` futures only complete when the backend acknowledges the write. Offline, the code after them (public session record, badge award, `endGame`'s `_currentGame = null`, post-game survey for Measure Internet) never runs until connectivity returns.
- **Scenario:** Measure Internet session ends while offline → `saveCurrentSession` hangs in `game_catalog.dart:285`, so `endGame` (screen-awake release, vibration stop) and the survey are delayed indefinitely.
- **Fix:** don't `await` the cloud write for control flow (or `.timeout()` it); the local cache already holds the write.

### D-4 (medium) Activity logging writes one Firestore document per UI rebuild
- **Where:** `lib/speed_test_page.dart:252`, `lib/game_catalog.dart:37`, `lib/home.dart:284`, `lib/dashboard.dart:22` (`loggingService.logEvent(...)` inside `build`).
- **Problem:** `logEvent` queues to Hive and triggers `syncToFirestore` → one Firestore write per event. `SpeedTestPage.build` re-runs on every NDT7 status line (`setState` per message, many per second), the home page rebuilds on every `UserDataProvider` notification.
- **Scenario:** one speed test generates hundreds of "User is in speed-test control page" events; on the Spark plan (20k writes/day) a few testers exhaust the quota, and the 500-item queue (`activity_logs.dart:50-55`) evicts the useful events.
- **Fix:** log once in `initState`/first frame.

### D-5 (low) Totals are absolute read-modify-write values
- **Where:** `lib/user_data_manager.dart:350-417`.
- **Problem:** two devices (or two quick saves) both compute `current + added` from their local copy and overwrite each other. `FieldValue.increment` avoids this.

### D-6 (low) `fetchUserData` rewrites `totalPointsCollected` on every call and defines "points" as measurements inside session documents only
- **Where:** `lib/user_data_manager.dart:475-481`.
- **Problem:** measurements in `collected_measurements` that never became part of a saved session (see S-8) are not counted; duplicated session docs (S-1) are counted twice. An extra write per fetch.

### D-7 (low) One non-bool value aborts the rest of `fetchUserData`
- **Where:** `lib/user_data_manager.dart:507` (`MapEntry(k.toString(), v as bool)`).
- **Scenario:** `messages_seen` contains a non-bool (manual console edit) → `TypeError`, caught at `:519`, so the onboarding branch and the log line are skipped.

### D-8 (low) Radius of gyration aggregation is not a radius of gyration
- **Where:** `lib/user_data_manager.dart:393-417`.
- **Problem:** the "weighted RMS" of per-session Rg values ignores that sessions have different centres, so the lifetime value shown on Home/Player Statistics is not the Rg of all points; a session of one point (Rg 0) dilutes it. Design-level, flagging in case the number is used in the research.

---

## 3. Session saving & game bridge

### S-1 (high) Every WebView game session is saved twice (three times if a game ever sends `endGameSession`)
- **Where:** `lib/game_catalog.dart:276-289` (`.then` → un-awaited `SessionManager.endGame`) → `lib/session_manager.dart:111` (`onWebViewClose`) → `saveCurrentSession`; **and** `lib/flutter_bridge.dart:122-125` (`dispose()` → `saveCurrentSession` again); **and** `lib/flutter_bridge.dart:211-216` (`endGameSession`).
- **Problem:** `Navigator.push(...).then(...)` runs as soon as the route is popped (before the 300 ms exit animation ends), at which point `onWebViewClose` is still set and fires save #1; `dispose()` later fires save #2 with the same session ID. Each save: `.add()`s a new session document, `updateDistanceTraveled`, `updateTotalLocationPoints`, `updateRadiusGyration` (all cumulative), then awards badges. Save #2 may also record `game: null` if `endGame` has already cleared `_currentGame`.
- **Scenario:** play Zombie Apocalypse for 600 m, back out → `measurements/{email}/sessions` gets two docs with identical `session_id`; `totalDistanceTraveled` += 1200 m; `totalPointsCollected` (sum over session docs) doubles; "First Steps → Regular Player (10 sessions)" and "Data Collector" come after ~5 plays; `public_sessions` is keyed by session ID so only the community stats are protected. (Only in release builds, because of S-9.)
- **Fix:** one save path: guard with a `_saved` flag keyed by session ID (clear it in `startGame`), remove either the `.then`→`onWebViewClose` path or the `dispose` save.

### S-2 (high) A finished game is never cleared from saved progress; "Continue" resumes the ending for 30 days (working-tree feature)
- **Where:** `lib/flutter_bridge.dart:211-216` (only place that calls `GameProgress.clear` on completion); the shipped games (`assets/ZombieApocalypse.html`, `hozhoni_scavenger_hunt.html`, `space_explorers_short.html`, `constellation_quest.html`) never post `endGameSession` (grep: zero occurrences; `SoulSeeker.html` only has `<<run endGameSession()>>` and no definition of that function, and it is commented out of the catalog anyway).
- **Scenario:** finish Zombie Apocalypse. `:passageend` has been saving every page through to the final passage, so the next time the catalog pop-up opens it says "You have a game in progress…" with Continue → drops the player into the end screen; they must hit "Start over". Same for Settings → "Clear saved games" counting finished games.
- **Fix:** add `window.endGameSession` to the games (or detect an end passage / tag in the hook script) and post the command; alternatively clear progress when a game's final passage is reached.

### S-3 (high) A new account's default favorite ("Soul Seeker") opens a broken game, and Dragon Slayer in the catalog does too
- **Where:** `lib/user_data_manager.dart:582` (default `favoriteGames: ['Zombie Apocalypse','Soul Seeker']`) and `:275-277`; `lib/game_catalog.dart:93-95, 105-117` (Soul Seeker/Dragon Slayer branches commented out "for the Hozhoni event"), `:189-192` (Play button).
- **Scenario:** new user or guest sees "Soul Seeker" on the home screen, taps it → dialog titled "Title", text "Content", **Play** → `_launchGame("Title","URL")` → `loadFlutterAsset('assets/URL')` fails (blank/error page), and the session is recorded with `game: "Title"`.
- **Fix:** filter `games` (and default favorites) to the games that have catalog entries; make the popup configuration data-driven so a game can't exist in one list but not the other.

### S-4 (high) `LocationLogger.start()` adds a new stream listener on every game launch and nothing ever stops it
- **Where:** `lib/location_logger.dart:12-15` (listener never stored or cancelled), `lib/game_catalog.dart:261`; stale comment at `lib/game_catalog.dart:289` / `lib/session_manager.dart:101` ("also will stop logging location").
- **Problem:** after N launches in one app run there are N listeners on the shared 1 Hz `bestForNavigation` stream; each increments the *shared* static `_writeCount` and each appends the point, so points are duplicated N-fold and sampling is irregular. GPS stays on for the rest of the process even outside games.
- **Scenario:** play three games in a row → ~3× `numLocationPoints`, wrong Rg weighting, `location_points` arrays tripled in Firestore; battery drain after the game ends.
- **Fix:** keep a single subscription; `start()` cancels the previous one; `stop()` from `endGame`.

### S-5 (high) Location failures leave the game waiting forever (and throw unhandled)
- **Where:** `lib/flutter_bridge.dart:395-410` (`sendLocationJSON`: no `try/catch`, no timeout); `lib/location_service.dart:77` (`FlutterCompass.events!.first` can wait forever if the sensor exists but never emits, *unconfirmed*), `:71` (`getCurrentPosition` has no `timeLimit`); also `writeCheckData` (`flutter_bridge.dart:506`) and the measurement path (`:339`) call `determineLocationData()` without a timeout.
- **Scenario:** location services off or permission denied; the game's "check my zone" posts `getLocation` → `determineLocationData()` returns `Future.error` → unhandled async exception, `window.onLocationJSON` is never called, the player is stuck on the zone-check screen. With a silent compass stream even permitted users can hang.
- **Fix:** wrap in `try/catch` + `.timeout`, reply with `{error: ...}` that the games handle; make the compass read optional with its own timeout.

### S-6 (medium) Latitude and longitude are swapped when building the measurement's geohash
- **Where:** `lib/flutter_bridge.dart:360` (`GeoFirePoint(GeoPoint(point.longitude, point.latitude))`; `GeoPoint` is `(latitude, longitude)`; compare the correct order at `session_manager.dart:188`).
- **Problem:** in debug builds `GeoPoint`'s asserts (`latitude` within ±90) fire for any longitude beyond ±90 (all of the US), the exception is swallowed by the catch at `:380`, and the measurement is never written to `collected_measurements` (it is already in the session list). In release builds the swapped value is stored as a garbage `geohash`.
- **Fix:** `GeoPoint(point.latitude, point.longitude)`.

### S-7 (medium) `requestMetricsAndWriteData` runs a full NDT7 test whose results are never stored, with no cooldown or error path
- **Where:** `lib/flutter_bridge.dart:170-188, 413-422`.
- **Problem:** `grabMetrics()` is not awaited, has no `try/catch` (a network failure is an unhandled exception and `window.onMetrics` is never called), no concurrency guard and no cooldown (unlike `getInternetMeasurement`); the results go only to the game's JS variables. The Firestore write (`writeCheckData`) contains the game's payload but no speeds, and nothing is added to `SessionManager.measurements`.
- **Scenario:** in Zombie Apocalypse / Hozhoni / Constellation Quest, every "request metrics" runs a ~20 s test, repeated taps run overlapping tests that distort each other, and none of it counts toward "measurements collected"/badges (only Space Explorers/Soul Seeker use `getInternetMeasurement`).
- **Fix:** reuse the `getInternetMeasurement` code path (cooldown, saving) and reply with an error payload on failure.

### S-8 (medium) The POI lookup runs twice, and the second result can reset collected POIs
- **Where:** `lib/flutter_bridge.dart:108` (initState) and `:264-266` (game's `setPOIs`), both ending in `SessionManager.setPOIs(...)` (`:432`).
- **Problem:** two Overpass queries per game start (extra rate-limit risk, 429s are tolerated but slow); whichever finishes last replaces the list, and a game that sends `setPOIs` again later (new zone, Zombie Apocalypse does this per zone) restores POIs the player had already collected. The game's own payload (`campusPois` etc.) is ignored.
- **Fix:** run the lookup once per game (or per explicit `setPOIs`) and ignore a stale result.

### S-9 (medium) `Provider.of(context)` inside `dispose()` throws in debug builds, skipping the save and `super.dispose()`
- **Where:** `lib/flutter_bridge.dart:122` (also `lib/home.dart:266`); contradicts the comment at `flutter_bridge.dart:61-63`.
- **Verified by probe:** `Provider.of<T>(context, listen: false)` in `dispose()` raises "Looking up a deactivated widget's ancestor is unsafe" under debug assertions.
- **Scenario:** in debug the dispose-time save, `onWebViewClose = null` and `super.dispose()` never run (so debug shows one save; release shows two, see S-1: the app behaves differently in the two modes). `HomePage` leaves its provider listener registered.
- **Fix:** cache the provider in `initState`/`didChangeDependencies` (the code already caches `_account`).

### S-10 (medium) Resume script is re-injected on every page load, and a stuck "resuming" flag blocks saving
- **Where:** `lib/flutter_bridge.dart:86-93, 455-467`; `lib/game_progress.dart:316-342` (`window.__netgauge.resuming = true` is set at `:321` *before* the `resumed` guard at `:322`); the comment at `flutter_bridge.dart:451-453` ("do nothing the second time") is not true across a reload because JS globals are recreated.
- **Scenario:** player taps Continue, then the game restarts via SugarCube's restart (`location.reload()`, *unconfirmed on device*) → `onPageFinished` fires again → `resumeScript(resumeFrom.save)` is injected again and puts the player back into the old save instead of the fresh start. If the page finishes loading twice in the same JS context, the second run sets `resuming = true` and returns without ever calling `done()`, so `saveGameProgress` is suppressed for the rest of the session.
- **Fix:** inject the resume script once (flag in Dart) and set `resuming` only after the `resumed` check.

### S-11 (medium) Location stream subscriptions have no `onError`
- **Where:** `lib/location_logger.dart:15`, `lib/vibration_controller.dart:30` (both `LocationDispatcher.stream.listen(...)`, stream defined `lib/location_service.dart:20-33`).
- **Problem:** with location services off or permission denied the position stream emits `LocationServiceDisabledException`/`PermissionDeniedException`; with no handler these become uncaught zone errors on every game launch.
- **Fix:** pass `onError` and surface a message once.

### S-12 (medium) `saveCurrentSession` is not protected against plugin failures
- **Where:** `lib/session_manager.dart:154-158` (`checkVPN()`, `checkFakeLocation()` are awaited with no `try/catch`, before anything is saved).
- **Scenario:** `vpn_connection_detector`/`detect_fake_location` throw (unsupported device, plugin error) → no session document, no totals, no badges for that play. Also `fakeLocationStatus` is computed but never stored anywhere (`:55, 157`).
- **Fix:** wrap each check, default to `false`, and always write the session.

### S-13 (medium) Unreplied or failed `getInternetMeasurement` still burns the 30 s cooldown
- **Where:** `lib/flutter_bridge.dart:309-317`.
- **Problem:** `_lastMeasurementTime` is set before the test; if the test throws (no network, token expired), the player cannot retry for 30 s and the game is never told either way.
- **Fix:** set the timestamp on success; reply with a result/error callback.

### S-15 (low) `requestPOIName` is broken (dead)
- **Where:** `lib/flutter_bridge.dart:157-168, 492-494`.
- **Problem:** `data['payload']` is a `Map`, so `poiRequested.longitude` throws `NoSuchMethodError`; `firstWhere` has no `orElse`; `sendPOIName` injects the name unquoted into JS (`onRequestPOIName($poiName)`) so any name with a space/quote is a JS syntax error. No shipped game sends it.
- **Fix:** delete, or read `payload['longitude']`, add `orElse`, and `jsonEncode` the name.

### S-16 (low) Location points collected by POI checks, hints and check-data writes are discarded
- **Where:** `lib/flutter_bridge.dart:56, 400, 507, 564, 630` (widget-local `locationPoints` is only ever appended to). Distance and Rg use `SessionManager.sessionLocationPoints` (logger samples and measurement points only).

### S-17 (low) POI collection radius is 7 m, the comment says 10 m
- **Where:** `lib/flutter_bridge.dart:587-588`. Vibration thresholds (`poi_logic.dart:52-55`) treat 7 m as "closest pulse", so the phone says "very close" at the exact distance a find becomes possible.

### S-18 (low) `startGame` runs twice per launch
- **Where:** `lib/game_catalog.dart:259` and `lib/flutter_bridge.dart:73` → duplicate "Starting …" log events, `_startTime` reset and a new session ID mid-launch (harmless today, but the first ID is orphaned).

### S-19 (low) Widget state used after dispose in `WebViewPage`
- **Where:** `lib/flutter_bridge.dart:91` (`setState` in `onPageFinished` with no `mounted` check), `:135` (`Provider.of(context)` before the `try`, for messages that arrive after disposal), `:408-410, 420-421, 549, 560` (`controller.runJavaScript` after the page is gone).
- **Fix:** guard with `if (!mounted) return;`.

### S-20 (low) GPS jitter inflates "distance traveled"
- **Where:** `lib/session_manager.dart:236-248`, `lib/location_service.dart:25-31` (`distanceFilter: 0`, no accuracy filter).
- **Scenario:** standing still outdoors for 10 minutes produces a few hundred metres of drift; badges ("Explorer") and totals count it. *Unconfirmed* magnitude.

### S-21 (low) Stale POIs from the previous game remain visible to vibration/hints until the new lookup completes
- **Where:** `lib/session_manager.dart:86-99` (`startGame` resets measurements and fallback but not `_poiList`).

### S-22 (low) Favorite toggle logs the opposite action
- **Where:** `lib/game_catalog.dart:315-326`. `toggleFavorite` updates state synchronously, so `isFavorited` is already the *new* value: adding a favorite logs "removed from favorites" and vice versa. Corrupts the activity log.

### S-23 (low) Placeholder text is user-visible
- **Where:** `lib/game_catalog.dart:132, 139` ("Testing this plz work!"), `lib/location_notice.dart:11-16` ("This is placeholder text…").

---

## 4. POI / location logic

### P-1 (medium) `Overpass` failures other than HTTP errors are indistinguishable from "no POIs"
- **Where:** `lib/poi_generator.dart:197-205, 223-233`, `lib/flutter_bridge.dart:440-443`.
- **Problem:** any exception (timeout across three 30 s endpoints, location unavailable) becomes `[]`, which silently switches the whole game to the 1 km "move a distance" fallback, even though real POIs may exist. A 429 on every mirror does not set `lastException` (`:41-42`), so the user-visible/logged reason is just "Failed to load".
- **Fix:** distinguish "no POIs" from "lookup failed", retry once, and tell the game.

### P-2 (medium) `fallback.distanceMoved` mutates state as a side effect of read-only callers
- **Where:** `lib/poi_logic.dart:94-100`, called by `VibrationController._onLocation` (`vibration_controller.dart:55-56`) and `provideHint` (`flutter_bridge.dart:636`).
- **Scenario:** with no POIs the vibration service starts, the first location update sets `_start` to where the player happened to be then; the later first "search" measures 1 km from that point rather than from the lookup location. Low impact, but the "start" is set by whichever caller comes first.

### P-3 (low) `getCurrentPosition` has no `timeLimit`
- **Where:** `lib/location_service.dart:71-72`. Indoors/with a poor fix it can wait indefinitely (callers that wrap it in `.timeout` leave the underlying request running).

### P-4 (low) POI search radius and pool
- **Where:** `lib/poi_generator.dart:204` (`max_distance = 500`): the 5 nearest within 500 m; dense areas fine, rural areas always fall back. Not a bug per se; note for expectations of "Rural" play areas.

### P-5 (low) `Position`-based `heading` can be stale/null on iOS
- **Where:** `lib/flutter_bridge.dart:641-646` returns "No compass available" whenever the one-shot compass read failed, even though POIs exist; the hint then never works on devices without a compass event.

---

## 5. Speed test / NDT7

### N-1 (high) Upload speed is capped at about 6.5 Mbps by the client itself
- **Where:** `lib/ndt7_service.dart:213, 246-256` (one 8 KB frame every 10 ms = 8192 × 8 / 0.01 = **6.55 Mbps** maximum), result computed from bytes *queued* with `socket.add`.
- **Scenario:** on a 100 Mbps connection the app reports ~6 Mbps upload; on a slow link `socket.add` buffers faster than the network drains so queued bytes overstate the real speed. Every upload number in `collected_measurements`, the maps, community averages and the "Need for Speed"-style badges derive from this.
- **Fix:** send as fast as the socket accepts (await `socket.done`/backpressure or use large frames and check `bufferedAmount` equivalent), and compute speed from the server's `AppInfo.NumBytes` messages like the official ndt7 client.

### N-2 (medium) Locate URLs (with access tokens) are cached for the lifetime of the service (unconfirmed)
- **Where:** `lib/ndt7_service.dart:25-37`; each `WebViewPage` keeps one `NDT7Service` for the whole game.
- **Problem:** M-Lab locate URLs carry a short-lived access token. A second measurement minutes later reuses the cached URL and the server may reject the connection, which surfaces as the generic failure in S-13. `getNDT7Urls` also has no HTTP timeout and does `data['results'][0]` without checking for an empty list.
- **Fix:** cache for ≤1–2 minutes; add timeout and null checks.

### N-3 (medium) `SpeedTestPage` stores `session_id: "Instance of 'Uuid'"`
- **Where:** `lib/speed_test_page.dart:171-172` (`Uuid()` then `.toString()`; `uuid` 4.5.3 has no `toString`; should be `Uuid().v4()`); the real session ID is read at `:156` and never used (analyzer flags the unused local).
- **Scenario:** every Measure Internet document in `collected_measurements` has the same literal `session_id`, so measurements can't be joined to sessions.

### N-4 (medium) Re-entrancy: "Run Test" can be started repeatedly
- **Where:** `lib/speed_test_page.dart:82, 298-306` (`onPressed: _runSpeedTest`, no busy flag).
- **Scenario:** double-tap → two concurrent download/upload tests share the link, both report depressed speeds and both write documents.
- **Fix:** disable the button while running.

### N-5 (medium) `setState` after dispose throughout the speed test
- **Where:** `lib/speed_test_page.dart:60-65` (probe error), `:92-248` (after every `await`, and from the NDT7 status callbacks at `:111-113, 148-150`).
- **Scenario:** player leaves the page during the 20+ s test → "setState() called after dispose()" errors from each remaining status line; the finished measurement is still written after the page is gone. Add `if (!mounted) return;`.

### N-6 (medium) Leftover debug WebSocket probe to a third-party host on every page open
- **Where:** `lib/speed_test_page.dart:39-62` (`wss://echo.websocket.org`).
- **Problem:** each visit connects out to an unrelated service (IP disclosure for a research app, extra battery/data); if the service is down the page shows "WebSocket test failed… network permission issue" even though the real test works.
- **Fix:** remove it.

### N-7 (low) Upload test edge cases
- **Where:** `lib/ndt7_service.dart:246-306`. If the socket errors (`isDone = true`, timer cancelled) the completer is not completed until the 15 s safety timer fires, and then it completes as a *success* with partial bytes; the safety timer path doesn't set `isDone`, so the periodic timer keeps trying to `add` to a closed socket until it throws.

### N-8 (low) Download byte count mixes server and client counters
- **Where:** `lib/ndt7_service.dart:104-110` assigns `bytesReceived = AppInfo.NumBytes` (bytes the *server* has sent) while binary frames are also added at `:128-129`, so bytes in flight at each JSON message are counted twice. Small but biases the speed up. *Unconfirmed* magnitude.

### N-9 (low) Placeholder values presented as results
- **Where:** `lib/speed_test_page.dart:221-222` shows `-1` for Jitter and Packet Loss; `lib/ndt7_service.dart:50-51` and `flutter_bridge.dart:328` store `jitter: -1`/`0.0`. Users and later analysis see a fake value instead of "not measured".

### N-10 (low) Measure Internet documents differ from in-game ones
- **Where:** `lib/speed_test_page.dart:174-183`: `game: 'Speedtest'` (the session uses "Measure Internet"; only the `canonicalGameName` alias hides it), no `vpn_used`, no `geohash`.

### N-11 (low) `substring(0, 50)` on the WebSocket URL
- **Where:** `lib/ndt7_service.dart:73, 196` → `RangeError` for a URL shorter than 50 characters (not the case with real M-Lab URLs, but an exception that would fail the test).

### N-12 (low) Connectivity listener compares a `List` with an enum
- **Where:** `lib/activity_logs.dart:56-58` (`connectivity_plus` 7.x emits `List<ConnectivityResult>`; `result != ConnectivityResult.none` is always true), so it syncs on every change including going offline.

---

## 6. Maps & H3

### M-1 (medium) The map's Home button stacks a second `HomePage`
- **Where:** `lib/dynamic_map.dart:295-299` (`pushReplacement(HomePage)` from a screen opened with `push` on top of the existing `HomePage`).
- **Scenario:** Home → Expand Map → tap the house icon: the stack becomes `HomePage, HomePage`. The new instance re-runs `_runFirstLaunchFlow` (surveys, location notice again because `_locationNoticeHandled` is per-instance) and registers another `onMessageOpenedApp` listener. Back returns to the first Home.
- **Fix:** `Navigator.popUntil(context, (r) => r.isFirst)`.

### M-2 (medium) Community-statistics query truncates by latitude only (silently biased south)
- **Where:** `lib/community_statistics.dart:67-74` (`where latitude >= min && <= max` `.limit(5000)`).
- **Problem:** a single-field range query is ordered by latitude ascending and has no longitude bound; once more than 5000 public documents fall inside the ±0.72° band anywhere in the world, the northernmost are dropped, so counts and averages for the user's 50-mile area are wrong, with no indication. Likewise `public_sessions` (most-played game).
- **Fix:** add a longitude bound via geohash ranges (the documents have no geohash today) or paginate and aggregate.

### M-3 (low) "All Measurements" reads an arbitrary 5000 documents each time it is opened
- **Where:** `lib/dynamic_map.dart:160-163`. No ordering/region filter, so which points appear is arbitrary once there are more than 5000; and each open costs up to 5000 reads (Spark: 50k/day). Errors in "mine" scope are swallowed (`:190`).

### M-4 (low) `MapPage` (`mapping.dart`) cannot cope with location being off, and is only reachable from dead code
- **Where:** `lib/mapping.dart:140-175` (`_logMapViewEvent` calls `determineLocationData()` with no `catch`; `_setInitialCenter` calls `setState` after an await with no `mounted` check); only referenced by `likert_form.dart` (see X-1).

### M-5 (low) Duplicate `DataPoint` classes and `getPointsStream`
- **Where:** `lib/dynamic_map.dart:16-75` redeclares `DataPoint`/`getPointsStream` already defined in `lib/user_data_manager.dart:89-140`; the local declaration silently shadows the imported one. Neither stream helper is used.

### M-6 (low) `toWeighted` has a cliff at 120 days and no guard for future timestamps
- **Where:** `lib/mapping.dart:20-26` (intensity jumps from 0.3 × to 0 at day 121; negative `age` makes `fadeFactor` > 1 before the clamp). Only used by the dead `MapPage`.

---

## 7. Surveys

### V-1 (high) A survey is marked completed before the answers are saved, and save errors are swallowed
- **Where:** `lib/surveys.dart:116-130` (`setDemographicStatus()` / `recordSurveyToken()` are awaited first), `:187-207` (`addUserData` catches and prints the exception), `:126-130` (snackbar "Survey submitted" runs in `.then` regardless).
- **Scenario:** network drops or rules reject the write → answers lost, the user is told "Survey submitted", `demographicsSurveyTaken`/`lastSeenSurveyToken` is set, the survey is never offered again (demographics only exist once). Data loss for the research.
- **Fix:** write the response first, mark the survey done only on success, and rethrow so the UI can say "could not submit".

### V-2 (medium) Survey Submit can be tapped repeatedly
- **Where:** `lib/surveys.dart:112-130` (no `_isSubmitting` flag, unlike `post_game_survey.dart:140-142`). Double tap → duplicate response documents.

### V-3 (medium) One question without a `mandatory` field makes the whole survey "not available"
- **Where:** `lib/surveys.dart:174` (`isMandatory: q['mandatory']` assigns `null` to a `bool` → `TypeError`), swallowed at `:187-191` which returns `[]`. `post_game_survey.dart:36` correctly uses `?? false`.
- **Fix:** `(q['mandatory'] as bool?) ?? false`.

### V-4 (medium) Tapping a survey push notification does nothing (or throws)
- **Where:** `lib/home.dart:73-85`.
- **Problem:** `Navigator.pushNamed(context, '/survey', arguments: SurveyState(...))`: `MaterialApp` defines no routes, so `/survey` is unknown (assertion in debug, no-op in release); `surveyDocId: message.data['type']` passes the string `"survey"` as the document ID; the `onMessageOpenedApp.listen` subscription (`:70`) is never cancelled, so every `HomePage` instance (see M-1) adds another handler, and `context` is used after the page may be disposed.
- **Fix:** `Navigator.push(MaterialPageRoute(builder: (_) => SurveyState(surveyDocId: message.data['surveyDocId'], ...)))`, store and cancel the subscription.

### V-5 (low) `_SurveyState.initState` calls `setState` from the future without `mounted` check
- **Where:** `lib/surveys.dart:44-52`.

### V-6 (low) Dismissing the remote-config survey without submitting shows it again every launch
- **Where:** `lib/home.dart:188-201` + `user_data_manager.dart:632-658` (token only recorded on submit). The comment on `recordSurveyToken` says "submits or dismisses". Product decision, but contradicts the comment.

### V-7 (low) Survey responses key off `userData.email` while the profile may not have loaded
- **Where:** `lib/surveys.dart:61, 125`; falls back to `accountIdFor`, fine, but the post-game survey is offered even if no session was saved (e.g. `D-1` aborted).

---

## 8. Badges

### B-1 (medium) Badges are awarded permanently from inflated numbers
- **Where:** `lib/user_data_manager.dart:206-217` + `lib/badges.dart:182-190`.
- **Problem:** badge progress comes from session documents, which are duplicated (S-1) and from `totalDistanceTraveled` which is double-counted. Stored badges "are only ever added, never removed" so a premature "Regular Player" or "Explorer" stays. Fixing S-1 later will not revoke already-awarded badges.
- **Fix:** fix S-1 first; consider a one-time recompute/cleanup.

### B-2 (low) A badge refresh can be silently skipped
- **Where:** `lib/user_data_manager.dart:202` (`|| _awardingBadges` returns `[]`). `dispose()` calls `fetchUserData()` right after saving (`flutter_bridge.dart:124`), so the game-end `awardNewBadges(refreshSessions: true)` can be dropped and the new session isn't counted until the next fetch (e.g. next launch).

### B-3 (low) Guests play but earn nothing, with no explanation
- **Where:** `lib/user_data_manager.dart:202`; consistent with the stats page being hidden for guests, but game-end snackbars never appear for them and they are never told why.

---

## 9. Settings / theme / notifications

### T-1 (medium) Changing the theme rebuilds the auth gate (spinner, refetch, first-launch flow) (unconfirmed on device)
- **Where:** `lib/main.dart:~66` (`context.watch<ThemeController>()` in `MyApp.build`) and `:~80` (`FirebaseAuth.instance.authStateChanges()` called in `build`).
- **Problem:** `authStateChanges()` returns a new `Stream` each call, so each theme change makes the `StreamBuilder` resubscribe and briefly report `ConnectionState.waiting` (the builder returns the spinner, disposing `HomePage`); on the next event it rebuilds `HomePage` from scratch and re-runs the post-frame `fetchUserData()`/`scheduleIfEnabled()`.
- **Scenario:** Settings → Appearance → Dark: a refetch occurs, and the recreated `HomePage` can push surveys/welcome/location-notice dialogs on top of the Settings page.
- **Fix:** create the stream once (`late final _authStream`) in a `StatefulWidget`, or move the theme watch below the `StreamBuilder`.

### T-2 (medium) The daily reminder preference says "on" even when the OS denied permission
- **Where:** `lib/daily_reminder_service.dart:56-62, 70-90`; `lib/main.dart:~90` (`scheduleIfEnabled` at every launch and login).
- **Problem:** `isEnabled` defaults to `true` and is only persisted when the user toggles. If notification permission was denied, every launch asks again (Android 13+/iOS prompts once more or silently fails) and the Settings switch shows "on" while no notification is scheduled (the switch is initialised from `isEnabled` at `settings.dart:28`).
- **Fix:** persist `false` when permission is denied; don't prompt on launch.

### T-3 (low) Startup requests notification permission twice
- **Where:** `lib/main.dart:31` (`FirebaseMessaging.requestPermission`) and `daily_reminder_service.dart:112-119`.

### T-4 (low) Screen-awake is toggled twice per launch and not tied to the single session
- **Where:** `lib/session_manager.dart:96` (via both `startGame` calls, see S-18) and `flutter_bridge.dart:118`. Harmless, but `endGame` is un-awaited and (offline) can run late (D-3).

---

## 10. UI / layout

### UI-1 (high) Home map preview is locked to a Swiss bounding box and rebuilt on every provider notification
- **Where:** `lib/home.dart:386-396` (`OSMFlutter(controller: MapController(initPosition: 47.4358055, 8.4737324, areaLimit: BoundingBox(east: 10.49, north: 47.81, south: 45.82, west: 5.96)))` created inside `build()`).
- **Problem:** (a) `areaLimit` restricts the camera to Switzerland, so a user in Flagstaff cannot see their own location in the preview (*unconfirmed visually*); (b) a new `MapController` is created on every rebuild (home rebuilds on each `UserDataProvider` notification, e.g. on every `updateDistanceTraveled`), which re-initialises the native map view and leaks controllers (never disposed).
- **Fix:** remove `areaLimit`, create the controller once in `initState`, dispose it.

### UI-2 (medium) `HomePage` leaks a provider listener and uses `context` after dispose
- **Where:** `lib/home.dart:243-262` (`_onDataLoaded` registered in `_waitForDataThenCheckSurvey` is never removed in `dispose`, `:265-272`), `:237-241` (`_runFirstLaunchFlow` begins with `Provider.of(context)` before any `mounted` check).
- **Scenario:** log out before the profile finishes loading → the callback fires on a disposed state and throws; a replaced `HomePage` (M-1, T-1) keeps a live listener.

### UI-3 (low) Player Statistics shows `null` and goes stale
- **Where:** `lib/dashboard.dart:170-171` (`'Average Download: ${item.averageDownloadSpeed?.toStringAsFixed(2)} Mbps'` prints "null Mbps" for sessions without measurements); `:21` (`Provider.of(..., listen: false)`, totals don't refresh if the page opens before `fetchUserData` finishes); `:116-122` (`didChangeDependencies` only rebuilds when the *length* changes).

### UI-4 (low) Distance is displayed without a unit
- **Where:** `lib/home.dart:327`, `lib/dashboard.dart:52` (meters, labelled "Total Distance Traveled").

### UI-5 (low) `SpeedTestPage` content is not scrollable
- **Where:** `lib/speed_test_page.dart:262-310` (`Column` of five cards + error log). With larger text or a long `errorLog` (it prints the full stack trace) the column overflows; wrap in `SingleChildScrollView`.

### UI-6 (low) `AnimatedEllipsis`/button widgets expose no semantics
- **Where:** `lib/widgets/buttons.dart:37` (`GestureDetector` with no `Semantics`, unlike the badge tiles) so TalkBack/VoiceOver cannot activate the main game/utility tiles. (Accessibility.)

---

## 11. Tests

### TT-1 (medium) None of the buggy areas has a test
- No tests import `session_manager`, `user_data_manager`, `flutter_bridge`, `ndt7_service`, `speed_test_page`, `surveys`, `settings` or `main`; only `screen_awake_test.dart` touches `SessionManager.startGame/endGame`. Every High/Medium finding in sections 2, 3, 5, 7 lives in that untested code. The pure helpers (`poi_logic`, `community_stats`, `badges`, `h3_grid`, `game_progress`, `public_*`) are well covered.

### TT-2 (medium) `game_progress_test.dart` checks the JavaScript only as text
- **Where:** `test/game_progress_test.dart:201-250` (`contains(':passageend')`, `contains('__netgauge.resuming = true')`, balanced-brace style checks). The scripts are never executed, so S-10 (flag set before the guard, re-injection on reload) can't be caught, and a typo in SugarCube API names would still pass.
- Also: the file is **untracked**, so the suite on the branch doesn't contain it.

### TT-3 (low) `test/widget_test.dart` is the template counter test (known failure)
- **Where:** `test/widget_test.dart:12-30`. Pumps `MyApp()` without Firebase/Provider setup and looks for a counter that doesn't exist. It should be deleted or replaced.

### TT-4 (low) Login tests prove validation only
- **Where:** `test/login_forgot_password_test.dart:42-50` ("does not call Firebase" passes because Firebase is not initialised; the success message and the `FirebaseAuthException` mapping at `login_page.dart:128-141` are untested).

---

## 12. Platform config, assets, dead code

### X-1 (low) Dead or contradictory code
- `lib/likert_form.dart` (never navigated to; reads a `LocationData` collection nothing writes since `location_logger.dart:21-48` was commented out), `lib/mapping.dart` `MapPage` (only reachable from it), `lib/name_entry_page.dart`, `lib/dashboard_pages/*` (unreferenced; `total_data_points.dart:51-59` calls `.latitude` on `dynamic` Map items and would throw), `lib/abc_onboarding.dart`, `showSurveyPopup`/`listenRemoteConfig` in `home.dart:563-652`, `fetchCollectedMeasurements`, `updateTotalPointsCollected`, `UserDataProvider.phone` (default `'1111111111'`), `createUserDocument`'s `radGyration: [0]`/`dataPoints: []` fields, `RemoteConfigService` defaults for keys the code doesn't read (`show_survey`) and no default for the ones it does (`survey_trigger_token`, `survey_cooldown_days`).

### X-2 (low) Stale game files and a non-existent JS bridge
- `assets/Zombie Apocalypse.html` and `assets/hozhoni scavenger hunt.html` are not declared in `pubspec.yaml`; every game still defines `grabAndCheckLocation()` calling `AndroidBridge.getLocationJSON()` (e.g. `ZombieApocalypse.html:497`), but no `AndroidBridge` channel exists. It is not called by the shipped passages I traced, so it is dead; if invoked it throws `ReferenceError`. Games also send `publishPlayerName` which the bridge ignores (logged as "Unknown command").

### X-3 (low) `functions/` (not deployed) would conflict with the app
- `functions/anonymize.js:24-26` keys public docs by `sha256(email/docId)` whereas the app writes `public_measurements/{savedRef.id}` (`public_measurements.dart:56`, `session`/`speed_test_page.dart`). If the project moves to Blaze and the function is deployed, each measurement is published twice under different IDs and counted twice on the maps. `functions/README.md` says "Not in use"; `dynamic_map.dart:159-160` still comments that the Cloud Function keeps the collection up to date.

### X-4 (low) Android build configuration
- **Where:** `android/app/build.gradle` (`applicationId "com.pht.netgauge"`, applies google-services) *and* `android/app/build.gradle.kts` (`com.example.internet_measurement_games_app`, no google-services) both exist; `google-services.json` lists three package names. Which file Gradle uses decides which app ID ships (*unconfirmed*). Release builds are signed with the debug key in both (`build.gradle:59`, `build.gradle.kts:38`). `android/app/.cxx/**` build output is tracked in git. `BODY_SENSORS` (manifest `:5`) is not needed for the compass.

### X-5 (low) iOS ATS and location strings
- **Where:** `ios/Runner/Info.plist:29-31` (`NSAllowsArbitraryLoads` = true; the per-domain exceptions are redundant), `:58-63` (the "Always" usage string promises "background performance metrics" but the app only uses foreground location and the Android manifest has no background permission; the WhenInUse string says "nearest speed test server", which doesn't describe games/maps).

---

## Notes for follow-up
- Several findings interact: fixing **S-1** (single save) and **S-4** (single location subscription) removes most of the inflated totals; **B-1** then needs a clean-up decision for existing accounts.
- The security items already handled on `security-hardening-claude` were not re-reported. New security-relevant observations: **N-6** (third-party echo probe), **X-5** (ATS arbitrary loads), **X-4** (debug signing for release).
