import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:light/light.dart';
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
  'Quietest',
  'Noisiest',
  'Brightest',
  'Dimmest',
];

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1D6F5F),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF111417),
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
    required this.noiseDb,
    required this.lightLux,
  });

  final LatLng point;
  final DateTime recordedAt;
  final String name;
  final String placeType;
  final String comment;
  final double? noiseDb;
  final int? lightLux;

  SavedPlaceLog copyWith({String? name, String? placeType, String? comment}) {
    return SavedPlaceLog(
      point: point,
      recordedAt: recordedAt,
      name: name ?? this.name,
      placeType: placeType ?? this.placeType,
      comment: comment ?? this.comment,
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
      noiseDb: (json['noiseDb'] as num?)?.toDouble(),
      lightLux: (json['lightLux'] as num?)?.toInt(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const String _savedPlacesFileName = 'urbanecho_saved_places.json';

  int _currentIndex = 0;
  int _focusRequestId = 0;
  SavedPlaceLog? _placeToFocus;
  final List<SavedPlaceLog> _savedPlaces = [];

  @override
  void initState() {
    super.initState();
    _loadSavedPlaces();
  }

  void _savePlace(SavedPlaceLog place) {
    setState(() {
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
      HomeScreen(savedPlaceCount: _savedPlaces.length),
      MapScreen(
        savedPlaces: _savedPlaces,
        onSavePlace: _savePlace,
        onUpdatePlace: _updatePlace,
        onDeletePlace: _deletePlace,
        focusPlace: _placeToFocus,
        focusRequestId: _focusRequestId,
      ),
      HistoryScreen(
        places: _savedPlaces,
        onViewPlace: _viewPlaceOnMap,
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
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
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
  const HomeScreen({super.key, required this.savedPlaceCount});

  final int savedPlaceCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        children: [
          Text(
            'UrbanEcho',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Record places, comments, and revisit saved locations on the map.',
            style: theme.textTheme.titleMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2127),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current milestone',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF7EE4C5),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'The app can request location, show your current position, and save place logs in the current session.',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                const _FeatureChip(label: 'Current location enabled'),
                const SizedBox(height: 8),
                const _FeatureChip(label: 'Save current place'),
                const SizedBox(height: 8),
                _FeatureChip(label: 'Saved points: $savedPlaceCount'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Next planned features',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          const _NextStep(
            title: 'Noise sensing',
            description: 'Capture sound level and combine it with place data.',
          ),
          const _NextStep(
            title: 'Notes and tags',
            description: 'Add manual labels to saved locations.',
          ),
          const _NextStep(
            title: 'History view',
            description: 'Review saved records and jump back to the map.',
          ),
        ],
      ),
    );
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.places,
    required this.onViewPlace,
    required this.onUpdatePlace,
    required this.onDeletePlace,
    required this.onClearAllPlaces,
  });

  final List<SavedPlaceLog> places;
  final ValueChanged<SavedPlaceLog> onViewPlace;
  final void Function(SavedPlaceLog oldPlace, SavedPlaceLog updatedPlace)
  onUpdatePlace;
  final ValueChanged<SavedPlaceLog> onDeletePlace;
  final VoidCallback onClearAllPlaces;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _selectedPlaceType = 'All';
  String _searchQuery = '';
  String _selectedSort = 'Newest';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showJsonExport() {
    final formattedJson = const JsonEncoder.withIndent(
      '  ',
    ).convert(widget.places.map((place) => place.toJson()).toList());

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export JSON'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              formattedJson,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearAll() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all places?'),
        content: const Text(
          'This removes every saved place from local storage. This cannot be undone.',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredPlaces = _sortPlaces(
      _searchPlaces(
        _filterPlacesByType(widget.places, _selectedPlaceType),
        _searchQuery,
      ),
      _selectedSort,
    );

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        children: [
          Text(
            'History',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Review all places saved in this session.',
            style: theme.textTheme.titleMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          _HistorySummary(places: widget.places),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: widget.places.isEmpty ? null : _showJsonExport,
                icon: const Icon(Icons.data_object),
                label: const Text('Export JSON'),
              ),
              TextButton.icon(
                onPressed: widget.places.isEmpty ? null : _confirmClearAll,
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('Clear all'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _PlaceTypeFilter(
            selectedPlaceType: _selectedPlaceType,
            onSelected: (placeType) {
              setState(() {
                _selectedPlaceType = placeType;
              });
            },
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
          if (widget.places.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2127),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                'No saved places yet. Use the map to save your current location.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white70,
                ),
              ),
            )
          else if (filteredPlaces.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2127),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                _searchQuery.trim().isEmpty
                    ? 'No $_selectedPlaceType places saved yet.'
                    : 'No places match this search.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white70,
                ),
              ),
            )
          else
            ...filteredPlaces.map(
              (place) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _HistoryPlaceCard(
                  place: place,
                  onViewPlace: widget.onViewPlace,
                  onUpdatePlace: widget.onUpdatePlace,
                  onDeletePlace: widget.onDeletePlace,
                ),
              ),
            ),
        ],
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
        TextField(
          controller: controller,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    onPressed: onClearSearch,
                    icon: const Icon(Icons.clear),
                    tooltip: 'Clear search',
                  ),
            hintText: 'Search by name, comment, or type',
            filled: true,
            fillColor: const Color(0xFF1A2127),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: selectedSort,
          decoration: InputDecoration(
            labelText: 'Sort records',
            filled: true,
            fillColor: const Color(0xFF1A2127),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
          ),
          items: _historySortOptions
              .map(
                (option) =>
                    DropdownMenuItem(value: option, child: Text(option)),
              )
              .toList(),
          onChanged: onSortChanged,
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
    final updatedPlace = await showDialog<SavedPlaceLog>(
      context: context,
      builder: (context) =>
          _SavePlaceDialog(point: place.point, existingPlace: place),
    );

    if (updatedPlace == null) {
      return;
    }

    onUpdatePlace(place, updatedPlace);
  }
}

