part of urbanecho;

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
