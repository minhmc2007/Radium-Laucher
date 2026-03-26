// Platform-specific integrations: native Java executable picker, JDK lifecycle
// (Adoptium Temurin install/scan, Arch `archlinux-java`, persisted managed Javas),
// and Microsoft device-flow + offline Minecraft authentication helpers.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

import 'minecraft_core.dart';

class NativePicker {
  static Future<String?> pickFile() async {
    try {
      if (Platform.isWindows) {
        var res = await Process.run('powershell',[
          '-NoProfile', '-Command',
          'Add-Type -AssemblyName System.Windows.Forms; \$f = New-Object System.Windows.Forms.OpenFileDialog; \$f.Title = "Select Java Executable"; \$f.Filter = "Executables (*.exe)|*.exe|All Files (*.*)|*.*"; \$f.ShowHelp = \$true; if (\$f.ShowDialog() -eq "OK") { Write-Output \$f.FileName }'
        ]);
        String path = res.stdout.toString().trim();
        return path.isNotEmpty ? path : null;
      } else if (Platform.isMacOS) {
        var res = await Process.run('osascript',['-e', 'POSIX path of (choose file with prompt "Select Java Executable")']);
        String path = res.stdout.toString().trim();
        return path.isNotEmpty ? path : null;
      } else if (Platform.isLinux) {
        try {
          var res = await Process.run('zenity',['--file-selection', '--title=Select Java Executable']);
          if (res.exitCode == 0) return res.stdout.toString().trim();
        } catch (_) {}
        try {
          var res = await Process.run('kdialog', ['--getopenfilename', '/', 'Java Executable']);
          if (res.exitCode == 0) return res.stdout.toString().trim();
        } catch (_) {}
      }
    } catch (e) {
      MinecraftCore.logVerbose("Native picker failed: $e");
    }
    return null;
  }
}

// ==========================================
// REAL JAVA / JDK MANAGER (TEMURIN / GRAALVM / ARCH)
// ==========================================

class JavaManager {
  static Future<List<Map<String, dynamic>>> getManagedJavas(String mcDir) async {
    List<Map<String, dynamic>> results =[];
    
    // 1. Load Local Adoptium installs
    final file = File("$mcDir${Platform.pathSeparator}radium_java${Platform.pathSeparator}managed_javas.json");
    if (await file.exists()) {
      try {
        final List data = jsonDecode(await file.readAsString());
        results.addAll(data.cast<Map<String, dynamic>>());
      } catch (_) {}
    }

    // 2. Scan Arch Linux via `archlinux-java`
    if (Platform.isLinux) {
      try {
        var res = await Process.run('archlinux-java', ['status']);
        if (res.exitCode == 0) {
          var lines = res.stdout.toString().split('\n');
          for (var line in lines) {
            line = line.trim();
            if (line.isNotEmpty && !line.startsWith('Available')) {
              String name = line.replaceAll('(default)', '').trim();
              int version = 21; 
              var match = RegExp(r'(\d+)').firstMatch(name);
              if (match != null) version = int.parse(match.group(1)!);
              
              results.add({
                'name': 'Arch OS: $name',
                'version': version,
                'path': '/usr/lib/jvm/$name/bin/java',
                'type': 'system'
              });
            }
          }
        }
      } catch (e) {
        MinecraftCore.logVerbose("archlinux-java scan bypassed: $e");
      }
    }
    return results;
  }

  static Future<void> saveManagedJavas(String mcDir, List<Map<String, dynamic>> list) async {
    final dir = Directory("$mcDir${Platform.pathSeparator}radium_java");
    if (!await dir.exists()) await dir.create(recursive: true);
    
    // Only save temurin ones locally so we don't duplicate OS scanned ones
    var temurins = list.where((j) => j['type'] == 'temurin').toList();
    final file = File("${dir.path}${Platform.pathSeparator}managed_javas.json");
    await file.writeAsString(jsonEncode(temurins));
  }

