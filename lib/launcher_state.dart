// Central launcher state: auth, selected version/engine, global and per-profile settings
// persistence, managed Java list, and orchestration of local game launch via MinecraftCore.
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
  String? msRefreshToken; 
  AuthMode authMode = AuthMode.offline;
  bool isAuthenticated = false;

  // --- NEW: Account List ---
  List<Map<String, dynamic>> savedAccounts =[];

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
  final List<Process> _secondaryProcesses = [];

  String jvmArgs = "-XX:+UseZGC -XX:+AlwaysPreTouch "
      "-XX:+DisableExplicitGC -XX:+UseNUMA";

  static String _sanitizeJvmArgs(String args) {
    return args
        .replaceAll(RegExp(r'-XX:\+ZGenerational\s*'), '')
        .replaceAll(RegExp(r'-XX:AllocateHeapAt=\S*\s*'), '')
        .trim();
  }

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
        jvmArgs = _sanitizeJvmArgs(data['jvmArgs'] ?? jvmArgs);

        // AUTH CACHE LOADING
        if (data['savedAccounts'] != null) {
          savedAccounts = List<Map<String, dynamic>>.from(data['savedAccounts'].map((e) => Map<String, dynamic>.from(e)));
        }

        if (data['isAuthenticated'] == true) {
          isAuthenticated = true;
          authMode = data['authMode'] == 'AuthMode.microsoft' ? AuthMode.microsoft : AuthMode.offline;
          username = data['username'];
          uuid = data['uuid'] ?? "";
          accessToken = data['accessToken'] ?? "";
          userType = data['userType'] ?? "";
          msRefreshToken = data['msRefreshToken'];

          // Auto-Refresh Active Microsoft Token
          if (authMode == AuthMode.microsoft && msRefreshToken != null) {
            try {
              final newMs = await AuthCore.refreshMicrosoftToken(msRefreshToken!);
              if (newMs['access_token'] != null) {
                final mcData = await AuthCore.authenticateMinecraft(newMs['access_token']);
                username = mcData['username'] as String?;
                uuid = mcData['uuid'] as String;
                accessToken = mcData['accessToken'] as String;
                userType = mcData['userType'] as String;
                msRefreshToken = newMs['refresh_token'] ?? msRefreshToken;
                
                // Update the token in the saved accounts list too
                _updateAccountInList();
                saveGlobalSettings(); 
              } else {
                isAuthenticated = false; 
              }
            } catch (e) {
              isAuthenticated = false; 
            }
          }
        }
      } catch (_) {}
    }
  }

  void _updateAccountInList() {
    final idx = savedAccounts.indexWhere((a) => a['uuid'] == uuid);
    if (idx >= 0) {
      savedAccounts[idx] = {
        'username': username,
        'uuid': uuid,
        'accessToken': accessToken,
        'userType': userType,
        'authMode': authMode.toString(),
        'msRefreshToken': msRefreshToken,
      };
    }
  }

  void addOrUpdateAccount(Map<String, dynamic> acc) {
    final idx = savedAccounts.indexWhere((a) => a['uuid'] == acc['uuid']);
    if (idx >= 0) {
      savedAccounts[idx] = acc;
    } else {
      savedAccounts.add(acc);
    }
    switchAccount(acc['uuid']); // Auto switch to newly added account
  }

  void switchAccount(String targetUuid) {
    final acc = savedAccounts.firstWhere((a) => a['uuid'] == targetUuid, orElse: () => <String, dynamic>{});
    if (acc.isNotEmpty) {
      username = acc['username'];
      uuid = acc['uuid'];
      accessToken = acc['accessToken'];
      userType = acc['userType'];
      authMode = acc['authMode'] == 'AuthMode.microsoft' ? AuthMode.microsoft : AuthMode.offline;
      msRefreshToken = acc['msRefreshToken'];
      isAuthenticated = true;
      saveGlobalSettings();
    }
  }

  void removeAccount(String targetUuid) {
    savedAccounts.removeWhere((a) => a['uuid'] == targetUuid);
    if (uuid == targetUuid) {
      isAuthenticated = false; // We deleted the active account
      if (savedAccounts.isNotEmpty) switchAccount(savedAccounts.first['uuid']);
    }
    saveGlobalSettings();
  }

  Future<void> saveGlobalSettings() async {
    final sep = Platform.pathSeparator;
    final file = File("$minecraftDir${sep}radium_global.json");
    await file.writeAsString(jsonEncode({
      'globalRamGB': globalRamGB,
      'globalJavaPath': globalJavaPath,
      'caperUrl': caperUrl,
      'showSnapshots': showSnapshots,
      'jvmArgs': jvmArgs,
      'savedAccounts': savedAccounts,
      'isAuthenticated': isAuthenticated,
      'authMode': authMode.toString(),
      'username': username,
      'uuid': uuid,
      'accessToken': accessToken,
      'userType': userType,
      'msRefreshToken': msRefreshToken,
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
    if (!isAuthenticated) return;
    
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
        jvmArgs: jvmArgs,
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

  Future<void> launchGameAsAccount(Map<String, dynamic> account) async {
    try {
      double ram = globalRamGB;
      if (activeProfileSettings['ramGb'] != null) ram = (activeProfileSettings['ramGb'] as num).toDouble();

      String jPath = resolveActiveJavaPath();
      MinecraftCore.logVerbose("Launching as ${account['username']} with Java: $jPath");

      Process process = await MinecraftCore.launch(
        mcDir: minecraftDir,
        version: selectedVersion,
        javaPath: jPath,
        ramGb: ram,
        jvmArgs: jvmArgs,
        caperUrl: caperUrl,
        username: account['username'] ?? '',
        uuid: account['uuid'] ?? '',
        accessToken: account['accessToken'] ?? '',
        userType: account['userType'] ?? '',
        onLog: (_, __) {},
      );

      _secondaryProcesses.add(process);

      process.stdout.transform(utf8.decoder).listen((data) => print("[MC-${account['username']}]: $data"));
      process.stderr.transform(utf8.decoder).listen((data) {
        print("[MC ERR-${account['username']}]: $data");
        if (data.contains("UnsatisfiedLinkError") || data.contains("libjawt.so") || data.contains("UnsupportedClassVersionError")) {
          print("[RADIUM ERROR] Incompatible Java version for ${account['username']}");
        }
      });

      await process.exitCode;
      _secondaryProcesses.remove(process);
    } catch (e) {
      print("[RADIUM ERROR] Launch failed for ${account['username']}: $e");
    }
  }
}
