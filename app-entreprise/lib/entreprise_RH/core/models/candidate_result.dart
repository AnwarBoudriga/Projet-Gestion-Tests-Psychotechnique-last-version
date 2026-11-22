class ResultLine {
  const ResultLine({
    required this.question,
    required this.chosen,
    required this.correct,
    required this.earned,
    required this.points,
  });

  /// API: élément de `questions` dans GET /api/entreprise/resultats/:invitationId.
  factory ResultLine.fromJson(Map<String, dynamic> j) {
    final options = (j['options'] as Map?) ?? const {};
    String label(dynamic letter) {
      if (letter == null) return 'Sans réponse';
      return '$letter. ${options[letter] ?? ''}';
    }

    return ResultLine(
      question: '${j['enonce'] ?? ''}',
      chosen: label(j['reponseCandidat']),
      correct: label(j['reponseCorrecte']),
      earned: (j['pointsObtenus'] as num?)?.toInt() ?? 0,
      points: (j['points'] as num?)?.toInt() ?? 0,
    );
  }

  final String question;
  final String chosen;
  final String correct;
  final int earned;
  final int points;
}

/// Alerte de surveillance (règle déclenchée par le service proctoring).
class RiskAlert {
  const RiskAlert({required this.regle, required this.detail, required this.points});

  factory RiskAlert.fromJson(Map<String, dynamic> j) => RiskAlert(
        regle: '${j['regle'] ?? ''}',
        detail: '${j['detail'] ?? ''}',
        points: (j['points'] as num?)?.toInt() ?? 0,
      );

  final String regle;
  final String detail;
  final int points;
}

/// Score de risque (0-100) calculé par le service Spring. Il SIGNALE, il ne prouve rien.
class RiskInfo {
  const RiskInfo({
    required this.score,
    required this.niveau,
    this.alertes = const [],
    this.paysDepart,
    this.paysFin,
  });

  /// API: `risque` dans /resultats (résumé) ou /resultats/:id (détail avec alertes).
  factory RiskInfo.fromJson(Map<String, dynamic> j) => RiskInfo(
        score: (j['scoreRisque'] as num?)?.toInt() ?? 0,
        niveau: '${j['niveau'] ?? 'FAIBLE'}',
        alertes: [
          for (final a in (j['alertes'] as List? ?? const []))
            RiskAlert.fromJson(Map<String, dynamic>.from(a as Map)),
        ],
        paysDepart: j['paysDepart'] as String?,
        paysFin: j['paysFin'] as String?,
      );

  final int score;

  /// FAIBLE | MOYEN | ELEVE
  final String niveau;
  final List<RiskAlert> alertes;
  final String? paysDepart;
  final String? paysFin;
}

class CandidateResult {
  const CandidateResult({
    required this.invitationId,
    required this.candidate,
    required this.email,
    required this.testTitle,
    required this.score,
    required this.total,
    required this.percent,
    required this.passed,
    this.lines = const [],
    this.risk,
  });

  /// API: GET /api/entreprise/resultats (liste) ou /resultats/:invitationId (détail + questions).
  factory CandidateResult.fromJson(Map<String, dynamic> j) => CandidateResult(
        invitationId: '${j['invitationId']}',
        candidate: '${j['candidat'] ?? ''}',
        email: '${j['email'] ?? ''}',
        testTitle: '${j['test'] ?? ''}',
        score: (j['score'] as num?)?.toInt() ?? 0,
        total: (j['scoreMax'] as num?)?.toInt() ?? 0,
        percent: (j['pourcentage'] as num?)?.toDouble() ?? 0,
        passed: j['reussi'] == true,
        risk: j['risque'] is Map
            ? RiskInfo.fromJson(Map<String, dynamic>.from(j['risque'] as Map))
            : null,
        lines: [
          for (final q in (j['questions'] as List? ?? const []))
            ResultLine.fromJson(Map<String, dynamic>.from(q as Map)),
        ],
      );

  final String invitationId;
  final String candidate;
  final String email;
  final String testTitle;
  final int score;
  final int total;
  final double percent;
  final bool passed;

  /// Vide dans la liste; rempli par le détail.
  final List<ResultLine> lines;

  /// Surveillance : null si aucune donnée (service arrêté ou candidat non surveillé).
  final RiskInfo? risk;
}
