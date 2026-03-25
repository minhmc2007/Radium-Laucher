//launcher_state.dart 
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

import 'launcher_platform.dart';
import 'minecraft_core.dart';

enum GameEngine { vanilla, fabric, forge }
enum AuthMode { microsoft, offline }

class LauncherState extends ChangeNotifier {
  String? username;
  String uuid = "";
  String accessToken = "";
  String userType = "";
  AuthMode authMode = AuthMode.offline;
  bool isAuthenticated = false;

  GameEngine selectedEngine = GameEngine.vanilla;
  String selectedVersion = "Loading...";
  List<String> availableVersions =[];
  
  // Persistent Settings
  double globalRamGB = 4.0;
  String globalJavaPath = "Auto-Detect";
  String minecraftDir = MinecraftCore.defaultMinecraftDir;
  String caperUrl = "https://example.com/capes"; 
  bool showSnapshots = false;
  List<Map<String, dynamic>> managedJavas =[];

  Map<String, dynamic> activeProfileSettings = {};
  
  bool isLaunching = false;
  double launchProgress = 0.0;
  String launchStatus = "READY";
  Process? runningProcess;

  final String aikarFlags = 
      "-XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 "
      "-XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch "
      "-XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M "
      "-XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 "
      "-XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 "
      "-XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 "
      "-XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 "
      "-Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true";

  LauncherState() {
    _init();
  }

  Future<void> _init() async {
    await _loadGlobalSettings();
    managedJavas = await JavaManager.getManagedJavas(minecraftDir);
    await loadVersions();
  }

  Future<void> _loadGlobalSettings() async {
    final sep = Platform.pathSeparator;
    final file = File("$minecraftDir${sep}radium_global.json");
    if (await file.exists()) {
      try {
        var data = jsonDecode(await file.readAsString());
        globalRamGB = (data['globalRamGB'] ?? 4.0).toDouble();
        globalJavaPath = data['globalJavaPath'] ?? "Auto-Detect";
        caperUrl = data['caperUrl'] ?? "https://example.com/capes";
        showSnapshots = data['showSnapshots'] ?? false;
      } catch (_) {}
    }
  }

  Future<void> saveGlobalSettings() async {
    final sep = Platform.pathSeparator;
    final file = File("$minecraftDir${sep}radium_global.json");
    await file.writeAsString(jsonEncode({
      'globalRamGB': globalRamGB,
      'globalJavaPath': globalJavaPath,
      'caperUrl': caperUrl,
      'showSnapshots': showSnapshots
    }));
    notifyListeners();
  }

  void updateSettings(void Function() fn) {
    fn();
    notifyListeners();
  }

  Future<void> refreshJavas() async {
    managedJavas = await JavaManager.getManagedJavas(minecraftDir);
    notifyListeners();
  }

  Future<void> loadVersions() async {
    final v = await MinecraftCore.getInstalledVersions(minecraftDir);
    availableVersions = v;
    if (v.isNotEmpty && !v.contains(selectedVersion)) {
      await setVersionAndAutoDetect(v.first);
    } else if (v.isEmpty) {
      selectedVersion = "No versions found";
      notifyListeners();
    }
  }

  Future<void> setVersionAndAutoDetect(String v) async {
    selectedVersion = v;
    final sep = Platform.pathSeparator;
    final versionDir = "$minecraftDir${sep}versions$sep$v";
    
    final profileSettingsFile = File("$versionDir${sep}radium_profile.json");
    if (await profileSettingsFile.exists()) {
      try {
        activeProfileSettings = jsonDecode(await profileSettingsFile.readAsString());
      } catch (_) { activeProfileSettings = {}; }
    } else {
      activeProfileSettings = {};
    }

    try {
      final jsonFile = File("$versionDir${sep}$v.json");
      if (await jsonFile.exists()) {
        final manifest = jsonDecode(await jsonFile.readAsString());
        String id = (manifest['id'] ?? "").toLowerCase();
        String inherits = (manifest['inheritsFrom'] ?? "").toLowerCase();
        
        if (id.contains('fabric') || inherits.contains('fabric')) {
          selectedEngine = GameEngine.fabric;
        } else if (id.contains('forge') || inherits.contains('forge') || id.contains('optifine') || inherits.contains('optifine')) {
          selectedEngine = GameEngine.forge;
        } else {
          selectedEngine = GameEngine.vanilla;
        }
      } else {
        throw Exception("No JSON");
      }
    } catch (e) {
      final lower = v.toLowerCase();
      if (lower.contains('fabric')) selectedEngine = GameEngine.fabric;
      else if (lower.contains('forge') || lower.contains('optifine')) selectedEngine = GameEngine.forge;
      else selectedEngine = GameEngine.vanilla;
    }
    notifyListeners();
  }

