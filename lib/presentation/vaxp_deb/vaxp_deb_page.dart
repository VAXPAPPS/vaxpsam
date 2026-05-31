import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import '../home/widgets/section_widgets.dart';
import '../../core/theme/app_theme.dart';

class VaxpDebPage extends StatefulWidget {
  const VaxpDebPage({super.key});

  @override
  State<VaxpDebPage> createState() => _VaxpDebPageState();
}

class _VaxpDebPageState extends State<VaxpDebPage>
    with TickerProviderStateMixin {
  String? selectedProjectPath;
  String? selectedIconPath;
  bool isConverting = false;
  String conversionStatus = '';
  late AnimationController _animationController;

  // Derived names
  String? _debPackageName; // Debian-safe package name

  // Desktop entry form fields
  final _desktopFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _commentController = TextEditingController();
  final _categoriesController = TextEditingController();
  final _keywordsController = TextEditingController();
  final _mimeTypeController = TextEditingController();
  String _selectedTerminal = 'false';
  String _autoExecPath = '';
  String? _selectedAppType;

  // Presets map: app type => { keywords, mimeType, categories }
  static const Map<String, Map<String, String>> _appTypePresets = {
    'File Manager': {
      'icon': 'folder',
      'keywords': 'filemanager;files;explorer;browser;',
      'mimeType': 'inode/directory;',
      'categories': 'System;FileTools;FileManager;',
    },
    'Video Player': {
      'icon': 'movie',
      'keywords': 'video;player;media;movie;stream;',
      'mimeType':
          'video/mp4;video/x-matroska;video/x-msvideo;video/webm;video/ogg;video/mpeg;',
      'categories': 'AudioVideo;Video;Player;',
    },
    'Audio Player': {
      'icon': 'music_note',
      'keywords': 'audio;music;player;sound;mp3;',
      'mimeType': 'audio/mpeg;audio/ogg;audio/flac;audio/wav;audio/aac;',
      'categories': 'AudioVideo;Audio;Player;',
    },
    'Store': {
      'icon': 'store',
      'keywords': 'store;software;install;packages;apps;',
      'mimeType': 'application/vnd.debian.binary-package;',
      'categories': 'System;PackageManager;',
    },
    'Terminal': {
      'icon': 'terminal',
      'keywords': 'terminal;console;shell;bash;command;',
      'mimeType': 'application/x-shell-script;',
      'categories': 'System;TerminalEmulator;',
    },
    'Settings': {
      'icon': 'settings',
      'keywords': 'settings;preferences;configuration;control;options;',
      'mimeType': '',
      'categories': 'Settings;System;',
    },
    'Text Editor': {
      'icon': 'edit_note',
      'keywords': 'editor;text;notepad;code;write;',
      'mimeType': 'text/plain;text/x-log;application/json;text/xml;',
      'categories': 'Utility;TextEditor;',
    },
    'Image Viewer': {
      'icon': 'image',
      'keywords': 'image;photo;picture;viewer;gallery;',
      'mimeType':
          'image/png;image/jpeg;image/gif;image/webp;image/svg+xml;image/bmp;image/tiff;image/avif;image/heif;',
      'categories': 'Graphics;Viewer;',
    },
    'Web Browser': {
      'icon': 'language',
      'keywords': 'browser;web;internet;html;url;',
      'mimeType': 'text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;',
      'categories': 'Network;WebBrowser;',
    },
    'Archive Manager': {
      'icon': 'archive',
      'keywords': 'archive;compress;zip;extract;tar;',
      'mimeType':
          'application/zip;application/x-tar;application/x-7z-compressed;application/x-rar-compressed;application/gzip;',
      'categories': 'Utility;Archiving;',
    },
  };

  // DEB control fields (user-editable)
  final _versionController = TextEditingController(text: '0.1.0');
  final _sectionController = TextEditingController(text: 'utils');
  final _priorityController = TextEditingController(text: 'optional');
  final _architectureController = TextEditingController(text: 'amd64');
  final _maintainerController = TextEditingController(
    text: 'VAXP DEB Converter <vaxp@vaxp.org>',
  );
  final _descriptionController = TextEditingController(
    text: 'Flutter application converted to DEB package',
  );

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _commentController.dispose();
    _categoriesController.dispose();
    _keywordsController.dispose();
    _mimeTypeController.dispose();
    _versionController.dispose();
    _sectionController.dispose();
    _priorityController.dispose();
    _architectureController.dispose();
    _maintainerController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectProjectFolder() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Flutter Project Folder',
      );

      if (selectedDirectory != null) {
        setState(() {
          selectedProjectPath = selectedDirectory;
          conversionStatus =
              'Project selected: ${path.basename(selectedDirectory)}';
          // Precompute Debian-safe name from the folder basename
          _debPackageName = _toDebianPackageName(
            path.basename(selectedDirectory),
          );
        });
      }
    } catch (e) {
      _showErrorDialog('Error selecting folder: $e');
    }
  }

  Future<void> _selectIconFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        dialogTitle: 'Select Application Icon',
        allowedExtensions: ['png', 'jpg', 'jpeg', 'svg'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          selectedIconPath = result.files.single.path!;
          conversionStatus =
              'Icon selected: ${path.basename(selectedIconPath!)}';
        });
      }
    } catch (e) {
      _showErrorDialog('Error selecting icon: $e');
    }
  }

  void _autoFillDesktopForm() {
    if (selectedProjectPath != null) {
      final projectName = path.basename(selectedProjectPath!);
      final debName = _debPackageName ?? _toDebianPackageName(projectName);
      _nameController.text = projectName;
      _commentController.text = 'Flutter Application - $projectName';
      _categoriesController.text = 'Utility;Development;';
      _autoExecPath = '/usr/bin/$debName';

      setState(() {
        conversionStatus = 'Desktop form auto-filled for: $projectName';
      });
    } else {
      _showErrorDialog('Please select a Flutter project folder first.');
    }
  }

  void _clearDesktopForm() {
    _nameController.clear();
    _commentController.clear();
    _categoriesController.clear();
    _keywordsController.clear();
    _mimeTypeController.clear();
    _selectedTerminal = 'false';
    _autoExecPath = '';

    setState(() {
      conversionStatus = 'Desktop form cleared';
    });
  }

  String _generateDesktopEntry() {
    final name =
        _nameController.text.isNotEmpty ? _nameController.text : 'Flutter App';
    final comment =
        _commentController.text.isNotEmpty
            ? _commentController.text
            : 'Flutter Application';
    final categories =
        _categoriesController.text.isNotEmpty
            ? _categoriesController.text
            : 'Utility;';
    final exec =
        _autoExecPath.isNotEmpty ? _autoExecPath : '/usr/bin/flutter_app';
    final debName =
        _debPackageName ??
        (selectedProjectPath != null
            ? _toDebianPackageName(path.basename(selectedProjectPath!))
            : 'flutter-app');
    final icon =
        selectedIconPath != null
            ? '/usr/share/icons/hicolor/256x256/apps/$debName.png'
            : '/usr/share/icons/hicolor/256x256/apps/flutter_app.png';

    final keywords = _keywordsController.text.trim();
    final mimeType = _mimeTypeController.text.trim();

    final buffer = StringBuffer();
    buffer.write('[Desktop Entry]\n');
    buffer.write('Version=1.0\n');
    buffer.write('Type=Application\n');
    buffer.write('Name=$name\n');
    buffer.write('Comment=$comment\n');
    buffer.write('Exec=$exec\n');
    buffer.write('Icon=$icon\n');
    buffer.write('Terminal=$_selectedTerminal\n');
    buffer.write('Categories=$categories\n');
    if (keywords.isNotEmpty) buffer.write('Keywords=$keywords\n');
    if (mimeType.isNotEmpty) buffer.write('MimeType=$mimeType\n');
    return buffer.toString();
  }

  Future<void> _convertToDeb() async {
    if (selectedProjectPath == null) {
      _showErrorDialog('Please select a Flutter project folder first.');
      return;
    }

    setState(() {
      isConverting = true;
      conversionStatus = 'Starting conversion...';
    });

    try {
      await _performConversion();
    } catch (e) {
      _showErrorDialog('Conversion failed: $e');
    } finally {
      setState(() {
        isConverting = false;
      });
    }
  }

  Future<void> _performConversion() async {
    final projectName = path.basename(selectedProjectPath!);
    final debName = _toDebianPackageName(projectName);
    // Save for later UI generation
    _debPackageName = debName;
    final outputDir = path.join(selectedProjectPath!, 'deb_output');

    setState(() {
      conversionStatus = 'Checking for existing build...';
    });

    // Check if build bundle exists
    final buildDir = path.join(
      selectedProjectPath!,
      'build',
      'linux',
      'x64',
      'release',
      'bundle',
    );
    if (!await Directory(buildDir).exists()) {
      throw Exception(
        'Build bundle not found at: $buildDir\nPlease build your Flutter app first using: flutter build linux --release',
      );
    }

    setState(() {
      conversionStatus =
          'Found existing build bundle, creating DEB package structure...';
    });

    // Create DEB package structure with build directory reference
    await _createDebStructure(debName, projectName, outputDir, buildDir);

    setState(() {
      conversionStatus = 'Generating DEB package...';
    });

    // Generate DEB package
    await _generateDebPackage(debName, outputDir);

    setState(() {
      conversionStatus = 'Conversion completed successfully!';
    });

    _showSuccessDialog(debName);
  }

  Future<void> _createDebStructure(
    String debName,
    String originalExecName,
    String outputDir,
    String buildDir,
  ) async {
    // Create directory structure
    final debianDir = path.join(outputDir, 'DEBIAN');
    final usrDir = path.join(outputDir, 'usr', 'bin');
    final appDir = path.join(outputDir, 'usr', 'share', debName);
    final desktopDir = path.join(outputDir, 'usr', 'share', 'applications');
    final iconsDir = path.join(
      outputDir,
      'usr',
      'share',
      'icons',
      'hicolor',
      '256x256',
      'apps',
    );

    await Directory(debianDir).create(recursive: true);
    await Directory(usrDir).create(recursive: true);
    await Directory(appDir).create(recursive: true);
    await Directory(desktopDir).create(recursive: true);
    await Directory(iconsDir).create(recursive: true);

    // Create control file with user-provided values
    final controlFile = File(path.join(debianDir, 'control'));
    final version =
        _versionController.text.isNotEmpty ? _versionController.text : '0.1.0';
    final section =
        _sectionController.text.isNotEmpty ? _sectionController.text : 'utils';
    final priority =
        _priorityController.text.isNotEmpty
            ? _priorityController.text
            : 'optional';
    final architecture =
        _architectureController.text.isNotEmpty
            ? _architectureController.text
            : 'amd64';
    final maintainer =
        _maintainerController.text.isNotEmpty
            ? _maintainerController.text
            : 'VAXP DEB Converter <vaxp@vaxp.org>';
    final description =
        _descriptionController.text.isNotEmpty
            ? _descriptionController.text
            : 'Flutter application converted to DEB package';
    await controlFile.writeAsString('''
Package: $debName
Version: $version
Section: $section
Priority: $priority
Architecture: $architecture
Depends: libc6, libgcc-s1, libstdc++6, libx11-6, libxcomposite1, libxdamage1, libxext6, libxfixes3, libxrandr2, libxrender1, libxss1, libxtst6, libgl1, libglu1-mesa
Maintainer: $maintainer
Description: $description
 A Flutter application packaged as a DEB package using VAXP DEB Converter.
 This package includes all necessary Flutter runtime dependencies.
''');

    // Copy built Flutter app bundle
    setState(() {
      conversionStatus = 'Copying Flutter app bundle...';
    });

    // Copy all files from bundle to app directory
    await Process.run('cp', ['-a', '$buildDir/.', appDir]);

    // Ensure executable permissions
    final executablePath = path.join(appDir, originalExecName);
    if (await File(executablePath).exists()) {
      await Process.run('chmod', ['+x', executablePath]);
    }

    // Handle icon
    if (selectedIconPath != null) {
      // Copy selected icon
      final iconFile = File(path.join(iconsDir, '$debName.png'));
      await File(selectedIconPath!).copy(iconFile.path);
    } else {
      // Create a default icon if none selected
      await _createDefaultIcon(iconsDir, debName);
    }

    // Create desktop entry using form data
    final desktopFile = File(path.join(desktopDir, '$debName.desktop'));
    final desktopEntry = _generateDesktopEntry();
    await desktopFile.writeAsString(desktopEntry);

    // Create executable script for the bundle
    final executableFile = File(path.join(usrDir, debName));
    await executableFile.writeAsString('''#!/bin/bash
# المسار الأساسي للتطبيق مع الاقتباسات لضمان عمله مع المسافات
APP_DIR="/usr/share/$debName"

# إعداد بيئة العمل لمكتبات فلاتر
export LD_LIBRARY_PATH="\$APP_DIR/lib:\$LD_LIBRARY_PATH"

# الانتقال إلى مجلد التطبيق
cd "\$APP_DIR"

# التأكد من وجود الملف التنفيذي
if [ ! -f "./$originalExecName" ]; then
    echo "Error: Flutter executable not found: $originalExecName"
    exit 1
fi

# التأكد من أن الملف لديه أذونات التشغيل
chmod +x "./$originalExecName"

# تشغيل التطبيق مع تمرير كل المدخلات
exec "./$originalExecName" "\$@"
''');
    await Process.run('chmod', ['+x', executableFile.path]);
  }

  Future<void> _createDefaultIcon(String iconsDir, String projectName) async {
    // Create a simple default icon using ImageMagick if available
    try {
      final iconFile = File(path.join(iconsDir, '$projectName.png'));
      await Process.run('convert', [
        'size',
        '256x256',
        'xc:transparent',
        'fill',
        '#6366F1',
        'draw',
        'circle 128,128 128,64',
        'fill',
        'white',
        'pointsize',
        '80',
        'font',
        'Arial-Bold',
        'gravity',
        'center',
        'annotate',
        '+0+0',
        projectName.substring(0, 1).toUpperCase(),
        iconFile.path,
      ]);
    } catch (e) {
      // If ImageMagick is not available, create a simple text file as placeholder
      final iconFile = File(path.join(iconsDir, '$projectName.png'));
      await iconFile.writeAsString('Default icon placeholder');
    }
  }

  Future<void> _generateDebPackage(String debName, String outputDir) async {
    final debFile = path.join(selectedProjectPath!, '$debName.deb');
    final result = await Process.run('dpkg-deb', [
      '--build',
      outputDir,
      debFile,
    ]);

    if (result.exitCode != 0) {
      throw Exception('DEB package creation failed: ${result.stderr}');
    }
  }

  // Convert a Flutter project name (may include underscores, etc.) to a Debian-safe package name
  // Rules: lowercase, allowed chars [a-z0-9+.-], replace '_' with '-', must start with alphanumeric
  String _toDebianPackageName(String input) {
    // Replace underscores with dashes
    String name = input.replaceAll('_', '-').toLowerCase();
    // Remove invalid characters
    name = name.replaceAll(RegExp('[^a-z0-9+.-]'), '');
    // Trim leading non-alphanumeric/dot/plus/minus to ensure starts with alphanumeric
    name = name.replaceFirst(RegExp('^[^a-z0-9]+'), '');
    // Remove leading separators if any remain
    name = name.replaceFirst(RegExp('^[+.-]+'), '');
    // Collapse duplicate separators
    name = name.replaceAll(RegExp('[+.-]{2,}'), '-');
    if (name.isEmpty) {
      return 'app';
    }
    return name;
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Error'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _showSuccessDialog(String projectName) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Success!'),
            content: Text('DEB package created successfully: $projectName.deb'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SectionVenomScaffold(
      title: 'VAXP DEB Converter',

      children: [
        _buildProjectSelectionCard(context),
        buildIconSelectionCard(context),
        _buildAutoMimeKeywordCard(context),
        _buildDesktopEntryCard(context),
        _buildConvertButton(context),
        _buildStatusDisplay(context),
      ],
    );
  }

  void _applyAppTypePreset(String appType) {
    final preset = _appTypePresets[appType];
    if (preset == null) return;
    setState(() {
      _selectedAppType = appType;
      _keywordsController.text = preset['keywords'] ?? '';
      _mimeTypeController.text = preset['mimeType'] ?? '';
      if ((preset['categories'] ?? '').isNotEmpty) {
        _categoriesController.text = preset['categories']!;
      }
      conversionStatus = 'Auto-filled preset: $appType';
    });
  }

  IconData _presetIcon(String appType) {
    const map = {
      'File Manager': Icons.folder_open,
      'Video Player': Icons.movie,
      'Audio Player': Icons.music_note,
      'Store': Icons.store,
      'Terminal': Icons.terminal,
      'Settings': Icons.settings,
      'Text Editor': Icons.edit_note,
      'Image Viewer': Icons.image,
      'Web Browser': Icons.language,
      'Archive Manager': Icons.archive,
    };
    return map[appType] ?? Icons.apps;
  }

  Widget _buildAutoMimeKeywordCard(BuildContext context) {
    return MacAppStoreCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: macAppStoreBlue, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Auto MimeType & Keywords',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Choose an application type to auto-fill Keywords, MimeType, and Categories',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: macAppStoreGray),
          ),
          const SizedBox(height: 16),
          // Grid of preset chips
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children:
                _appTypePresets.keys.map((appType) {
                  final isSelected = _selectedAppType == appType;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: InkWell(
                      onTap: () => _applyAppTypePreset(appType),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient:
                              isSelected
                                  ? LinearGradient(
                                    colors: [
                                      macAppStoreBlue,
                                      // ignore: deprecated_member_use
                                      macAppStoreBlue.withOpacity(0.7),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                  : null,
                          color: isSelected ? null : macAppStoreCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                isSelected
                                    ? macAppStoreBlue
                                    // ignore: deprecated_member_use
                                    : macAppStoreLightGray.withOpacity(0.3),
                            width: isSelected ? 1.5 : 1,
                          ),
                          boxShadow:
                              isSelected
                                  ? [
                                    BoxShadow(
                                      // ignore: deprecated_member_use
                                      color: macAppStoreBlue.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                  : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _presetIcon(appType),
                              size: 18,
                              color:
                                  isSelected
                                      ? Colors.white
                                      : macAppStoreLightGray,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              appType,
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(
                                color:
                                    isSelected
                                        ? Colors.white
                                        : macAppStoreLightGray,
                                fontWeight:
                                    isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
          if (_selectedAppType != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: macAppStoreBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  // ignore: deprecated_member_use
                  color: macAppStoreBlue.withOpacity(0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: macAppStoreBlue,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Applied: $_selectedAppType — Keywords & MimeType auto-filled below',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: macAppStoreBlue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.close,
                      size: 16,
                      color: macAppStoreLightGray,
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedAppType = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProjectSelectionCard(BuildContext context) {
    return MacAppStoreCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_outlined, color: macAppStoreBlue, size: 28),
              const SizedBox(width: 12),
              Text(
                'Select Built Flutter Project',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Select a Flutter project that has been built with: flutter build linux --release',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: macAppStoreGray),
          ),
          const SizedBox(height: 16),
          if (selectedProjectPath != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: macAppStoreBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: macAppStoreBlue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      path.basename(selectedProjectPath!),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectProjectFolder,
              icon: const Icon(Icons.folder_open),
              label: Text(
                selectedProjectPath == null
                    ? 'Select Project Folder'
                    : 'Change Project Folder',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: macAppStoreBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildIconSelectionCard(BuildContext context) {
    return MacAppStoreCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.image_outlined, color: macAppStoreBlue, size: 28),
              const SizedBox(width: 12),
              Text(
                'Application Icon (Optional)',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Select a PNG, JPG, or SVG icon for your application',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: macAppStoreGray),
          ),
          const SizedBox(height: 16),
          if (selectedIconPath != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: macAppStoreBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: macAppStoreBlue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      path.basename(selectedIconPath!),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        selectedIconPath = null;
                        conversionStatus = 'Icon removed';
                      });
                    },
                    icon: const Icon(Icons.close),
                    iconSize: 20,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectIconFile,
              icon: const Icon(Icons.image),
              label: Text(
                selectedIconPath == null
                    ? 'Select Icon File'
                    : 'Change Icon File',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: macAppStoreCard,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopEntryCard(BuildContext context) {
    return MacAppStoreCard(
      child: Form(
        key: _desktopFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.desktop_windows_outlined,
                  color: macAppStoreBlue,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Desktop Entry & DEB Control Configuration',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Configure the desktop entry and DEB control fields for your application',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: macAppStoreGray),
            ),
            const SizedBox(height: 20),
            // Desktop entry fields
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Application Name',
                hintText: 'Enter application name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter application name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _commentController,
              decoration: const InputDecoration(
                labelText: 'Comment/Description',
                hintText: 'Enter application description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _categoriesController,
              decoration: const InputDecoration(
                labelText: 'Categories',
                hintText: 'e.g., Utility;Development;',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Run in Terminal:',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _selectedTerminal,
                  items: const [
                    DropdownMenuItem(value: 'false', child: Text('No')),
                    DropdownMenuItem(value: 'true', child: Text('Yes')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedTerminal = value!;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            // DEB control fields
            Text(
              'DEB Control Fields',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _versionController,
              decoration: const InputDecoration(
                labelText: 'Version',
                hintText: 'e.g., 1.0.0',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sectionController,
              decoration: const InputDecoration(
                labelText: 'Section',
                hintText: 'e.g., utils',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priorityController,
              decoration: const InputDecoration(
                labelText: 'Priority',
                hintText: 'e.g., optional',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _architectureController,
              decoration: const InputDecoration(
                labelText: 'Architecture',
                hintText: 'e.g., amd64',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _maintainerController,
              decoration: const InputDecoration(
                labelText: 'Maintainer',
                hintText: 'e.g., John Doe <john@example.com>',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Short package description',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            // Desktop Entry optional fields
            Text(
              'Desktop Entry Optional Fields',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _keywordsController,
              decoration: const InputDecoration(
                labelText: 'Keywords',
                hintText: 'e.g., editor;text;notepad;',
                border: OutlineInputBorder(),
                helperText:
                    'Semicolon-separated keywords for application search',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _mimeTypeController,
              decoration: const InputDecoration(
                labelText: 'MimeType',
                hintText: 'e.g., text/plain;image/png;',
                border: OutlineInputBorder(),
                helperText:
                    'Semicolon-separated MIME types handled by the app',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _autoFillDesktopForm,
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('Auto Fill'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: macAppStoreCard,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _clearDesktopForm,
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: macAppStoreCard,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConvertButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: SizedBox(
        height: 60,
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed:
              selectedProjectPath != null && !isConverting
                  ? _convertToDeb
                  : null,
          icon:
              isConverting
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                  : const Icon(Icons.build),
          label: Text(
            isConverting ? 'Converting...' : 'Convert to DEB',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: macAppStoreBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 8,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusDisplay(BuildContext context) {
    if (conversionStatus.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: macAppStoreCard,
        borderRadius: BorderRadius.circular(12),
        // ignore: deprecated_member_use
        border: Border.all(color: macAppStoreLightGray.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            isConverting ? Icons.sync : Icons.info_outline,
            color: macAppStoreBlue,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              conversionStatus,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
