import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Client du service Spring « proctoring-service » (surveillance anti-triche).
///
/// URL : flutter run --dart-define=PROCTORING_URL=http://10.0.2.2:8081
/// Il réutilise le token candidat émis par Node (même JWT_SECRET des deux côtés).
/// Toute erreur est ignorée : la surveillance ne doit JAMAIS bloquer le passage du test.
class ProctoringApi {
  ProctoringApi._();

  static const String _rawUrl =
      String.fromEnvironment('PROCTORING_URL', defaultValue: 'http://localhost:8081');
  static final String baseUrl =
      _rawUrl.replaceFirst(RegExp(r'/+$'), '').replaceFirst(RegExp(r'/api$'), '');

  static const _storage = FlutterSecureStorage();

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 8),
    contentType: Headers.jsonContentType,
  ))
    ..interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'candidat_token');
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
    ));

  /// POST /api/sessions : début de la surveillance (idempotent).
  static Future<void> demarrer() async {
    try {
      await _dio.post('/api/sessions');
    } catch (_) {}
  }

  /// POST /api/events. type : ANSWER | ANSWER_CHANGED | APP_BACKGROUND | APP_RESUME | SCREENSHOT.
  static Future<void> evenement(
    String type, {
    int? questionId,
    String? choix,
    int? tempsMs,
  }) async {
    try {
      await _dio.post('/api/events', data: {
        'type': type,
        if (questionId != null) 'questionId': questionId,
        if (choix != null) 'choix': choix,
        if (tempsMs != null) 'tempsMs': tempsMs.clamp(0, 3600000),
      });
    } catch (_) {}
  }
}
