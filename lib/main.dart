import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:light/light.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

const List<String> _placeTypes = ['Study', 'Rest', 'Social'];
const List<String> _historySortOptions = [
  'Newest',
  'Oldest',
  'Best study fit',
  'Best rest fit',
  'Best social fit',
  'Best rated',
  'Quietest',
  'Noisiest',
  'Brightest',
  'Dimmest',
];
const String _mqttConfigAssetPath = 'assets/config/mqtt_config.json';
const String _defaultMqttHost = String.fromEnvironment(
  'MQTT_HOST',
  defaultValue: 'your-mqtt-host.example.com',
);
const int _defaultMqttPort = int.fromEnvironment(
  'MQTT_PORT',
  defaultValue: 1883,
);
const String _defaultMqttUser = String.fromEnvironment(
  'MQTT_USER',
  defaultValue: 'your-username',
);
const String _defaultMqttPass = String.fromEnvironment(
  'MQTT_PASS',
  defaultValue: 'your-password',
);
const String _defaultMqttTopicPrefix = String.fromEnvironment(
  'MQTT_TOPIC_PREFIX',
  defaultValue: 'urbanecho/places',
);

const Color _cream = Color(0xFFF5F0E8);
const Color _paper = Color(0xFFEDE8DC);
const Color _paperDark = Color(0xFFD9D2C0);
const Color _paperSurface = Colors.white;
const Color _paperSoft = Color(0xFFF0E4D0);
const Color _paperLine = Color(0xFFC8BFA8);
const Color _deepBrown = Color(0xFF4A3420);
const Color _brown = Color(0xFF7A5C3A);
const Color _ink = Color(0xFF2E2518);
const Color _mutedInk = Color(0xFF7B6755);
const Color _terracotta = Color(0xFFC4633A);
const Color _terracottaSoft = Color(0xFFF5DDD3);
const Color _teal = Color(0xFF4A8C80);
const Color _tealSoft = Color(0xFFD4EAE6);
const Color _amber = Color(0xFFB07A40);
const Color _amberSoft = Color(0xFFF0E4D0);

void main() {
  runApp(const UrbanEchoApp());
}

class UrbanEchoApp extends StatelessWidget {
  const UrbanEchoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UrbanEcho',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: _terracotta,
              brightness: Brightness.light,
            ).copyWith(
              primary: _terracotta,
              secondary: _teal,
              surface: _paperSurface,
              onSurface: _ink,
              outline: _paperLine,
            ),
        scaffoldBackgroundColor: _cream,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: _ink,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: _paper,
          indicatorColor: _terracottaSoft,
          surfaceTintColor: Colors.transparent,
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(color: _ink, fontWeight: FontWeight.w700),
          ),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: _paperSurface,
          surfaceTintColor: Colors.transparent,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: _cream,
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _paperSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: _paperLine),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: _paperLine),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: _terracotta, width: 1.4),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: _paperSurface,
          selectedColor: _terracottaSoft,
          side: const BorderSide(color: _paperLine),
          labelStyle: const TextStyle(color: _ink),
          secondaryLabelStyle: const TextStyle(color: _ink),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _terracotta,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _brown,
            side: const BorderSide(color: _paperLine),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: _ink,
          displayColor: _ink,
        ),
        useMaterial3: true,
      ),
      home: const AppShell(),
    );
  }
}

class SavedPlaceLog {
  const SavedPlaceLog({
    required this.point,
    required this.recordedAt,
    required this.name,
    required this.placeType,
    required this.comment,
    required this.rating,
    required this.noiseDb,
    required this.lightLux,
  });

  final LatLng point;
  final DateTime recordedAt;
  final String name;
  final String placeType;
  final String comment;
  final double? rating;
  final double? noiseDb;
  final int? lightLux;

  SavedPlaceLog copyWith({
    String? name,
    String? placeType,
    String? comment,
    double? rating,
    bool clearRating = false,
  }) {
    return SavedPlaceLog(
      point: point,
      recordedAt: recordedAt,
      name: name ?? this.name,
      placeType: placeType ?? this.placeType,
      comment: comment ?? this.comment,
      rating: clearRating ? null : rating ?? this.rating,
      noiseDb: this.noiseDb,
      lightLux: this.lightLux,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'latitude': point.latitude,
      'longitude': point.longitude,
      'recordedAt': recordedAt.toIso8601String(),
      'name': name,
      'placeType': placeType,
      'comment': comment,
      'rating': rating,
      'noiseDb': noiseDb,
      'lightLux': lightLux,
    };
  }

  factory SavedPlaceLog.fromJson(Map<String, Object?> json) {
    return SavedPlaceLog(
      point: LatLng(
        (json['latitude'] as num).toDouble(),
        (json['longitude'] as num).toDouble(),
      ),
      recordedAt:
          DateTime.tryParse(json['recordedAt'] as String? ?? '') ??
          DateTime.now(),
      name: json['name'] as String? ?? 'Saved place',
      placeType: json['placeType'] as String? ?? _placeTypes.first,
      comment: json['comment'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble(),
      noiseDb: (json['noiseDb'] as num?)?.toDouble(),
      lightLux: (json['lightLux'] as num?)?.toInt(),
    );
  }
}

class SharedPlaceLog {
  const SharedPlaceLog({
    required this.id,
    required this.source,
    required this.uploadedAt,
    required this.place,
  });

  final String id;
  final String source;
  final DateTime uploadedAt;
  final SavedPlaceLog place;

  Map<String, Object?> toJson() {
    final assessment = _assessEnvironment(place);

    return {
      'id': id,
      'source': source,
      'uploadedAt': uploadedAt.toIso8601String(),
      'bestUse': assessment.label,
      'score': assessment.score,
      ...place.toJson(),
    };
  }

  factory SharedPlaceLog.fromJson(Map<String, Object?> json) {
    return SharedPlaceLog(
      id: json['id'] as String? ?? _sharedPlaceIdFromJson(json),
      source: json['source'] as String? ?? 'anonymous',
      uploadedAt:
          DateTime.tryParse(json['uploadedAt'] as String? ?? '') ??
          DateTime.now(),
      place: SavedPlaceLog.fromJson(json),
    );
  }
}

class SharedPlaceGroup {
  const SharedPlaceGroup({required this.places});

  final List<SharedPlaceLog> places;

  SharedPlaceLog get latestPlace {
    return places.reduce((latest, next) {
      return next.uploadedAt.isAfter(latest.uploadedAt) ? next : latest;
    });
  }

  SavedPlaceLog get place => _mergeSharedPlaceValues();

  SharedPlaceLog get localCopy {
    final latest = latestPlace;
    return SharedPlaceLog(
      id: latest.id,
      source: latest.source,
      uploadedAt: latest.uploadedAt,
      place: _mergeSharedPlaceValues(),
    );
  }

  DateTime get uploadedAt => latestPlace.uploadedAt;

  double? get averageRating {
    final ratings = places
        .map((sharedPlace) => sharedPlace.place.rating)
        .whereType<double>()
        .toList();
    if (ratings.isEmpty) {
      return null;
    }

    return ratings.reduce((sum, value) => sum + value) / ratings.length;
  }

  int get ratingCount {
    return places
        .where((sharedPlace) => sharedPlace.place.rating != null)
        .length;
  }

  int get commentCount {
    return places.where((sharedPlace) {
      return sharedPlace.place.comment.trim().isNotEmpty;
    }).length;
  }

  SavedPlaceLog _mergeSharedPlaceValues() {
    final latest = latestPlace.place;
    double? noiseDb = latest.noiseDb;
    int? lightLux = latest.lightLux;

    for (final sharedPlace in places) {
      noiseDb ??= sharedPlace.place.noiseDb;
      lightLux ??= sharedPlace.place.lightLux;
      if (noiseDb != null && lightLux != null) {
        break;
      }
    }

    return SavedPlaceLog(
      point: latest.point,
      recordedAt: latest.recordedAt,
      name: latest.name,
      placeType: latest.placeType,
      comment: latest.comment,
      rating: latest.rating ?? averageRating,
      noiseDb: noiseDb,
      lightLux: lightLux,
    );
  }
}

class MqttSettings {
  const MqttSettings({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.topicPrefix,
  });

  final String host;
  final int port;
  final String username;
  final String password;
  final String topicPrefix;

  static const defaults = MqttSettings(
    host: _defaultMqttHost,
    port: _defaultMqttPort,
    username: _defaultMqttUser,
    password: _defaultMqttPass,
    topicPrefix: _defaultMqttTopicPrefix,
  );

  bool get isConfigured {
    return host != 'your-mqtt-host.example.com' &&
        username != 'your-username' &&
        password != 'your-password' &&
        host.trim().isNotEmpty &&
        username.trim().isNotEmpty &&
        password.trim().isNotEmpty;
  }

  factory MqttSettings.fromJson(Map<String, Object?> json) {
    return MqttSettings(
      host: json['host'] as String? ?? defaults.host,
      port: (json['port'] as num?)?.toInt() ?? defaults.port,
      username: json['username'] as String? ?? defaults.username,
      password: json['password'] as String? ?? defaults.password,
      topicPrefix: json['topicPrefix'] as String? ?? defaults.topicPrefix,
    );
  }
}

enum _PlacesViewMode { all, favorites }

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const String _savedPlacesFileName = 'urbanecho_saved_places.json';

  final GlobalKey<_MapScreenState> _mapScreenKey = GlobalKey<_MapScreenState>();

  int _currentIndex = 0;
  int _focusRequestId = 0;
  int _sharedFocusRequestId = 0;
  int _placesRequestId = 0;
  SavedPlaceLog? _placeToFocus;
  SavedPlaceLog? _sharedPlaceToFocus;
  _PlacesViewMode _placesMode = _PlacesViewMode.all;
  String _placesPlaceType = 'All';
  final List<SavedPlaceLog> _savedPlaces = [];
  final List<SharedPlaceLog> _sharedPlaces = [];

  @override
  void initState() {
    super.initState();
    _loadSavedPlaces();
  }

  void _savePlace(SavedPlaceLog place) {
    final existingIndex = _savedPlaces.indexWhere(
      (savedPlace) => _isSameSavedPlace(savedPlace, place),
    );

    setState(() {
      if (existingIndex != -1) {
        _savedPlaces.removeAt(existingIndex);
      }
      _savedPlaces.insert(0, place);
    });
    _persistSavedPlaces();
  }

  void _viewPlaceOnMap(SavedPlaceLog place) {
    setState(() {
      _focusRequestId += 1;
      _placeToFocus = place;
      _currentIndex = 1;
    });
  }

  void _viewSharedPlaceOnMap(SharedPlaceGroup group) {
    setState(() {
      _sharedFocusRequestId += 1;
      _sharedPlaceToFocus = group.place;
      _currentIndex = 1;
    });
  }

  void _openPlaces({
    _PlacesViewMode mode = _PlacesViewMode.all,
    String placeType = 'All',
  }) {
    setState(() {
      _placesRequestId += 1;
      _placesMode = mode;
      _placesPlaceType = placeType;
      _currentIndex = 2;
    });
  }

  void _handleSharedPlacesChanged(List<SharedPlaceLog> places) {
    setState(() {
      _sharedPlaces
        ..clear()
        ..addAll(places);
    });
  }

  Future<bool> _deleteSharedPlaceGroup(SharedPlaceGroup group) async {
    final deleted =
        await _mapScreenKey.currentState?._deleteSharedPlaceGroup(group) ??
        false;

    if (!deleted) {
      return false;
    }

    final deletedIds = group.places.map((place) => place.id).toSet();
    setState(() {
      _sharedPlaces.removeWhere((place) => deletedIds.contains(place.id));
    });
    return true;
  }

