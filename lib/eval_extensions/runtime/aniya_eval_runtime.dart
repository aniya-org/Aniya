import 'dart:convert';
import 'dart:typed_data';
import 'package:dart_eval/dart_eval.dart';
import 'package:dart_eval/dart_eval_bridge.dart';
import 'package:dart_eval/dart_eval_security.dart';
import 'package:dart_eval/stdlib/core.dart';
import 'package:beautiful_soup_dart/beautiful_soup.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import '../storage/aniya_eval_plugin_store.dart';

dynamic _unwrapEvalValue(dynamic raw) {
  if (raw is $Instance) return raw.$reified;
  if (raw is $Value) return raw.$value;
  return raw;
}

dynamic _deepUnwrapEvalValue(dynamic raw) {
  final v = raw is $Instance
      ? raw.$reified
      : (raw is $Value ? raw.$value : raw);
  if (v is List) {
    return v.map(_deepUnwrapEvalValue).toList();
  }
  if (v is Set) {
    return v.map(_deepUnwrapEvalValue).toSet();
  }
  if (v is Map) {
    return v.map(
      (k, value) =>
          MapEntry(_deepUnwrapEvalValue(k), _deepUnwrapEvalValue(value)),
    );
  }
  return v;
}

String _unwrapEvalString(dynamic raw) =>
    (_unwrapEvalValue(raw) ?? '').toString();

Map<String, dynamic>? _asStringKeyedMap(dynamic raw) {
  if (raw is Map) {
    return raw.map((k, v) => MapEntry(k.toString(), _deepUnwrapEvalValue(v)));
  }
  return null;
}

Map<String, Object>? _asStringKeyedObjectMap(dynamic raw) {
  final m = _asStringKeyedMap(raw);
  if (m == null) return null;
  final out = <String, Object>{};
  for (final entry in m.entries) {
    final v = entry.value;
    if (v == null) continue;
    out[entry.key] = v as Object;
  }
  return out.isEmpty ? null : out;
}

Map<String, dynamic>? _asFindOptions(dynamic raw) {
  if (raw == null) return null;
  if (raw is $Value) return _asFindOptions(raw.$value);
  return _asStringKeyedMap(raw);
}

Bs4Element? _findOn(dynamic node, String tag, Map<String, dynamic>? options) {
  if (options == null || options.isEmpty) {
    return node.find(tag);
  }
  final selector = options != null && options.containsKey('selector')
      ? _unwrapEvalString(options['selector'])
      : null;
  final attrs = _asStringKeyedObjectMap(options?['attrs']);
  final class_ = options != null && options.containsKey('class_')
      ? _unwrapEvalString(options['class_'])
      : null;
  final id = options != null && options.containsKey('id')
      ? _unwrapEvalString(options['id'])
      : null;
  final regex = options != null && options.containsKey('regex')
      ? _unwrapEvalString(options['regex'])
      : null;
  final string = options != null && options.containsKey('string')
      ? _unwrapEvalString(options['string'])
      : null;

  return node.find(
    tag,
    selector: selector,
    attrs: attrs,
    class_: class_,
    id: id,
    regex: regex,
    string: string,
  );
}

List<Bs4Element> _findAllOn(
  dynamic node,
  String tag,
  Map<String, dynamic>? options,
) {
  if (options == null || options.isEmpty) {
    final result = node.findAll(tag);
    return result is List<Bs4Element> ? result : <Bs4Element>[];
  }
  final selector = options != null && options.containsKey('selector')
      ? _unwrapEvalString(options['selector'])
      : null;
  final attrs = _asStringKeyedObjectMap(options?['attrs']);
  final class_ = options != null && options.containsKey('class_')
      ? _unwrapEvalString(options['class_'])
      : null;
  final id = options != null && options.containsKey('id')
      ? _unwrapEvalString(options['id'])
      : null;
  final regex = options != null && options.containsKey('regex')
      ? _unwrapEvalString(options['regex'])
      : null;
  final string = options != null && options.containsKey('string')
      ? _unwrapEvalString(options['string'])
      : null;

  final result = node.findAll(
    tag,
    selector: selector,
    attrs: attrs,
    class_: class_,
    id: id,
    regex: regex,
    string: string,
  );
  return result is List<Bs4Element> ? result : <Bs4Element>[];
}

