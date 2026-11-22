import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

int _toInt(dynamic v) => v is num ? v.toInt() : (int.tryParse('$v') ?? 0);

// ─────────────────────────── Modèles ───────────────────────────

/// GET /api/candidat/test
class TestInfo {
  const TestInfo({
    required this.titre,
    required this.description,
    required this.dureeMinutes,
    required this.nbQuestions,
    required this.statut,
    required this.resteSecondes,
    required this.candidat,
  });

  final String titre;
  final String? description;
  final int dureeMinutes;
  final int nbQuestions;

  /// invite | en_cours | termine | expire
  final String statut;
  final int? resteSecondes;
  final String candidat;

  factory TestInfo.fromJson(Map<String, dynamic> j) => TestInfo(
        titre: j['titre']?.toString() ?? '',
        description: j['description']?.toString(),
        dureeMinutes: _toInt(j['dureeMinutes']),
        nbQuestions: _toInt(j['nbQuestions']),
        statut: j['statut']?.toString() ?? 'invite',
        resteSecondes:
            j['resteSecondes'] == null ? null : _toInt(j['resteSecondes']),
        candidat: j['candidat']?.toString() ?? '',
      );
}

class Question {
  const Question({
    required this.id,
    required this.position,
    required this.enonce,
    required this.points,
    required this.options,
  });

  final int id;
  final int position;
  final String enonce;
  final int points;

  /// {'A': '...', 'B': '...', ...} (les options vides sont ignorées)
  final Map<String, String> options;

  factory Question.fromJson(Map<String, dynamic> j) {
    final raw = Map<String, dynamic>.from((j['options'] as Map?) ?? const {});
    final opts = <String, String>{};
    for (final k in const ['A', 'B', 'C', 'D']) {
      final v = raw[k];
      if (v != null && v.toString().trim().isNotEmpty) opts[k] = v.toString();
    }
    return Question(
      id: _toInt(j['id']),
      position: _toInt(j['position']),
      enonce: j['enonce']?.toString() ?? '',
      points: _toInt(j['points']),
      options: opts,
    );
  }
}

/// POST /api/candidat/test/demarrer  et  GET /api/candidat/test/questions
class TestContent {
  const TestContent({
    required this.titre,
    required this.dureeMinutes,
    required this.resteSecondes,
    required this.total,
    required this.repondues,
    required this.questions,
    required this.reponses,
  });

  final String titre;
  final int dureeMinutes;
  final int resteSecondes;
  final int total;
  final int repondues;
  final List<Question> questions;

  /// questionId -> choix ('A'..'D'), pour la reprise après rafraîchissement
  final Map<int, String> reponses;

  factory TestContent.fromJson(Map<String, dynamic> j) {
    final rep = <int, String>{};
    final rawRep = (j['reponses'] as Map?) ?? const {};
    rawRep.forEach((k, v) => rep[_toInt(k)] = v.toString());
    final qs = ((j['questions'] as List?) ?? const [])
        .map((e) => Question.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return TestContent(
      titre: j['titre']?.toString() ?? '',
      dureeMinutes: _toInt(j['dureeMinutes']),
      resteSecondes: _toInt(j['resteSecondes']),
      total: _toInt(j['total']),
      repondues: _toInt(j['repondues']),
      questions: qs,
      reponses: rep,
    );
  }
}

/// POST /api/candidat/test/soumettre  et  GET /api/candidat/test/resultat
class TestResult {
  const TestResult({
    required this.titre,
    required this.scoreVisible,
    this.score,
    this.scoreMax,
  });

  final String titre;
  final bool scoreVisible;
  final int? score;
  final int? scoreMax;

  factory TestResult.fromJson(Map<String, dynamic> j) => TestResult(
        titre: j['titre']?.toString() ?? '',
        scoreVisible: j['scoreVisible'] == true,
        score: j['score'] == null ? null : _toInt(j['score']),
        scoreMax: j['scoreMax'] == null ? null : _toInt(j['scoreMax']),
      );
}

// ─────────────────────────── Client HTTP ───────────────────────────

/// Client HTTP de l'espace Candidat (Dio).
///
/// URL de l'API : flutter run --dart-define=API_URL=http://10.0.2.2:3000
/// Le token candidat est stocké sous une clé distincte ('candidat_token').
class CandidatApi {
  CandidatApi._();

  /// Accepte avec ou sans le suffixe /api (les chemins ci-dessous incluent déjà /api).
  static const String _rawUrl =
      String.fromEnvironment('API_URL', defaultValue: 'http://localhost:3000');
  static final String baseUrl =
      _rawUrl.replaceFirst(RegExp(r'/+$'), '').replaceFirst(RegExp(r'/api$'), '');

  static const _tokenKey = 'candidat_token';
  static const _storage = FlutterSecureStorage();

  /// Appelé quand l'API répond 401 (session expirée ou invitation invalidée).
  static VoidCallback? onUnauthorized;

  static final Dio dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    contentType: Headers.jsonContentType,
  ))
    ..interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: _tokenKey);
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (e, handler) async {
        final isLogin = e.requestOptions.path.contains('/auth/login');
        if (e.response?.statusCode == 401 && !isLogin) {
          await logout();
          onUnauthorized?.call();
        }
        handler.next(e);
      },
    ));

  static Future<bool> hasToken() async =>
      (await _storage.read(key: _tokenKey)) != null;

  static Future<void> logout() => _storage.delete(key: _tokenKey);

  static Map<String, dynamic> _map(Response r) =>
      Map<String, dynamic>.from(r.data as Map);

  /// POST /api/candidat/auth/login  { cle }  ->  statut (invite | en_cours | termine)
  static Future<String> login(String cle) async {
    final r = await dio.post('/api/candidat/auth/login', data: {'cle': cle.trim()});
    final d = _map(r);
    await _storage.write(key: _tokenKey, value: d['token'] as String);
    return d['statut']?.toString() ?? 'invite';
  }

  static Future<TestInfo> info() async =>
      TestInfo.fromJson(_map(await dio.get('/api/candidat/test')));

  static Future<TestContent> demarrer() async =>
      TestContent.fromJson(_map(await dio.post('/api/candidat/test/demarrer')));

  static Future<TestContent> questions() async =>
      TestContent.fromJson(_map(await dio.get('/api/candidat/test/questions')));

  static Future<void> repondre(int questionId, String choix) =>
      dio.put('/api/candidat/test/reponses/$questionId', data: {'choix': choix});

  static Future<TestResult> soumettre() async =>
      TestResult.fromJson(_map(await dio.post('/api/candidat/test/soumettre')));

  static Future<TestResult> resultat() async =>
      TestResult.fromJson(_map(await dio.get('/api/candidat/test/resultat')));

  static int? statusCode(Object e) => e is DioException ? e.response?.statusCode : null;

  /// Message lisible à partir d'une erreur Dio (format API : {message, errors[]}).
  static String errorMessage(Object e) {
    if (e is DioException) {
      final d = e.response?.data;
      if (d is Map) {
        final errs = d['errors'];
        if (errs is List && errs.isNotEmpty) {
          return errs.map((x) => x['message']).join('\n');
        }
        if (d['message'] != null) return d['message'].toString();
      }
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return 'Serveur injoignable.';
      }
    }
    return 'Une erreur est survenue.';
  }
}
