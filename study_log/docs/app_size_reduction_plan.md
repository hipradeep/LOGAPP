# StudyLog App Size Reduction Plan

## 1. Executive Summary & Diagnosis

The current release APK size is **57.7 MB** (`60,471,580 bytes`).
Our target is to reduce single-device release APK size to **~16–18 MB** (over **68% reduction**) and Google Play install size to **~12–15 MB**.

### Root Cause Analysis of 57.7 MB Fat APK
| Factor | Size Contribution | Why It Is Happening |
|---|---|---|
| **Multi-ABI Bundling (Fat APK)** | **~42 MB** (~70%) | Default `flutter build apk` packages native shared libraries (`libflutter.so`, `libapp.so`) for **3 architectures** (`arm64-v8a`, `armeabi-v7a`, `x86_64`) into a single universal APK. |
| **Disabled R8 Minification** | **~3–5 MB** | In [android/app/build.gradle.kts](file:///c:/Users/hipradeep/Documents/android_apps/log_app/study_log/android/app/build.gradle.kts#L35-L46), `isMinifyEnabled = true` is absent. Unused classes from `googleapis`, `google_sign_in`, `desugar_jdk_libs`, `flutter_local_notifications`, and AndroidX remain unstripped. |
| **Disabled Resource Shrinking** | **~1–2 MB** | `isShrinkResources = true` is absent, retaining unused drawables, layouts, and strings from third-party Android dependencies. |
| **Unstripped Dart Symbols** | **~2–3 MB** | Symbol tables and debug metadata are embedded inside `libapp.so` instead of being split into separate debug files. |
| **Uncompressed Assets** | **~0.15 MB** | `splash_logo.png` is currently an uncompressed PNG (165 KB). |

---

## 2. Target Size Benchmark

| Build Target | Current Size | Target Size | Reduction |
|---|---|---|---|
| **Universal Fat APK** (`app-release.apk`) | 57.7 MB | ~48–50 MB | ~15% |
| **ARM64 APK** (`app-arm64-v8a-release.apk`) *(95%+ of modern devices)* | *(bundled)* | **~16–18 MB** | **~70%** |
| **ARMv7 APK** (`app-armeabi-v7a-release.apk`) *(legacy 32-bit devices)* | *(bundled)* | **~15–17 MB** | **~72%** |
| **x86_64 APK** (`app-x86_64-release.apk`) *(emulators & ChromeOS)* | *(bundled)* | **~17–19 MB** | **~67%** |
| **Google Play App Bundle** (`.aab` / dynamic delivery) | *(n/a)* | **~12–15 MB** | **~75%** |

---

## 3. Implementation Phases

### Phase 1: Gradle R8 Code Minification & Resource Shrinking
**Target File**: [android/app/build.gradle.kts](file:///c:/Users/hipradeep/Documents/android_apps/log_app/study_log/android/app/build.gradle.kts) & [android/app/proguard-rules.pro](file:///c:/Users/hipradeep/Documents/android_apps/log_app/study_log/android/app/proguard-rules.pro)

1. Enable R8 minifier and resource shrinker in Kotlin DSL:
   ```kotlin
   buildTypes {
       release {
           signingConfig = signingConfigs.getByName("debug")
           isMinifyEnabled = true
           isShrinkResources = true
           proguardFiles(
               getDefaultProguardFile("proguard-android-optimize.txt"),
               "proguard-rules.pro"
           )
       }
   }
   ```
2. Audit and update [proguard-rules.pro](file:///c:/Users/hipradeep/Documents/android_apps/log_app/study_log/android/app/proguard-rules.pro) to ensure zero runtime crashes:
   - Preserve `flutter_local_notifications` and `Gson` models (already configured).
   - Preserve `google_sign_in` / `googleapis` credentials and HTTP client serializers.
   - Preserve `sqflite` native JNI bridge.

### Phase 2: ABI Architecture Splitting
**Target File**: Build commands & CI/distribution scripts

1. **Split-Per-ABI Configuration**:
   Instead of generating a monolithic fat APK, compile dedicated APKs tailored to device CPU architectures:
   ```bash
   flutter build apk --split-per-abi
   ```
   This generates:
   - `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
   - `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`
   - `build/app/outputs/flutter-apk/app-x86_64-release.apk`

2. **App Bundle (`.aab`) for Google Play**:
   For official store distribution:
   ```bash
   flutter build appbundle
   ```
   Google Play's Dynamic Delivery automatically delivers only the required ABI and screen density assets to each user's phone.

### Phase 3: Dart AOT Obfuscation & Debug Symbol Stripping
**Target File**: Build commands

1. Extract and strip Dart symbol tables from `libapp.so`:
   ```bash
   flutter build apk --split-per-abi --obfuscate --split-debug-info=build/app/outputs/symbols
   ```
   - Shaves **~1.5–2.5 MB** off `libapp.so`.
   - Generates symbols files in `build/app/outputs/symbols` for stack trace de-obfuscation if needed.

### Phase 4: Asset & Dependency Hygiene
**Target File**: [study_log/assets/images/splash_logo.png](file:///c:/Users/hipradeep/Documents/android_apps/log_app/study_log/assets/images/splash_logo.png) & [pubspec.yaml](file:///c:/Users/hipradeep/Documents/android_apps/log_app/study_log/pubspec.yaml)

1. **Splash Logo Compression**:
   - Convert `splash_logo.png` (165 KB) into optimized WebP or lossless compressed PNG (~50 KB).
2. **Icon Tree-shaking Verification**:
   - Confirm `--tree-shake-icons` strips all unreferenced Material & Cupertino glyphs.
3. **Dependency Check**:
   - Verified: `google_fonts` already purged in the previous phase (0 runtime font download/bundling overhead).

---

## 4. Verification & Testing Checklist

- [ ] **Static Code Analysis**: Run `flutter analyze` inside `study_log/` to ensure 0 diagnostics.
- [ ] **Gradle Configuration Test**: Verify `build.gradle.kts` syntax and R8 configuration.
- [ ] **Release Build Execution**: Run `flutter build apk --split-per-abi --obfuscate --split-debug-info=build/app/outputs/symbols`.
- [ ] **Runtime Sanity Check**: Verify that R8 shrinking did not break:
  - Local notifications scheduling
  - SQLite database read/write
  - Google Sign-In & Google Drive backup
- [ ] **Size Comparison Table**: Record and compare file sizes before and after optimization.
