import 'package:flutter/material.dart';

import '../core/candidat_api.dart';
import '../core/proctoring_api.dart';
import '../widgets/candidat_scaffold.dart';
import 'intro_view.dart';
import 'result_view.dart';
import 'test_view.dart';

enum _Phase { loading, intro, test, result, expired, error }

/// Espace candidat complet. L'écran affiché dépend du statut renvoyé par le
/// backend : invite -> présentation, en_cours -> test (reprise), termine -> score,
/// expire -> invitation expirée.
class CandidatFlow extends StatefulWidget {
  const CandidatFlow({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  State<CandidatFlow> createState() => _CandidatFlowState();
}

class _CandidatFlowState extends State<CandidatFlow> {
  _Phase _phase = _Phase.loading;
  TestInfo? _info;
  TestContent? _content;
  TestResult? _result;
  String _error = '';
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Recharge l'état depuis le serveur.
  /// [retry] : si le serveur répond 409 (ex. temps écoulé -> soumission automatique),
  /// on recharge une seule fois pour afficher l'écran de résultat.
  Future<void> _load({bool retry = true}) async {
    if (mounted) setState(() => _phase = _Phase.loading);
    try {
      final info = await CandidatApi.info();
      TestContent? content;
      TestResult? result;
      _Phase next;
      switch (info.statut) {
        case 'termine':
          result = await CandidatApi.resultat();
          next = _Phase.result;
          break;
        case 'expire':
          next = _Phase.expired;
          break;
        case 'en_cours':
          content = await CandidatApi.questions();
          ProctoringApi.demarrer(); // reprise : idempotent
          next = _Phase.test;
          break;
        default:
          next = _Phase.intro;
      }
      if (!mounted) return;
      setState(() {
        _info = info;
        _content = content;
        _result = result;
        _phase = next;
      });
    } catch (e) {
      final s = CandidatApi.statusCode(e);
      if (s == 409 && retry) {
        await _load(retry: false);
        return;
      }
      if (!mounted) return;
      if (s == 410) {
        setState(() => _phase = _Phase.expired);
        return;
      }
      setState(() {
        _error = CandidatApi.errorMessage(e);
        _phase = _Phase.error;
      });
    }
  }

  Future<void> _start() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      final c = await CandidatApi.demarrer();
      ProctoringApi.demarrer(); // début de la surveillance (ne bloque pas)
      if (!mounted) return;
      setState(() {
        _content = c;
        _phase = _Phase.test;
        _starting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _starting = false);
      _toast(CandidatApi.errorMessage(e));
      final s = CandidatApi.statusCode(e);
      if (s == 409 || s == 410) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    switch (_phase) {
      case _Phase.loading:
        body = const Padding(
          padding: EdgeInsets.only(top: 80),
          child: Center(child: CircularProgressIndicator()),
        );
        break;
      case _Phase.intro:
        body = IntroView(info: _info!, onStart: _start, starting: _starting);
        break;
      case _Phase.test:
        body = TestView(
          // Nouvelle clé à chaque rechargement pour repartir d'un état propre.
          key: ValueKey(_content),
          content: _content!,
          onSubmitted: (r) => setState(() {
            _result = r;
            _phase = _Phase.result;
          }),
          onReload: _load,
        );
        break;
      case _Phase.result:
        body = ResultView(result: _result!, onLogout: widget.onLogout);
        break;
      case _Phase.expired:
        body = ExpiredView(onLogout: widget.onLogout);
        break;
      case _Phase.error:
        body = LoadErrorView(message: _error, onRetry: _load, onLogout: widget.onLogout);
        break;
    }
    return CandidatScaffold(onLogout: widget.onLogout, child: body);
  }
}
