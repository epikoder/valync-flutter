// ignore_for_file: strict_raw_type

export 'annotations.dart';
import 'dart:convert';
import 'dart:nativewrappers/_internal/vm/lib/ffi_allocation_patch.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:option_result/option_result.dart';

/// ----- Base Contract -----
abstract class JsonType<T> {
  T fromJson(dynamic json);
}

/// ----- Status Enum -----
enum ApiResponseStatus {
  success,
  failed;

  static ApiResponseStatus fromString(String source) =>
      source.toLowerCase() == 'success'
          ? ApiResponseStatus.success
          : ApiResponseStatus.failed;

  String get string => name.toLowerCase();
}

/// ----- Error Class -----
class ApiError {
  final String name;
  final String message;
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

/// ----- Generic API Response -----
class ApiResponse<T> {
  final ApiResponseStatus status;
  final Option<T> data;
  final Option<ApiError> error;

  ApiResponse({
    required this.status,
    required this.data,
    required this.error,
  });

  bool isData() => status == ApiResponseStatus.success;
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

/// ----- Factory Registry (Generated) -----
final Map<Type, JsonType> typeFactories = {}; // populated by generator
void registerFactory(Type t, JsonType jt) {
  typeFactories[t] = jt;
}

/// ----- HTTP Client Methods -----
enum HttpMethod { get, post, put, patch, delete }

class ValyncClientConfig {
  // final Future<void> Function()? onUnauthorized;
  final Future<Result<T, ApiError>> Function<T>(
      ApiError error, Future<Result<T, ApiError>> Function() retry)? onError;
  final Map<String, String> Function()? headers;

  const ValyncClientConfig({
    this.onError,
    this.headers,
  });
}

typedef ValyncClient = Future<Result<T, ApiError>> Function<T>(
  String url, {
  HttpMethod method,
  Map<String, dynamic>? body,
  Map<String, String>? headers,
});

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
  }) async {
    final factory = typeFactories[T];
    if (factory == null) {
      throw Exception('Missing factory for type $T');
    }

    Future<Result<T, ApiError>> doRequest() async {
      final uri = Uri.parse(url);
      final defaultHeaders = {'Content-Type': 'application/json'};
      final authHeaders = config.headers?.call() ?? {};
      final mergedHeaders = {
        ...?configHeaders,
        ...defaultHeaders,
        ...authHeaders,
        ...?headers,
      };

      late http.Response response;

      try {
        switch (method) {
          case HttpMethod.get:
            response = await http.get(uri, headers: mergedHeaders);
            break;
          case HttpMethod.post:
            response = await http.post(
              uri,
              headers: mergedHeaders,
              body: jsonEncode(body ?? {}),
            );
            break;
          case HttpMethod.put:
            response = await http.put(
              uri,
              headers: mergedHeaders,
              body: jsonEncode(body ?? {}),
            );
            break;
          case HttpMethod.patch:
            response = await http.patch(
              uri,
              headers: mergedHeaders,
              body: jsonEncode(body ?? {}),
            );
            break;
          case HttpMethod.delete:
            response = await http.delete(
              uri,
              headers: mergedHeaders,
              body: jsonEncode(body ?? {}),
            );
            break;
        }
      } on http.ClientException catch (e) {
        return Err(ApiError(
          name: "Network Error",
          message: e.toString(),
          code: const None(),
        ));
      } catch (e) {
        Logger().e('Unknown error: $e');
        return Err(ApiError(
          name: "UnknownError",
          message: "Something went wrong",
          code: const None(),
        ));
      }

      return _handleResponse<T>(response, factory as JsonType<T>);
    }

    // Initial call
    Result<T, ApiError> result = await doRequest();

    switch (result) {
      case Ok(:final value):
        return Ok(value);
      case Err(:final error):
        if (config.onError != null) {
          return await config.onError!(error, doRequest);
        }
        return Err(error);
    }
  };
}

/// ----- Generic HTTP Client -----
Future<Result<T, ApiError>> valync<T>(
  String url, {
  HttpMethod method = HttpMethod.get,
  Map<String, dynamic>? body,
  Map<String, String>? headers,
}) async {
  final factory = typeFactories[T];
  if (factory == null) {
    throw Exception('Missing factory for type $T');
  }

  final uri = Uri.parse(url);
  final defaultHeaders = {'Content-Type': 'application/json'};
  final mergedHeaders = {...defaultHeaders, ...?headers};

  late http.Response response;

  try {
    switch (method) {
      case HttpMethod.get:
        response = await http.get(uri, headers: mergedHeaders);
        break;
      case HttpMethod.post:
        response = await http.post(
          uri,
          headers: mergedHeaders,
          body: jsonEncode(body ?? {}),
        );
        break;
      case HttpMethod.put:
        response = await http.put(
          uri,
          headers: mergedHeaders,
          body: jsonEncode(body ?? {}),
        );
        break;
      case HttpMethod.patch:
        response = await http.patch(
          uri,
          headers: mergedHeaders,
          body: jsonEncode(body ?? {}),
        );
        break;
      case HttpMethod.delete:
        response = await http.delete(
          uri,
          headers: mergedHeaders,
          body: jsonEncode(body ?? {}),
        );
        break;
    }
  } catch (e) {
    return Err(ApiError(
      name: "Network Error",
      message: e.toString(),
      code: const None(),
    ));
  }

  return _handleResponse<T>(response, factory as JsonType<T>);
}

Future<Result<T, ApiError>> _handleResponse<T>(
  http.Response res,
  JsonType<T> factory,
) async {
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