class $BeautifulSoup implements $Instance {
  $BeautifulSoup.wrap(this.$value);

  @override
  final BeautifulSoup $value;

  @override
  dynamic get $reified => $value;

  @override
  $Value? $getProperty(Runtime runtime, String identifier) {
    switch (identifier) {
      case '==':
        return $Function((rt, target, args) {
          final self = (target as $BeautifulSoup).$value;
          final other = args.isNotEmpty ? _unwrapEvalValue(args[0]) : null;
          if (other is BeautifulSoup) {
            return $bool(identical(self, other) || self == other);
          }
          return $bool(false);
        });
      case '!=':
        return $Function((rt, target, args) {
          final self = (target as $BeautifulSoup).$value;
          final other = args.isNotEmpty ? _unwrapEvalValue(args[0]) : null;
          if (other is BeautifulSoup) {
            return $bool(!(identical(self, other) || self == other));
          }
          return $bool(true);
        });
      case 'find':
        return $Function((rt, target, args) {
          final soup = (target as $BeautifulSoup).$value;
          final tag = args.isNotEmpty ? _unwrapEvalString(args[0]) : '';
          final options = args.length > 1
              ? _asFindOptions(_unwrapEvalValue(args[1]))
              : null;
          final el = _findOn(soup, tag, options);
          return el == null ? const $null() : $Bs4Element.wrap(el);
        });
      case 'findAll':
        return $Function((rt, target, args) {
          final soup = (target as $BeautifulSoup).$value;
          final tag = args.isNotEmpty ? _unwrapEvalString(args[0]) : '';
          final options = args.length > 1
              ? _asFindOptions(_unwrapEvalValue(args[1]))
              : null;
          final list = _findAllOn(soup, tag, options);
          return $List.wrap(list.map($Bs4Element.wrap).toList());
        });
      case 'body':
        final body = $value.body;
        return body == null ? const $null() : $Bs4Element.wrap(body);
      case 'head':
        final head = $value.head;
        return head == null ? const $null() : $Bs4Element.wrap(head);
      case 'html':
        final html = $value.html;
        return html == null ? const $null() : $Bs4Element.wrap(html);
      case 'text':
        return $String($value.text);
      case 'prettify':
        return $Function(
          (rt, target, args) =>
              $String((target as $BeautifulSoup).$value.prettify()),
        );
      case 'toString':
        return $Function(
          (rt, target, args) =>
              $String((target as $BeautifulSoup).$value.toString()),
        );
    }
    return null;
  }

  @override
  void $setProperty(Runtime runtime, String identifier, $Value value) {}

  @override
  int $getRuntimeType(Runtime runtime) => runtime.lookupType(CoreTypes.object);
}

class $Bs4Element implements $Instance {
  $Bs4Element.wrap(this.$value);

  @override
  final Bs4Element $value;

  @override
  dynamic get $reified => $value;

