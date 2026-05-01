import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/lifecycle_observer.dart';
import 'core/theme.dart';
import 'features/home/home_screen.dart';
import 'firebase_options.dart';
import 'services/analytics_service.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Firebase + offline persistence (default-on, but explicit is fine).
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  // 2. Make sure we have an (anonymous) UID before any service runs.
  final auth = AuthService();
  await auth.ensureSignedIn();

  // 3. Wire up app-open tracking. Cold start counts immediately;
  //    foreground resumes are caught by the binding observer.
  final analytics = AnalyticsService();
  final lifecycle = LifecycleObserver(analytics);
  WidgetsBinding.instance.addObserver(lifecycle);
  await lifecycle.logInitialOpen();

  runApp(const ShiftMyOcdApp());
}

class ShiftMyOcdApp extends StatelessWidget {
  const ShiftMyOcdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shift My OCD',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const HomeScreen(),
    );
  }
}