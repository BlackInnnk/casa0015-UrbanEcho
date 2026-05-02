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
- Opening screen explaining the purpose of the app.
- Live sensor scanning for noise and light.
- Current location detection and map centering.
- Create places by moving the map under a fixed centre marker.
- Create shared places with a name, activity type, notes, 0-5 star rating, and sensor context.
- Places view with All Places, Favorites, search, filtering, sorting, and top-rated places.
- MQTT-based shared places, average ratings, and public comments.
- Local favorites for places the user wants to bookmark.
- Temporary moderation delete action for shared places during prototype testing.
- OpenStreetMap map tiles through `flutter_map`.

## App Walkthrough

### Opening and Home

UrbanEcho starts with a short opening page that explains the app purpose before moving into the main interface. The Home page gives quick access to All Places, activity-based browsing, the map, and recent favorites.

<img src="media/09_loading_page.jpg" alt="Opening screen" width="260">
<img src="media/01_home.jpg" alt="Home screen" width="260">

### Map and Sensor Capture

The Map page shows the user's current location, shared places, and favorited places. The bottom panel contains the main actions: locating the user, starting sensor capture, creating a place, and opening the Places view.

<img src="media/02_map.jpg" alt="Map screen" width="260">
<img src="media/03_map_sensor.jpg" alt="Map controls and sensors" width="260">

### Creating a Place

To create a place, the user first starts Sensors so the app has noise and light data. The place is positioned by moving the map under the fixed centre marker, then the create sheet records the name, activity type, rating, note, coordinates, and sensor context.

<img src="media/04_create_place.jpg" alt="Create place sheet" width="260">

### All Places and Sorting

All Places shows shared MQTT places from all users. The list can be filtered by activity type and sorted by recency, rating, study fit, rest fit, social fit, noise, or light.

<img src="media/05_all_places.jpg" alt="All places screen" width="260">
<img src="media/06_place_sort.jpg" alt="Place sorting options" width="260">

### Favorites

Favorites are local bookmarks for places the user wants to keep. They make it easier to return to useful shared places without changing the public All Places list.

<img src="media/07_fav_places.jpg" alt="Favorite places screen" width="260">

### Place Details and Public Feedback

Place Details combines location, environmental fit, sensor readings, average star rating, and public comments. Each user can add one rating/comment for a shared place and later edit their own review; the displayed score is calculated from shared feedback.

<img src="media/08_place_details.jpg" alt="Place details with environmental fit and public reviews" width="260">

## How It Works

1. The user opens the app and reviews the opening screen.
2. On the Map page, the user starts Sensors so the app can read GPS location, noise level, and light level.
3. The user creates a place by moving the map so the fixed centre marker points to the target location.
4. The create sheet stores the place name, activity type, note, rating, coordinates, and sensor readings.
5. If MQTT is configured, the place is uploaded to All Places and synced with other users.
6. Other users can open Place Details, add or edit their own rating/comment, and see the average score.
7. Users can bookmark useful shared places into Favorites for quick local access.

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
