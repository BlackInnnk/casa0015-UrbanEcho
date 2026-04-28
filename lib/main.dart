import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

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
  });

  final LatLng point;
  final DateTime recordedAt;
  final String name;
  final String placeType;
  final String comment;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  int _focusRequestId = 0;
  SavedPlaceLog? _placeToFocus;
  final List<SavedPlaceLog> _savedPlaces = [];

  void _savePlace(SavedPlaceLog place) {
    setState(() {
      _savedPlaces.insert(0, place);
    });
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
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(savedPlaceCount: _savedPlaces.length),
      MapScreen(
        savedPlaces: _savedPlaces,
        onSavePlace: _savePlace,
        onDeletePlace: _deletePlace,
        focusPlace: _placeToFocus,
        focusRequestId: _focusRequestId,
      ),
      HistoryScreen(
        places: _savedPlaces,
        onViewPlace: _viewPlaceOnMap,
        onDeletePlace: _deletePlace,
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

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({
    super.key,
    required this.places,
    required this.onViewPlace,
    required this.onDeletePlace,
  });

  final List<SavedPlaceLog> places;
  final ValueChanged<SavedPlaceLog> onViewPlace;
  final ValueChanged<SavedPlaceLog> onDeletePlace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
          const SizedBox(height: 24),
          if (places.isEmpty)
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
          else
            ...places.map(
              (place) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _HistoryPlaceCard(
                  place: place,
                  onViewPlace: onViewPlace,
                  onDeletePlace: onDeletePlace,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryPlaceCard extends StatelessWidget {
  const _HistoryPlaceCard({
    required this.place,
    required this.onViewPlace,
    required this.onDeletePlace,
  });

  final SavedPlaceLog place;
  final ValueChanged<SavedPlaceLog> onViewPlace;
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
}

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.savedPlaces,
    required this.onSavePlace,
    required this.onDeletePlace,
    required this.focusPlace,
    required this.focusRequestId,
  });

  final List<SavedPlaceLog> savedPlaces;
  final ValueChanged<SavedPlaceLog> onSavePlace;
  final ValueChanged<SavedPlaceLog> onDeletePlace;
  final SavedPlaceLog? focusPlace;
  final int focusRequestId;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const LatLng _ucl = LatLng(51.5246, -0.1340);

  final MapController _mapController = MapController();

  LatLng? _currentLocation;
  bool _isLoading = true;
  String _statusMessage = 'Requesting location...';

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
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

    final place = await showDialog<SavedPlaceLog>(
      context: context,
      builder: (context) => _SavePlaceDialog(point: location),
    );

    if (place == null) {
      return;
    }

    widget.onSavePlace(place);
    setState(() {
      _statusMessage = '${place.name} saved.';
    });
  }

  Future<void> _showSavedPlaces() async {
    final selectedPlace = await showModalBottomSheet<SavedPlaceLog>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111417),
      builder: (context) => _SavedPlacesSheet(
        places: widget.savedPlaces,
        onDeletePlace: widget.onDeletePlace,
      ),
    );

    if (selectedPlace == null || !mounted) {
      return;
    }

    _focusPlace(selectedPlace);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = _currentLocation;

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
                      ...widget.savedPlaces.map(
                        (place) => Marker(
                          point: place.point,
                          width: 88,
                          height: 88,
                          child: _MapMarker(
                            color: _placeTypeColor(place.placeType),
                            icon: Icons.bookmark,
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
              if (_isLoading) const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedPlacesSheet extends StatelessWidget {
  const _SavedPlacesSheet({required this.places, required this.onDeletePlace});

  final List<SavedPlaceLog> places;
  final ValueChanged<SavedPlaceLog> onDeletePlace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: StatefulBuilder(
        builder: (context, setSheetState) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.58,
            minChildSize: 0.32,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
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
                          '${places.length}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: const Color(0xFF7EE4C5),
                          ),
                        ),
                      ],
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
                          : ListView.separated(
                              controller: scrollController,
                              itemCount: places.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final place = places[index];
                                return InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => Navigator.of(context).pop(place),
                                  child: _SavedPlaceSummary(
                                    place: place,
                                    trailing: IconButton(
                                      tooltip: 'Delete',
                                      onPressed: () {
                                        onDeletePlace(place);
                                        setSheetState(() {});
                                      },
                                      icon: const Icon(Icons.delete_outline),
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
  const _SavePlaceDialog({required this.point});

  final LatLng point;

  @override
  State<_SavePlaceDialog> createState() => _SavePlaceDialogState();
}

class _SavePlaceDialogState extends State<_SavePlaceDialog> {
  static const List<String> _placeTypes = ['Study', 'Rest', 'Social'];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  String _placeType = _placeTypes.first;

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
      SavedPlaceLog(
        point: widget.point,
        recordedAt: DateTime.now(),
        name: name,
        placeType: _placeType,
        comment: comment,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save this place'),
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

class _SavedPlaceSummary extends StatelessWidget {
  const _SavedPlaceSummary({required this.place, this.trailing});

  final SavedPlaceLog place;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final comment = place.comment.isEmpty ? 'No comment added.' : place.comment;

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
              '${place.point.latitude.toStringAsFixed(4)}, ${place.point.longitude.toStringAsFixed(4)}  •  ${_formatTime(place.recordedAt)}',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
            ),
          ],
        ),
      ),
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

String _formatTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  final second = value.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}

Color _placeTypeColor(String placeType) {
  return switch (placeType) {
    'Study' => const Color(0xFF7EE4C5),
    'Rest' => const Color(0xFF8FB8FF),
    'Social' => const Color(0xFFFFB84D),
    _ => const Color(0xFF8B97A4),
  };
}
