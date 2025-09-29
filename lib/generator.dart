import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:analyzer/dart/element/element.dart';
import 'annotations.dart';
import 'type_registry_collector.dart';

class ValyncGenerator extends GeneratorForAnnotation<AutoFactory> {
  @override
  Future<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    if (element is! ClassElement) return '';

    final className = element.name;

    // Compute proper import path
    final importPath =
        buildStep.inputId.uri.toString().replaceFirst('asset:', 'package:');

    registerTypeFactory(className, importPath);

    return ''; // don't emit to per-file .g.dart
  }
}
