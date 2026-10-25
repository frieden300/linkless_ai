import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:linkless_ai/core/app_theme.dart';
import '../../providers/chat_provider.dart';
import '../../providers/folder_provider.dart';
import '../widgets/server_status_badge.dart';
import '../screens/settings_screen.dart';

class Sidebar extends ConsumerStatefulWidget {
  const Sidebar({super.key});

  @override
  ConsumerState<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends ConsumerState<Sidebar> {
  final Set<String> _expandedFolders = {};

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final folderState = ref.watch(folderProvider);

    // Group chats by folder
    final Map<String?, List<dynamic>> groupedChats = {};
    for (var conv in chatState.allConversations) {
      groupedChats.putIfAbsent(conv.folderId, () => []).add(conv);
    }

    return Theme(
      data: Theme.of(context).copyWith(
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: Builder(
        builder: (context) {
          return Container(
            width: 280,
            color: AppTheme.sidebarBackground,
            child: Column(
              children: [
                // App Logo & Name
                _buildHeader(context),

                // New Chat & Temp Chat Buttons
                _buildActionButtons(context, ref),

                const SizedBox(height: 20),

                // Folders and Chats List
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _buildSectionHeader(context, "CHATS"),

                      // Chats without folders
                      if (groupedChats.containsKey(null))
                        ...groupedChats[null]!.map(
                          (conv) => _buildChatTile(context, ref, conv),
                        ),

                      const SizedBox(height: 12),
                      _buildSectionHeader(
                        context,
                        "FOLDERS",
                        onAdd: () => _showNewFolderDialog(context, ref),
                      ),

                      // Folders
                      ...folderState.folders.map((folder) {
                        final chatsInFolder = groupedChats[folder.id] ?? [];
                        final isExpanded = _expandedFolders.contains(folder.id);

                        return _buildFolderTile(
                          context,
                          ref,
                          folder,
                          chatsInFolder,
                          isExpanded,
                        );
                      }),
                    ],
                  ),
                ),

                // Settings Section (Bottom)
                _buildBottomSection(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.psychology,
              color: AppTheme.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "LINKLESS AI",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                letterSpacing: -0.3,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 6),
          const ServerStatusBadge(),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => ref.read(chatProvider.notifier).createNewChat(),
              icon: const Icon(Icons.add, color: Colors.white, size: 18),
              label: const Text(
                "New Chat",
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Ghost Chat Button (Temporary Chat)
          Tooltip(
            message: 'Temporary Chat (Ghost Mode)',
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.auto_fix_high_rounded,
                  color: Colors.purpleAccent,
                  size: 20,
                ),
                onPressed: () => ref
                    .read(chatProvider.notifier)
                    .createNewChat(isTemporary: true),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title, {
    VoidCallback? onAdd,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: AppTheme.textSecondary,
            ),
          ),
          if (onAdd != null)
            IconButton(
              onPressed: onAdd,
              icon: const Icon(
                Icons.add,
                size: 16,
                color: AppTheme.textSecondary,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Widget _buildChatTile(BuildContext context, WidgetRef ref, dynamic conv) {
    final chatState = ref.watch(chatProvider);
    final isSelected = conv.id == chatState.currentConversationId;
    final isTemp = conv.id.startsWith('temp-');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: GestureDetector(
        onSecondaryTapDown: (details) =>
            _showChatContextMenu(context, ref, conv, details.globalPosition),
        child: Material(
          color: Colors.transparent,
          child: ListTile(
            onTap: () =>
                ref.read(chatProvider.notifier).selectConversation(conv.id),
            selected: isSelected,
            dense: true,
            selectedTileColor: AppTheme.primary.withValues(alpha: 0.12),
            hoverColor: Colors.white.withValues(alpha: 0.05),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            leading: Icon(
              isTemp
                  ? Icons.auto_fix_high_rounded
                  : Icons.chat_bubble_outline_rounded,
              size: 16,
              color: isTemp ? Colors.purpleAccent : AppTheme.textSecondary,
            ),
            title: Text(
              conv.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFolderTile(
    BuildContext context,
    WidgetRef ref,
    dynamic folder,
    List<dynamic> chats,
    bool isExpanded,
  ) {
    return Column(
      children: [
        GestureDetector(
          onSecondaryTapDown: (details) => _showFolderContextMenu(
            context,
            ref,
            folder,
            details.globalPosition,
          ),
          child: ListTile(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedFolders.remove(folder.id);
                } else {
                  _expandedFolders.add(folder.id);
                }
              });
            },
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: Icon(
              isExpanded ? Icons.folder_open_rounded : Icons.folder_rounded,
              size: 18,
              color: AppTheme.secondary.withValues(alpha: 0.15),
            ),
            title: Text(
              folder.name,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            trailing: Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              size: 16,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Column(
              children: chats
                  .map((conv) => _buildChatTile(context, ref, conv))
                  .toList(),
            ),
          ),
      ],
    );
  }

  void _showChatContextMenu(
    BuildContext context,
    WidgetRef ref,
    dynamic conv,
    Offset position,
  ) async {
    final folderState = ref.read(folderProvider);

    final RelativeRect positionRect = RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      position.dx + 1.0,
      position.dy + 1.0,
    );

    await showMenu<dynamic>(
      context: context,
      position: positionRect,
      color: AppTheme.surface.withValues(alpha: 0.98),
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      items: <PopupMenuEntry<dynamic>>[
        PopupMenuItem(
          padding: EdgeInsets.zero,
          child: const _ContextMenuItem(
            icon: Icons.edit_outlined,
            text: "Rename",
          ),
          onTap: () {
            Future.delayed(
              Duration.zero,
              () {
                if (context.mounted) {
                  _showRenameChatDialog(context, ref, conv);
                }
              },
            );
          },
        ),
        PopupMenuItem(
          padding: EdgeInsets.zero,
          child: const _ContextMenuItem(
            icon: Icons.delete_outline,
            text: "Delete",
            color: Colors.redAccent,
          ),
          onTap: () =>
              ref.read(chatProvider.notifier).deleteConversation(conv.id),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          enabled: false,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              "MOVE TO FOLDER",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        ...folderState.folders.where((f) => f.id != conv.folderId).map(
          (folder) => PopupMenuItem(
            padding: EdgeInsets.zero,
            child: _ContextMenuItem(
              icon: Icons.folder_outlined,
              text: folder.name,
            ),
            onTap: () => ref
                .read(chatProvider.notifier)
                .moveToFolder(conv.id, folder.id),
          ),
        ),
        if (conv.folderId != null)
          PopupMenuItem(
            padding: EdgeInsets.zero,
            child: const _ContextMenuItem(
              icon: Icons.remove_circle_outline,
              text: "Remove from folder",
            ),
            onTap: () =>
                ref.read(chatProvider.notifier).moveToFolder(conv.id, null),
          ),
      ],
    );
  }

  void _showFolderContextMenu(
    BuildContext context,
    WidgetRef ref,
    dynamic folder,
    Offset position,
  ) async {
    final RelativeRect positionRect = RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      position.dx + 1.0,
      position.dy + 1.0,
    );

    await showMenu<dynamic>(
      context: context,
      position: positionRect,
      color: AppTheme.surface.withValues(alpha: 0.98),
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      items: <PopupMenuEntry<dynamic>>[
        PopupMenuItem(
          padding: EdgeInsets.zero,
          child: const _ContextMenuItem(
            icon: Icons.edit_outlined,
            text: "Rename Folder",
          ),
          onTap: () {
            Future.delayed(
              Duration.zero,
              () {
                if (context.mounted) {
                  _showRenameFolderDialog(context, ref, folder);
                }
              },
            );
          },
        ),
        PopupMenuItem(
          padding: EdgeInsets.zero,
          child: const _ContextMenuItem(
            icon: Icons.delete_outline,
            text: "Delete Folder",
            color: Colors.redAccent,
          ),
          onTap: () =>
              ref.read(folderProvider.notifier).deleteFolder(folder.id),
        ),
      ],
    );
  }

  Widget _buildBottomSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: ListTile(
        leading: const Icon(
          Icons.settings_outlined,
          color: AppTheme.textSecondary,
        ),
        title: const Text(
          "Settings",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        onTap: () {
          showDialog(context: context, builder: (_) => const SettingsDialog());
        },
      ),
    );
  }

  // Dialogs
  void _showNewFolderDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();

    void submit() {
      if (controller.text.isNotEmpty) {
        ref.read(folderProvider.notifier).createFolder(controller.text);
      }
      Navigator.pop(context);
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text("New Folder", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          onSubmitted: (_) => submit(),
          decoration: const InputDecoration(
            hintText: "Enter folder name",
            hintStyle: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: submit,
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  void _showRenameChatDialog(
    BuildContext context,
    WidgetRef ref,
    dynamic conv,
  ) {
    final controller = TextEditingController(text: conv.title);
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );

    void submit() {
      if (controller.text.isNotEmpty) {
        ref
            .read(chatProvider.notifier)
            .renameConversation(conv.id, controller.text);
      }
      Navigator.pop(context);
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text("Rename Chat", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          onSubmitted: (_) => submit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: submit,
            child: const Text("Rename"),
          ),
        ],
      ),
    );
  }

  void _showRenameFolderDialog(
    BuildContext context,
    WidgetRef ref,
    dynamic folder,
  ) {
    final controller = TextEditingController(text: folder.name);
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );

    void submit() {
      if (controller.text.isNotEmpty) {
        ref
            .read(folderProvider.notifier)
            .renameFolder(folder.id, controller.text);
      }
      Navigator.pop(context);
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          "Rename Folder",
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          onSubmitted: (_) => submit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: submit,
            child: const Text("Rename"),
          ),
        ],
      ),
    );
  }
}

class _ContextMenuItem extends StatefulWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _ContextMenuItem({required this.icon, required this.text, this.color});

  @override
  State<_ContextMenuItem> createState() => _ContextMenuItemState();
}

class _ContextMenuItemState extends State<_ContextMenuItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _isHovered
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _isHovered
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 150),
              scale: _isHovered ? 1.1 : 1.0,
              child: Icon(
                widget.icon,
                size: 18,
                color:
                    widget.color ??
                    (_isHovered ? Colors.white : Colors.white70),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.text,
                style: TextStyle(
                  color:
                      widget.color ??
                      (_isHovered ? Colors.white : Colors.white),
                  fontSize: 13,
                  fontWeight: _isHovered ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
