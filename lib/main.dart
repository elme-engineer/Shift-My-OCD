import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Enable offline persistence (already on by default for mobile, but explicit is fine)
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Skip auth flow for the demo
  await FirebaseAuth.instance.signInAnonymously();

  runApp(const ShiftMyOcdApp());
}

class ShiftMyOcdApp extends StatelessWidget {
  const ShiftMyOcdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shift My OCD',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: const _DebugHome(),
    );
  }
}

// Temporary screen to verify Firestore is connected — delete after confirming
class _DebugHome extends StatelessWidget {
  const _DebugHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shift My OCD')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await FirebaseFirestore.instance.collection('debug').add({
              'hello': 'world',
              'at': FieldValue.serverTimestamp(),
            });
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Wrote to Firestore ✓')),
              );
            }
          },
          child: const Text('Test Firestore'),
        ),
      ),
    );
  }
}