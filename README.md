# FitGo — Your Path to Fitness

A comprehensive, offline-first fitness tracking app built with Flutter. Track calories, fasting, water intake, exercise, sleep, and weight — all with smart weekly budget management and advanced analytics.

---

## Features

### Calorie Management
- **Weekly Calorie Budget** — Set a weekly target (e.g., 7500 kcal/week), app auto-calculates daily quota
- **Smart Redistribution** — Eat less today? Tomorrow's allowance increases automatically
- **Quick Add Buttons** — +100, +250, +500 kcal with one tap, or enter custom amounts
- **Net Calories** — `Eaten - Burned = Net` — the number that actually matters

### Intermittent Fasting Timer
- **Radial Dial** — Beautiful red-to-amber gradient that fills as your fast progresses
- **Timestamp Delta** — Survives app kills, restarts, and OS battery optimization
- **Flexible Presets** — 16:8, 18:6, 20:4
- **Edit Start/End Time** — Forgot to start? Set "I started earlier" anytime
- **Overtime Counter** — Shows how long you've fasted past your goal

### Activity Tracking
- **Step Counter** — Enter steps from Google Fit/Apple Health, auto-calculates calories burned and distance
- **Exercise Logger** — 12 preset activities (Running, Cycling, Gym, Yoga, HIIT, Swimming, etc.) with MET-based calorie burn calculations
- **Sleep Tracker** — Log bedtime & wake time, quality indicator (Great/Okay/Low), 8h target tracking

### Water Tracker
- **Quick +250ml** button with glass indicators
- **Dynamic goals** based on body weight (~35ml per kg)
- **Progress bar** with milestone alerts

### Weight Tracker
- **Manual weight logging** with trend chart (fl_chart)
- **BMI auto-calculation** with color-coded categories

### Analytics Dashboard
- **Consistency Score** — 0-100 ring showing how well you hit daily targets
- **Cumulative Trend Chart** — Your actual intake vs ideal pace (line + area chart)
- **Daily Bar Chart** — Color-coded bars with dashed target line
- **Weekly Heatmap** — 7 colored squares showing daily performance at a glance
- **Day-by-Day Expandable List** — Tap any day for full breakdown (calories, water, entries)
- **Smart Insights Engine** — Auto-generated tips: streak detection, consistency analysis, variance alerts, hydration checks, budget redistribution advice
- **Week-End Projection** — Predicts if you'll finish under or over budget

### Personalized Onboarding
- **DOB Picker** — Auto-calculates age
- **Weight & Height Sliders** — Interactive, live TDEE preview
- **Goal Selection** — Lose / Maintain / Gain / Custom budget
- **Full Math Breakdown** — Shows deficit calculation, expected weight loss per week/month/3 months, projected weight timeline
- **Safety Warnings** — Alerts if daily intake drops below 1200 kcal

### Profile & Settings
- **BMI Display** with color scale (Underweight / Normal / Overweight / Obese)
- **Inline Editing** — Tap any stat to edit (weight, height, weekly goal, water goal)
- **Sync Status** — Shows Connected/Offline
- **Redo Full Setup** option

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart) |
| State Management | Riverpod |
| Local Storage | Hive (offline-first) |
| Backend | Supabase (Auth + PostgreSQL) |
| Charts | fl_chart |
| Auth | Email/Password + Google OAuth |

---

## Architecture

```
lib/
├── main.dart                          # Entry point — init Hive + Supabase
├── app.dart                           # Auth gate -> Profile gate -> Dashboard
├── core/
│   ├── constants.dart                 # Goals, presets, step sizes
│   ├── theme.dart                     # Dark navy + amber flame theme
│   ├── utils.dart                     # Duration formatters
│   └── supabase_config.dart           # Supabase URL + anon key
├── models/
│   ├── daily_metrics.dart             # Hive model — all daily data
│   ├── user_profile.dart              # Profile with BMR/TDEE calculations
│   └── weight_entry.dart              # Weight history
├── providers/
│   ├── storage_provider.dart          # LocalStorage injection
│   ├── profile_provider.dart          # User profile + cloud sync
│   ├── calorie_provider.dart          # Calorie tracking
│   ├── water_provider.dart            # Water tracking
│   ├── timer_provider.dart            # Fasting timer (timestamp delta)
│   ├── weight_provider.dart           # Weight logging
│   ├── weekly_provider.dart           # Weekly analytics + insights engine
│   └── activity_provider.dart         # Steps, exercise, sleep
├── services/
│   ├── local_storage.dart             # Hive wrapper
│   └── supabase_service.dart          # Auth + cloud sync
├── widgets/
│   ├── radial_dial.dart               # Custom painted fasting dial
│   └── weight_chart.dart              # fl_chart line chart
└── screens/
    ├── auth_screen.dart               # Login / Signup / Google OAuth
    ├── onboarding_screen.dart         # 4-step setup wizard
    ├── home_screen.dart               # Dashboard with all feature cards
    ├── analytics_screen.dart          # Charts, insights, projections
    └── profile_screen.dart            # View/edit profile, BMI, logout
```

---

## Key Design Decisions

**Offline-First** — All data lives in Hive locally. Supabase sync is optional and runs in the background. App works perfectly without internet.

**Timestamp Delta for Fasting** — Instead of running background timers (battery drain), we store `T_start_epoch` in Hive. On app reopen: `elapsed = DateTime.now() - T_start_epoch`. The OS can kill the app — time still passes.

**Weekly Budget Redistribution** — Daily target = `(weekly_goal - calories_consumed_so_far) / remaining_days`. Eat less Monday, more allowance Tuesday. The math forces consistency.

**MET-Based Exercise Calories** — `Calories = MET x weight(kg) x hours`. Scientifically accurate for 12 activity types.

**Net Calories** — The dashboard shows `Eaten - Burned = Net`, not just intake. This is what determines weight change.

---

## Setup

### Prerequisites
- Flutter SDK (3.x+)
- Dart SDK
- A Supabase project (free tier works)

### Installation

```bash
# Clone the repo
git clone https://github.com/YOUR_USERNAME/FitGo.git
cd FitGo

# Install dependencies
flutter pub get

# Generate Hive adapters
dart run build_runner build --delete-conflicting-outputs

# Run the app
flutter run
```

### Supabase Setup

1. Create a project at [supabase.com](https://supabase.com)
2. Run the SQL from `supabase_setup.sql` in SQL Editor (creates tables + RLS policies)
3. Update `lib/core/supabase_config.dart` with your project URL and anon key
4. Enable Google OAuth in Authentication > Providers > Google

### Build APK

```bash
flutter build apk --release
```

APK output: `build/app/outputs/flutter-apk/app-release.apk`

---

## Calorie Science

The app uses the **Mifflin-St Jeor** equation for BMR:

```
Male:   BMR = 10 x weight(kg) + 6.25 x height(cm) - 5 x age + 5
Female: BMR = 10 x weight(kg) + 6.25 x height(cm) - 5 x age - 161
```

**TDEE** = BMR x 1.4 (sedentary multiplier)

**Weight change**: 7,700 kcal deficit = ~1 kg fat loss

---

## Download

Get the latest APK from the [Releases](../../releases) page.

---

## License

MIT License — free to use, modify, and distribute.

---

Built with Flutter + Riverpod + Hive + Supabase + fl_chart
