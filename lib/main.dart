import 'package:flutter/material.dart';
import 'package:motopart/app.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/store/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await store.attach(prefs);
  await auth.attach(prefs); // setelah store: memulihkan sesi login
  runApp(const MotoPartApp());
}
