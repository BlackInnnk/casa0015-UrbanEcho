part of urbanecho;

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