  void _deletePlace(SavedPlaceLog place) {
    setState(() {
      _savedPlaces.remove(place);
      if (_placeToFocus == place) {
        _placeToFocus = null;
      }
    });
    _persistSavedPlaces();
  }

  void _clearAllPlaces() {
    setState(() {
      _savedPlaces.clear();
      _placeToFocus = null;
    });
    _persistSavedPlaces();
  }

  void _updatePlace(SavedPlaceLog oldPlace, SavedPlaceLog updatedPlace) {
    final index = _savedPlaces.indexOf(oldPlace);
    if (index == -1) {
      return;
    }

    setState(() {
      _savedPlaces[index] = updatedPlace;
      if (_placeToFocus == oldPlace) {
        _placeToFocus = updatedPlace;
      }
    });
    _persistSavedPlaces();
  }

  Future<File> _savedPlacesFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_savedPlacesFileName');
  }

  Future<void> _loadSavedPlaces() async {
    try {
      final file = await _savedPlacesFile();
      if (!await file.exists()) {
        return;
      }

      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return;
      }

      final places = decoded
          .whereType<Map>()
          .map(
            (item) => SavedPlaceLog.fromJson(Map<String, Object?>.from(item)),
          )
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _savedPlaces
          ..clear()
          ..addAll(places);
      });
    } catch (_) {
      // Ignore corrupted local data so the prototype can still launch.
    }
  }

  Future<void> _persistSavedPlaces() async {
    try {
      final file = await _savedPlacesFile();
      final raw = jsonEncode(
        _savedPlaces.map((place) => place.toJson()).toList(),
      );
      await file.writeAsString(raw);
    } catch (_) {
      // Local persistence should not block the main app flow.
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        savedPlaces: _savedPlaces,
        onOpenMap: () {
          setState(() {
            _currentIndex = 1;
          });
        },
        onOpenFavorites: () {
          _openPlaces(mode: _PlacesViewMode.favorites);
        },
        onBrowseActivity: (placeType) {
          _openPlaces(mode: _PlacesViewMode.all, placeType: placeType);
        },
      ),
      MapScreen(
        key: _mapScreenKey,
        savedPlaces: _savedPlaces,
        onSavePlace: _savePlace,
        onUpdatePlace: _updatePlace,
        onDeletePlace: _deletePlace,
        onSharedPlacesChanged: _handleSharedPlacesChanged,
        onOpenPlaces: (placeType) {
          _openPlaces(mode: _PlacesViewMode.all, placeType: placeType);
        },
        focusPlace: _placeToFocus,
        focusRequestId: _focusRequestId,
        focusSharedPlace: _sharedPlaceToFocus,
        sharedFocusRequestId: _sharedFocusRequestId,
      ),
      PlacesScreen(
        favoritePlaces: _savedPlaces,
        sharedPlaceGroups: _groupSharedPlaces(_sharedPlaces),
        initialMode: _placesMode,
        initialPlaceType: _placesPlaceType,
        requestId: _placesRequestId,
        onViewFavoritePlace: _viewPlaceOnMap,
        onViewSharedPlace: _viewSharedPlaceOnMap,
        onSaveSharedPlace: (sharedPlace) => _savePlace(sharedPlace.place),
        onDeleteSharedGroup: _deleteSharedPlaceGroup,
        onUpdatePlace: _updatePlace,
        onDeletePlace: _deletePlace,
        onClearAllPlaces: _clearAllPlaces,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmarks_outlined),
            selectedIcon: Icon(Icons.bookmarks),
            label: 'Places',
          ),
        ],
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.savedPlaces,
    required this.onOpenMap,
    required this.onOpenFavorites,
    required this.onBrowseActivity,
  });

  final List<SavedPlaceLog> savedPlaces;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenFavorites;
  final ValueChanged<String> onBrowseActivity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final savedPlaceCount = savedPlaces.length;
    final weekStart = DateTime.now().subtract(const Duration(days: 7));
    final addedThisWeek = savedPlaces
        .where((place) => place.recordedAt.isAfter(weekStart))
        .length;
    final recentPlaces = savedPlaces.take(2).toList();

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: _paper,
              border: const Border(bottom: BorderSide(color: _paperLine)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _LogoMark(),
                      const SizedBox(width: 8),
                      Text(
                        'UrbanEcho',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your city, your notes.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _mutedInk,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel('Your places'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _HomeStatCard(
                        value: '$savedPlaceCount',
                        label: 'Saved places',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _HomeStatCard(
                        value: '$addedThisWeek',
                        label: 'Added this week',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _SectionLabel('Browse by activity'),
                const SizedBox(height: 10),
                _HomeAllPlacesCta(onTap: () => onBrowseActivity('All')),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _UseCaseChip(
                    icon: Icons.menu_book_outlined,
                    label: 'Study',
                    onTap: () => onBrowseActivity('Study'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _UseCaseChip(
                    icon: Icons.spa_outlined,
                    label: 'Rest',
                    onTap: () => onBrowseActivity('Rest'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _UseCaseChip(
                    icon: Icons.groups_outlined,
                    label: 'Social',
                    onTap: () => onBrowseActivity('Social'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _HomeMapCta(onOpenMap: onOpenMap),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                const Expanded(child: _SectionLabel('Recent')),
                TextButton(
                  onPressed: onOpenFavorites,
                  child: const Text('Saved'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: recentPlaces.isEmpty
                ? _RecentEmpty(onOpenMap: onOpenMap)
                : Column(
                    children: recentPlaces
                        .map((place) => _RecentPlaceItem(place: place))
                        .toList(),
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class PlacesScreen extends StatefulWidget {
  const PlacesScreen({
    super.key,
    required this.favoritePlaces,
    required this.sharedPlaceGroups,
    required this.initialMode,
    required this.initialPlaceType,
    required this.requestId,
    required this.onViewFavoritePlace,
    required this.onViewSharedPlace,
    required this.onSaveSharedPlace,
    required this.onDeleteSharedGroup,
    required this.onUpdatePlace,
    required this.onDeletePlace,
    required this.onClearAllPlaces,
  });

  final List<SavedPlaceLog> favoritePlaces;
  final List<SharedPlaceGroup> sharedPlaceGroups;
  final _PlacesViewMode initialMode;
  final String initialPlaceType;
  final int requestId;
  final ValueChanged<SavedPlaceLog> onViewFavoritePlace;
  final ValueChanged<SharedPlaceGroup> onViewSharedPlace;
  final ValueChanged<SharedPlaceLog> onSaveSharedPlace;
  final Future<bool> Function(SharedPlaceGroup group) onDeleteSharedGroup;
  final void Function(SavedPlaceLog oldPlace, SavedPlaceLog updatedPlace)
  onUpdatePlace;
  final ValueChanged<SavedPlaceLog> onDeletePlace;
  final VoidCallback onClearAllPlaces;

  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> {
  final TextEditingController _searchController = TextEditingController();

  late _PlacesViewMode _selectedMode;
  String _selectedPlaceType = 'All';
  String _searchQuery = '';
  String _selectedSort = 'Newest';

  @override
  void initState() {
    super.initState();
    _applyIncomingRequest();
  }

  @override
  void didUpdateWidget(covariant PlacesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.requestId == oldWidget.requestId) {
      return;
    }

    setState(_applyIncomingRequest);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyIncomingRequest() {
    _selectedMode = widget.initialMode;
    _selectedPlaceType = widget.initialPlaceType;
  }

  Future<void> _confirmClearAllFavorites() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all places?'),
        content: const Text(
          'This removes every local favorite from storage. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );

    if (shouldClear != true) {
      return;
    }

    widget.onClearAllPlaces();
  }

  Future<void> _confirmDeleteSharedPlaceGroup(SharedPlaceGroup group) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete shared place?'),
        content: Text(
          'This removes "${group.place.name}" from All places for everyone. '
          'For this prototype it works as a temporary moderation tool.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: _deepBrown),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    final deleted = await widget.onDeleteSharedGroup(group);
    if (!mounted || deleted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not delete this place.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showingAllPlaces = _selectedMode == _PlacesViewMode.all;
    final filteredFavorites = _sortPlaces(
      _searchPlaces(
        _filterPlacesByType(widget.favoritePlaces, _selectedPlaceType),
        _searchQuery,
      ),
      _selectedSort,
    );
    final filteredSharedGroups = _sortSharedPlaceGroups(
      _searchSharedPlaceGroups(
        _filterSharedPlaceGroupsByType(
          widget.sharedPlaceGroups,
          _selectedPlaceType,
        ),
        _searchQuery,
      ),
      _selectedSort,
    );
    final topRatedFavorites = _topRatedPlaces(widget.favoritePlaces);
    final topRatedSharedGroups = _topRatedSharedPlaceGroups(
      widget.sharedPlaceGroups,
    );
    final itemCount = showingAllPlaces
        ? widget.sharedPlaceGroups.length
        : widget.favoritePlaces.length;

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              color: _paper,
              border: Border(bottom: BorderSide(color: _paperLine)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Places',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        showingAllPlaces
                            ? '$itemCount all places'
                            : '$itemCount favorites',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: _mutedInk,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<_PlacesViewMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: _PlacesViewMode.all,
                        icon: Icon(Icons.public, size: 16),
                        label: Text('All places'),
                      ),
                      ButtonSegment(
                        value: _PlacesViewMode.favorites,
                        icon: Icon(Icons.bookmark_border, size: 16),
                        label: Text('Favorites'),
                      ),
                    ],
                    selected: {_selectedMode},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _selectedMode = selection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _HistorySearchAndSort(
                    controller: _searchController,
                    selectedSort: _selectedSort,
                    onSearchChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    onClearSearch: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                    onSortChanged: (value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        _selectedSort = value;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  _PlaceTypeFilter(
                    selectedPlaceType: _selectedPlaceType,
                    onSelected: (placeType) {
                      setState(() {
                        _selectedPlaceType = placeType;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          if (!showingAllPlaces)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: widget.favoritePlaces.isEmpty
                      ? null
                      : _confirmClearAllFavorites,
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Clear all'),
                ),
              ),
            ),
          if (showingAllPlaces && topRatedSharedGroups.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _TopRatedSharedStrip(
                groups: topRatedSharedGroups,
                onViewGroup: widget.onViewSharedPlace,
              ),
            ),
            const SizedBox(height: 4),
          ] else if (!showingAllPlaces && topRatedFavorites.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: _TopRatedStrip(
                places: topRatedFavorites,
                onViewPlace: widget.onViewFavoritePlace,
              ),
            ),
            const SizedBox(height: 4),
          ],
          if (showingAllPlaces)
            _AllPlacesList(
              groups: filteredSharedGroups,
              totalCount: widget.sharedPlaceGroups.length,
              selectedPlaceType: _selectedPlaceType,
              searchQuery: _searchQuery,
              favoritePlaces: widget.favoritePlaces,
              onViewGroup: widget.onViewSharedPlace,
              onSaveSharedPlace: widget.onSaveSharedPlace,
              onDeleteFavorite: widget.onDeletePlace,
              onDeleteSharedGroup: _confirmDeleteSharedPlaceGroup,
            )
          else if (widget.favoritePlaces.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _paperSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _paperLine),
                ),
                child: Text(
                  'No favorites yet. Open the map to save a place.',
                  style: theme.textTheme.bodyLarge?.copyWith(color: _mutedInk),
                ),
              ),
            )
          else if (filteredFavorites.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _paperSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _paperLine),
                ),
                child: Text(
                  _searchQuery.trim().isEmpty
                      ? 'No $_selectedPlaceType favorites saved yet.'
                      : 'No places match this search.',
                  style: theme.textTheme.bodyLarge?.copyWith(color: _mutedInk),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                children: filteredFavorites
                    .map(
                      (place) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _HistoryPlaceCard(
                          place: place,
                          onViewPlace: widget.onViewFavoritePlace,
                          onUpdatePlace: widget.onUpdatePlace,
                          onDeletePlace: widget.onDeletePlace,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _AllPlacesList extends StatelessWidget {
  const _AllPlacesList({
    required this.groups,
    required this.totalCount,
    required this.selectedPlaceType,
    required this.searchQuery,
    required this.favoritePlaces,
    required this.onViewGroup,
    required this.onSaveSharedPlace,
    required this.onDeleteFavorite,
    required this.onDeleteSharedGroup,
  });

  final List<SharedPlaceGroup> groups;
  final int totalCount;
  final String selectedPlaceType;
  final String searchQuery;
  final List<SavedPlaceLog> favoritePlaces;
  final ValueChanged<SharedPlaceGroup> onViewGroup;
  final ValueChanged<SharedPlaceLog> onSaveSharedPlace;
  final ValueChanged<SavedPlaceLog> onDeleteFavorite;
  final Future<void> Function(SharedPlaceGroup group) onDeleteSharedGroup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (totalCount == 0) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _paperSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _paperLine),
          ),
          child: Text(
            'No online places loaded yet. Check the map connection.',
            style: theme.textTheme.bodyLarge?.copyWith(color: _mutedInk),
          ),
        ),
      );
    }

    if (groups.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _paperSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _paperLine),
          ),
          child: Text(
            searchQuery.trim().isEmpty
                ? 'No $selectedPlaceType places found.'
                : 'No places match this search.',
            style: theme.textTheme.bodyLarge?.copyWith(color: _mutedInk),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        children: groups
            .map(
              (group) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SharedPlaceListCard(
                  group: group,
                  savedPlace: _matchingSavedPlace(favoritePlaces, group.place),
                  onViewGroup: onViewGroup,
                  onSaveSharedPlace: onSaveSharedPlace,
                  onDeleteFavorite: onDeleteFavorite,
                  onDeleteSharedGroup: onDeleteSharedGroup,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _HistorySearchAndSort extends StatelessWidget {
  const _HistorySearchAndSort({
    required this.controller,
    required this.selectedSort,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onSortChanged,
  });

  final TextEditingController controller;
  final String selectedSort;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<String?> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: controller.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: onClearSearch,
                          icon: const Icon(Icons.clear, size: 18),
                          tooltip: 'Clear search',
                        ),
                  hintText: 'Search places',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            DecoratedBox(
              decoration: BoxDecoration(
                color: _paperSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _paperLine),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedSort,
                    icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                    items: _historySortOptions
                        .map(
                          (option) => DropdownMenuItem(
                            value: option,
                            child: Text(
                              option,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: onSortChanged,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HistoryPlaceCard extends StatelessWidget {
  const _HistoryPlaceCard({
    required this.place,
    required this.onViewPlace,
    required this.onUpdatePlace,
    required this.onDeletePlace,
  });

  final SavedPlaceLog place;
  final ValueChanged<SavedPlaceLog> onViewPlace;
  final void Function(SavedPlaceLog oldPlace, SavedPlaceLog updatedPlace)
  onUpdatePlace;
  final ValueChanged<SavedPlaceLog> onDeletePlace;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SavedPlaceSummary(place: place),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => onDeletePlace(place),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
              ),
              TextButton.icon(
                onPressed: () => _editPlace(context),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => onViewPlace(place),
                icon: const Icon(Icons.map_outlined),
                label: const Text('View on map'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editPlace(BuildContext context) async {
    final updatedPlace = await _showSavePlaceSheet(
      context,
      point: place.point,
      existingPlace: place,
    );

    if (updatedPlace == null) {
      return;
    }

    onUpdatePlace(place, updatedPlace);
  }
}

class _SharedPlaceListCard extends StatelessWidget {
  const _SharedPlaceListCard({
    required this.group,
    required this.savedPlace,
    required this.onViewGroup,
    required this.onSaveSharedPlace,
    required this.onDeleteFavorite,
    required this.onDeleteSharedGroup,
  });

  final SharedPlaceGroup group;
  final SavedPlaceLog? savedPlace;
  final ValueChanged<SharedPlaceGroup> onViewGroup;
  final ValueChanged<SharedPlaceLog> onSaveSharedPlace;
  final ValueChanged<SavedPlaceLog> onDeleteFavorite;
  final Future<void> Function(SharedPlaceGroup group) onDeleteSharedGroup;

  @override
  Widget build(BuildContext context) {
    final isSaved = savedPlace != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onViewGroup(group),
          child: _SavedPlaceSummary(
            place: group.place,
            averageRating: group.averageRating,
            ratingCount: group.ratingCount,
            trailing: Wrap(
              spacing: 2,
              children: [
                IconButton(
                  tooltip: isSaved ? 'Remove favorite' : 'Save favorite',
                  style: IconButton.styleFrom(
                    backgroundColor: isSaved ? _deepBrown : _paper,
                    foregroundColor: isSaved ? _cream : _brown,
                  ),
                  onPressed: () {
                    final saved = savedPlace;
                    if (saved != null) {
                      onDeleteFavorite(saved);
                      return;
                    }
                    onSaveSharedPlace(group.localCopy);
                  },
                  icon: Icon(
                    isSaved ? Icons.bookmark : Icons.bookmark_add_outlined,
                  ),
                ),
                IconButton(
                  tooltip: 'Delete from All places',
                  style: IconButton.styleFrom(
                    backgroundColor: _paper,
                    foregroundColor: _deepBrown,
                  ),
                  onPressed: () {
                    onDeleteSharedGroup(group);
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => onViewGroup(group),
            icon: const Icon(Icons.map_outlined),
            label: const Text('View on map'),
          ),
        ),
      ],
    );
  }
}

class _TopRatedStrip extends StatelessWidget {
  const _TopRatedStrip({required this.places, required this.onViewPlace});

  final List<SavedPlaceLog> places;
  final ValueChanged<SavedPlaceLog> onViewPlace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _paperLine),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top rated',
              style: theme.textTheme.labelSmall?.copyWith(
                color: _mutedInk,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            ...places.map(
              (place) => InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onViewPlace(place),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _placeTypeColor(place.placeType),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          place.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '★ ${(place.rating ?? 0).toStringAsFixed(1)}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: _terracotta,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopRatedSharedStrip extends StatelessWidget {
  const _TopRatedSharedStrip({required this.groups, required this.onViewGroup});

  final List<SharedPlaceGroup> groups;
  final ValueChanged<SharedPlaceGroup> onViewGroup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _paperLine),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top rated',
              style: theme.textTheme.labelSmall?.copyWith(
                color: _mutedInk,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            ...groups.map(
              (group) => InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onViewGroup(group),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _placeTypeColor(group.place.placeType),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          group.place.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '★ ${(group.averageRating ?? 0).toStringAsFixed(1)}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: _terracotta,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.savedPlaces,
    required this.onSavePlace,
    required this.onUpdatePlace,
    required this.onDeletePlace,
    required this.onSharedPlacesChanged,
    required this.onOpenPlaces,
    required this.focusPlace,
    required this.focusRequestId,
    required this.focusSharedPlace,
    required this.sharedFocusRequestId,
  });

  final List<SavedPlaceLog> savedPlaces;
  final ValueChanged<SavedPlaceLog> onSavePlace;
  final void Function(SavedPlaceLog oldPlace, SavedPlaceLog updatedPlace)
  onUpdatePlace;
  final ValueChanged<SavedPlaceLog> onDeletePlace;
  final ValueChanged<List<SharedPlaceLog>> onSharedPlacesChanged;
  final ValueChanged<String> onOpenPlaces;
  final SavedPlaceLog? focusPlace;
  final int focusRequestId;
  final SavedPlaceLog? focusSharedPlace;
  final int sharedFocusRequestId;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const LatLng _ucl = LatLng(51.5246, -0.1340);
  static const double _nearbyPlaceThresholdMeters = 25;

  final GlobalKey _mapAreaKey = GlobalKey();
  final MapController _mapController = MapController();
  final Light _light = Light();
  final NoiseMeter _noiseMeter = NoiseMeter();
  final Distance _distance = const Distance();
  final String _mqttClientId =
      'urbanecho_${DateTime.now().millisecondsSinceEpoch}';

  LatLng? _currentLocation;
  StreamSubscription<int>? _lightSubscription;
  StreamSubscription<NoiseReading>? _noiseSubscription;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage?>>?>?
  _mqttSubscription;
  Timer? _mqttRefreshTimer;
  MqttServerClient? _mqttClient;
  MqttSettings _mqttSettings = MqttSettings.defaults;
  final List<SharedPlaceLog> _sharedPlaces = [];
  double? _currentNoiseDb;
  int? _currentLightLux;
  int _noiseSampleCount = 0;
  int _lightSampleCount = 0;
  double _noiseSampleTotal = 0;
  int _lightSampleTotal = 0;
  double? _minNoiseDb;
  double? _maxNoiseDb;
  int? _minLightLux;
  int? _maxLightLux;
  bool _isLoading = true;
  bool _isSensorScanning = false;
  bool _isMqttConnecting = false;
  bool _isMqttConnected = false;
  bool _isSavingDraftPlace = false;
  bool _showSharedPlaces = true;
  bool _showMapFilters = false;
  LatLng? _draftPlacePoint;
  String _selectedMapPlaceType = 'All';
  String _statusMessage = 'Requesting location...';
  String _sensorMessage = 'Sensors are off.';

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
    _loadMqttSettings();
  }

  @override
  void dispose() {
    _lightSubscription?.cancel();
    _noiseSubscription?.cancel();
    _mqttSubscription?.cancel();
    _mqttRefreshTimer?.cancel();
    _mqttClient?.disconnect();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final focusPlace = widget.focusPlace;
    if (focusPlace == null ||
        widget.focusRequestId == oldWidget.focusRequestId) {
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _focusPlace(focusPlace);
      });
    }

    final focusSharedPlace = widget.focusSharedPlace;
    if (focusSharedPlace != null &&
        widget.sharedFocusRequestId != oldWidget.sharedFocusRequestId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _focusSharedPlace(focusSharedPlace);
      });
    }
  }

  void _focusPlace(SavedPlaceLog place) {
    _mapController.move(place.point, 17);
    setState(() {
      _statusMessage = 'Viewing ${place.name}.';
    });
  }

  void _focusSharedPlace(SavedPlaceLog place) {
    _mapController.move(place.point, 17);
    setState(() {
      _showSharedPlaces = true;
      _selectedMapPlaceType = place.placeType;
      _statusMessage = 'Viewing ${place.name}.';
    });
  }

  Future<void> _loadMqttSettings() async {
    if (mounted) {
      setState(() {
        _isMqttConnecting = true;
      });
    }

    try {
      final raw = await rootBundle.loadString(_mqttConfigAssetPath);
      final decoded = jsonDecode(raw);
      if (decoded is Map && mounted) {
        final settings = MqttSettings.fromJson(
          Map<String, Object?>.from(decoded),
        );
        setState(() {
          _mqttSettings = settings;
        });
      }
    } catch (_) {
      // The ignored local config is optional. Fall back to --dart-define values.
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isMqttConnecting = false;
    });
    if (_mqttSettings.isConfigured) {
      _startMqttRefreshTimer();
    }
    await _connectSharedMap();
  }

  Future<void> _loadCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Checking location permission...';
    });

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _statusMessage = 'Location services are turned off.';
      });
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _statusMessage = 'Location permission was denied.';
      });
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _statusMessage = 'Permission denied forever. Enable it in Settings.';
      });
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final point = LatLng(position.latitude, position.longitude);
      if (!mounted) {
        return;
      }

      setState(() {
        _currentLocation = point;
        _isLoading = false;
        _statusMessage = 'Current location loaded.';
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.move(point, 16.8);
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _statusMessage = 'Unable to read current location.';
      });
    }
  }

  void _startDraftPlace() {
    final startPoint =
        _draftPlacePoint ?? _currentLocation ?? _mapController.camera.center;
    final zoom = _mapController.camera.zoom < 16
        ? 16.0
        : _mapController.camera.zoom;

    setState(() {
      _draftPlacePoint = startPoint;
      _statusMessage = 'Move the map to place the marker, then save here.';
    });
    _mapController.move(startPoint, zoom);
  }

  void _cancelDraftPlace() {
    setState(() {
      _draftPlacePoint = null;
      _statusMessage = 'Place creation cancelled.';
    });
  }

  void _syncDraftPlaceToMapCenter() {
    final draftPoint = _draftPlacePoint;
    if (draftPoint == null) {
      return;
    }

    final centerPoint = _mapController.camera.center;
    if (_distance(draftPoint, centerPoint) < 0.5) {
      return;
    }

    setState(() {
      _draftPlacePoint = centerPoint;
      _statusMessage = 'Marker is centered. Save here when ready.';
    });
  }

  Future<void> _saveDraftPlace() async {
    if (_isSavingDraftPlace) {
      return;
    }

    final point = _mapController.camera.center;
    setState(() {
      _isSavingDraftPlace = true;
    });

    bool? uploaded;
    try {
      uploaded = await _createPlaceAtPoint(point);
    } catch (_) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Upload failed. Check network connection.';
        });
      }
    }
    if (!mounted) {
      return;
    }

    setState(() {
      _isSavingDraftPlace = false;
      if (uploaded == true) {
        _draftPlacePoint = null;
      }
    });
  }

  Future<bool?> _createPlaceAtPoint(LatLng point) async {
    if (_averageCurrentNoiseDb == null || _averageCurrentLightLux == null) {
      return false;
    }

    final nearbyPlace = _nearestSharedPlaceWithin(
      point,
      _nearbyPlaceThresholdMeters,
    );
    if (nearbyPlace != null) {
      final shouldSaveNewPlace = await _confirmNearbyPlaceSave(
        nearbyPlace.group,
        nearbyPlace.distanceMeters,
      );
      if (!shouldSaveNewPlace) {
        return null;
      }
    }

    final place = await _showSavePlaceSheet(
      context,
      point: point,
      noiseDb: _averageCurrentNoiseDb,
      lightLux: _averageCurrentLightLux,
      sensorSummary: _sensorSampleSummary,
    );

    if (place == null) {
      return null;
    }

    if (mounted) {
      setState(() {
        _statusMessage = 'Uploading ${place.name}...';
      });
    }

    final uploaded = await _publishSharedPlace(place);
    if (!mounted) {
      return uploaded;
    }

    setState(() {
      _statusMessage = uploaded
          ? '${place.name} uploaded.'
          : 'Upload failed. Check network connection.';
    });
    return uploaded;
  }

  Future<bool> _waitForMqttConnection({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      if (_isMqttConnected && _mqttClient != null) {
        return true;
      }
      if (!_isMqttConnecting) {
        return false;
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }

    return _isMqttConnected && _mqttClient != null;
  }

  ({SharedPlaceGroup group, double distanceMeters})? _nearestSharedPlaceWithin(
    LatLng point,
    double thresholdMeters,
  ) {
    ({SharedPlaceGroup group, double distanceMeters})? nearestPlace;

    for (final group in _sharedPlaceGroups) {
      final distanceMeters = _distance(point, group.place.point);
      if (distanceMeters > thresholdMeters) {
        continue;
      }
      if (nearestPlace == null ||
          distanceMeters < nearestPlace.distanceMeters) {
        nearestPlace = (group: group, distanceMeters: distanceMeters);
      }
    }

    return nearestPlace;
  }

  Future<bool> _confirmNearbyPlaceSave(
    SharedPlaceGroup nearbyPlace,
    double distanceMeters,
  ) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nearby place already saved'),
        content: Text(
          '${nearbyPlace.place.name} is about ${distanceMeters.round()} m away. '
          'You can view it instead of creating a duplicate record.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: const Text('Cancel'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop('view'),
            icon: const Icon(Icons.map_outlined),
            label: const Text('View existing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('save'),
            child: const Text('Save new'),
          ),
        ],
      ),
    );

    if (action == 'view') {
      _mapController.move(nearbyPlace.place.point, 17);
      await _showSharedPlaceDetails(nearbyPlace);
      return false;
    }

    return action == 'save';
  }

  Future<void> _showPlaceDetails(SavedPlaceLog place) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _SavedPlaceDetailsDialog(
        place: place,
        currentLocation: _currentLocation,
        onUpdatePlace: widget.onUpdatePlace,
        onDeletePlace: widget.onDeletePlace,
      ),
    );
  }

  Future<void> _showSharedPlaceDetails(SharedPlaceGroup group) async {
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final savedPlace = _matchingSavedPlace(
            widget.savedPlaces,
            group.place,
          );
          final isSaved = savedPlace != null;

          return AlertDialog(
            title: const Text('Place details'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SavedPlaceSummary(
                    place: group.place,
                    currentLocation: _currentLocation,
                    averageRating: group.averageRating,
                    ratingCount: group.ratingCount,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${group.ratingCount} rating(s) • ${group.commentCount} public comment(s)',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: _mutedInk),
                  ),
                  const SizedBox(height: 10),
                  ...group.places
                      .where((sharedPlace) {
                        return sharedPlace.place.comment.trim().isNotEmpty ||
                            sharedPlace.place.rating != null;
                      })
                      .map(
                        (sharedPlace) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _SharedCommentCard(sharedPlace: sharedPlace),
                        ),
                      ),
                ],
              ),
            ),
            actions: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: isSaved ? _deepBrown : _terracotta,
                  foregroundColor: _cream,
                ),
                onPressed: () {
                  if (savedPlace != null) {
                    widget.onDeletePlace(savedPlace);
                    setDialogState(() {});
                    return;
                  }
                  _saveSharedPlaceLocally(group.localCopy);
                  setDialogState(() {});
                },
                icon: Icon(
                  isSaved ? Icons.bookmark : Icons.bookmark_add_outlined,
                ),
                label: Text(isSaved ? 'Saved' : 'Save'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  List<SharedPlaceGroup> get _sharedPlaceGroups {
    return _groupSharedPlaces(_sharedPlaces);
  }

  void _saveSharedPlaceLocally(SharedPlaceLog sharedPlace) {
    final place = sharedPlace.place;
    final alreadySaved = widget.savedPlaces.any(
      (savedPlace) => _isSameSavedPlace(savedPlace, place),
    );
    if (alreadySaved) {
      setState(() {
        _statusMessage = '${place.name} is already in Favorites.';
      });
      return;
    }

    widget.onSavePlace(place);

    if (!mounted) {
      return;
    }

    setState(() {
      _statusMessage = '${sharedPlace.place.name} saved locally.';
    });
  }

  Future<void> _connectSharedMap() async {
    if (_isMqttConnecting || _isMqttConnected) {
      return;
    }

    if (!_mqttSettings.isConfigured) {
      setState(() {
        _isMqttConnected = false;
        _isMqttConnecting = false;
      });
      return;
    }

    setState(() {
      _isMqttConnecting = true;
    });

    final client = MqttServerClient.withPort(
      _mqttSettings.host,
      _mqttClientId,
      _mqttSettings.port,
    );
    client.logging(on: false);
    client.keepAlivePeriod = 30;
    client.autoReconnect = true;
    client.onDisconnected = () {
      if (!mounted) {
        return;
      }
      setState(() {
        _isMqttConnected = false;
        _isMqttConnecting = false;
      });
    };
    client.onConnected = () {
      if (!mounted) {
        return;
      }
      setState(() {
        _isMqttConnected = true;
        _isMqttConnecting = false;
      });
    };
    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(_mqttClientId)
        .authenticateAs(_mqttSettings.username, _mqttSettings.password)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    try {
      await client.connect();
      if (client.connectionStatus?.state != MqttConnectionState.connected) {
        client.disconnect();
        throw StateError('MQTT connection failed');
      }

      await _mqttSubscription?.cancel();
      _mqttSubscription = client.updates?.listen(_handleSharedPlaceMessages);
      _subscribeToSharedPlaces(client);
      _startMqttRefreshTimer();

      if (!mounted) {
        return;
      }
      setState(() {
        _mqttClient = client;
        _isMqttConnected = true;
        _isMqttConnecting = false;
      });
    } catch (_) {
      client.disconnect();
      if (!mounted) {
        return;
      }
      setState(() {
        _mqttClient = null;
        _isMqttConnected = false;
        _isMqttConnecting = false;
      });
    }
  }

  String get _sharedPlacesTopic => '${_mqttSettings.topicPrefix}/#';

  void _subscribeToSharedPlaces(
    MqttServerClient client, {
    bool refresh = false,
  }) {
    if (refresh) {
      client.unsubscribe(_sharedPlacesTopic);
    }
    client.subscribe(_sharedPlacesTopic, MqttQos.atLeastOnce);
  }

  void _startMqttRefreshTimer() {
    _mqttRefreshTimer?.cancel();
    _mqttRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _refreshSharedPlacesFromMqtt();
    });
  }

  Future<void> _refreshSharedPlacesFromMqtt() async {
    if (!_mqttSettings.isConfigured) {
      return;
    }

    final client = _mqttClient;
    if (_isMqttConnected && client != null) {
      _subscribeToSharedPlaces(client, refresh: true);
      return;
    }

    if (!_isMqttConnecting) {
      await _connectSharedMap();
    }
  }

  void _handleSharedPlaceMessages(
    List<MqttReceivedMessage<MqttMessage?>>? messages,
  ) {
    if (messages == null || messages.isEmpty) {
      return;
    }

    for (final message in messages) {
      final payload = message.payload;
      if (payload is! MqttPublishMessage) {
        continue;
      }

      try {
        final raw = MqttPublishPayload.bytesToStringAsString(
          payload.payload.message,
        );
        if (raw.trim().isEmpty) {
          final deletedId = _sharedPlaceIdFromTopic(
            message.topic,
            _mqttSettings.topicPrefix,
          );
          if (deletedId != null) {
            _removeSharedPlacesByIds({deletedId});
          }
          continue;
        }

        final decoded = jsonDecode(raw);
        if (decoded is! Map) {
          continue;
        }

        final sharedPlace = SharedPlaceLog.fromJson(
          Map<String, Object?>.from(decoded),
        );
        _upsertSharedPlace(sharedPlace);
      } catch (_) {
        // Ignore malformed shared messages from other clients.
      }
    }
  }

  void _upsertSharedPlace(SharedPlaceLog sharedPlace) {
    if (!mounted) {
      return;
    }

    setState(() {
      final index = _sharedPlaces.indexWhere((place) {
        return place.id == sharedPlace.id;
      });
      if (index == -1) {
        _sharedPlaces.insert(0, sharedPlace);
      } else {
        _sharedPlaces[index] = sharedPlace;
      }
    });
    _notifySharedPlacesChanged();
  }

  void _removeSharedPlacesByIds(Set<String> ids) {
    if (!mounted || ids.isEmpty) {
      return;
    }

    setState(() {
      _sharedPlaces.removeWhere((place) => ids.contains(place.id));
    });
    _notifySharedPlacesChanged();
  }

  void _notifySharedPlacesChanged() {
    widget.onSharedPlacesChanged(
      List<SharedPlaceLog>.unmodifiable(_sharedPlaces),
    );
  }

  Future<bool> _publishSharedPlace(SavedPlaceLog place) async {
    if (_isMqttConnecting) {
      await _waitForMqttConnection();
    }

    if (!_isMqttConnected || _mqttClient == null) {
      await _connectSharedMap();
      if (_isMqttConnecting) {
        await _waitForMqttConnection();
      }
    }

    final client = _mqttClient;
    if (!_isMqttConnected || client == null) {
      return false;
    }

    final sharedPlace = SharedPlaceLog(
      id: _sharedPlaceId(place),
      source: 'anonymous-urbanecho',
      uploadedAt: DateTime.now(),
      place: place,
    );
    final builder = MqttClientPayloadBuilder()
      ..addString(jsonEncode(sharedPlace.toJson()));

    client.publishMessage(
      '${_mqttSettings.topicPrefix}/${sharedPlace.id}',
      MqttQos.atLeastOnce,
      builder.payload!,
      retain: true,
    );
    _upsertSharedPlace(sharedPlace);

    if (!mounted) {
      return true;
    }
    setState(() {
      _statusMessage = '${place.name} uploaded.';
    });

    return true;
  }

  Future<bool> _deleteSharedPlaceGroup(SharedPlaceGroup group) async {
    if (!_isMqttConnected || _mqttClient == null) {
      await _connectSharedMap();
    }

    final client = _mqttClient;
    if (!_isMqttConnected || client == null) {
      return false;
    }

    final emptyPayload = MqttClientPayloadBuilder().payload!;
    final ids = group.places.map((place) => place.id).toSet();
    for (final id in ids) {
      client.publishMessage(
        '${_mqttSettings.topicPrefix}/$id',
        MqttQos.atLeastOnce,
        emptyPayload,
        retain: true,
      );
    }

    _removeSharedPlacesByIds(ids);
    return true;
  }

  Future<void> _toggleSensors() async {
    if (_isSensorScanning) {
      await _stopSensors();
      return;
    }

    await _startSensors();
  }

  double? get _averageCurrentNoiseDb {
    if (_noiseSampleCount == 0) {
      return _currentNoiseDb;
    }

    return _noiseSampleTotal / _noiseSampleCount;
  }

  int? get _averageCurrentLightLux {
    if (_lightSampleCount == 0) {
      return _currentLightLux;
    }

    return (_lightSampleTotal / _lightSampleCount).round();
  }

  String get _sensorSampleSummary {
    if (_noiseSampleCount == 0 && _lightSampleCount == 0) {
      return 'No sensor samples collected yet.';
    }

    final parts = <String>[];
    if (_noiseSampleCount > 0) {
      parts.add(
        'Noise avg ${_formatNoiseValue(_averageCurrentNoiseDb)} '
        '(${_formatNoiseValue(_minNoiseDb)}-${_formatNoiseValue(_maxNoiseDb)}, $_noiseSampleCount samples)',
      );
    }
    if (_lightSampleCount > 0) {
      parts.add(
        'Light avg ${_formatLightValue(_averageCurrentLightLux)} '
        '(${_formatLightValue(_minLightLux)}-${_formatLightValue(_maxLightLux)}, $_lightSampleCount samples)',
      );
    }

    return parts.join('\n');
  }

  void _resetSensorSamples() {
    _noiseSampleCount = 0;
    _lightSampleCount = 0;
    _noiseSampleTotal = 0;
    _lightSampleTotal = 0;
    _minNoiseDb = null;
    _maxNoiseDb = null;
    _minLightLux = null;
    _maxLightLux = null;
  }

  Future<void> _startSensors() async {
    setState(() {
      _sensorMessage = 'Starting sensors...';
      _resetSensorSamples();
    });

    final microphoneStatus = await Permission.microphone.request();
    if (!microphoneStatus.isGranted) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSensorScanning = false;
        _sensorMessage = 'Microphone permission denied.';
      });
      return;
    }

    await _light.requestAuthorization();
    await _noiseSubscription?.cancel();
    await _lightSubscription?.cancel();

    _noiseSubscription = _noiseMeter.noise.listen(
      (reading) {
        if (!mounted) {
          return;
        }
        setState(() {
          final noise = reading.meanDecibel;
          _currentNoiseDb = noise;
          _noiseSampleCount += 1;
          _noiseSampleTotal += noise;
          _minNoiseDb = _minNoiseDb == null
              ? noise
              : (_minNoiseDb! < noise ? _minNoiseDb : noise);
          _maxNoiseDb = _maxNoiseDb == null
              ? noise
              : (_maxNoiseDb! > noise ? _maxNoiseDb : noise);
          _sensorMessage = 'Sensors running. Averaging recent samples.';
        });
      },
      onError: (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _sensorMessage = 'Noise sensor unavailable.';
        });
      },
    );

    _lightSubscription = _light.lightSensorStream.listen(
      (lux) {
        if (!mounted) {
          return;
        }
        setState(() {
          if (lux < 0) {
            _currentLightLux = null;
            return;
          }
          _currentLightLux = lux;
          _lightSampleCount += 1;
          _lightSampleTotal += lux;
          _minLightLux = _minLightLux == null
              ? lux
              : (_minLightLux! < lux ? _minLightLux : lux);
          _maxLightLux = _maxLightLux == null
              ? lux
              : (_maxLightLux! > lux ? _maxLightLux : lux);
        });
      },
      onError: (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _sensorMessage = 'Light sensor unavailable.';
        });
      },
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSensorScanning = true;
      _sensorMessage = 'Sensors running.';
    });
  }

  Future<void> _stopSensors() async {
    await _noiseSubscription?.cancel();
    await _lightSubscription?.cancel();

    _noiseSubscription = null;
    _lightSubscription = null;

    if (!mounted) {
      return;
    }

    setState(() {
      _isSensorScanning = false;
      _sensorMessage = 'Sensors paused.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final location = _currentLocation;
    final visibleSavedPlaces = _filterPlacesByType(
      widget.savedPlaces,
      _selectedMapPlaceType,
    );
    final visibleSharedPlaces = _showSharedPlaces
        ? _filterSharedPlaceGroupsByType(
            _sharedPlaceGroups,
            _selectedMapPlaceType,
          )
        : <SharedPlaceGroup>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Urban Map'),
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: ClipRRect(
          key: _mapAreaKey,
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _ucl,
                  initialZoom: 15.2,
                  onPositionChanged: (_, _) => _syncDraftPlaceToMapCenter(),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.urbanecho',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _ucl,
                        width: 52,
                        height: 52,
                        alignment: Alignment.bottomCenter,
                        rotate: true,
                        child: const _MapMarker(
                          color: _mutedInk,
                          icon: Icons.school,
                        ),
                      ),
                      ...visibleSavedPlaces.map(
                        (place) => Marker(
                          point: place.point,
                          width: 52,
                          height: 52,
                          alignment: Alignment.bottomCenter,
                          rotate: true,
                          child: GestureDetector(
                            onTap: () => _showPlaceDetails(place),
                            child: _MapMarker(
                              color: _placeTypeColor(place.placeType),
                              icon: Icons.bookmark,
                            ),
                          ),
                        ),
                      ),
                      ...visibleSharedPlaces.map(
                        (sharedGroup) => Marker(
                          point: sharedGroup.place.point,
                          width: 52,
                          height: 52,
                          alignment: Alignment.bottomCenter,
                          rotate: true,
                          child: GestureDetector(
                            onTap: () => _showSharedPlaceDetails(sharedGroup),
                            child: _MapMarker(
                              color: _placeTypeColor(
                                sharedGroup.place.placeType,
                              ).withValues(alpha: 0.72),
                              icon: Icons.public,
                            ),
                          ),
                        ),
                      ),
                      if (location != null)
                        Marker(
                          point: location,
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          rotate: true,
                          child: const _CurrentLocationMarker(),
                        ),
                    ],
                  ),
                ],
              ),
              if (_draftPlacePoint != null)
                const IgnorePointer(child: Center(child: _CenterDraftMarker())),
              if (_draftPlacePoint != null)
                const Positioned(
                  left: 12,
                  top: 12,
                  child: _PlacementHintPill(),
                ),
              Positioned(
                right: 12,
                top: 12,
                child: _MqttStatusPill(
                  isConnected: _isMqttConnected,
                  isConnecting: _isMqttConnecting,
                  onRetry: _isMqttConnected || _isMqttConnecting
                      ? null
                      : _connectSharedMap,
                ),
              ),
              DraggableScrollableSheet(
                initialChildSize: 0.24,
                minChildSize: 0.14,
                maxChildSize: 0.74,
                builder: (context, scrollController) => _MapControlSheet(
                  scrollController: scrollController,
                  location: location,
                  draftPlacePoint: _draftPlacePoint,
                  isLoading: _isLoading,
                  isSavingDraftPlace: _isSavingDraftPlace,
                  isSensorScanning: _isSensorScanning,
                  showSharedPlaces: _showSharedPlaces,
                  showFilters: _showMapFilters,
                  statusMessage: _statusMessage,
                  sensorMessage: _sensorMessage,
                  currentNoiseDb: _currentNoiseDb,
                  currentLightLux: _currentLightLux,
                  averageNoiseDb: _averageCurrentNoiseDb,
                  averageLightLux: _averageCurrentLightLux,
                  sensorSampleSummary: _sensorSampleSummary,
                  selectedPlaceType: _selectedMapPlaceType,
                  visibleSavedCount: visibleSavedPlaces.length,
                  savedCount: widget.savedPlaces.length,
                  sharedCount: _sharedPlaces.length,
                  onLocate: _isLoading ? null : _loadCurrentLocation,
                  onStartDraftPlace: _startDraftPlace,
                  onSaveDraftPlace: _draftPlacePoint == null
                      ? null
                      : _saveDraftPlace,
                  onCancelDraftPlace: _cancelDraftPlace,
                  onToggleSensors: _toggleSensors,
                  onShowPlaces: () =>
                      widget.onOpenPlaces(_selectedMapPlaceType),
                  onToggleFilters: () {
                    setState(() {
                      _showMapFilters = !_showMapFilters;
                    });
                  },
                  onToggleSharedPlaces: (value) {
                    setState(() {
                      _showSharedPlaces = value;
                    });
                  },
                  onSelectPlaceType: (placeType) {
                    setState(() {
                      _selectedMapPlaceType = placeType;
                    });
                  },
                ),
              ),
              if (_isLoading) const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }
}

