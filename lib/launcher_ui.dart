// Radium Launcher Flutter UI: app shell, home/settings screens, version and profile
// modals, auth flow, download matrix, and shared visual components (glass cards, atmosphere).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import 'launcher_platform.dart';
import 'launcher_state.dart';
import 'minecraft_core.dart';

class RadiumLauncher extends StatelessWidget {
  const RadiumLauncher({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Radium Launcher',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF050505),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme),
      ),
      home: const MainLayout(),
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with SingleTickerProviderStateMixin {
  final LauncherState state = LauncherState();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    state.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children:[
          AnimatedAtmosphere(color: state.currentEngineColor),
          Positioned.fill(child: CustomPaint(painter: GridPainter())),
          SafeArea(
            child: Row(
              children:[
                _buildSidebar(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    switchInCurve: Curves.easeOutExpo,
                    switchOutCurve: Curves.easeInExpo,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(animation),
                        child: child,
                      ),
                    ),
                    child: _currentIndex == 0
                        ? HomeView(state: state, key: const ValueKey('home'))
                        : SettingsView(state: state, key: const ValueKey('settings')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.white.withOpacity(0.05)))),
      child: Column(
        children:[
          HoverAnimatedScale(
            scale: 1.1,
            child: Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow:[BoxShadow(color: state.currentEngineColor.withOpacity(0.5), blurRadius: 20)],
                gradient: RadialGradient(colors:[state.currentEngineColor, state.currentEngineColor.withOpacity(0.2)]),
              ),
              child: Center(child: Text("R", style: GoogleFonts.unbounded(fontWeight: FontWeight.w900, fontSize: 24, color: Colors.black87))),
            ),
          ),
          const Spacer(),
          _NavIcon(icon: Icons.dashboard_rounded, isSelected: _currentIndex == 0, accent: state.currentEngineColor, onTap: () => setState(() => _currentIndex = 0)),
          const SizedBox(height: 32),
          _NavIcon(icon: Icons.tune_rounded, isSelected: _currentIndex == 1, accent: state.currentEngineColor, onTap: () => setState(() => _currentIndex = 1)),
          const Spacer(),
          HoverAnimatedScale(
            child: GestureDetector(
              onTap: () => AnimatedDialog.show(context, AccountManagerModal(state: state)),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white.withOpacity(0.1),
                backgroundImage: state.isAuthenticated && state.authMode == AuthMode.microsoft 
                    ? NetworkImage("https://minotar.net/helm/${state.uuid}/64.png") 
                    : null,
                child: (!state.isAuthenticated || state.authMode == AuthMode.offline) 
                    ? Icon(state.isAuthenticated ? Icons.person : Icons.person_off, color: state.isAuthenticated ? Colors.white : Colors.white38, size: 20)
                    : null,
              ),
            ),
          )
        ],
      ),
    );
  }
}

// ==========================================
// VIEWS
// ==========================================

