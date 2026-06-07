# Android 12+ (API 31+) Splash Screen Setup & Fix

This guide covers how to set up the Android Splash Screen API correctly on Android 12+ (API 31+), resolving common issues like raw app icons nesting inside white circular/rounded-square masks, size constraints, and Dark Mode theme precedence bugs.

---

## The Problems & Root Causes

### 1. Nested Square/White Border Icon Mask
On Android 12+, the OS automatically masks the splash screen icon into a circular or rounded-square shape. If the app icon specified by `android:windowSplashScreenAnimatedIcon` is a legacy/opaque launcher icon, its square background shows inside the container mask.

### 2. Quiet Fallback due to Large Images
The splash screen runs in the Android system server process before your app process is launched. It has strict size and memory constraints. Using a high-resolution PNG (e.g. `1024x1024 px`) will fail decoding in the system server, causing it to quietly fall back to your app's default launcher icon (`@mipmap/ic_launcher`).

### 3. Dark Mode ignoring `values-v31/styles.xml`
Android's resource qualifier matching rules state that **Night Mode (`-night`) has higher precedence than API Level (`-v31`)**. 
If a device is in Dark Mode and runs Android 12+:
1. Android looks for `values-night-v31/styles.xml` (does not exist by default).
2. It prefers the `-night` qualifier over `-v31` and loads from `values-night/styles.xml`.
3. Since `values-night/styles.xml` usually does not have Splash Screen API properties, it defaults to using the launcher icon on a white background mask.

---

## Step-by-Step Resolution

### Step 1: Create a Properly Scaled Splash Icon
Export your logo with a **transparent background** and scale it down to meet Android's splash limits.
* Size target: **288x288 px** (Fits within a 192dp circular container).
* Format: PNG or Vector Drawable XML.
* Place it in: `android/app/src/main/res/drawable/ic_splash.png` (or `.xml`).

### Step 2: Configure styles.xml for Light Mode (API 31+)
Create or update `android/app/src/main/res/values-v31/styles.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <!-- Main splash screen background color -->
        <item name="android:windowSplashScreenBackground">@color/launch_background</item>
        
        <!-- Optimized transparent splash icon (288x288 px) -->
        <item name="android:windowSplashScreenAnimatedIcon">@drawable/ic_splash</item>
        
        <!-- Matches the background color to blend and hide the icon container mask -->
        <item name="android:windowSplashScreenIconBackgroundColor">@color/launch_background</item>
        
        <item name="android:windowBackground">@drawable/launch_background</item>
    </style>
</resources>
```

### Step 3: Configure styles.xml for Dark Mode (API 31+)
To prevent Android from preferring `values-night/styles.xml` and losing your splash settings, create the specific combined qualifier file `android/app/src/main/res/values-night-v31/styles.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Black.NoTitleBar">
        <!-- Main splash screen background color (Dark) -->
        <item name="android:windowSplashScreenBackground">@color/launch_background</item>
        
        <!-- Optimized transparent splash icon (288x288 px) -->
        <item name="android:windowSplashScreenAnimatedIcon">@drawable/ic_splash</item>
        
        <!-- Matches the background color to blend and hide the icon container mask -->
        <item name="android:windowSplashScreenIconBackgroundColor">@color/launch_background</item>
        
        <item name="android:windowBackground">@drawable/launch_background</item>
    </style>
</resources>
```

### Step 4: Clear OS Splash Cache & Rebuild
Android caches splash screens aggressively. You must clear the cache to verify the changes:

1. **Uninstall the app** from the device or emulator.
2. Clear the build cache:
   ```bash
   flutter clean
   ```
3. Run the app:
   ```bash
   flutter run
   ```
