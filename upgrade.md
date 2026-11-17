# FitGo 3.0 — UI Upgrade & iOS Roadmap

## Goal planner UX proposal — 17 Nov 2026

Status: planned, not implemented.

Keep the current target weight and target date inputs. Keep the existing **Use this plan** action. Directly below it, add one optional numeric input labeled **What if I eat … kcal per day?**. Use the profile and the already selected target date to calculate one prominent result: **Estimated weight on [date]: [weight]**. This is the daily-intake forecast the user asked for. Do not add a second mode, or another target/date form.

Calculate on-device using simple math, with no AI or network:

- Estimated weight change = (maintenance calories − entered daily intake) × days ÷ 7,700.
- Projected weight = current weight − estimated weight change.

Keep the main screen calm. Put detailed math and longer explanations behind a collapsed **Goal breakdown** or an info icon. Do not block saving or hide a zero/negative raw calorie result; show a concise explanation beside it. Keep workouts separate from the base goal and intake forecast. Logged activity may show its observed impact separately. Do not assume future workouts unless the user explicitly enters that assumption.


> **Status:** In progress on `feature/ios-foundation`  
> **Current app:** FitGo `3.0.0+3` — Flutter 3.41.7 / Dart 3.11.5  
> **Target:** A polished, adaptive FitGo that feels at home on iPhone and iPad, is App Store-ready, and keeps Android working.  
> **Last updated:** 17 November 2026
> **Next milestone:** a TestFlight install on a real iPhone and iPad. Code-side Phase 0, Phase 1, the v3 Today/Trends/Profile rebuild, and the optional AI coach are in place; macOS signing, device verification, account deletion, published legal URLs, and store data-safety answers remain external blockers.
>
> **v3 UI snapshot (16 Nov 2026):** Today is a quick logbook with one calorie hero, independent flat rows, one meal sheet, one-tap water with Undo, and a folded Health section. Trends opens on this week with one intake-vs-budget chart, one plain-language insight, lazy history, and `/past-day?date=` deep links. Profile is grouped into **Goals**, **Preferences**, **Account & Backup**, and **Help & Privacy**, with last sync, pending-change count, and retry together. **Goals → Goal plan** asks for a target weight and date, then sets daily calories and water from a safe deficit/surplus.
>
> **Goal planner (16 Nov 2026):** `GoalPlan` converts 7,700 kcal/kg into a daily budget, caps loss at 750 kcal/day and gain at 500 kcal/day, enforces a 1,200 kcal/day floor, and shows the earliest safe date when a deadline is too aggressive. The user’s target date is kept, but the saved calorie target follows the safe pace instead of recommending starvation. Water follows 35 ml/kg rounded to 250 ml with a **1,500 ml/day floor**. Onboarding applies the same suggested calorie floor and water floor, so the first plan is safe too. The plan is stored in Hive fields 10–11, included in Supabase profile sync, and recalculated when weight or height changes.
>
> **Notification audit (16 Nov 2026):** Android now uses only the cross-platform `flutter_local_notifications` path; the legacy Kotlin alarm/receiver stack was removed so old reminders cannot duplicate. Fasting series cover the full 36 h preset (60 pending slots), use the white status-bar icon and a high-importance channel, and never schedule a time in the past. The series is re-armed on resume after a permission change or an OS cleanup. The calorie guard is one-shot and re-armed on resume/data changes even when no screen is open, so stale month totals cannot repeat. Permission prompts only happen from explicit user actions, and concurrent initialization now awaits one shared future.
>
> **AI coach (17 Nov 2026):** An optional, read-only Gemini coach now lives in **Profile → Preferences → AI coach**. It uses the user’s own free Gemini key, stored per account in platform secure storage (never Hive, Supabase, logs, or a FitGo server) and excluded from Android backup. The first 10 requests of each day alternate between 3.8 Flash and 3.6 Flash, then route automatically to 3.5 Flash Lite (1,500 free requests/day); quota, missing model, overload, network, timeout, and empty-answer failures fall through without user action. FitGo computes the progress facts and on-track status locally; the model receives a compact, PII-free snapshot plus recent chat and is forbidden from changing goals or giving unsafe diet/medical advice. Chat history is local, capped at 40 messages, and deletable.
>
> **Latest fixes (14 Nov 2026):** Meal Undo now preserves legacy v2 calories and untracked totals; past-day edits refresh Trends and every derived cache via `LocalStorage.dataRevision`; Today’s header and water row fit 320 pt at 200% text in guest and pending-sync states. Regressions live in `test/provider_undo_test.dart`, `test/past_day_screen_test.dart`, and `test/home_layout_test.dart`.
>
> **Verified (17 Nov 2026):** `flutter analyze` clean and all **91 tests** pass, including 17 AI routing/context/fallback/isolation/layout/lifecycle tests, 10 goal-planner/hydration tests, 9 notification-scheduling tests, and 2 branding tests. Android release builds pass after dropping retained native debug symbols: universal APK **26.7 MB** (all ABIs, 10:41, SHA-256 `9F95A1B05C3817BDFB26BB367B7BB493BD7EA90DC34E48E2E7FB885A6917618C`), arm64 split **9.8 MB**, and Play AAB **45.3 MB** (per-device download is roughly 10 MB). The previous 123 MB APK was the same app with ~140 MB unstripped `libflutter.so` per ABI. Hosted Supabase migration `20261117110000_initial_schema.sql` was pushed successfully; local and remote migration history match, and the `user_profiles` goal columns plus `weight_entries.updated_at` were verified. The packaged APK exposes `drawable/ic_stat_fitgo`, so the notification icon survives release resource optimization, and secure-storage preferences are excluded from Android backup. The new white-on-orange mark was checked at 40/64/76 px and in the loading state, and the Android 12+ splash theme compiles. iOS runtime verification, a real-key Gemini smoke test, and real-device notification timing still require physical devices. The APK and AAB are debug-signed until `android/key.properties` and a release keystore are supplied.

---

## How to use this document

This file is the single source of truth for the upgrade. It is split into **phases** so the app never becomes half-redesigned and unshippable.

Each phase has:

- **Goal** — what the phase delivers.
- **Tasks** — concrete code/file changes.
- **Acceptance criteria** — when the phase is done.
- **Dependencies** — what must exist before starting.

**Priority legend**

| Tag | Meaning |
|---|---|
| **P0** | Blocks an iOS/App Store release or causes data loss/crash |
| **P1** | Major UX/feature improvement; required for the 3.0 vision |
| **P2** | Polish, growth, and post-launch improvements |

**Effort legend**

| Tag | Approx. effort (1 developer) |
|---|---|
| **S** | 1–3 days |
| **M** | 1–2 weeks |
| **L** | 3–6 weeks |
| **XL** | 6+ weeks / native work |

> **Golden rule:** Finish Phase 0 before building widgets, Live Activities, or a Watch app. Those features are worthless if login, notifications, HealthKit permissions, and TestFlight are not already solid.

---

## 1. Executive summary

FitGo already has an unusually strong feature set for a Flutter fitness app: weekly calorie budgeting, fasting, water, steps, exercise, sleep, weight, analytics, offline Hive storage, and Supabase sync.

The upgrade has three tracks:

1. **iOS compatibility** — make the existing app actually work on iPhone: OAuth deep links, Apple Sign In, notifications, permissions, privacy manifest, App Store requirements.
2. **UI/UX refresh** — replace the current “dark dashboard with many cards” with a calmer, premium, adaptive design system that feels intentional on both iOS and Android.
3. **Apple-native differentiation** — HealthKit, widgets, Live Activities, Siri shortcuts, and optionally Apple Watch. These are what make an app feel like an iPhone app rather than a Flutter app.

### Recommended release train

| Release | Contents | Target |
|---|---|---|
| **2.1 — iOS Foundation** | Phase 0 + critical auth/notification fixes | 2–3 weeks |
| **2.2 — New Look** | Phase 1 + Phase 2 screen refresh | 4–6 weeks |
| **2.3 — Apple Health** | HealthKit, widgets, Live Activity, Siri | 4–6 weeks |
| **3.0 — App Store** | Phase 4 + Phase 5 + Phase 6 launch | 3–4 weeks |

A solo developer should plan **4–6 months** for the full roadmap. A small team can compress this to **2–3 months** by parallelising native iOS work and Flutter UI work.

> **Release mechanics:** the first App Store version must use a **manual release** after review. Phased release is available for updates, not for the first version. Do not mark “phased release enabled” as a 3.0 launch requirement.

### The five decisions that matter most

1. **Allow guest/local-only use.** The current `_AuthGate` requires cloud login even though the app is offline-first. Apple users often reject forced sign-up. Let people use FitGo locally, then offer sync later.
2. **Add Sign in with Apple before Google.** App Store guideline 4.8 requires an equivalent Apple option when Google sign-in is present.
3. **Use a real cross-platform notification layer.** `NotificationService` currently returns `false` on every non-Android platform.
4. **Add HealthKit.** Manual step/sleep/weight entry is the biggest gap for Apple users.
5. **Build a design system, not a pile of one-off cards.** There are currently **129 hard-coded colours** and **69 `BorderRadius.circular` calls** across `lib/`; that is why screens feel inconsistent.

---

## 2. Current state audit

### 2.1 What already works well

- **Offline-first Hive storage** with Supabase backup.
- **Weekly calorie budget** and redistribution logic.
- **Fasting timer based on timestamps**, so it survives app kills.
- **Rich analytics** (consistency score, cumulative trend, heatmap, insights, projection).
- **Dark/light themes** and a recognisable ember/amber palette.
- **Optional AI coach** with a user-supplied Gemini key, account-scoped history, and automatic model fallback.
- **Feature depth**: water, steps, exercise, sleep, weight, macros, monthly calorie guard.
- **Flutter 3.41 / Dart 3.11** is modern enough for the current plugin ecosystem.

### 2.2 iOS blockers (must fix)

| # | Issue | Where | Impact | Fix | Phase |
|---|---|---|---|---|---|
| 1 | Notifications are Android-only (`Platform.isAndroid`) | `lib/services/notification_service.dart` | No fasting/water/monthly reminders on iPhone | Cross-platform notification service (plugin or Swift bridge) | 0 |
| 2 | No `CFBundleURLTypes` URL scheme | `ios/Runner/Info.plist` | Google OAuth cannot return to the app | Add `com.fitgo.fitgo` URL scheme; allow it in Supabase | 0 |
| 3 | No Sign in with Apple | `auth_screen.dart`, `SupabaseService` | App Store rejection risk under guideline 4.8 | Add native Apple button + `signInWithIdToken` | 0 |
| 4 | No HealthKit usage strings or entitlement | iOS project | HealthKit impossible; cannot read steps/sleep/weight | Add `Info.plist` keys + HealthKit capability | 0 / 3 |
| 5 | No privacy manifest | `ios/Runner/` | App Store upload warnings/rejection | Add `PrivacyInfo.xcprivacy` | 0 |
| 6 | No entitlements file | iOS project | Apple Sign In, HealthKit, push, widgets unavailable | Add `Runner.entitlements` + capabilities | 0 |
| 7 | Old launch screen / white flash | `LaunchScreen.storyboard` | Looks unfinished on iPhone, bad dark-mode launch | Branded light/dark launch screen | 1 |
| 8 | iPhone supports landscape | `Info.plist` | Layouts are phone-portrait-first and break in landscape | Portrait-only on iPhone, all orientations on iPad | 0 |
| 9 | No localisation delegates/locales | `MaterialApp` in `app.dart` | Date pickers, units, RTL, and system language are English-only | Add `flutter_localizations` + ARB | 1 |
| 10 | Theme only light/dark, no system | `theme_provider.dart` | iPhone users expect automatic appearance | Add `ThemeMode.system` | 1 |
| 11 | Material navigation/controls on iOS | `app.dart`, screens | Feels like an Android app on iPhone | Adaptive navigation, sheets, pickers, transitions | 1 / 2 |
| 12 | No account deletion | `profile_screen.dart` | App Store rejection under 5.1.1(v) | In-app delete account flow plus server-side Apple token revocation | 4 |
| 13 | No App Store metadata/privacy policy/support URL | repo | Cannot submit | Phase 6 checklist | 6 |
| 14 | No macOS build/CI/TestFlight pipeline | repo | No way to ship iOS from Windows | macOS CI + fastlane/Xcode Cloud | 0 |
| 15 | Only one smoke test | `test/widget_test.dart` | High regression risk during redesign | Unit/widget/golden/integration tests | 5 |
| 16 | `withOpacity` / raw colours everywhere | `lib/` | Deprecated APIs, inconsistent theming | Semantic tokens + `withValues` | 1 |
| 17 | No iPad/responsive layout | all screens | Stretched phone UI on iPad | Breakpoints, rail/sidebar, max-width content | 1 / 2 |
| 18 | Manual steps/sleep/weight only | providers/screens | Apple users expect HealthKit | HealthKit read/write + fallback | 3 |
| 19 | No widgets/Live Activity/Siri | none | Misses the best Apple differentiators | Phase 3 | 3 |
| 20 | No in-app “rate/support/legal” links | profile | Poor App Store hygiene | Settings rows + `url_launcher` | 2 |

### 2.3 UI/UX audit by screen

| Screen | Current issue | Upgrade direction |
|---|---|---|
| **Auth** | Centered form, Google only, no Apple, no guest mode, “cloud sync required” contradicts offline-first | Hero brand moment, Apple first, Google/email secondary, guest mode, inline validation, legal links |
| **Onboarding** | Four dense steps, sliders, no units, no HealthKit connect, no back/skip affordance | Six light steps, wheel pickers, unit toggle, Health connect, notification opt-in, animated summary |
| **Dashboard** | Long card list, four-way focus selector at top, two app-bar icons, no greeting/large title, no quick actions | Large “Today” title, calories-left hero ring, quick-log row, grouped cards, focus mode moved into “Customise” |
| **Fasting** | Good dial, but cramped, no Live Activity, no eating-window card, no goal celebration | Bigger dial, presets, edit start/end, goal haptics, Live Activity (short fasts), lock-screen widget |
| **Nutrition** | One total number; no meal grouping; quick adds are visually heavy | Meal sections, macro ring, quick-add sheet, undo, barcode/photo hooks |
| **Water** | Glass grid is functional but flat | Animated bottle/glass fill, +250/+500, undo, hydration reminders, HealthKit write |
| **Steps** | Manual entry only, source unclear | HealthKit auto-sync, source badge, manual override, weekly chart |
| **Exercise** | Dialog-based logging, dense activity list | Activity grid with icons, recent/favourites, MET preview, HealthKit workout |
| **Sleep** | Manual bedtime/wake, basic quality | HealthKit sleep stages, chart, target, manual fallback |
| **Weight** | Basic chart, kg only | kg/lb, 7-day average, range toggle, BMI, progress photos, HealthKit |
| **Analytics** | Strong features, but 54 KB single file, dense cards, no export | Split widgets, chart cards, share/export, empty states, iPad two-column |
| **Profile** | Long mixed list, no grouped settings, no delete account | iOS Settings-style groups, account header, units, notifications, health, privacy, legal |
| **Past day** | `_loadExistingData` mutates controllers during `build` | Move to `initState`/`didChangeDependencies`, add date picker, validation, undo |

### 2.4 Technical debt that affects the upgrade

- `lib/screens/home_screen.dart` is **111 KB**; `analytics_screen.dart` is **54 KB**; `profile_screen.dart` is **35 KB**. Split by feature/widget before restyling.
- No router. Navigation is scattered `Navigator.push(MaterialPageRoute(...))` calls. Adopt `go_router` in Phase 1 so deep links, notification taps, and widget taps all work.
- Sync is fire-and-forget. The local cache is now account-scoped and has an outbox, and pull-to-refresh preserves records with pending edits. Whole-row conflict resolution still needs field-level timestamps in Phase 4.
- `PastDayLogScreen` writes controller text during build. Fix immediately when touching that file.
- `ThemeModeNotifier` cannot represent “system”.
- No error boundary, no offline banner, no sync status indicator.
- No `Semantics` labels on charts or custom painters.
- No generated localisation; date/number formatting uses default locale.

### 2.5 App Store readiness gaps

- Sign in with Apple.
- In-app account deletion, including Apple token revocation for “Sign in with Apple” users.
- Privacy policy, Terms of Use, and support URL published publicly.
- HealthKit purpose strings and review notes.
- Privacy manifest and privacy nutrition labels.
- Export compliance (`ITSAppUsesNonExemptEncryption`).
- App icon without alpha, current iPhone/iPad screenshot sizes.
- TestFlight build and demo account for review.
- If FitGo Pro is added later: StoreKit 2 in-app purchase, not external payment links.

### 2.6 Review follow-ups (13 November 2026)

| Follow-up | Status | Where |
|---|---|---|
| Account-scoped local data; no cross-account upload | Done: per-account Hive namespaces + pending-edit guard | `local_storage.dart`, `local_storage_test.dart` |
| Guest data merged only with consent | Done: sign-in prompt + Profile import action | `app.dart`, `profile_screen.dart` |
| Pull-to-refresh must not overwrite unsynced edits | Done: pull-first + outbox | `local_storage.dart` |
| Same-day multi-device field merges | Open: needs event rows or field timestamps | Phase 4.2 |
| Android scheduled/reboot notification receivers | Done | `AndroidManifest.xml` |
| Google OAuth uses a Web application client | Documented | Phase 4.4 |
| Account deletion + Apple token revocation before submission | Open: backend Edge Function + UI | Phase 8.4 |
| First App Store release is manual; phased release is for updates | Corrected | Phase 10 |
| Light-theme button contrast | Done: dark text on ember + AA tests | `fitgo_theme.dart`, `theme_contrast_test.dart` |
| Health Connect parity | Planned | Phase 7.1 |
| Midnight/timezone rollover | Midnight watcher + resume check done; offset-aware storage open | Phase 8.2 |
| Private Relay emails | Documented | Phase 6.1 (Apple setup) |
| Minimum-version gating | Planned | Phase 8.2 |
| iOS edge-swipe gesture conflicts | Planned in accessibility pass | Phase 9.3 |
| Dark-mode text contrast | Documented + core token tests | Phase 9.3 |
| Saved meals in Quick Log | Planned | Phase 6.5 |

