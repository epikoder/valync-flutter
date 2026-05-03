// ignore_for_file: strict_raw_type

export 'annotations.dart';
export 'generic.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:option_result/option_result.dart';
import 'generic.dart';

/// Base interface for JSON deserialization factories.
///
/// Implement this on every model class you want to deserialize from an API
/// response. The [fromJson] method receives the raw `data` value from the
/// response body.
///
/// ```dart
/// class User implements JsonType<User> {
///   final String id;
///   User({required this.id});
///
///   @override
///   User fromJson(dynamic json) => User(id: json['id'] as String);
/// }
/// ```
abstract class JsonType<T> {
  T fromJson(dynamic json);
}

/// Discriminates between a successful and a failed API response.
enum ApiResponseStatus {
  success,
  failed;

  /// Parses a status string from the response body (`"success"` or `"failed"`).
  static ApiResponseStatus fromString(String source) =>
      source.toLowerCase() == 'success'
          ? ApiResponseStatus.success
          : ApiResponseStatus.failed;

  /// Returns the lowercase string representation of the status.
  String get string => name.toLowerCase();
}

/// Represents a structured error returned by the API.
///
/// The API is expected to return errors in this shape:
/// ```json
/// { "name": "NotFound", "message": "User not found", "code": "404" }
/// ```
class ApiError {
  /// A short machine-readable error identifier (e.g. `"NotFound"`).
  final String name;

  /// A human-readable description of the error.
  final String message;

  /// An optional error code (e.g. HTTP status or domain-specific code).
  final Option<String> code;

  ApiError({
    required this.name,
    required this.message,
    this.code = const None(),
  });

  factory ApiError.fromJson(Map<String, dynamic> json) => ApiError(
        name: json["name"] as String,
        message: json["message"] as String,
        code:
            json["code"] != null ? Some(json["code"] as String) : const None(),
      );

  @override
  String toString() => "$name: $message";
}

/// Wraps a parsed API response, carrying either the deserialized [data] or
/// an [error] depending on [status].
class ApiResponse<T> {
  final ApiResponseStatus status;

  /// The deserialized response payload. Present only when [status] is
  /// [ApiResponseStatus.success].
  final Option<T> data;

  /// The structured error. Present only when [status] is
  /// [ApiResponseStatus.failed].
  final Option<ApiError> error;

  ApiResponse({
    required this.status,
    required this.data,
    required this.error,
  });

  /// Returns `true` when the response carries a successful payload.
  bool isData() => status == ApiResponseStatus.success;

  /// Returns `true` when the response carries an error.
  bool isError() => status == ApiResponseStatus.failed;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) fromJsonT,
  ) {
    final status = ApiResponseStatus.fromString(json['status'] as String);
    return ApiResponse(
      status: status,
      data: status == ApiResponseStatus.success
          ? Some(fromJsonT(json['data']))
          : const None(),
      error: status == ApiResponseStatus.failed
          ? Some(ApiError.fromJson(json['error'] as Map<String, dynamic>))
          : const None(),
    );
  }
}

/// Global registry mapping [Type] to its [JsonType] factory.
///
/// Pre-populated with the built-in generic response types ([EmptyResponse],
/// [ListResponse], [JsonObjectResponse]). Extended by calling
/// `registerAllFactories()` from the generated `lib/type_factories.dart`, or
/// manually via [registerFactory].
final Map<Type, JsonType> typeFactories = {
  EmptyResponse: EmptyResponse(),
  ListResponse: ListResponse(),
  JsonObjectResponse: JsonObjectResponse(),
};

/// Manually registers a [JsonType] factory for [t].
///
/// Use this when you prefer not to rely on code generation:
/// ```dart
/// registerFactory(User, User());
/// ```
void registerFactory(Type t, JsonType jt) {
  typeFactories[t] = jt;
}

/// Supported HTTP methods.
enum HttpMethod { get, post, put, patch, delete }

/// Configuration for a [ValyncClient] created with [createClient].
class ValyncClientConfig {
  /// Called when a request returns an [ApiError]. Return `true` to retry the
  /// request once, `false` to propagate the error.
  ///
  /// Typical use: refresh an auth token on a 401 and retry.
  /// ```dart
  /// onError: (error) async {
  ///   if (error.code.unwrapOr('') == '401') {
  ///     await refreshToken();
  ///     return true;
  ///   }
  ///   return false;
  /// }
  /// ```
  final Future<bool> Function(ApiError error)? onError;

  /// Returns headers that are merged into every request — evaluated lazily so
  /// the latest token value is always used.
  ///
  /// ```dart
  /// headers: () => {'Authorization': 'Bearer $token'},
  /// ```
  final Map<String, String> Function()? headers;

  const ValyncClientConfig({
    this.onError,
    this.headers,
  });
}

/// A callable client function returned by [createClient].
///
/// Call it like a function, supplying the type parameter of the expected
/// response model:
/// ```dart
/// final result = await client<User>('https://api.example.com/me');
/// ```
typedef ValyncClient = Future<Result<T, ApiError>> Function<T>(
  String url, {
  HttpMethod method,
  Map<String, dynamic>? body,
  Map<String, String>? headers,
  List<http.MultipartFile>? files,
});

