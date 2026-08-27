import 'dart:io';
import '../core/api_client.dart';

/// Wraps the chat-specific HTTP calls shared by chat_page.dart (client side)
/// and am/workspace/chat_tab.dart (AM side) — two ~1230-line near-duplicate
/// files, both with zero test coverage and both wiring ReverbService directly
/// into initState. Migrating either screen means untangling that duplication
/// and making the realtime dependency injectable first, which is a bigger,
/// separate piece of work (see docs/state-layer-migration-plan.md, Chat
/// slice notes) — this repository only builds the foundation so that future
/// work doesn't have to start from raw ApiClient calls.
///
/// Raw maps/lists throughout, no model: chat messages carry a varied,
/// evolving shape (attachments, contract references, action-required
/// state, reply-to) that isn't worth locking into a class before an actual
/// screen migration settles what fields are really needed.
class ChatRepository {
  final ApiClient _api;
  ChatRepository({ApiClient? api}) : _api = api ?? ApiClient();

  /// GET /workspaces/:id — used by both screens to load the workspace header
  /// (name, status, client/manager info) alongside the chat thread.
  Future<Map<String, dynamic>> fetchWorkspace(int workspaceId) => _api.get('/workspaces/$workspaceId');

  Future<List<dynamic>> fetchMessages(int workspaceId) async {
    final res = await _api.get('/workspaces/$workspaceId/chat');
    return safeList(res['messages']);
  }

  Future<void> markRead(int workspaceId) => _api.post('/workspaces/$workspaceId/chat/mark-read', {});

  /// [replyToId] is only included in the request body when non-null, matching
  /// the original inline behavior in both screens.
  Future<void> sendMessage(int workspaceId, String message, {int? replyToId}) {
    final body = <String, dynamic>{'message': message};
    if (replyToId != null) body['reply_to_id'] = replyToId;
    return _api.post('/workspaces/$workspaceId/chat', body);
  }

  Future<void> editMessage(int messageId, String message) => _api.put('/chat/$messageId', {'message': message});

  /// AM-only: flags a message as requiring the client's action.
  Future<void> requireAction(int messageId) => _api.patch('/chat/$messageId/require-action', {});

  Future<void> uploadFile(int workspaceId, File file) =>
      _api.multipartPost('/workspaces/$workspaceId/chat', {}, file: file, fileField: 'file');

  /// [reason] is only included in the request body when non-null, matching
  /// the original inline behavior (used for the 'edit_requested' action).
  Future<void> respond(int messageId, {required String action, String? reason}) {
    final body = <String, dynamic>{'action': action};
    if (reason != null) body['reason'] = reason;
    return _api.post('/chat/$messageId/respond', body);
  }
}
