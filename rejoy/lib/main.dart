import 'package:flutter/material.dart';

import 'src/core/api_config.dart';
import 'src/core/auth_session.dart';
import 'src/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.initialize();
  await AuthSession.initialize();
  runApp(const ReJoyApp());
}
