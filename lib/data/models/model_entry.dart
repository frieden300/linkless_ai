import 'dart:io';
import 'package:path/path.dart' as path;

class ModelEntry {
  final String id;
  final String name;
  final String filePath;
  final String? sizeParam;
  final String? quantization;
  final int? fileSizeMb;
  final String? modelFamily;
  final String storageType;
  final int contextLength;
  final DateTime createdAt;

  ModelEntry({
    required this.id,
    required this.name,
    required this.filePath,
    this.sizeParam,
    this.quantization,
    this.fileSizeMb,
    this.modelFamily,
    this.storageType = 'External',
    this.contextLength = 4096,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Auto-extract metadata from filename
  factory ModelEntry.fromFilePath(String filePath, String id) {
    final filename = path.basename(filePath).replaceAll('.gguf', '');

    // Extract quantization
    String? quantization;
    if (filename.contains('Q4_K_M')) {
      quantization = 'Q4_K_M';
    } else if (filename.contains('Q8_0')) {
      quantization = 'Q8_0';
    } else if (filename.contains('Q5_K_M')) {
      quantization = 'Q5_K_M';
    }

    // Extract model family
    String? family;
    if (filename.toLowerCase().contains('phi')) {
      family = 'Phi';
    } else if (filename.toLowerCase().contains('llama')) {
      family = 'Llama';
    } else if (filename.toLowerCase().contains('qwen')) {
      family = 'Qwen';
    }

    // Extract size parameter
    String? sizeParam;
    final sizeMatch = RegExp(
      r'(\d+\.?\d*[BM]|mini)',
      caseSensitive: false,
    ).firstMatch(filename);
    if (sizeMatch != null) {
      sizeParam = sizeMatch.group(1);
    }

    // Try to get file size
    int? fileSizeMb;
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        fileSizeMb = (file.lengthSync() / (1024 * 1024)).round();
      }
    } catch (e) {
      // Ignore file size errors
    }

    return ModelEntry(
      id: id,
      name: filename,
      filePath: filePath,
      quantization: quantization,
      modelFamily: family,
      sizeParam: sizeParam,
      fileSizeMb: fileSizeMb,
      storageType: 'External',
      contextLength: 131072, // Default high context
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'file_path': filePath,
      'size_param': sizeParam,
      'quantization': quantization,
      'file_size_mb': fileSizeMb,
      'model_family': modelFamily,
      'storage_type': storageType,
      'context_length': contextLength,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory ModelEntry.fromMap(Map<String, dynamic> map) {
    return ModelEntry(
      id: map['id'] as String,
      name: map['name'] as String,
      filePath: map['file_path'] as String,
      sizeParam: map['size_param'] as String?,
      quantization: map['quantization'] as String?,
      fileSizeMb: map['file_size_mb'] as int?,
      modelFamily: map['model_family'] as String?,
      storageType: map['storage_type'] as String? ?? 'External',
      contextLength: map['context_length'] as int? ?? 4096,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  ModelEntry copyWith({
    String? id,
    String? name,
    String? filePath,
    String? sizeParam,
    String? quantization,
    int? fileSizeMb,
    String? modelFamily,
    String? storageType,
    int? contextLength,
    DateTime? createdAt,
  }) {
    return ModelEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      filePath: filePath ?? this.filePath,
      sizeParam: sizeParam ?? this.sizeParam,
      quantization: quantization ?? this.quantization,
      fileSizeMb: fileSizeMb ?? this.fileSizeMb,
      modelFamily: modelFamily ?? this.modelFamily,
      storageType: storageType ?? this.storageType,
      contextLength: contextLength ?? this.contextLength,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