  @override
  $Value? $getProperty(Runtime runtime, String identifier) {
    switch (identifier) {
      case '==':
        return $Function((rt, target, args) {
          final self = (target as $Bs4Element).$value;
          final other = args.isNotEmpty ? _unwrapEvalValue(args[0]) : null;
          if (other is Bs4Element) {
            return $bool(identical(self, other) || self == other);
          }
          return $bool(false);
        });
      case '!=':
        return $Function((rt, target, args) {
          final self = (target as $Bs4Element).$value;
          final other = args.isNotEmpty ? _unwrapEvalValue(args[0]) : null;
          if (other is Bs4Element) {
            return $bool(!(identical(self, other) || self == other));
          }
          return $bool(true);
        });
      case 'find':
        return $Function((rt, target, args) {
          final el = (target as $Bs4Element).$value;
          final tag = args.isNotEmpty ? _unwrapEvalString(args[0]) : '';
          final options = args.length > 1
              ? _asFindOptions(_unwrapEvalValue(args[1]))
              : null;
          final found = _findOn(el, tag, options);
          return found == null ? const $null() : $Bs4Element.wrap(found);
        });
      case 'findAll':
        return $Function((rt, target, args) {
          final el = (target as $Bs4Element).$value;
          final tag = args.isNotEmpty ? _unwrapEvalString(args[0]) : '';
          final options = args.length > 1
              ? _asFindOptions(_unwrapEvalValue(args[1]))
              : null;
          final list = _findAllOn(el, tag, options);
          return $List.wrap(list.map($Bs4Element.wrap).toList());
        });
      case 'name':
        return $String($value.name ?? '');
      case 'string':
        final str = $value.string;
        return $String(str);
      case 'text':
        return $String($value.text);
      case 'innerHtml':
        return $String($value.innerHtml);
      case 'outerHtml':
        return $String($value.outerHtml);
      case 'className':
        return $String($value.className);
      case 'children':
        return $List.wrap($value.children.map($Bs4Element.wrap).toList());
      case 'attr':
        return $Function((rt, target, args) {
          final el = (target as $Bs4Element).$value;
          final key = args.isNotEmpty ? _unwrapEvalString(args[0]) : '';
          final val = el[key];
          return val == null ? const $null() : $String(val.toString());
        });
      case 'setAttr':
        return $Function((rt, target, args) {
          final el = (target as $Bs4Element).$value;
          final key = args.isNotEmpty ? _unwrapEvalString(args[0]) : '';
          final val = args.length > 1 ? _unwrapEvalValue(args[1]) : null;
          if (key.isEmpty) {
            return const $null();
          }
          if (val == null) {
            try {
              el.attributes.remove(key);
            } catch (_) {
              el[key] = '';
            }
          } else {
            el[key] = val.toString();
          }
          return const $null();
        });
      case 'toString':
        return $Function(
          (rt, target, args) =>
              $String((target as $Bs4Element).$value.toString()),
        );
    }
    return null;
  }

  @override
  void $setProperty(Runtime runtime, String identifier, $Value value) {}

  @override
  int $getRuntimeType(Runtime runtime) => runtime.lookupType(CoreTypes.object);
}

class $HttpGetFn implements $Instance {
  $HttpGetFn();

  @override
  final Object $value = Object();

  @override
  dynamic get $reified => $value;

  @override
  $Value? $getProperty(Runtime runtime, String identifier) {
    switch (identifier) {
      case 'call':
        return $Function((rt, target, args) {
          final url = args.isNotEmpty ? _unwrapEvalString(args[0]) : '';
          final headers = <String, String>{};
          if (args.length > 1 && args[1] != null) {
            final raw = _unwrapEvalValue(args[1]);
            if (raw is Map) {
              for (final entry in raw.entries) {
                headers[_unwrapEvalString(entry.key)] = _unwrapEvalString(
                  entry.value,
                );
              }
            }
          }

          final future = http
              .get(Uri.parse(url), headers: headers)
              .then((res) => res.body);
          return $Future.wrap(future.then((body) => $String(body)));
        });
    }
    return null;
  }

  @override
  void $setProperty(Runtime runtime, String identifier, $Value value) {}

  @override
  int $getRuntimeType(Runtime runtime) => runtime.lookupType(CoreTypes.object);
}

class $SoupParseFn implements $Instance {
  $SoupParseFn();

  @override
  final Object $value = Object();

  @override
  dynamic get $reified => $value;

  @override
  $Value? $getProperty(Runtime runtime, String identifier) {
    switch (identifier) {
      case 'call':
        return $Function((rt, target, args) {
          final html = args.isNotEmpty ? _unwrapEvalString(args[0]) : '';
          return $BeautifulSoup.wrap(BeautifulSoup(html));
        });
    }
    return null;
  }

  @override
  void $setProperty(Runtime runtime, String identifier, $Value value) {}

  @override
  int $getRuntimeType(Runtime runtime) => runtime.lookupType(CoreTypes.object);
}

class $Sha256HexFn implements $Instance {
  $Sha256HexFn();

  @override
  final Object $value = Object();

  @override
  dynamic get $reified => $value;

  @override
  $Value? $getProperty(Runtime runtime, String identifier) {
    switch (identifier) {
      case 'call':
        return $Function((rt, target, args) {
          final input = args.isNotEmpty ? _unwrapEvalString(args[0]) : '';
          return $String(sha256.convert(utf8.encode(input)).toString());
        });
    }
    return null;
  }

  @override
  void $setProperty(Runtime runtime, String identifier, $Value value) {}

