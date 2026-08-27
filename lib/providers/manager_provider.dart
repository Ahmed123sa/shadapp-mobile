import 'package:flutter/material.dart';
import '../data/manager_repository.dart';
import '../models/manager.dart';

class ManagerProvider extends ChangeNotifier {
  final ManagerRepository _repo;
  ManagerProvider({ManagerRepository? repository}) : _repo = repository ?? ManagerRepository();

  List<Manager> _managers = [];
  bool _isLoading = false;
  String? _error;

  List<Manager> get managers => _managers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchManagers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _managers = await _repo.fetchAll();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> createManager(Map<String, dynamic> body) => _repo.create(body);

  Future<Map<String, dynamic>> updateManager(int id, Map<String, dynamic> body) => _repo.update(id, body);

  Future<void> deleteManager(int id) async {
    await _repo.delete(id);
    _managers = _managers.where((m) => m.id != id).toList();
    notifyListeners();
  }
}
