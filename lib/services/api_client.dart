import 'package:dio/dio.dart';

/// ApiClient configures Dio HTTP clients for fetching Malaysian open data.
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  /// General-purpose Dio for unauthenticated APIs (e.g. data.gov.my).
  late final Dio dio;

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'HappyWay-TravelSafetyApp/1.0',
        },
      ),
    );
    _attachLogger(dio);
  }

  /// Creates a new Dio instance pre-configured for the MET Malaysia API.
  /// The caller must supply the Bearer token loaded from AppConfig.
  static Dio createMetDio(String token) {
    final metDio = Dio(
      BaseOptions(
        baseUrl: 'https://api.met.gov.my/v2.1/',
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'METToken $token',
          'User-Agent': 'HappyWay-TravelSafetyApp/1.0',
        },
      ),
    );
    _attachLogger(metDio);
    return metDio;
  }

  static void _attachLogger(Dio d) {
    d.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.next(options),
        onResponse: (response, handler) => handler.next(response),
        onError: (DioException error, handler) => handler.next(error),
      ),
    );
  }
}
