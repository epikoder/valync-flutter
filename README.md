# valync

A Flutter package for making typed HTTP requests with automatic JSON deserialization, structured success/failure responses, and built-in error handling.

## Features

- Typed HTTP client — responses are deserialized directly into your Dart models
- `Result<T, ApiError>` return type (via `option_result`) — no uncaught exceptions
- Structured API responses with `success`/`failed` status discrimination
- Multipart file upload support
- Auto-generated factory registry via the `@AutoFactory` annotation and `build_runner`
- Optional `createClient` for shared headers and automatic retry on error

## Getting started

Add to your `pubspec.yaml`:

```yaml
dependencies:
  valync: ^0.1.0

dev_dependencies:
  build_runner: any
```

## Setup

### 1. Annotate your models

Implement `JsonType<T>` and annotate with `@AutoFactory`:

```dart
import 'package:valync/valync.dart';
import 'package:valync/annotations.dart';

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

## Usage

### One-off request

```dart
final result = await valync<User>('https://api.example.com/users/1');

result.match(
  ok: (user) => print(user.name),
  err: (error) => print('${error.name}: ${error.message}'),
);
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
        return true; // true = retry the request
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
final result = await client<UploadResponse>(
  'https://api.example.com/upload',
  method: HttpMethod.post,
  body: {'description': 'profile photo'},
  files: [await http.MultipartFile.fromPath('avatar', '/path/to/file.jpg')],
);
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

Returns a `ValyncClient` function with shared configuration.

```dart
ValyncClient createClient({
  Map<String, String>? headers,
  ValyncClientConfig config = const ValyncClientConfig(),
})
```

### `ValyncClientConfig`

| Field | Type | Description |
|-------|------|-------------|
| `headers` | `Map<String, String> Function()?` | Dynamic headers added to every request (e.g. auth tokens) |
| `onError` | `Future<bool> Function(ApiError)?` | Called on error — return `true` to retry the request once |

### `ApiError`

| Field | Type |
|-------|------|
| `name` | `String` |
| `message` | `String` |
| `code` | `Option<String>` |

Built-in error names: `ServerUnreacheable`, `InternalServerError`, `UnknownError`.

### `registerFactory(Type, JsonType)`

Register a factory manually without code generation:

```dart
registerFactory(User, User());
```

## API response contract

The package expects responses in this shape:

```json
{ "status": "success", "data": { ... } }
{ "status": "failed",  "error": { "name": "...", "message": "...", "code": "..." } }
```

`204 No Content` responses are treated as success with no data.

## Additional information

- Issues and contributions: open a GitHub issue or pull request
- Built on [`option_result`](https://pub.dev/packages/option_result), [`http`](https://pub.dev/packages/http), and [`source_gen`](https://pub.dev/packages/source_gen)
