/// Marks a class for automatic [JsonType] factory registration.
///
/// Apply this annotation to any model that implements [JsonType]. The
/// `build_runner` code generator will collect all annotated classes and emit
/// `lib/type_factories.dart` with a `registerAllFactories()` function that
/// populates the global [typeFactories] registry at startup.
///
/// ```dart
/// @AutoFactory()
/// class User implements JsonType<User> {
///   final String id;
///   User({required this.id});
///
///   @override
///   User fromJson(dynamic json) => User(id: json['id'] as String);
/// }
/// ```
///
/// Then in `main()`:
/// ```dart
/// import 'package:your_app/type_factories.dart';
///
/// void main() {
///   registerAllFactories();
///   runApp(const MyApp());
/// }
/// ```
class AutoFactory {
  const AutoFactory();
}
