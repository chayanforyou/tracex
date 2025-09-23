# TraceX

Advanced In-App Debugging Console for Flutter Applications with Network Monitoring

[![pub package](https://img.shields.io/pub/v/tracex.svg)](https://pub.dev/packages/tracex)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Features

*  **In-app console**: Monitor your app inside your app
*  **Network inspector**: Track API calls and responses with beautiful formatting
*  **Custom FAB**: Use your own floating action button design
*  **Auto-stash**: FAB automatically hides to screen edge after inactivity
*  **Search & filter**: Find specific logs quickly
*  **Copy & export**: Share debug logs with your team
*  **Pretty logging**: Beautiful formatted console output
*  **Performance optimized**: Lightweight and efficient
*  **Theme support**: Adapts to your app's theme

##  Screenshots

| Console                                                                  | Network Logs                                                             | Custom FAB                                                           |
|--------------------------------------------------------------------------|--------------------------------------------------------------------------|----------------------------------------------------------------------|
| ![Console](https://github.com/chayanforyou/tracex/blob/master/doc/1.png) | ![Network](https://github.com/chayanforyou/tracex/blob/master/doc/2.png) | ![FAB](https://github.com/chayanforyou/tracex/blob/master/doc/3.png) |

##  Getting Started

### Add to pubspec.yaml

```yaml
dependencies:
  tracex: ^1.0.0
```

Then run `flutter pub get`.

##  Usage

### Initialize

Create a global `TraceX` instance:

```dart
final TraceX tracex = TraceX(
  // Custom floating action button
  customFab: (isOpen) => MyCustomFab(isOpen: isOpen),
  
  // Pretty logger for beautiful console output
  logger: TraceXPrettyLogger(
    compact: true,
    maxWidth: 100,
  ),
  
  // Button size and edge margin
  buttonSize: 48.0,
  edgeMargin: 6.0,
  
  // Log buffer length
  logBufferLength: 2500,
);
```

### Enable the debug console

#### In debug mode

Attach the floating button to the widget tree:

```dart
@override
void initState() {
  super.initState();
  
  tracex.attach(context);
}
```

#### Open console manually

```dart
tracex.openConsole(context);
```

### Log network requests

#### With Dio

```dart
dio.interceptors.add(TraceXDioInterceptor(tracex));
```

#### With other HTTP clients

```dart
// After your HTTP request:
tracex.network(
  request: NetworkRequestEntry(
    method: 'POST',
    url: endpoint,
    headers: headers,
    body: body,
  ),
  response: NetworkResponseEntry(
    statusCode: response.statusCode,
    headers: response.headers,
    body: response.body,
  ),
);
```

### Log messages

```dart
tracex.log('Hello World!');
```

### Custom FAB Example

```dart
class MyCustomFab extends StatelessWidget {
  final bool isOpen;

  const MyCustomFab({
    super.key,
    required this.isOpen,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOpen
              ? [const Color(0xFFe74c3c), const Color(0xFFc0392b)]
              : [const Color(0xFF667eea), const Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        isOpen ? Icons.close_rounded : Icons.bug_report_rounded,
        color: Colors.white,
        size: 28,
      ),
    );
  }
}
```

##  Pretty Logger

TraceX includes a beautiful pretty logger inspired by [PrettyDioLogger](https://github.com/Milad-Akarie/pretty_dio_logger):

```dart
final TraceX tracex = TraceX(
  prettyLogger: TraceXPrettyLogger(
    enabled: true,
    compact: true,
    maxWidth: 90,
    request: true,
    requestHeader: true,
    requestBody: true,
    responseHeader: true,
    responseBody: true,
  ),
);
```

##  Advanced Features

### Auto-stash FAB

The FAB automatically stashes to the nearest screen edge after 3 seconds of inactivity and can be unstashed by tapping.

### Search & Filter

- Search through logs by text
- Filter by log type
- Clear search to show all logs

### Theme Integration

TraceX automatically adapts to your app's theme using Material 3 design principles.

##  Example

See the complete example in the `/example` folder of this repository.

##  License

MIT License - see [LICENSE](LICENSE) file.

##  Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

##  Support

If you encounter any problems or have suggestions, please file an issue at the [GitHub repository](https://github.com/chayanforyou/tracex/issues).

---

**TraceX** - Making Flutter debugging beautiful and efficient! 🚀
