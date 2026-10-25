import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/models/attachment.dart';
import '../utils/attachment_utils.dart';

/// Horizontally scrollable row of file/image attachment thumbnails
/// with animated entry/exit and a remove (×) button on each chip.
class FilePreviewBar extends StatelessWidget {
  final List<Attachment> attachments;
  final void Function(int index) onRemove;

  const FilePreviewBar({
    super.key,
    required this.attachments,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      alignment: Alignment.bottomCenter,
      child: attachments.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: attachments.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final a = attachments[index];
                    return _AttachmentTile(
                      attachment: a,
                      onRemove: () => onRemove(index),
                    );
                  },
                ),
              ),
            ),
    );
  }
}

class _AttachmentTile extends StatefulWidget {
  final Attachment attachment;
  final VoidCallback onRemove;

  const _AttachmentTile({required this.attachment, required this.onRemove});

  @override
  State<_AttachmentTile> createState() => _AttachmentTileState();
}

class _AttachmentTileState extends State<_AttachmentTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.attachment;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main tile
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: a.isImage
                ? _ImageTile(filePath: a.filePath)
                : _DocTile(attachment: a),
          ),

          // Hover overlay (×)
          if (_hovering)
            Positioned.fill(
              child: GestureDetector(
                onTap: widget.onRemove,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    // Add the same border to ensure perfect alignment
                    border: Border.all(color: Colors.transparent, width: 1),
                  ),
                  child: const Center(
                    child: Icon(Icons.close, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  final String filePath;

  const _ImageTile({required this.filePath});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        File(filePath),
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.broken_image, color: Colors.white54),
        ),
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  final Attachment attachment;

  const _DocTile({required this.attachment});

  @override
  Widget build(BuildContext context) {
    final style = AttachmentStyle.getFromFileName(attachment.displayName);

    return Container(
      width: 150, // Slightly wider for better text layout
      height: 80,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: attachment.isExtracting
              ? style.baseColor.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Icon Box Section
          if (attachment.isExtracting)
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: style.baseColor,
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: style.baseColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(style.icon, color: style.baseColor, size: 20),
            ),
          const SizedBox(width: 10),

          // Info Section
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  attachment.isExtracting ? 'Extracting...' : style.label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