---

## 3. Product and design direction

### 3.1 Design principles

1. **Calm energy.** Keep the ember/amber brand, but use it as an accent, not a wall of gradients.
2. **One primary number per screen.** Calories left on Today; consistency score on Trends; fasting progress on Fast.
3. **Progressive disclosure.** Show the daily essentials first; move editing, history, and advanced math into sheets or detail screens.
4. **Native where it matters.** Use iOS conventions for navigation, sheets, pickers, switches, and back gestures — not a Material skin.
5. **Motion with meaning.** Animate progress and state changes; never animate just to decorate.
6. **Accessible by default.** 44×44 pt targets, dynamic type, contrast, reduced motion, screen-reader labels.
7. **Offline is a feature.** Never block the core experience on a network call.

### 3.2 Visual language

**Palette**

Keep the existing warm identity but reduce saturation on large surfaces.

| Token | Light | Dark | Use |
|---|---|---|---|
| `ember` | `#F25C2A` | `#FF7A45` | Primary action, active state |
| `emberDeep` | `#C2410C` | `#E85D04` | Pressed state, gradients |
| `amber` | `#F59E0B` | `#FFB020` | Fasting progress, highlights |
| `mint` | `#10B981` | `#34D399` | On target, success |
| `aqua` | `#0891B2` | `#22D3EE` | Water, info |
| `danger` | `#DC2626` | `#F87171` | Over budget, destructive |
| `ink` | `#0B0F1A` | — | Dark background |
| `porcelain` | — | `#FAF9F6` | Light background |
| `surface` | `#FFFFFF` | `#111827` | Cards |
| `surfaceMuted` | `#F3F1ED` | `#1A2233` | Grouped background |
| `textPrimary` | `#161A2D` | `#F8FAFC` | Main text |
| `textSecondary` | `#667085` | `#94A3B8` | Supporting text |
| `border` | `#E7E5E4` | `#273244` | 1 px card borders |

> Do not use pure black (`#000000`) or pure white (`#FFFFFF`) for large backgrounds. Tonal surfaces look more premium and reduce eye strain.

**Typography**

- iOS: system San Francisco (Flutter’s Cupertino typography) for a native feel.
- Android: bundle **Inter** or **Manrope** for a consistent brand voice.
- Use **tabular figures** for calories, timers, and charts.

| Style | Size / line height | Weight | Use |
|---|---|---|---|
| Display | 34 / 40 | 700 | Hero numbers |
| Title 1 | 28 / 34 | 700 | Screen title |
| Title 2 | 22 / 28 | 700 | Section title |
| Title 3 | 20 / 26 | 600 | Card title |
| Headline | 17 / 22 | 600 | List row title |
| Body | 17 / 24 | 400 | Main copy |
| Callout | 16 / 22 | 500 | Buttons |
| Subhead | 15 / 20 | 400 | Secondary copy |
| Footnote | 13 / 18 | 400 | Captions |
| Caption | 12 / 16 | 500 | Labels |

**Spacing, radius, elevation**

- Spacing scale: `4, 8, 12, 16, 20, 24, 32, 40`.
- Radius scale: `12` (inputs), `16` (small cards), `20` (cards), `24` (sheets), `28` (hero).
- Elevation: avoid heavy shadows. Use a 1 px border plus a soft `0 8 24 rgba(15, 23, 42, 0.06)` shadow in light mode; no shadow in dark mode.
- Blur: reserve `BackdropFilter` for the tab bar and modal headers, not every card.

**Motion**

| Interaction | Duration | Curve |
|---|---|---|
| Button press | 120 ms | `easeOut` |
| Card expand | 220 ms | `easeOutCubic` |
| Page transition | 300 ms | platform default |
| Progress ring | 600 ms | `easeOutCubic` |
| Goal celebration | 900 ms | spring / `elasticOut` |

Respect `MediaQuery.disableAnimations` and reduce durations to near-zero when enabled.

### 3.3 iOS vs Android adaptation matrix

| Element | iOS | Android |
|---|---|---|
| Bottom navigation | `CupertinoTabBar` with SF-style icons | `NavigationBar` with Material icons |
| Page transition | Cupertino slide + swipe back | Material zoom/fade + predictive back |
| Scroll physics | `BouncingScrollPhysics` | `ClampingScrollPhysics` |
| Pull to refresh | `CupertinoSliverRefreshControl` | `RefreshIndicator` |
| Date/time picker | `CupertinoDatePicker` / wheel | `showDatePicker` / `showTimePicker` |
| Dialogs | `CupertinoAlertDialog` | `AlertDialog` |
| Action menu | `CupertinoActionSheet` | `showModalBottomSheet` |
| Switch | `CupertinoSwitch` | Material `Switch` |
| Text field | iOS-style filled field, clear button | Material outlined/filled |
| Haptics | light impact on selection, success notification on goal | same API, platform-tuned |
| Typography | San Francisco | Inter/Manrope |
| Status bar | light/dark content via `AnnotatedRegion` | same |

### 3.4 Proposed information architecture

Current: **2 tabs** (Dashboard, Analytics) + profile/history icons in the app bar.

Proposed: **3 tabs + centre quick-log action**.

```
┌─────────────────────────────────────┐
│  Today        Trends        Profile │
│                                     │
│              [+ Log]                │
└─────────────────────────────────────┘
```

- **Today** — greeting, date, streak, calories-left hero, quick actions, fasting, water, steps, activity, sleep, weight.
- **Trends** — consistency, weekly/monthly/yearly charts, insights, projection, export.
- **Profile** — account, goals, units, notifications, Health, appearance, privacy, legal.
- **+ Log** — opens a quick-log sheet: Meal, Water, Weight, Workout, Steps, Sleep, Start/Stop Fast.
- **AI coach** lives in **Profile → Preferences** as an optional chat with the user’s own Gemini key; there is no Today card or extra tab in 3.0.

Why not four tabs? Three tabs + a central action is easier to scan, leaves room for the quick-log button, and avoids burying Profile. iPad uses a sidebar instead of a bottom bar.

### 3.5 Component inventory to build

Create `lib/ui/` (or `lib/core/design/`) and move reusable widgets there.

| Component | Purpose |
|---|---|
| `FitGoScaffold` | Safe area, background, status bar, optional large title |
| `FitGoLargeTitle` | Collapsing/large screen title with subtitle |
| `FitGoCard` | Tonal surface, border, radius, padding, optional onTap |
| `FitGoSectionHeader` | Title + optional action (“See all”) |
| `FitGoStatTile` | Icon, value, label, trend |
| `FitGoPill` | Small status/tag chip |
| `FitGoPrimaryButton` | Filled, loading state, full-width option |
| `FitGoSegmentedControl` | Adaptive segmented control |
| `FitGoRing` | Animated progress ring with centre slot |
| `FitGoProgressBar` | Animated bar with semantic colours |
| `FitGoListRow` | Settings/detail row with leading icon, trailing value |
| `FitGoEmptyState` | Illustration/icon, title, message, action |
| `FitGoErrorState` | Retry + friendly message |
| `FitGoSkeleton` | Shimmer/placeholder card |
| `FitGoSheet` | Drag handle, safe area, detents, keyboard padding |
| `FitGoSnackBar` | Consistent floating message + undo |
| `FitGoChartCard` | Title, legend, chart, empty state, semantics |
| `FitGoSyncBadge` | Offline/syncing/synced status |

---

## 4. Phase 0 — iOS build and release foundation

**Priority:** P0  
**Effort:** M (1–2 weeks)  
**Goal:** A TestFlight-installable iOS build with working auth, notifications, permissions, and no App Store validation blockers.

### 4.1 Prerequisites

- macOS 14+ with the **current Xcode and iOS SDK required by App Store Connect** (plan for Xcode 26+).
- Apple Developer Program membership.
- CocoaPods installed (`sudo gem install cocoapods`).
- Access to the Supabase dashboard and App Store Connect.
- A real iPhone for final testing (simulator is not enough for HealthKit, push, and performance).

Verify:

```bash
flutter doctor -v
flutter devices
cd ios && pod --version
```

> You cannot build or sign an iOS app on Windows. Use a Mac, a macOS CI runner, Codemagic, or Xcode Cloud. Keep the Flutter code cross-platform; only the build/signing step needs macOS.

### 4.2 Project identity and deployment target

Current bundle ID: `com.fitgo.fitgo`. Confirm it is available in your Apple Developer account, or choose a permanent reverse-DNS ID now (for example `app.fitgo.ios`). Changing it later breaks App Store records and Sign in with Apple.

Recommended settings:

| Setting | Value |
|---|---|
| Display name | `FitGo` (not `Fitgo`) |
| Bundle ID | `com.fitgo.fitgo` |
| Version | `3.0.0` |
| Build number | Increment every upload |
| Minimum iOS | **16.0** (recommended); use 15.0 only if reach is more important |
| iPhone orientations | Portrait only for v3.0 |
| iPad orientations | All |
| Status bar | Controlled by Flutter via `AnnotatedRegion` |

Update in Xcode **Runner → General → Minimum Deployments**, and in `ios/Podfile`:

```ruby
platform :ios, '16.0'
```

Also update `ios/Flutter/AppFrameworkInfo.plist` `MinimumOSVersion` to `16.0`, and the `IPHONEOS_DEPLOYMENT_TARGET` values in `ios/Runner.xcodeproj/project.pbxproj`.

> If you keep iOS 15, gate Live Activities (`iOS 16.1+`), App Intents (`iOS 16+`), and lock-screen widgets (`iOS 16+`) with availability checks.

### 4.3 `Info.plist` changes

File: `ios/Runner/Info.plist`

Add/replace the following keys. Keep the existing `CFBundleDisplayName`, `CFBundleIdentifier`, `CFBundleShortVersionString`, `CFBundleVersion`, `LSRequiresIPhoneOS`, `UILaunchStoryboardName`, and `UIApplicationSupportsIndirectInputEvents` keys.

```xml
<key>CFBundleDisplayName</key>
<string>FitGo</string>

<!-- Return path for Supabase OAuth (Google, etc.) -->
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLName</key>
    <string>com.fitgo.fitgo</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.fitgo.fitgo</string>
    </array>
  </dict>
</array>

<!-- HealthKit (add when Phase 3 starts; safe to add earlier) -->
<key>NSHealthShareUsageDescription</key>
<string>FitGo reads your steps, sleep, workouts, and weight so your daily dashboard stays accurate without manual entry.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>FitGo can save water, weight, and workouts you log to Apple Health.</string>

<!-- Motion / pedometer fallback -->
<key>NSMotionUsageDescription</key>
<string>FitGo uses motion data to count your steps and estimate activity calories.</string>

<!-- Face ID app lock (Phase 4) -->
<key>NSFaceIDUsageDescription</key>
<string>FitGo uses Face ID to protect your health data when you reopen the app.</string>

<!-- Future barcode/meal photo features -->
<key>NSCameraUsageDescription</key>
<string>FitGo uses the camera to scan food barcodes and capture meal photos.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>FitGo lets you choose a progress photo to track your journey.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>FitGo saves progress photos to your photo library.</string>

<!-- Only standard HTTPS is used -->
<key>ITSAppUsesNonExemptEncryption</key>
<false/>

<!-- Remote push (Phase 3; harmless before then) -->
<key>UIBackgroundModes</key>
<array>
  <string>remote-notification</string>
</array>

<!-- Live Activities (Phase 3; iOS 16.1+) -->
<key>NSSupportsLiveActivities</key>
<true/>
<key>NSSupportsLiveActivitiesFrequentUpdates</key>
<true/>
```

Change iPhone orientation to portrait only:

```xml
<key>UISupportedInterfaceOrientations</key>
<array>
  <string>UIInterfaceOrientationPortrait</string>
</array>
```

Keep all four orientations for `UISupportedInterfaceOrientations~ipad`.

### 4.4 OAuth deep link configuration

The Dart code already uses:

```dart
redirectTo: 'com.fitgo.fitgo://login-callback'
```

That only works if the URL scheme exists on iOS. After adding `CFBundleURLTypes`:

1. **Supabase Dashboard → Authentication → URL Configuration**
   - Add `com.fitgo.fitgo://login-callback` to **Redirect URLs**.
   - Keep your web Site URL for the web build.
2. **Google Cloud Console → APIs & Services → Credentials**
   - Create a **Web application** OAuth client. `supabase_flutter` uses the browser/authorization-code flow, so an “iOS” client is not used here.
   - Add the Supabase callback URL (`https://<project-ref>.supabase.co/auth/v1/callback`) as an authorised redirect URI.
   - Copy the Web client ID and secret into Supabase. The iOS URL scheme only returns the browser to FitGo.
3. **Supabase Dashboard → Authentication → Providers → Google**
   - Add the Google client ID and secret.
4. Test on a real device:
   - Tap “Continue with Google”.
   - Authenticate in the browser sheet.
   - Confirm the app reopens and `authStateChanges` emits a signed-in session.

`supabase_flutter` already listens for app links via `app_links`; you do **not** need to parse tokens manually. If you later adopt universal links, add an `Associated Domains` entitlement and host `apple-app-site-association` at the domain root.

### 4.5 Entitlements and capabilities

Create `ios/Runner/Runner.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.developer.applesignin</key>
  <array>
    <string>Default</string>
  </array>

  <key>com.apple.developer.healthkit</key>
  <true/>

  <!-- Add when the WidgetKit/Live Activity extension exists -->
  <key>com.apple.security.application-groups</key>
  <array>
    <string>group.com.fitgo.fitgo</string>
  </array>

  <!-- Add only if you implement push notifications -->
  <key>aps-environment</key>
  <string>development</string>

  <!-- Add only if you adopt universal links -->
  <key>com.apple.developer.associated-domains</key>
  <array>
    <string>applinks:fitgo.app</string>
  </array>
</dict>
</plist>
```

Then in Xcode:

1. Select the **Runner** target → **Signing & Capabilities**.
2. Add **Sign in with Apple**, **HealthKit**, **Push Notifications** (later), **Associated Domains** (later), and **App Groups** (later).
3. Set **Code Signing Entitlements** to `Runner/Runner.entitlements` for Debug, Release, and Profile.
4. Ensure the entitlements file is a member of the Runner target.

> The `aps-environment` value must be `production` in the App Store provisioning profile. Xcode normally manages this automatically when the Push Notifications capability is enabled. Do not hard-code it incorrectly.

### 4.6 Privacy manifest

Create `ios/Runner/PrivacyInfo.xcprivacy`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>NSPrivacyTracking</key>
  <false/>
  <key>NSPrivacyTrackingDomains</key>
  <array/>

  <key>NSPrivacyCollectedDataTypes</key>
  <array>
    <dict>
      <key>NSPrivacyCollectedDataType</key>
      <string>NSPrivacyCollectedDataTypeHealth</string>
      <key>NSPrivacyCollectedDataTypeLinked</key>
      <true/>
      <key>NSPrivacyCollectedDataTypeTracking</key>
      <false/>
      <key>NSPrivacyCollectedDataTypePurposes</key>
      <array>
        <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
      </array>
    </dict>
    <dict>
      <key>NSPrivacyCollectedDataType</key>
      <string>NSPrivacyCollectedDataTypeFitness</string>
      <key>NSPrivacyCollectedDataTypeLinked</key>
      <true/>
      <key>NSPrivacyCollectedDataTypeTracking</key>
      <false/>
      <key>NSPrivacyCollectedDataTypePurposes</key>
      <array>
        <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
      </array>
    </dict>
    <dict>
      <key>NSPrivacyCollectedDataType</key>
      <string>NSPrivacyCollectedDataTypeEmailAddress</string>
      <key>NSPrivacyCollectedDataTypeLinked</key>
      <true/>
      <key>NSPrivacyCollectedDataTypeTracking</key>
      <false/>
      <key>NSPrivacyCollectedDataTypePurposes</key>
      <array>
        <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
      </array>
    </dict>
    <dict>
      <key>NSPrivacyCollectedDataType</key>
      <string>NSPrivacyCollectedDataTypeUserID</string>
      <key>NSPrivacyCollectedDataTypeLinked</key>
      <true/>
      <key>NSPrivacyCollectedDataTypeTracking</key>
      <false/>
      <key>NSPrivacyCollectedDataTypePurposes</key>
      <array>
        <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
      </array>
    </dict>
  </array>

  <key>NSPrivacyAccessedAPITypes</key>
  <array>
    <dict>
      <key>NSPrivacyAccessedAPIType</key>
      <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
      <key>NSPrivacyAccessedAPITypeReasons</key>
      <array>
        <string>CA92.1</string>
      </array>
    </dict>
  </array>
