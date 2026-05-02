part of urbanecho;

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

class _SharedReviewDraft {
  const _SharedReviewDraft({required this.comment, required this.rating});

  final String comment;
  final double rating;

  bool get hasContent => comment.trim().isNotEmpty || rating > 0;
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
