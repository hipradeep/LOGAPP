# Budget App - Firebase Android Implementation Plan

## 1. Overview & Specifications

* **App Name**: `Budget`
* **Package / Application ID**: `in.logapp.budget`
* **Root Folder**: `budget_app/` (located in workspace root alongside `log_app_offline` and `log_app_firebase`)
* **Platform**: Android only (Flutter-based)
* **Backend**: **Firebase Cloud Firestore** (100% cloud-synced, zero offline SQLite database)
* **Currency**: Exclusively **Indian Rupee (₹ / INR)** formatted with Indian numbering system (`en_IN`, e.g., ₹ 50,000 / ₹ 1,25,000)
* **Home Page Title**: **"Budget/Log"**
* **Bottom Navigation**: Persistent 4-tab glassmorphic navigation bar:
  1. 🏠 **Home**: Header "Budget/Log", monthly salary, budget summary cards, spent progress bar, category spending donut chart, recent transactions preview, and quick actions.
  2. 💳 **Budget**: Detailed active budget progress, daily & monthly expense graphs, category-wise breakdown sheets, and budget switcher.
  3. 📜 **Log**: Full searchable transaction ledger with date range, category, payment mode filters, and quick transaction FAB.
  4. 👤 **Profile**: Profile settings, avatar & username customization, Manage Budgets, Expense Categories, Payment Modes, Theme Switcher, and App Info.
* **Design & Theming**:
  * Glassmorphism styling (`FullScreenPage`, `BackdropFilter`, blurred modals)
  * Dynamic multi-theme system (Classic Light, Classic Dark, Orix Gold, Teal Logo, Forest Earth)
  * Strict compliance with modern Flutter styling: zero `.withOpacity()`, exclusively using `.withValues(alpha: ...)`
  * Spacing strictly powered by `AppSpacers` (`VGapSm()`, `HGapMd()`, etc.)
* **State Management**: Pure zero-dependency `ChangeNotifier` + `ListenableBuilder` / `AppProvider` pattern.
* **Execution Constraint**: Non-blocking implementation — do not run build analysis or long-running commands that block execution.

---

## 2. Architecture & Directory Tree

```
budget_app/
├── android/
│   ├── app/
│   │   ├── build.gradle.kts           # namespace & applicationId = "in.logapp.budget", plugin: com.google.gms.google-services
│   │   ├── google-services.json       # Firebase project logapp-c7867 configured for in.logapp.budget
│   │   └── src/main/AndroidManifest.xml # android:label="Budget", INTERNET permission
│   ├── build.gradle.kts
│   └── settings.gradle.kts            # com.google.gms.google-services plugin registered
├── pubspec.yaml                       # firebase_core, cloud_firestore, intl, google_fonts, uuid, path_provider, cupertino_icons
└── lib/
    ├── firebase_options.dart          # DefaultFirebaseOptions configured for Android in.logapp.budget
    ├── main.dart                      # Firebase.initializeApp(), ThemeController, MainNavigationScreen root
    ├── models/
    │   └── budget.dart                # Budget & Transaction models with Firestore serialization (Timestamp, DocumentSnapshot)
    ├── controllers/
    │   ├── budget_controller.dart     # Reactive controller subscribing to live Firestore streams
    │   └── theme_controller.dart      # Reactive theme manager (Light, Dark, Orix, Logo, Earth)
    ├── services/
    │   ├── budget_service.dart        # Firestore CRUD & reactive snapshot streams for budgets, transactions, & salary
    │   └── preferences_service.dart   # Firestore metadata & local cache for categories, payment modes, and theme
    ├── theme/
    │   └── app_theme.dart             # Curated design system (all colors using .withValues(alpha: ...))
    ├── utils/
    │   ├── date_utils.dart            # Date range and formatting helpers
    │   ├── id_utils.dart              # UUID generation helper
    │   └── responsive.dart            # Screen size and responsive helpers
    ├── widgets/
    │   ├── full_screen_page.dart      # Glassmorphic full-screen container with scaffold & header actions
    │   ├── app_spacers.dart           # Strict spacing tokens (VGap, HGap)
    │   ├── app_provider.dart          # Zero-dependency InheritedNotifier
    │   ├── app_premium_fab.dart       # Gradient floating action button
    │   ├── app_empty_state.dart       # Empty state placeholder
    │   ├── app_title_input.dart       # Title input with underline/border
    │   ├── app_title_dropdown.dart    # Styled dropdown selector
    │   ├── app_text_action_button.dart# Header action button
    │   ├── app_popup_menu_button.dart # Custom popup menu
    │   ├── app_binary_toggle.dart     # Two-way pill toggle
    │   ├── app_action_buttons.dart    # Cancel/Save action button row
    │   ├── app_toast.dart             # Toast utility
    │   ├── app_tooltip.dart           # Tooltip utility
    │   ├── glow_blob.dart             # Ambient background blur blob
    │   ├── glass_modal_sheet.dart     # Glassmorphic bottom sheet wrapper
    │   ├── budget_progress_bar.dart   # Budget limit vs spent progress indicator
    │   ├── budget_expense_graph.dart  # Multi-period expense line/bar chart
    │   ├── budget_daily_expense_graph.dart # Daily expense breakdown chart
    │   ├── budget_monthly_expense_graph.dart # Monthly expense breakdown chart
    │   ├── expense_donut_chart.dart   # Category expense donut chart
    │   ├── category_breakdown_sheet.dart # Modal sheet with category-wise spending
    │   ├── add_transaction_sheet.dart # Bottom sheet to log expenses/credits to Firestore
    │   └── transaction_filter_sheet.dart # Modal sheet to filter transactions
    └── screens/
        ├── main_navigation_screen.dart # Persistent bottom navigation with 'Home / Budget / Log / Profile'
        ├── home_screen.dart           # Home page titled 'Budget/Log' with salary, summary cards, donut chart, quick actions
        ├── budget_screen.dart         # Detailed budget limits, progress bar, daily/monthly graphs, and category breakdown
        ├── log_screen.dart            # Full transaction ledger with search, filtering, and add transaction FAB
        ├── profile_screen.dart        # Profile & settings (Budgets, Categories, Payment Modes, Themes, App Info)
        ├── add_budget_screen.dart     # Create & edit budget in Firestore
        ├── manage_budget_screen.dart  # Budget list management, switch active budget, quick links
        ├── expense_category_screen.dart # Manage custom expense categories
        ├── payment_mode_screen.dart   # Manage custom payment modes
        ├── theme_selection_screen.dart # Theme switcher (Dark, Light, Orix Gold, Teal Logo, Forest Earth)
        └── splash_screen.dart         # Animated splash screen
```

