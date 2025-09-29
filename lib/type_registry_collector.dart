final _typeFactoryEntries = <String>[];
final _typeFactoryImports = <String>{};

void registerTypeFactory(String typeName, String importPath) {
  _typeFactoryEntries.add(typeName);
  _typeFactoryImports.add("import '$importPath';");
}

String generateTypeFactoryFile() {
  if (_typeFactoryEntries.isEmpty) return '';

  final buffer = StringBuffer();
  buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
  buffer.writeln('import \'package:valync/valync.dart\';');

  for (final import in _typeFactoryImports) {
    buffer.writeln(import);
  }
  buffer.writeln();

  buffer.writeln('void registerAllFactories() {');
  for (final typeName in _typeFactoryEntries) {
    buffer.writeln('\ttypeFactories[$typeName] = $typeName();');
  }
  buffer.writeln('}');
  return buffer.toString();
}