class _HistorySummary extends StatelessWidget {
  const _HistorySummary({required this.places});

  final List<SavedPlaceLog> places;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final averageNoise = _averageNoiseDb(places);
    final averageLight = _averageLightLux(places);
    final bestStudyPlace = _bestPlaceFor(places, 'Study');
    final bestRestPlace = _bestPlaceFor(places, 'Rest');
    final bestSocialPlace = _bestPlaceFor(places, 'Social');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2127),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Data summary',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SummaryChip(label: 'Total: ${places.length}'),
              ..._placeTypes.map(
                (type) => _SummaryChip(
                  label: '$type: ${_placeTypeCount(places, type)}',
                ),
              ),
              _SummaryChip(
                label: 'Avg noise: ${_formatNoiseValue(averageNoise)}',
              ),
              _SummaryChip(
                label: 'Avg light: ${_formatLightValue(averageLight)}',
              ),
            ],
          ),
          if (places.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(color: Colors.white.withValues(alpha: 0.08)),
            const SizedBox(height: 10),
            Text(
              'Top picks',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TopPickChip(
                  label: 'Study',
                  place: bestStudyPlace,
                  score: bestStudyPlace == null
                      ? null
                      : _studyScore(bestStudyPlace),
                ),
                _TopPickChip(
                  label: 'Rest',
                  place: bestRestPlace,
                  score: bestRestPlace == null
                      ? null
                      : _restScore(bestRestPlace),
                ),
                _TopPickChip(
                  label: 'Social',
                  place: bestSocialPlace,
                  score: bestSocialPlace == null
                      ? null
                      : _socialScore(bestSocialPlace),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xAA0F3029),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(label, style: Theme.of(context).textTheme.labelMedium),
      ),
    );
  }
}

