import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'generator.dart';

Builder valyncGenerator(BuilderOptions options) =>
    SharedPartBuilder([ValyncGenerator()], 'valync_generator');
