import 'dart:convert';

import 'package:copiando_package_codigo/span_parser.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// import 'textspan_controller.dart';
// import 'package:copiando_package_codigo/grammars/';

const _bracketStyles = <TextStyle>[
  TextStyle(color: Color(0xFF5caeef)),
  TextStyle(color: Color(0xFFdfb976)),
  TextStyle(color: Color(0xFFc172d9)),
  TextStyle(color: Color(0xFF4fb1bc)),
  TextStyle(color: Color(0xFF97c26c)),
  TextStyle(color: Color(0xFFabb2c0)),
];

// const _failedBracketStyle = TextStyle(color: Color(0xFFff0000));
const _failedBracketStyle = TextStyle(color: Color(0xFF5caeef));

const _defaultLightThemeFiles = [
  'lib/themes/light_vs.json',
  'lib/themes/light_plus.json',
];

const _defaultDarkThemeFiles = [
  'lib/themes/dark_vs.json',
  'lib/themes/dark_plus.json',
];

/// The [Highlighter] class can format a String of code and add syntax
/// highlighting in the form of a [TextSpan]. Currrently supports Dart and
/// YAML. Formatting style is similar to VS Code.
class Highlighter {
  static final _cache = <String, Grammar>{};

  /// Creates a [Highlighter] for the given [language] and [theme]. The
  /// [language] must be one of the languages supported by this package,
  /// unless it has been manually added. Before creating a [Highlighter],
  /// you must call [initialize] with a list of languages to load.
  Highlighter({
    required this.language,
    required this.theme,
  }) {
    _grammar = _cache[language]!;
  }

  /// Initializes the [Highlighter] with the given list of [languages]. This
  /// must be called before creating any [Highlighter]s. Supported languages
  /// are 'dart' and 'yaml'.
  static Future<void> initialize(List<String> languages) async {
    for (var language in languages) {
      var json = await rootBundle.loadString(
        'lib/grammars/$language.json',
      );
      _cache[language] = Grammar.fromJson(jsonDecode(json));
    }
  }

  /// Adds a custom language to the list of languages.
  /// Associates a language [name] with a TextMate formatted [json] definition.
  /// This must be called before creating any [Highlighter]s.
  static void addLanguage(String name, String json) {
    _cache.putIfAbsent(name, () => Grammar.fromJson(jsonDecode(json)));
  }

  /// The language of this [Highlighter].
  final String language;

  late final Grammar _grammar;

  /// The [HighlighterTheme] used to style the code.
  final HighlighterTheme theme;