class _TopPickChip extends StatelessWidget {
  const _TopPickChip({
    required this.label,
    required this.place,
    required this.score,
  });

  final String label;
  final SavedPlaceLog? place;
  final int? score;

  @override
  Widget build(BuildContext context) {
    final text = place == null
        ? '$label: no data'
        : '$label: ${place!.name} (${score ?? 0}/100)';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xAA16263A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(text, style: Theme.of(context).textTheme.labelMedium),
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
    required this.focusPlace,
    required this.focusRequestId,
  });

  final List<SavedPlaceLog> savedPlaces;
  final ValueChanged<SavedPlaceLog> onSavePlace;
  final void Function(SavedPlaceLog oldPlace, SavedPlaceLog updatedPlace)
  onUpdatePlace;
  final ValueChanged<SavedPlaceLog> onDeletePlace;
  final SavedPlaceLog? focusPlace;
  final int focusRequestId;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const LatLng _ucl = LatLng(51.5246, -0.1340);
  static const double _nearbyPlaceThresholdMeters = 25;

  final MapController _mapController = MapController();
  final Light _light = Light();
  final NoiseMeter _noiseMeter = NoiseMeter();
  final Distance _distance = const Distance();

  LatLng? _currentLocation;
  StreamSubscription<int>? _lightSubscription;
  StreamSubscription<NoiseReading>? _noiseSubscription;
  double? _currentNoiseDb;
  int? _currentLightLux;
  bool _isLoading = true;
  bool _isSensorScanning = false;
  String _selectedMapPlaceType = 'All';
  String _statusMessage = 'Requesting location...';
  String _sensorMessage = 'Sensors are off.';

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  @override
  void dispose() {
    _lightSubscription?.cancel();
    _noiseSubscription?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final focusPlace = widget.focusPlace;
    if (focusPlace == null ||
        widget.focusRequestId == oldWidget.focusRequestId) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _focusPlace(focusPlace);
    });
  }

  void _focusPlace(SavedPlaceLog place) {
    _mapController.move(place.point, 17);
    setState(() {
      _statusMessage = 'Viewing ${place.name}.';
    });
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

  Future<void> _saveCurrentPlace() async {
    final location = _currentLocation;
    if (location == null) {
      return;
    }

    final nearbyPlace = _nearestPlaceWithin(
      location,
      _nearbyPlaceThresholdMeters,
    );
    if (nearbyPlace != null) {
      final shouldSaveNewPlace = await _confirmNearbyPlaceSave(
        nearbyPlace.place,
        nearbyPlace.distanceMeters,
      );
      if (!shouldSaveNewPlace) {
        return;
      }
    }

    final place = await showDialog<SavedPlaceLog>(
      context: context,
      builder: (context) => _SavePlaceDialog(
        point: location,
        noiseDb: _currentNoiseDb,
        lightLux: _currentLightLux,
      ),
    );

    if (place == null) {
      return;
    }

    widget.onSavePlace(place);
    setState(() {
      _statusMessage = '${place.name} saved.';
    });
  }

  ({SavedPlaceLog place, double distanceMeters})? _nearestPlaceWithin(
    LatLng point,
    double thresholdMeters,
  ) {
    ({SavedPlaceLog place, double distanceMeters})? nearestPlace;

    for (final place in widget.savedPlaces) {
      final distanceMeters = _distance(point, place.point);
      if (distanceMeters > thresholdMeters) {
        continue;
      }
      if (nearestPlace == null ||
          distanceMeters < nearestPlace.distanceMeters) {
        nearestPlace = (place: place, distanceMeters: distanceMeters);
      }
    }

    return nearestPlace;
  }

  Future<bool> _confirmNearbyPlaceSave(
    SavedPlaceLog nearbyPlace,
    double distanceMeters,
  ) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nearby place already saved'),
        content: Text(
          '${nearbyPlace.name} is about ${distanceMeters.round()} m away. '
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
      _focusPlace(nearbyPlace);
      await _showPlaceDetails(nearbyPlace);
      return false;
    }

    return action == 'save';
  }

  Future<void> _showSavedPlaces() async {
    final selectedPlace = await showModalBottomSheet<SavedPlaceLog>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111417),
      builder: (context) => _SavedPlacesSheet(
        places: widget.savedPlaces,
        currentLocation: _currentLocation,
        onUpdatePlace: widget.onUpdatePlace,
        onDeletePlace: widget.onDeletePlace,
      ),
    );

    if (selectedPlace == null || !mounted) {
      return;
    }

    _focusPlace(selectedPlace);
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

  Future<void> _toggleSensors() async {
    if (_isSensorScanning) {
      await _stopSensors();
      return;
    }

    await _startSensors();
  }

  Future<void> _startSensors() async {
    setState(() {
      _sensorMessage = 'Starting sensors...';
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
          _currentNoiseDb = reading.meanDecibel;
          _sensorMessage = 'Sensors running.';
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
          _currentLightLux = lux < 0 ? null : lux;
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
    final theme = Theme.of(context);
    final location = _currentLocation;
    final visibleSavedPlaces = _filterPlacesByType(
      widget.savedPlaces,
      _selectedMapPlaceType,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Urban Map'),
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: _ucl,
                  initialZoom: 15.2,
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
                        width: 90,
                        height: 90,
                        child: const _MapMarker(
                          color: Color(0xFF8B97A4),
                          icon: Icons.school,
                        ),
                      ),
                      ...visibleSavedPlaces.map(
                        (place) => Marker(
                          point: place.point,
                          width: 88,
                          height: 88,
                          child: GestureDetector(
                            onTap: () => _showPlaceDetails(place),
                            child: _MapMarker(
                              color: _placeTypeColor(place.placeType),
                              icon: Icons.bookmark,
                            ),
                          ),
                        ),
                      ),
                      if (location != null)
                        Marker(
                          point: location,
                          width: 96,
                          height: 96,
                          child: const _MapMarker(
                            color: Color(0xFF7EE4C5),
                            icon: Icons.my_location,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              Positioned(
                left: 16,
                right: 16,
                top: 16,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xCC111417),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          location == null
                              ? 'Waiting for your location'
                              : 'Current location ready',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _statusMessage,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: _isLoading
                                  ? null
                                  : _loadCurrentLocation,
                              icon: const Icon(Icons.my_location),
                              label: const Text('Locate me'),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: location == null
                                  ? null
                                  : _saveCurrentPlace,
                              icon: const Icon(Icons.bookmark_add),
                              label: const Text('Save place'),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: _toggleSensors,
                              icon: Icon(
                                _isSensorScanning
                                    ? Icons.sensors_off
                                    : Icons.sensors,
                              ),
                              label: Text(
                                _isSensorScanning
                                    ? 'Stop sensors'
                                    : 'Start sensors',
                              ),
                            ),
                          ],
                        ),
                        if (location != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Lat ${location.latitude.toStringAsFixed(5)} | Lng ${location.longitude.toStringAsFixed(5)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF7EE4C5),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Text(
                          _sensorMessage,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _SensorChip(
                              icon: Icons.graphic_eq,
                              label:
                                  'Noise: ${_formatNoiseValue(_currentNoiseDb)}',
                            ),
                            _SensorChip(
                              icon: Icons.wb_sunny_outlined,
                              label:
                                  'Light: ${_formatLightValue(_currentLightLux)}',
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _EnvironmentFitCard(
                          assessment: _assessEnvironmentValues(
                            noiseDb: _currentNoiseDb,
                            lightLux: _currentLightLux,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: FilledButton.tonalIcon(
                  onPressed: _showSavedPlaces,
                  icon: const Icon(Icons.list_alt),
                  label: Text('Saved (${widget.savedPlaces.length})'),
                ),
              ),
              Positioned(
                left: 16,
                right: 132,
                bottom: 16,
                child: _MapPlaceFilter(
                  selectedPlaceType: _selectedMapPlaceType,
                  visibleCount: visibleSavedPlaces.length,
                  totalCount: widget.savedPlaces.length,
                  onSelected: (placeType) {
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

class _MapPlaceFilter extends StatelessWidget {
  const _MapPlaceFilter({
    required this.selectedPlaceType,
    required this.visibleCount,
    required this.totalCount,
    required this.onSelected,
  });

  final String selectedPlaceType;
  final int visibleCount;
  final int totalCount;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xCC111417),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedPlaceType == 'All'
                  ? 'Showing $totalCount saved'
                  : 'Showing $visibleCount/$totalCount $selectedPlaceType',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 6),
            _PlaceTypeFilter(
              selectedPlaceType: selectedPlaceType,
              onSelected: onSelected,
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedPlacesSheet extends StatelessWidget {
  const _SavedPlacesSheet({
    required this.places,
    required this.currentLocation,
    required this.onUpdatePlace,
    required this.onDeletePlace,
  });

  final List<SavedPlaceLog> places;
  final LatLng? currentLocation;
  final void Function(SavedPlaceLog oldPlace, SavedPlaceLog updatedPlace)
  onUpdatePlace;
  final ValueChanged<SavedPlaceLog> onDeletePlace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String selectedPlaceType = 'All';
    String selectedSort = currentLocation == null ? 'Newest' : 'Nearest';

    return SafeArea(
      child: StatefulBuilder(
        builder: (context, setSheetState) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.58,
            minChildSize: 0.32,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              final filteredPlaces = _sortSavedPlacesForMapSheet(
                _filterPlacesByType(places, selectedPlaceType),
                selectedSort,
                currentLocation,
              );

              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Saved places',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          selectedPlaceType == 'All'
                              ? '${places.length}'
                              : '${filteredPlaces.length}/${places.length}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: const Color(0xFF7EE4C5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _PlaceTypeFilter(
                      selectedPlaceType: selectedPlaceType,
                      onSelected: (placeType) {
                        setSheetState(() {
                          selectedPlaceType = placeType;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedSort,
                      decoration: InputDecoration(
                        labelText: 'Sort saved places',
                        filled: true,
                        fillColor: const Color(0xFF1A2127),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items:
                          [
                                if (currentLocation != null) 'Nearest',
                                'Newest',
                                'Oldest',
                              ]
                              .map(
                                (sortMode) => DropdownMenuItem(
                                  value: sortMode,
                                  child: Text(sortMode),
                                ),
                              )
                              .toList(),
                      onChanged: (sortMode) {
                        if (sortMode == null) {
                          return;
                        }

                        setSheetState(() {
                          selectedSort = sortMode;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: places.isEmpty
                          ? Center(
                              child: Text(
                                'No places saved yet.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                            )
                          : filteredPlaces.isEmpty
                          ? Center(
                              child: Text(
                                'No $selectedPlaceType places saved yet.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                            )
                          : ListView.separated(
                              controller: scrollController,
                              itemCount: filteredPlaces.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final place = filteredPlaces[index];
                                return InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => Navigator.of(context).pop(place),
                                  child: _SavedPlaceSummary(
                                    place: place,
                                    currentLocation: currentLocation,
                                    trailing: Wrap(
                                      spacing: 2,
                                      children: [
                                        IconButton(
                                          tooltip: 'Edit',
                                          onPressed: () async {
                                            final updatedPlace =
                                                await showDialog<SavedPlaceLog>(
                                                  context: context,
                                                  builder: (context) =>
                                                      _SavePlaceDialog(
                                                        point: place.point,
                                                        existingPlace: place,
                                                      ),
                                                );

                                            if (updatedPlace == null) {
                                              return;
                                            }

                                            onUpdatePlace(place, updatedPlace);
                                            setSheetState(() {});
                                          },
                                          icon: const Icon(Icons.edit_outlined),
                                        ),
                                        IconButton(
                                          tooltip: 'Delete',
                                          onPressed: () {
                                            onDeletePlace(place);
                                            setSheetState(() {});
                                          },
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SavePlaceDialog extends StatefulWidget {
  const _SavePlaceDialog({
    required this.point,
    this.noiseDb,
    this.lightLux,
    this.existingPlace,
  });

  final LatLng point;
  final double? noiseDb;
  final int? lightLux;
  final SavedPlaceLog? existingPlace;

  @override
  State<_SavePlaceDialog> createState() => _SavePlaceDialogState();
}

class _SavePlaceDialogState extends State<_SavePlaceDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  String _placeType = _placeTypes.first;

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
          ) ??
          SavedPlaceLog(
            point: widget.point,
            recordedAt: DateTime.now(),
            name: name,
            placeType: _placeType,
            comment: comment,
            noiseDb: widget.noiseDb,
            lightLux: widget.lightLux,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existingPlace == null ? 'Save this place' : 'Edit place',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Place name',
                hintText: 'e.g. Library corner',
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _placeType,
              decoration: const InputDecoration(labelText: 'Place type'),
              items: _placeTypes
                  .map(
                    (type) => DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _placeType = value;
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Comment',
                hintText: 'How does this place feel?',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Lat ${widget.point.latitude.toStringAsFixed(5)} | Lng ${widget.point.longitude.toStringAsFixed(5)}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF7EE4C5)),
            ),
            const SizedBox(height: 8),
            Text(
              'Noise ${_formatNoiseValue(widget.existingPlace?.noiseDb ?? widget.noiseDb)} | Light ${_formatLightValue(widget.existingPlace?.lightLux ?? widget.lightLux)}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.existingPlace == null ? 'Save' : 'Update'),
        ),
      ],
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
    final updatedPlace = await showDialog<SavedPlaceLog>(
      context: context,
      builder: (context) =>
          _SavePlaceDialog(point: place.point, existingPlace: place),
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
    this.trailing,
  });

  final SavedPlaceLog place;
  final LatLng? currentLocation;
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
        color: const Color(0xAA1A2127),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bookmark,
                  size: 16,
                  color: _placeTypeColor(place.placeType),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    place.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  place.placeType,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _placeTypeColor(place.placeType),
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 4), trailing!],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              comment,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Text(
              [
                '${place.point.latitude.toStringAsFixed(4)}, ${place.point.longitude.toStringAsFixed(4)}',
                _formatTime(place.recordedAt),
                if (distanceLabel != null) distanceLabel,
              ].join('  •  '),
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SensorChip(
                  icon: Icons.graphic_eq,
                  label:
                      '${_noiseLevelFromDb(place.noiseDb)} (${_formatNoiseValue(place.noiseDb)})',
                ),
                _SensorChip(
                  icon: Icons.wb_sunny_outlined,
                  label:
                      '${_lightLevelFromLux(place.lightLux)} (${_formatLightValue(place.lightLux)})',
                ),
              ],
            ),
            const SizedBox(height: 8),
            _EnvironmentFitCard(assessment: _assessEnvironment(place)),
          ],
        ),
      ),
    );
  }
}

class _SensorChip extends StatelessWidget {
  const _SensorChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xAA0F3029),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF7EE4C5)),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _EnvironmentFitCard extends StatelessWidget {
  const _EnvironmentFitCard({required this.assessment});

  final _EnvironmentAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: assessment.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: assessment.color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(assessment.icon, size: 16, color: assessment.color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    assessment.label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: assessment.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${assessment.score}/100',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: assessment.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: assessment.score / 100,
                backgroundColor: Colors.white12,
                color: assessment.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              assessment.reason,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
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

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0F3029),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(label),
      ),
    );
  }
}

class _NextStep extends StatelessWidget {
  const _NextStep({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFF1D6F5F),
          child: Icon(Icons.arrow_outward, color: Colors.white),
        ),
        title: Text(title),
        subtitle: Text(
          description,
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: const Color(0xFF0E1816), size: 26),
        ),
        Container(width: 2, height: 18, color: color),
      ],
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

List<SavedPlaceLog> _filterPlacesByType(
  List<SavedPlaceLog> places,
  String placeType,
) {
  if (placeType == 'All') {
    return places;
  }

  return places.where((place) => place.placeType == placeType).toList();
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

List<SavedPlaceLog> _sortSavedPlacesForMapSheet(
  List<SavedPlaceLog> places,
  String sortMode,
  LatLng? currentLocation,
) {
  final sortedPlaces = List<SavedPlaceLog>.of(places);

  switch (sortMode) {
    case 'Nearest':
      final location = currentLocation;
      if (location == null) {
        return sortedPlaces;
      }
      const distance = Distance();
      sortedPlaces.sort(
        (a, b) =>
            distance(location, a.point).compareTo(distance(location, b.point)),
      );
    case 'Oldest':
      sortedPlaces.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    case 'Newest':
    default:
      sortedPlaces.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }

  return sortedPlaces;
}

int _placeTypeCount(List<SavedPlaceLog> places, String placeType) {
  return places.where((place) => place.placeType == placeType).length;
}

SavedPlaceLog? _bestPlaceFor(List<SavedPlaceLog> places, String targetUse) {
  if (places.isEmpty) {
    return null;
  }

  final placesWithSensorData = places
      .where((place) => place.noiseDb != null || place.lightLux != null)
      .toList();
  if (placesWithSensorData.isEmpty) {
    return null;
  }

  return placesWithSensorData.reduce((best, next) {
    return _scoreForUse(next, targetUse) > _scoreForUse(best, targetUse)
        ? next
        : best;
  });
}

int _scoreForUse(SavedPlaceLog place, String targetUse) {
  return switch (targetUse) {
    'Study' => _studyScore(place),
    'Rest' => _restScore(place),
    'Social' => _socialScore(place),
    _ => 0,
  };
}

double? _averageNoiseDb(List<SavedPlaceLog> places) {
  final values = places
      .map((place) => place.noiseDb)
      .whereType<double>()
      .toList();
  if (values.isEmpty) {
    return null;
  }

  return values.reduce((sum, value) => sum + value) / values.length;
}

int? _averageLightLux(List<SavedPlaceLog> places) {
  final values = places
      .map((place) => place.lightLux)
      .whereType<int>()
      .toList();
  if (values.isEmpty) {
    return null;
  }

  return (values.reduce((sum, value) => sum + value) / values.length).round();
}

String _formatNoiseValue(double? value) {
  return value == null ? 'Unknown' : '${value.toStringAsFixed(1)} dB';
}

String _formatLightValue(int? value) {
  return value == null ? 'Unknown' : '$value lux';
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
      color: Color(0xFF8B97A4),
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
      color: const Color(0xFF7EE4C5),
    ),
    'Rest' => _EnvironmentAssessment(
      label: 'Best for rest',
      reason:
          'Lower stimulation makes this place better for breaks or reading.',
      score: bestUse.value,
      icon: Icons.self_improvement_outlined,
      color: const Color(0xFF9AB7FF),
    ),
    _ => _EnvironmentAssessment(
      label: 'Best for social',
      reason:
          'Higher activity and enough light make this place better for meeting others.',
      score: bestUse.value,
      icon: Icons.groups_2_outlined,
      color: const Color(0xFFFFC36A),
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
    'Study' => const Color(0xFF7EE4C5),
    'Rest' => const Color(0xFF8FB8FF),
    'Social' => const Color(0xFFFFB84D),
    _ => const Color(0xFF8B97A4),
  };
}
