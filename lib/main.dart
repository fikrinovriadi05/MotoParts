import 'package:flutter/material.dart';
import 'package:motopart/app.dart';
import 'package:motopart/store/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await store.attach(await SharedPreferences.getInstance());
  runApp(const MotoPartApp());
}