class HomeView extends StatelessWidget {
  final LauncherState state;
  const HomeView({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    String displayName = state.selectedVersion;
    if (state.activeProfileSettings['customName'] != null && state.activeProfileSettings['customName'].toString().isNotEmpty) {
      displayName = state.activeProfileSettings['customName'];
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(48.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children:[
          StaggeredEntrance(delayMs: 0, child: Text("RADIUM", style: GoogleFonts.unbounded(fontSize: 64, fontWeight: FontWeight.w900, letterSpacing: 4, color: Colors.white))),
          StaggeredEntrance(delayMs: 50, child: Text("A D V A N C E D   E X E C U T I O N   C O R E", style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 4, color: state.currentEngineColor))),

          SizedBox(height: math.max(32.0, constraints.maxHeight * 0.08)),

          StaggeredEntrance(
            delayMs: 100,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: state.currentEngineColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: state.currentEngineColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children:[
                  Icon(Icons.bolt, color: state.currentEngineColor, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    "${state.selectedEngine.name.toUpperCase()} ENGINE DETECTED",
                    style: GoogleFonts.plusJakartaSans(color: state.currentEngineColor, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 2),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          StaggeredEntrance(
            delayMs: 150,
            child: Row(
              children:[
                Expanded(
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: state.availableVersions.contains(state.selectedVersion) ? state.selectedVersion : null,
                        dropdownColor: const Color(0xFF111111),
                        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
                        style: GoogleFonts.unbounded(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 16),
                        items: state.availableVersions.map((e) {
                          return DropdownMenuItem(value: e, child: Text(e));
                        }).toList(),
                        onChanged: (val) { if (val != null) state.setVersionAndAutoDetect(val); },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                HoverAnimatedScale(
                  child: GestureDetector(
                    onTap: () => AnimatedDialog.show(context, ProfileSettingsModal(state: state)),
                    child: const GlassCard(
                      padding: EdgeInsets.all(22),
                      child: Icon(Icons.settings, color: Colors.white70, size: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                HoverAnimatedScale(
                  child: GestureDetector(
                    onTap: () => AnimatedDialog.show(context, VersionDownloaderModal(state: state)),
                    child: const GlassCard(
                      padding: EdgeInsets.all(22),
                      child: Icon(Icons.download, color: Colors.white70, size: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                HoverAnimatedScale(
                  child: GestureDetector(
                    onTap: () => AnimatedDialog.show(context, ProfileCreatorModal(state: state)),
                    child: const GlassCard(
                      padding: EdgeInsets.all(22),
                      child: Icon(Icons.create_new_folder, color: Colors.white70, size: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                HoverAnimatedScale(
                  child: GestureDetector(
                    onTap: () {
                      if (state.selectedVersion == "No versions found" || state.isLaunching) return;
                      AnimatedDialog.show(
                        context, 
                        ConfirmDeleteModal(
                          title: "DELETE VERSION",
                          message: "Are you sure you want to permanently delete '${state.selectedVersion}'?\nThis will wipe all related client files and isolated mods.",
                          onConfirm: () => state.deleteCurrentVersion(),
                        )
                      );
                    },
                    child: GlassCard(
                      padding: const EdgeInsets.all(22),
                      child: Icon(Icons.delete_outline, color: Colors.redAccent.withOpacity(0.8), size: 24),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          if (displayName != state.selectedVersion)
            StaggeredEntrance(
              delayMs: 180,
              child: Padding(
                padding: const EdgeInsets.only(top: 12.0, left: 8.0),
                child: Text("Active Profile Name: $displayName", style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),

          const SizedBox(height: 32),
          
          StaggeredEntrance(delayMs: 200, child: LaunchLocalButton(state: state)),
          
          const SizedBox(height: 16),
          if (state.isLaunching || state.launchStatus.contains("ERROR") || state.launchStatus.contains("CRASH"))
             StaggeredEntrance(
               delayMs: 0,
               child: Text(
                 state.launchStatus,
                 style: GoogleFonts.plusJakartaSans(
                   color: (state.launchStatus.contains("ERROR") || state.launchStatus.contains("CRASH")) ? Colors.redAccent : Colors.white,
                   fontWeight: FontWeight.bold,
                   fontSize: 12,
                   letterSpacing: 1.5,
                 ),
               ),
             )
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class SettingsView extends StatefulWidget {
  final LauncherState state;
  const SettingsView({super.key, required this.state});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late TextEditingController _caperController;
  late TextEditingController _javaController;

  @override
  void initState() {
    super.initState();
    _caperController = TextEditingController(text: widget.state.caperUrl);
    _javaController = TextEditingController(text: widget.state.globalJavaPath);
  }

  @override
  void dispose() {
    _caperController.dispose();
    _javaController.dispose();
    super.dispose();
  }

  void _saveAll() {
    widget.state.globalJavaPath = _javaController.text.trim().isEmpty ? "Auto-Detect" : _javaController.text.trim();
    widget.state.caperUrl = _caperController.text.trim();
    widget.state.saveGlobalSettings();
  }

  @override
  Widget build(BuildContext context) {
    List<String> jOpts =["Auto-Detect", "System Default"];
    for (var j in widget.state.managedJavas) {
      jOpts.add(j['path'] as String);
    }

    return ListView(
      padding: const EdgeInsets.all(48.0),
      children:[
        Text("GLOBAL CONFIGURATION", style: GoogleFonts.unbounded(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 48),

        _buildSectionTitle(Icons.memory, "SYSTEM RESOURCE ALLOCATION"),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children:[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children:[
                  Text("JVM MAXIMUM RAM (XMX)", style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontWeight: FontWeight.bold)),
                  Text("${widget.state.globalRamGB.toInt()} GB", style: GoogleFonts.unbounded(color: widget.state.currentEngineColor, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              SliderTheme(
                data: SliderThemeData(activeTrackColor: widget.state.currentEngineColor, inactiveTrackColor: Colors.white.withOpacity(0.1), thumbColor: Colors.white),
                child: Slider(value: widget.state.globalRamGB, min: 2, max: 32, divisions: 15, onChanged: (val) {
                  setState(() => widget.state.globalRamGB = val);
                  _saveAll();
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        _buildSectionTitle(Icons.code, "RADIUM JAVA MANAGER (NATIVE)"),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children:[
              Text("MANAGED JVM ENVIRONMENTS", style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 12),
              if (widget.state.managedJavas.isEmpty)
                Text("No managed Javas installed. Relying on System Default.", style: GoogleFonts.plusJakartaSans(color: Colors.white24, fontStyle: FontStyle.italic)),
              
              ...widget.state.managedJavas.map((j) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children:[
                    Icon(j['type'] == 'system' ? Icons.settings_system_daydream : Icons.terminal, color: widget.state.currentEngineColor, size: 16),
                    const SizedBox(width: 8),
                    Text(j['name'], style: GoogleFonts.unbounded(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(j['path'], style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 10), overflow: TextOverflow.ellipsis)),
                  ],
                ),
              )).toList(),
              
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children:[
                  _JavaInstallBtn(version: 8, state: widget.state),
                  _JavaInstallBtn(version: 17, state: widget.state),
                  _JavaInstallBtn(version: 21, state: widget.state),
                  _JavaInstallBtn(version: 23, state: widget.state),
                  _JavaInstallBtn(version: 25, state: widget.state),
                ],
              ),
              const SizedBox(height: 32),

              Text("GLOBAL CUSTOM / GRAALVM EXECUTABLE PATH", style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                children:[
                  Expanded(
                    child: TextField(
                      controller: _javaController,
                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 12),
                      onChanged: (value) => _saveAll(),
                      decoration: InputDecoration(
                        hintText: "Path to bin/java (e.g. Auto-Detect)",
                        hintStyle: const TextStyle(color: Colors.white38),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: widget.state.currentEngineColor)),
                        filled: true,
                        fillColor: Colors.black26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.folder_open, color: widget.state.currentEngineColor),
                    onPressed: () async {
                      String? path = await NativePicker.pickFile();
                      if (path != null) {
                        setState(() => _javaController.text = path);
                        _saveAll();
                      }
                    },
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.arrow_drop_down, color: widget.state.currentEngineColor),
                    onSelected: (val) {
                      setState(() => _javaController.text = val);
                      _saveAll();
                    },
                    itemBuilder: (ctx) => jOpts.map((j) {
                      String label = j;
                      if (j.contains("radium_java")) label = "Managed: ${j.split(Platform.pathSeparator).reversed.skip(2).first}";
                      return PopupMenuItem(value: j, child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12)));
                    }).toList(),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 32),

        _buildSectionTitle(Icons.link, "CAPER CAPE SYSTEM INJECTION"),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children:[
              Text("CAPE SERVER URL", style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _caperController,
                style: GoogleFonts.plusJakartaSans(color: Colors.white),
                onChanged: (value) => _saveAll(),
                decoration: InputDecoration(
                  hintText: "https://your-cape-server.com/",
                  hintStyle: const TextStyle(color: Colors.white38),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: widget.state.currentEngineColor)),
                  filled: true,
                  fillColor: Colors.black26,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 64),
      ],
    );
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children:[
          Icon(icon, color: Colors.white54, size: 20),
          const SizedBox(width: 12),
          Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2, color: Colors.white54)),
        ],
      ),
    );
  }
}

class _JavaInstallBtn extends StatefulWidget {
  final int version;
  final LauncherState state;
  const _JavaInstallBtn({required this.version, required this.state});

  @override
  State<_JavaInstallBtn> createState() => _JavaInstallBtnState();
}

class _JavaInstallBtnState extends State<_JavaInstallBtn> {
  bool isInstalling = false;
  String status = "";

  Future<void> _doInstall() async {
    setState(() => isInstalling = true);
    try {
      await JavaManager.installTemurin(widget.version, widget.state.minecraftDir, (msg) {
        if (mounted) setState(() => status = msg);
      });
      widget.state.refreshJavas();
    } catch (e) {
      if (mounted) setState(() => status = "ERROR: API UNAVAILABLE");
      await Future.delayed(const Duration(seconds: 3));
    } finally {
      if (mounted) setState(() => isInstalling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isInstalling) {
      return SizedBox(
        width: 130,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
          alignment: Alignment.center,
          child: Text(status, style: GoogleFonts.plusJakartaSans(fontSize: 9, color: widget.state.currentEngineColor, fontWeight: FontWeight.bold), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
        )
      );
    }
    return SizedBox(
      width: 130,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.05),
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white24),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: _doInstall,
        child: Text("Java ${widget.version}", style: GoogleFonts.unbounded(fontSize: 10, fontWeight: FontWeight.bold)),
      )
    );
  }
}

// ==========================================
// PER-PROFILE OVERRIDES / GEAR ICON UI
// ==========================================

class ProfileSettingsModal extends StatefulWidget {
  final LauncherState state;
  const ProfileSettingsModal({super.key, required this.state});

  @override
  State<ProfileSettingsModal> createState() => _ProfileSettingsModalState();
}

class _ProfileSettingsModalState extends State<ProfileSettingsModal> {
  late TextEditingController _nameController;
  late TextEditingController _javaController;
  late double _ram;

  @override
  void initState() {
    super.initState();
    final s = widget.state.activeProfileSettings;
    _nameController = TextEditingController(text: s['customName'] ?? "");
    _ram = (s['ramGb'] != null) ? (s['ramGb'] as num).toDouble() : widget.state.globalRamGB;
    _javaController = TextEditingController(text: s['javaPath'] ?? "Auto-Detect");
  }

  @override
  void dispose() {
    _nameController.dispose();
    _javaController.dispose();
    super.dispose();
  }

  void _save() {
    widget.state.saveProfileSettings({
      "customName": _nameController.text.trim(),
      "ramGb": _ram,
      "javaPath": _javaController.text.trim().isEmpty ? "Auto-Detect" : _javaController.text.trim(),
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    List<String> jOpts =["Auto-Detect", "System Default"];
    for (var j in widget.state.managedJavas) {
      jOpts.add(j['path'] as String);
    }

    return Center(
      child: Material(
        color: Colors.transparent,
        child: GlassCard(
          padding: const EdgeInsets.all(40),
          child: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children:[
                Text("PROFILE OVERRIDES", style: GoogleFonts.unbounded(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                Text("Modifying overrides for: ${widget.state.selectedVersion}", style: GoogleFonts.plusJakartaSans(color: widget.state.currentEngineColor, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 32),
                
                TextField(
                  controller: _nameController,
                  style: GoogleFonts.plusJakartaSans(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Custom Display Name",
                    labelStyle: const TextStyle(color: Colors.white54),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: widget.state.currentEngineColor)),
                    filled: true,
                    fillColor: Colors.black26,
                  ),
                ),
                const SizedBox(height: 24),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children:[
                    Text("ALLOCATED RAM", style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12)),
                    Text("${_ram.toInt()} GB", style: GoogleFonts.unbounded(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
                SliderTheme(
                  data: SliderThemeData(activeTrackColor: widget.state.currentEngineColor, inactiveTrackColor: Colors.white.withOpacity(0.1), thumbColor: Colors.white),
                  child: Slider(value: _ram, min: 2, max: 32, divisions: 15, onChanged: (val) => setState(() => _ram = val)),
                ),
                const SizedBox(height: 24),

                Text("FORCE SPECIFIC JAVA VERSION", style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children:[
                    Expanded(
                      child: TextField(
                        controller: _javaController,
                        style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: "Path to bin/java (e.g. Auto-Detect)",
                          hintStyle: const TextStyle(color: Colors.white38),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: widget.state.currentEngineColor)),
                          filled: true,
                          fillColor: Colors.black26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.folder_open, color: widget.state.currentEngineColor),
                      onPressed: () async {
                        String? path = await NativePicker.pickFile();
                        if (path != null) setState(() => _javaController.text = path);
                      },
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.arrow_drop_down, color: widget.state.currentEngineColor),
                      onSelected: (val) {
                        setState(() => _javaController.text = val);
                      },
                      itemBuilder: (ctx) => jOpts.map((j) {
                        String label = j;
                        if (j.contains("radium_java")) label = "Managed: ${j.split(Platform.pathSeparator).reversed.skip(2).first}";
                        if (j == "Auto-Detect") label = "Auto-Detect (Recommended)";
                        return PopupMenuItem(value: j, child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12)));
                      }).toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.state.currentEngineColor,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _save,
                    child: Text("SAVE OVERRIDES", style: GoogleFonts.unbounded(fontWeight: FontWeight.w900, letterSpacing: 2)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// MODPACK / ISOLATED PROFILE CREATOR
// ==========================================

class ProfileCreatorModal extends StatefulWidget {
  final LauncherState state;
  const ProfileCreatorModal({super.key, required this.state});

  @override
  State<ProfileCreatorModal> createState() => _ProfileCreatorModalState();
}

class _ProfileCreatorModalState extends State<ProfileCreatorModal> {
  final _nameController = TextEditingController();
  String? _selectedBase;
  List<String> _validBaseVersions =[];

  @override
  void initState() {
    super.initState();
    _filterBaseVersions();
  }

  void _filterBaseVersions() {
    final sep = Platform.pathSeparator;
    _validBaseVersions = widget.state.availableVersions.where((v) {
      final modsDir = Directory("${widget.state.minecraftDir}${sep}versions$sep$v${sep}mods");
      return !modsDir.existsSync(); 
    }).toList();

    if (_validBaseVersions.isNotEmpty) {
      _selectedBase = _validBaseVersions.first;
    }
  }

  Future<void> _createProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _selectedBase == null) return;

    final sep = Platform.pathSeparator;
    final profileDir = Directory("${widget.state.minecraftDir}${sep}versions$sep$name");
    
    if (!await profileDir.exists()) {
      await profileDir.create(recursive: true);
    }
    
    final jsonFile = File("${profileDir.path}$sep$name.json");
    final manifestData = {
      "id": name,
      "inheritsFrom": _selectedBase
    };
    await jsonFile.writeAsString(jsonEncode(manifestData));

    final modsDir = Directory("${profileDir.path}${sep}mods");
    await modsDir.create(recursive: true);

    MinecraftCore.logVerbose("Created Isolated Profile: $name inheriting $_selectedBase");

    widget.state.updateSettings(() {
      widget.state.loadVersions().then((_) {
        widget.state.setVersionAndAutoDetect(name); 
      });
    });

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: GlassCard(
          padding: const EdgeInsets.all(40),
          child: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children:[
                Text("CREATE MODPACK PROFILE", style: GoogleFonts.unbounded(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 8),
                Text("Creates an isolated instance with its own mods/ directory.", style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 32),
                
                TextField(
                  controller: _nameController,
                  style: GoogleFonts.plusJakartaSans(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Profile Name (e.g. MySurvivalPack)",
                    labelStyle: const TextStyle(color: Colors.white54),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: widget.state.currentEngineColor)),
                    filled: true,
                    fillColor: Colors.black26,
                  ),
                ),
                const SizedBox(height: 24),
                
                Text("BASE ENGINE / VERSION", style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                DropdownButtonHideUnderline(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12)),
                    child: DropdownButton<String>(
                      isExpanded: true,
                      hint: Text("Select Base Loader", style: GoogleFonts.plusJakartaSans(color: Colors.white54)),
                      value: _selectedBase,
                      dropdownColor: const Color(0xFF111111),
                      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                      style: GoogleFonts.unbounded(color: Colors.white, fontWeight: FontWeight.w600),
                      items: _validBaseVersions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedBase = val;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.state.currentEngineColor,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _selectedBase == null ? null : _createProfile,
                    child: Text("CREATE ISOLATED INSTANCE", style: GoogleFonts.unbounded(fontWeight: FontWeight.w900, letterSpacing: 2)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// REAL LIVE MOJANG API VERSION INSTALLER MATRIX
// ==========================================

class VersionDownloaderModal extends StatefulWidget {
  final LauncherState state;
  const VersionDownloaderModal({super.key, required this.state});

  @override
  State<VersionDownloaderModal> createState() => _VersionDownloaderModalState();
}

class _VersionDownloaderModalState extends State<VersionDownloaderModal> {
  String selectedType = "VANILLA";
  String selectedVersion = "Loading...";
  bool isDownloading = false;
  bool isFetchingMeta = true;
  String downloadStatus = "";
  
  Map<String, String> manifestUrls = {};
  List<String> versions =[];

  @override
  void initState() {
    super.initState();
    _fetchMojangManifest();
  }

  Future<void> _fetchMojangManifest() async {
    try {
      final res = await http.get(Uri.parse("https://piston-meta.mojang.com/mc/game/version_manifest_v2.json"));
      final data = jsonDecode(res.body);
      final List vList = data['versions'];
      
      for (var v in vList) {
        if (v['type'] == 'release' || widget.state.showSnapshots) {
          manifestUrls[v['id']] = v['url'];
          versions.add(v['id']);
        }
      }
          
      if (mounted) {
        setState(() {
          selectedVersion = versions.first;
          isFetchingMeta = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => downloadStatus = "FAILED TO CONNECT TO MOJANG PISTON");
    }
  }

  int _getMinorVersion(String v) {
    try {
      final parts = v.split('.');
      if (parts.length > 1) return int.parse(parts[1]);
      return 0;
    } catch (_) {
      return 0; 
    }
  }

  Future<void> _startRealDownload() async {
    setState(() {
      isDownloading = true;
      downloadStatus = "CONNECTING TO REPOSITORIES...";
    });
    
    try {
      final sep = Platform.pathSeparator;
      final versionName = "$selectedVersion-${selectedType.toLowerCase()}";
      final vDir = Directory("${widget.state.minecraftDir}${sep}versions$sep$versionName");
      
      if (!await vDir.exists()) {
        await vDir.create(recursive: true);
      }

      if (selectedType == "VANILLA") {
        setState(() => downloadStatus = "DOWNLOADING VANILLA MANIFEST...");
        final manifestUrl = manifestUrls[selectedVersion]!;
        final res = await http.get(Uri.parse(manifestUrl));
        final manifestJson = jsonDecode(res.body);

        manifestJson['id'] = versionName;
        final jsonFile = File("${vDir.path}$sep$versionName.json");
        await jsonFile.writeAsString(jsonEncode(manifestJson));
      } else if (selectedType == "FABRIC") {
        setState(() => downloadStatus = "FETCHING FABRIC META API...");
        final res = await http.get(Uri.parse("https://meta.fabricmc.net/v2/versions/loader/$selectedVersion/0.15.11/profile/json"));
        if (res.statusCode != 200) throw Exception("Fabric does not support this version yet.");
        
        Map<String, dynamic> fManifest = jsonDecode(res.body);
        fManifest['id'] = versionName; 
        
        final jsonFile = File("${vDir.path}$sep$versionName.json");
        await jsonFile.writeAsString(jsonEncode(fManifest));
      }

      setState(() => downloadStatus = "METADATA INSTALLED (Libraries will sync on launch)");
      MinecraftCore.logVerbose("Successfully installed base manifest for $versionName");
      
      await Future.delayed(const Duration(seconds: 1));
      
      widget.state.updateSettings(() {
        widget.state.loadVersions().then((_) {
          widget.state.setVersionAndAutoDetect(versionName);
        }); 
      });

      if (mounted) Navigator.pop(context);

    } catch (e) {
      setState(() => downloadStatus = "ERROR: $e");
      MinecraftCore.logVerbose("MANIFEST DOWNLOAD ERROR: $e");
      await Future.delayed(const Duration(seconds: 4));
      if (mounted) setState(() => isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: GlassCard(
          padding: const EdgeInsets.all(40),
          child: SizedBox(
            width: 500,
            child: isDownloading ? _buildLoading() : _buildSelector(),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children:[
        const CircularProgressIndicator(color: Colors.white),
        const SizedBox(height: 24),
        Text(downloadStatus, textAlign: TextAlign.center, style: GoogleFonts.unbounded(fontSize: 12, letterSpacing: 2, color: widget.state.currentEngineColor, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSelector() {
    final minor = _getMinorVersion(selectedVersion);
    final bool canFabric = minor >= 14; 
    final bool canForge = false;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children:[
        Text("INSTALLATION MATRIX", style: GoogleFonts.unbounded(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
        const SizedBox(height: 32),
        
        Text("ENGINE TARGET", style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 8),
        Row(
          children:[
            _buildTypeBtn("VANILLA", true),
            _buildTypeBtn("FABRIC", canFabric),
            _buildTypeBtn("FORGE", canForge),
          ],
        ),
        
        const SizedBox(height: 24),
        
        Text("VERSION MANIFEST", style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12)),
          child: isFetchingMeta 
            ? const Padding(padding: EdgeInsets.all(12), child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54))))
            : DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: selectedVersion,
              dropdownColor: const Color(0xFF111111),
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
              style: GoogleFonts.unbounded(color: Colors.white, fontWeight: FontWeight.w600),
              items: versions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    selectedVersion = val;
                    final newMinor = _getMinorVersion(val);
                    if (selectedType == "FABRIC" && newMinor < 14) selectedType = "VANILLA";
                    if (selectedType == "FORGE" && newMinor < 7) selectedType = "VANILLA";
                  });
                }
              },
            ),
          ),
        ),

        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.state.currentEngineColor,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: isFetchingMeta || selectedType == "FORGE" ? null : _startRealDownload,
            child: Text(selectedType == "FORGE" ? "FORGE UNAVAILABLE" : "INSTALL BASE FILES", style: GoogleFonts.unbounded(fontWeight: FontWeight.w900, letterSpacing: 2)),
          ),
        )
      ],
    );
  }

  Widget _buildTypeBtn(String t, bool isEnabled) {
    final bool isSelected = selectedType == t;
    return Expanded(
      child: GestureDetector(
        onTap: () { if (isEnabled) setState(() => selectedType = t); },
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent,
            border: Border.all(color: isSelected ? Colors.white : (isEnabled ? Colors.white12 : Colors.white10)),
            borderRadius: BorderRadius.circular(8)
          ),
          alignment: Alignment.center,
          child: Text(t, style: GoogleFonts.unbounded(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : (isEnabled ? Colors.white54 : Colors.white24))),
        ),
      )
    );
  }
}

// ==========================================
// AESTHETIC COMPONENTS & LAUNCH BUTTON
// ==========================================

class LaunchLocalButton extends StatefulWidget {
  final LauncherState state;
  const LaunchLocalButton({super.key, required this.state});

  @override
  State<LaunchLocalButton> createState() => _LaunchLocalButtonState();
}

class _LaunchLocalButtonState extends State<LaunchLocalButton> with SingleTickerProviderStateMixin {
  late AnimationController _breathCtrl;

  @override
  void initState() {
    super.initState();
    _breathCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    super.dispose();
  }

  Future<bool> _isJavaValid(String path) async {
    if (path.toLowerCase() == "system default" || path.toLowerCase() == "auto-detect" || path.isEmpty) {
      try {
        final res = await Process.run('java', ['-version']);
        return res.exitCode == 0;
      } catch (e) {
        return false;
      }
    }
    return File(path).existsSync();
  }

  @override
  Widget build(BuildContext context) {
    return HoverAnimatedScale(
      scale: 1.03,
      child: GestureDetector(
        onTap: () async {
          if (!widget.state.isAuthenticated) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("AUTHENTICATION REQUIRED", style: GoogleFonts.unbounded())));
            return;
          }

          bool validJava = await _isJavaValid(widget.state.resolveActiveJavaPath());
          if (!validJava) {
            if (context.mounted) AnimatedDialog.show(context, JavaMissingModal(state: widget.state));
            return;
          }
          
          widget.state.launchGameLocal();
        },
        child: AnimatedBuilder(
          animation: _breathCtrl,
          builder: (ctx, child) {
            // Apply breathing scale ONLY when not launching
            final breathScale = widget.state.isLaunching ? 1.0 : 1.0 + (_breathCtrl.value * 0.015);
            return Transform.scale(scale: breathScale, child: child);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCirc,
            height: 80,
            width: widget.state.isLaunching ? 400 : 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              boxShadow:[if (!widget.state.isLaunching) BoxShadow(color: widget.state.currentEngineColor.withOpacity(0.3), blurRadius: 40, offset: const Offset(0, 10))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.state.isLaunching ? widget.state.currentEngineColor.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                    border: Border.all(color: widget.state.currentEngineColor.withOpacity(0.5), width: 1.5),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children:[
                      if (widget.state.isLaunching)
                        Positioned(
                          left: 0, top: 0, bottom: 0,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 400 * widget.state.launchProgress,
                            decoration: BoxDecoration(color: widget.state.currentEngineColor.withOpacity(0.2), borderRadius: BorderRadius.circular(40)),
                          ),
                        ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          widget.state.isLaunching ? "INITIALIZING..." : "PLAY GAME",
                          key: ValueKey(widget.state.isLaunching),
                          style: GoogleFonts.unbounded(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 4, color: widget.state.isLaunching ? Colors.white : widget.state.currentEngineColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// REAL MICROSOFT & OFFLINE ACCOUNT MANAGER
// ==========================================

class AccountManagerModal extends StatefulWidget {
  final LauncherState state;
  const AccountManagerModal({super.key, required this.state});

  @override
  State<AccountManagerModal> createState() => _AccountManagerModalState();
}

class _AccountManagerModalState extends State<AccountManagerModal> {
  bool isAuthenticating = false;
  bool isAddingNew = false;
  String statusText = "";
  String deviceCodeStr = "";
  String verificationUrl = "";

  @override
  void initState() {
    super.initState();
    // Default to the "Add" screen if there are no accounts saved
    if (widget.state.savedAccounts.isEmpty) {
      isAddingNew = true;
    }
  }

  Future<void> _doMicrosoftAuth() async {
    setState(() => isAuthenticating = true);
    try {
      setState(() => statusText = "REQUESTING DEVICE CODE...");
      final codeRes = await AuthCore.startMicrosoftDeviceFlow();
      deviceCodeStr = codeRes['user_code']!;
      verificationUrl = codeRes['verification_uri']!;
      setState(() => statusText = "ENTER CODE AT $verificationUrl");

      bool authed = false;
      while (!authed && mounted) {
        await Future.delayed(const Duration(seconds: 5));
        final tokenRes = await AuthCore.pollMicrosoftToken(codeRes['device_code']!);
        if (tokenRes['access_token'] != null) {
          authed = true;
          setState(() => statusText = "SECURING XBOX LIVE...");
          final mcData = await AuthCore.authenticateMinecraft(tokenRes['access_token']);
          
          widget.state.addOrUpdateAccount({
            'username': mcData['username'] as String,
            'uuid': mcData['uuid'] as String,
            'accessToken': mcData['accessToken'] as String,
            'userType': mcData['userType'] as String,
            'authMode': AuthMode.microsoft.toString(),
            'msRefreshToken': tokenRes['refresh_token'] as String?,
          });
          
          if (mounted) Navigator.pop(context);
        } else if (tokenRes['error'] != 'authorization_pending') {
          throw Exception(tokenRes['error_description']);
        }
      }
    } catch (e) {
      setState(() => statusText = "AUTH FAILED: $e");
    }
  }

  void _doOfflineAuth(String name) {
    if (name.isEmpty) return;
    final data = AuthCore.generateOfflineAccount(name);
    
    widget.state.addOrUpdateAccount({
      'username': data['username']!,
      'uuid': data['uuid']!,
      'accessToken': data['accessToken']!,
      'userType': data['userType']!,
      'authMode': AuthMode.offline.toString(),
      'msRefreshToken': null,
    });
    
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: GlassCard(
          padding: const EdgeInsets.all(40),
          child: SizedBox(
            width: 450,
            child: isAuthenticating 
              ? _buildLoading() 
              : (isAddingNew ? _buildAddAccount() : _buildAccountList()),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (deviceCodeStr.isNotEmpty) ...[
          Text(deviceCodeStr, style: GoogleFonts.unbounded(fontSize: 32, color: widget.state.currentEngineColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
        ],
        Text(statusText, textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(color: Colors.white)),
        const SizedBox(height: 24),
        const CircularProgressIndicator(color: Colors.white),
      ],
    );
  }

  Widget _buildAccountList() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children:[
            Text("ACCOUNT MANAGER", style: GoogleFonts.unbounded(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
            Text("${widget.state.savedAccounts.length} SAVED", style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54)),
          ],
        ),
        const SizedBox(height: 24),
        
        Container(
          constraints: const BoxConstraints(maxHeight: 300),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: widget.state.savedAccounts.length,
            itemBuilder: (ctx, i) {
              final acc = widget.state.savedAccounts[i];
              final isMicrosoft = acc['authMode'] == AuthMode.microsoft.toString();
              final isActive = widget.state.uuid == acc['uuid'];

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isActive ? widget.state.currentEngineColor.withOpacity(0.1) : Colors.white.withOpacity(0.05),
                  border: Border.all(color: isActive ? widget.state.currentEngineColor.withOpacity(0.5) : Colors.white12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.black26,
                    backgroundImage: isMicrosoft ? NetworkImage("https://minotar.net/helm/${acc['uuid']}/64.png") : null,
                    child: !isMicrosoft ? const Icon(Icons.person, color: Colors.white54) : null,
                  ),
                  title: Text(acc['username'], style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Row(
                    children:[
                      Icon(isMicrosoft ? Icons.window : Icons.wifi_off, size: 12, color: isMicrosoft ? const Color(0xFF00A4EF) : Colors.white38),
                      const SizedBox(width: 4),
                      Text(isMicrosoft ? "Microsoft Authentication" : "Offline Account", style: GoogleFonts.plusJakartaSans(color: isMicrosoft ? const Color(0xFF00A4EF) : Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children:[
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(color: widget.state.currentEngineColor, borderRadius: BorderRadius.circular(4)),
                          child: Text("ACTIVE", style: GoogleFonts.unbounded(fontSize: 8, color: Colors.black, fontWeight: FontWeight.bold)),
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.white38),
                        onPressed: () {
                          AnimatedDialog.show(
                            context,
                            ConfirmDeleteModal(
                              title: "REMOVE ACCOUNT",
                              message: "Are you sure you want to remove the account '${acc['username']}' from the launcher?",
                              onConfirm: () {
                                setState(() => widget.state.removeAccount(acc['uuid']));
                                if (widget.state.savedAccounts.isEmpty) {
                                  setState(() => isAddingNew = true);
                                }
                              },
                            )
                          );
                        },
                      ),
                    ],
                  ),
                  onTap: () {
                    widget.state.switchAccount(acc['uuid']);
                    Navigator.pop(context);
                  },
                ),
              );
            },
          ),
        ),
        
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.05),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: Text("ADD NEW ACCOUNT", style: GoogleFonts.unbounded(fontWeight: FontWeight.bold, fontSize: 12)),
            onPressed: () => setState(() => isAddingNew = true),
          ),
        ),
      ],
    );
  }

  Widget _buildAddAccount() {
    final offlineController = TextEditingController();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children:[
        Row(
          children:[
            if (widget.state.savedAccounts.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white54),
                onPressed: () => setState(() => isAddingNew = false),
              ),
            Text("ADD ACCOUNT", style: GoogleFonts.unbounded(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
          ],
        ),
        const SizedBox(height: 32),
        InkWell(
          onTap: _doMicrosoftAuth,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFF00A4EF).withOpacity(0.3)), borderRadius: BorderRadius.circular(12), color: const Color(0xFF00A4EF).withOpacity(0.05)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children:[Icon(Icons.window, color: const Color(0xFF00A4EF)), const SizedBox(width: 16), Text("MICROSOFT LOGIN", style: GoogleFonts.plusJakartaSans(color: const Color(0xFF00A4EF), fontWeight: FontWeight.bold))]),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: offlineController,
          style: GoogleFonts.plusJakartaSans(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Enter Offline Username",
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
            focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
            suffixIcon: IconButton(
              icon: const Icon(Icons.arrow_forward, color: Colors.white),
              onPressed: () => _doOfflineAuth(offlineController.text),
            )
          ),
          onSubmitted: _doOfflineAuth,
        ),
      ],
    );
  }
}

// ==========================================
// BACKGROUND VISUALS
// ==========================================

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(24)});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors:[Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.01)]),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final Color accent;
  final VoidCallback onTap;
  const _NavIcon({required this.icon, required this.isSelected, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return HoverAnimatedScale(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 48, height: 48,
          decoration: BoxDecoration(color: isSelected ? accent.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(16), border: Border.all(color: isSelected ? accent.withOpacity(0.5) : Colors.transparent)),
          child: Icon(icon, color: isSelected ? accent : Colors.white54, size: 24),
        ),
      ),
    );
  }
}

class AnimatedAtmosphere extends StatefulWidget {
  final Color color;
  const AnimatedAtmosphere({super.key, required this.color});
  @override
  State<AnimatedAtmosphere> createState() => _AnimatedAtmosphereState();
}

class _AnimatedAtmosphereState extends State<AnimatedAtmosphere> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value * 2 * math.pi;
        return TweenAnimationBuilder<Color?>(
          tween: ColorTween(begin: widget.color, end: widget.color),
          duration: const Duration(milliseconds: 800),
          builder: (context, color, child) {
            return Stack(
              children:[
                Positioned(left: MediaQuery.of(context).size.width * 0.5 + math.sin(t) * 200, top: MediaQuery.of(context).size.height * 0.5 + math.cos(t) * 100, child: _buildOrb(color!, 600, 0.15)),
                Positioned(left: MediaQuery.of(context).size.width * 0.2 + math.cos(t * 1.5) * 300, top: MediaQuery.of(context).size.height * 0.8 + math.sin(t * 1.5) * 200, child: _buildOrb(const Color(0xFF0033FF), 800, 0.1)),
              ],
            );
          },
        );
      },
    );
  }
  Widget _buildOrb(Color color, double size, double opacity) => Transform.translate(offset: Offset(-size / 2, -size / 2), child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color.withOpacity(opacity), Colors.transparent]))));
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.015)..strokeWidth = 1.0;
    for (double i = 0; i < size.width; i += 40.0) canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    for (double i = 0; i < size.height; i += 40.0) canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
// ==========================================
// MISSING JAVA PROMPT & AUTO-INSTALLER
// ==========================================

class JavaMissingModal extends StatefulWidget {
  final LauncherState state;
  const JavaMissingModal({super.key, required this.state});

  @override
  State<JavaMissingModal> createState() => _JavaMissingModalState();
}

class _JavaMissingModalState extends State<JavaMissingModal> {
  bool isInstalling = false;
  String status = "";

  Future<void> _installJava(int version) async {
    setState(() {
      isInstalling = true;
      status = "STARTING INSTALL...";
    });
    try {
      await JavaManager.installTemurin(version, widget.state.minecraftDir, (msg) {
        if (mounted) setState(() => status = msg);
      });
      await widget.state.refreshJavas();
      widget.state.globalJavaPath = "Auto-Detect"; // Set back to auto-detect to find new java
      await widget.state.saveGlobalSettings();
      
      if (mounted) {
        Navigator.pop(context);
        widget.state.launchGameLocal(); // Auto-start the game after install
      }
    } catch (e) {
      if (mounted) setState(() => status = "ERROR: $e");
      await Future.delayed(const Duration(seconds: 4));
      if (mounted) setState(() => isInstalling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: GlassCard(
          padding: const EdgeInsets.all(40),
          child: SizedBox(
            width: 450,
            child: isInstalling
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children:[
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 24),
                      Text(status, textAlign: TextAlign.center, style: GoogleFonts.unbounded(fontSize: 12, color: widget.state.currentEngineColor, fontWeight: FontWeight.bold)),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children:[
                      const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 48),
                      const SizedBox(height: 16),
                      Text("JAVA ENVIRONMENT MISSING", style: GoogleFonts.unbounded(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                      const SizedBox(height: 16),
                      Text(
                        "No valid Java installation was found at the configured path or on your system. Minecraft requires Java to execute.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.state.currentEngineColor,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _installJava(21), // Target Java 21 for modern versions
                          child: Text("AUTO-INSTALL JAVA 21", style: GoogleFonts.unbounded(fontWeight: FontWeight.w900, letterSpacing: 1)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: Text("CANCEL", style: GoogleFonts.unbounded(fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ),
                      )
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// CONFIRMATION DIALOG
// ==========================================

class ConfirmDeleteModal extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onConfirm;

  const ConfirmDeleteModal({
    super.key,
    required this.title,
    required this.message,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: GlassCard(
          padding: const EdgeInsets.all(40),
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children:[
                const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 48),
                const SizedBox(height: 16),
                Text(title, style: GoogleFonts.unbounded(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 32),
                Row(
                  children:[
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text("CANCEL", style: GoogleFonts.unbounded(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(context); // Close the dialog
                          onConfirm();            // Execute delete
                        },
                        child: Text("DELETE", style: GoogleFonts.unbounded(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 12)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// FLUID ANIMATION UTILITIES
// ==========================================

class HoverAnimatedScale extends StatefulWidget {
  final Widget child;
  final double scale;
  const HoverAnimatedScale({super.key, required this.child, this.scale = 1.05});

  @override
  State<HoverAnimatedScale> createState() => _HoverAnimatedScaleState();
}

class _HoverAnimatedScaleState extends State<HoverAnimatedScale> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        scale: isHovered ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

class StaggeredEntrance extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const StaggeredEntrance({super.key, required this.child, this.delayMs = 0});

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutExpo);
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(_anim),
        child: widget.child,
      ),
    );
  }
}

class AnimatedDialog {
  static void show(BuildContext context, Widget dialog) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Dismiss",
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation1, animation2) => dialog,
      transitionBuilder: (context, a1, a2, child) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(a1.value),
          child: Opacity(opacity: a1.value, child: child),
        );
      },
    );
  }
}
