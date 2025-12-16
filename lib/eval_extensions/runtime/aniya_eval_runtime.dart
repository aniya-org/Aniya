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

class AniyaEvalRuntime {
  final AniyaEvalPluginStore store;

  AniyaEvalRuntime(this.store);

  $Value? _wrapArg(dynamic value) {
    if (value == null) return null;
    if (value is $Value) return value;
    if (value is String) return $String(value);
    if (value is int) return $int(value);
    if (value is double) return $double(value);
    if (value is bool) return $bool(value);
    if (value is List) {
      return $List.wrap(value.map(_wrapArg).toList());
    }
    if (value is Map) {
      final wrapped = <dynamic, dynamic>{};
      for (final entry in value.entries) {
        wrapped[_wrapArg(entry.key)] = _wrapArg(entry.value);
      }
      return $Map.wrap(wrapped);
    }
    return $Object(value);
  }

  Future<Runtime> _prepareRuntime(AniyaEvalPlugin plugin) async {
    if (plugin.bytecode != null) {
      final byteData = ByteData.sublistView(
        Uint8List.fromList(plugin.bytecode!),
      );
      final runtime = Runtime(byteData);
      runtime.grant(NetworkPermission.any);
      return runtime;
    } else {
      final compiler = Compiler();
      final program = compiler.compile({
        'plugin': {'main.dart': plugin.sourceCode},
      });
      final runtime = Runtime.ofProgram(program);
      runtime.grant(NetworkPermission.any);
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
    final runtime = await _prepareRuntime(plugin);

    final httpGet = $Closure((rt, target, argv) {
      final url = argv[0]!.$value.toString();
      final headers = <String, String>{};
      if (argv.length > 1 && argv[1] != null) {
        final raw = argv[1]!.$value;
        if (raw is Map) {
          for (final entry in raw.entries) {
            headers[entry.key.toString()] = entry.value.toString();
          }
        }
      }

      final future = http
          .get(Uri.parse(url), headers: headers)
          .then((res) => res.body);
      return $Future.wrap(future.then((body) => $String(body)));
    });

    final soupParse = $Closure((rt, target, argv) {
      final html = argv[0]!.$value.toString();
      final bs = BeautifulSoup(html);
      return $String(bs.toString());
    });

    final sha256Hex = $Closure((rt, target, argv) {
      final input = argv[0]!.$value.toString();
      final hash = sha256.convert(utf8.encode(input)).toString();
      return $String(hash);
    });

    final wrappedArgs = args.map(_wrapArg).toList();
    final fullArgs = [...wrappedArgs, httpGet, soupParse, sha256Hex];

    return runtime.executeLib('package:plugin/main.dart', function, fullArgs);
  }
}
