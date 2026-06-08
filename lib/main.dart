import 'package:flutter/material.dart';
import 'screens/home_page.dart';

void main() {
  runApp(const EliteCardApp());
}

class EliteCardApp extends StatelessWidget {
  const EliteCardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}