class _MqttStatusPill extends StatelessWidget {
  const _MqttStatusPill({
    required this.isConnected,
    required this.isConnecting,
    required this.onRetry,
  });

  final bool isConnected;
  final bool isConnecting;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isConnected
        ? _teal
        : isConnecting
        ? _terracotta
        : _brown;
    final label = isConnected
        ? '🟢 Online'
        : isConnecting
        ? '🟡 Connecting'
        : '🔴 Failed';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _paperSurface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26A86D38),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: _ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(width: 8),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlacementHintPill extends StatelessWidget {
  const _PlacementHintPill();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _paperSurface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _terracotta.withValues(alpha: 0.5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26A86D38),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          '📍 Move map to place marker',
          style: theme.textTheme.labelMedium?.copyWith(
            color: _ink,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MapControlSheet extends StatelessWidget {
  const _MapControlSheet({
    required this.scrollController,
    required this.location,
    required this.draftPlacePoint,
    required this.isLoading,
    required this.isSavingDraftPlace,
    required this.isSensorScanning,
    required this.showSharedPlaces,
    required this.showFilters,
    required this.statusMessage,
    required this.sensorMessage,
    required this.currentNoiseDb,
    required this.currentLightLux,
    required this.averageNoiseDb,
    required this.averageLightLux,
    required this.sensorSampleSummary,
    required this.selectedPlaceType,
    required this.visibleSavedCount,
    required this.savedCount,
    required this.sharedCount,
    required this.onLocate,
    required this.onStartDraftPlace,
    required this.onSaveDraftPlace,
    required this.onCancelDraftPlace,
    required this.onToggleSensors,
    required this.onShowPlaces,
    required this.onToggleFilters,
    required this.onToggleSharedPlaces,
    required this.onSelectPlaceType,
  });

  final ScrollController scrollController;
  final LatLng? location;
  final LatLng? draftPlacePoint;
  final bool isLoading;
  final bool isSavingDraftPlace;
  final bool isSensorScanning;
  final bool showSharedPlaces;
  final bool showFilters;
  final String statusMessage;
  final String sensorMessage;
  final double? currentNoiseDb;
  final int? currentLightLux;
  final double? averageNoiseDb;
  final int? averageLightLux;
  final String sensorSampleSummary;
  final String selectedPlaceType;
  final int visibleSavedCount;
  final int savedCount;
  final int sharedCount;
  final VoidCallback? onLocate;
  final VoidCallback onStartDraftPlace;
  final VoidCallback? onSaveDraftPlace;
  final VoidCallback onCancelDraftPlace;
  final VoidCallback onToggleSensors;
  final VoidCallback onShowPlaces;
  final VoidCallback onToggleFilters;
  final ValueChanged<bool> onToggleSharedPlaces;
  final ValueChanged<String> onSelectPlaceType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPlacingDraft = draftPlacePoint != null;
    final hasRequiredSensorData =
        (averageNoiseDb ?? currentNoiseDb) != null &&
        (averageLightLux ?? currentLightLux) != null;
    final needsSensorData = isPlacingDraft && !hasRequiredSensorData;
    final activePoint = draftPlacePoint ?? location;
    final assessment = _assessEnvironmentValues(
      noiseDb: averageNoiseDb,
      lightLux: averageLightLux,
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _cream,
        border: Border(top: BorderSide(color: _paperLine)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Color(0x24A86D38),
            blurRadius: 18,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        children: [
          const _SheetHandle(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: isSavingDraftPlace
                      ? null
                      : needsSensorData
                      ? isSensorScanning
                            ? null
                            : onToggleSensors
                      : isPlacingDraft
                      ? onSaveDraftPlace
                      : onStartDraftPlace,
                  icon: Icon(
                    isSavingDraftPlace
                        ? Icons.hourglass_top
                        : needsSensorData
                        ? isSensorScanning
                              ? Icons.hourglass_top
                              : Icons.sensors
                        : isPlacingDraft
                        ? Icons.check
                        : Icons.add_location_alt,
                  ),
                  label: Text(
                    isSavingDraftPlace
                        ? 'Saving'
                        : needsSensorData
                        ? isSensorScanning
                              ? 'Waiting for sensors'
                              : 'Start sensors first'
                        : isPlacingDraft
                        ? 'Save here'
                        : 'Create',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: isPlacingDraft ? onCancelDraftPlace : onLocate,
                icon: Icon(isPlacingDraft ? Icons.close : Icons.my_location),
                label: Text(
                  isPlacingDraft
                      ? 'Cancel'
                      : isLoading
                      ? 'Locating'
                      : 'Locate',
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: _paper,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MapActionTile(
                  icon: Icons.bookmarks_outlined,
                  label: 'Places',
                  value: '${sharedCount + savedCount}',
                  onTap: onShowPlaces,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _MapActionTile(
                  icon: isSensorScanning ? Icons.sensors_off : Icons.sensors,
                  label: isSensorScanning ? 'Stop' : 'Sensors',
                  value: isSensorScanning ? 'On' : 'Off',
                  onTap: onToggleSensors,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _MapActionTile(
                  icon: Icons.tune,
                  label: 'Filter',
                  value: selectedPlaceType,
                  active: showFilters,
                  onTap: onToggleFilters,
                ),
              ),
            ],
          ),
          if (showFilters) ...[
            const SizedBox(height: 12),
            _PlaceTypeFilter(
              selectedPlaceType: selectedPlaceType,
              onSelected: onSelectPlaceType,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    selectedPlaceType == 'All'
                        ? '$savedCount favorites shown'
                        : '$visibleSavedCount/$savedCount $selectedPlaceType favorites shown',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _mutedInk,
                    ),
                  ),
                ),
                FilterChip(
                  label: Text('Show all places ($sharedCount)'),
                  selected: showSharedPlaces,
                  onSelected: onToggleSharedPlaces,
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          _SensorSummaryBar(
            currentNoiseDb: currentNoiseDb,
            currentLightLux: currentLightLux,
            averageNoiseDb: averageNoiseDb,
            averageLightLux: averageLightLux,
            assessment: assessment,
          ),
          const SizedBox(height: 8),
          Text(
            sensorMessage,
            style: theme.textTheme.labelSmall?.copyWith(color: _mutedInk),
          ),
          if (activePoint != null) ...[
            const SizedBox(height: 4),
            Text(
              '${isPlacingDraft ? 'Draft' : 'Current'} position · '
              '${activePoint.latitude.toStringAsFixed(5)}, '
              '${activePoint.longitude.toStringAsFixed(5)}',
              style: theme.textTheme.labelSmall?.copyWith(color: _mutedInk),
            ),
          ],
          if (isPlacingDraft || statusMessage.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              isPlacingDraft
                  ? 'Move the map until the pin is on the right spot.'
                  : statusMessage,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isPlacingDraft ? _terracotta : _mutedInk,
              ),
            ),
          ],
          if (sensorSampleSummary.isNotEmpty && showFilters) ...[
            const SizedBox(height: 6),
            Text(
              sensorSampleSummary,
              style: theme.textTheme.labelSmall?.copyWith(color: _mutedInk),
            ),
          ],
        ],
      ),
    );
  }
}

class _MapActionTile extends StatelessWidget {
  const _MapActionTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? _terracotta : _mutedInk;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: active ? _terracottaSoft : _paper,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? _terracotta : _paperLine),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 9, 4, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _mutedInk,
                  fontSize: 10,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: active ? _terracotta : _ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SensorSummaryBar extends StatelessWidget {
  const _SensorSummaryBar({
    required this.currentNoiseDb,
    required this.currentLightLux,
    required this.averageNoiseDb,
    required this.averageLightLux,
    required this.assessment,
  });

  final double? currentNoiseDb;
  final int? currentLightLux;
  final double? averageNoiseDb;
  final int? averageLightLux;
  final _EnvironmentAssessment assessment;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _paperLine),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          children: [
            _SensorSummaryItem(
              label: 'Noise',
              value: _noiseLevelFromDb(averageNoiseDb ?? currentNoiseDb),
              detail: _formatNoiseValue(averageNoiseDb ?? currentNoiseDb),
            ),
            const SizedBox(height: 8),
            _SensorSummaryItem(
              label: 'Light',
              value: _lightLevelFromLux(averageLightLux ?? currentLightLux),
              detail: _formatLightValue(averageLightLux ?? currentLightLux),
            ),
            const SizedBox(height: 8),
            _SensorSummaryItem(
              label: 'Best use',
              value: assessment.label.replaceFirst('Best for ', ''),
              detail: '${assessment.score}/100',
            ),
          ],
        ),
      ),
    );
  }
}

