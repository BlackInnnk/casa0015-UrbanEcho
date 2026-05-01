part of urbanecho;

const List<String> _placeTypes = ['Study', 'Rest', 'Social'];
const List<String> _historySortOptions = [
  'Newest',
  'Oldest',
  'Best study fit',
  'Best rest fit',
  'Best social fit',
  'Best rated',
  'Quietest',
  'Noisiest',
  'Brightest',
  'Dimmest',
];
const String _mqttConfigAssetPath = 'assets/config/mqtt_config.json';
const String _defaultMqttHost = String.fromEnvironment(
  'MQTT_HOST',
  defaultValue: 'your-mqtt-host.example.com',
);
const int _defaultMqttPort = int.fromEnvironment(
  'MQTT_PORT',
  defaultValue: 1883,
);
const String _defaultMqttUser = String.fromEnvironment(
  'MQTT_USER',
  defaultValue: 'your-username',
);
const String _defaultMqttPass = String.fromEnvironment(
  'MQTT_PASS',
  defaultValue: 'your-password',
);
const String _defaultMqttTopicPrefix = String.fromEnvironment(
  'MQTT_TOPIC_PREFIX',
  defaultValue: 'urbanecho/places',
);