</dict>
</plist>
```

Add it to **Runner → Build Phases → Copy Bundle Resources**.

Review the privacy manifests generated by Flutter plugins in `ios/Pods/` after `pod install`; App Store Connect aggregates them. Only declare data you actually collect. If you add Sentry/analytics, update this file and the App Privacy answers.

### 4.7 Notifications: recommended cross-platform architecture

> **Implemented (16 Nov 2026):** `NotificationService` now uses
> `flutter_local_notifications` on Android, iOS, and macOS. It handles
> permission on explicit user actions, fasting reminder series, the one-shot
> calorie guard, notification actions (`+250 ml`, `End fast`), cold-start taps,
> and deep links. The obsolete Kotlin `fitgo/notifications` channel and its
> receiver/helper files were removed to prevent duplicate alarms from older
> installs. Scheduling math is unit-tested in
> `test/notification_schedule_test.dart`.
>
> Remaining device checks: Android 13+ permission prompt, Android 12+ battery
> optimization delay (inexact scheduling may shift by a few minutes), channel
> settings, reboot rescheduling, cold-start tap, and iOS foreground/background
> delivery. Exact alarms are intentionally **not** requested; the app uses
> `inexactAllowWhileIdle` to avoid the Android 14 exact-alarm special access
> and Play policy burden.

The historical notes below describe the migration that is now complete.

#### Option A (recommended): `flutter_local_notifications`

**Why:** one Dart API for Android and iOS, correct permission handling, notification taps, actions, and scheduled notifications. It removes the need to maintain two native implementations.

Steps:

1. Add dependencies:
   ```bash
   flutter pub add flutter_local_notifications timezone flutter_timezone
   ```
2. Initialise in `main()` after Hive/Supabase:
   ```dart
   await NotificationService.init();
   ```
3. Replace the internals of `lib/services/notification_service.dart` while keeping its public methods so callers do not change.
4. Request permission **contextually**, after the onboarding “Enable reminders” step — not at app launch.
5. Schedule fasting reminders as a finite series of notifications (iOS allows a maximum of 64 pending notifications per app).
6. Schedule the monthly calorie alert with `matchDateTimeComponents: DateTimeComponents.time`.
7. Handle taps in `onDidReceiveNotificationResponse` and route to the relevant screen.
8. Add notification actions: “+250 ml” and “End fast”.

Starter implementation:

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;

    tzdata.initializeTimeZones();
    final localZone = await FlutterTimezone.getLocalTimezone();
    // flutter_timezone 4.x returns TimezoneInfo; use `.identifier` there.
    // Older versions return a String. Adjust to the installed API.
    final zoneName = localZone is String
        ? localZone
        : (localZone as dynamic).identifier as String;
    tz.setLocalLocation(tz.getLocation(zoneName));

    const android = AndroidInitializationSettings('@mipmap/launcher_icon');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: darwin),
      onDidReceiveNotificationResponse: _onTap,
    );
    _ready = true;
  }

  static Future<bool> requestPermission() async {
    await init();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (ios != null) {
      return await ios.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    }
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    return false;
  }

  static Future<void> scheduleMonthlyCalorieAlert({
    required String title,
    required String message,
    required int hour,
    required int minute,
  }) async {
    await init();
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (when.isBefore(now)) when = when.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      1001,
      title,
      message,
      when,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'calorie_guard',
          'Calorie guard',
          channelDescription: 'Daily monthly calorie budget warning',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancelMonthlyCalorieAlert() async {
    await init();
    await _plugin.cancel(1001);
  }

  static Future<void> scheduleFastingReminder({
    required int intervalMinutes,
    required int untilEpoch,
    String title = 'Drink water',
    String message = 'Stay zero-calorie until your fast ends.',
  }) async {
    await init();
    await cancelFastingReminder();

    final now = DateTime.now();
    final end = DateTime.fromMillisecondsSinceEpoch(untilEpoch);
    var next = now.add(Duration(minutes: intervalMinutes));
    var id = 2000;

    // iOS keeps at most 64 pending notifications. Cap the series.
    while (next.isBefore(end) && id < 2024) {
      await _plugin.zonedSchedule(
        id++,
        title,
        message,
        tz.TZDateTime.from(next, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'fasting_reminders',
            'Fasting reminders',
            channelDescription: 'Hydration reminders during a fast',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      next = next.add(Duration(minutes: intervalMinutes));
    }
  }

  static Future<void> cancelFastingReminder() async {
    await init();
    for (var id = 2000; id < 2024; id++) {
      await _plugin.cancel(id);
    }
  }

  static void _onTap(NotificationResponse response) {
    // Route using a global navigator key or a deep link, e.g. fitgo://fasting
  }
}
```

Notes:

- Android 13+ needs `POST_NOTIFICATIONS`; the plugin requests it.
- iOS permission is requested once; if denied, show a “Open Settings” row using `url_launcher` with `app-settings:`.
- Exact alarms on Android may require `SCHEDULE_EXACT_ALARM`; if you do not need minute precision, use `AndroidScheduleMode.inexactAllowWhileIdle` to avoid extra permissions.
- Do not schedule a repeating iOS notification shorter than 60 seconds.
- Test notification taps from a cold start, background, and foreground.

#### Option B (fast path): native Swift bridge

If you want to keep the existing Android implementation untouched, add a matching Swift handler in `AppDelegate.swift`. This is faster to ship but duplicates logic and is harder to maintain.

```swift
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    UNUserNotificationCenter.current().delegate = self

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "fitgo/notifications",
        binaryMessenger: controller.binaryMessenger
      )

      channel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "requestPermission":
          UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
          ) { granted, _ in
            DispatchQueue.main.async { result(granted) }
          }

        case "scheduleMonthlyCalorieAlert":
          let args = call.arguments as? [String: Any] ?? [:]
          self?.scheduleDaily(
            title: args["title"] as? String ?? "FitGo",
            body: args["message"] as? String ?? "",
            hour: args["hour"] as? Int ?? 21,
            minute: args["minute"] as? Int ?? 0
          )
          result(true)

        case "cancelMonthlyCalorieAlert":
          UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["monthly-calorie-alert"])
          result(true)

        case "showMonthlyCalorieAlertNow", "showFastingReminderNow":
          let args = call.arguments as? [String: Any] ?? [:]
          self?.showNow(
            title: args["title"] as? String ?? "FitGo",
            body: args["message"] as? String ?? ""
          )
          result(true)

        case "scheduleFastingReminder":
          let args = call.arguments as? [String: Any] ?? [:]
          self?.scheduleFasting(
            intervalMinutes: args["intervalMinutes"] as? Int ?? 60,
            untilEpoch: args["untilEpoch"] as? Int ?? 0
          )
          result(true)

        case "cancelFastingReminder":
          UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["fasting-reminder"])
          result(true)

        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func scheduleDaily(title: String, body: String, hour: Int, minute: Int) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default

    var components = DateComponents()
    components.hour = hour
    components.minute = minute
    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
    let request = UNNotificationRequest(
      identifier: "monthly-calorie-alert",
      content: content,
      trigger: trigger
    )
    UNUserNotificationCenter.current().add(request)
  }

  private func scheduleFasting(intervalMinutes: Int, untilEpoch: Int) {
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: ["fasting-reminder"])

    let end = Date(timeIntervalSince1970: TimeInterval(untilEpoch) / 1000)
    let interval = TimeInterval(max(intervalMinutes, 60) * 60)
    var fireDate = Date().addingTimeInterval(interval)
    var index = 0

    while fireDate < end && index < 24 {
      let content = UNMutableNotificationContent()
      content.title = "Drink water"
      content.body = "Stay zero-calorie until your fast ends."
      content.sound = .default

      let trigger = UNTimeIntervalNotificationTrigger(
        timeInterval: fireDate.timeIntervalSinceNow,
        repeats: false
      )
      let request = UNNotificationRequest(
        identifier: "fasting-reminder-\(index)",
        content: content,
        trigger: trigger
      )
      center.add(request)
      fireDate = fireDate.addingTimeInterval(interval)
      index += 1
    }
  }

  private func showNow(title: String, body: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    let request = UNNotificationRequest(
      identifier: UUID().uuidString,
      content: content,
      trigger: nil
    )
    UNUserNotificationCenter.current().add(request)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound, .badge])
  }
}
```

> Recommendation: ship Option A. Keep Option B only as a temporary fallback if the plugin migration threatens the release date.

### 4.8 Launch screen and app icon

> **Implemented (17 Nov 2026):** FitGo now uses one white-on-orange flame mark
> everywhere. The canonical asset is `assets/images/logo.png` (1024×1024). It
> drives the Android/iOS launcher icon, the dark native splash, the in-app
> `FitGoMark` (auth, onboarding, navigation), and the `FitGoLoading` spinner
> used for content loading.
>
> - Android starts on `#03071E` with the rounded 360 px
>   `drawable-nodpi/splash_logo.png` centred by both `launch_background.xml`
>   variants. Android 12+ uses matching `values-v31` / `values-night-v31`
>   themes so the system splash keeps the dark background and orange icon
>   instead of falling back to a white window. Both `LaunchTheme` and
>   `NormalTheme` use `#03071E` on every API level, so Flutter's first frame
>   cannot expose a white window either.
> - iOS uses a dark `#03071E` storyboard background with `LaunchImage` at
>   1x/2x/3x (120 pt). The old white flash is gone.
> - Launcher icons were regenerated with `flutter_launcher_icons`
>   (`remove_alpha_ios: true`); the iOS app-icon files are RGB so App Store
>   validation does not see an alpha channel.
> - Do not animate the native launch screen; iOS does not allow it. The branded
>   Flutter loader handles in-app waiting states instead.
> - Optional follow-up: add iOS 18+ dark/tinted app-icon variants.

The original launch screen was white with a centred `LaunchImage`, which
produced a bright flash on a dark-themed app.

```yaml
flutter_launcher_icons:
  android: "launcher_icon"
  ios: true
  image_path: "assets/images/logo.png"
  remove_alpha_ios: true
  min_sdk_android: 21
```

Then:

```bash
dart run flutter_launcher_icons
```

### 4.9 Build and TestFlight pipeline

Local release build:

```bash
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter build ipa --release
```

Upload with Xcode Organizer or Transporter. For CI:

- **Codemagic** or **GitHub Actions `macos-latest`**.
- Use an App Store Connect API key and `fastlane` (`match` for certificates, `pilot` for TestFlight).
- Cache Flutter SDK, Pub cache, CocoaPods.
- Run `flutter analyze`, `flutter test`, then `flutter build ipa`.
- Upload to TestFlight on every `main` build; tag releases.

Recommended `fastlane` lanes:

```ruby
lane :beta do
  setup_ci
  match(type: "appstore")
  build_app(scheme: "Runner", export_method: "app-store")
  upload_to_testflight(skip_waiting_for_build_processing: true)
end
```

### 4.9a Android distribution artifacts

> **Implemented (17 Nov 2026):** `android/app/build.gradle.kts` no longer keeps
> debug symbols in release native libraries. That setting was inflating every
> `libflutter.so` to ~140 MB. Release builds now strip symbols while keeping
> `useLegacyPackaging = true`, so native libraries stay compressed and the
> download stays small.

Version `3.0.0+3`, `minSdk 24` (Android 7.0), `targetSdk 36`:

| Artifact | Purpose | Size |
|---|---|---|
| `app-release.apk` | Universal sideload: arm64-v8a, armeabi-v7a, x86_64 | 26.7 MB |
| `app-arm64-v8a-release.apk` | Modern 64-bit phones | 9.8 MB |
| `app-armeabi-v7a-release.apk` | Older 32-bit phones | 9.5 MB |
| `app-x86_64-release.apk` | Emulators / Chromebooks | 10.0 MB |
| `app-release.aab` | Play Store upload; Play delivers per-device splits | 45.3 MB |

Build commands:

```bash
# Universal APK for direct sharing/sideloading
flutter build apk --release

# Modern-device and legacy splits
flutter build apk --release --split-per-abi

# Play Store
flutter build appbundle --release
```

SHA-256:

- Universal APK: `9F95A1B05C3817BDFB26BB367B7BB493BD7EA90DC34E48E2E7FB885A6917618C`
- arm64 APK: `46CAE6003D2A9D1883FBAB99FE59887D04166BA820DDCD8AA0D3D2B47789A7A1`
- armeabi-v7a APK: `8D3D13035CE61EEB5D3B2CF90E8F2A855C4941AF1467E34FB464C6F231979CDA`
- x86_64 APK: `E9A88CED440D6ADC7618FBFC0DF09CD1D2C18CE914DD4CDC0DC405386625B5FF`
- AAB: `18CF798F85ED61F811C2D8ECF31A6C743AAAE979F8770FADE80587B20FE3B2FE`

The Play AAB is larger than a single device download because it contains every
ABI and density; Play splits it during delivery. A separate feature-reduced
“Lite” app would need its own package ID, store listing, and data plan — size
alone is solved by ABI splits and the bundle.

### 4.10 Phase 0 acceptance criteria

> **Implementation status (2026-11-13):** the code-side Phase 0 foundation is in
> place on `feature/ios-foundation`; the version is `3.0.0+3`, and `flutter
> analyze`, `flutter test`, and the Android release build pass locally.
> Cross-platform notifications, taps, cold-start payloads, and “+250 ml” /
> “End fast” actions are wired. Android now declares the plugin’s scheduled,
> action, and boot receivers. The next milestone is a TestFlight build on a real
> iPhone and iPad, including Apple sign-in, Google sign-in, password recovery,
> and reminder delivery. Those checks still require macOS, hardware, and Apple
> Developer credentials.

- [ ] `flutter build ios --release` succeeds on macOS.
- [ ] App installs on a real iPhone and an iPad.
- [ ] Email/password sign-in works.
- [ ] Password recovery email returns to the app and saves a new password.
- [ ] Google sign-in returns to the app via the custom URL scheme, using a Google **Web application** OAuth client.
- [ ] Sign in with Apple works (native button + Supabase session), including “Hide My Email”.
- [ ] Notification permission can be granted/denied, and a test notification appears.
- [ ] Fasting reminder series fires and is cancelled when the fast ends.
- [ ] Monthly calorie alert schedules at the chosen time.
- [ ] Android scheduled notifications survive a reboot and an app update.
- [ ] iPhone is portrait-only; iPad rotates cleanly.
- [ ] No App Store Connect validation warnings for privacy manifest or encryption.
- [ ] TestFlight build is installable by an external tester.
- [x] Android build still passes (`flutter build apk --release`).
- [x] Android notification receivers are declared in `AndroidManifest.xml`.
- [x] No secrets or service-role keys in the repo.

---

## 5. Phase 1 — Design system v2 and adaptive shell

**Priority:** P0/P1  
**Effort:** M (2–3 weeks)  
**Goal:** One theme, one component library, and a navigation shell that adapts to iPhone, iPad, and Android — before individual screens are redesigned.

### 5.1 Create the token layer

Add:

```
lib/ui/theme/fitgo_tokens.dart
lib/ui/theme/fitgo_typography.dart
lib/ui/theme/fitgo_theme.dart
lib/ui/components/...
lib/ui/adaptive/...
```

`FitGoTokens` is a `ThemeExtension` so widgets can read semantic colours without hard-coding hex values.

```dart
import 'package:flutter/material.dart';

@immutable
class FitGoTokens extends ThemeExtension<FitGoTokens> {
  const FitGoTokens({
    required this.ember,
    required this.emberDeep,
    required this.amber,
    required this.mint,
    required this.aqua,
    required this.danger,
    required this.surface,
    required this.surfaceMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.shadow,
    required this.cardRadius,
    required this.sheetRadius,
  });

  final Color ember;
  final Color emberDeep;
  final Color amber;
  final Color mint;
  final Color aqua;
  final Color danger;
  final Color surface;
  final Color surfaceMuted;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color shadow;
  final double cardRadius;
  final double sheetRadius;

  @override
  FitGoTokens copyWith({
    Color? ember,
    Color? emberDeep,
    Color? amber,
    Color? mint,
    Color? aqua,
    Color? danger,
    Color? surface,
    Color? surfaceMuted,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? shadow,
    double? cardRadius,
    double? sheetRadius,
  }) {
    return FitGoTokens(
      ember: ember ?? this.ember,
      emberDeep: emberDeep ?? this.emberDeep,
      amber: amber ?? this.amber,
      mint: mint ?? this.mint,
      aqua: aqua ?? this.aqua,
      danger: danger ?? this.danger,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      shadow: shadow ?? this.shadow,
      cardRadius: cardRadius ?? this.cardRadius,
      sheetRadius: sheetRadius ?? this.sheetRadius,
    );
  }

  @override
  FitGoTokens lerp(ThemeExtension<FitGoTokens>? other, double t) {
    if (other is! FitGoTokens) return this;
    return FitGoTokens(
      ember: Color.lerp(ember, other.ember, t)!,
      emberDeep: Color.lerp(emberDeep, other.emberDeep, t)!,
      amber: Color.lerp(amber, other.amber, t)!,
      mint: Color.lerp(mint, other.mint, t)!,
      aqua: Color.lerp(aqua, other.aqua, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      cardRadius: cardRadius,
      sheetRadius: sheetRadius,
    );
  }
}

extension FitGoTokensX on BuildContext {
  FitGoTokens get tokens => Theme.of(this).extension<FitGoTokens>()!;
}
```

### 5.2 Rebuild `ThemeData` around explicit tokens

In `lib/core/theme.dart` (or the new `fitgo_theme.dart`):

- Use an explicit `ColorScheme` instead of only `colorSchemeSeed`.
- Define typography, buttons, cards, inputs, chips, switches, segmented buttons, navigation bars, bottom sheets, snack bars, dividers, and page transitions.
- Remove `InkSparkle`/ripple on iOS by setting `splashFactory: NoSplash.splashFactory` for iOS, or keep a subtle `InkRipple` on Android.
- Add `FitGoTokens` as an extension for both light and dark themes.

Excerpt:

```dart
static ThemeData get light {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFFF25C2A),
    onPrimary: Colors.white,
    secondary: Color(0xFFF59E0B),
    onSecondary: Color(0xFF1C1917),
    error: Color(0xFFDC2626),
    onError: Colors.white,
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF161A2D),
    // ...fill all required M3 roles
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFFAF9F6),
    fontFamily: null, // iOS uses San Francisco via Cupertino typography
    extensions: const [
      FitGoTokens(
        ember: Color(0xFFF25C2A),
        emberDeep: Color(0xFFC2410C),
        amber: Color(0xFFF59E0B),
        mint: Color(0xFF10B981),
        aqua: Color(0xFF0891B2),
        danger: Color(0xFFDC2626),
        surface: Colors.white,
        surfaceMuted: Color(0xFFF3F1ED),
        textPrimary: Color(0xFF161A2D),
        textSecondary: Color(0xFF667085),
        border: Color(0xFFE7E5E4),
        shadow: Color(0x0F0F172A),
        cardRadius: 20,
        sheetRadius: 28,
      ),
    ],
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE7E5E4)),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
      },
    ),
  );
}
```

### 5.3 Typography