/// Creates a stateful [ValyncClient] with shared [headers] and [config].
///
/// The returned client merges headers in this order (later entries win):
/// 1. [headers] passed to [createClient]
/// 2. Default `Content-Type: application/json` (omitted for multipart)
/// 3. Headers from [ValyncClientConfig.headers]
/// 4. Per-request [headers]
///
/// ```dart
/// final client = createClient(
///   headers: {'X-App-Version': '1.0.0'},
///   config: ValyncClientConfig(
///     headers: () => {'Authorization': 'Bearer $token'},
///     onError: (error) async {
///       if (error.code.unwrapOr('') == '401') {
///         await refreshToken();
///         return true;
///       }
///       return false;
///     },
///   ),
/// );
///
/// final result = await client<User>('https://api.example.com/me');
/// ```
ValyncClient createClient({
  Map<String, String>? headers,
  ValyncClientConfig config = const ValyncClientConfig(),
}) {
  final configHeaders = headers;

  return <T>(
    String url, {
    HttpMethod method = HttpMethod.get,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    List<http.MultipartFile>? files,
  }) async {
    final factory = typeFactories[T];
    if (factory == null) {
      throw Exception('Missing factory for type $T');
    }

    Future<Result<T, ApiError>> doRequest() async {
      final uri = Uri.parse(url);
      final isMultipart = files != null && files.isNotEmpty;
      final defaultHeaders = isMultipart
          ? <String, String>{}
          : {'Content-Type': 'application/json'};
      final authHeaders = config.headers?.call() ?? {};
      final mergedHeaders = {
        ...?configHeaders,
        ...defaultHeaders,
        ...authHeaders,
        ...?headers,
      };

      late http.Response response;

      try {
        response = await _sendRequest(uri, method, mergedHeaders, body, files);
      } on http.ClientException catch (e, stackTrace) {
        Logger(level: Level.error).e(e, stackTrace: stackTrace);
        return Err(ApiError(
          name: "ServerUnreacheable",
          message: "Server unreacheable",
          code: const None(),
        ));
      } catch (e, stackTrace) {
        Logger(level: Level.error).e(e, stackTrace: stackTrace);
        return Err(ApiError(
          name: "InternalServerError",
          message: "Something went wrong",
          code: const None(),
        ));
      }

      return _handleResponse<T>(response, factory as JsonType<T>);
    }

    Result<T, ApiError> result = await doRequest();

    switch (result) {
      case Ok(:final value):
        return Ok(value);
      case Err(:final error):
        if (config.onError != null) {
          final retry = await config.onError!(error);
          if (retry) {
            return await doRequest();
          }

          return Err(error);
        }
        return Err(error);
    }
  };
}

/// Makes a single typed HTTP request without a shared client.
///
/// Requires the target type [T] to be registered in [typeFactories] (either
/// via `registerAllFactories()` or [registerFactory]).
///
/// Returns `Ok<T>` on success or `Err<ApiError>` on failure — never throws.
///
/// ```dart
/// final result = await valync<User>('https://api.example.com/users/1');
///
/// switch (result) {
///   case Ok(:final value):
///     print(value.name);
///   case Err(:final error):
///     print('${error.name}: ${error.message}');
/// }
/// ```
Future<Result<T, ApiError>> valync<T>(
  String url, {
  HttpMethod method = HttpMethod.get,
  Map<String, dynamic>? body,
  Map<String, String>? headers,
  List<http.MultipartFile>? files,
}) async {
  final factory = typeFactories[T];
  if (factory == null) {
    throw Exception('Missing factory for type $T');
  }

  final uri = Uri.parse(url);
  final isMultipart = files != null && files.isNotEmpty;
  final defaultHeaders =
      isMultipart ? <String, String>{} : {'Content-Type': 'application/json'};
  final mergedHeaders = {...defaultHeaders, ...?headers};

  late http.Response response;

  try {
    response = await _sendRequest(uri, method, mergedHeaders, body, files);
  } on http.ClientException catch (e, stackTrace) {
    Logger(level: Level.error).e(e, stackTrace: stackTrace);
    return Err(ApiError(
      name: "ServerUnreacheable",
      message: "Server unreacheable",
      code: const None(),
    ));
  } catch (e, stackTrace) {
    Logger(level: Level.error).e(e, stackTrace: stackTrace);
    return Err(ApiError(
      name: "InternalServerError",
      message: "Something went wrong",
      code: const None(),
    ));
  }

  return _handleResponse<T>(response, factory as JsonType<T>);
}

Future<http.Response> _sendRequest(
  Uri uri,
  HttpMethod method,
  Map<String, String> headers,
  Map<String, dynamic>? body,
  List<http.MultipartFile>? files,
) async {
  if (files != null && files.isNotEmpty) {
    final request = http.MultipartRequest(method.name.toUpperCase(), uri)
      ..headers.addAll(headers)
      ..files.addAll(files);
    if (body != null) {
      body.forEach((key, value) => request.fields[key] = value.toString());
    }
    return http.Response.fromStream(await request.send());
  }

  switch (method) {
    case HttpMethod.get:
      return http.get(uri, headers: headers);
    case HttpMethod.post:
      return http.post(uri, headers: headers, body: jsonEncode(body ?? {}));
    case HttpMethod.put:
      return http.put(uri, headers: headers, body: jsonEncode(body ?? {}));
    case HttpMethod.patch:
      return http.patch(uri, headers: headers, body: jsonEncode(body ?? {}));
    case HttpMethod.delete:
      return http.delete(uri, headers: headers, body: jsonEncode(body ?? {}));
  }
}

Future<Result<T, ApiError>> _handleResponse<T>(
  http.Response res,
  JsonType<T> factory,
) async {
  if (res.statusCode == 204) {
    return Ok(factory.fromJson(<Map<String, dynamic>>{}));
  }

  try {
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final response = ApiResponse.fromJson(json, factory.fromJson);
    return response.isData()
        ? Ok(response.data.unwrap())
        : Err(response.error.unwrap());
  } catch (e) {
    Logger().e('JSON parsing error: $e');
    return Err(ApiError(
      name: "UnknownError",
      message: "Unknown server error",
      code: Some(res.statusCode.toString()),
    ));
  }
}
