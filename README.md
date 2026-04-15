# valync

A Flutter package for making typed HTTP requests with automatic JSON deserialization, built-in error handling, and optional auth token refresh.

## Features

- Typed HTTP client — responses are deserialized directly into your Dart models
- Structured API responses with `success`/`failed` status discrimination
- `Result<T, ApiError>` return type (via `option_result`) — no uncaught exceptions
- Auto-generated `JsonType` factories via the `@AutoFactory` annotation and `build_runner`
- Optional `createClient` for shared headers, auth token injection, and automatic token refresh on 401

## Getting started

Add to your `pubspec.yaml`:

```yaml
dependencies:
  valync: ^0.0.1

dev_dependencies:
  build_runner: any
```

Annotate your model with `@AutoFactory` and implement `JsonType<T>`:

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

Run the generator:

```sh
flutter pub run build_runner build
```

## Usage

### Simple one-off request

```dart
final result = await valync<User>('https://api.example.com/users/1');

result.match(
  ok: (user) => print(user.name),
  err: (error) => print('Error: $error'),
);
```

### Client with shared config (auth headers + token refresh)

```dart
final client = createClient(
  config: ValyncClientConfig(
    getAuthHeaders: () => {'Authorization': 'Bearer $token'},
    isUnauthorized: (error) => error.code.unwrapOr('') == '401',
    onUnauthorized: () async => await refreshToken(),
  ),
);

// GET
final result = await client<User>('https://api.example.com/me');

// POST
final result = await client<User>(
  'https://api.example.com/users',
  method: HttpMethod.post,
  body: {'name': 'Alice'},
);
```

### Supported HTTP methods

`HttpMethod.get`, `HttpMethod.post`, `HttpMethod.put`, `HttpMethod.patch`, `HttpMethod.delete`

## API response contract

The package expects responses in this shape:

```json
{ "status": "success", "data": { ... } }
{ "status": "failed",  "error": { "name": "...", "message": "...", "code": "..." } }
```

## Additional information

- Issues and contributions: open a GitHub issue or pull request
- Built on [`option_result`](https://pub.dev/packages/option_result), [`http`](https://pub.dev/packages/http), and [`source_gen`](https://pub.dev/packages/source_gen)
