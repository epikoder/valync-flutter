import 'package:build/build.dart';
import 'type_registry_collector.dart';

Builder typeFactoryCombiner(BuilderOptions options) => _TypeFactoryCombiner();

class _TypeFactoryCombiner implements Builder {
  @override
  final buildExtensions = const {
    r'$lib$': ['type_factories.dart'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final content = generateTypeFactoryFile();
    final output =
        AssetId(buildStep.inputId.package, 'lib/type_factories.dart');
    await buildStep.writeAsString(output, content);
  }
}