class _SensorSummaryItem extends StatelessWidget {
  const _SensorSummaryItem({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: _mutedInk),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: _ink,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          detail,
          style: theme.textTheme.labelMedium?.copyWith(
            color: _mutedInk,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _CenterDraftMarker extends StatelessWidget {
  const _CenterDraftMarker();

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -44),
      child: const SizedBox(
        width: 88,
        height: 88,
        child: _MapMarker(color: _terracotta, icon: Icons.add),
      ),
    );
  }
}

Future<SavedPlaceLog?> _showSavePlaceSheet(
  BuildContext context, {
  required LatLng point,
  double? noiseDb,
  int? lightLux,
  String? sensorSummary,
  SavedPlaceLog? existingPlace,
}) {
  return showModalBottomSheet<SavedPlaceLog>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _SavePlaceSheet(
      point: point,
      noiseDb: noiseDb,
      lightLux: lightLux,
      sensorSummary: sensorSummary,
      existingPlace: existingPlace,
    ),
  );
}

class _SavePlaceSheet extends StatefulWidget {
  const _SavePlaceSheet({
    required this.point,
    this.noiseDb,
    this.lightLux,
    this.sensorSummary,
    this.existingPlace,
  });

  final LatLng point;
  final double? noiseDb;
  final int? lightLux;
  final String? sensorSummary;
  final SavedPlaceLog? existingPlace;

