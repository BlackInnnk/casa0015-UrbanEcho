part of urbanecho;

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
