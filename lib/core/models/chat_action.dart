import 'package:flutter/material.dart';

class ChatAction {
  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;

  const ChatAction({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

const List<ChatAction> defaultChatActions = [
  ChatAction(
    id: 'web_search',
    icon: Icons.search,
    label: 'Web Search',
    subtitle: 'Search the web',
    color: Color(0xFF4ECDC4),
  ),
  ChatAction(
    id: 'upload_document',
    icon: Icons.upload_file,
    label: 'Upload Document',
    subtitle: 'Analyze files',
    color: Color(0xFFFF6B6B),
  ),
  ChatAction(
    id: 'upload_image',
    icon: Icons.add_photo_alternate_outlined,
    label: 'Upload Image',
    subtitle: 'Analyze with vision',
    color: Color(0xFFB388FF),
  ),
  ChatAction(
    id: 'generate_code',
    icon: Icons.code,
    label: 'Generate Code',
    subtitle: 'Create code snippets',
    color: Color(0xFF00D9FF),
  ),
  ChatAction(
    id: 'deep_research',
    icon: Icons.lightbulb_outline,
    label: 'Deep Research',
    subtitle: 'In-depth analysis',
    color: Color(0xFFFFBE0B),
  ),
  ChatAction(
    id: 'write_report',
    icon: Icons.description_outlined,
    label: 'Write Report',
    subtitle: 'Draft documents',
    color: Color(0xFF26DE81),
  ),
];
