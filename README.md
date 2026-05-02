# UrbanEcho

UrbanEcho is an Android-first Flutter app for recording and exploring city places through environmental sensing, map-based place memory, and shared public feedback. It combines phone sensors, location, OpenStreetMap, and MQTT so users can compare how different places feel for studying, resting, or socialising.

## Project Idea

Students and city users often choose places based on vague memory: whether a space felt quiet, bright, busy, or comfortable. UrbanEcho turns those impressions into small place records by combining:

- Noise readings from the phone microphone.
- Light readings from the phone light sensor.
- GPS location shown on an interactive map.
- User notes, activity type, star ratings, and shared comments.
- MQTT-based online sharing so places can appear for other users.

The app is not intended to be a scientific pollution monitor. Its goal is to make urban environmental experience easier to record, compare, and discuss.

## Current Features

- Warm notebook-style interface with Home, Map, and Places views.
- Intro screen explaining the purpose of the app.
- Live sensor scanning for noise and light.
- Current location detection and map centering.
- Create places by moving the map under a fixed centre marker.
- Save place name, activity type, notes, 0-5 star rating, and sensor context.
- All Places and Favorites views with search, filtering, sorting, and top-rated places.
- Online shared map using MQTT, including average ratings and public comments.
- Local favorites for places the user wants to keep.
- Temporary moderation delete action for shared places during prototype testing.
- OpenStreetMap map tiles through `flutter_map`.

## Screenshots

> Screenshots are stored under `media/readme/`. The files below should be added before final submission.

| Home | Map |
| --- | --- |
| ![Home screen](media/readme/01_home.png) | ![Map screen](media/readme/02_map.png) |

| Create Place | Places |
| --- | --- |
| ![Create place sheet](media/readme/03_create_place.png) | ![Places screen](media/readme/04_places.png) |

| Place Details | Shared Comments |
| --- | --- |
| ![Place details](media/readme/05_place_details.png) | ![Shared comments](media/readme/06_shared_comments.png) |

## How It Works

1. The user opens the app and starts scanning sensors on the Map page.
2. The app reads current GPS location, noise level, and light level.
3. The user creates a place by moving the map so the fixed centre marker points to the target location.
4. A place record is saved with coordinates, sensor readings, activity type, rating, and comment.
5. If MQTT is configured, the record is uploaded to the shared topic and synced with other users.
6. Users can browse all shared places, favorite useful places locally, and compare places by activity fit, rating, noise, or light.

## Activity Scoring

UrbanEcho uses simple rule-based scoring to turn sensor readings into activity suggestions:

- Study places are favoured when they are quieter and reasonably bright.
- Rest places are favoured when they are quieter and softer in light.
- Social places are favoured when they are more active and brighter.

The score is intentionally understandable rather than opaque. It supports user decision-making without pretending to be a precise environmental model.

## Technology

- Flutter and Dart.
- Android target platform.
- `flutter_map` with OpenStreetMap tiles.
- `geolocator` for GPS location.
- `noise_meter` for microphone-based noise readings.
- `light` for ambient light readings.
- `mqtt_client` for shared online place data.
- `path_provider` for local favorites persistence.
- `permission_handler` for runtime permissions.

## MQTT Configuration

The real MQTT credential file is intentionally ignored by Git:

```text
assets/config/mqtt_config.json
```

Use the example file as a template:

```text
assets/config/mqtt_config.example.json
```

Local setup:

```bash
cp assets/config/mqtt_config.example.json assets/config/mqtt_config.json
```

Then edit `assets/config/mqtt_config.json` with your own server details:

```json
{
  "host": "your-mqtt-server.example.com",
  "port": 1883,
  "username": "your-mqtt-username",
  "password": "your-mqtt-password",
  "topicPrefix": "urbanecho/places"
}
```

No real username or password should be committed to this repository.

## Running Locally

Install dependencies:

```bash
flutter pub get
```

List connected devices:

```bash
flutter devices
```

Run on an Android phone:

```bash
flutter run -d <android-device-id>
```

Build an Android release APK:

```bash
flutter build apk --release
```

## Repository Structure

```text
lib/
  app/          App shell and top-level app widget
  constants/    Shared app constants
  models/       Place, shared place, and MQTT settings models
  screens/      Home, Map, Places, and intro screens
  theme/        Warm city notebook theme and colour system
  utils/        Formatting, scoring, and place helper functions
  widgets/      Reusable UI components
assets/
  config/       MQTT example config and ignored local config
android/        Android project files
```

## Assessment Notes

UrbanEcho addresses the Mobile Systems coursework requirements by including:

- Multiple app views with a coherent user journey.
- On-device sensor use through location, microphone noise, and light readings.
- Interaction with the physical environment through live sensing and map-based place creation.
- External service integration through MQTT-based shared place data.
- Iterative GitHub development history with incremental commits.
- Android native testing on a physical phone.

## Future Improvements

- Replace prototype delete controls with a proper moderation and review workflow.
- Add stronger duplicate-place detection and merge suggestions.
- Add offline-first sync queues for unstable networks.
- Improve accessibility testing and larger text layouts.
- Add a landing page and final project video for assessment presentation.
