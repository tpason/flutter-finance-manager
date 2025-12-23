import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logarte/logarte.dart';
import 'package:flutter_frontend/src/core/logging/logarte_instance.dart';

class QuoteService {
  final Logarte _logarte = logarte;
  static const String _baseUrl = 'https://www.goodreads.com';

  Future<Quote?> getRandomQuote() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/quotes'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.5',
        },
      ).timeout(const Duration(seconds: 10));

      _logarte.log('Quote API status: ${response.statusCode}');
      
      if (response.statusCode == HttpStatus.ok) {
        final html = response.body;
        final quotes = _parseQuotesFromHtml(html);
        _logarte.log('Parsed ${quotes.length} quotes from Goodreads');
        
        if (quotes.isNotEmpty) {
          // Get random quote from the list
          final randomIndex = DateTime.now().millisecondsSinceEpoch % quotes.length;
          final quote = quotes[randomIndex];
          _logarte.log('Selected quote: "${quote.text}" by ${quote.author}');
          return quote;
        } else {
          _logarte.log('No quotes parsed from HTML');
        }
      } else {
        _logarte.log('API returned status code: ${response.statusCode}');
      }
      return null;
    } catch (e, stackTrace) {
      _logarte.log('Error fetching quote: $e');
      _logarte.log('Stack trace: $stackTrace');
      return null;
    }
  }

  List<Quote> _parseQuotesFromHtml(String html) {
    final quotes = <Quote>[];
    try {
      // Goodreads quotes structure:
      // <div class="quoteText">quote text</div>
      // <span class="authorOrTitle">author name</span>
      
      // Try multiple patterns to match different HTML structures
      // Match quote text and its author inside the same quoteText block
      final quoteBlockPattern = RegExp(
        r'<div class="quoteText"[^>]*>(.*?)<span class="authorOrTitle"[^>]*>(.*?)</span>',
        multiLine: true,
        dotAll: true,
      );

      // First try: Match quote blocks with separate author
      final blockMatches = quoteBlockPattern.allMatches(html);
      for (final match in blockMatches) {
        String quoteText = match.group(1) ?? '';
        String author = match.group(2) ?? '';
        
        if (quoteText.isEmpty || author.isEmpty) continue;
        
        quoteText = _cleanHtmlText(quoteText);
        author = _cleanAuthor(author);
        
        if (quoteText.isNotEmpty && author.isNotEmpty && quoteText.length < 300) {
          quotes.add(Quote(text: quoteText, author: author));
        }
      }

      // Second try: Match quotes with inline author (fallback)
      if (quotes.isEmpty) {
        final inlinePattern = RegExp(
          r'<div class="quoteText"[^>]*>(.*?)</div>',
          multiLine: true,
          dotAll: true,
        );
        
        final inlineMatches = inlinePattern.allMatches(html);
        for (final match in inlineMatches) {
          String content = match.group(1) ?? '';
          if (content.trim().isEmpty) continue;

          content = _cleanHtmlText(content);
          
          // Try to split by em dash, en dash, or regular dash
          final dashPattern = RegExp(r'[—–-]');
          if (dashPattern.hasMatch(content)) {
            final parts = content.split(dashPattern);
            if (parts.length >= 2) {
              String quoteText = parts[0].trim();
              String author = parts.sublist(1).join(' ').trim();
              
              // Remove surrounding quotes
              quoteText = quoteText.replaceAll(RegExp(r'^["""]|["""]$'), '').trim();
              
              if (quoteText.isNotEmpty && author.isNotEmpty && quoteText.length < 300) {
                quotes.add(Quote(text: quoteText, author: author));
              }
            }
          }
        }
      }

      // Third try: Match pattern with authorOrTitle class separately
      if (quotes.isEmpty) {
        final authorPattern = RegExp(
          r'<span class="authorOrTitle"[^>]*>(.*?)</span>',
          multiLine: true,
        );
        
        final quoteTextPattern = RegExp(
          r'<div class="quoteText"[^>]*>(.*?)</div>',
          multiLine: true,
          dotAll: true,
        );
        
        final quoteTexts = quoteTextPattern.allMatches(html).map((m) => _cleanHtmlText(m.group(1) ?? '')).toList();
        final authors = authorPattern.allMatches(html).map((m) => _cleanHtmlText(m.group(1) ?? '')).toList();
        
        final minLength = quoteTexts.length < authors.length ? quoteTexts.length : authors.length;
        for (int i = 0; i < minLength; i++) {
          final quoteText = quoteTexts[i];
          final author = authors[i];
          
          if (quoteText.isNotEmpty && author.isNotEmpty && quoteText.length < 300) {
            quotes.add(Quote(text: quoteText, author: author));
          }
        }
      }
      
    } catch (e, stackTrace) {
      _logarte.log('Error parsing quotes: $e');
      _logarte.log('Stack trace: $stackTrace');
    }
    return quotes;
  }

  String _cleanHtmlText(String text) {
    return text
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll('&ldquo;', '"')
        .replaceAll('&rdquo;', '"')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&#8213;', '')
        .replaceAll('"', '')
        .replaceAll('&apos;', "'")
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
  }

  String _cleanAuthor(String text) {
    var author = _cleanHtmlText(text);
    // Strip leading dashes/em dashes and trailing metadata like book titles
    author = author.replaceAll(RegExp(r'^[—–-]\s*'), '');
    author = author.split(RegExp(r',|\(|\[')).first.trim();
    return author;
  }
}

class Quote {
  final String text;
  final String author;

  const Quote({
    required this.text,
    required this.author,
  });
}

