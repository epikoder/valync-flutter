library valync;

export 'annotations.dart';
import 'dart:convert';
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
        name: json["name"],
        message: json["message"],
        code: json["code"] != null ? Some(json["code"]) : const None(),
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
    final status = ApiResponseStatus.fromString(json['status']);
    return ApiResponse(
      status: status,
      data: status == ApiResponseStatus.success
          ? Some(fromJsonT(json['data']))
          : const None(),
      error: status == ApiResponseStatus.failed
          ? Some(ApiError.fromJson(json['error']))
          : const None(),
    );
  }
}

/// ----- Factory Registry (Generated) -----
final Map<Type, JsonType> typeFactories = {}; // populated by generator
registerFactory(Type t, JsonType jt) {
  typeFactories[t] = jt;
}

/// ----- HTTP Client Methods -----
enum HttpMethod { get, post, put, patch, delete }

class ValyncClientConfig {
  final Future<void> Function()? onUnauthorized;
  final bool Function(ApiError error)? isUnauthorized;
  final Map<String, String> Function()? getAuthHeaders;

  const ValyncClientConfig({
    this.onUnauthorized,
    this.isUnauthorized,
    this.getAuthHeaders,
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
      final authHeaders = config.getAuthHeaders?.call() ?? {};
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
      } catch (e) {
        return Err(ApiError(
          name: "Network Error",
          message: e.toString(),
          code: const None(),
        ));
      }

      return _handleResponse<T>(response, factory as JsonType<T>);
    }

    // Initial call
    Result<T, ApiError> result = await doRequest();

    // If unauthorized, attempt token refresh and retry once
    if (result.isErr() &&
        config.isUnauthorized?.call(result.unwrapErr()) == true &&
        config.onUnauthorized != null) {
      await config.onUnauthorized!();
      result = await doRequest(); // Retry once after refresh
    }

    return result;
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
  if (res.statusCode >= 200 && res.statusCode < 300) {
    final json = jsonDecode(res.body);
    final response = ApiResponse.fromJson(json, factory.fromJson);
    return response.isData()
        ? Ok(response.data.unwrap())
        : Err(response.error.unwrap());
  } else {
    Logger().e('HTTP error: ${res.statusCode}, ${res.body}');
    return Err(ApiError(
      name: "HTTP Error",
      message: "Unknown server error",
      code: Some(res.statusCode.toString()),
    ));
  }
}
