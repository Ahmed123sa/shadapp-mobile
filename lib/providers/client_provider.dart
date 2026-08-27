import 'dart:io';
import 'package:flutter/material.dart';
import '../data/client_repository.dart';
import '../models/client.dart';

class ClientProvider extends ChangeNotifier {
  final ClientRepository _repo;
  ClientProvider({ClientRepository? repository}) : _repo = repository ?? ClientRepository();

  List<Client> _clients = [];
  bool _isLoading = false;
  String? _error;

  List<Client> get clients => _clients;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchClients() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _clients = await _repo.fetchAll();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Returns the raw create response — it carries one-time credentials the
  /// caller needs to show once. Deliberately does not refetch [clients]
  /// itself (the original inline version in create_client_page.dart never
  /// did either); a screen that lists clients calls [fetchClients] on its
  /// own when it becomes visible again, same as before.
  Future<Map<String, dynamic>> createClient(Map<String, dynamic> body) => _repo.create(body);

  Future<void> uploadAvatar(int clientId, File file) => _repo.uploadAvatar(clientId, file);

  /// Raw `/clients/:id` envelope (including the nested `workspace` object) —
  /// see [ClientRepository.fetchOneRaw].
  Future<Map<String, dynamic>> fetchClientRaw(int id) => _repo.fetchOneRaw(id);

  Future<void> deleteClient(int id) async {
    await _repo.delete(id);
    _clients = _clients.where((c) => c.id != id).toList();
    notifyListeners();
  }
}