- iOS: let Flutter use the Cupertino text theme (San Francisco). Do not bundle SF Pro; Apple’s licence does not allow redistributing it.
- Android: bundle a variable font such as **Inter** or **Manrope** in `assets/fonts/`, declare it in `pubspec.yaml`, and set `fontFamily` in the Android theme only.
- Use `FontFeature.tabularFigures()` for all numeric displays (calories, timer, weight, steps).
- Define a `TextTheme` scale once and use `theme.textTheme.*` everywhere. Stop writing `TextStyle(fontSize: 12)` in screens.

### 5.4 Adaptive navigation shell

Replace the current `_MainShell` in `lib/app.dart` with an adaptive shell that preserves tab state.

```dart
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _pages = [
    TodayScreen(),
    TrendsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final isIOS = platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    final content = IndexedStack(index: _index, children: _pages);

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: FitGoMark(size: 36),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.today_outlined),
                  selectedIcon: Icon(Icons.today),
                  label: Text('Today'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.insights_outlined),
                  selectedIcon: Icon(Icons.insights),
                  label: Text('Trends'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: Text('Profile'),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Scaffold(
      body: content,
      floatingActionButton: FloatingActionButton(
        onPressed: () => showQuickLogSheet(context),
        tooltip: 'Log',
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: isIOS
          ? CupertinoTabBar(
              currentIndex: _index,
              onTap: (i) => setState(() => _index = i),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.house),
                  activeIcon: Icon(CupertinoIcons.house_fill),
                  label: 'Today',
                ),
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.chart_bar),
                  activeIcon: Icon(CupertinoIcons.chart_bar_fill),
                  label: 'Trends',
                ),
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.person),
                  activeIcon: Icon(CupertinoIcons.person_fill),
                  label: 'Profile',
                ),
              ],
            )
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.today_outlined),
                  selectedIcon: Icon(Icons.today),
                  label: 'Today',
                ),
                NavigationDestination(
                  icon: Icon(Icons.insights_outlined),
                  selectedIcon: Icon(Icons.insights),
                  label: 'Trends',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
    );
  }
}
```

Add `go_router` in this phase so notification taps and widget deep links can navigate:

```bash
flutter pub add go_router
```

Routes:

```
/                 → Today
/trends           → Trends
/profile          → Profile
/profile/settings → Settings
/log              → Quick log (sheet route or full screen on iPad)
/fast             → Fasting detail
/food             → Nutrition detail
```

### 5.5 Platform behaviours

**Scroll physics**

```dart
class FitGoScrollBehavior extends MaterialScrollBehavior {
  const FitGoScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return switch (Theme.of(context).platform) {
      TargetPlatform.iOS || TargetPlatform.macOS =>
        const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      _ => super.getScrollPhysics(context),
    };
  }
}
```

Set `scrollBehavior: const FitGoScrollBehavior()` on `MaterialApp`.

**Status bar**

Use an `AnnotatedRegion<SystemUiOverlayStyle>` at the root of each scaffold, or set `appBarTheme.systemOverlayStyle`. In dark mode use light icons; in light mode use dark icons. On iOS, set both `statusBarBrightness` and `statusBarIconBrightness`.

**Haptics**

Create `lib/ui/haptics.dart`:

```dart
import 'package:flutter/services.dart';

class FitGoHaptics {
  static Future<void> select() => HapticFeedback.selectionClick();
  static Future<void> impact() => HapticFeedback.lightImpact();
  static Future<void> success() => HapticFeedback.mediumImpact();
  static Future<void> warning() => HapticFeedback.heavyImpact();
}
```

Call `select()` on segmented control changes, `impact()` on quick-add, `success()` when a goal is reached.

### 5.6 Theme mode: add System

Current provider only supports light/dark and defaults to dark. Add `ThemeMode.system` and migrate the stored value.

```dart
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final stored = ref.read(localStorageProvider).getThemeModeKey();
    return switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  void setMode(ThemeMode mode) {
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    ref.read(localStorageProvider).saveThemeModeKey(value);
    state = mode;
  }
}
```

Profile UI: a segmented control **System / Light / Dark**, with System as the default for new installs.

### 5.7 Localisation and units foundation

Add:

```yaml
dependencies:
  flutter_localizations:
    sdk: flutter
  intl: ^0.20.2
```

In `MaterialApp`:

```dart
localizationsDelegates: GlobalMaterialLocalizations.delegates,
supportedLocales: const [
  Locale('en'),
  Locale('hi'),
  Locale('es'),
],
```

Create `l10n.yaml` and `lib/l10n/app_en.arb`; run `flutter gen-l10n`. Move all user-facing strings out of widgets over time. For v3.0, English is acceptable, but the infrastructure must exist so date pickers, plurals, and RTL work.

Add a unit system:

```dart
enum UnitSystem { metric, imperial }

extension UnitSystemX on UnitSystem {
  String get weightLabel => this == UnitSystem.metric ? 'kg' : 'lb';
  String get volumeLabel => this == UnitSystem.metric ? 'ml' : 'fl oz';

  double weightFromKg(double kg) =>
      this == UnitSystem.metric ? kg : kg * 2.2046226218;

  double weightToKg(double value) =>
      this == UnitSystem.metric ? value : value / 2.2046226218;

  double volumeFromMl(double ml) =>
      this == UnitSystem.metric ? ml : ml / 29.5735;

  double volumeToMl(double value) =>
      this == UnitSystem.metric ? value : value * 29.5735;
}
```

Store canonical values in **kg and ml**; convert only at the UI edge. Add `unit_system` to app settings and sync it.

### 5.8 Accessibility baseline

- Minimum 44×44 pt touch targets.
- `Semantics(label: ..., value: ...)` on custom rings, dials, charts, and icon-only buttons.
- Do not rely on colour alone: pair red/green with text or icons.
- Support text scaling up to 200%; test with iOS **Larger Text** at maximum.
- Respect `MediaQuery.disableAnimations`.
- Contrast: body text ≥ 4.5:1, large text ≥ 3:1.
- Add a “Reduce Motion” toggle that shortens animations.
- Charts need a text summary for screen readers (“1,300 kcal on Tuesday, 217 over target”).

### 5.9 Phase 1 acceptance criteria

- [x] `ThemeData` has no raw colours outside `fitgo_tokens.dart` / `fitgo_theme.dart`.
- [x] All new widgets use `FitGoTokens` and `theme.textTheme`.
- [x] iOS uses Cupertino transitions and bouncing scroll physics.
- [x] Bottom navigation preserves state via `IndexedStack`.
- [x] iPad shows a navigation rail at ≥ 900 px.
- [x] Theme mode includes System and persists correctly.
- [x] Localisation delegates and `supportedLocales` are configured.
- [x] Unit conversion helpers have unit tests.
- [x] `flutter analyze` is clean.
- [x] Existing screens still compile and function after the shell swap.

---

## 6. Phase 2 — Screen-by-screen UI upgrade

**Priority:** P1  
**Effort:** L (4–6 weeks)  
**Goal:** Apply the design system to every screen without changing the underlying feature set. Each screen is a separate pull request with before/after screenshots.

> Split large files before restyling:
>
> - `home_screen.dart` → `lib/features/today/widgets/...`
> - `analytics_screen.dart` → `lib/features/trends/widgets/...`
> - `profile_screen.dart` → `lib/features/profile/widgets/...`
> - `onboarding_screen.dart` → `lib/features/onboarding/steps/...`
>
> Keep the existing providers and models; this is a UI refactor, not a rewrite.

### 6.1 Auth screen

**Now:** centred logo/form, Google only, no Apple, no guest mode, “cloud sync is required” message.

**Upgrade:**

- Full-bleed warm gradient or subtle brand texture; logo at top.
- Headline: “Your day, in balance.” Subhead: “Calories, fasting, water, sleep, and progress — in one calm place.”
- **Sign in with Apple** button first on iOS (official button style, 50 pt height, 12 pt radius).
- **Continue with Google** second.
- **Continue with email** expands the email/password form (progressive disclosure).
- **Continue without an account** link → local-only mode. Show a sync banner on Today: “Back up your progress” with a sign-in action.
- Inline validation, password visibility toggle, autofill hints:
  ```dart
  autofillHints: const [AutofillHints.email],
  keyboardType: TextInputType.emailAddress,
  textInputAction: TextInputAction.next,
  ```
- Legal footer: “By continuing you agree to our Terms and Privacy Policy.”
- Add “Forgot password?” as a text button; show a success state instead of a snackbar only.
- Add loading state with a disabled button and spinner; prevent double submission.

**Code changes:**

- `lib/screens/auth_screen.dart`: rewrite layout; split `_EmailForm`, `_SocialButtons`, `_LegalFooter`.
- `lib/services/supabase_service.dart`: add Apple sign-in.
- `lib/app.dart`: `_AuthGate` should allow a local profile without a Supabase session.
- Add `sign_in_with_apple` and `crypto` dependencies.

**Sign in with Apple implementation:**

```dart
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<AuthResponse> signInWithApple() async {
  final rawNonce = _generateNonce();
  final nonce = sha256.convert(utf8.encode(rawNonce)).toString();

  final credential = await SignInWithApple.getAppleIDCredential(
    scopes: [
      AppleIDAuthorizationScopes.email,
      AppleIDAuthorizationScopes.fullName,
    ],
    nonce: nonce,
  );

  final idToken = credential.identityToken;
  if (idToken == null) {
    throw const AuthException('Apple did not return an identity token.');
  }

  return Supabase.instance.client.auth.signInWithIdToken(
    provider: OAuthProvider.apple,
    idToken: idToken,
    nonce: rawNonce,
  );
}

String _generateNonce([int length = 32]) {
  const chars =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
  final random = Random.secure();
  return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
}
```

Supabase setup:

1. **Apple Developer → Certificates, Identifiers & Profiles → Keys** → create a Sign in with Apple key.
2. **Supabase → Authentication → Providers → Apple** → add Service ID, Team ID, Key ID, private key.
3. Add the iOS bundle ID (`com.fitgo.fitgo`) to the authorised client IDs.
4. Add `com.fitgo.fitgo://login-callback` to redirect URLs.
5. Test on a real device; Apple only returns name/email on first authorisation, so save them to the profile immediately.
6. **Private Relay email:** if the user chooses “Hide My Email”, the account email ends in `@privaterelay.appleid.com`. Register the outbound email domain (SPF/DKIM) under Apple Developer → Sign in with Apple → Email Sources before sending password resets, exports, or account emails through Supabase. Otherwise those messages silently bounce. Never reject relay addresses.

**Acceptance:** Apple, Google, email, and guest paths all work; no dead ends; VoiceOver labels are present; buttons meet 44 pt targets.

> **Status (2026-11-13):** auth layout, Apple-first ordering, progressive
> email form, guest/local-only entry, inline reset success, legal footer,
> autofill hints, and the Today backup banner are implemented. Published
> Terms/Privacy URLs and a real-device VoiceOver pass remain.

### 6.2 Onboarding

**Now:** four dense steps, sliders for height/weight, no units, no HealthKit, no notification opt-in.

**Upgrade to six light steps:**

1. **Welcome** — brand, one-line value proposition, “Get started” and “I already have an account”.
2. **About you** — gender (or “prefer not to say”), date of birth, height/weight with a **unit toggle** (cm/kg ↔ ft/in/lb). Use `CupertinoPicker`/wheel or large numeric fields, not tiny sliders.
3. **Your goal** — lose / maintain / gain, target weight, pace (gentle/steady/ambitious). Show a live TDEE and weekly budget preview.
4. **Activity level** — sedentary/light/moderate/active; explain how it changes calories.
5. **Connect Apple Health** (iOS only) — “Read steps, sleep, workouts, and weight” with a clear “Not now”.
6. **Reminders** — fasting, water, weekly recap; request notification permission only after the user taps “Enable”.

**UX details:**

- Progress dots at the top; back button; “Skip for now” where safe.
- Persist a draft so an interrupted onboarding resumes.
- Animated transitions between steps (`AnimatedSwitcher` or `PageView`).
- Final summary card: “Your daily target is 2,050 kcal” with a “Start using FitGo” button.
- No forced account creation.

**Code changes:**

- Split into `lib/features/onboarding/onboarding_controller.dart` and `steps/*.dart`.
- Replace `_weight`/`_height` sliders with unit-aware fields.
- Add `HealthService.requestPermissions()` call (Phase 3) behind an iOS check.
- Add `NotificationService.requestPermission()` on the reminders step.
- Save via `profileProvider.saveProfile`.

### 6.3 Today dashboard

> **Implemented (14 Nov 2026):** the focus selector is gone. Today is now a
> single scrollable logbook: sync pill, one calorie hero, flat **Meals /
> Fasting / Water** rows, and a compact **Health** card. Each row watches only
> its own slice of state, and the fasting countdown rebuilds at minute
> granularity rather than every tick. Meal, fasting, activity, sleep, and
> weight entry all happen in one focused sheet each.

**Now:** focus selector, overview strip, then a long list of cards; two app-bar icons; no greeting or quick actions.

**Upgrade:**

```
Good morning, Mayuresh
Tuesday, 13 November                         🔥 12-day streak

┌─────────────────────────────────────┐
│  Calories left                      │
│         1,420 kcal                  │
│  ███████████░░░░░  62%              │
│  Eaten 1,300 · Burned 315 · Net 985 │
└─────────────────────────────────────┘

[ + Meal ] [ + Water ] [ + Weight ] [ + Workout ]

Weekly plan card
Fasting card
Water / Steps / Activity / Sleep / Weight
```

- Use a `CustomScrollView` with `SliverAppBar.large` or a custom large title.
- One hero card: calories left, ring or bar, net breakdown.
- Quick actions row (horizontally scrollable on small phones).
- Keep the focus modes but move them into a **Customise dashboard** sheet (Auto/Fast/Food/Full), not a permanent segmented control.
- Group secondary metrics into a 2-column grid on wider phones and iPad.
- Add a sync badge: “Offline · saved locally”, “Syncing…”, “Synced”.
- Add skeleton placeholders on first load; never show a blank screen.
- Pull to refresh: sync then invalidate providers; show a subtle success/failure banner.

**Code changes:**

- Split `home_screen.dart` into `features/today/today_screen.dart` and widgets.
- Create `FitGoRing`, `QuickAction`, `MacroSummary`, `SyncBadge`.
- Use `ref.watch(provider.select(...))` to reduce rebuilds.
- Wrap charts/custom painters in `RepaintBoundary`.
- Remove the `ref.listen` snackbar from `build`; move to a dedicated listener widget or `ref.listen` inside a `ConsumerStatefulWidget` with mounted checks.

### 6.4 Fasting

**Now:** radial dial, presets, start/end chips, reminder controls, start section.

**Upgrade:**

- Make fasting a first-class screen (`/fast`) with a large dial and a clear state:
  - Not fasting: “Ready to fast” + preset chips (16:8, 18:6, 20:4, custom).
  - Fasting: elapsed, remaining, progress, expected end time.
  - Complete: “Goal reached” celebration + “End fast” / “Keep fasting”.
- Add an **eating window** card: “Your eating window is 12:00–20:00”.
- Edit start/end with a wheel picker; confirm if changing an active fast.
- Add a “Remind me every 60 min” toggle and permission prompt.
- Haptics + confetti (subtle) on goal; respect reduce motion.
- Show a 7-day fasting history strip.
- Keep timestamp-based math; do not use a background timer for correctness.

**Apple-native (Phase 3):**

- Lock-screen widget showing elapsed/remaining.
- Live Activity for short fasts or the eating window (see the 8-hour limitation in Phase 3).
- Siri: “Start a 16-hour fast in FitGo”.

**Code changes:**

- `lib/widgets/radial_dial.dart`: use tokens, animate progress with `TweenAnimationBuilder`, add `Semantics`.
- `lib/screens/home_screen.dart` `_FastingCard` → `features/fasting/widgets/fasting_card.dart`.
- Add `FastingNotificationCoordinator` that schedules/cancels reminders on start/stop.
- Add `LiveActivityService` in Phase 3.

### 6.5 Nutrition

> **Implemented (14 Nov 2026):** one meal sheet with recent meals first,
> saved meals (synced through the settings outbox), a portion stepper, manual
> name/calories, macros under **Details**, a save-to-my-meals toggle, and the
> day's meal log with delete/Undo. Recent meals stay account-local; saved
> meals survive reinstalls through cloud settings.

**Upgrade:**

- Hero: calories consumed / target, net calories, remaining.
- Macro ring or three compact bars (protein, carbs, fat) with grams and percentages.
- **Meal sections**: Breakfast, Lunch, Dinner, Snacks. Each row shows calories, time, and edit/delete.
- Quick add sheet: +100/+250/+500, custom calories, “Add meal” with macros.
- **Saved meals:** repeat a recent meal, adjust the portion, then save. This is the highest-value addition to Quick Log because most people eat the same meals weekly.
- Undo last entry via snackbar.
- Weekly coach card: “You have 5,200 kcal left this week; 1,083 kcal/day”.
- If fasting, show a non-judgemental warning before adding calories.
- Future hooks: barcode scan, food search, meal photo.

**Code changes:**

- Extend `NutritionEntry` with `mealType`, `createdAt`, `source` (manual/health/scan). This is a Hive schema change; add a migration and regenerate the adapter.
- Add `MealSection` widget and `QuickAddSheet`.
- Keep `NutritionNotifier` as the source of truth; add `addEntry`, `removeEntry`, `undoLast`.
- Add saved/recent meals with a portion multiplier; store them per account, not in the shared cache.

### 6.6 Water

> **Implemented (14 Nov 2026):** one-tap `+250 ml` from the Today row with a
> snackbar **Undo** that subtracts the same amount. The button label follows
> the selected unit system.

**Upgrade:**

- Large animated bottle or 8-glass grid with fill animation.
- Primary “+250 ml” button and secondary “+500 ml”.
- Undo last addition.
- Goal progress and “X ml to go”.
- Hydration reminder toggle (respect notification permission).
- Units: ml ↔ fl oz.
- Write to Apple Health when enabled.

**Code changes:**

- `water_provider.dart`: add `removeWater`, `undo`, `lastAddedAt`.
- `HealthService.writeWater(ml)` (Phase 3).
- Add `WaterBottle` custom painter or use a simple stacked container with `AnimatedContainer`.