  @override
  State<_SavePlaceSheet> createState() => _SavePlaceSheetState();
}

class _SavePlaceSheetState extends State<_SavePlaceSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  String _placeType = _placeTypes.first;
  double _rating = 0;

  @override
  void initState() {
    super.initState();

    final existingPlace = widget.existingPlace;
    if (existingPlace == null) {
      return;
    }

    _nameController.text = existingPlace.name;
    _commentController.text = existingPlace.comment;
    _placeType = existingPlace.placeType;
    _rating = existingPlace.rating ?? 0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final comment = _commentController.text.trim();

    if (name.isEmpty) {
      return;
    }

    Navigator.of(context).pop(
      widget.existingPlace?.copyWith(
            name: name,
            placeType: _placeType,
            comment: comment,
            rating: _rating == 0 ? null : _rating,
            clearRating: _rating == 0,
          ) ??
          SavedPlaceLog(
            point: widget.point,
            recordedAt: DateTime.now(),
            name: name,
            placeType: _placeType,
            comment: comment,
            rating: _rating == 0 ? null : _rating,
            noiseDb: widget.noiseDb,
            lightLux: widget.lightLux,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final noiseDb = widget.existingPlace?.noiseDb ?? widget.noiseDb;
    final lightLux = widget.existingPlace?.lightLux ?? widget.lightLux;
    final assessment = _assessEnvironmentValues(
      noiseDb: noiseDb,
      lightLux: lightLux,
    );

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: _cream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            border: Border(top: BorderSide(color: _paperLine)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SheetHandle(),
                const SizedBox(height: 12),
                Text(
                  widget.existingPlace == null
                      ? 'Record this place'
                      : 'Edit place note',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                const _FieldLabel('Place name'),
                TextField(
                  controller: _nameController,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Library corner',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 12),
                const _FieldLabel('Activity type'),
                _PlaceTypeSelector(
                  selectedPlaceType: _placeType,
                  onSelected: (type) {
                    setState(() {
                      _placeType = type;
                    });
                  },
                ),
                const SizedBox(height: 12),
                const _FieldLabel('Comment'),
                TextField(
                  controller: _commentController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'How does this place feel?',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _StarRatingInput(
                  rating: _rating,
                  onChanged: (value) {
                    setState(() {
                      _rating = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                _CreateContextStrip(
                  point: widget.point,
                  noiseDb: noiseDb,
                  lightLux: lightLux,
                  assessment: assessment,
                ),
                if (widget.sensorSummary != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.sensorSummary!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _mutedInk,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _submit,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          widget.existingPlace == null ? 'Save' : 'Update',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: _paperLine,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: _mutedInk,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.72,
        ),
      ),
    );
  }
}

class _PlaceTypeSelector extends StatelessWidget {
  const _PlaceTypeSelector({
    required this.selectedPlaceType,
    required this.onSelected,
  });

  final String selectedPlaceType;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _placeTypes.map((type) {
        final selected = selectedPlaceType == type;
        final color = _placeTypeColor(type);

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: type == _placeTypes.last ? 0 : 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onSelected(type),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: selected ? color.withValues(alpha: 0.18) : _paper,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? color : _paperLine,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Text(
                    type,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: selected ? color : _mutedInk,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CreateContextStrip extends StatelessWidget {
  const _CreateContextStrip({
    required this.point,
    required this.noiseDb,
    required this.lightLux,
    required this.assessment,
  });

  final LatLng point;
  final double? noiseDb;
  final int? lightLux;
  final _EnvironmentAssessment assessment;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _paperLine),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: _ContextItem(
                label: 'Position',
                value:
                    '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}',
              ),
            ),
            Expanded(
              child: _ContextItem(
                label: 'Sensors',
                value:
                    '${_noiseLevelFromDb(noiseDb)} · ${_lightLevelFromLux(lightLux)}',
              ),
            ),
            Expanded(
              child: _ContextItem(label: 'Fit', value: assessment.label),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContextItem extends StatelessWidget {
  const _ContextItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: _mutedInk),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: _brown,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StarRatingInput extends StatelessWidget {
  const _StarRatingInput({required this.rating, required this.onChanged});

  final double rating;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Rating',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: _mutedInk,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.72,
                ),
              ),
            ),
            TextButton(
              onPressed: rating == 0 ? null : () => onChanged(0),
              child: Text(rating == 0 ? 'No rating' : 'Clear'),
            ),
          ],
        ),
        Row(
          children: [
            ...List.generate(5, (index) {
              final starValue = index + 1;
              final icon = rating >= starValue
                  ? Icons.star
                  : rating >= starValue - 0.5
                  ? Icons.star_half
                  : Icons.star_border;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  final localX = details.localPosition.dx;
                  final half = localX < 16 ? 0.5 : 1.0;
                  onChanged(index + half);
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(icon, size: 30, color: _terracotta),
                ),
              );
            }),
            const SizedBox(width: 8),
            Text(
              rating == 0 ? 'Tap stars' : '★ ${rating.toStringAsFixed(1)}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: rating == 0 ? _mutedInk : _terracotta,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StarRatingDisplay extends StatelessWidget {
  const _StarRatingDisplay({required this.rating, this.ratingCount});

  final double? rating;
  final int? ratingCount;

  @override
  Widget build(BuildContext context) {
    final value = rating;
    if (value == null || value <= 0) {
      return Text(
        '☆ No rating',
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: _mutedInk),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (index) {
          final starNumber = index + 1;
          final icon = value >= starNumber
              ? Icons.star
              : value >= starNumber - 0.5
              ? Icons.star_half
              : Icons.star_border;

          return Icon(icon, size: 16, color: _terracotta);
        }),
        const SizedBox(width: 6),
        Text(
          ratingCount == null
              ? '★ ${value.toStringAsFixed(1)}'
              : '★ ${value.toStringAsFixed(1)} (${ratingCount!})',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: _terracotta),
        ),
      ],
    );
  }
}

class _SharedCommentCard extends StatelessWidget {
  const _SharedCommentCard({required this.sharedPlace});

  final SharedPlaceLog sharedPlace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final comment = sharedPlace.place.comment.trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _paperSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _paperLine),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _StarRatingDisplay(rating: sharedPlace.place.rating),
                ),
                Text(
                  _formatTime(sharedPlace.uploadedAt),
                  style: theme.textTheme.labelSmall?.copyWith(color: _mutedInk),
                ),
              ],
            ),
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                comment,
                style: theme.textTheme.bodySmall?.copyWith(color: _mutedInk),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SavedPlaceDetailsDialog extends StatelessWidget {
  const _SavedPlaceDetailsDialog({
    required this.place,
    required this.currentLocation,
    required this.onUpdatePlace,
    required this.onDeletePlace,
  });

  final SavedPlaceLog place;
  final LatLng? currentLocation;
  final void Function(SavedPlaceLog oldPlace, SavedPlaceLog updatedPlace)
  onUpdatePlace;
  final ValueChanged<SavedPlaceLog> onDeletePlace;

  Future<void> _editPlace(BuildContext context) async {
    final updatedPlace = await _showSavePlaceSheet(
      context,
      point: place.point,
      existingPlace: place,
    );

    if (updatedPlace == null) {
      return;
    }

    onUpdatePlace(place, updatedPlace);
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  void _deletePlace(BuildContext context) {
    onDeletePlace(place);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Place details'),
      content: SingleChildScrollView(
        child: _SavedPlaceSummary(
          place: place,
          currentLocation: currentLocation,
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => _deletePlace(context),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Delete'),
        ),
        TextButton.icon(
          onPressed: () => _editPlace(context),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _SavedPlaceSummary extends StatelessWidget {
  const _SavedPlaceSummary({
    required this.place,
    this.currentLocation,
    this.averageRating,
    this.ratingCount,
    this.trailing,
  });

  final SavedPlaceLog place;
  final LatLng? currentLocation;
  final double? averageRating;
  final int? ratingCount;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final comment = place.comment.isEmpty ? 'No comment added.' : place.comment;
    final distanceLabel = currentLocation == null
        ? null
        : _formatDistanceMeters(
            const Distance()(currentLocation!, place.point),
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _paperSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _paperLine),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    place.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _ActivityTypeChip(placeType: place.placeType),
                if (trailing != null) ...[const SizedBox(width: 4), trailing!],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              comment,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _mutedInk,
                fontStyle: FontStyle.italic,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              [
                _formatTime(place.recordedAt),
                if (distanceLabel != null) distanceLabel,
                '${place.point.latitude.toStringAsFixed(4)}, ${place.point.longitude.toStringAsFixed(4)}',
              ].join('  •  '),
              style: theme.textTheme.labelSmall?.copyWith(color: _mutedInk),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _StarRatingDisplay(
                  rating: averageRating ?? place.rating,
                  ratingCount: ratingCount,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${_noiseLevelFromDb(place.noiseDb)} ${_formatNoiseValue(place.noiseDb)} · '
                    '${_lightLevelFromLux(place.lightLux)} ${_formatLightValue(place.lightLux)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _mutedInk,
                    ),
                  ),
                ),
                _SuitabilityDots(placeType: place.placeType),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityTypeChip extends StatelessWidget {
  const _ActivityTypeChip({required this.placeType});

  final String placeType;

  @override
  Widget build(BuildContext context) {
    final color = _placeTypeColor(placeType);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: Text(
          placeType,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SuitabilityDots extends StatelessWidget {
  const _SuitabilityDots({required this.placeType});

  final String placeType;

  @override
  Widget build(BuildContext context) {
    const dotTypes = ['Study', 'Rest', 'Social'];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        final type = dotTypes[index];
        final active = placeType == type;
        final color = _placeTypeColor(type);
        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color.withValues(alpha: active ? 1 : 0.24),
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }
}

class _PlaceTypeFilter extends StatelessWidget {
  const _PlaceTypeFilter({
    required this.selectedPlaceType,
    required this.onSelected,
  });

  final String selectedPlaceType;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final options = ['All', ..._placeTypes];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((placeType) {
        return ChoiceChip(
          label: Text(placeType),
          selected: selectedPlaceType == placeType,
          onSelected: (_) => onSelected(placeType),
        );
      }).toList(),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _terracotta,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const SizedBox(
        width: 28,
        height: 28,
        child: Icon(Icons.place_outlined, color: Colors.white, size: 17),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: _mutedInk,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _HomeStatCard extends StatelessWidget {
  const _HomeStatCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _paperLine),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: _deepBrown,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(color: _mutedInk),
            ),
          ],
        ),
      ),
    );
  }
}

class _UseCaseChip extends StatelessWidget {
  const _UseCaseChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = switch (label) {
      'Study' => (background: _tealSoft, foreground: const Color(0xFF2A5C54)),
      'Rest' => (background: _amberSoft, foreground: const Color(0xFF6B4A20)),
      _ => (background: _terracottaSoft, foreground: const Color(0xFF7A3018)),
    };

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _placeTypeColor(label),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 5),
              Icon(icon, color: colors.foreground, size: 17),
              const SizedBox(height: 3),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeAllPlacesCta extends StatelessWidget {
  const _HomeAllPlacesCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _paper,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _paperLine),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _deepBrown,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.public, color: _cream, size: 17),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'All places',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Browse every shared city note',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: _mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward, color: _brown, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeMapCta extends StatelessWidget {
  const _HomeMapCta({required this.onOpenMap});

  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onOpenMap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _deepBrown,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Open map',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: _cream,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Explore & record places around you',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFFB0A090),
                      ),
                    ),
                  ],
                ),
              ),
              const CircleAvatar(
                radius: 14,
                backgroundColor: Color(0x22FFFFFF),
                child: Icon(Icons.arrow_forward, color: Colors.white, size: 17),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentEmpty extends StatelessWidget {
  const _RecentEmpty({required this.onOpenMap});

  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onOpenMap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: _terracotta,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No recent places yet. Open the map to record one.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: _mutedInk),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentPlaceItem extends StatelessWidget {
  const _RecentPlaceItem({required this.place});

  final SavedPlaceLog place;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rating = place.rating;

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _paperDark)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _placeTypeColor(place.placeType),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${place.placeType} · ${_formatTime(place.recordedAt)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _mutedInk,
                    ),
                  ),
                ],
              ),
            ),
            if (rating != null)
              Text(
                '★ ${rating.toStringAsFixed(1)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: _terracotta,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        width: 52,
        height: 52,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Icon(
              Icons.location_on,
              color: color,
              size: 52,
              shadows: const [
                Shadow(
                  color: Color(0x33000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            Positioned(
              top: 11,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: _paperSurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.18)),
                ),
                child: Icon(icon, color: color, size: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentLocationMarker extends StatelessWidget {
  const _CurrentLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: _teal,
          shape: BoxShape.circle,
          border: Border.all(color: _paperSurface, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(Icons.my_location, size: 12, color: _paperSurface),
      ),
    );
  }
}

class _EnvironmentAssessment {
  const _EnvironmentAssessment({
    required this.label,
    required this.reason,
    required this.score,
    required this.icon,
    required this.color,
  });

  final String label;
  final String reason;
  final int score;
  final IconData icon;
  final Color color;
}

String _formatTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  final second = value.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}

String _sharedPlaceId(SavedPlaceLog place) {
  final rawId = [
    place.name,
    place.point.latitude.toStringAsFixed(5),
    place.point.longitude.toStringAsFixed(5),
    place.recordedAt.millisecondsSinceEpoch,
  ].join('_');

  return rawId
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}

String _sharedPlaceIdFromJson(Map<String, Object?> json) {
  return [
    json['name'] ?? 'shared-place',
    json['latitude'] ?? 'unknown-lat',
    json['longitude'] ?? 'unknown-lng',
    json['recordedAt'] ?? DateTime.now().toIso8601String(),
  ].join('_').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
}

String? _sharedPlaceIdFromTopic(String topic, String topicPrefix) {
  final normalizedPrefix = topicPrefix.endsWith('/')
      ? topicPrefix.substring(0, topicPrefix.length - 1)
      : topicPrefix;
  final prefixWithSlash = '$normalizedPrefix/';
  if (!topic.startsWith(prefixWithSlash)) {
    return null;
  }

  final id = topic.substring(prefixWithSlash.length).trim();
  return id.isEmpty ? null : id;
}

List<SavedPlaceLog> _filterPlacesByType(
  List<SavedPlaceLog> places,
  String placeType,
) {
  if (placeType == 'All') {
    return places;
  }

  return places.where((place) => place.placeType == placeType).toList();
}

List<SharedPlaceGroup> _filterSharedPlaceGroupsByType(
  List<SharedPlaceGroup> groups,
  String placeType,
) {
  if (placeType == 'All') {
    return groups;
  }

  return groups.where((group) => group.place.placeType == placeType).toList();
}

List<SharedPlaceGroup> _groupSharedPlaces(List<SharedPlaceLog> places) {
  final groupedPlaces = <String, List<SharedPlaceLog>>{};
  for (final place in places) {
    final key = _sharedPlaceGroupKey(place.place);
    groupedPlaces.putIfAbsent(key, () => []).add(place);
  }

  return groupedPlaces.values
      .map((places) => SharedPlaceGroup(places: places))
      .toList();
}

String _sharedPlaceGroupKey(SavedPlaceLog place) {
  return [
    _normalizedPlaceName(place.name),
    place.point.latitude.toStringAsFixed(4),
    place.point.longitude.toStringAsFixed(4),
  ].join('|');
}

bool _isSameSavedPlace(SavedPlaceLog first, SavedPlaceLog second) {
  return _sharedPlaceGroupKey(first) == _sharedPlaceGroupKey(second);
}

SavedPlaceLog? _matchingSavedPlace(
  List<SavedPlaceLog> savedPlaces,
  SavedPlaceLog place,
) {
  for (final savedPlace in savedPlaces) {
    if (_isSameSavedPlace(savedPlace, place)) {
      return savedPlace;
    }
  }
  return null;
}

String _normalizedPlaceName(String name) {
  return name
      .toLowerCase()
      .replaceFirst(RegExp(r'\s*\(shared\)\s*$'), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

List<SavedPlaceLog> _searchPlaces(List<SavedPlaceLog> places, String query) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) {
    return places;
  }

  return places.where((place) {
    final searchableText = [
      place.name,
      place.comment,
      place.placeType,
      _formatRatingValue(place.rating),
      _formatNoiseValue(place.noiseDb),
      _formatLightValue(place.lightLux),
    ].join(' ').toLowerCase();

    return searchableText.contains(normalizedQuery);
  }).toList();
}

List<SavedPlaceLog> _sortPlaces(List<SavedPlaceLog> places, String sortMode) {
  final sortedPlaces = List<SavedPlaceLog>.of(places);

  switch (sortMode) {
    case 'Oldest':
      sortedPlaces.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    case 'Best study fit':
      sortedPlaces.sort((a, b) => _studyScore(b).compareTo(_studyScore(a)));
    case 'Best rest fit':
      sortedPlaces.sort((a, b) => _restScore(b).compareTo(_restScore(a)));
    case 'Best social fit':
      sortedPlaces.sort((a, b) => _socialScore(b).compareTo(_socialScore(a)));
    case 'Best rated':
      sortedPlaces.sort((a, b) => (b.rating ?? -1).compareTo(a.rating ?? -1));
    case 'Quietest':
      sortedPlaces.sort(
        (a, b) => (a.noiseDb ?? double.infinity).compareTo(
          b.noiseDb ?? double.infinity,
        ),
      );
    case 'Noisiest':
      sortedPlaces.sort((a, b) => (b.noiseDb ?? -1).compareTo(a.noiseDb ?? -1));
    case 'Brightest':
      sortedPlaces.sort(
        (a, b) => (b.lightLux ?? -1).compareTo(a.lightLux ?? -1),
      );
    case 'Dimmest':
      sortedPlaces.sort(
        (a, b) => (a.lightLux ?? 1 << 30).compareTo(b.lightLux ?? 1 << 30),
      );
    case 'Newest':
    default:
      sortedPlaces.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }

  return sortedPlaces;
}

List<SavedPlaceLog> _topRatedPlaces(List<SavedPlaceLog> places) {
  final ratedPlaces = places
      .where((place) => place.rating != null && place.rating! > 0)
      .toList();
  ratedPlaces.sort((a, b) {
    final ratingCompare = b.rating!.compareTo(a.rating!);
    if (ratingCompare != 0) {
      return ratingCompare;
    }
    return b.recordedAt.compareTo(a.recordedAt);
  });
  return ratedPlaces.take(3).toList();
}

List<SharedPlaceGroup> _topRatedSharedPlaceGroups(
  List<SharedPlaceGroup> groups,
) {
  final ratedGroups = groups
      .where((group) => group.averageRating != null && group.averageRating! > 0)
      .toList();
  ratedGroups.sort((a, b) {
    final ratingCompare = b.averageRating!.compareTo(a.averageRating!);
    if (ratingCompare != 0) {
      return ratingCompare;
    }
    return b.uploadedAt.compareTo(a.uploadedAt);
  });
  return ratedGroups.take(3).toList();
}

List<SharedPlaceGroup> _searchSharedPlaceGroups(
  List<SharedPlaceGroup> groups,
  String query,
) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) {
    return groups;
  }

  return groups.where((group) {
    final place = group.place;
    final comments = group.places
        .map((sharedPlace) => sharedPlace.place.comment)
        .join(' ');
    final searchableText = [
      place.name,
      place.comment,
      comments,
      place.placeType,
      _formatRatingValue(group.averageRating),
      _formatNoiseValue(place.noiseDb),
      _formatLightValue(place.lightLux),
    ].join(' ').toLowerCase();

    return searchableText.contains(normalizedQuery);
  }).toList();
}

