import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

class AttachmentStyle {
  final Color baseColor;
  final IconData icon;
  final String label;

  const AttachmentStyle({
    required this.baseColor,
    required this.icon,
    required this.label,
  });

  static AttachmentStyle getFromFileName(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    
    switch (ext) {
      case 'pdf':
        return const AttachmentStyle(
          baseColor: Colors.redAccent,
          icon: Icons.picture_as_pdf_rounded,
          label: 'PDF',
        );
      case 'xlsx':
      case 'xls':
      case 'csv':
        return const AttachmentStyle(
          baseColor: Colors.greenAccent,
          icon: Icons.table_chart_rounded,
          label: 'Spreadsheet',
        );
      case 'docx':
      case 'doc':
        return const AttachmentStyle(
          baseColor: Colors.blueAccent,
          icon: Icons.description_rounded,
          label: 'Document',
        );
      case 'epub':
        return const AttachmentStyle(
          baseColor: Colors.orangeAccent,
          icon: Icons.menu_book_rounded,
          label: 'E-Book',
        );
      case 'txt':
        return const AttachmentStyle(
          baseColor: Colors.blueGrey,
          icon: Icons.article_rounded,
          label: 'Plain Text',
        );
      case 'dart':
      case 'py':
      case 'js':
      case 'ts':
      case 'cpp':
      case 'h':
      case 'hpp':
      case 'c':
      case 'cs':
      case 'java':
      case 'kt':
      case 'sh':
      case 'bash':
      case 'yml':
      case 'yaml':
      case 'rb':
      case 'go':
      case 'rs':
      case 'sql':
      case 'json':
      case 'html':
      case 'css':
      case 'md':
      case 'xml':
        return const AttachmentStyle(
          baseColor: Color(0xFFA29BFE), // Purple-ish
          icon: Icons.code_rounded,
          label: 'Source Code',
        );
      default:
        return AttachmentStyle(
          baseColor: AppTheme.primary,
          icon: Icons.insert_drive_file_rounded,
          label: ext.toUpperCase(),
        );
    }
  }
}