### 6.7 Steps and exercise

**Steps upgrade:**

- Auto-read today’s steps from HealthKit (iOS) or the existing manual source.
- Show a source badge: “Apple Health” / “Manual”.
- Distance and calories derived from steps; show walking time.
- Manual override in a sheet; keep the last sync time.
- Weekly bar chart with target line.

**Exercise upgrade:**

- Grid of activity cards with icons, MET value, and recent/favourite ordering.
- Duration picker with quick chips (15/30/45/60 min).
- Preview estimated calories before saving.
- Save to Apple Health as a workout (write permission).
- Recent activity list with edit/delete.

**Code changes:**

- `activity_provider.dart`: add `removeActivity`, `favouritePresets`.
- `HealthService.readSteps`, `writeWorkout`.
- Split the exercise dialog into `ActivityPickerSheet`.

### 6.8 Sleep

**Upgrade:**

- Read sleep analysis from Apple Health (asleep, in bed, stages if available).
- Show bedtime, wake time, duration, and quality.
- 7-day sleep chart with target line.
- Manual fallback with wheel pickers.
- Sleep reminder notification (“Wind down in 30 minutes”).
- Avoid medical claims; use “sleep quality” as a heuristic, not a diagnosis.

**Code changes:**

- `HealthService.readSleep(start, end)`.
- Add `SleepChart` widget.
- Store `sleepSource` (health/manual) in metrics.

### 6.9 Weight

**Upgrade:**

- kg/lb toggle; store kg.
- Large current weight + 7-day moving average.
- Range toggle (1M / 3M / 6M / 1Y / All).
- BMI card with colour + category, plus a healthy-weight range.
- “Log weight” sheet with decimal keyboard and date.
- Read/write Apple Health body mass.
- Optional progress photos (camera/photo permission) — Phase 3/4.

**Code changes:**

- `weight_provider.dart`: add range filtering and moving average.
- `weight_chart.dart`: tokens, semantics, empty state, touch tooltip.
- `HealthService.readWeight`, `writeWeight`.

### 6.10 Analytics / Trends

> **Implemented (14 Nov 2026):** Trends opens on the current week with one
> intake-vs-budget bar chart and one plain-language insight. Period navigation
> covers week/month/year; the year view aggregates monthly totals and drills
> into a month. Calculations are cached per timeframe/data key, history rows
> build lazily, and tapping a day opens the meal sheet for today or the
> `/past-day?date=yyyy-MM-dd` log for an earlier day.

**Upgrade:**

- Rename tab to **Trends**.
- Header: period picker (Week/Month/Year) + previous/next arrows + “Today”.
- Consistency score card with a ring and one actionable sentence.
- Quick stats: consumed, remaining, average/day, streak.
- Cumulative trend chart with “Actual vs ideal pace” and a clear legend.
- Daily bar chart with target line and semantic colours.
- Heatmap with a legend and accessible text summary.
- Day-by-day expandable list with edit action.
- Smart insights card with 2–3 insights max, each with an action.
- Projection card with “what if” slider (optional).
- Share/export: PDF or image summary via the iOS share sheet; CSV export.
- iPad: two-column layout (charts left, insights right).

**Code changes:**

- Split `analytics_screen.dart` into `features/trends/widgets/*`.
- Add `ShareService.exportWeeklyReport()` using `share_plus` and `path_provider`.
- Add `RepaintBoundary` around each chart.
- Add empty states for new users (“Log your first day to see trends”).
- Add `Semantics` summaries for every chart.

### 6.11 Profile / Settings

> **Implemented (16 Nov 2026):** Profile is grouped into **Goals**,
> **Preferences**, **Account & Backup**, and **Help & Privacy**. Goals covers
> calorie/water/weight goals plus body measurements and the projection dialog.
> **Goal plan** asks for a target weight and target date, previews daily
> calories, water, expected pace, and the total change, and can flag a deadline
> that would require an unsafe deficit/surplus. The target date is kept as the
> user’s choice, but the calorie target is capped at a safe deficit/surplus and
> a 1,200 kcal floor; the sheet shows the earliest safe date. Water follows
> 35 ml/kg with a 1,500 ml/day floor. Saving updates the calorie, weekly, and
> water goals together; changing weight or height later recalculates the plan.
> Preferences covers System/Light/Dark, Metric/Imperial, the Monthly Calorie
> Guard, and the optional **AI coach** row (`Chat` when a key is saved, `Set up`
> otherwise); Account & Backup puts last sync, pending-change count, and
> **Retry sync** together, then guest import and sign-out; Help & Privacy
> explains sync/data handling and exposes the legal/support URLs plus the app
> version. Account deletion is still a release blocker (see section 10).

**Upgrade to iOS Settings-style groups:**

```
[Avatar]  Mayuresh
          mayuresh@example.com
          [ Sync now ]

ACCOUNT
  Personal details
  Goals & targets
  Units (Metric / Imperial)
  Apple Health
  Notifications
  Appearance (System / Light / Dark)
  AI coach (optional)
  App lock (Face ID)

DATA
  Export my data
  Sync status
  Delete account

ABOUT
  Help & support
  Privacy policy
  Terms of service
  Rate FitGo
  Version 3.0.0 (30)
```

- Use `FitGoListRow` with leading icon, title, optional subtitle, trailing value/chevron.
- Destructive actions in red, with confirmation.
- Delete account: explain what is deleted, require typing “DELETE” or Face ID, then call the backend and clear local data.
- Sign out: confirm and keep local data (or offer “Sign out and remove local data”).
- Add “Restore purchases” only if IAP exists.

**Code changes:**

- Split `profile_screen.dart` into `features/profile/profile_screen.dart` and `settings/*`.
- Add `package_info_plus`, `url_launcher`, `share_plus`, `local_auth`.
- Add `AccountDeletionService`.
- Add `AppLockService` with Face ID/Touch ID.

### 6.11a Optional AI coach (Gemini)

> **Implemented (17 Nov 2026):** FitGo has an optional, read-only AI coach in
> **Profile → Preferences → AI coach** (`Chat` when a key exists, `Set up`
> otherwise). There is no permanent Today card and no extra tab. The AI settings
> sheet and `/ai-chat` screen are the only surfaces; both use the existing
> FitGo theme and components.

**How it works**

- **Bring your own key.** The user creates a free Gemini API key in Google AI
  Studio and pastes it into the AI settings sheet. The key is validated
  locally, stored in platform secure storage (`flutter_secure_storage`,
  `first_unlock_this_device` on iOS), and namespaced by the active local
  account or guest. It is never written to Hive, Supabase, logs, analytics, or a
  FitGo backend. The UI shows only the last four characters; the user can
  replace or delete it.
- **Consent is explicit.** Nothing is sent until the key exists and the user
  accepts the AI privacy note. The note explains that FitGo data and chat go
  directly to Google under the user’s own key and terms, that free-tier prompts
  may be reviewed by Google, and that a paid key has stricter privacy.
- **Model routing.** The first 10 requests per account per calendar day
  alternate between `gemini-3.8-flash` and `gemini-3.6-flash`; after that the
  app switches to `gemini-3.5-flash-lite` (about 1,500 free requests/day).
  Failure routing is automatic: quota/rate limit, missing model, overload,
  network failure, timeout, empty answer, and unknown provider errors fall
  through to the next allowed model. An invalid key stops the request instead
  of spending other models. Local cancellation never consumes quota.
- **Read-only grounding.** `AiContextBuilder` computes the last 7/30 days of
  calories, water, steps, sleep, macros, fasting, weight change, the goal plan,
  and an authoritative `ON_TRACK` / `SLIGHTLY_OFF` / `OFF_TRACK` /
  `NOT_ENOUGH_DATA` status. The model receives this compact snapshot plus at
  most 20 recent turns; names, email, account IDs, raw notes, and keys are
  excluded. It can explain the data but cannot write to Hive, Supabase, goals,
  settings, or notifications.
- **Safety rules.** The shared system prompt requires low-judgment language,
  truthful “no data” answers, no invented numbers, no medical diagnosis, and
  referral for symptoms, pregnancy, medication, eating disorders, or self-harm.
  It forbids intake below 1,200 kcal/day, loss above 750 kcal/day, or gain above
  500 kcal/day, and redirects any goal change to Profile → Goal plan. Blocked
  or unsafe provider output becomes a normal in-chat message, not a raw error.
- **Chat behaviour.** Themed bubbles, typing indicator, stop, retry for
  network/timeout/unavailable/empty failures, clear-history confirmation,
  missing-key/consent/quota/offline/safety states, and one grouped settings
  action. The composer rotates `Summarize week`, `How is my water going?`,
  `Explain my weight trend`, and `What should I focus on?` while empty.
- **Local history.** At most 40 messages are kept per account; 20 are sent.
  History and usage counters use the account’s local Hive settings and never
  enter the sync outbox. Account switch/sign-out invalidates the AI providers;
  account deletion must call `deleteAllAiData()` (key, consent, usage, history).
- **Privacy.** Requests go from the device to
  `generativelanguage.googleapis.com` over HTTPS; there is no FitGo proxy,
  server cost, background call, or AI notification. Android backup rules
  exclude secure-storage preferences so a key cannot ride along in a device
  backup. Store data-safety answers still need to disclose the optional Google
  data flow.

**Code:** `lib/services/ai/*` (models, usage, key store, chat store, context,
prompts, Gemini client, failures), `lib/providers/ai_provider.dart`,
`lib/screens/ai_chat_screen.dart`, `lib/ui/profile/ai_settings_sheet.dart`, the
Profile row and `/ai-chat` route, and
`android/app/src/main/res/xml/{backup_rules,data_extraction_rules}.xml`.

**Verified:** 17 AI tests cover routing/fallback, quota and usage isolation,
history cap/clear, account scoping, deterministic on-track context, PII-free
prompt, provider error/safety mapping, missing key/consent, invalid-key stop,
cancel-before-request, and 320 pt/200% text layouts. Total suite: 89 passing.

**Remaining device checks:** a real-key smoke test on a physical Android and
iPhone, secure-storage persistence, keyboard/scroll feel on small screens, and
final App Store/Play data-safety wording. Real Gemini quota behaviour can vary
by account and region; the fallback path is covered with fakes.

### 6.12 Past day

> **Implemented (14 Nov 2026):** `/past-day?date=yyyy-MM-dd` opens the requested
> historical day, keeping the five quick chips and adding the deep-linked day
> when it falls outside that window. Existing values now load in `initState`
> and when a chip is tapped rather than during `build`; a full `Form` with
> inline validation is still pending.

**Upgrade:**

- Use a calendar/date picker instead of only five chips; keep the chips as quick options.
- Load existing data in `initState`/`didChangeDependencies`, not during `build`.
- Validate inputs; show inline errors.
- Save button with loading/success state; undo.
- Add “Import from Apple Health” for steps/sleep/weight.
- Delete entry with confirmation.

**Code changes:**

- Refactor `_loadExistingData` out of `build`.
- Use a `Form` with `TextFormField` validators.
- Add `storage.deleteMetrics(dateKey)` and provider invalidation.

### 6.13 Cross-cutting UI states

Every data-driven screen needs:

- **Loading:** skeleton cards, not a spinner on a blank screen.
- **Empty:** friendly illustration/icon, one sentence, primary action.
- **Error:** what happened, retry button, offline hint.
- **Offline:** banner “You’re offline. Changes are saved on this device.”
- **Sync:** subtle badge, never a blocking modal.
- **Permission denied:** explain why and link to Settings.
- **Undo:** for destructive or quick-add actions.

### 6.14 Phase 2 acceptance criteria

- [ ] Every screen uses the new tokens and typography.
- [ ] Auth supports Apple, Google, email, and guest mode.
- [ ] Onboarding supports units, Health connect, and notification opt-in.
- [ ] Today has a large title, hero calories card, and quick actions.
- [ ] Fasting, nutrition, water, steps, exercise, sleep, and weight all have empty/loading/error states.
- [ ] Trends can export/share a weekly summary.
- [x] Profile is grouped into Goals, Preferences, Account & Backup, and Help & Privacy.
- [ ] Account deletion is reachable in-app and revokes Apple tokens.
- [x] Past day no longer mutates controllers during build.
- [ ] All screens are usable at 200% text scale and on iPhone SE.
- [x] Optional AI coach is account-scoped, read-only, consent-gated, and falls back across models automatically.
- [ ] AI data flow is disclosed in App Store App Privacy and Play Data safety answers.
- [ ] Before/after screenshots are attached to each PR.
- [x] `flutter analyze` and `flutter test` pass.

---

## 7. Phase 3 — Notifications and Apple platform integration

**Priority:** P1  
**Effort:** L (3–5 weeks)  
**Goal:** Make FitGo feel like a native iPhone app: HealthKit sync, widgets, Live Activities, Siri shortcuts, and optionally Apple Watch.

### 7.1 HealthKit

**Why:** Apple users expect steps, sleep, workouts, and weight to appear automatically. Manual entry is the biggest friction point in the current app.

**Scope for v2.3:**

| Data | Direction | Notes |
|---|---|---|
| Steps | Read | Today + last 7 days |
| Walking/running distance | Read | Derived chart |
| Active energy burned | Read | Show as “Apple Health” source |
| Sleep analysis | Read | Asleep/in bed; stages if available |
| Workouts | Read + write | Map FitGo activities to HKWorkoutActivityType |
| Body weight | Read + write | Canonical storage remains kg |
| Water | Write | Log FitGo water to Health |
| Dietary energy | Optional write | Only if nutrition entries are complete |
| Mindful minutes | Optional write | Future meditation feature |

**Permissions:**

- Add `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription`.
- Enable the HealthKit capability and entitlement.
- Use the `health` package (or a thin native bridge if you need exact HK APIs).
- Request read and write permissions separately; HealthKit may deny write while allowing read.
- Never block the app if permission is denied; fall back to manual entry and show a “Connect Apple Health” card.

Starter service:

```dart
import 'package:health/health.dart';

class HealthService {
  final Health _health = Health();
  bool _configured = false;

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  Future<bool> requestPermissions() async {
    await _configure();

    const readTypes = [
      HealthDataType.STEPS,
      HealthDataType.DISTANCE_WALKING_RUNNING,
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.WORKOUT,
      HealthDataType.BODY_WEIGHT,
    ];

    const writeTypes = [
      HealthDataType.WORKOUT,
      HealthDataType.BODY_WEIGHT,
      HealthDataType.WATER,
    ];

    final read = await _health.requestAuthorization(
      readTypes,
      permissions: [HealthDataAccess.READ],
    );
    final write = await _health.requestAuthorization(
      writeTypes,
      permissions: [HealthDataAccess.WRITE],
    );
    return read && write;
  }

  Future<int> stepsToday() async {
    await _configure();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return await _health.getTotalStepsInInterval(start, now) ?? 0;
  }

  Future<void> writeWater(int ml, DateTime at) async {
    await _configure();
    await _health.writeHealthData(
      value: ml.toDouble(),
      startTime: at,
      endTime: at,
      type: HealthDataType.WATER,
      unit: HealthDataUnit.MILLILITER,
    );
  }
}
```

> The exact `health` package API changes between majors. Treat the code above as the target shape and check the installed version’s README before shipping.

**Deduplication and source of truth:**

- Store `source` on each metric (`manual`, `healthkit`, `fitgo`).
- If HealthKit has steps for today, prefer it; allow a manual override with a “Manual” badge.
- Do not write FitGo water back to Health if the entry originated from Health, or you will create duplicates.
- On first connect, import the last 30 days, then use incremental sync on app resume.
- Add `lastHealthSyncAt` to settings.
- HealthKit background delivery is optional; start with foreground sync to keep scope small.

**Privacy:**

- Health data is sensitive. Do not send it to analytics/crash reporting.
- Disclose HealthKit usage in the privacy policy and App Privacy labels.
- Never use health data for advertising.
- Provide a “Disconnect Apple Health” setting that stops reads/writes.

#### Android Health Connect parity

Google Fit is deprecated for new integrations; **Health Connect** is the Android
equivalent. The same `health` package exposes both platforms, so build one
`HealthService` with platform-specific permission handling instead of two
integrations.

- Add Health Connect permissions and the
  `androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE` activity to
  `AndroidManifest.xml`; show the rationale before requesting access.
- Read steps, sleep, active energy, exercise, and weight on Android 9+ where
  Health Connect is installed (built into Android 14+).
- Keep the manual fallback and source badge identical to iOS.
- Add a “Connect Health Connect” entry on Android onboarding/settings.
- Test permission denial, revocation in the Health Connect app, and a device
  without Health Connect installed.
- Health Connect review requires a privacy policy that names the data types
  read/written; complete the Play Console health-data declaration.

### 7.2 WidgetKit widgets

**Why:** A home-screen and lock-screen widget is the most visible Apple feature. A fasting timer or “calories left” widget keeps FitGo in the user’s daily routine.

**Widgets to build:**

1. **Small** — calories left + progress ring.
2. **Medium** — calories left, water, steps, fasting status.
3. **Lock screen (iOS 16+)** — fasting elapsed/remaining, calories left.
4. **Lock screen accessory circular** — progress ring.

**Architecture:**

- Add a **Widget Extension** target in Xcode.
- Share data through an **App Group** (`group.com.fitgo.fitgo`).
- Use `home_widget` to write values from Flutter and trigger timeline reloads:
  ```dart
  await HomeWidget.saveWidgetData<int>('calories_left', 1420);
  await HomeWidget.saveWidgetData<int>('water_ml', 1750);
  await HomeWidget.saveWidgetData<String>('fasting_state', 'fasting');
  await HomeWidget.updateWidget(iOSName: 'FitGoWidget');
  ```
- The widget should show “Updated 2h ago” and never claim live data it does not have.
- Deep link taps: `fitgo://today`, `fitgo://fast`, `fitgo://water`.
- Update the widget after every log action and on app resume.

**Limitations:**