List<SharedPlaceGroup> _sortSharedPlaceGroups(
  List<SharedPlaceGroup> groups,
  String sortMode,
) {
  final sortedGroups = List<SharedPlaceGroup>.of(groups);

  switch (sortMode) {
    case 'Oldest':
      sortedGroups.sort((a, b) => a.uploadedAt.compareTo(b.uploadedAt));
    case 'Best study fit':
      sortedGroups.sort(
        (a, b) => _studyScore(b.place).compareTo(_studyScore(a.place)),
      );
    case 'Best rest fit':
      sortedGroups.sort(
        (a, b) => _restScore(b.place).compareTo(_restScore(a.place)),
      );
    case 'Best social fit':
      sortedGroups.sort(
        (a, b) => _socialScore(b.place).compareTo(_socialScore(a.place)),
      );
    case 'Best rated':
      sortedGroups.sort(
        (a, b) => (b.averageRating ?? -1).compareTo(a.averageRating ?? -1),
      );
    case 'Quietest':
      sortedGroups.sort(
        (a, b) => (a.place.noiseDb ?? double.infinity).compareTo(
          b.place.noiseDb ?? double.infinity,
        ),
      );
    case 'Noisiest':
      sortedGroups.sort(
        (a, b) => (b.place.noiseDb ?? -1).compareTo(a.place.noiseDb ?? -1),
      );
    case 'Brightest':
      sortedGroups.sort(
        (a, b) => (b.place.lightLux ?? -1).compareTo(a.place.lightLux ?? -1),
      );
    case 'Dimmest':
      sortedGroups.sort(
        (a, b) => (a.place.lightLux ?? 1 << 30).compareTo(
          b.place.lightLux ?? 1 << 30,
        ),
      );
    case 'Newest':
    default:
      sortedGroups.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
  }

  return sortedGroups;
}

