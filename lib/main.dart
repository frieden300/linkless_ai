import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/app_theme.dart';
import 'ui/screens/main_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: LinklessAIApp()));
}

class LinklessAIApp extends StatelessWidget {
  const LinklessAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Linkless AI',
      theme: AppTheme.darkTheme,
      home: const MainScreen(),
    );
  }
}
