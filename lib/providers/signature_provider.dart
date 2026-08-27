import 'dart:io';
import 'package:flutter/material.dart';
import '../data/signature_repository.dart';

class SignatureProvider extends ChangeNotifier {
  final SignatureRepository _repo;
  SignatureProvider({SignatureRepository? repository}) : _repo = repository ?? SignatureRepository();

  Future<void> deleteSignature(int clientId) => _repo.deleteSignature(clientId);

  Future<void> uploadImage(int clientId, File file) => _repo.uploadImage(clientId, file);

  Future<void> saveText(int clientId, String text) => _repo.saveText(clientId, text);
}
