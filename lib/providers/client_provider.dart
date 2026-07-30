import 'package:flutter/material.dart';
import '../core/api_client.dart';

class ClientProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  List<dynamic> _clients = [];
  bool _isLoading = false;
  String? _error;

  List<dynamic> get clients => _clients;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchClients() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _api.get('/clients');
      _clients = res['clients'] as List<dynamic>;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
