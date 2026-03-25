# Radium Launcher
**A D V A N C E D · E X E C U T I O N · C O R E**

Radium is a high-performance, aesthetically driven Minecraft launcher built with Flutter. It combines a modern Glassmorphic interface with a robust, "self-healing" execution engine optimized for modern desktop environments—specifically tailored for **Arch Linux (PipeWire)**, macOS, and Windows.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey.svg)
![Framework](https://img.shields.io/badge/framework-Flutter-02569B.svg)

---

## ✨ Key Features

### 🚀 Performance & Execution
*   **Engine Detection:** Native support and automatic configuration for **Vanilla**, **Fabric**, and **Forge**.
*   **Aikar's Flags:** Integrated industry-standard JVM flags for high-performance garbage collection and stutter-free gameplay.
*   **Isolated Profiles:** Create modded instances with their own `mods/` and configuration directories to prevent version pollution.
*   **Smart RAM Allocation:** Dynamic slider for JVM heap sizing (XMX/XMS) with per-profile overrides.

### ☕ Advanced Java Management
*   **Managed JDKs:** Built-in downloader for **Eclipse Temurin (Adoptium)** versions 8, 17, 21, 23, and 25.
*   **Arch Linux Native:** Automatically detects and integrates with `archlinux-java` to utilize system-wide OpenJDK environments.
*   **Logic-Based Auto-Detect:** Radium automatically maps the correct Java version based on the Minecraft sub-version requirements.

### 🛡️ Integrity & Audio Healing
*   **Corrupt Asset Repair:** Advanced integrity checking that verifies asset file sizes against Mojang's manifest. Corrupted or 0-byte `.ogg` (audio) files are automatically detected and redownloaded.
*   **PipeWire Optimization:** Environment handling specifically tuned for Arch Linux audio stacks, resolving common "Missing Sound" issues found in other custom launchers.
*   **Batch Downloader:** Resilient network logic using batched requests to prevent socket exhaustion during massive asset syncs.

### 🔑 Authentication
*   **Microsoft Login:** Fully implemented OAuth2 Device Flow for secure official account access.
*   **Offline Mode:** Instant local profile creation for offline play or development.

---

## 🎨 UI Architecture
*   **Glassmorphism:** Custom-built blur filters and acrylic transparency effects.
*   **Animated Atmosphere:** A dynamic, orbital background system that shifts accent colors based on the active game engine (Vanilla Green, Fabric Orange, Forge Red).
*   **Modern Typography:** Utilizing *Jakarta Sans* and *Unbounded* for a premium, high-tech aesthetic.

---

## 🛠️ Build & Development

### Prerequisites
*   [Flutter SDK](https://docs.flutter.dev/get-started/install) (Stable)
*   Desktop development workloads:
    *   **Windows:** Visual Studio 2022 (C++ desktop development)
    *   **Linux:** `pkg-config`, `libgtk-3-dev`, `ninja-build`
    *   **macOS:** Xcode

### Quick Start
```bash
# Clone the repository
git clone https://github.com/minhmc2007/Radium-Laucher.git
cd Radium-Laucher

# Install dependencies
flutter pub get

# Run in Debug mode
flutter run -d <windows|linux|macos>

# Build Release binary
flutter build <windows|linux|macos>
```

---

## 📂 Core Architecture
*   `launcher_ui.dart`: Glassmorphic UI components and navigation.
*   `launcher_state.dart`: Central state, persistent settings, and launch orchestration.
*   `launcher_platform.dart`: Native file pickers, Microsoft Auth flow, and OS-specific Java scanning.
*   `minecraft_core.dart`: The core execution engine. Handles manifest inheritance, library extraction, asset verification (Audio Healing), and JVM process spawning.

---

## 📄 License
This project is licensed under the **GNU General Public License v3.0 (GPL-3.0)**. See the [LICENSE](LICENSE) file for the full license text.

## 📝 Legal
**Radium Launcher** is not affiliated with Mojang Studios or Microsoft. Minecraft is a trademark of Mojang Synergies AB. This software is provided as-is for personal game management and development.

***

### Links
*   **Source Code:** [https://github.com/minhmc2007/Radium-Laucher](https://github.com/minhmc2007/Radium-Laucher)
*   **Report Issues:** [https://github.com/minhmc2007/Radium-Laucher/issues](https://github.com/minhmc2007/Radium-Laucher/issues)