String _formatNoiseValue(double? value) {
  return value == null ? 'Unknown' : '${value.toStringAsFixed(1)} dB';
}

String _formatLightValue(int? value) {
  return value == null ? 'Unknown' : '$value lux';
}

String _formatRatingValue(double? value) {
  return value == null ? 'No rating' : '${value.toStringAsFixed(1)} stars';
}

String _formatDistanceMeters(double value) {
  if (value < 1000) {
    return '${value.round()} m away';
  }

  return '${(value / 1000).toStringAsFixed(1)} km away';
}

String _noiseLevelFromDb(double? value) {
  if (value == null) {
    return 'Noise unknown';
  }
  if (value < 55) {
    return 'Quiet';
  }
  if (value < 72) {
    return 'Moderate';
  }
  return 'Loud';
}

String _lightLevelFromLux(int? value) {
  if (value == null) {
    return 'Light unknown';
  }
  if (value < 80) {
    return 'Dim';
  }
  if (value < 500) {
    return 'Balanced';
  }
  return 'Bright';
}

_EnvironmentAssessment _assessEnvironment(SavedPlaceLog place) {
  return _assessEnvironmentValues(
    noiseDb: place.noiseDb,
    lightLux: place.lightLux,
  );
}

_EnvironmentAssessment _assessEnvironmentValues({
  required double? noiseDb,
  required int? lightLux,
}) {
  if (noiseDb == null && lightLux == null) {
    return const _EnvironmentAssessment(
      label: 'Needs sensor data',
      reason: 'Start sensors to calculate the current environment fit score.',
      score: 0,
      icon: Icons.sensors,
      color: _mutedInk,
    );
  }

  final scores = <String, int>{
    'Study': _studyScoreFromValues(noiseDb: noiseDb, lightLux: lightLux),
    'Rest': _restScoreFromValues(noiseDb: noiseDb, lightLux: lightLux),
    'Social': _socialScoreFromValues(noiseDb: noiseDb, lightLux: lightLux),
  };
  final bestUse = scores.entries.reduce(
    (best, next) => next.value > best.value ? next : best,
  );

  return switch (bestUse.key) {
    'Study' => _EnvironmentAssessment(
      label: 'Best for study',
      reason:
          'Quietness and usable light make this place stronger for focused work.',
      score: bestUse.value,
      icon: Icons.menu_book_outlined,
      color: _teal,
    ),
    'Rest' => _EnvironmentAssessment(
      label: 'Best for rest',
      reason:
          'Lower stimulation makes this place better for breaks or reading.',
      score: bestUse.value,
      icon: Icons.self_improvement_outlined,
      color: _amber,
    ),
    _ => _EnvironmentAssessment(
      label: 'Best for social',
      reason:
          'Higher activity and enough light make this place better for meeting others.',
      score: bestUse.value,
      icon: Icons.groups_2_outlined,
      color: _terracotta,
    ),
  };
}