  Future<void> saveProfileSettings(Map<String, dynamic> newSettings) async {
    activeProfileSettings = newSettings;
    final sep = Platform.pathSeparator;
    final versionDir = "$minecraftDir${sep}versions$sep$selectedVersion";
    final file = File("$versionDir${sep}radium_profile.json");
    await file.writeAsString(jsonEncode(activeProfileSettings));
    notifyListeners();
  }

  Future<void> deleteCurrentVersion() async {
    if (selectedVersion == "No versions found" || isLaunching) return;
    final dir = Directory("$minecraftDir${Platform.pathSeparator}versions${Platform.pathSeparator}$selectedVersion");
    if (await dir.exists()) await dir.delete(recursive: true);
    await loadVersions();
  }

  Color get currentEngineColor {
    switch (selectedEngine) {
      case GameEngine.vanilla: return const Color(0xFF00FFA3);
      case GameEngine.fabric: return const Color(0xFFFFB067);
      case GameEngine.forge: return const Color(0xFFFF3366);
    }
  }

  int _parseMinorVersion(String v) {
    try {
      final match = RegExp(r'1\.(\d+)').firstMatch(v);
      if (match != null) return int.parse(match.group(1)!);
    } catch (_) {}
    return 21; 
  }

  String resolveActiveJavaPath() {
    String prof = activeProfileSettings['javaPath'] ?? "Auto-Detect";
    if (prof != "Auto-Detect") return prof;

    if (globalJavaPath != "Auto-Detect") return globalJavaPath;

    int minor = _parseMinorVersion(selectedVersion);
    return JavaManager.autoDetectJava(minor, managedJavas, "System Default");
  }

  Future<void> launchGameLocal() async {
    if (isLaunching || runningProcess != null) return;
    
    isLaunching = true;
    launchProgress = 0.05;
    launchStatus = "PREPARING LAUNCH CYCLE...";
    notifyListeners();

    try {
      double ram = globalRamGB;
      if (activeProfileSettings['ramGb'] != null) ram = (activeProfileSettings['ramGb'] as num).toDouble();

      String jPath = resolveActiveJavaPath();
      MinecraftCore.logVerbose("Final Java Path Selected: $jPath");

      runningProcess = await MinecraftCore.launch(
        mcDir: minecraftDir,
        version: selectedVersion,
        javaPath: jPath,
        ramGb: ram,
        aikarFlags: aikarFlags,
        caperUrl: caperUrl,
        username: username!,
        uuid: uuid,
        accessToken: accessToken,
        userType: userType,
        onLog: (progress, msg) {
          launchProgress = progress;
          launchStatus = msg;
          notifyListeners();
        },
      );

      launchProgress = 1.0;
      launchStatus = "GAME RUNNING";
      notifyListeners();

      runningProcess!.stdout.transform(utf8.decoder).listen((data) => print("[MC]: $data"));
      runningProcess!.stderr.transform(utf8.decoder).listen((data) {
        print("[MC ERR]: $data");
        if (data.contains("UnsatisfiedLinkError") || data.contains("libjawt.so") || data.contains("UnsupportedClassVersionError")) {
          launchStatus = "CRASH: INCOMPATIBLE JAVA VERSION!";
          notifyListeners();
        }
      });

      await runningProcess!.exitCode;
      
      if (!launchStatus.contains("CRASH")) {
        launchStatus = "GAME EXITED";
      }
    } catch (e) {
      launchStatus = "ERROR: $e";
      print("[RADIUM ERROR] $e");
    } finally {
      await Future.delayed(const Duration(seconds: 5));
      isLaunching = false;
      runningProcess = null;
      launchStatus = "READY";
      launchProgress = 0.0;
      notifyListeners();
    }
  }
}
