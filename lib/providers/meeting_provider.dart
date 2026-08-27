import 'package:flutter/material.dart';
import '../data/meeting_repository.dart';
import '../models/meeting.dart';

class MeetingProvider extends ChangeNotifier {
  final MeetingRepository _repo;
  MeetingProvider({MeetingRepository? repository}) : _repo = repository ?? MeetingRepository();

  List<Meeting> _meetings = [];
  bool _isLoading = false;
  String? _error;

  List<Meeting> get meetings => _meetings;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchForWorkspace(int workspaceId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _meetings = await _repo.fetchForWorkspace(workspaceId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchAllWorkspaces() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _meetings = await _repo.fetchAllWorkspaces();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
