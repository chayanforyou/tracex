import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:material_ui/material_ui.dart';
import 'package:tracex/tracex.dart';

final TraceX tracex = TraceX(
  buttonSize: 48.0,
  edgeMargin: 6.0,
  logBufferLength: 5,
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

    tracex.attach(
      context: context,
      visible: kDebugMode,
    );
  }

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }

  /// Runs [request] and swallows [DioException]s, which
  /// [TraceXDioInterceptor] has already logged.
  Future<void> _send(Future<Response> Function() request) async {
    try {
      await request();
    } on DioException catch (_) {}
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
            Text(
              'HTTP Requests',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () async {
                await _send(() =>
                    _dio.get('https://jsonplaceholder.typicode.com/posts'));
              },
              child: const Text('GET'),
            ),
            FilledButton.tonal(
              onPressed: () async {
                final jsonString =
                    await rootBundle.loadString('assets/sample.json');
                final data = jsonDecode(jsonString);

                await _send(
                  () => _dio.post('https://jsonplaceholder.typicode.com/posts',
                      data: data),
                );
              },
              child: const Text('POST (sample.json)'),
            ),
            FilledButton.tonal(
              onPressed: () async {
                final jsonString =
                    await rootBundle.loadString('assets/large_sample.json');
                final data = jsonDecode(jsonString);

                await _send(
                  () => _dio.post('https://jsonplaceholder.typicode.com/posts',
                      data: data),
                );
              },
              child: const Text('POST (large_sample.json)'),
            ),
            FilledButton.tonal(
              onPressed: () async {
                // Built in memory, so no temp files and it also runs on web.
                // Shows each kind of field TraceX formats: plain strings,
                // a JSON field, a repeated key, a single file and several
                // files under one key.
                final formData = FormData()
                  ..fields.addAll([
                    const MapEntry('title', 'Weekend trip'),
                    const MapEntry('user_id', '123'),
                    const MapEntry('is_public', 'true'),
                    MapEntry(
                      'location',
                      jsonEncode({'lat': 23.8103, 'lng': 90.4125}),
                    ),
                    const MapEntry('tags[]', 'travel'),
                    const MapEntry('tags[]', 'beach'),
                  ])
                  ..files.addAll([
                    MapEntry(
                      'photo',
                      MultipartFile.fromBytes(
                        List.generate(2048, (i) => i % 256),
                        filename: 'beach.jpg',
                        contentType: DioMediaType('image', 'jpeg'),
                      ),
                    ),
                    MapEntry(
                      'attachments',
                      MultipartFile.fromString(
                        'Pack sunscreen.\nLeave at 7am.',
                        filename: 'notes.txt',
                        contentType: DioMediaType('text', 'plain'),
                      ),
                    ),
                    MapEntry(
                      'attachments',
                      MultipartFile.fromBytes(
                        List.generate(4096, (i) => (i * 7) % 256),
                        filename: 'itinerary.pdf',
                        contentType: DioMediaType('application', 'pdf'),
                      ),
                    ),
                  ]);

                await _send(
                  () => _dio.post(
                    'https://jsonplaceholder.typicode.com/posts',
                    data: formData,
                  ),
                );
              },
              child: const Text('POST (Multipart Body)'),
            ),
            FilledButton.tonal(
              onPressed: () async {
                await _send(() =>
                    _dio.put('https://jsonplaceholder.typicode.com/posts/1'));
              },
              child: const Text('PUT'),
            ),
            FilledButton.tonal(
              onPressed: () async {
                await _send(() => _dio
                    .delete('https://jsonplaceholder.typicode.com/posts/1'));
              },
              child: const Text('DELETE'),
            ),
            FilledButton.tonal(
              onPressed: () async {
                await _send(() =>
                    _dio.get('https://jsonplaceholder.typicode.com/invalid'));
              },
              child: const Text('Error (404)'),
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
