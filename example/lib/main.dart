import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tracex/tracex.dart';

final TraceX tracex = TraceX(
  buttonSize: 48.0,
  edgeMargin: 6.0,
  customFab: (isOpen) => MyCustomFab(isOpen: isOpen),
  logger: TraceXPrettyLogger(
    enabled: kDebugMode,
    compact: true,
    responseHeader: false,
  ),
);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blueGrey.shade900,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  late final Dio _dio;

  @override
  void initState() {
    super.initState();

    _dio = Dio()
      ..options.contentType = Headers.jsonContentType
      ..interceptors.add(
        TraceXDioInterceptor(tracex),
      );

    tracex.attach(context);
  }

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TraceX Example'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.terminal_outlined),
              title: const Text('TraceX console'),
              subtitle: const Text(
                'Tap to open the console.',
              ),
              onTap: () {
                tracex.openConsole(context);
              },
            ),
            const Divider(height: 40),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HTTP Requests',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () async {
                    try {
                      await _dio.get('https://jsonplaceholder.typicode.com/posts');
                    } catch (e) {
                      tracex.log(e);
                    }
                  },
                  child: const Text('GET'),
                ),
                FilledButton.tonal(
                  onPressed: () async {
                    try {
                      await _dio.post(
                        'https://jsonplaceholder.typicode.com/posts',
                        data: {
                          'title': 'TraceX Test Post',
                          'body': 'This is a test post body',
                          'userId': 1,
                        },
                      );
                    } catch (e) {
                      tracex.log(e);
                    }
                  },
                  child: const Text('POST'),
                ),
                FilledButton.tonal(
                  onPressed: () async {
                    try {
                      await _dio.put('https://jsonplaceholder.typicode.com/posts');
                    } catch (e) {
                      tracex.log(e);
                    }
                  },
                  child: const Text('PUT'),
                ),
                FilledButton.tonal(
                  onPressed: () async {
                    try {
                      await _dio.delete('https://jsonplaceholder.typicode.com/posts/1');
                    } catch (e) {
                      tracex.log(e);
                    }
                  },
                  child: const Text('DELETE'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
        shape: BoxShape.circle,
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
        size: 24,
      ),
    );
  }
}
