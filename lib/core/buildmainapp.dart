import 'package:vaxpsam/core/venom_layout.dart';
import 'main_export.dart';

class BuildMainApp extends StatefulWidget {
  const BuildMainApp({super.key});

  @override
  State<BuildMainApp> createState() => _BuildMainAppState();
}

class _BuildMainAppState extends State<BuildMainApp> {
  int _selectedIndex = 0;
  bool _consoleOpen = false;

  // All pages to prevent rebuilding
  final List<Widget> _pages = const [
    MySystemPageRefactored(),
    BrowsersPage(),
    ToolsPage(),
    CybersecurityPage(),
    DeveloperToolsPage(),
    IdesPage(),
    ContentCreationPage(),
    SystemInfoPage(),
    GamingUtilitiesPage(),
    DesktopEnvironmentPage(),
    AdvancedDebuggingPage(),
    VaxpDebPage(),
    SettingsPage(),
  ];

  final List<String> _pageTitles = const [
    "My System",
    "Browsers",
    "Tools",
    "Cybersecurity",
    "Developer Tools",
    "IDEs",
    "Content Creation",
    "System Info",
    "Gaming Utilities",
    "Desktop Environment",
    "Advanced Debugging",
    "Vaxp Deb",
    "Settings",
  ];

  void _toggleConsole() => setState(() => _consoleOpen = !_consoleOpen);

  @override
  Widget build(BuildContext context) {
    return VenomScaffold(
      title: _pageTitles[_selectedIndex],
      body: Stack(
        children: [
          // Main content with sidebar
          Row(
            children: [
              // Sidebar
              Sidebar(
                selectedIndex: _selectedIndex,
                onItemSelected:
                    (index) => setState(() => _selectedIndex = index),
                onConsoleToggle: _toggleConsole,
                isConsoleOpen: _consoleOpen,
              ),

              // Main content area
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: IndexedStack(
                          index: _selectedIndex,
                          children: _pages,
                        ),
                      ),
                    ),
                    // Console panel (now at the bottom of the content area)
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: SizedBox(
                        height: 220,
                        child: ConsolePanel(lines: const [], isPaused: false),
                      ),
                      crossFadeState:
                          _consoleOpen
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 250),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