---

## 3. Firestore Schema Design

### Collection: `budgets`
* `id`: Document ID
* `name`: `String` (e.g. "Monthly Budget", "Vacation")
* `categoryName`: `String` (e.g. "Expenses", "Travel")
* `limit`: `double` (amount in ₹ INR)
* `period`: `String` (`'daily'`, `'weekly'`, `'monthly'`, `'custom'`)
* `description`: `String`
* `repeatDays`: `List<int>`
* `scheduledTime`: `String?`
* `startDate`: `Timestamp?`
* `endDate`: `Timestamp?`
* `repeat`: `bool`
* `isActive`: `bool`
* `alertThreshold`: `double` (e.g. `0.7` for 70%)
* `createdAt`: `FieldValue.serverTimestamp()`

### Collection: `transactions`
* `id`: Document ID
* `budgetId`: `String`
* `tag`: `String` (category label, e.g. "Grocery", "Dining", "Bills")
* `description`: `String`
* `merchant`: `String?` (e.g. "Amazon", "Swiggy", "DMart")
* `type`: `String` (`'expense'`, `'income'`, `'transfer'`)
* `amount`: `double` (value in ₹ INR)
* `entryDate`: `Timestamp`
* `expenseDate`: `Timestamp`
* `isValidated`: `bool`
* `rawBody`: `String?`
* `paymentMethod`: `String` (e.g. "Cash", "PNB", "UPI", "ICICI")
* `createdAt`: `FieldValue.serverTimestamp()`

### Collection: `metadata`
* Document `budget_settings`: `{ "monthlySalary": 50000.0 }`
* Document `expense_categories`: `{ "categories": [ ... ] }`
* Document `payment_modes`: `{ "modes": [ ... ] }`

---

## 4. Step-by-Step Execution Plan

### Step 1: Scaffold Flutter Project
* Run `flutter create --org in.logapp --project-name budget --platforms android budget_app`
* Update `pubspec.yaml` with required dependencies:
  * `firebase_core: ^3.0.0`
  * `cloud_firestore: ^5.0.0`
  * `google_fonts: ^8.0.2`
  * `intl: ^0.20.2`
  * `uuid: ^4.4.0`
  * `path_provider: ^2.1.0`
  * `cupertino_icons: ^1.0.8`
* Run `flutter pub get` non-interactively.

### Step 2: Configure Android Native & Firebase Layer
* In `budget_app/android/settings.gradle.kts`:
  * Add Google services gradle plugin: `id("com.google.gms.google-services") version "4.4.1" apply false`
* In `budget_app/android/app/build.gradle.kts`:
  * Verify `namespace = "in.logapp.budget"` and `applicationId = "in.logapp.budget"`
  * Add `id("com.google.gms.google-services")` plugin
  * Configure Java 17 compatibility and core library desugaring