  static Future<void> installTemurin(int version, String mcDir, Function(String) onStatus) async {
    onStatus("FETCHING ADOPTIUM API FOR JAVA $version...");
    final String os = Platform.isWindows ? "windows" : (Platform.isMacOS ? "mac" : "linux");
    String arch = "x64";
    if (Platform.version.contains("arm64") || Platform.version.contains("aarch64")) arch = "aarch64";

    final apiUrl = "https://api.adoptium.net/v3/assets/latest/$version/hotspot?os=$os&architecture=$arch&image_type=jdk";
    
    final res = await http.get(Uri.parse(apiUrl));
    if (res.statusCode != 200) throw Exception("Failed to find Java $version for $os/$arch in Adoptium API.");

    final List data = jsonDecode(res.body);
    if (data.isEmpty) throw Exception("No Java $version releases available for this OS/Arch.");

    final pkg = data[0]['binary']['package'];
    final downloadUrl = pkg['link'];
    final fileName = pkg['name'];
    
    final sep = Platform.pathSeparator;
    final targetDir = Directory("$mcDir${sep}radium_java${sep}temurin-$version");
    if (!await targetDir.exists()) await targetDir.create(recursive: true);

    final archivePath = "${targetDir.path}$sep$fileName";
    
    onStatus("DOWNLOADING TEMURIN $version...");
    await MinecraftCore.downloadFile(downloadUrl, archivePath);

    onStatus("EXTRACTING JVM ARCHIVE...");
    try {
      if (Platform.isWindows && archivePath.endsWith(".zip")) {
         await Process.run('powershell',['-NoProfile', '-Command', "Expand-Archive -Force -Path '$archivePath' -DestinationPath '${targetDir.path}'"]);
      } else {
         await Process.run('tar',['-xf', archivePath, '-C', targetDir.path]);
      }
    } catch (e) {
      MinecraftCore.logVerbose("Extraction failed, but continuing: $e");
    }

    onStatus("LOCATING JAVA EXECUTABLE...");
    String javaExePath = "";
    await for (var entity in targetDir.list(recursive: true)) {
      if (entity is File) {
        final lower = entity.path.toLowerCase();
        if (lower.endsWith("${sep}bin${sep}java") || lower.endsWith("${sep}bin${sep}java.exe")) {
          javaExePath = entity.path;
          break;
        }
      }
    }

    if (javaExePath.isEmpty) throw Exception("Extracted archive, but missing bin/java!");

    if (!Platform.isWindows) {
      await Process.run('chmod',['+x', javaExePath]);
    }

    onStatus("REGISTERING JDK $version...");
    final javas = await getManagedJavas(mcDir);
    javas.removeWhere((j) => j['name'] == "Temurin $version");
    javas.add({
      "name": "Temurin $version",
      "version": version,
      "path": javaExePath,
      "type": "temurin"
    });
    await saveManagedJavas(mcDir, javas);

    if (await File(archivePath).exists()) await File(archivePath).delete();
    onStatus("JAVA $version SUCCESSFULLY INSTALLED");
  }

  static String autoDetectJava(int mcMinorVersion, List<Map<String, dynamic>> managedJavas, String defaultPath) {
    int targetJava = 21; 
    if (mcMinorVersion <= 16) {
      targetJava = 8;
    } else if (mcMinorVersion <= 19) {
      targetJava = 17;
    }
    
    for (var j in managedJavas) {
      if (j['version'] == targetJava) return j['path'];
    }
    return defaultPath;
  }
}

// ==========================================
// REAL MICROSOFT & OFFLINE AUTHENTICATION
// ==========================================

class AuthCore {
  static const String clientId = "00000000402b5328";

  static Future<Map<String, String>> startMicrosoftDeviceFlow() async {
    final res = await http.post(
      Uri.parse("https://login.live.com/oauth20_connect.srf"),
      body: {"client_id": clientId, "scope": "XboxLive.signin offline_access", "response_type": "device_code"},
    );
    return Map<String, String>.from(jsonDecode(res.body));
  }

  static Future<Map<String, dynamic>> pollMicrosoftToken(String deviceCode) async {
    final res = await http.post(
      Uri.parse("https://login.live.com/oauth20_token.srf"),
      body: {"client_id": clientId, "grant_type": "urn:ietf:params:oauth:grant-type:device_code", "device_code": deviceCode},
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> authenticateMinecraft(String msAccessToken) async {
    var xblRes = await http.post(
      Uri.parse("https://user.auth.xboxlive.com/user/authenticate"),
      headers: {"Content-Type": "application/json", "Accept": "application/json"},
      body: jsonEncode({"Properties": {"AuthMethod": "RPS", "SiteName": "user.auth.xboxlive.com", "RpsTicket": "d=$msAccessToken"}, "RelyingParty": "http://auth.xboxlive.com", "TokenType": "JWT"}),
    );
    final xblToken = jsonDecode(xblRes.body)['Token'];

    var xstsRes = await http.post(
      Uri.parse("https://xsts.auth.xboxlive.com/xsts/authorize"),
      headers: {"Content-Type": "application/json", "Accept": "application/json"},
      body: jsonEncode({"Properties": {"SandboxId": "RETAIL", "UserTokens": [xblToken]}, "RelyingParty": "rp://api.minecraftservices.com/", "TokenType": "JWT"}),
    );
    final xstsData = jsonDecode(xstsRes.body);
    final xstsToken = xstsData['Token'];
    final uhs = xstsData['DisplayClaims']['xui'][0]['uhs'];

    var mcRes = await http.post(
      Uri.parse("https://api.minecraftservices.com/authentication/login_with_xbox"),
      headers: {"Content-Type": "application/json", "Accept": "application/json"},
      body: jsonEncode({"identityToken": "XBL3.0 x=$uhs;$xstsToken"}),
    );
    final mcToken = jsonDecode(mcRes.body)['access_token'];

    var profileRes = await http.get(
      Uri.parse("https://api.minecraftservices.com/minecraft/profile"),
      headers: {"Authorization": "Bearer $mcToken"},
    );
    
    final profile = jsonDecode(profileRes.body);
    return {"username": profile['name'], "uuid": profile['id'], "accessToken": mcToken, "userType": "msa"};
  }

  static Map<String, String> generateOfflineAccount(String username) {
    final bytes = utf8.encode("OfflinePlayer:$username");
    final seed = bytes.fold<int>(0, (int a, int b) => a + b);
    final random = math.Random(seed);
    final uuid = List.generate(32, (_) => random.nextInt(16).toRadixString(16)).join();
    return {"username": username, "uuid": uuid, "accessToken": "offline_token", "userType": "mojang"};
  }
}