  @override
  int $getRuntimeType(Runtime runtime) => runtime.lookupType(CoreTypes.object);
}

class AniyaEvalRuntime {
  final AniyaEvalPluginStore store;

  AniyaEvalRuntime(this.store);

  String _rewritePluginSourceForInterop(String source) {
    var out = source;
    out = out.replaceAllMapped(
      RegExp(r'<\s*(String|int|double|bool|num)\s*>\s*\['),
      (m) => '<dynamic>[',
    );
    out = out.replaceAllMapped(
      RegExp(r'<\s*(String|int|double|bool|num)\s*>\s*\{'),
      (m) => '<dynamic>{',
    );
    out = out.replaceAllMapped(
      RegExp(
        r'<\s*(String|int|double|bool|num)\s*,\s*(String|int|double|bool|num)\s*>\s*\{',
      ),
      (m) => '<dynamic, dynamic>{',
    );
    out = out.replaceAllMapped(
      RegExp(r'\bList\s*<\s*(String|int|double|bool|num)\s*>\b'),
      (m) => 'List<dynamic>',
    );
    out = out.replaceAllMapped(
      RegExp(r'\bSet\s*<\s*(String|int|double|bool|num)\s*>\b'),
      (m) => 'Set<dynamic>',
    );
    out = out.replaceAllMapped(
      RegExp(r'\bIterable\s*<\s*(String|int|double|bool|num)\s*>\b'),
      (m) => 'Iterable<dynamic>',
    );
    out = out.replaceAllMapped(
      RegExp(
        r'\bMap\s*<\s*(String|int|double|bool|num)\s*,\s*(String|int|double|bool|num|dynamic|Object)\s*\??\s*>\b',
      ),
      (m) => 'Map<dynamic, dynamic>',
    );

    final needsSoupInterop = RegExp(
      r'(\?\.)?\s*findAll\s*\(|(\?\.)?\s*find\s*\(|(\?\.)?\s*attr\s*\(',
    ).hasMatch(out);

    final needsToStringInterop = RegExp(
      r'(\?\.)?\s*toString\s*\(\s*\)',
    ).hasMatch(out);

    if (needsToStringInterop && !out.contains('_aniyaEvalToString(')) {
      const helper = '''
String? _aniyaEvalToString(dynamic value) {
  if (value == null) return null;
  return '\$value';
}
''';
      final directiveBlock = RegExp(
        r'^\s*(?:(?:library|import|export|part)\b[^\n]*;\s*\n)+',
      ).firstMatch(out);
      if (directiveBlock != null) {
        out =
            out.substring(0, directiveBlock.end) +
            '\n' +
            helper +
            '\n' +
            out.substring(directiveBlock.end);
      } else {
        out = helper + '\n' + out;
      }
    }

    if (out.contains('sha256Hex') || needsSoupInterop) {
      bool hasInjectedParam(String name) =>
          RegExp('(^|[\\s,(])${RegExp.escape(name)}\\s*,').hasMatch(out);
      final shouldInject =
          !hasInjectedParam('encodeComponent') ||
          !hasInjectedParam('encodeQueryComponent') ||
          !hasInjectedParam('jsonEncode') ||
          !hasInjectedParam('jsonDecode') ||
          (needsSoupInterop &&
              (!hasInjectedParam('soupFind') ||
                  !hasInjectedParam('soupFindAll') ||
                  !hasInjectedParam('soupAttr')));
      if (shouldInject) {
        final anchors = <RegExp>[
          RegExp(r'\bsha256Hex\b\s*,'),
          RegExp(r'\bsoupParse\b\s*,'),
          RegExp(r'\bhttpGet\b\s*,'),
        ];

        for (final anchor in anchors) {
          if (!anchor.hasMatch(out)) continue;
          out = out.replaceAllMapped(anchor, (m) {
            final idx = m.start;
            final lineStart = out.lastIndexOf('\n', idx);
            final line = out.substring(lineStart + 1, idx);
            final indent = RegExp(r'^\s*').stringMatch(line) ?? '';

            final inject = StringBuffer();
            if (!hasInjectedParam('encodeComponent')) {
              inject.writeln(
                '${indent}dynamic Function(dynamic) encodeComponent,',
              );
            }
            if (!hasInjectedParam('encodeQueryComponent')) {
              inject.writeln(
                '${indent}dynamic Function(dynamic) encodeQueryComponent,',
              );
            }
            if (!hasInjectedParam('jsonEncode')) {
              inject.writeln('${indent}dynamic Function(dynamic) jsonEncode,');
            }
            if (!hasInjectedParam('jsonDecode')) {
              inject.writeln('${indent}dynamic Function(dynamic) jsonDecode,');
            }
            if (needsSoupInterop && !hasInjectedParam('soupFind')) {
              inject.writeln(
                '${indent}dynamic Function(dynamic, String, [dynamic]) soupFind,',
              );
            }
            if (needsSoupInterop && !hasInjectedParam('soupFindAll')) {
              inject.writeln(
                '${indent}dynamic Function(dynamic, String, [dynamic]) soupFindAll,',
              );
            }
            if (needsSoupInterop && !hasInjectedParam('soupAttr')) {
              inject.writeln(
                '${indent}dynamic Function(dynamic, String) soupAttr,',
              );
            }

            final injectStr = inject.toString().trimRight();
            if (injectStr.isEmpty) return m[0]!;
            return '${m[0]}\n$injectStr';
          });
          break;
        }
      }
    }

    out = out.replaceAllMapped(
      RegExp(r'\bUri\.encodeQueryComponent\s*\('),
      (m) => 'encodeQueryComponent(',
    );
    out = out.replaceAllMapped(
      RegExp(r'\bUri\.encodeComponent\s*\('),
      (m) => 'encodeComponent(',
    );
    out = out.replaceAllMapped(
      RegExp(r'\bjson\.encode\s*\('),
      (m) => 'jsonEncode(',
    );
    out = out.replaceAllMapped(
      RegExp(r'\bjson\.decode\s*\('),
      (m) => 'jsonDecode(',
    );

    if (needsToStringInterop) {
      out = out.replaceAllMapped(
        RegExp(r'(^|[^\w.])([A-Za-z_]\w*)\s*\?\.\s*toString\s*\(\s*\)'),
        (m) => '${m[1]}_aniyaEvalToString(${m[2]})',
      );
      out = out.replaceAllMapped(
        RegExp(r'(^|[^\w.])([A-Za-z_]\w*)\s*\.\s*toString\s*\(\s*\)'),
        (m) => '${m[1]}_aniyaEvalToString(${m[2]})',
      );
    }

    if (needsSoupInterop) {
      out = out.replaceAllMapped(
        RegExp(r'\b([A-Za-z_]\w*)\s*\?\.\s*findAll\s*\('),
        (m) => 'soupFindAll(${m[1]}, ',
      );
      out = out.replaceAllMapped(
        RegExp(r'\b([A-Za-z_]\w*)\s*\.\s*findAll\s*\('),
        (m) => 'soupFindAll(${m[1]}, ',
      );
      out = out.replaceAllMapped(
        RegExp(r'\b([A-Za-z_]\w*)\s*\?\.\s*find\s*\('),
        (m) => 'soupFind(${m[1]}, ',
      );
      out = out.replaceAllMapped(
        RegExp(r'\b([A-Za-z_]\w*)\s*\.\s*find\s*\('),
        (m) => 'soupFind(${m[1]}, ',
      );
      out = out.replaceAllMapped(
        RegExp(r'\b([A-Za-z_]\w*)\s*\?\.\s*attr\s*\('),
        (m) => 'soupAttr(${m[1]}, ',
      );
      out = out.replaceAllMapped(
        RegExp(r'\b([A-Za-z_]\w*)\s*\.\s*attr\s*\('),
        (m) => 'soupAttr(${m[1]}, ',
      );
    }
    return out;
  }

