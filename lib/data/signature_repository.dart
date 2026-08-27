import 'dart:io';
import '../core/api_client.dart';

/// Wraps the `/clients/:id/sign` HTTP calls shared by signature_page.dart
/// (standalone route) and signature_tab.dart (embedded tab inside
/// client_dashboard_screen.dart) — two near-identical screens for drawing,
/// typing, or uploading a client's signature. Fetching the client itself
/// (to read `signature_data`) is not duplicated here — both screens use
/// [ClientProvider.fetchClientRaw], already built for the Dashboard slice.
class SignatureRepository {
  final ApiClient _api;
  SignatureRepository({ApiClient? api}) : _api = api ?? ApiClient();

  Future<void> deleteSignature(int clientId) => _api.delete('/clients/$clientId/sign');

  /// Used both for a picked image file and for a rendered drawing PNG — both
  /// call sites in the original screens hit this exact same endpoint/field.
  Future<void> uploadImage(int clientId, File file) =>
      _api.multipartPost('/clients/$clientId/sign', {}, file: file, fileField: 'signature_image');

  Future<void> saveText(int clientId, String text) => _api.post('/clients/$clientId/sign', {'signature': text});
}