- Widgets are snapshots, not live apps.
- iOS controls refresh cadence; do not promise minute-by-minute updates.
- A fasting timer can show a static “ends at 17:00” or use `Text(timerInterval:)` in SwiftUI for a live countdown.

### 7.3 Live Activity and Dynamic Island

**Why:** A fasting Live Activity is a signature Apple experience: the timer stays visible on the Lock Screen and in the Dynamic Island.

**Important limitation:** Live Activities are intended for **active, time-bound events** and are limited to roughly **8 hours of active updates** (and up to 12 hours on the Lock Screen). A 16:8 fast is longer. Options:

- Use a **Lock Screen widget** for the full 16-hour fast.
- Start the Live Activity for the **eating window** or shorter 12-hour fasts.
- Start the Live Activity mid-fast (for example, at the 8-hour mark) so it covers the remaining time.
- Use local notifications at key milestones instead of a continuous Live Activity.

**Implementation:**

1. Add `NSSupportsLiveActivities` to `Info.plist`.
2. Add a Widget Extension target with `ActivityKit` support.
3. Define attributes and content state in Swift:
   ```swift
   import ActivityKit

   struct FastingActivityAttributes: ActivityAttributes {
     public struct ContentState: Codable, Hashable {
       var startDate: Date
       var targetDate: Date
       var progress: Double
     }
     var goalHours: Int
   }
   ```
4. Start/update/end from Swift, called through a Flutter `MethodChannel`:
   ```swift
   let attributes = FastingActivityAttributes(goalHours: 16)
   let state = FastingActivityAttributes.ContentState(
     startDate: start,
     targetDate: end,
     progress: 0
   )
   let activity = try Activity.request(
     attributes: attributes,
     contentState: state,
     pushType: nil
   )
   ```
5. Build the Lock Screen and Dynamic Island layouts in SwiftUI:
   - Compact: elapsed time + flame icon.
   - Minimal: progress ring.
   - Expanded: elapsed, remaining, goal.
6. End the activity when the fast ends or the user stops it; use a stale date so the system can dismiss it.
7. Test on a physical iPhone with Dynamic Island and on a notch device.

**Dart bridge:**

```dart
class LiveActivityService {
  static const _channel = MethodChannel('fitgo/live_activity');

  static Future<void> startFasting({
    required DateTime start,
    required DateTime target,
    required int goalHours,
  }) async {
    await _channel.invokeMethod('startFasting', {
      'startEpoch': start.millisecondsSinceEpoch,
      'targetEpoch': target.millisecondsSinceEpoch,
      'goalHours': goalHours,
    });
  }

  static Future<void> endFasting() async {
    await _channel.invokeMethod('endFasting');
  }
}
```

> There are community packages for Live Activities, but native Swift gives you the most control and avoids plugin breakage on new iOS releases.

### 7.4 Siri, App Intents, and Shortcuts

**Why:** “Hey Siri, log water in FitGo” is a delightful Apple-only feature and costs relatively little once deep links exist.

**Intents to ship:**

- `LogWaterIntent(amountMl)` — log 250/500 ml.
- `StartFastIntent(hours)` — start a 16/18/20-hour fast.
- `EndFastIntent` — end the current fast.
- `LogWeightIntent(weightKg)` — log weight.
- `CaloriesLeftIntent` — speak or display remaining calories.

**Implementation:**

- Add an **App Intents Extension** (or include App Intents in the main target).
- `perform()` writes to the App Group or calls a deep link:
  ```swift
  let url = URL(string: "fitgo://log-water?amount=250")!
  // Open the app or write to the shared store.
  ```
- Register `AppShortcutsProvider` phrases:
  ```swift
  AppShortcut(
    intent: LogWaterIntent(),
    phrases: ["Log water in FitGo", "Add water to FitGo"],
    shortTitle: "Log water",
    systemImageName: "drop.fill"
  )
  ```
- Handle `fitgo://` links in Flutter with `app_links` or `go_router`.
- Test from Siri, Spotlight, and the Shortcuts app.

### 7.5 Apple Watch (optional, Phase 3.5)

**Why:** A Watch app is excellent for quick water logging, starting a fast, and seeing today’s rings. It is also a large native effort.

**Recommended scope:**

- SwiftUI watchOS app.
- Complication showing calories left or fasting progress.
- Quick actions: +250 ml water, start/stop fast, view steps.
- Sync via Supabase REST or WatchConnectivity to the iPhone app.
- HealthKit read/write on the watch.

**Why not Flutter:** Flutter does not render watchOS UI. A Watch app must be native SwiftUI. Budget **XL** effort and do it only after the iPhone app is stable and has users asking for it.

### 7.6 Universal links, Handoff, and Focus

- **Universal links:** use `https://fitgo.app/...` for auth callbacks, shared reports, and widget taps. Requires an `Associated Domains` entitlement and an `apple-app-site-association` file. Custom URL schemes are sufficient for v3.0; add universal links when you have a domain.
- **Handoff:** optional; lets a user continue from iPhone to iPad. Requires `NSUserActivity` and `NSUserActivityTypes`.
- **Focus filters:** optional; expose a “Fitness” focus filter that opens Today. Nice-to-have, not a launch blocker.

### 7.7 Push notifications (optional, Phase 3)

Local notifications cover fasting/water/monthly alerts. Server-driven push is useful for:

- “Your weekly recap is ready.”
- “You haven’t logged today — keep your streak.”
- “Your friend sent a challenge.”

**If you add push:**

- Enable Push Notifications capability and APNs.
- Store device tokens in a Supabase table with user ID, platform, and opt-in preferences.
- Send via APNs from a Supabase Edge Function (or a service such as OneSignal).
- Respect quiet hours and notification categories.
- Never include sensitive health details in the notification payload; use generic text and deep link into the app.
- Add a “Notification settings” screen with per-category toggles.

### 7.8 StoreKit 2 (only if monetising)

If FitGo Pro is planned:

- Use **StoreKit 2** / `in_app_purchase` for subscriptions.
- Digital features must use Apple in-app purchase (guideline 3.1.1), not external payment links, except where regional rules explicitly allow otherwise.
- Add “Restore purchases”, subscription management, and clear renewal terms.
- Do not gate core health data behind a paywall in a way that surprises users; be transparent.

### 7.9 Phase 3 acceptance criteria

- [ ] HealthKit reads steps, sleep, workouts, and weight on a real iPhone.
- [ ] Water/weight/workout writes appear in Apple Health.
- [ ] Health Connect reads the same data types on Android and passes the Play Console health-data review.
- [ ] Permission denial or revocation falls back gracefully to manual entry on both platforms.
- [ ] Widgets show calories/water/fasting and deep link into the right screen.
- [ ] Live Activity starts, updates, and ends correctly; limitation documented in the UI.
- [ ] Siri shortcuts work from a cold start.
- [ ] No health data appears in analytics or crash logs.
- [ ] Privacy policy and App Privacy answers updated.
- [ ] App Store review notes explain HealthKit usage and include a demo account.

---

## 8. Phase 4 — Data, sync, security, and account lifecycle

**Priority:** P1  
**Effort:** M (2–3 weeks)  
**Goal:** Make multi-device sync trustworthy and satisfy App Store account requirements.

### 8.1 Schema additions

> **Applied (17 Nov 2026):** the baseline/repair migration
> `supabase/migrations/20261117110000_initial_schema.sql` was pushed to the
> hosted FitGo project. Remote migration history matches local, and
> `user_profiles.activity_level`, `target_weight_kg`,
> `goal_target_date`, and `weight_entries.updated_at` are present. The
> migration also fixes the old `weight_entries` trigger that referenced a
> missing `updated_at` column, and recreates RLS policies with explicit
> `authenticated` roles plus delete policies and grants.

Add columns to `daily_metrics`, `weight_entries`, `user_profiles`, and `app_settings`:

| Column | Type | Purpose |
|---|---|---|
| `updated_at` | `timestamptz` | Conflict resolution |
| `deleted_at` | `timestamptz` | Tombstones for deletes |
| `source` | `text` | `manual`, `healthkit`, `fitgo` |
| `meal_type` | `text` | Breakfast/lunch/dinner/snack |
| `unit_system` | `text` | `metric`/`imperial` |
| `timezone` | `text` | Correct day boundaries |
| `health_sync_enabled` | `boolean` | User preference |
| `notification_prefs` | `jsonb` | Per-category settings |

Example migration:

```sql
alter table daily_metrics
  add column if not exists source text not null default 'manual',
  add column if not exists meal_type text,
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists deleted_at timestamptz;

alter table weight_entries
  add column if not exists source text not null default 'manual',
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists deleted_at timestamptz;

create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists daily_metrics_touch on daily_metrics;
create trigger daily_metrics_touch
before update on daily_metrics
for each row execute function public.touch_updated_at();
```

> Hive is a schema too. Adding fields to `DailyMetrics`/`NutritionEntry` requires updating the model, running `dart run build_runner build --delete-conflicting-outputs`, and handling old records with defaults. Never ship a model change without a migration test.

### 8.2 Sync strategy

**Already implemented (data-safety foundation):**

- **Per-account Hive namespaces.** Guest data and each Supabase user have
  separate boxes (`fitgo_v3_user_<id>_*`). Signing in never uploads another
  account's cache.
- **One-time legacy migration.** The pre-3.0 shared cache is copied to the guest
  namespace, never silently to the signed-in account. Signed-in users are asked
  before guest data is imported.
- **Local outbox.** `saveMetrics`, `saveWeight`, `saveProfile`, and
  `saveSetting` mark a pending change and retry it until the upload succeeds.
- **Pull first, then push.** Cloud refresh updates non-pending local records and
  never overwrites a record with an unsynced local edit.
- **Sync triggers.** App start, sign-in, app resume (throttled), and
  pull-to-refresh.

**Still required for trustworthy multi-device editing:**

1. **Field-level timestamps.** A single `updated_at` per daily row still loses a
   meal logged on device A when device B syncs water for the same date. Move
   volatile data (water, meals, activities, sleep) to append-only event rows or
   give each field its own timestamp and merge field by field.
2. **Delta pull.** Fetch rows updated since `lastSyncedAt` instead of every row.
3. **Tombstones.** Deletes set `deleted_at`; do not hard-delete until both sides
   have seen the tombstone.
4. **Conflict UI.** Show a “Sync conflict” only when timestamps are close and
   values differ materially.
5. **Retry with backoff.** Keep the outbox on network failure; never drop it.
6. **Status UI (implemented).** Today and Profile show last synced time, the
   pending-change count, and a retry action. Local saves confirm immediately
   with **Saved on this device** and a **Sync pending** suffix on signed-in
   saves; the live pill later switches to **Synced**.

#### Midnight, timezone, and day boundaries

- **Implemented:** a midnight timer plus a resume check invalidates daily
  providers when the local civil day changes, so “Today” cannot keep showing
  yesterday's totals (`lib/core/day_boundary.dart`, `app.dart`).
- Store `date_key` as the user's local calendar day and persist
  `utc_offset_minutes` (or an IANA timezone) with each log.
- Store timestamps as UTC, render in local time, and recompute “today” when the
  app resumes or the timezone changes.
- Test 23:59 → 00:00 while the app is open, backgrounded overnight, DST spring
  forward/fall back, and travel across timezones.
- Do not re-key historical days just because the device timezone changed; keep
  the original day and show a timezone note on edited entries.

#### Minimum-version gating

- Add an `app_config` table (or Edge Config) with `min_supported_version`,
  `force_update_url`, `latest_version`, and `maintenance_mode`.
- Check it on startup and after a long background period.
- If the installed build is below `min_supported_version`, show a
  non-dismissible dialog with an App Store / Play Store action. Never let an old
  client write to a schema it does not understand.
- Keep the check fail-open (if the config cannot be fetched, let the user
  continue offline) and cache the last known value.

### 8.3 Secure storage

- Supabase sessions are stored in shared preferences by default. For a health app, store the session in the **iOS Keychain**.
- `supabase_flutter` supports a custom `LocalStorage` via `FlutterAuthClientOptions`; implement a Keychain-backed `LocalStorage` with `flutter_secure_storage`.
- Store the PKCE verifier in secure storage as well (`pkceAsyncStorage`).
- Do not store health data in plain text logs.
- If you add Hive encryption, use a key stored in the Keychain/Keystore; do not hard-code it.

Example skeleton:

```dart
class SecureLocalStorage implements LocalStorage {
  final FlutterSecureStorage _storage;
  SecureLocalStorage(this._storage);

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async =>
      await _storage.containsKey(key: 'supabase_session');

  @override
  Future<String?> accessToken() =>
      _storage.read(key: 'supabase_session');

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: 'supabase_session', value: persistSessionString);

  @override
  Future<void> removePersistedSession() =>
      _storage.delete(key: 'supabase_session');
}
```

Then:

```dart
await Supabase.initialize(
  url: SupabaseConfig.url,
  anonKey: SupabaseConfig.anonKey,
  authOptions: FlutterAuthClientOptions(
    localStorage: SecureLocalStorage(const FlutterSecureStorage()),
  ),
);
```

> Check the installed `supabase_flutter` version’s `LocalStorage` interface; implement every required method.

### 8.4 Account deletion and data export

App Store guideline 5.1.1(v) requires in-app account deletion if account creation exists. This is a **submission requirement**, not a post-launch polish item. The flow must also revoke tokens issued by “Sign in with Apple”.

**Apple token revocation (required):**

- Sign in with Apple returns an authorization code. Exchange it server-side at
  `https://appleid.apple.com/auth/token` (`grant_type=authorization_code`) and
  store the resulting refresh token against the Supabase user.
- On deletion, call `https://appleid.apple.com/auth/revoke` with the stored
  refresh token before deleting the account.
- The exchange/revocation must run in a Supabase Edge Function. The Apple
  `.p8` key and the client-secret JWT must never ship in the Flutter app.
- Store only what is needed; delete the refresh token after revocation.
- Test with a “Hide My Email” Apple account, then confirm the Apple ID no longer
  lists FitGo under Settings → Apple ID → Sign in with Apple.

**Backend option (SQL function):**

```sql
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_my_account() from public;
grant execute on function public.delete_my_account() to authenticated;
```

Client:

```dart
Future<void> deleteAccount() async {
  // Revokes the Apple token first, then deletes cloud rows.
  await SupabaseService.client.functions.invoke('delete-account');
  await ref.read(localStorageProvider).clearAll();
  await SupabaseService.signOut();
}
```

**Safer alternative:** a Supabase Edge Function using the service-role key,
invoked with the user's JWT. The function revokes Apple tokens, deletes the auth
user, and cascades health rows. This keeps privileged logic out of the public
schema.

**Data export:**

- “Export my data” generates JSON/CSV of profile, daily metrics, weights, and settings.
- Share via the iOS share sheet (`share_plus`).
- Do not include another user’s data.
- Mention export in the privacy policy.

### 8.5 App lock and privacy screen

- Add Face ID/Touch ID app lock (`local_auth`).
- Add `NSFaceIDUsageDescription`.
- When the app goes to background, blur the UI in the app switcher (iOS screenshot privacy).
- Offer “Require Face ID after 1 minute / 5 minutes / immediately”.
- Always allow access after a device passcode fallback.
- Do not lock the user out permanently; provide “Sign out” as a recovery path.

### 8.6 Phase 4 acceptance criteria

- [ ] Two devices can edit different days without losing data.
- [ ] A delete on one device propagates as a tombstone, not a resurrection.
- [ ] Offline edits queue and sync when connectivity returns.
- [ ] Two accounts on the same device never see or upload each other's data.
- [ ] Guest data is imported only after an explicit prompt.
- [ ] Same-day edits from two devices merge per field without data loss.
- [ ] The app recovers correctly after midnight and a timezone change.
- [ ] Supabase session is stored in Keychain on iOS.
- [ ] Account deletion removes cloud and local data, revokes Apple tokens, and signs out.
- [ ] Data export produces a readable file via the share sheet.
- [ ] Face ID lock works and the app switcher shows a blurred screen.
- [ ] RLS policies are tested for cross-user access.
- [ ] No service-role key exists in the Flutter app.

---

## 9. Phase 5 — Quality, performance, accessibility, and observability

**Priority:** P2  
**Effort:** M (2 weeks)  
**Goal:** Catch regressions, keep the app fast on older devices, and make releases measurable.

### 9.1 Testing

Current: one smoke test that likely fails because `FitGoApp` expects Supabase/Hive initialisation.

Add:

| Type | What to test |
|---|---|
| Unit | TDEE/BMR, weekly budget redistribution, unit conversion, sync merge, streak calculation |
| Widget | Auth form validation, quick-add sheet, dashboard hero, empty states, settings rows |
| Golden | Today, Trends, Profile, onboarding steps at 3 text scales |
| Integration | Onboarding → log meal → log water → see analytics update |
| iOS-specific | Apple sign-in, notification permission, HealthKit permission, deep link, widget tap |
| Regression | Every bug fix gets a test |

Example widget test:

```dart
testWidgets('Today shows calories left', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageProvider.overrideWithValue(fakeStorage),
      ],
      child: const MaterialApp(home: TodayScreen()),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text('Calories left'), findsOneWidget);
});
```

Use `integration_test` for flows that need real plugins. Run iOS integration tests on a simulator in CI; run HealthKit/notification tests manually on a device.

### 9.2 Performance

- Profile on a physical iPhone SE (2nd gen) or iPhone 11, not just a simulator.
- Use `flutter run --profile` and DevTools frame timings.
- Keep the Today screen at 60/120 fps while scrolling charts.
- `RepaintBoundary` around custom painters and charts.
- Avoid rebuilding the whole dashboard on every provider tick; use `select`.
- Prefer `const` constructors and `ListView.builder`/`SliverList` for long lists.
- Compress images; avoid full-resolution photos in cards.
- Measure app size (`flutter build ipa --analyze-size`).
- Test with Low Power Mode and reduced motion.
- Do not run a 1-second `Timer` for the fasting display while the app is backgrounded; compute from timestamps.

### 9.3 Accessibility audit

