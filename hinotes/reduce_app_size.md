# Reducing Flutter App Size (firebase & offline variants)

This document provides a comprehensive guide on how to optimize and significantly reduce the binary size of both the Firebase and Offline variants of the Log App.

---

## 1. Android Release Build Optimization

The most immediate reduction in app download and install size comes from how the release binaries are built.

### A. Use Android App Bundles (AAB)
Instead of building a universal fat APK, always build an Android App Bundle for production deployment. Google Play uses the AAB to serve optimized APKs tailored to each user's device architecture (ABI) and screen density.

```bash
flutter build appbundle --release
```

### B. Split APKs by ABI (for Direct Distribution)
If you need to distribute APKs directly (e.g., for testing or self-hosting) instead of through Google Play, avoid the universal APK. Build separate APKs for each CPU architecture:

```bash
flutter build apk --split-per-abi --release
```
This generates three separate APKs (for `armeabi-v7a`, `arm64-v8a`, and `x86_64`), reducing the download size by up to 60% per file.

---

## 2. Code Shrinking & Obfuscation

Obfuscation renames classes and members to short names, reducing the binary size of the Dart code and stripping debug info.

### A. Dart Code Obfuscation
Compile release builds with obfuscation and strip debug symbols:

```bash
flutter build apk --obfuscate --split-debug-info=build/app/outputs/symbols
```

### B. Enable R8 / Proguard (Android)
Since `log_app_firebase` relies on Firebase SDKs (`firebase_core` and `cloud_firestore`), the native Java/Kotlin dependency footprint is large. Enabling Proguard/R8 is critical to strip unused native bytecode.

Ensure the following configuration is set in `log_app_firebase/android/app/build.gradle`:

```groovy
android {
    buildTypes {
        release {
            signingConfig signingConfigs.release
            
            // Enable code shrinking, obfuscation, and optimization
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}
```

---

## 3. Asset & Resource Optimization

Assets (images, fonts) are often the largest contributors to app size.

### A. Image Compression
- Convert large PNG/JPEG files to **WebP** format. WebP offers superior lossless and lossy compression.
- Run assets through compression tools like [TinyPNG](https://tinypng.com/) before committing them.
- In this project, `assets/images/splash_logo.png` can be optimized or converted to WebP.

### B. Font Pruning
- The project uses the `google_fonts` package. Google Fonts downloads font files dynamically at runtime and caches them locally, which keeps the initial installation footprint very small.
- If you bundle static fonts in `pubspec.yaml`, ensure you only include the styles and weights you actually use (e.g., regular and bold) and avoid importing the entire font family.
- Avoid using `.ttf` or `.otf` if compressed formats are supported, or run them through a subsetting tool (like `pyftsubset`) to strip unused glyphs.

### C. Icon Tree Shaking
Flutter automatically tree-shakes material and cupertino icons in release builds, removing unused icons from the font files. Ensure you do not disable this default behavior.

---

## 4. Package & Dependency Audit

Heavy dependencies can silently bloat the application.

### A. Analyze Dependency Size
Run the following commands to inspect dependencies and their sizes:

```bash
# View dependency tree to identify heavy transitive dependencies
flutter pub deps

# Build and generate a size analysis report
flutter build apk --analyze-size
flutter build appbundle --analyze-size
```
This output provides a breakdown of exactly how many bytes are contributed by the Dart code, assets, package dependencies, and native engines.

### B. Avoid Bloated Packages
- Ensure state management remains zero-dependency as per the custom `AppProvider`/`ChangeNotifier` design. Do not add heavy state packages (Provider, Riverpod, Bloc, GetX) which add overhead.
- For tasks like formatting or helper utilities, write simple custom helpers instead of importing large utility libraries.

---

## 5. Deferred Loading (Lazy Loading)

For larger features or screens that are not needed on initial startup (e.g., heavy chart screens, historical reports), load the code dynamically when the user accesses them.

```dart
// Import the library as deferred
import 'package:log/screens/heavy_reporting_screen.dart' deferred as heavy_report;

// Load before navigating
await heavy_report.loadLibrary();
Navigator.of(context).push(
  MaterialPageRoute(builder: (context) => heavy_report.HeavyReportingScreen()),
);
```
This splits the Dart compiled binary into multiple smaller parts, loading them on-demand.
