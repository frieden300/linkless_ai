class TokenEstimator {
  /// Estimates token count for a given text or message.
  /// Uses approximation: 1 token ≈ 4 characters
  static int estimate(String text) {
    return text.length ~/ 4;
  }

  /// Estimates total tokens from a list of messages (api format)
  static int estimateMessages(List<Map<String, dynamic>> messages) {
    int total = 0;
    for (final message in messages) {
      final content = message['content'];
      if (content is String) {
        total += estimate(content);
      } else if (content is List) {
        for (final block in content) {
          if (block['type'] == 'text') {
            total += estimate(block['text'] as String);
          } else if (block['type'] == 'image_url') {
            total += 512; // Typical vision model penalty
          }
        }
      }
      
      // Also check for raw image paths in our internal format
      final imagePaths = message['image_paths'] as List?;
      if (imagePaths != null) {
        total += (imagePaths.length * 512);
      }
    }
    return total;
  }
}
