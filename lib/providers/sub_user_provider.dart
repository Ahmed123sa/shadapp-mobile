import 'package:flutter/material.dart';
import '../data/sub_user_repository.dart';

class SubUserProvider extends ChangeNotifier {
  final SubUserRepository _repo;
  SubUserProvider({SubUserRepository? repository}) : _repo = repository ?? SubUserRepository();

  Future<List<dynamic>> fetchForClient(int clientId) => _repo.fetchForClient(clientId);

  Future<Map<String, dynamic>> create(int clientId, Map<String, dynamic> body) => _repo.create(clientId, body);

  Future<void> delete(int id) => _repo.delete(id);

  Future<Map<String, dynamic>> updatePermissions(int id, Map<String, dynamic> permissions) =>
      _repo.updatePermissions(id, permissions);
}
