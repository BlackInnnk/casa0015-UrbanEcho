part of urbanecho;

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
  const _SharedCommentCard({
    required this.sharedPlace,
    this.isOwnReview = false,
  });

  final SharedPlaceLog sharedPlace;
  final bool isOwnReview;

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
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _StarRatingDisplay(rating: sharedPlace.place.rating),
                if (isOwnReview) ...[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: _tealSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      child: Text(
                        'Your review',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: _teal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
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

Future<_SharedReviewDraft?> _showSharedReviewSheet(
  BuildContext context, {
  required SavedPlaceLog place,
  required SharedPlaceLog? existingReview,
}) {
  return showModalBottomSheet<_SharedReviewDraft>(
    context: context,
    isScrollControlled: true,
    builder: (context) =>
        _SharedReviewSheet(place: place, existingReview: existingReview),
  );
}

class _SharedReviewSheet extends StatefulWidget {
  const _SharedReviewSheet({required this.place, required this.existingReview});

  final SavedPlaceLog place;
  final SharedPlaceLog? existingReview;

  @override
  State<_SharedReviewSheet> createState() => _SharedReviewSheetState();
}

class _SharedReviewSheetState extends State<_SharedReviewSheet> {
  final TextEditingController _commentController = TextEditingController();
  double _rating = 0;

  @override
  void initState() {
    super.initState();
    final existingReview = widget.existingReview;
    if (existingReview == null) {
      return;
    }

    _commentController.text = existingReview.place.comment;
    _rating = existingReview.place.rating ?? 0;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submit() {
    final review = _SharedReviewDraft(
      comment: _commentController.text.trim(),
      rating: _rating,
    );
    if (!review.hasContent) {
      return;
    }

    Navigator.of(context).pop(review);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existingReview != null;
    final canSubmit = _commentController.text.trim().isNotEmpty || _rating > 0;

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
                  isEditing ? 'Edit your review' : 'Review this place',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.place.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: _mutedInk),
                ),
                const SizedBox(height: 14),
                const _FieldLabel('Public comment'),
                TextField(
                  controller: _commentController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'What should other people know about this place?',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
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
                        onPressed: canSubmit ? _submit : null,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          isEditing ? 'Update review' : 'Post review',
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
      actionsOverflowDirection: VerticalDirection.down,
      actionsOverflowButtonSpacing: 8,
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
            Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _StarRatingDisplay(
                  rating: averageRating ?? place.rating,
                  ratingCount: ratingCount,
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 190),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    children: [
                      Text(
                        '${_noiseLevelFromDb(place.noiseDb)} ${_formatNoiseValue(place.noiseDb)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: _mutedInk,
                        ),
                      ),
                      Text(
                        '${_lightLevelFromLux(place.lightLux)} ${_formatLightValue(place.lightLux)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: _mutedInk,
                        ),
                      ),
                    ],
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
