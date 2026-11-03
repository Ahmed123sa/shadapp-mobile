import '../core/api_client.dart';

/// CLIENT_ASSISTANT_PLAN.md ٨ — what the client assistant shows. The server
/// builds every sentence in both languages from the client's own data (and the
/// wording the super admin set), so this is a plain read with no logic of its
/// own: pick the language and show it.
class AssistantQuestion {
  final int? id;
  final String? key;
  final String kind; // data | faq
  final Map<String, String> question;
  final Map<String, String> answer;
  final double? progressPaid;
  final double? progressTotal;
  final List<String> actions; // workspace tabs: contracts, payments, chat...

  const AssistantQuestion({
    required this.id,
    required this.key,
    required this.kind,
    required this.question,
    required this.answer,
    required this.progressPaid,
    required this.progressTotal,
    required this.actions,
  });

  factory AssistantQuestion.fromJson(Map<String, dynamic> j) {
    final progress = j['progress'];
    return AssistantQuestion(
      id: j['id'] as int?,
      key: j['key'] as String?,
      kind: (j['kind'] ?? 'data').toString(),
      question: _pair(j['question']),
      answer: _pair(j['answer']),
      progressPaid: progress is Map ? double.tryParse(progress['paid']?.toString() ?? '') : null,
      progressTotal: progress is Map ? double.tryParse(progress['total']?.toString() ?? '') : null,
      actions: [
        for (final a in (j['actions'] as List<dynamic>? ?? const []))
          if (a is Map && a['target'] != null) a['target'].toString(),
      ],
    );
  }

  /// Same id and key = the same question after a refresh.
  bool sameAs(AssistantQuestion o) => id == o.id && key == o.key;

  String q(String lang) => question[lang] ?? question['en'] ?? '';
  String a(String lang) => answer[lang] ?? answer['en'] ?? '';
}

class AssistantData {
  final bool enabled;
  final Map<String, String> name;
  final Map<String, String> welcome;
  final List<AssistantQuestion> questions;

  const AssistantData({required this.enabled, required this.name, required this.welcome, required this.questions});

  static const off = AssistantData(enabled: false, name: {}, welcome: {}, questions: []);

  factory AssistantData.fromJson(Map<String, dynamic> j) {
    if (j['enabled'] != true) return off;
    final assistant = j['assistant'] as Map<String, dynamic>? ?? const {};
    return AssistantData(
      enabled: true,
      name: _pair(assistant['name']),
      welcome: _pair(assistant['welcome']),
      questions: [
        for (final q in (j['questions'] as List<dynamic>? ?? const []))
          if (q is Map<String, dynamic>) AssistantQuestion.fromJson(q),
      ],
    );
  }

  String nameIn(String lang) => name[lang] ?? name['en'] ?? '';
  String welcomeIn(String lang) => welcome[lang] ?? welcome['en'] ?? '';
}

Map<String, String> _pair(dynamic v) {
  if (v is! Map) return const {};
  return {for (final e in v.entries) e.key.toString(): (e.value ?? '').toString()};
}

class AssistantRepository {
  final ApiClient _api;
  AssistantRepository({ApiClient? api}) : _api = api ?? ApiClient();

  Future<AssistantData> fetch(int workspaceId) async {
    final res = await _api.get('/workspaces/$workspaceId/assistant');
    return AssistantData.fromJson(res);
  }
}
