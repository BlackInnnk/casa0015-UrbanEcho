part of urbanecho;

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
      if (_hasActiveMqttConnection) {
        return true;
      }
      if (!_isMqttConnecting) {
        return false;
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }

    return _hasActiveMqttConnection;
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
    if (_isMqttConnecting || _hasActiveMqttConnection) {
      return;
    }

    if (!_mqttSettings.isConfigured) {
      setState(() {
        _isMqttConnected = false;
        _isMqttConnecting = false;
      });
      return;
    }

    _mqttClient?.disconnect();
    setState(() {
      _mqttClient = null;
      _isMqttConnected = false;
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

  bool get _hasActiveMqttConnection {
    final client = _mqttClient;
    return client != null &&
        client.connectionStatus?.state == MqttConnectionState.connected;
  }

  Future<bool> _ensureMqttConnected() async {
    if (_hasActiveMqttConnection) {
      return true;
    }

    if (_isMqttConnecting) {
      return _waitForMqttConnection();
    }

    await _connectSharedMap();
    if (_isMqttConnecting) {
      return _waitForMqttConnection();
    }

    return _hasActiveMqttConnection;
  }

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
    if (_hasActiveMqttConnection && client != null) {
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
    final sharedPlace = SharedPlaceLog(
      id: _sharedPlaceId(place),
      source: 'anonymous-urbanecho',
      uploadedAt: DateTime.now(),
      place: place,
    );
    final builder = MqttClientPayloadBuilder()
      ..addString(jsonEncode(sharedPlace.toJson()));

    for (var attempt = 0; attempt < 2; attempt += 1) {
      final connected = await _ensureMqttConnected();
      final client = _mqttClient;
      if (!connected || client == null) {
        continue;
      }

      try {
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
      } catch (_) {
        client.disconnect();
        if (!mounted) {
          return false;
        }
        setState(() {
          _mqttClient = null;
          _isMqttConnected = false;
          _isMqttConnecting = false;
        });
      }
    }

    return false;
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
                options: MapOptions(initialCenter: _ucl, initialZoom: 15.2),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.urbanecho',
                  ),
                  Positioned.fill(
                    child: _ProjectedMarkerLayer(
                      campusPoint: _ucl,
                      currentLocation: location,
                      savedPlaces: visibleSavedPlaces,
                      sharedPlaceGroups: visibleSharedPlaces,
                      onSavedPlaceTap: _showPlaceDetails,
                      onSharedPlaceTap: _showSharedPlaceDetails,
                    ),
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
