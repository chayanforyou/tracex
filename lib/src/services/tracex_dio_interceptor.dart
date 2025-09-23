import 'package:dio/dio.dart';
import 'package:tracex/tracex.dart';

class TraceXDioInterceptor extends Interceptor {
  final TraceX _tracex;

  TraceXDioInterceptor(this._tracex);

  final _cache = <RequestOptions, DateTime>{};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _cache[options] = DateTime.now();

    return super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final Map<String, String> responseHeaders = response.headers.map.map(
          (key, value) => MapEntry(key, value.join(', ')),
    );
    final sentAt = _cache[response.requestOptions];
    final receivedAt = DateTime.now();

    _tracex.network(
      request: NetworkRequestEntry(
        url: response.requestOptions.uri.toString(),
        method: response.requestOptions.method,
        headers: response.requestOptions.headers,
        body: response.requestOptions.data,
        sentAt: sentAt,
      ),
      response: NetworkResponseEntry(
        statusCode: response.statusCode,
        headers: responseHeaders,
        body: response.data,
        receivedAt: receivedAt,
      ),
    );

    return super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final Map<String, String>? responseHeaders = err.response?.headers.map.map(
          (key, value) => MapEntry(key, value.join(', ')),
    );

    _tracex.network(
      request: NetworkRequestEntry(
        url: err.requestOptions.uri.toString(),
        method: err.requestOptions.method,
        headers: err.requestOptions.headers,
        body: err.requestOptions.data,
      ),
      response: NetworkResponseEntry(
        statusCode: err.response?.statusCode ?? 0,
        headers: responseHeaders,
        body: err.response?.data,
      ),
    );

    return super.onError(err, handler);
  }
}