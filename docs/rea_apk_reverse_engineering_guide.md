# REA (Reverse Engineer Anything) Android APK Setup Guide

This guide provides end-to-end instructions for configuring **[morluto/rea](https://github.com/morluto/rea)** (Reverse Engineer Anything) to reverse-engineer Android applications, specifically targeting **Time Balance** (`com.cetinkaya.time_balance`).

---

## 1. Overview & Architecture

REA is an MCP (Model Context Protocol) server and command-line suite that enables AI coding agents (Antigravity IDE, Claude Code, Cursor, Windsurf) and developers to inspect compiled binaries, mobile apps, and runtime behaviors with **evidence-backed outputs**.

For Android analysis, REA interfaces directly with a headless **JADX engine** (`jadx-headless-mcp`) without needing the JADX GUI:
- **Manifest Extraction**: Decodes permissions, exported activities, services, broadcast receivers, and application metadata.
- **Decompilation**: Translates Dalvik bytecode into high-level Java/Kotlin source trees on demand.
- **Symbol & Reference Tracing**: Identifies calls, class hierarchies, and usage patterns across the entire APK.

```
+-------------------------------------------------------------+
| AI Agent / Terminal (Antigravity IDE, Claude Code, CLI)     |
+------------------------------+------------------------------+
                               | (MCP Protocol / CLI queries)
                               v
+-------------------------------------------------------------+
| REA (rea-agents npm package)                                |
+------------------------------+------------------------------+
                               |
                               v
+-------------------------------------------------------------+
| Headless JADX Engine (jadx-headless-mcp-0.7.1-all.jar)     |
| Powered by Java JDK 17+                                     |
+------------------------------+------------------------------+
                               |
                               v
+-------------------------------------------------------------+
| Target APK (time_balance.apk)                               |
+-------------------------------------------------------------+
```

---

## 2. Environment Prerequisites

Ensure the following tools are installed on Windows:

| Requirement | Minimum Version | Verified Path on System |
| :--- | :--- | :--- |
| **Node.js** | `>= 22.x` | `v25.4.0` |
| **Java JDK** | `JDK 17+` | `C:\Program Files\Java\jdk-17.0.12` |
| **Android ADB** | Platform-Tools | `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe` |

---

## 3. Step-by-Step Setup

### Step 1: Extract the APK from the Connected Android Device

If the target app is already installed on your physical device or emulator, extract it using ADB:

```powershell
# 1. Define paths
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$targetDir = "C:\Users\hipradeep\Documents\re_targets\time_balance"
New-Item -ItemType Directory -Force $targetDir | Out-Null

# 2. Verify device connection
& $adb devices

# 3. Locate package installation paths
& $adb shell pm path com.cetinkaya.time_balance

# 4. Pull base.apk into target folder
& $adb pull /data/app/~~MsYzCLDDOReKT8wrHOastQ==/com.cetinkaya.time_balance-_FC_YWayIJN2E44s0AAs3Q==/base.apk "$targetDir\time_balance.apk"

# (Optional) Pull split configs if analyzing resources/localized assets
& $adb pull /data/app/~~MsYzCLDDOReKT8wrHOastQ==/com.cetinkaya.time_balance-_FC_YWayIJN2E44s0AAs3Q==/ "$targetDir\splits\"
```

> **Alternative (Without Device)**: You can download the APK directly using services like APKMirror, APKPure, or the open-source Aurora Store client.

---

### Step 2: Download & Verify the Headless JADX JAR

REA requires `jadx-headless-mcp-0.7.1-all.jar` with a pinned SHA-256 integrity hash:

```powershell
# Destination path recommended by REA
$jarPath = Join-Path $HOME '.local\share\rea\android\jadx-headless-mcp-0.7.1-all.jar'
New-Item -ItemType Directory -Force (Split-Path $jarPath) | Out-Null

# Download the jar
Invoke-WebRequest -Uri 'https://github.com/1013503897/jadx-headless-mcp/releases/download/v0.7.1/jadx-headless-mcp-0.7.1-all.jar' -OutFile $jarPath

# Verify SHA-256 hash against REA pinned metadata
$expectedHash = '6e5eacf500b64292bfb73c49797c1958f6ee44646e43e868039ae7feb573ff75'
$actualHash = (Get-FileHash -Algorithm SHA256 $jarPath).Hash.ToLowerInvariant()

if ($actualHash -ne $expectedHash) {
    throw "Checksum mismatch! Expected: $expectedHash, Actual: $actualHash"
} else {
    Write-Host "Verified JADX MCP JAR successfully." -ForegroundColor Green
}
```

---

### Step 3: Install REA & Configure Environment Variables

1. Install `rea-agents` globally:
```powershell
npm install --global rea-agents
```

2. Set the environment variables permanently for the current user:
```powershell
[System.Environment]::SetEnvironmentVariable('JAVA_HOME', 'C:\Program Files\Java\jdk-17.0.12', 'User')
[System.Environment]::SetEnvironmentVariable('REA_JADX_MCP_JAR', "$HOME\.local\share\rea\android\jadx-headless-mcp-0.7.1-all.jar", 'User')

# Apply immediately to current PowerShell session
$env:JAVA_HOME = 'C:\Program Files\Java\jdk-17.0.12'
$env:REA_JADX_MCP_JAR = "$HOME\.local\share\rea\android\jadx-headless-mcp-0.7.1-all.jar"
```

---

### Step 4: Configure the MCP Server for AI Coding Agents

#### Option A: Antigravity IDE Configuration
Add the REA server entry into your global MCP configuration file:
`C:\Users\hipradeep\.gemini\antigravity-ide\mcp_config.json`:

```json
{
  "mcpServers": {
    "rea": {
      "command": "npx",
      "args": ["-y", "rea-agents@latest", "mcp"],
      "env": {
        "JAVA_HOME": "C:\\Program Files\\Java\\jdk-17.0.12",
        "REA_JADX_MCP_JAR": "C:\\Users\\hipradeep\\.local\\share\\rea\\android\\jadx-headless-mcp-0.7.1-all.jar"
      }
    }
  }
}
```

#### Option B: Automated Agent Registration Wizard
For other tools like Claude Code, Cursor, or Codex:
```powershell
npx rea-agents setup
```
Follow the interactive prompts to detect and install workflow rules and server bindings.

---

## 4. Practical Reverse-Engineering Workflows

Once the APK is pulled to `C:\Users\hipradeep\Documents\re_targets\time_balance\time_balance.apk`:

### 1. Package & Manifest Overview
Inspect package identity, SDK levels, permissions, and service declarations:
```powershell
rea inspect-android-package "C:\Users\hipradeep\Documents\re_targets\time_balance\time_balance.apk"
```

### 2. Search for Specific Features
Locate timer management, audio/vibration feedback, local database (Room/SQLite), or billing modules:
```powershell
# Search for timer logic
rea search-android-classes "C:\Users\hipradeep\Documents\re_targets\time_balance\time_balance.apk" Timer

# Search for Pomodoro state machine
rea search-android-classes "C:\Users\hipradeep\Documents\re_targets\time_balance\time_balance.apk" Pomodoro

# Search for storage / database DAOs
rea search-android-classes "C:\Users\hipradeep\Documents\re_targets\time_balance\time_balance.apk" Dao
```

### 3. Inspect Classes & Decompiled Code
Read the full decompiled class implementation:
```powershell
rea inspect-android-class "C:\Users\hipradeep\Documents\re_targets\time_balance\time_balance.apk" com.cetinkaya.time_balance.service.TimerService
```

### 4. Trace Method References
Understand where and how a particular method is triggered:
```powershell
rea trace-android-references "C:\Users\hipradeep\Documents\re_targets\time_balance\time_balance.apk" com.cetinkaya.time_balance.service.TimerService --method-name startTimer
```

---

## 5. Sample Agent Prompts

When pairing with an AI agent with REA enabled, you can ask direct architectural questions:

1. **Timer Architecture**:
   > *"Using REA, inspect `time_balance.apk`. How does the app handle background timing when the screen is turned off? Does it use a Foreground Service, AlarmManager, or WorkManager? Provide the decompiled evidence."*

2. **Data Model**:
   > *"Inspect `time_balance.apk` with REA and find the Room database entities for tracking Pomodoro sessions and project statistics. Show me the schema definitions."*

3. **Feature Recreation**:
   > *"Trace the interval countdown logic in `time_balance.apk`. Show the class and state flow so we can implement a clean Flutter equivalent in our study_log app."*

---

## 6. Windows Gotchas & Troubleshooting

1. **Execution Policy in PowerShell**:
   If script execution is disabled, enable current user scripts:
   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
   ```

2. **Paths with Spaces**:
   Always wrap paths in single or double quotes when invoking REA via PowerShell:
   ```powershell
   rea inspect-android-package 'C:\Users\hipradeep\Documents\re_targets\time_balance\time_balance.apk'
   ```

3. **Split APKs**:
   Modern apps published as Android App Bundles (.aab) install multiple split APKs on device (`base.apk`, `split_config.arm64_v8a.apk`, `split_config.xxhdpi.apk`).
   - For Java/Kotlin source code and logic: `base.apk` contains all Dalvik Executable (`classes.dex`) files.
   - For localized strings or assets: Inspect the corresponding `split_config.<lang>.apk` or extract using Apktool.