- VoiceOver pass on Today, Trends, Fasting, Auth, and Onboarding.
- Dynamic Type at 200%; no clipped text or overlapping buttons.
- Contrast check for all semantic colours in light and dark.
- Reduce Motion respected.
- All icon-only buttons have tooltips/semantics.
- Charts have text summaries.
- Forms have labels, hints, and error text linked to fields.
- No colour-only status indicators.
- Test with Switch Control if time allows.
- **iOS edge-swipe:** keep the outer ~20 pt of chart areas and horizontal
  carousels clear of drag recognisers so the native swipe-back gesture still
  works. Verify on Today's charts, Trends, and the fasting dial.
- **Dark-mode contrast:** do not use vivid ember/amber tokens for small body
  text or captions. Restrict them to icons, rings, borders, and bold large
  numbers; use `textPrimary`/`textSecondary` for normal text.
- Automated contrast tests cover button text, containers, and semantic text
  tokens in both themes (`test/theme_contrast_test.dart`).

### 9.4 Observability

- **Crash reporting:** Sentry Flutter or Firebase Crashlytics. Scrub health data and emails.
- **Analytics:** opt-in, privacy-friendly events only (screen views, feature usage). Never send calories, weight, sleep, or health samples.
- **Performance monitoring:** cold start, dashboard load, sync duration.
- **Release health:** crash-free sessions, ANRs (Android), hang rate (iOS).
- **Logging:** structured logs in debug; no PII in release logs.
- **Feature flags:** remote config for phased rollout of widgets/HealthKit.

### 9.5 Phase 5 acceptance criteria

- [ ] Unit tests cover all financial-like math (budgets, TDEE, unit conversion, sync merge).
- [ ] Golden tests pass on iPhone SE and iPad sizes.
- [ ] Integration test covers the core daily loop.
- [ ] 60 fps scrolling on a low-end physical device.
- [ ] VoiceOver and 200% text scale pass.
- [ ] Crash reporting is configured and scrubbed.
- [ ] App size is documented; no unused assets.
- [ ] CI runs analyze, tests, and a release build on every PR.

---

## 10. Phase 6 — App Store launch

**Priority:** P1  
**Effort:** M (1–2 weeks)  
**Goal:** Submit a complete, compliant, review-ready app.

### 10.1 App Store Connect checklist

- [ ] Apple Developer Program membership active; agreements, tax, and banking complete (if paid).
- [ ] App record created with bundle ID `com.fitgo.fitgo`, SKU, primary language.
- [ ] Signing certificates and provisioning profiles valid.
- [ ] Build uploaded and processed in TestFlight.
- [ ] App icon 1024×1024, no alpha.
- [ ] Screenshots for the required sizes:
  - iPhone 6.9" (or current required large size)
  - iPhone 6.5"
  - iPad 13" (if iPad supported)
  - Localised screenshots for each supported language
- [ ] App preview video (optional but recommended).
- [ ] Name, subtitle, promotional text, description, keywords.
- [ ] Support URL and marketing URL.
- [ ] Privacy policy URL (public, no login).
- [ ] Category: **Health & Fitness**.
- [ ] Age rating questionnaire.
- [ ] Copyright and contact information.
- [ ] App Privacy answers match the privacy manifest and actual data flows.
- [ ] Export compliance (`ITSAppUsesNonExemptEncryption = false` for HTTPS-only).
- [ ] Review notes with:
  - Demo account credentials (or “no login required”).
  - HealthKit and Health Connect explanation and where permissions are requested.
  - Account deletion path, including Apple token revocation.
  - Sign in with Apple path and private-relay email support.
  - Any subscription details (if applicable).
- [ ] In-app account deletion is reachable without contacting support and revokes Apple tokens.
- [ ] Published Privacy Policy and Terms of Use URLs load without login.
- [ ] TestFlight internal testing passed on a real iPhone and iPad.
- [ ] External beta feedback addressed.
- [ ] **First App Store version is set to manual release after approval.** Phased release is enabled only for subsequent updates.
- [ ] Monitoring plan for the first 48 hours.

### 10.1a Current 3.0 submission blockers

- [ ] **In-app account deletion with Apple token revocation.** Needs a Supabase
  Edge Function that deletes the authenticated user's rows, clears the account
  namespace on the device, and revokes the Apple refresh token with the Apple
  server credentials. Do not submit without this.
- [ ] **Published Privacy Policy, Terms of Use, and Support URLs.** Profile
  currently shows `fitgo.app/privacy`, `fitgo.app/terms`, and
  `fitgo.app/support` as copyable addresses. They must load publicly, without
  login, before App Store submission.
- [ ] **AI data-safety disclosure and terms.** The optional Gemini coach sends
  a compact FitGo snapshot and recent chat from the device to Google under the
  user's own key. App Privacy, Play Data safety, and the published Privacy
  Policy must state this explicitly, including free-tier data-use terms and the
  paid-key recommendation. The key itself stays in platform secure storage and
  is excluded from Android backup.
- [ ] **iOS/TestFlight verification on macOS and physical devices.** Apple Sign
  In, notification scheduling/actions, deep links, dark-mode contrast, and the
  iPad layout still need a real iPhone/iPad pass.
- [ ] **Android release signing.** `android/key.properties` is absent, so the
  current release APK and AAB are debug-signed. Create and secure a Play upload
  keystore before any store upload.
- [x] **Supabase schema migration.** `20261117110000_initial_schema.sql` was
  pushed to the hosted FitGo project on 17 Nov 2026. Local/remote migration
  history match; the goal-plan columns and `weight_entries.updated_at` were
  verified.
- [ ] **Supabase auth provider console setup.** Apple Service ID/key, Google
  OAuth client, redirect URLs, and the `app_settings` row for saved meals must
  exist in the deployed environment.
- [ ] **Field-level sync.** Same-day edits from two devices can still overwrite
  each other at row granularity; move volatile fields to per-field timestamps
  or append-only events before marketing multi-device editing.

### 10.2 Metadata draft

| Field | Draft |
|---|---|
| Name | FitGo — Calories & Fasting |
| Subtitle | Weekly budget, fasting, health |
| Promotional text | A calmer way to track calories, fasting, water, sleep, and weight — with Apple Health sync. |
| Keywords | calorie tracker, intermittent fasting, water tracker, health, weight, steps, sleep |
| Description | See the full feature list; lead with the weekly calorie budget and Apple Health, not a wall of features. |
| Support URL | `https://fitgo.app/support` (create this) |
| Privacy URL | `https://fitgo.app/privacy` (create this) |

### 10.3 Privacy nutrition labels

Declare only what you collect:

- **Health & Fitness** — health, fitness, and sleep data. Linked to the user. Not used for tracking.
- **Contact Info** — email address (if account creation). Linked. App functionality.
- **User Content** — meal/weight notes, photos if added. Linked. App functionality.
- **Identifiers** — user ID. Linked. App functionality.
- **Diagnostics** — crash logs, if Sentry/Crashlytics is enabled. Not linked (if scrubbed) or linked (if user ID attached). Not tracking.
- **Usage Data** — optional product interaction analytics. Not tracking.
- **AI coach (optional)** — a compact progress snapshot and recent chat are sent directly from the device to Google’s Gemini API with the user’s own key, only after explicit consent. FitGo does not receive or store this content. Declare it under the appropriate content category in App Privacy and Play Data safety; it is not used for tracking.

If you do **not** track users across apps/websites, set “Used to Track You” to **No** for every category.

### 10.4 Common rejection reasons and fixes

| Guideline | Reason | Fix |
|---|---|---|
| 4.8 | Google sign-in without Sign in with Apple | Add native Apple button and test it |
| 5.1.1 | Missing/weak permission purpose strings | Specific, user-facing descriptions in `Info.plist` |
| 5.1.1(v) | No account deletion | In-app delete account flow |
| 5.1.3 | HealthKit data used improperly or not disclosed | Clear purpose, privacy policy, no advertising use |
| 2.1 | Crash or incomplete feature | TestFlight pass on a physical device |
| 4.2 | “Minimum functionality” | Emphasise unique weekly budget, fasting, HealthKit, widgets |
| 3.1.1 | External payment for digital features | Use StoreKit 2 / in-app purchase |
| 5.1.2 | Data sharing without consent | Explicit opt-in, privacy policy |
| 2.3.1 | Hidden features or misleading metadata | Screenshots and description match the app |

### 10.5 Launch day

- Submit 1–2 weeks before the desired launch date; review can take days.
- For the **first version**, choose manual release after approval. Phased release is only available for updates, so do not plan a 7-day phased 3.0 launch.
- For later updates, use phased release (7 days) to catch crashes.
- Monitor crash-free rate, App Store reviews, and support email.
- Have a rollback plan: keep the previous build available and a server-side feature flag for risky features.
- Post-launch: respond to reviews, ship a 3.0.1 fix within the first two weeks.

---

## 11. Phase 7 — Post-launch roadmap (ideas)

These are intentionally **not** required for 3.0. Prioritise based on user requests and retention data.

### 11.1 High-value ideas

| Idea | Why | Effort | Phase |
|---|---|---|---|
| AI meal photo / calorie estimate | Removes the biggest logging friction | XL | 3.1 |
| Barcode scanner | Fast packaged-food logging | M | 3.1 |
| Food search database | Better than manual calories | L | 3.1 |
| Recipe builder | Makes home cooking trackable | L | 3.2 |
| Weekly AI action plan | Builds on the in-app coach with a scheduled weekly summary | M | 3.2 |
| Apple Watch app | Quick water/fast/rings | XL | 3.5 |
| Social challenges | Retention and accountability | L | 3.2 |
| Streak repair / grace days | Reduces streak anxiety | S | 3.1 |
| Home screen widget packs | Personalisation | M | 3.1 |
| Live Activity for eating window | Signature Apple feature | M | 3.1 |
| Siri shortcuts | Delight and speed | M | 3.1 |
| PDF report for clinicians | High-value export | M | 3.2 |
| Family sharing | Household health goals | XL | 4.0 |
| Android widgets / Wear OS | Parity for Android users | L | 3.3 |
| Web dashboard | Planning and export | L | 4.0 |

### 11.2 Product ideas that fit the brand

- **“Calm streak”** — consistency without shame; a missed day is shown as a rest day, not a failure.
- **Weekly review ritual** — a Sunday recap with one win, one adjustment, and next week’s budget.
- **Fasting stages** — educational content (not medical advice) about what happens at 12/16/18 hours.
- **Hydration pacing** — a gentle schedule instead of a single goal.
- **Sleep wind-down** — a reminder and a 5-minute breathing exercise.
- **Grocery list from meal plan** — if meal planning is added.
- **Apple Health “share with clinician”** — export a clean PDF, not raw JSON.

### 11.3 Things to avoid

- Copying Apple Fitness rings exactly; use your own visual language.
- Medical claims (“cures”, “detox”, “boosts metabolism”).
- Shaming copy (“you failed”, “bad day”).
- Dark patterns around streaks, subscriptions, or notifications.
- Forcing account creation before showing value.
- Adding social features before privacy and moderation are ready.

---

## 12. Prioritised backlog

Use this as the working backlog. IDs are stable so PRs and issues can reference them.

| ID | Item | Priority | Effort | Phase |
|---|---|---|---|---|
| IOS-001 | Add URL scheme + Supabase redirect config | P0 | S | 0 |
| IOS-002 | Sign in with Apple | P0 | M | 0 |
| IOS-003 | Cross-platform notifications | P0 | M | 0 |
| IOS-004 | Info.plist permissions + privacy manifest | P0 | S | 0 |
| IOS-005 | Entitlements + capabilities | P0 | S | 0 |
| IOS-006 | TestFlight CI pipeline | P0 | M | 0 |
| IOS-007 | Portrait-only iPhone / iPad orientations | P0 | S | 0 |
| IOS-008 | Account deletion + Apple token revocation | P0 | M | 4 |
| IOS-009 | Google OAuth Web application client + device test | P0 | S | 0 |
| IOS-010 | Android scheduled/reboot notification receivers | P0 | S | 0 |
| UI-001 | Design tokens + theme extension | P1 | M | 1 |
| UI-002 | Component library | P1 | L | 1 |
| UI-003 | Adaptive navigation shell + go_router | P1 | M | 1 |
| UI-004 | Theme mode System | P1 | S | 1 |
| UI-005 | Localisation + units | P1 | M | 1 |
| UI-006 | Auth redesign + guest mode | P1 | M | 2 |
| UI-007 | Onboarding redesign | P1 | M | 2 |
| UI-008 | Today dashboard redesign | P1 | L | 2 |
| UI-009 | Fasting screen + celebration | P1 | M | 2 |
| UI-010 | Nutrition meal sections + quick add | P1 | M | 2 |
| UI-010b | Saved/recent meals in Quick Log | P1 | S | 2 |
| UI-011 | Water animation + undo | P1 | S | 2 |
| UI-012 | Steps/exercise redesign | P1 | M | 2 |
| UI-013 | Sleep redesign | P1 | M | 2 |
| UI-014 | Weight redesign | P1 | M | 2 |
| UI-015 | Trends redesign + export | P1 | L | 2 |
| UI-016 | Profile/settings redesign | P1 | M | 2 |
| UI-017 | Past day fix + redesign | P1 | S | 2 |
| UI-018 | Empty/loading/error states | P1 | M | 2 |
| AI-001 | Optional Gemini coach: secure BYO key, read-only grounding, automatic fallback | P1 | M | 3.0 |
| APPLE-001 | HealthKit read/write | P1 | L | 3 |
| ANDROID-001 | Health Connect parity + Play health declaration | P1 | M | 3 |
| APPLE-002 | WidgetKit widgets | P1 | L | 3 |
| APPLE-003 | Live Activity / Dynamic Island | P2 | L | 3 |
| APPLE-004 | Siri / App Intents | P2 | M | 3 |
| APPLE-005 | Push notifications | P2 | M | 3 |
| APPLE-006 | Apple Watch app | P2 | XL | 3.5 |
| DATA-000 | Per-account Hive namespaces + outbox + guest import | P0 | M | 4 |
| DATA-001 | Field-level/delta sync conflict resolution | P1 | M | 4 |
| DATA-001b | Midnight/timezone rollover handling | P1 | S | 1 / 4 |
| DATA-001c | Minimum-version / maintenance gating | P1 | S | 4 |
| DATA-002 | Keychain session storage | P1 | S | 4 |
| DATA-003 | Data export | P1 | M | 4 |
| DATA-004 | Face ID app lock | P2 | M | 4 |
| DATA-005 | Schema migrations + tests | P1 | M | 4 |
| QA-001 | Unit/widget/golden tests | P1 | M | 5 |
| QA-002 | Integration tests | P1 | M | 5 |
| QA-003 | Performance profiling | P2 | S | 5 |
| QA-004 | Accessibility audit (contrast, VoiceOver, edge swipe) | P1 | M | 5 |
| QA-005 | Crash reporting + analytics | P2 | S | 5 |
| SHIP-001 | App Store metadata + screenshots | P1 | M | 6 |
| SHIP-002 | Privacy policy + support site | P1 | S | 6 |
| SHIP-003 | TestFlight beta + review | P1 | M | 6 |
| POST-001 | Barcode scanner | P2 | M | 3.1 |
| POST-002 | AI meal photo | P2 | XL | 3.1 |
| POST-003 | Food search database | P2 | L | 3.1 |
| POST-004 | Weekly AI action plan | P2 | M | 3.2 |

---

## 13. File-by-file change map

| File / folder | Change | Phase |
|---|---|---|
| `pubspec.yaml` | Add localizations, notifications, Apple sign-in, health, secure storage, go_router, share, url_launcher, package_info, local_auth, home_widget | 0–4 |
| `lib/main.dart` | Init notifications, timezone, app lock, deep links; wrap errors | 0–4 |
| `lib/app.dart` | Adaptive shell, router, localizations, scroll behavior, theme mode, guest gate | 0–2 |
| `lib/core/theme.dart` | Replace with tokens/typography/theme extensions | 1 |
| `lib/core/constants.dart` | Add unit defaults, notification IDs, breakpoints | 1 |
| `lib/providers/theme_provider.dart` | Add `ThemeMode.system` | 1 |
| `lib/services/notification_service.dart` | Cross-platform implementation | 0 |
| `lib/services/supabase_service.dart` | Apple sign-in, delete account, schema fields | 0 / 4 |
| `lib/services/local_storage.dart` | Unit system, notification prefs, migration helpers | 1 / 4 |
| `lib/services/health_service.dart` | New HealthKit service | 3 |
| `lib/services/live_activity_service.dart` | New MethodChannel bridge | 3 |
| `lib/services/share_service.dart` | New export/share helper | 2 |
| `lib/services/app_lock_service.dart` | New Face ID service | 4 |
| `lib/services/ai/*` | Gemini client, secure key store, usage router, context, prompts, chat history | 3.0 |
| `lib/providers/ai_provider.dart` | AI settings/chat state and automatic fallback orchestration | 3.0 |
| `lib/screens/ai_chat_screen.dart` | Optional themed AI chat surface | 3.0 |
| `lib/ui/profile/ai_settings_sheet.dart` | Key entry, consent, usage, delete | 3.0 |
| `lib/screens/auth_screen.dart` | Rewrite + Apple + guest mode | 2 |
| `lib/screens/onboarding_screen.dart` | Split into steps + units + Health | 2 |
| `lib/screens/home_screen.dart` | Split into Today feature widgets | 2 |
| `lib/screens/analytics_screen.dart` | Split into Trends feature widgets + export | 2 |
| `lib/screens/profile_screen.dart` | Split into Settings groups + account deletion | 2 / 4 |
| `lib/screens/past_day_screen.dart` | Fix build side effects + redesign | 2 |
| `lib/widgets/radial_dial.dart` | Tokens, animation, semantics | 2 |
| `lib/widgets/weight_chart.dart` | Tokens, empty state, tooltip, semantics | 2 |
| `lib/models/*.dart` | Add source/mealType/timestamps; regenerate adapters | 4 |
| `lib/features/**` | New feature-first structure | 1–3 |
| `ios/Runner/Info.plist` | URL scheme, permissions, encryption, orientations | 0 |
| `ios/Runner/Runner.entitlements` | New capabilities file | 0 |
| `ios/Runner/PrivacyInfo.xcprivacy` | New privacy manifest | 0 |
| `ios/Runner/AppDelegate.swift` | Notification delegate / native bridge (if Option B) | 0 |
| `ios/Runner/Base.lproj/LaunchScreen.storyboard` | Branded light/dark launch screen | 1 |
| `ios/Runner/Assets.xcassets/` | App icon variants, launch background | 1 |
| `ios/Podfile` | Platform 16.0 | 0 |
| `ios/Runner.xcodeproj/project.pbxproj` | Deployment target, entitlements, capabilities | 0 |
| `ios/Runner.xcodeproj/.../WidgetExtension` | New WidgetKit target | 3 |
| `android/app/src/main/res/xml/backup_rules.xml` | Exclude secure-storage prefs from Android backup | 3.0 |
| `android/app/src/main/res/xml/data_extraction_rules.xml` | Android 12+ backup exclusion | 3.0 |
| `test/ai_test.dart` | AI routing, context, client, and account-isolation tests | 3.0 |
| `test/ai_chat_screen_test.dart` | AI state and 320 pt/200% layout tests | 3.0 |
| `supabase_setup.sql` | New columns, triggers, delete function | 4 |
| `test/` | Unit/widget/golden/integration tests | 5 |
| `fastlane/` or `.github/workflows/` | iOS CI + TestFlight | 0 |
| `README.md` | Update setup, iOS build, TestFlight, architecture | 6 |
| `upgrade.md` | This roadmap; update checkboxes as work lands | all |