* In `budget_app/android/app/src/main/AndroidManifest.xml`:
  * Set `android:label="Budget"`
  * Add `<uses-permission android:name="android.permission.INTERNET" />`
* Create `budget_app/android/app/google-services.json` targeting `in.logapp.budget` on project `logapp-c7867`.
* Create `budget_app/lib/firebase_options.dart` with standard platform options for project `logapp-c7867`.

### Step 3: Implement Foundation (Theme, Spacers & Utilities)
* `lib/theme/app_theme.dart`: Design system supporting Dark, Light, Orix Gold, Teal Logo, and Forest Earth, strictly with `.withValues(alpha: ...)`.
* `lib/utils/date_utils.dart`, `id_utils.dart`, `responsive.dart`: Core formatting & responsive helpers.
* `lib/services/preferences_service.dart`: Theme and metadata sync with Firestore and local fallback cache.

### Step 4: Implement Models, Firebase Services & Controllers
* `lib/models/budget.dart`: `Budget` & `Transaction` models with Firestore `fromFirestore` and `toFirestore`.
* `lib/services/budget_service.dart`: Native live Firestore stream listeners and CRUD methods.
* `lib/controllers/budget_controller.dart`: Reactive controller coordinating live budget and transaction streams.
* `lib/controllers/theme_controller.dart`: Dynamic theme switcher controller.

### Step 5: Implement UI Widgets
* Containers: `full_screen_page.dart`, `glass_modal_sheet.dart`, `glow_blob.dart`.
* Controls: `app_premium_fab.dart`, `app_spacers.dart`, `app_provider.dart`, `app_title_input.dart`, `app_title_dropdown.dart`, `app_text_action_button.dart`, `app_popup_menu_button.dart`, `app_binary_toggle.dart`, `app_action_buttons.dart`, `app_empty_state.dart`.
* Analytics: `budget_progress_bar.dart`, `budget_expense_graph.dart`, `budget_daily_expense_graph.dart`, `budget_monthly_expense_graph.dart`, `expense_donut_chart.dart`.
* Modals: `category_breakdown_sheet.dart`, `add_transaction_sheet.dart`, `transaction_filter_sheet.dart`.

### Step 6: Implement Screens & Bottom Navigation
* `screens/main_navigation_screen.dart`: Persistent glassmorphic bottom bar switching between:
  1. `screens/home_screen.dart`: Title **"Budget/Log"**, salary status, spend progress bar, safe-to-spend allowance, donut chart, recent transactions.
  2. `screens/budget_screen.dart`: Detailed budget list, progress tracking, daily/monthly charts, category breakdown.
  3. `screens/log_screen.dart`: Full transaction log, date range & category filters, search bar, add transaction FAB.
  4. `screens/profile_screen.dart`: Profile details, avatar picker, Manage Budgets, Categories, Payment Modes, Theme Switcher, and App Info.
* Subscreens: `add_budget_screen.dart`, `manage_budget_screen.dart`, `expense_category_screen.dart`, `payment_mode_screen.dart`, `theme_selection_screen.dart`, `splash_screen.dart`.
* `lib/main.dart`: App entry point with `Firebase.initializeApp()`, `ThemeController`, and `MainNavigationScreen`.

### Step 7: Final File Verification
* Non-blocking file integrity check to verify all files are created and cleanly linked without running blocking build analysis.

---

## 7. Execution Status Summary

* [x] **Project Scaffolding**: `budget_app` created with package `in.logapp.budget` and Android platform support.
* [x] **Android Native Layer**: Configured `build.gradle.kts`, `settings.gradle.kts`, `AndroidManifest.xml`, and `google-services.json` (Firebase project `logapp-c7867`).
* [x] **Dependencies**: `pubspec.yaml` configured and `flutter pub get` completed.
* [x] **Design System & Utilities**: `AppTheme` (all `.withValues(alpha: ...)`), `AppSpacers`, `AppProvider`, date, ID, and responsive utilities.
* [x] **Cloud Backend & Services**: `budget_service.dart`, `preferences_service.dart`, `budget_controller.dart`, `theme_controller.dart`.
* [x] **Charts & Glassmorphic UI Widgets**: 23 reusable widgets created (charts, bottom sheets, FAB, inputs, toggles, spacers).
* [x] **Core Screens & Navigation**: 4-tab glassmorphic bottom bar (`Home` with header "Budget/Log", `Budget`, `Log`, `Profile`), plus full sub-screens (`AddBudget`, `ManageBudget`, `ExpenseCategory`, `PaymentMode`, `ThemeSelection`, `SplashScreen`).
* [x] **App Root**: `main.dart` initialized with Firebase and dynamic multi-theme engine.

