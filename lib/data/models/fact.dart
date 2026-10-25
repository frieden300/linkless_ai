class Fact {
  final String id;
  final String key;
  final String value;
  final String source; // 'manual' or 'auto'
  final double confidence;
  final DateTime createdAt;
  final DateTime updatedAt;

  Fact({
    required this.id,
    required this.key,
    required this.value,
    this.source = 'manual',
    this.confidence = 1.0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fact_key': key,
      'fact_value': value,
      'source': source,
      'confidence': confidence,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Fact.fromMap(Map<String, dynamic> map) {
    return Fact(
      id: map['id'],
      key: map['fact_key'],
      value: map['fact_value'],
      source: map['source'] ?? 'manual',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 1.0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
    );
  }

  Fact copyWith({
    String? id,
    String? key,
    String? value,
    String? source,
    double? confidence,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Fact(
      id: id ?? this.id,
      key: key ?? this.key,
      value: value ?? this.value,
      source: source ?? this.source,
      confidence: confidence ?? this.confidence,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