---

## 14. New dependencies

Add with `flutter pub add <package>` so the latest compatible version is resolved. Do not copy stale version numbers from blog posts.

| Package | Purpose | Phase |
|---|---|---|
| `flutter_localizations` (SDK) | Material/Cupertino localizations | 1 |
| `go_router` | Declarative routes, deep links, widget/notification taps | 1 |
| `flutter_local_notifications` | Cross-platform local notifications | 0 |
| `timezone` + `flutter_timezone` | Correct scheduled local notifications | 0 |
| `sign_in_with_apple` | Native Apple button + credential | 0 |
| `crypto` | SHA-256 nonce for Apple sign-in | 0 |
| `http` | Direct HTTPS calls to the user's Gemini API | 3.0 (added) |
| `health` | HealthKit/Health Connect read/write | 3 |
| `home_widget` | WidgetKit/App Widget data bridge | 3 |
| `flutter_secure_storage` | Keychain/Keystore session storage and the per-account Gemini key | 0 / 4 (added) |
| `local_auth` | Face ID/Touch ID app lock | 4 |
| `package_info_plus` | Version/build in settings | 2 |
| `share_plus` | Share/export reports | 2 |
| `url_launcher` | Support, privacy, App Store rating, Settings | 2 |
| `connectivity_plus` | Offline banner and sync retry | 4 |
| `image_picker` | Progress photos / meal photos | 3+ |
| `mobile_scanner` | Barcode scanning (post-launch) | 3.1 |
| `permission_handler` | Camera/photos/motion permission flows | 3 |
| `sentry_flutter` or `firebase_crashlytics` | Crash reporting | 5 |
| `in_app_purchase` | StoreKit 2 subscriptions (if monetised) | 3+ |
| `google_fonts` (optional) | Brand font; bundle it instead for offline reliability | 1 |
| `flutter_animate` (optional) | Declarative micro-animations | 2 |
| `skeletonizer` (optional) | Skeleton loading states | 2 |

Avoid adding a package for something you can build in 50 lines. Every dependency is an iOS build and privacy-manifest risk.

---

## 15. Detailed implementation recipes

### 15.1 `MaterialApp` target configuration

```dart
return MaterialApp.router(
  title: 'FitGo',
  debugShowCheckedModeBanner: false,
  themeMode: themeMode,
  theme: FitGoTheme.light,
  darkTheme: FitGoTheme.dark,
  themeAnimationDuration: const Duration(milliseconds: 250),
  scrollBehavior: const FitGoScrollBehavior(),
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  supportedLocales: const [Locale('en'), Locale('hi'), Locale('es')],
  routerConfig: router,
);
```

### 15.2 `FitGoCard`

```dart
class FitGoCard extends StatelessWidget {
  const FitGoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? tokens.surface,
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        border: Border.all(color: tokens.border),
        boxShadow: [
          BoxShadow(
            color: tokens.shadow,
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        onTap: onTap,
        child: card,
      ),
    );
  }
}
```

### 15.3 `FitGoRing`

```dart
class FitGoRing extends StatelessWidget {
  const FitGoRing({
    super.key,
    required this.progress,
    required this.child,
    this.size = 220,
    this.strokeWidth = 14,
    this.color,
  });

  final double progress;
  final Widget child;
  final double size;
  final double strokeWidth;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      label: 'Progress',
      value: '${(progress * 100).round()} percent',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress.clamp(0, 1)),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => CustomPaint(
                size: Size.square(size),
                painter: _RingPainter(
                  progress: value,
                  track: tokens.surfaceMuted,
                  color: color ?? tokens.ember,
                  strokeWidth: strokeWidth,
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}
```

### 15.4 Quick log sheet

```dart
Future<void> showQuickLogSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (context) => const QuickLogSheet(),
  );
}
```

Inside `QuickLogSheet`, use a `Wrap` of `QuickAction` tiles: Meal, Water, Weight, Workout, Steps, Sleep, Fast. Each opens the relevant dialog/sheet, then closes.

### 15.5 Native iOS notification bridge

See section 4.7, Option B. If you use Option A, delete the native channel only after Android parity is verified.

### 15.6 HealthKit service

See section 7.1. Add a `HealthSyncProvider` that:

- Checks `HealthService.isAvailable` (iOS only).
- Reads steps/sleep/weight on app resume, at most every 15 minutes.
- Merges into local storage with `source: 'healthkit'`.
- Invalidates the relevant Riverpod providers.
- Shows a source badge in the UI.

### 15.7 Widget data bridge

```dart
class WidgetService {
  static Future<void> updateToday({
    required int caloriesLeft,
    required int waterMl,
    required int steps,
    required String fastingState,
  }) async {
    await HomeWidget.saveWidgetData<int>('calories_left', caloriesLeft);
    await HomeWidget.saveWidgetData<int>('water_ml', waterMl);
    await HomeWidget.saveWidgetData<int>('steps', steps);
    await HomeWidget.saveWidgetData<String>('fasting_state', fastingState);
    await HomeWidget.updateWidget(iOSName: 'FitGoWidget');
  }
}
```

Call after each log action, debounced to avoid excessive reloads.

### 15.8 App lock

```dart
class AppLockService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock FitGo to view your health data',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
```

Use a `WidgetsBindingObserver` to lock on `AppLifecycleState.paused` after the configured grace period. Show a blurred placeholder in the app switcher.

### 15.9 Account deletion

See section 8.4. Add a confirmation flow that explains:

- What will be deleted (profile, metrics, weights, settings).
- What will be retained (none, or anonymised logs if legally required).
- That the action cannot be undone.
- A final Face ID/password confirmation.

### 15.10 App Store review notes template

```
FitGo is a health and fitness tracker. No account is required to try the app;
a demo account is provided below for cloud sync and HealthKit testing.

Demo account: review@fitgo.app / <password>

HealthKit: FitGo requests read access to steps, sleep, workouts, and body weight,
and write access to water, weight, and workouts. The purpose strings explain
each request. Health data is stored in the user's private Supabase account and
is never used for advertising or tracking.

Sign in with Apple is available on the login screen alongside Google and email.

Account deletion: Profile → Data → Delete account. This permanently deletes the
account and all associated health data.

No in-app purchases are present in this build.
```

---

## 16. Release plan and estimates

### 16.1 Phase timeline (solo developer)

| Phase | Duration | Depends on | Deliverable |
|---|---|---|---|
| Phase 0 — iOS foundation | 1–2 weeks | Mac/CI, Apple account | TestFlight build with auth + notifications |
| Phase 1 — Design system | 2–3 weeks | Phase 0 | Tokens, components, adaptive shell |
| Phase 2 — Screen refresh | 4–6 weeks | Phase 1 | New UI across all screens |
| Phase 3 — Apple features | 3–5 weeks | Phase 2 | HealthKit, widgets, Live Activity, Siri |
| Phase 4 — Data/security | 2–3 weeks | Phase 0 | Trustworthy sync, deletion, app lock |
| Phase 5 — Quality | 2 weeks | Phase 2–4 | Tests, performance, accessibility |
| Phase 6 — Launch | 1–2 weeks | all | App Store submission |

**Total:** ~15–23 weeks of focused work, plus buffer. With a designer and an iOS developer in parallel, ~8–12 weeks.

### 16.2 Suggested sprint sequence

| Sprint | Focus |
|---|---|
| 0 | Repo hygiene, CI, Apple account, bundle ID, TestFlight “hello world” |
| 1 | Phase 0: auth, URL scheme, notifications, Info.plist, privacy manifest |
| 2 | Phase 1: tokens, theme, typography, component library |
| 3 | Phase 1: adaptive shell, router, theme mode, localisation, units |
| 4 | Phase 2: auth, onboarding |
| 5 | Phase 2: Today, fasting |
| 6 | Phase 2: nutrition, water, steps, exercise |
| 7 | Phase 2: sleep, weight, past day |
| 8 | Phase 2: Trends, profile, states, polish |
| 9 | Phase 3: HealthKit |
| 10 | Phase 3: widgets, Live Activity, Siri |
| 11 | Phase 4: sync, keychain, deletion, app lock |
| 12 | Phase 5: tests, performance, accessibility |
| 13 | Phase 6: App Store assets, TestFlight beta, submission |

### 16.3 Versioning

- This branch is already `3.0.0+3`; keep one 3.0 release line and increment the
  build number on every TestFlight upload.
- If the work is split into staged releases, the earlier numbering was
  `2.1.0` (Phase 0), `2.2.0` (Phases 1–2), `2.3.0` (Phase 3), then `3.0.0`
  (Phases 4–6). Do not reuse an App Store version/build pair.
- Update `pubspec.yaml` and the iOS/Android build numbers together in CI.
- The first App Store version is released manually after approval; phased
  release applies to later updates.

---

## 17. Risks and mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| App Store rejection for Sign in with Apple | High if omitted | Blocks launch | Implement in Phase 0 and test |
| HealthKit permission denied | Medium | Missing data | Manual fallback + clear “Connect” card |
| Live Activity 8-hour limit | High for 16:8 | Feature feels broken | Use lock-screen widget or start mid-fast |
| iOS build only on macOS | Certain | Slows iteration | Set up Codemagic/GitHub macOS CI early |
| Notification limit (64) | Medium | Missing reminders | Cap series; reschedule on app open |
| Sync data loss | Medium | Trust damage | Pull/merge/outbox/tombstones before shipping |
| Plugin breakage on new iOS/Xcode | Medium | Build failure | Pin versions; test on beta Xcode; isolate native code |
| Privacy manifest inaccuracy | Medium | Rejection | Audit actual data flows; update App Privacy |
| Scope creep | High | Delays launch | Phase gates; no widgets before Phase 0 |
| Performance regression on old iPhones | Medium | Bad reviews | Profile on iPhone SE/11; RepaintBoundary |
| Google OAuth deep link fails | Medium | Login blocked | Test on device; verify Supabase redirect URLs |
| Apple name/email only first sign-in | Medium | Empty profile | Save immediately; allow edit in settings |
| Private Relay transactional email bounces | Medium | Password reset/export broken | Register email domain under Sign in with Apple Email Sources |
| Account switch leaks cached data | High if shared boxes | Privacy breach | Per-account namespaces + automated isolation tests |
| Gemini key exposed or reused across accounts | Low | Privacy breach | Platform keystore, per-account namespace, masked UI, backup exclusion, provider invalidation on switch |
| AI quota or provider outage | High over time | Chat unavailable | Automatic 3.8/3.6 → Flash Lite routing, retry for transient failures, local logs unaffected |
| AI gives unsafe or goal-changing advice | Medium | Health/safety | Read-only snapshot, app-owned on-track status, hard prompt limits, no write path |
| Old client writes after schema change | Medium | Corruption | Minimum-version gating with fail-open offline mode |
| Health Connect policy rejection | Medium | Android launch delay | Health-data declaration + in-app rationale before permissions |
| Unit conversion bugs | Medium | Wrong goals | Store canonical kg/ml; unit tests |
| Localisation/RTL layout issues | Low initially | Future rework | Use `EdgeInsetsDirectional`, test RTL early |

---

## 18. Definition of done

### 18.1 Phase 0

- [ ] TestFlight build installs on a real iPhone and iPad.
- [ ] Apple, Google, and email sign-in all work.
- [ ] Notifications work on iOS and Android.
- [ ] No App Store validation blockers.
- [ ] Android release build still passes.

### 18.2 Phase 1

- [ ] Design tokens are the only source of colours/typography.
- [ ] Adaptive navigation works on phone and iPad.
- [ ] Theme mode includes System.
- [ ] Localisation and units are wired.
- [ ] Accessibility baseline passes, including automated contrast tests in both themes.

### 18.3 Phase 2

- [ ] All screens use the new design system.
- [ ] Core flows are faster and clearer than v2.
- [ ] Empty/loading/error/offline states exist.
- [ ] Before/after screenshots approved.
- [ ] No feature regressions.

### 18.4 Phase 3

- [ ] HealthKit read/write works and falls back gracefully.
- [ ] Health Connect provides parity on Android.
- [ ] Widgets and Live Activity work on a real device.
- [ ] Siri shortcuts work from cold start.
- [ ] Privacy disclosures updated.

### 18.5 Phase 4

- [ ] Multi-device sync is trustworthy, including same-day field merges.
- [ ] Account deletion (with Apple token revocation) and export work.
- [ ] Per-account local caches and guest import are verified.
- [ ] Midnight rollover and timezone changes are handled.
- [ ] Session storage is secure.
- [ ] App lock and privacy screen work.

### 18.6 Phase 5

- [ ] Tests cover the core math and flows.
- [ ] 60 fps on a low-end device.
- [ ] VoiceOver and Dynamic Type pass.
- [ ] Crash reporting is live and scrubbed.

### 18.7 Phase 6

- [ ] App Store listing is complete.
- [ ] TestFlight beta feedback addressed.
- [ ] Review notes, demo account, and account-deletion path provided.
- [ ] First version set to manual release; phased-release plan ready for updates.
- [ ] Monitoring plan ready.

### 18.8 Overall 3.0 quality bar

- Crash-free sessions ≥ 99.5%.
- Cold start < 2 seconds on iPhone 11.
- No P0/P1 bugs open.
- All health data flows disclosed and private.
- The app feels at home on iPhone, not like an Android app in a Material costume.
- Android parity is maintained.

---

## 19. Open decisions

These need a product decision before the relevant phase starts.

1. **Minimum iOS version:** 15.0 (reach) or 16.0 (modern APIs, simpler code)? Recommended: **16.0**.
2. **Guest mode:** allow local-only use? Recommended: **yes**; sync is optional.
3. **Navigation:** three tabs + FAB, or four tabs? Recommended: **three tabs + FAB** for v3.0.
4. **HealthKit scope:** read-only first, or read/write from day one? Recommended: **read steps/sleep/weight, write water/weight/workout**.
5. **Live Activity:** full fast or eating window? Recommended: **eating window / short fasts**, plus a lock-screen widget for 16:8.
6. **iPad:** full responsive support or “compatible” only? Recommended: **responsive rail + two-column Today/Trends**.
7. **Apple Watch:** now, later, or never? Recommended: **after 3.0**, only if users ask.
8. **Monetisation:** free, one-time, or subscription? If subscription, design StoreKit 2 before launch.
9. **Localisation:** English only at launch, or English + Hindi + Spanish? Recommended: infrastructure now, translations after launch.
10. **Backend push:** local notifications only, or APNs + Supabase Edge Functions? Recommended: **local first**, push in 3.1.
11. **Brand font:** San Francisco on iOS + Inter on Android, or a single brand font everywhere? Recommended: **platform-native on iOS**, Inter on Android.
12. **Analytics:** none, privacy-friendly product analytics, or full analytics? Recommended: **opt-in, privacy-friendly, no health data**.

---

## 20. Quick-start checklist for the next coding session

If you want to start immediately, do these in order:

- [x] Create a branch `feature/ios-foundation`.
- [x] Add `CFBundleURLTypes` to `ios/Runner/Info.plist` (OAuth + `fitgo://`).
- [x] Add the Supabase redirect URL `com.fitgo.fitgo://login-callback`.
- [x] Add Sign in with Apple capability + `sign_in_with_apple`.
- [x] Replace `NotificationService.isSupported` with a cross-platform implementation.
- [x] Add `PrivacyInfo.xcprivacy` and `Runner.entitlements`.
- [x] Set iPhone portrait-only and iOS 16 deployment target.
- [x] Add Android scheduled/action/boot notification receivers.
- [x] Isolate local Hive data per account and add the outbox.
- [x] Fix light-theme button contrast and add contrast tests.
- [ ] Build on a Mac/CI and upload the first TestFlight build.
- [x] Start Phase 1 with `FitGoTokens`, `FitGoCard`, and the adaptive `go_router` shell.
- [x] Add the midnight watcher and resume day-rollover refresh.
- [x] Add the optional, account-scoped Gemini coach with secure key storage, consent, and automatic model fallback.
- [ ] Run a real-key Gemini smoke test on Android and iOS; update App Privacy and Play Data safety answers.
- [ ] Run the real-device matrix: Apple/Google/email sign-in, password reset, reminder delivery, overnight midnight rollover, and account switching.
- [ ] Publish Terms/Privacy URLs and complete the account-deletion + Apple token revocation flow.

---

*This document is intentionally detailed. Treat it as a living plan: check off items, add decisions, and update estimates as the app evolves.*
