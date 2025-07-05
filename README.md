# Connect-Ed 📚

**A comprehensive student companion app that streamlines daily school life**

Connect-Ed is a mobile application designed to enhance the daily experience of students by providing a centralized hub for all essential school-related information. The app integrates schedules, meal menus, sports events, and academic assessments into one beautiful, easy-to-use interface.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-039BE5?style=for-the-badge&logo=Firebase&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)

## ✨ Features

### 📅 **Personalized Schedules**
- Daily and weekly class schedules synced with school webcal feeds
- Special events and holiday integration
- Filter by day, week, or custom date ranges

### 🍽️ **Meal Menus**
- Breakfast, lunch, and dinner menus updated daily
- Dietary options and allergen information
- Clean, easy-to-read interface

### 🏆 **Sports Events & Scores**
- Upcoming games and sports events
- Live scores and results
- Team standings and statistics
- Detailed game information with times and locations

### 📝 **Assessment Tracker**
- Track upcoming assignments and exams
- Integration with calendar system
- Push notifications for deadlines

### 📱 **Unified Calendar View**
- All events in one color-coded calendar
- Classes, meals, sports, and assessments combined
- Intuitive navigation and filtering

### 🔔 **Smart Notifications**
- Schedule changes and updates
- New menu items and sports results
- Assessment deadline reminders
- Customizable notification preferences

## 🏗️ Architecture

- **Frontend**: Flutter (Dart)
- **Backend**: Firebase
- **Database**: Cloud Firestore
- **Authentication**: Firebase Auth
- **Push Notifications**: Firebase Cloud Messaging
- **Analytics**: Firebase Analytics

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (>=3.7.0)
- [Firebase CLI](https://firebase.google.com/docs/cli)
- Xcode (for iOS development)
- Android Studio (for Android development)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/connect-ed-2.git
   cd connect-ed-2
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Set up Firebase** (See [Firebase Setup](#-firebase-setup) below)

4. **Configure school-specific settings** (See [School Configuration](#-school-configuration) below)

5. **Run the app**
   ```bash
   flutter run
   ```

## 🔥 Firebase Setup

**Important**: This app requires Firebase configuration to function properly. The Firebase configuration file has been excluded from version control for security reasons.

### Step 1: Create Firebase Project

1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project" or "Add project"
3. Enter your project name (e.g., "connect-ed-your-school")
4. Follow the setup wizard

### Step 2: Enable Required Services

In your Firebase project, enable:
- **Authentication** (for user login)
- **Cloud Firestore** (for data storage)
- **Cloud Messaging** (for push notifications)
- **Analytics** (for app insights)
- **Crashlytics** (for error reporting)

### Step 3: Add Apps to Firebase Project

1. **Add Android App**:
   - Package name: `com.example.connect_ed_2` (or your custom package)
   - Download `google-services.json` → place in `android/app/`

2. **Add iOS App**:
   - Bundle ID: `com.example.connectEd2` (or your custom bundle ID)
   - Download `GoogleService-Info.plist` → place in `ios/Runner/`

3. **Add Web App**:
   - App nickname: "Connect-Ed Web"
   - Copy the configuration object

### Step 4: Configure Firebase Options

1. **Copy the template file**:
   ```bash
   cp lib/firebase/firebase_options.dart.template lib/firebase/firebase_options.dart
   ```

2. **Fill in your Firebase configuration**:
   Open `lib/firebase/firebase_options.dart` and replace all placeholder values:

   ```dart
   static const FirebaseOptions web = FirebaseOptions(
     apiKey: 'your-web-api-key-here',
     appId: 'your-web-app-id-here',
     messagingSenderId: 'your-sender-id-here',
     projectId: 'your-project-id-here',
     authDomain: 'your-project-id.firebaseapp.com',
     storageBucket: 'your-project-id.firebasestorage.app',
     measurementId: 'your-measurement-id-here',
   );
   ```

   **Where to find these values**:
   - Go to Firebase Console → Project Settings → General tab
   - Scroll down to "Your apps" section
   - Click on each app (Web, Android, iOS) to see the configuration

### Step 5: FlutterFire CLI (Alternative Method)

You can also use the FlutterFire CLI to automatically configure Firebase:

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase for your project
flutterfire configure
```

This will automatically generate the `firebase_options.dart` file with your configuration.

## 🏫 School Configuration

To customize the app for your school:

### 1. Update School Portal URL

In `lib/frontend/onboarding/setup_link.dart`, line 474:
```dart
..loadRequest(Uri.parse('https://your-school.myschoolapp.com/app/'));
```
Replace `your-school` with your school's portal subdomain.

### 2. Customize Branding

- Replace school logos in the `assets/` folder
- Update app icons in `android/app/src/main/res/` and `ios/Runner/Assets.xcassets/`
- Modify the app name in `android/app/src/main/AndroidManifest.xml` and `ios/Runner/Info.plist`

### 3. Configure Calendar Integration

The app supports webcal feed integration. Configure your school's calendar URL in the appropriate service files.

## 📱 Platform Support

- ✅ **iOS** (iPhone & iPad)
- ✅ **Android** (Phone & Tablet)
- 🚧 **Web** (In development)
- 🚧 **macOS** (Planned)
- 🚧 **Windows** (Planned)

## 🛠️ Development

### Project Structure

```
lib/
├── classes/           # Data models
├── firebase/          # Firebase configuration
├── frontend/          # UI components and screens
│   ├── calendar/      # Calendar-related screens
│   ├── home/          # Home screen and widgets
│   ├── onboarding/    # Setup and welcome screens
│   ├── settings/      # App settings
│   ├── sports/        # Sports events and scores
│   └── setup/         # UI setup and styling
├── requests/          # API and data fetching
└── main.dart          # App entry point
```

### Key Dependencies

- `firebase_core` - Firebase SDK core
- `cloud_firestore` - Database
- `firebase_auth` - Authentication
- `firebase_messaging` - Push notifications
- `cached_network_image` - Image caching
- `shared_preferences` - Local storage
- `http` - HTTP requests
- `intl` - Internationalization

### Building for Release

**Android**:
```bash
flutter build apk --release
# or
flutter build appbundle --release
```

**iOS**:
```bash
flutter build ios --release
```

## 🔒 Security Notes

- Firebase configuration files are excluded from version control
- API keys should never be committed to the repository
- Use Firebase Security Rules to protect your data
- Enable App Check for additional security

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

If you encounter any issues:

1. Check the [Firebase documentation](https://firebase.google.com/docs)
2. Review the [Flutter documentation](https://docs.flutter.dev/)
3. Search existing [GitHub issues](https://github.com/yourusername/connect-ed-2/issues)
4. Create a new issue with detailed information

## 🚀 Roadmap

- [ ] **Widget Integration** - Home screen widgets for quick access
- [ ] **Live Sports Streaming** - Integration with live sports streams
- [ ] **Enhanced Analytics** - Detailed usage and performance metrics
- [ ] **Social Features** - Student groups and messaging
- [ ] **Parent Portal** - Parent access to student information
- [ ] **Multi-language Support** - Internationalization
- [ ] **Dark Mode** - Enhanced dark theme support
- [ ] **Offline Mode** - Cached data access without internet

---

**Made with ❤️ for students everywhere**
