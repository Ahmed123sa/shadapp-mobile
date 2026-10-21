import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import '../../core/app_log.dart';
import '../../providers/client_provider.dart';
import '../../providers/signature_provider.dart';
import '../../core/luxe/tokens.dart';
import '../../core/widgets/luxe/luxe_widgets.dart';
import '../../core/widgets/signature_pad_screen.dart';

class SignatureTab extends StatefulWidget {
  // Optional so this screen can be pumped in a widget test with mocked
  // providers instead of hitting the network.
  final ClientProvider? clientProvider;
  final SignatureProvider? signatureProvider;
  final ApiClient? api;
  const SignatureTab({super.key, this.clientProvider, this.signatureProvider, this.api});

  @override
  State<SignatureTab> createState() => _SignatureTabState();
}

class _SignatureTabState extends State<SignatureTab> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final ClientProvider _clientProvider = widget.clientProvider ?? ClientProvider();
  late final SignatureProvider _signatureProvider = widget.signatureProvider ?? SignatureProvider();
  final _textController = TextEditingController();
  bool _saving = false;
  String _mode = 'draw';

  String? _existingSigUrl;
  String? _existingSigText;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    try {
      final cid = _api.userId;
      if (cid == null) return;
      final data = await _clientProvider.fetchClientRaw(cid);
      final client = data['client'] as Map<String, dynamic>?;
      final sigData = client?['signature_data'] as String?;
      setState(() {
        _existingSigUrl = null;
        _existingSigText = null;
      });
      if (sigData != null && sigData.isNotEmpty) {
        if (sigData.startsWith('http') || sigData.startsWith('/')) {
          // signature_url: the backend's signed link - /storage/... doesn't
          // exist in production (23 Sept 2026).
          final signedUrl = client?['signature_url'] as String?;
          setState(() => _existingSigUrl = signedUrl ?? _api.resolveFileUrl(sigData));
        } else {
          setState(() => _existingSigText = sigData);
        }
      }
    } catch (e, s) {
      AppLog.error('signature_tab._loadExisting', e, s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(AppLocalizations.of(context)!.signature_loadFailed('$e'))),
        );
      }
    }
  }

  void _clear() => setState(() {
        _textController.clear();
      });

  Future<void> _deleteSignature() async {
    try {
      final cid = _api.userId;
      if (cid == null) return;
      await _signatureProvider.deleteSignature(cid);
      setState(() {
        _existingSigUrl = null;
        _existingSigText = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.signature_deleted)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.signature_deleteFailed)),
        );
      }
    }
  }

  Future<void> _openFullscreenSignature() async {
    final bytes = await SignaturePadScreen.show(context);
    if (bytes == null) return;
    setState(() => _saving = true);
    try {
      final cid = _api.userId;
      if (cid == null) throw Exception('User ID not found');
      final dir = Directory.systemTemp;
      final file = File('${dir.path}/signature_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      await _signatureProvider.uploadImage(cid, file);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.signature_saved)),
        );
        _loadExisting();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.signature_saveFailed}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      try {
        final file = File(result.files.single.path!);
        final cid = _api.userId;
        if (cid == null) return;
        await _signatureProvider.uploadImage(cid, file);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.signature_saved)),
          );
          _loadExisting();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.signature_saveFailed)),
          );
        }
      }
    }
  }

  Future<void> _saveText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    setState(() => _saving = true);
    try {
      final cid = _api.userId;
      if (cid == null) throw Exception('User ID not found');
      await _signatureProvider.saveText(cid, text);
      if (mounted) {
        _textController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.signature_saved)),
        );
        _loadExisting();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.signature_saveFailed)),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LuxeFormTheme(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LuxePageTitle(l10n.signature),
            if (_existingSigUrl != null || _existingSigText != null) ...[
              _buildExistingSignature(),
              const SizedBox(height: 20),
            ],
            Align(alignment: AlignmentDirectional.centerStart, child: _buildModeSelector()),
            const SizedBox(height: 4),
            if (_mode == 'draw')
              _buildDrawArea()
            else
              _buildTextArea(),
            const SizedBox(height: 16),
            _buildActionButtons(),
            const SizedBox(height: 12),
            _buildUploadButton(),
          ],
        ),
      ),
    );
  }

  /// Mockup `.sigbox`: bordered 110px box with the saved signature in italic serif.
  Widget _buildExistingSignature() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LuxeKind(l10n.signature_currentSignature),
        Container(
          height: 110,
          margin: const EdgeInsets.symmetric(vertical: 14),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: Lx.line2)),
          child: _existingSigUrl != null
              ? LuxeSignatureInk(
                  child: Image.network(
                    _existingSigUrl!,
                    height: 70,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.error, size: 30, color: Lx.danger),
                  ),
                )
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(_existingSigText!, style: Lx.display(context, size: 36).copyWith(fontStyle: FontStyle.italic)),
                ),
        ),
        OutlinedButton.icon(
          onPressed: _deleteSignature,
          icon: const Icon(Icons.delete_outline, size: 16),
          label: Text(l10n.signature_deleteSignature),
          style: OutlinedButton.styleFrom(foregroundColor: Lx.danger, side: BorderSide(color: Lx.danger.withAlpha(128))),
        ),
      ],
    );
  }

  /// Mockup `.segm`: pill segmented control.
  Widget _buildModeSelector() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(Lx.rPill), border: Border.all(color: Lx.line2)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeTab('draw', l10n.signature_drawMode),
          _buildModeTab('text', l10n.signature_textMode),
        ],
      ),
    );
  }

  Widget _buildModeTab(String value, String label) {
    final selected = _mode == value;
    return GestureDetector(
      onTap: () => setState(() => _mode = value),
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0x14FFFFFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(Lx.rPill),
        ),
        child: Text(label, style: Lx.text(context, size: 12, color: selected ? Lx.ink : Lx.muted)),
      ),
    );
  }

  /// Mockup `.pad`: 150px bordered area.
  Widget _padBox({required Widget child}) => Container(
        height: 150,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: Lx.line2)),
        child: child,
      );

  Widget _buildDrawArea() {
    final l10n = AppLocalizations.of(context)!;
    return _padBox(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(l10n.signatureDrawSignature, style: Lx.text(context, size: 14, color: Lx.ink2)),
        const SizedBox(height: 14),
        ElevatedButton.icon(
          onPressed: _saving ? null : _openFullscreenSignature,
          icon: const Icon(Icons.fullscreen, size: 20),
          label: Text(l10n.signatureOpenFullscreen),
        ),
      ]),
    );
  }

  Widget _buildTextArea() {
    final l10n = AppLocalizations.of(context)!;
    return _padBox(
      child: TextField(
        controller: _textController,
        textAlign: TextAlign.center,
        style: Lx.display(context, size: 38).copyWith(fontStyle: FontStyle.italic),
        decoration: InputDecoration(
          hintText: l10n.signature_typeYourName,
          hintStyle: Lx.text(context, size: 18, color: Lx.faint),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
        maxLines: 1,
      ),
    );
  }

  Widget _buildActionButtons() {
    final l10n = AppLocalizations.of(context)!;
    if (_mode == 'draw') return const SizedBox.shrink();
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(onPressed: _clear, child: Text(l10n.signature_clear)),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _saveText,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check, size: 18),
            label: Text(_saving ? l10n.signature_saving : l10n.signature_saveSignature),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadButton() {
    final l10n = AppLocalizations.of(context)!;
    return OutlinedButton.icon(
      onPressed: _pickImage,
      icon: const Icon(Icons.attach_file, size: 18),
      label: Text(l10n.signature_orUploadImage),
    );
  }
}
