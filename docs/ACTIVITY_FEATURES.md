# Daily Activity & Outdoor Intelligence

## Architecture discovered

| Area | Current stack |
| --- | --- |
| Language / UI | Flutter (Dart) + Material 3 custom fintech UI |
| iOS host | Swift `AppDelegate` / `SceneDelegate`, deployment target **iOS 15.0** |
| Navigation | `IndexedStack` shell + `CupertinoPageRoute` pushes |
| Persistence | `shared_preferences` for money ledger and activity targets; Documents JSON for outdoor sessions |
| Bundle | `com.debugged.aster.aster` · Team `YLKU69SJ9T` |

The existing expense tracker was left in place. Activity features are additive modules under `lib/motion/` and `lib/screens/motion/`, with a native bridge in `ios/Runner/ActivityPlugin.swift`.

## Plan and assumptions

1. **Source of truth for daily totals:** HealthKit when a sample exists. Core Motion (CMPedometer) only when HealthKit has no value. Never sum both.
2. **Outdoor sessions:** Core Location GPS + optional CMAltimeter relative altitude. Dart pure functions filter drift and compute distance / pace / elevation.
3. **Maps:** Native MapKit via Flutter `UiKitView` (`aster/route_map`) — no third-party map package.
4. **Background:** `UIBackgroundModes` = `location`, Always authorization requested only when starting outdoor tracking, with blue status bar indicator while active.
5. **HealthKit read denial** is not detectable; the UI treats empty results as “no data / unavailable,” not as proof of denial.

## Required Xcode / iOS configuration

- Info.plist usage strings: Health share/update, Motion, Location When In Use, Location Always
- Background mode: `location`
- Signing: Automatic with team `YLKU69SJ9T`

### HealthKit entitlement (blocked until portal is updated)

Release signing currently fails with:
1. Account Holder **Sheshank Jamwal** must accept the latest Apple Developer Program License Agreement.
2. Enable **HealthKit** on App ID `com.debugged.aster.aster` (wildcard profiles cannot carry HealthKit).
3. Uncomment the HealthKit keys in `ios/Runner/Runner.entitlements`.

Until then, daily steps/distance use **Core Motion** when authorized. Outdoor GPS tracking does not need HealthKit.

## Manual test steps (physical iPhone)

1. Open **More → Daily activity → Enable activity access**. Allow Health and Motion prompts.
2. Confirm today’s steps/distance render or show “—” without crashing if empty.
3. Change daily targets via the flag icon; reopen and confirm they persist.
4. Open **Outdoor tracking → Walk**. Allow location (Always if prompted).
5. Start, pause, resume, finish. Confirm map polyline, timer, distance, and GPS quality label update.
6. Lock the phone briefly during tracking; unlock and confirm tracking resumes or remains active when Always is granted.
7. Finish session; reopen from history; force-quit app; reopen history — session still present.
8. Deny Health or Location in Settings → Ajuga; confirm screens show permission / empty states without crash.
