# Core Module

This module contains the core infrastructure and utilities used throughout the application.

## Structure

```
core/
├── constants/          # Application-wide constants
│   └── app_constants.dart
├── di/                 # Dependency Injection
│   └── injection_container.dart
├── error/              # Error handling
│   ├── exceptions.dart
│   └── failures.dart
└── utils/              # Utility functions
    └── logger.dart
```

## Error Handling

The application uses a two-tier error handling approach:

1. **Exceptions**: Used in the data layer when operations fail
2. **Failures**: Used in the domain layer to represent business logic failures

### Exception Types
- `NetworkException`: Network-related errors
- `ExtensionException`: Extension loading/execution errors
- `StorageException`: Local storage errors
- `AuthenticationException`: Authentication errors
- `ValidationException`: Data validation errors
- `ServerException`: Server-side errors
- `CacheException`: Cache-related errors

### Failure Types
- `NetworkFailure`: Network-related failures
- `ExtensionFailure`: Extension-related failures
- `StorageFailure`: Storage-related failures
- `AuthenticationFailure`: Authentication failures
- `ValidationFailure`: Validation failures
- `ServerFailure`: Server failures
- `CacheFailure`: Cache failures
- `UnknownFailure`: Unknown failures

## Dependency Injection

The application uses GetIt for dependency injection. All dependencies are registered in `injection_container.dart`.

### Usage

```dart
import 'package:aniya/core/di/injection_container.dart';

// Get a dependency
final myDependency = sl<MyDependency>();
```

## Logger

A simple logging utility that only logs in debug mode.

### Usage

```dart
import 'package:aniya/core/utils/logger.dart';

Logger.info('Information message', tag: 'MyTag');
Logger.error('Error message', tag: 'MyTag', error: e, stackTrace: st);
Logger.warning('Warning message', tag: 'MyTag');
Logger.debug('Debug message', tag: 'MyTag');
```

## Constants

Application-wide constants are defined in `app_constants.dart`.

### Categories
- App Info
- Storage Keys
- API Configuration
- Pagination
- Performance
- Download
