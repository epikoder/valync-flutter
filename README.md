# valync

A Flutter package for making typed HTTP requests with automatic JSON deserialization, structured success/failure responses, and built-in error handling.

## Features

- Typed HTTP client — responses are deserialized directly into your Dart models
- `Result<T, ApiError>` return type (via `option_result`) — no uncaught exceptions
- Structured API responses with `success`/`failed` status discrimination
- Multipart file upload support
- Built-in generic response types: `EmptyResponse`, `ListResponse`, `JsonObjectResponse`
- Auto-generated factory registry via the `@AutoFactory` annotation and `build_runner`
- Optional `createClient` for shared headers and automatic retry on error

## Getting started

Add to your `pubspec.yaml`:

```yaml
dependencies:
  valync: ^0.1.2

dev_dependencies:
  build_runner: any
```

## Setup

### 1. Annotate your models

Implement `JsonType<T>` and annotate with `@AutoFactory`:

```dart
import 'package:valync/valync.dart';

@AutoFactory()
class User implements JsonType<User> {
  final String id;
  final String name;

  User({required this.id, required this.name});

  @override
  User fromJson(dynamic json) => User(
        id: json['id'] as String,
        name: json['name'] as String,
      );
}
```

### 2. Run the generator

```sh
flutter pub run build_runner build
```

This generates `lib/type_factories.dart` containing a `registerAllFactories()` function.

### 3. Register factories at startup

Call `registerAllFactories()` before making any requests — typically in `main()`:

```dart
import 'package:your_app/type_factories.dart';

void main() {
  registerAllFactories();
  runApp(const MyApp());
}
```

> Built-in types (`EmptyResponse`, `ListResponse`, `JsonObjectResponse`) are
> pre-registered automatically — no annotation or setup needed.

## Usage

### One-off request

```dart
final result = await valync<User>('https://api.example.com/users/1');

switch (result) {
  case Ok(:final value):
    print(value.name);
  case Err(:final error):
    print('${error.name}: ${error.message}');
}
```

### Client with shared config

```dart
final client = createClient(
  headers: {'X-App-Version': '1.0.0'},
  config: ValyncClientConfig(
    headers: () => {'Authorization': 'Bearer $token'},
    onError: (error) async {
      if (error.code.unwrapOr('') == '401') {
        await refreshToken();
        return true; // true = retry the request once
      }
      return false;
    },
  ),
);

// GET
final result = await client<User>('https://api.example.com/me');

// POST with JSON body
final result = await client<User>(
  'https://api.example.com/users',
  method: HttpMethod.post,
  body: {'name': 'Alice'},
);

// POST with multipart files
final result = await client<User>(
  'https://api.example.com/avatar',
  method: HttpMethod.post,
  files: [await http.MultipartFile.fromPath('avatar', '/path/to/file.jpg')],
);
```

### List responses

Use `ListResponse` when the API returns an array as `data`:

```dart
final result = await client<ListResponse>('https://api.example.com/users');

switch (result) {
  case Ok(:final value):
    final users = value.apply((e) => User().fromJson(e));
    print(users.map((u) => u.name).join(', '));
  case Err(:final error):
    print(error);
}
```

### No-body responses

Use `EmptyResponse` for endpoints that return `204 No Content` or a bare success:

```dart
final result = await client<EmptyResponse>(
  'https://api.example.com/logout',
  method: HttpMethod.post,
);

switch (result) {
  case Ok():
    print('logged out');
  case Err(:final error):
    print(error);
}
```

### Raw JSON object

Use `JsonObjectResponse` when you need to map `data` yourself:

```dart
final result = await client<JsonObjectResponse>('https://api.example.com/config');

switch (result) {
  case Ok(:final value):
    final config = value.apply((e) => AppConfig.fromJson(e));
    print(config.featureFlags);
  case Err(:final error):
    print(error);
}
```

### Supported HTTP methods

`HttpMethod.get`, `HttpMethod.post`, `HttpMethod.put`, `HttpMethod.patch`, `HttpMethod.delete`

## API

### `valync<T>(url, {...})`

Stateless one-off request.

```dart
Future<Result<T, ApiError>> valync<T>(
  String url, {
  HttpMethod method = HttpMethod.get,
  Map<String, dynamic>? body,
  Map<String, String>? headers,
  List<http.MultipartFile>? files,
})
```

### `createClient({headers, config})`

Returns a `ValyncClient` with shared configuration.

```dart
ValyncClient createClient({
  Map<String, String>? headers,
  ValyncClientConfig config = const ValyncClientConfig(),
})
```

### `ValyncClientConfig`

| Field | Type | Description |
|-------|------|-------------|
| `headers` | `Map<String, String> Function()?` | Dynamic headers merged into every request (e.g. auth tokens) |
| `onError` | `Future<bool> Function(ApiError)?` | Called on error — return `true` to retry the request once |

### `ApiError`

| Field | Type | Description |
|-------|------|-------------|
| `name` | `String` | Machine-readable error identifier |
| `message` | `String` | Human-readable description |
| `code` | `Option<String>` | Optional error code |

Built-in error names: `ServerUnreacheable`, `InternalServerError`, `UnknownError`.

### Built-in response types

| Type | Use when `data` is |
|------|--------------------|
| `EmptyResponse` | absent or irrelevant (e.g. 204) |
| `ListResponse` | a JSON array — use `.apply((e) => T.fromJson(e))` to map |
| `JsonObjectResponse` | an arbitrary value — use `.apply((e) => T.fromJson(e))` to map |

### `registerFactory(Type, JsonType)`

Register a factory manually without code generation:

```dart
registerFactory(User, User(id: '', name: ''));
```

## API response contract

The package expects responses in this shape:

```json
{ "status": "success", "data": { ... } }
{ "status": "failed",  "error": { "name": "...", "message": "...", "code": "..." } }
```

`204 No Content` responses are treated as success with no data.

## Example

A runnable Flutter example app is available in [`examples/basic`](examples/basic).
It demonstrates one-off requests, list responses, empty responses, error handling,
and `createClient` — all using a mock HTTP client, no server required.

## Additional information

- Issues and contributions: open a GitHub issue or pull request
- Built on [`option_result`](https://pub.dev/packages/option_result), [`http`](https://pub.dev/packages/http), and [`source_gen`](https://pub.dev/packages/source_gen)
