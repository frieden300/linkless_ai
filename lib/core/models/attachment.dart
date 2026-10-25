/// Represents a file attached to a chat message.
enum AttachmentType { image, document }

class Attachment {
  final String filePath;
  final AttachmentType type;
  final String? extractedText; // For documents: text extracted from PDF/TXT
  final String? fileName; // Display name
  final bool isExtracting;

  const Attachment({
    required this.filePath,
    required this.type,
    this.extractedText,
    this.fileName,
    this.isExtracting = false,
  });

  Attachment copyWith({
    String? extractedText,
    bool? isExtracting,
  }) {
    return Attachment(
      filePath: filePath,
      type: type,
      fileName: fileName,
      extractedText: extractedText ?? this.extractedText,
      isExtracting: isExtracting ?? this.isExtracting,
    );
  }

  /// Whether this attachment is an image that needs vision model.
  bool get isImage => type == AttachmentType.image;

  /// Whether this attachment is a document for text extraction.
  bool get isDocument => type == AttachmentType.document;

  /// Display-friendly file name.
  String get displayName {
    if (fileName != null) return fileName!;
    return filePath.split(RegExp(r'[/\\]')).last;
  }
}
