import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/server_provider.dart';

import '../widgets/sidebar.dart';
import '../widgets/chat_area.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    // Listen for app exit to stop server
    _listener = AppLifecycleListener(
      onDetach: () {
        debugPrint('App Event: onDetach');
        ref.read(serverProvider.notifier).stopServerImmediate();
      },
      onExitRequested: () async {
        debugPrint('App Event: onExitRequested');
        ref.read(serverProvider.notifier).stopServerImmediate();
        await Future.delayed(const Duration(milliseconds: 300));
        return AppExitResponse.exit;
      },
    );
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background - Mesh Gradient or simple deep color
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF1E1E3F),
                  Color(0xFF0F172A),
                ],
              ),
            ),
          ),

          // Main Content Layout
          Row(
            children: [
              // Sidebar
              Sidebar(),

              // Vertical Divider
              Container(width: 1, color: Colors.white.withValues(alpha: 0.05)),

              // Chat Area
              Expanded(child: ChatArea()),
            ],
          ),
        ],
      ),
    );
  }
}
