library urbanecho;

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

part 'constants/app_constants.dart';
part 'theme/app_theme.dart';
part 'models/app_models.dart';
part 'app/urban_echo_app.dart';
part 'app/app_shell.dart';
part 'screens/intro_screen.dart';
part 'screens/home_screen.dart';
part 'screens/places_screen.dart';
part 'screens/map_screen.dart';
part 'widgets/home_widgets.dart';
part 'widgets/place_widgets.dart';
part 'widgets/map_widgets.dart';
part 'utils/place_helpers.dart';

void main() {
  runApp(const UrbanEchoApp());
}
