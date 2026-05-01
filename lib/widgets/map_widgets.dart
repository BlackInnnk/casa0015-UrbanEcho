part of urbanecho;

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

class _ProjectedMarkerLayer extends StatelessWidget {
  const _ProjectedMarkerLayer({
    required this.campusPoint,
    required this.currentLocation,
    required this.savedPlaces,
    required this.sharedPlaceGroups,
    required this.onSavedPlaceTap,
    required this.onSharedPlaceTap,
  });

  final LatLng campusPoint;
  final LatLng? currentLocation;
  final List<SavedPlaceLog> savedPlaces;
  final List<SharedPlaceGroup> sharedPlaceGroups;
  final Future<void> Function(SavedPlaceLog place) onSavedPlaceTap;
  final Future<void> Function(SharedPlaceGroup group) onSharedPlaceTap;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        _ProjectedMapMarker(
          camera: camera,
          point: campusPoint,
          width: 52,
          height: 52,
          anchor: Alignment.bottomCenter,
          child: const _MapMarker(color: _mutedInk, icon: Icons.school),
        ),
        ...savedPlaces.map(
          (place) => _ProjectedMapMarker(
            camera: camera,
            point: place.point,
            width: 52,
            height: 52,
            anchor: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {
                onSavedPlaceTap(place);
              },
              child: _MapMarker(
                color: _placeTypeColor(place.placeType),
                icon: Icons.bookmark,
              ),
            ),
          ),
        ),
        ...sharedPlaceGroups.map(
          (sharedGroup) => _ProjectedMapMarker(
            camera: camera,
            point: sharedGroup.place.point,
            width: 52,
            height: 52,
            anchor: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {
                onSharedPlaceTap(sharedGroup);
              },
              child: _MapMarker(
                color: _placeTypeColor(
                  sharedGroup.place.placeType,
                ).withValues(alpha: 0.72),
                icon: Icons.public,
              ),
            ),
          ),
        ),
        if (currentLocation != null)
          _ProjectedMapMarker(
            camera: camera,
            point: currentLocation!,
            width: 44,
            height: 44,
            anchor: Alignment.center,
            child: const _CurrentLocationMarker(),
          ),
      ],
    );
  }
}

class _ProjectedMapMarker extends StatelessWidget {
  const _ProjectedMapMarker({
    required this.camera,
    required this.point,
    required this.width,
    required this.height,
    required this.anchor,
    required this.child,
  });

  final MapCamera camera;
  final LatLng point;
  final double width;
  final double height;
  final Alignment anchor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final offset = camera.latLngToScreenOffset(point);
    final anchorX = (anchor.x + 1) / 2;
    final anchorY = (anchor.y + 1) / 2;

    return Positioned(
      left: offset.dx - width * anchorX,
      top: offset.dy - height * anchorY,
      width: width,
      height: height,
      child: child,
    );
  }
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