int _studyScore(SavedPlaceLog place) {
  return _studyScoreFromValues(
    noiseDb: place.noiseDb,
    lightLux: place.lightLux,
  );
}

int _studyScoreFromValues({required double? noiseDb, required int? lightLux}) {
  final noiseScore = switch (noiseDb) {
    null => 35,
    < 45 => 100,
    < 55 => 90,
    < 65 => 65,
    < 75 => 35,
    _ => 10,
  };
  final lightScore = switch (lightLux) {
    null => 35,
    < 80 => 35,
    < 200 => 70,
    < 700 => 100,
    < 1100 => 75,
    _ => 45,
  };

  return _weightedScore(noiseScore, lightScore);
}

int _restScore(SavedPlaceLog place) {
  return _restScoreFromValues(noiseDb: place.noiseDb, lightLux: place.lightLux);
}

int _restScoreFromValues({required double? noiseDb, required int? lightLux}) {
  final noiseScore = switch (noiseDb) {
    null => 35,
    < 45 => 100,
    < 55 => 85,
    < 65 => 55,
    < 75 => 25,
    _ => 10,
  };
  final lightScore = switch (lightLux) {
    null => 35,
    < 40 => 95,
    < 180 => 100,
    < 450 => 70,
    < 800 => 40,
    _ => 20,
  };

  return _weightedScore(noiseScore, lightScore);
}

int _socialScore(SavedPlaceLog place) {
  return _socialScoreFromValues(
    noiseDb: place.noiseDb,
    lightLux: place.lightLux,
  );
}

int _socialScoreFromValues({required double? noiseDb, required int? lightLux}) {
  final noiseScore = switch (noiseDb) {
    null => 35,
    < 45 => 40,
    < 60 => 65,
    < 78 => 100,
    < 90 => 75,
    _ => 45,
  };
  final lightScore = switch (lightLux) {
    null => 35,
    < 80 => 45,
    < 250 => 75,
    < 900 => 95,
    _ => 70,
  };

  return _weightedScore(noiseScore, lightScore);
}

int _weightedScore(int noiseScore, int lightScore) {
  return ((noiseScore * 0.65) + (lightScore * 0.35)).round();
}

Color _placeTypeColor(String placeType) {
  return switch (placeType) {
    'Study' => _teal,
    'Rest' => _amber,
    'Social' => _terracotta,
    _ => _mutedInk,
  };
}
