// Single place for how proof-of-payment images are picked, shared by the
// payments page (new payment + scheduled-installment proof) and onboarding.
// Every pick goes through ImagePicker with imageQuality/maxWidth/maxHeight
// set, which does two things at once:
// - Re-encodes to JPEG, so a gallery pick on iPhone can no longer come back
//   as HEIC, which the backend rejects (see UploadRules::PROOF_MIMES).
// - Downscales, so a normal phone-camera photo (often 3-8MB unedited) comes
//   back well under 1MB — under both the backend's own 10MB limit and any
//   reverse-proxy body-size cap (see ApiClient's 413 handling).
// This replaces FilePicker entirely for these three sheets: the gallery
// picker used to hand back the original file untouched.
// payment-proof-upload-plan.md, Stage 3 (ح3).
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

const int _proofImageQuality = 70;
const double _proofMaxDimension = 1920;

/// Opens the camera and returns the shot as `{'file': File, 'name': String}`
/// on native platforms or `{'bytes': Uint8List, 'name': String}` on web, or
/// `null` if the user cancelled.
Future<Map<String, dynamic>?> pickProofFromCamera() async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.camera,
    imageQuality: _proofImageQuality,
    maxWidth: _proofMaxDimension,
    maxHeight: _proofMaxDimension,
  );
  if (picked == null) return null;
  if (kIsWeb) {
    return {'bytes': await picked.readAsBytes(), 'name': picked.name};
  }
  return {'file': File(picked.path), 'name': picked.name};
}

/// Opens the gallery and returns the picked image(s) in the same shape as
/// [pickProofFromCamera]. Pass `multiple: true` to allow picking more than
/// one image at once (onboarding); the payments page keeps it single.
/// Returns an empty list if the user cancelled.
Future<List<Map<String, dynamic>>> pickProofFromGallery({bool multiple = false}) async {
  final picker = ImagePicker();
  if (multiple) {
    final picked = await picker.pickMultiImage(
      imageQuality: _proofImageQuality,
      maxWidth: _proofMaxDimension,
      maxHeight: _proofMaxDimension,
    );
    if (picked.isEmpty) return [];
    if (kIsWeb) {
      return Future.wait(picked.map((p) async => {'bytes': await p.readAsBytes(), 'name': p.name}));
    }
    return picked.map((p) => {'file': File(p.path), 'name': p.name}).toList();
  }
  final picked = await picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: _proofImageQuality,
    maxWidth: _proofMaxDimension,
    maxHeight: _proofMaxDimension,
  );
  if (picked == null) return [];
  if (kIsWeb) {
    return [
      {'bytes': await picked.readAsBytes(), 'name': picked.name}
    ];
  }
  return [
    {'file': File(picked.path), 'name': picked.name}
  ];
}