  $Value _wrapToValue(dynamic value) {
    if (value == null) return const $null();
    if (value is $Value) return value;
    if (value is String) return $String(value);
    if (value is int) return $int(value);
    if (value is double) return $double(value);
    if (value is bool) return $bool(value);
    if (value is List) return $List.wrap(value.map(_wrapToValue).toList());
    if (value is Set) return $Set.wrap(value.map(_wrapToValue).toSet());
    if (value is Map) {
      final out = <dynamic, dynamic>{};
      for (final entry in value.entries) {
        out[_wrapToValue(entry.key)] = _wrapToValue(entry.value);
      }
      return $Map.wrap(out);
    }
    return $Object(value);
  }

  List<String?> _getFunctionParamTypes(String source, String function) {
    final match = RegExp(
      '\\b${RegExp.escape(function)}\\s*\\(',
    ).firstMatch(source);
    if (match == null) return const <String?>[];

    final startParen = match.end - 1;
    var i = startParen + 1;

    var parenDepth = 1;
    var angleDepth = 0;
    var bracketDepth = 0;
    var braceDepth = 0;
    while (i < source.length && parenDepth > 0) {
      final ch = source[i];
      switch (ch) {
        case '(':
          parenDepth++;
          break;
        case ')':
          parenDepth--;
          break;
        case '<':
          angleDepth++;
          break;
        case '>':
          if (angleDepth > 0) angleDepth--;
          break;
        case '[':
          bracketDepth++;
          break;
        case ']':
          if (bracketDepth > 0) bracketDepth--;
          break;
        case '{':
          braceDepth++;
          break;
        case '}':
          if (braceDepth > 0) braceDepth--;
          break;
      }
      i++;
    }

    final endParen = i - 1;
    if (endParen <= startParen) return const <String?>[];

    final paramsSrc = source.substring(startParen + 1, endParen);

    final parts = <String>[];
    final buf = StringBuffer();
    parenDepth = 0;
    angleDepth = 0;
    bracketDepth = 0;
    braceDepth = 0;
    for (var j = 0; j < paramsSrc.length; j++) {
      final ch = paramsSrc[j];
      switch (ch) {
        case '(':
          parenDepth++;
          break;
        case ')':
          if (parenDepth > 0) parenDepth--;
          break;
        case '<':
          angleDepth++;
          break;
        case '>':
          if (angleDepth > 0) angleDepth--;
          break;
        case '[':
          bracketDepth++;
          break;
        case ']':
          if (bracketDepth > 0) bracketDepth--;
          break;
        case '{':
          braceDepth++;
          break;
        case '}':
          if (braceDepth > 0) braceDepth--;
          break;
      }

      if (ch == ',' &&
          parenDepth == 0 &&
          angleDepth == 0 &&
          bracketDepth == 0 &&
          braceDepth == 0) {
        parts.add(buf.toString());
        buf.clear();
        continue;
      }

      buf.write(ch);
    }
    final tail = buf.toString();
    if (tail.trim().isNotEmpty) parts.add(tail);

    String? normalizeType(String raw) {
      var s = raw.trim();
      if (s.isEmpty) return null;

      final eq = s.indexOf('=');
      if (eq != -1) s = s.substring(0, eq).trim();

      s = s.replaceAll(RegExp('^required\\s+'), '');
      s = s.replaceAll(RegExp('^final\\s+'), '');
      s = s.replaceAll(RegExp('^var\\s+'), '');

      var splitPos = -1;
      parenDepth = 0;
      angleDepth = 0;
      bracketDepth = 0;
      braceDepth = 0;
      for (var k = s.length - 1; k >= 0; k--) {
        final ch = s[k];
        switch (ch) {
          case ')':
            parenDepth++;
            break;
          case '(':
            if (parenDepth > 0) parenDepth--;
            break;
          case '>':
            angleDepth++;
            break;
          case '<':
            if (angleDepth > 0) angleDepth--;
            break;
          case ']':
            bracketDepth++;
            break;
          case '[':
            if (bracketDepth > 0) bracketDepth--;
            break;
          case '}':
            braceDepth++;
            break;
          case '{':
            if (braceDepth > 0) braceDepth--;
            break;
        }
        if (parenDepth == 0 &&
            angleDepth == 0 &&
            bracketDepth == 0 &&
            braceDepth == 0 &&
            (ch == ' ' || ch == '\n' || ch == '\t' || ch == '\r')) {
          splitPos = k;
          break;
        }
      }

      if (splitPos == -1) return 'dynamic';

      var typePart = s.substring(0, splitPos).trim();
      if (typePart.isEmpty) return 'dynamic';
      typePart = typePart.replaceAll('?', '');
      if (typePart == 'dynamic') return 'dynamic';
      return typePart;
    }

    return parts.map(normalizeType).toList();
  }

