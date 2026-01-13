import 'package:flutter/material.dart';
import 'app.dart';

Future<void> main() async {
  // Stellt sicher, dass die Flutter-Engine bereit ist
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const CreateToPdfApp());
}