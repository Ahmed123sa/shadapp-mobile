import 'dart:io';
import 'package:flutter/material.dart';
import '../data/chat_repository.dart';

/// Thin wrapper over [ChatRepository]. Pure pass-throughs — chat_tab.dart and
/// chat_page.dart both own their own message-list/loading/error state (each
/// has its own realtime + polling wiring), so this provider doesn't hold any
/// state of its own, matching the pattern already used for
/// payments_page.dart/payments_tab.dart's PaymentProvider pass-throughs.
class ChatProvider extends ChangeNotifier {
  final ChatRepository _repo;
  ChatProvider({ChatRepository? repository}) : _repo = repository ?? ChatRepository();

  /// Raw envelope — see [ChatRepository.fetchWorkspace]. Callers pull out
  /// `workspace`/`nextMeeting`/`nextPayment` themselves.
  Future<Map<String, dynamic>> fetchWorkspace(int workspaceId) => _repo.fetchWorkspace(workspaceId);

  /// See [ChatRepository.fetchMessages].
  Future<List<dynamic>> fetchMessages(int workspaceId) => _repo.fetchMessages(workspaceId);

  /// See [ChatRepository.markRead].
  Future<void> markRead(int workspaceId) => _repo.markRead(workspaceId);

  /// See [ChatRepository.sendMessage].
  Future<void> sendMessage(int workspaceId, String message, {int? replyToId, bool requiresAction = false}) =>
      _repo.sendMessage(workspaceId, message, replyToId: replyToId, requiresAction: requiresAction);

  /// See [ChatRepository.editMessage].
  Future<void> editMessage(int messageId, String message) => _repo.editMessage(messageId, message);

  /// See [ChatRepository.requireAction].
  Future<void> requireAction(int messageId) => _repo.requireAction(messageId);

  /// See [ChatRepository.uploadFile].
  Future<void> uploadFile(int workspaceId, File file) => _repo.uploadFile(workspaceId, file);

  /// See [ChatRepository.respond].
  Future<void> respond(int messageId, {required String action, String? reason}) =>
      _repo.respond(messageId, action: action, reason: reason);
}