  dynamic _coerceForParamType(dynamic value, String? type) {
    final t = (type ?? 'dynamic').trim();
    if (value is $Value) return value;
    if (t == 'dynamic') return _wrapToValue(value);

    if (t.startsWith('List') || t.startsWith('Iterable')) {
      if (value == null) return $List.wrap(<$Value>[]);
      if (value is Iterable) {
        return $List.wrap(value.map(_wrapToValue).toList());
      }
      return $List.wrap(<$Value>[_wrapToValue(value)]);
    }

    if (t.startsWith('Map')) {
      if (value is Map) return _wrapToValue(value);
      return $Map.wrap(const <dynamic, dynamic>{});
    }

    if (t.startsWith('Set')) {
      if (value == null) return $Set.wrap(<$Value>{});
      if (value is Iterable) {
        return $Set.wrap(value.map(_wrapToValue).toSet());
      }
      return $Set.wrap(<$Value>{_wrapToValue(value)});
    }

    if (value == null) return null;

    if (t == 'String') return $String(value.toString());
    if (t == 'int') {
      final parsed = value is int ? value : int.tryParse('$value') ?? 0;
      return $int(parsed);
    }
    if (t == 'double') {
      final parsed = value is double ? value : double.tryParse('$value') ?? 0.0;
      return $double(parsed);
    }
    if (t == 'num') {
      final parsed = value is num ? value : num.tryParse('$value') ?? 0;
      if (parsed is int) return $int(parsed);
      return $double(parsed.toDouble());
    }
    if (t == 'bool') {
      final parsed = value is bool
          ? value
          : ('$value').toLowerCase().trim() == 'true';
      return $bool(parsed);
    }

    return _wrapToValue(value);
  }

