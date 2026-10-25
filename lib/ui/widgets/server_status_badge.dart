import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glass_kit/glass_kit.dart';
import '../../core/app_theme.dart';
import '../../providers/server_provider.dart';

class ServerStatusBadge extends ConsumerWidget {
  const ServerStatusBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverState = ref.watch(serverProvider);

    Color color;
    String label;
    IconData icon;

    switch (serverState.status) {
      case ServerStatus.online:
        color = AppTheme.accent;
        label = "Online";
        icon = Icons.check_circle;
        break;
      case ServerStatus.starting:
      case ServerStatus.loading:
      case ServerStatus.stopping:
        color = Colors.orange;
        label = serverState.status == ServerStatus.stopping
            ? "Stopping..."
            : "Starting...";
        icon = Icons.sync;
        break;
      case ServerStatus.error:
        color = Colors.red;
        label = "Error";
        icon = Icons.error;
        break;
      case ServerStatus.offline:
        color = AppTheme.textSecondary;
        label = "Offline";
        icon = Icons.cloud_off;
        break;
    }

    return GlassContainer.frostedGlass(
      height: 28, // Slightly shorter for sidebar
      width: 88, // Narrower to fit sidebar header
      blur: 10,
      frostedOpacity: 0.1,
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(16),
      borderWidth: 0.5,
      borderColor: Colors.white.withValues(alpha: 0.1),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
