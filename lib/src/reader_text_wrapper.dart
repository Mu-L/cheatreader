import 'dart:math' as math;

import 'package:flutter/widgets.dart';

class ReaderTextWrapper {
  final _cache =
      <
        (String, double, TextStyle, TextDirection, TextScaler, bool),
        List<String>
      >{};

  List<String> wrap({
    required String text,
    required double maxWidth,
    required TextStyle style,
    required TextDirection textDirection,
    required TextScaler textScaler,
    required bool preferPunctuationLineBreaks,
  }) {
    if (text.isEmpty || maxWidth <= 0) return [text];
    final key = (
      text,
      maxWidth,
      style,
      textDirection,
      textScaler,
      preferPunctuationLineBreaks,
    );
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached;
      return cached;
    }

    final boundaries = <int>[0];
    for (final character in text.characters) {
      boundaries.add(boundaries.last + character.length);
    }
    final painter = TextPainter(
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: 1,
    );
    final segments = <String>[];
    try {
      var start = 0;
      final count = boundaries.length - 1;
      while (start < count) {
        bool fits(int end) {
          painter.text = TextSpan(
            text: text.substring(boundaries[start], boundaries[end]),
            style: style,
          );
          painter.layout();
          return !painter.didExceedMaxLines && painter.width <= maxWidth;
        }

        // Bound each measurement to a visual line, never half of the remaining
        // paragraph. Exponential search also handles unusually narrow glyphs.
        var best = start + 1;
        var high = math.min(count, start + 2);
        while (fits(high)) {
          best = high;
          if (high == count) break;
          high = math.min(count, start + (high - start) * 2);
        }
        var low = best + 1;
        high -= 1;
        while (low <= high) {
          final middle = (low + high) ~/ 2;
          if (fits(middle)) {
            best = middle;
            low = middle + 1;
          } else {
            high = middle - 1;
          }
        }
        if (preferPunctuationLineBreaks) {
          for (var end = best; end > start && best - end <= 16; end--) {
            if (_punctuation.contains(text.codeUnitAt(boundaries[end] - 1))) {
              best = end;
              break;
            }
          }
        }
        segments.add(text.substring(boundaries[start], boundaries[best]));
        start = best;
      }
    } finally {
      painter.dispose();
    }
    final result = List<String>.unmodifiable(segments);
    if (_cache.length >= 16) _cache.remove(_cache.keys.first);
    _cache[key] = result;
    return result;
  }

  static const _punctuation = {
    0x20,
    0x09,
    0x3000,
    0x3001,
    0x3002,
    0xFF0C,
    0xFF01,
    0xFF1F,
    0xFF1A,
    0xFF1B,
    0x2014,
    0x2026,
    0xFF09,
    0x002C,
    0x002E,
    0x003A,
    0x003B,
    0x003F,
    0x0021,
    0x0029,
  };
}