  Future<Runtime> _prepareRuntime(
    AniyaEvalPlugin plugin, {
    required String sourceForCompile,
  }) async {
    final canUseBytecode =
        plugin.bytecode != null && sourceForCompile == plugin.sourceCode;
    if (canUseBytecode) {
      final byteData = ByteData.sublistView(
        Uint8List.fromList(plugin.bytecode!),
      );
      final runtime = Runtime(byteData);
      runtime.grant(NetworkPermission.any);
      runtime.addTypeAutowrapper((dynamic value) {
        if (value is $Value) return value;
        if (value is String) return $String(value);
        if (value is int) return $int(value);
        if (value is double) return $double(value);
        if (value is bool) return $bool(value);
        if (value is List) return $List.wrap(value.map(_wrapToValue).toList());
        if (value is Set) return $Set.wrap(value.map(_wrapToValue).toSet());
        if (value is Map) return _wrapToValue(value);
        return null;
      });
      return runtime;
    } else {
      final compiler = Compiler();
      final program = compiler.compile({
        'plugin': {'main.dart': sourceForCompile},
      });
      final runtime = Runtime.ofProgram(program);
      runtime.grant(NetworkPermission.any);
      runtime.addTypeAutowrapper((dynamic value) {
        if (value is $Value) return value;
        if (value is String) return $String(value);
        if (value is int) return $int(value);
        if (value is double) return $double(value);
        if (value is bool) return $bool(value);
        if (value is List) return $List.wrap(value.map(_wrapToValue).toList());
        if (value is Set) return $Set.wrap(value.map(_wrapToValue).toSet());
        if (value is Map) return _wrapToValue(value);
        return null;
      });
      return runtime;
    }
  }

