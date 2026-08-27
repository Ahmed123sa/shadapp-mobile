import 'package:flutter/material.dart';
import '../data/report_repository.dart';

/// Thin pass-through — reports_tab.dart already owns its own
/// loading/filter/error state, so this provider doesn't duplicate it.
class ReportProvider extends ChangeNotifier {
  final ReportRepository _repo;
  ReportProvider({ReportRepository? repository}) : _repo = repository ?? ReportRepository();

  Future<Map<String, dynamic>> fetch({
    String? dateFrom,
    String? dateTo,
    int? clientId,
    String? clientType,
    int? managerId,
  }) =>
      _repo.fetch(dateFrom: dateFrom, dateTo: dateTo, clientId: clientId, clientType: clientType, managerId: managerId);
}