  /// Formats the given [code] and returns a [TextSpan] with syntax
  /// highlighting.
  TextSpan obtenerPosiciones(String code) {
    var textSpans = <InlineSpan>[];

    int indiceInicial = 0;

    List<Palabra> palabras = [
      // Palabra(0, 3),
      // Palabra(5, 8),
      // Palabra(21, 24),
    ];
    for (var palabra in palabras) {
      // Añadir texto normal antes de la palabra
      textSpans.add(
        highlight(code.substring(indiceInicial, palabra.inicio)),
      );

      textSpans.add(
        WidgetSpan(
          child: IntrinsicWidth(
            child: TextField(
              textAlign: TextAlign.center,
              controller: TextEditingController(
                text: code.substring(palabra.inicio, palabra.fin + 1),
              ),
              style: TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                // contentPadding: EdgeInsets.only(left: 10, right: 10),
                // isCollapsed: true,
                // isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ),
      );

      // textSpans.add(TextSpan(
      //   text: code.substring(palabra.inicio, palabra.fin + 1),
      //   style: TextStyle(color: Colors.blue),
      // ));
      indiceInicial = palabra.fin + 1;
    }
    textSpans.add(
      highlight(
        code.substring(indiceInicial),
      ),
    );

    return TextSpan(children: textSpans, style: theme._wrapper);
  }

  TextSpan highlight(String code) {
    var spans = SpanParser.parse(_grammar, code);
    var textSpans = <InlineSpan>[];
    var bracketCounter = 0;

    int charPos = 0;
    for (var span in spans) {
      // Add any text before the span.
      if (span.start > charPos) {
        var text = code.substring(charPos, span.start);
        TextSpan? textSpan;
        (textSpan, bracketCounter) = _formatBrackets(text, bracketCounter);
        textSpans.add(
          textSpan,
        );

        charPos = span.start;
      }

      // Add the span.
      var segment = code.substring(span.start, span.end);
      var style = theme._getStyle(span.scopes);

      textSpans.add(
        TextSpan(
          text: segment,
          style: style,
        ),
      );

      charPos = span.end;
    }

    // Add any text after the last span.
    if (charPos < code.length) {
      var text = code.substring(charPos, code.length);
      TextSpan? textSpan;
      (textSpan, bracketCounter) = _formatBrackets(text, bracketCounter);
      textSpans.add(
        textSpan,
      );
    }
    // print('hola');
    return TextSpan(
      children: textSpans,
      style: GoogleFonts.jetBrainsMono(
        fontSize: 16,
        height: 1.3,
      ),
    );
  }

  (TextSpan, int) _formatBrackets(String text, int bracketCounter) {
    var spans = <TextSpan>[];
    var plainText = '';
    for (var char in text.characters) {
      if (_isStartingBracket(char)) {
        if (plainText.isNotEmpty) {
          spans.add(TextSpan(text: plainText));
          plainText = '';
        }

        spans.add(TextSpan(
          text: char,
          style: _getBracketStyle(bracketCounter),
        ));
        bracketCounter += 1;
        plainText = '';
      } else if (_isEndingBracket(char)) {
        if (plainText.isNotEmpty) {
          spans.add(TextSpan(text: plainText));
          plainText = '';
        }

        bracketCounter -= 1;
        spans.add(TextSpan(
          text: char,
          style: _getBracketStyle(bracketCounter),
        ));
        plainText = '';
      } else {
        plainText += char;
      }
    }
    if (plainText.isNotEmpty) {
      spans.add(TextSpan(text: plainText));
    }

    if (spans.length == 1) {
      return (spans[0], bracketCounter);
    } else {
      return (TextSpan(children: spans), bracketCounter);
    }
  }

  TextStyle _getBracketStyle(int bracketCounter) {
    if (bracketCounter < 0) {
      return _failedBracketStyle;
    }
    return _bracketStyles[bracketCounter % _bracketStyles.length];
  }

  bool _isStartingBracket(String bracket) {
    return bracket == '{' || bracket == '[' || bracket == '(';
  }

  bool _isEndingBracket(String bracket) {
    return bracket == '}' || bracket == ']' || bracket == ')';
  }
}

/// A [HighlighterTheme] which is used to style the code.
class HighlighterTheme {
  final TextStyle _wrapper;
  TextStyle? _fallback;
  final _scopes = <String, TextStyle>{};

  HighlighterTheme._({required TextStyle wrapper}) : _wrapper = wrapper;

  /// Load a [HighlighterTheme] from a JSON string.
  factory HighlighterTheme.fromConfiguration(
    String json,
    TextStyle defaultStyle,
  ) {
    final theme = HighlighterTheme._(wrapper: defaultStyle);
    theme._parseTheme(json);
    return theme;
  }

  /// Loads the default theme for the given [brightness].
  static Future<HighlighterTheme> loadForBrightness(
    Brightness brightness,
  ) async {
    if (brightness == Brightness.dark) {
      return loadDarkTheme();
    } else {
      return loadLightTheme();
    }
  }

  /// Loads the default theme for the given [BuildContext].
  static Future<HighlighterTheme> loadForContext(
    BuildContext context,
  ) async {
    return loadForBrightness(
      Theme.of(context).brightness,
    );
  }

  /// Loads the default dark theme.
  static Future<HighlighterTheme> loadDarkTheme() async {
    return loadFromAssets(
      _defaultDarkThemeFiles,
      const TextStyle(color: Color(0xFFB9EEFF)),
    );
  }

  /// Loads the default light theme.
  static Future<HighlighterTheme> loadLightTheme() async {
    return loadFromAssets(
      _defaultLightThemeFiles,
      const TextStyle(color: Color(0xFF000088)),
    );
  }

  /// Loads a custom theme from a (list of) [jsonFiles] and a [defaultStyle].
  /// Pass in multiple [jsonFiles] to merge multiple themes.
  static Future<HighlighterTheme> loadFromAssets(
    List<String> jsonFiles,
    TextStyle defaultStyle,
  ) async {
    var theme = HighlighterTheme._(wrapper: defaultStyle);
    await theme._load(jsonFiles);
    return theme;
  }

  Future<void> _load(List<String> definitions) async {
    for (var definition in definitions) {
      var json = await rootBundle.loadString(
        definition,
      );
      _parseTheme(json);
    }
  }

  void _parseTheme(String json) {
    var theme = jsonDecode(json);
    List settings = theme['settings'];
    for (Map setting in settings) {
      var style = _parseTextStyle(setting['settings']);

      var scopes = setting['scope'];
      if (scopes is String) {
        _addScope(scopes, style);
      } else if (scopes is List) {
        for (String scope in scopes) {
          _addScope(scope, style);
        }
      } else if (scopes == null) {
        _fallback = style;
      }
    }
  }

  TextStyle _parseTextStyle(Map setting) {
    Color? color;
    var foregroundSetting = setting['foreground'];
    if (foregroundSetting is String && foregroundSetting.startsWith('#')) {
      color = Color(
        int.parse(
              foregroundSetting.substring(1),
              radix: 16,
            ) |
            0xFF000000,
      );
    }

    FontStyle? fontStyle;
    FontWeight? fontWeight;
    TextDecoration? textDecoration;

    var fontStyleSetting = setting['fontStyle'];
    if (fontStyleSetting is String) {
      if (fontStyleSetting == 'italic') {
        fontStyle = FontStyle.italic;
      } else if (fontStyleSetting == 'bold') {
        fontWeight = FontWeight.bold;
      } else if (fontStyleSetting == 'underline') {
        textDecoration = TextDecoration.underline;
      } else {
        throw Exception('WARNING unknown style: $fontStyleSetting');
      }
    }

    return TextStyle(
      color: color,
      fontStyle: fontStyle,
      fontWeight: fontWeight,
      decoration: textDecoration,
    );
  }

  void _addScope(String scope, TextStyle style) {
    _scopes[scope] = style;
  }

  TextStyle? _getStyle(List<String> scope) {
    for (var s in scope) {
      var fallbacks = _fallbacks(s);
      for (var f in fallbacks) {
        var style = _scopes[f];
        if (style != null) {
          return style;
        }
      }
    }
    return _fallback;
  }

  List<String> _fallbacks(String scope) {
    var fallbacks = <String>[];
    var parts = scope.split('.');
    for (var i = 0; i < parts.length; i++) {
      var s = parts.sublist(0, i + 1).join('.');
      fallbacks.add(s);
    }
    return fallbacks.reversed.toList();
  }
}

class Palabra {
  int inicio;
  int fin;

  Palabra(this.inicio, this.fin);
}