  Future<dynamic> callFunction(
    String pluginId,
    String function,
    List<dynamic> args,
  ) async {
    final plugin = store.get(pluginId);
    if (plugin == null) {
      throw StateError('Plugin not found: $pluginId');
    }
    final sourceForCompile = _rewritePluginSourceForInterop(plugin.sourceCode);
    final runtime = await _prepareRuntime(
      plugin,
      sourceForCompile: sourceForCompile,
    );

    final httpGet = $Closure((rt, target, argv) {
      final url = argv.isNotEmpty ? _unwrapEvalString(argv[0]) : '';
      final headers = <String, String>{};
      if (argv.length > 1 && argv[1] != null) {
        final raw = _unwrapEvalValue(argv[1]);
        if (raw is Map) {
          for (final entry in raw.entries) {
            headers[_unwrapEvalString(entry.key)] = _unwrapEvalString(
              entry.value,
            );
          }
        }
      }

      final future = http
          .get(Uri.parse(url), headers: headers)
          .then((res) => res.body);
      return $Future.wrap(future.then((body) => $String(body)));
    });

    final soupParse = $Closure((rt, target, argv) {
      final html = argv.isNotEmpty ? _unwrapEvalString(argv[0]) : '';
      return $BeautifulSoup.wrap(BeautifulSoup(html));
    });

    final sha256Hex = $Closure((rt, target, argv) {
      final input = argv.isNotEmpty ? _unwrapEvalString(argv[0]) : '';
      return $String(sha256.convert(utf8.encode(input)).toString());
    });

    final encodeComponent = $Closure((rt, target, argv) {
      final input = argv.isNotEmpty ? _unwrapEvalString(argv[0]) : '';
      return $String(Uri.encodeComponent(input));
    });

    final encodeQueryComponent = $Closure((rt, target, argv) {
      final input = argv.isNotEmpty ? _unwrapEvalString(argv[0]) : '';
      return $String(Uri.encodeQueryComponent(input));
    });

    final jsonEncode = $Closure((rt, target, argv) {
      final input = argv.isNotEmpty ? _deepUnwrapEvalValue(argv[0]) : null;
      return $String(json.encode(input));
    });

    final jsonDecode = $Closure((rt, target, argv) {
      final input = argv.isNotEmpty ? _unwrapEvalString(argv[0]) : '';
      final decoded = json.decode(input);
      return _wrapToValue(decoded);
    });

    final soupFind = $Closure((rt, target, argv) {
      final node = argv.isNotEmpty ? _unwrapEvalValue(argv[0]) : null;
      if (node == null) return const $null();
      final tag = argv.length > 1 ? _unwrapEvalString(argv[1]) : '';
      final options = argv.length > 2
          ? _asFindOptions(_unwrapEvalValue(argv[2]))
          : null;
      final found = _findOn(node, tag, options);
      return found == null ? const $null() : $Bs4Element.wrap(found);
    });

    final soupFindAll = $Closure((rt, target, argv) {
      final node = argv.isNotEmpty ? _unwrapEvalValue(argv[0]) : null;
      if (node == null) return $List.wrap(const <$Value>[]);
      final tag = argv.length > 1 ? _unwrapEvalString(argv[1]) : '';
      final options = argv.length > 2
          ? _asFindOptions(_unwrapEvalValue(argv[2]))
          : null;
      final list = _findAllOn(node, tag, options);
      return $List.wrap(list.map($Bs4Element.wrap).toList());
    });

    final soupAttr = $Closure((rt, target, argv) {
      final node = argv.isNotEmpty ? _unwrapEvalValue(argv[0]) : null;
      if (node is! Bs4Element) return const $null();
      final key = argv.length > 1 ? _unwrapEvalString(argv[1]) : '';
      if (key.isEmpty) return const $null();
      final val = node[key];
      return val == null ? const $null() : $String(val.toString());
    });

    final paramTypes = _getFunctionParamTypes(sourceForCompile, function);
    final coercedArgs = <dynamic>[];
    for (var i = 0; i < args.length; i++) {
      final type = i < paramTypes.length ? paramTypes[i] : null;
      coercedArgs.add(_coerceForParamType(args[i], type));
    }

    final availableExtras = <dynamic>[
      httpGet,
      soupParse,
      sha256Hex,
      encodeComponent,
      encodeQueryComponent,
      jsonEncode,
      jsonDecode,
      soupFind,
      soupFindAll,
      soupAttr,
    ];
    final extrasNeeded = (paramTypes.length - coercedArgs.length).clamp(
      0,
      availableExtras.length,
    );
    final fullArgs = <dynamic>[
      ...coercedArgs,
      ...availableExtras.take(extrasNeeded),
    ];

    final boxedFullArgs = fullArgs.map(_wrapToValue).toList();
    final result = runtime.executeLib(
      'package:plugin/main.dart',
      function,
      boxedFullArgs,
    );
    final awaited = result is Future ? await result : result;
    return _deepUnwrapEvalValue(awaited);
  }
}
