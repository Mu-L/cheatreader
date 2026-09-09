import 'package:cheatreader/src/reader_text_wrapper.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final wrapper = ReaderTextWrapper();
  List<String> wrap(
    String text, {
    bool punctuation = true,
    double width = 180,
  }) {
    return wrapper.wrap(
      text: text,
      maxWidth: width,
      style: const TextStyle(fontSize: 16),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      preferPunctuationLineBreaks: punctuation,
    );
  }

  test('punctuation wrapping preserves every character across boundaries', () {
    for (final text in [
      'First, this sentence includes punctuation. Next sentence! ' * 40,
      '甲乙丙丁戊，己庚辛壬癸子丑寅卯辰巳午未申酉戌亥。' * 40,
      'unbreakableEnglishWord' * 40,
      ' leading and trailing spaces ',
    ]) {
      for (final punctuation in [true, false]) {
        final segments = wrap(text, punctuation: punctuation);
        expect(segments.join(), text);
        for (final segment in segments) {
          final painter = TextPainter(
            text: TextSpan(text: segment, style: const TextStyle(fontSize: 16)),
            textDirection: TextDirection.ltr,
          )..layout();
          expect(painter.width, lessThanOrEqualTo(180));
          painter.dispose();
        }
      }
    }
  });

  test('does not split surrogate pairs or combined characters', () {
    final text = 'a\u0301\u{1F642}' * 20;
    final segments = wrap(text, width: 18);
    expect(segments.join(), text);
    expect(
      segments.every((segment) => text.characters.contains(segment)),
      isTrue,
    );
  });

  test('long paragraphs are cached and cache invalidates for width', () {
    final text = 'x' * 100000;
    final timer = Stopwatch()..start();
    final segments = wrap(text);
    final elapsed = timer.elapsedMilliseconds;
    expect(segments.join(), text);
    expect(identical(wrap(text), segments), isTrue);
    expect(wrap(text, width: 300).length, lessThan(segments.length));
    // This generous limit catches the former quadratic implementation.
    expect(elapsed, lessThan(10000));
    // ignore: avoid_print
    print('100000-character wrapping: ${elapsed}ms; repeat uses cached result');
  });
}
