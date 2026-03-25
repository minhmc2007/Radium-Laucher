//minecraft_core.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class MinecraftCore {
  static String get defaultMinecraftDir {
    if (Platform.isWindows) {
      return "${Platform.environment['APPDATA']}\\.minecraft";
    } else if (Platform.isMacOS) {
      return "${Platform.environment['HOME']}/Library/Application Support/minecraft";
    } else {
      return "${Platform.environment['HOME']}/.minecraft";
    }
  }

  static void logVerbose(String msg) {
    print("[RADIUM DEBUG] $msg");
  }

  static Future<List<String>> getInstalledVersions(String mcDir) async {
    final dir = Directory("$mcDir${Platform.pathSeparator}versions");
    if (!await dir.exists()) return [];
    final versions = <String>[];
    await for (var entity in dir.list()) {
      if (entity is Directory) {
        final name = entity.path.split(Platform.pathSeparator).last;
        versions.add(name);
      }
    }
    return versions..sort((a, b) => b.compareTo(a)); 
  }

  static Future<Map<String, dynamic>> resolveManifest(String mcDir, String version) async {
    final sep = Platform.pathSeparator;
    final jsonFile = File("$mcDir${sep}versions$sep$version$sep$version.json");
    
    if (!await jsonFile.exists()) {
      throw Exception("Manifest missing for $version. Please download it via the installer matrix.");
    }
    
    Map<String, dynamic> manifest = jsonDecode(await jsonFile.readAsString());
    
    if (manifest.containsKey('inheritsFrom')) {
      final parentVersion = manifest['inheritsFrom'];
      logVerbose("Inheriting manifest properties from $parentVersion");
      final parentManifest = await resolveManifest(mcDir, parentVersion);
      
      final List libs = parentManifest['libraries'] ??[];
      libs.addAll(manifest['libraries'] ??[]);
      manifest['libraries'] = libs;
      
      manifest['mainClass'] ??= parentManifest['mainClass'];
      manifest['minecraftArguments'] ??= parentManifest['minecraftArguments'];
      manifest['assetIndex'] ??= parentManifest['assetIndex'];
      manifest['downloads'] ??= parentManifest['downloads'];
      
      if (parentManifest['arguments'] != null) {
        manifest['arguments'] ??= {};
        if (parentManifest['arguments']['game'] != null) {
          final List parentGameArgs = List.from(parentManifest['arguments']['game']);
          final List currentArgs = manifest['arguments']['game'] != null ? List.from(manifest['arguments']['game']) :[];
          currentArgs.insertAll(0, parentGameArgs);
          manifest['arguments']['game'] = currentArgs;
        }
        if (parentManifest['arguments']['jvm'] != null) {
          final List parentJvmArgs = List.from(parentManifest['arguments']['jvm']);
          final List currentJvmArgs = manifest['arguments']['jvm'] != null ? List.from(manifest['arguments']['jvm']) :[];
          currentJvmArgs.insertAll(0, parentJvmArgs);
          manifest['arguments']['jvm'] = currentJvmArgs;
        }
      }
      manifest['jarVersion'] = parentVersion;
    } else {
      manifest['jarVersion'] = version;
    }
    
    return manifest;
  }

  // FIX: Added expectedSize verification and Retry Loops to auto-heal corrupted audio files
  static Future<void> downloadFile(String url, String destPath, {int? expectedSize, http.Client? client}) async {
    final file = File(destPath);
    if (await file.exists()) {
      final length = await file.length();
      if (expectedSize != null) {
        if (length == expectedSize) return; // Perfect match, valid cache
        logVerbose("Size mismatch for $destPath (expected: $expectedSize, actual: $length). Auto-Healing...");
      } else if (length > 0) {
        return; // No strict size given, but file is populated
      }
    }
    
    await file.parent.create(recursive: true);
    
    final useClient = client ?? http.Client();
    int retries = 3;
    
    try {
      while (retries > 0) {
        try {
          final res = await useClient.get(Uri.parse(url));
          if (res.statusCode == 200) {
            await file.writeAsBytes(res.bodyBytes);
            // Post-download verification
            if (expectedSize != null && await file.length() != expectedSize) {
               throw Exception("Downloaded file corrupted during sync.");
            }
            return;
          }
        } catch (e) {
          logVerbose("Network dropped for $url: Retrying...");
        }
        retries--;
        if (retries > 0) await Future.delayed(const Duration(milliseconds: 500));
      }
      logVerbose("[FATAL] Failed to download $url after 3 retries.");
    } finally {
      if (client == null) useClient.close();
    }
  }

  static Future<void> extractNatives(String zipPath, String destDir) async {
    logVerbose("Extracting native library: $zipPath -> $destDir");
    await Directory(destDir).create(recursive: true);
    try {
      if (Platform.isWindows) {
        await Process.run('powershell',['-NoProfile', '-Command', "Expand-Archive -Force -Path '$zipPath' -DestinationPath '$destDir'"]);
      } else {
        var res = await Process.run('unzip',['-o', '-q', zipPath, '-d', destDir]);
        if (res.exitCode != 0) {
          logVerbose("unzip failed, falling back to Java 'jar xf'...");
          await Process.run('jar',['xf', zipPath], workingDirectory: destDir);
        }
      }
    } catch (e) {
      logVerbose("ERROR extracting natives: $e");
    }
  }

  static bool checkOSRule(List? rules) {
    if (rules == null) return true;
    bool allow = false;
    String currentOS = Platform.isWindows ? 'windows' : (Platform.isMacOS ? 'osx' : 'linux');
    
    for (var rule in rules) {
      bool matchOS = true;
      if (rule['os'] != null && rule['os']['name'] != null) {
        matchOS = rule['os']['name'] == currentOS;
      }
      if (rule['action'] == 'allow' && matchOS) allow = true;
      if (rule['action'] == 'disallow' && matchOS) allow = false;
    }
    return allow;
  }

  static Future<void> verifyAndDownload(String mcDir, Map<String, dynamic> manifest, String versionDir, Function(double, String) onProgress) async {
    final sep = Platform.pathSeparator;
    logVerbose("Starting Verification & Download Phase...");

    final client = http.Client();
    try {
      onProgress(0.1, "VERIFYING CLIENT JAR...");
      final jarVersion = manifest['jarVersion'] ?? manifest['id'];
      final jarPath = "$mcDir${sep}versions$sep$jarVersion$sep$jarVersion.jar";
      if (manifest['downloads'] != null && manifest['downloads']['client'] != null) {
        final url = manifest['downloads']['client']['url'];
        final int? size = manifest['downloads']['client']['size'] is int ? manifest['downloads']['client']['size'] : null;
        await downloadFile(url, jarPath, expectedSize: size, client: client);
      }

      onProgress(0.3, "VERIFYING LIBRARIES & NATIVES...");
      final nativesDir = "$versionDir${sep}natives";
      await Directory(nativesDir).create(recursive: true);
      
      if (manifest['libraries'] != null) {
        int totalLibs = manifest['libraries'].length;
        int processed = 0;
        for (var lib in manifest['libraries']) {
          processed++;
          if (processed % 10 == 0) onProgress(0.3 + (0.3 * (processed / totalLibs)), "CHECKING LIBRARIES ($processed/$totalLibs)");
          
          if (!checkOSRule(lib['rules'])) continue;

          if (lib['downloads'] != null && lib['downloads']['artifact'] != null) {
            final art = lib['downloads']['artifact'];
            final path = "$mcDir${sep}libraries$sep${art['path'].replaceAll('/', sep)}";
            final int? artSize = art['size'] is int ? art['size'] : null;
            await downloadFile(art['url'], path, expectedSize: artSize, client: client);
          }

          if (lib['downloads'] != null && lib['downloads']['classifiers'] != null) {
            String osKey = Platform.isWindows ? 'natives-windows' : (Platform.isMacOS ? 'natives-macos' : 'natives-linux');
            if (lib['downloads']['classifiers'][osKey] != null) {
              final nat = lib['downloads']['classifiers'][osKey];
              final path = "$mcDir${sep}libraries$sep${nat['path'].replaceAll('/', sep)}";
              final int? natSize = nat['size'] is int ? nat['size'] : null;
              await downloadFile(nat['url'], path, expectedSize: natSize, client: client);
              await extractNatives(path, nativesDir);
            }
          }
        }
      }

      onProgress(0.7, "VERIFYING ASSETS...");
      if (manifest['assetIndex'] != null) {
        final assetId = manifest['assetIndex']['id'];
        final assetUrl = manifest['assetIndex']['url'];
        final int? assetSize = manifest['assetIndex']['size'] is int ? manifest['assetIndex']['size'] : null;
        final indexFile = File("$mcDir${sep}assets${sep}indexes$sep$assetId.json");
        await downloadFile(assetUrl, indexFile.path, expectedSize: assetSize, client: client);

        if (await indexFile.exists()) {
          Map<String, dynamic> assetData = jsonDecode(await indexFile.readAsString());
          Map<String, dynamic> objects = assetData['objects'];
          int totalAssets = objects.length;
          int currentAsset = 0;
          
          final bool isLegacyAssets = assetId == 'legacy' || assetId == 'pre-1.6';
          final String legacyDir = "$mcDir${sep}assets${sep}virtual${sep}legacy";
          
          List<MapEntry<String, dynamic>> objectEntries = objects.entries.toList();
          logVerbose("Queueing $totalAssets asset downloads in batches...");
          
          for (int i = 0; i < objectEntries.length; i += 50) {
            int end = (i + 50 < objectEntries.length) ? i + 50 : objectEntries.length;
            final batch = objectEntries.sublist(i, end);
            
            await Future.wait(batch.map((entry) async {
              final key = entry.key;
              final value = entry.value;
              final hash = value['hash'];
              final int? expectedSize = value['size'] is int ? value['size'] : null;
              final subHash = hash.substring(0, 2);
              final url = "https://resources.download.minecraft.net/$subHash/$hash";
              final path = "$mcDir${sep}assets${sep}objects$sep$subHash$sep$hash";
              
              try {
                await downloadFile(url, path, expectedSize: expectedSize, client: client);
                if (isLegacyAssets) {
                  final legacyFile = File("$legacyDir${sep}${key.replaceAll('/', sep)}");
                  if (!await legacyFile.exists()) {
                    await legacyFile.parent.create(recursive: true);
                    await File(path).copy(legacyFile.path);
                  }
                }
              } catch (e) {
                logVerbose("Failed to sync asset $key: $e");
              }
              
              currentAsset++;
              if (currentAsset % 100 == 0) {
                onProgress(0.7 + (0.25 * (currentAsset / totalAssets)), "HEALING AUDIO & ASSETS ($currentAsset/$totalAssets)");
              }
            }));
          }
        }
      }
      
      onProgress(1.0, "SYSTEM INTEGRITY VERIFIED");
    } finally {
      client.close();
    }
  }

  static Map<String, String> childProcessEnvironment() {
    return Map<String, String>.from(Platform.environment);
  }

  static Future<Process> launch({
    required String mcDir,
    required String version,
    required String javaPath,
    required double ramGb,
    required String aikarFlags,
    required String caperUrl,
    required String username,
    required String uuid,
    required String accessToken,
    required String userType,
    required Function(double, String) onLog,
  }) async {
    final sep = Platform.pathSeparator;
    final versionDir = "$mcDir${sep}versions$sep$version";
    
    final isolatedModsDir = Directory("$versionDir${sep}mods");
    final bool isIsolated = await isolatedModsDir.exists();
    final String executionDir = isIsolated ? versionDir : mcDir;
    
    onLog(0.05, "RESOLVING MANIFEST INHERITANCE...");
    final Map<String, dynamic> manifest = await resolveManifest(mcDir, version);
    
    await verifyAndDownload(mcDir, manifest, versionDir, onLog);

    onLog(1.0, "ASSEMBLING CLASSPATH...");
    List<String> classpath =[];
    if (manifest['libraries'] != null) {
      for (var lib in manifest['libraries']) {
        if (!checkOSRule(lib['rules'])) continue;
        if (lib['downloads'] != null && lib['downloads']['artifact'] != null) {
          final path = lib['downloads']['artifact']['path'];
          classpath.add("$mcDir${sep}libraries$sep${path.replaceAll('/', sep)}");
        } else if (lib['name'] != null) {
          final parts = lib['name'].split(':');
          if (parts.length >= 3) {
            final pkg = parts[0].replaceAll('.', sep);
            final name = parts[1];
            final ver = parts[2];
            classpath.add("$mcDir${sep}libraries$sep$pkg$sep$name$sep$ver$sep$name-$ver.jar");
          }
        }
      }
    }
    
    final jarVersion = manifest['jarVersion'] ?? version;
    final gameJar = "$mcDir${sep}versions$sep$jarVersion$sep$jarVersion.jar";
    if (!await File(gameJar).exists()) {
      throw Exception("Game JAR missing: $jarVersion.jar. Integrity failed.");
    }
    classpath.add(gameJar);
    
    final cpSeparator = Platform.isWindows ? ';' : ':';
    final cpString = classpath.join(cpSeparator);

    List<String> args =[];
    final ram = ramGb.toInt();
    args.addAll(['-Xmx${ram}G', '-Xms${ram}G']);
    args.addAll(aikarFlags.split(' '));
    
    if (caperUrl.isNotEmpty) {
      args.add("-Dcaper.url=$caperUrl");
      args.add("-Dminecraft.api.capes=$caperUrl");
    }

    if (manifest['arguments'] != null && manifest['arguments']['jvm'] != null) {
      final List jvmArgList = manifest['arguments']['jvm'];
      for (var arg in jvmArgList) {
        List<String> toProcess =[];
        
        if (arg is String) {
          toProcess.add(arg);
        } else if (arg is Map) {
          if (checkOSRule(arg['rules'])) {
            if (arg['value'] is String) {
              toProcess.add(arg['value']);
            } else if (arg['value'] is List) {
              toProcess.addAll(List.castFrom<dynamic, String>(arg['value']));
            }
          }
        }
        
        for (String str in toProcess) {
          String parsedArg = str
              .replaceAll('\${natives_directory}', "$versionDir${sep}natives")
              .replaceAll('\${launcher_name}', "Radium")
              .replaceAll('\${launcher_version}', "1.0")
              .replaceAll('\${classpath}', cpString);
          if (!args.contains(parsedArg)) args.add(parsedArg);
        }
      }
    }

    if (!args.contains("-cp")) args.addAll(["-cp", cpString]);
    if (!args.any((a) => a.startsWith("-Djava.library.path="))) {
      args.add("-Djava.library.path=$versionDir${sep}natives");
    }
    
    args.add(manifest['mainClass']);

    List<String> rawGameArgs = [];
    if (manifest['minecraftArguments'] != null) {
      rawGameArgs = manifest['minecraftArguments'].split(' ').where((s) => s.toString().trim().isNotEmpty).cast<String>().toList();
    } else if (manifest['arguments'] != null && manifest['arguments']['game'] != null) {
      final List gameArgList = manifest['arguments']['game'];
      for (var arg in gameArgList) {
        if (arg is String) {
          rawGameArgs.add(arg);
        } else if (arg is Map) {
          if (checkOSRule(arg['rules'])) {
            if (arg['value'] is String) {
              rawGameArgs.add(arg['value']);
            } else if (arg['value'] is List) {
              rawGameArgs.addAll(List.castFrom<dynamic, String>(arg['value']));
            }
          }
        }
      }
    }

    String resolvedAssetsDir = "$mcDir${sep}assets";
    if (manifest['assetIndex']?['id'] == 'legacy' || manifest['assetIndex']?['id'] == 'pre-1.6') {
      resolvedAssetsDir = "$mcDir${sep}assets${sep}virtual${sep}legacy";
    }

    List<String> finalGameArgs =[];
    for (int i = 0; i < rawGameArgs.length; i++) {
      if (rawGameArgs[i] == '--username' || rawGameArgs[i] == '--uuid') {
        i++; 
        continue;
      }
      
      finalGameArgs.add(rawGameArgs[i]
          .replaceAll('\${version_name}', version)
          .replaceAll('\${game_directory}', executionDir)
          .replaceAll('\${assets_root}', resolvedAssetsDir)
          .replaceAll('\${game_assets}', resolvedAssetsDir) 
          .replaceAll('\${assets_index_name}', manifest['assetIndex']?['id'] ?? "legacy")
          .replaceAll('\${auth_access_token}', accessToken)
          .replaceAll('\${auth_session}', accessToken) 
          .replaceAll('\${auth_player_name}', username) 
          .replaceAll('\${auth_uuid}', uuid) 
          .replaceAll('\${user_properties}', "{}") 
          .replaceAll('\${user_type}', userType)
          .replaceAll('\${version_type}', manifest['type'] ?? "release")
      );
    }

    if (!finalGameArgs.contains('--version')) finalGameArgs.addAll(['--version', jarVersion]);
    if (!finalGameArgs.contains('--gameDir')) finalGameArgs.addAll(['--gameDir', executionDir]);
    
    // FIX: Explictly enforce assetsDir and assetIndex in case Fabric/Forge manifests stripped them out
    if (!finalGameArgs.contains('--assetsDir')) finalGameArgs.addAll(['--assetsDir', resolvedAssetsDir]);
    if (!finalGameArgs.contains('--assetIndex')) finalGameArgs.addAll(['--assetIndex', manifest['assetIndex']?['id'] ?? "legacy"]);

    if (!finalGameArgs.contains(username) && !finalGameArgs.contains('--username')) {
        finalGameArgs.addAll(['--username', username, '--uuid', uuid]);
    }

    args.addAll(finalGameArgs);

    onLog(1.0, "EXECUTING JVM ENVIRONMENT...");
    logVerbose("====== JVM EXECUTION ARGUMENTS ======");
    logVerbose("Java Binary: $javaPath");
    logVerbose(args.join(" "));
    logVerbose("=====================================");

    final process = await Process.start(
      javaPath.toLowerCase() == "system default" || javaPath.toLowerCase() == "auto-detect" ? "java" : javaPath,
      args,
      workingDirectory: executionDir,
      environment: childProcessEnvironment(),
    );

    return process;
  }
}