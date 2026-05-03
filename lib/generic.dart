import 'valync.dart';

/// A response type for endpoints that return no body (e.g. `204 No Content`
/// or a bare `{ "status": "success" }` with no `data` field).
class EmptyResponse implements JsonType<EmptyResponse> {
  EmptyResponse();

  @override
  EmptyResponse fromJson(dynamic _) => EmptyResponse();
}

/// A response type for endpoints that return a JSON array as `data`.
///
/// Use [apply] to map each element to a typed model:
/// ```dart
/// final result = await client<ListResponse>('https://api.example.com/users');
/// final users = result.unwrap().apply((e) => User().fromJson(e));
/// ```
class ListResponse implements JsonType<ListResponse> {
  ListResponse();
  var _sourceList = <dynamic>[];

  List<dynamic> get inner => _sourceList;

  @override
  ListResponse fromJson(dynamic source) =>
      ListResponse().._sourceList = source as List;

  /// Maps each element in the list using [fn].
  List<T> apply<T>(T Function(dynamic source) fn) {
    final list = <T>[];
    for (var item in _sourceList) {
      list.add(fn(item));
    }
    return list;
  }
}

/// A response type for endpoints that return an arbitrary JSON value as `data`
/// (object, primitive, etc.).
///
/// Use [apply] to map the raw value to a typed model:
/// ```dart
/// final result = await client<JsonObjectResponse>('https://api.example.com/me');
/// final user = result.unwrap().apply((e) => User().fromJson(e));
/// ```
class JsonObjectResponse implements JsonType<JsonObjectResponse> {
  JsonObjectResponse();
  late dynamic _sourceValue;

  dynamic get inner => _sourceValue;

  @override
  JsonObjectResponse fromJson(dynamic source) =>
      JsonObjectResponse().._sourceValue = source;

  /// Maps the raw value using [fn].
  T apply<T>(T Function(dynamic source) fn) => fn(_sourceValue);
}
