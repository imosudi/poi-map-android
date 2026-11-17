import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../logging/app_logger.dart';

/// Creates configured [Dio] instances with timeouts and safe logging.
abstract final class DioFactory {
  static Dio create({
    required AppConfig config,
    required AppLogger logger,
    HttpClientAdapter? adapter,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: config.viennaOgdBaseUrl,
        connectTimeout: config.requestTimeout,
        receiveTimeout: config.requestTimeout,
        sendTimeout: config.requestTimeout,
        responseType: ResponseType.plain,
        headers: const {'Accept': 'application/json'},
      ),
    );

    if (adapter != null) {
      dio.httpClientAdapter = adapter;
    }

    dio.interceptors.add(_SafeNetworkLogInterceptor(logger));
    return dio;
  }
}

final class _SafeNetworkLogInterceptor extends Interceptor {
  _SafeNetworkLogInterceptor(this._logger);

  final AppLogger _logger;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _logger.debug('HTTP', 'Request ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _logger.debug(
      'HTTP',
      'Response ${response.statusCode} ${response.requestOptions.uri}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logger.warning(
      'HTTP',
      'Request failed (${err.type.name}) ${err.requestOptions.uri}',
      context: {'statusCode': err.response?.statusCode},
    );
    handler.next(err);
  }
}
