import 'dart:io';
import '../data/signature_repository.dart';

// See docs/state-layer-migration-plan.md, بند ٤: no notifyListeners() calls
// here and nothing listens to this class reactively.
class SignatureProvider {
  final SignatureRepository _repo;
  SignatureProvider({SignatureRepository? repository}) : _repo = repository ?? SignatureRepository();

  Future<void> deleteSignature(int clientId) => _repo.deleteSignature(clientId);

  Future<void> uploadImage(int clientId, File file) => _repo.uploadImage(clientId, file);

  Future<void> saveText(int clientId, String text) => _repo.saveText(clientId, text);

  Future<void> deleteSelfSignature() => _repo.deleteSelfSignature();

  Future<void> uploadSelfSignatureImage(File file) => _repo.uploadSelfSignatureImage(file);

  Future<void> saveSelfSignatureText(String text) => _repo.saveSelfSignatureText(text);
}
