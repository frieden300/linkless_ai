import 'dart:io';
import 'package:path/path.dart' as p;

import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:docx_to_text/docx_to_text.dart';
import 'package:excel/excel.dart';
import 'package:epubx/epubx.dart';
import 'package:csv/csv.dart';

class FileExtractionService {
  /// Extracts text from a file based on its extension.
  /// Converts various document formats into raw text for the LLM.
  /// Returns null or an error string if extraction fails.
  /// [maxChars] limits the output size (default 10,000) to fit within
  /// smaller LLM context windows (e.g., 1.7B parameter models).
  static Future<String?> extractText(File file, {int maxChars = 10000}) async {
    try {
      if (!await file.exists()) {
        return "Error: File not found.";
      }

      final extension = p.extension(file.path).toLowerCase();
      String? extractedText;

      switch (extension) {
        case '.pdf':
          extractedText = await _extractPdf(file);
          break;
        case '.docx':
          extractedText = await _extractDocx(file);
          break;
        case '.xlsx':
        case '.xls':
          extractedText = await _extractExcel(file);
          break;
        case '.epub':
          extractedText = await _extractEpub(file);
          break;
        case '.csv':
          extractedText = await _extractCsv(file);
          break;
        case '.txt':
        case '.dart':
        case '.py':
        case '.js':
        case '.ts':
        case '.cpp':
        case '.h':
        case '.hpp':
        case '.c':
        case '.cs':
        case '.java':
        case '.kt':
        case '.sh':
        case '.bash':
        case '.json':
        case '.html':
        case '.xml':
        case '.md':
        case '.yml':
        case '.yaml':
        case '.rb':
        case '.go':
        case '.rs':
        case '.sql':
          extractedText = await _extractPlainText(file);
          break;
        default:
          return "Error: Unsupported file type '$extension'.";
      }

      if (extractedText == null || extractedText.trim().isEmpty) {
        return "Error: No text could be extracted from this file.";
      }

      // Sanitize: remove unpaired surrogates and control chars that break
      // JSON serialisation in llama-server (e.g. lone \uD835 from math PDFs).
      extractedText = _sanitizeText(extractedText);

      // Truncate to save context window space
      if (extractedText.length > maxChars) {
        extractedText = "${extractedText.substring(0, maxChars)}\n...[Text truncated due to length limits]";
      }

      return extractedText;
    } catch (e) {
      return "Error extracting file: ${e.toString()}";
    }
  }

  /// Removes characters that are illegal in JSON strings:
  ///   - Unpaired surrogate code points U+D800..U+DFFF
  ///   - C0 control characters (U+0000..U+001F) except \t, \n, \r
  static String _sanitizeText(String text) {
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final int code = text.codeUnitAt(i);

      // High surrogate
      if (code >= 0xD800 && code <= 0xDBFF) {
        if (i + 1 < text.length) {
          final int next = text.codeUnitAt(i + 1);
          if (next >= 0xDC00 && next <= 0xDFFF) {
            // Valid surrogate pair — write both and skip ahead
            buffer.writeCharCode(code);
            buffer.writeCharCode(next);
            i++;
            continue;
          }
        }
        // Lone high surrogate — drop it
        continue;
      }

      // Lone low surrogate — drop it
      if (code >= 0xDC00 && code <= 0xDFFF) {
        continue;
      }

      // Strip C0 control chars except tab (9), LF (10), CR (13)
      if (code < 0x20 && code != 9 && code != 10 && code != 13) {
        continue;
      }

      buffer.writeCharCode(code);
    }
    return buffer.toString();
  }

  static Future<String?> _extractPdf(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      final String text = PdfTextExtractor(document).extractText();
      document.dispose();
      return text;
    } catch (e) {
      throw Exception("PDF extraction failed: $e");
    }
  }

  static Future<String?> _extractDocx(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final text = docxToText(bytes);
      return text;
    } catch (e) {
      throw Exception("DOCX extraction failed: $e");
    }
  }

  static Future<String?> _extractExcel(File file) async {
    try {
      final bytes = await file.readAsBytes();
      var excel = Excel.decodeBytes(bytes);
      StringBuffer buffer = StringBuffer();

      for (var table in excel.tables.keys) {
        buffer.writeln("Sheet: $table");
        buffer.writeln("-" * 20);
        for (var row in excel.tables[table]!.rows) {
          // Join cells with a pipe | for structural clarity so LLM understands table rows
          final rowText = row.map((cell) => cell?.value?.toString().replaceAll('\n', ' ') ?? "").join(" | ");
          buffer.writeln("| $rowText |");
        }
        buffer.writeln("");
      }
      return buffer.toString();
    } catch (e) {
      throw Exception("Excel extraction failed: $e");
    }
  }

  static Future<String?> _extractEpub(File file) async {
    try {
      final bytes = await file.readAsBytes();
      EpubBook epubBook = await EpubReader.readBook(bytes);
      StringBuffer buffer = StringBuffer();

      // Read text from chapters
      if (epubBook.Chapters != null) {
        for (var chapter in epubBook.Chapters!) {
          buffer.writeln(chapter.HtmlContent ?? "");
        }
      }
      
      // Basic strip html tags for cleaner output
      final cleanText = buffer.toString().replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ');
      return cleanText;
    } catch (e) {
      throw Exception("EPUB extraction failed: $e");
    }
  }

  static Future<String?> _extractCsv(File file) async {
    try {
      final input = await file.readAsString();
      List<List<dynamic>> rowsAsListOfValues = const CsvToListConverter().convert(input);
      StringBuffer buffer = StringBuffer();
      
      for (var row in rowsAsListOfValues) {
        final rowText = row.map((e) => e.toString().replaceAll('\n', ' ')).join(" | ");
        buffer.writeln("| $rowText |");
      }
      return buffer.toString();
    } catch (e) {
      throw Exception("CSV extraction failed: $e");
    }
  }

  static Future<String?> _extractPlainText(File file) async {
    try {
      return await file.readAsString();
    } catch (e) {
      throw Exception("Text reading failed: $e");
    }
  }
}
