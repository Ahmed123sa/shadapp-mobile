import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The mockup's icon set (`const I={…}` in design/mobile/client-mobile-mockup.html):
/// 24×24 thin-line icons, stroke 1.4, round caps/joins. Path data is copied
/// as-is so the app draws exactly what the mockup draws.
const Map<String, String> _paths = {
  'home': '<path d="M3 10.5 12 4l9 6.5V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/>',
  'scroll': '<path d="M7 4h10a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H7M7 4a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2M9 9h6M9 13h6M9 17h3"/>',
  'wallet': '<rect x="3" y="6" width="18" height="13" rx="2.5"/><path d="M3 10h18M16.5 14.5h1"/>',
  'chat': '<path d="M4 5h16v11H9l-5 4z"/>',
  'check': '<rect x="4" y="4" width="16" height="16" rx="3"/><path d="m8.5 12 2.5 2.5 4.5-5"/>',
  'folder': '<path d="M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>',
  'more': '<circle cx="5" cy="12" r="1.2"/><circle cx="12" cy="12" r="1.2"/><circle cx="19" cy="12" r="1.2"/>',
  'bell': '<path d="M6 16V11a6 6 0 1 1 12 0v5l1.5 2h-15z"/><path d="M10 20.5a2.2 2.2 0 0 0 4 0"/>',
  'lock': '<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>',
  'up': '<path d="M12 16V4M7 9l5-5 5 5"/><path d="M4 16v3a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-3"/>',
  'down': '<path d="M12 4v11M7 10.5l5 5 5-5M5 20h14"/>',
  'eye': '<path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
  'doc': '<path d="M7 3h7l5 5v13H7z"/><path d="M14 3v5h5M10 13h6M10 17h6"/>',
  'clip': '<path d="m20 11.5-8.2 8.2a5 5 0 0 1-7.1-7.1l8.6-8.6a3.4 3.4 0 0 1 4.8 4.8l-8.5 8.5a1.7 1.7 0 0 1-2.4-2.4l7.8-7.8"/>',
  'send': '<path d="M5 12h13M13 6l6 6-6 6"/>',
  'video': '<rect x="3" y="6" width="13" height="12" rx="2"/><path d="m16 10 5-3v10l-5-3"/>',
  'users': '<circle cx="9" cy="8" r="3.2"/><path d="M3.5 19c.6-3 2.8-4.6 5.5-4.6s4.9 1.6 5.5 4.6"/><path d="M16 5.2a3 3 0 0 1 0 5.6M18 14.6c1.5.6 2.5 2 2.8 4.4"/>',
  'sign': '<path d="M4 18c3-6 5-10 6-10s-2 8 0 8 3-5 5-5-1 4 1 4 3-2 4-2"/><path d="M4 21h16"/>',
  'gear': '<circle cx="12" cy="12" r="3"/><path d="M12 2.8v2.4M12 18.8v2.4M4.2 7.5l2.1 1.2M17.7 15.3l2.1 1.2M4.2 16.5l2.1-1.2M17.7 8.7l2.1-1.2"/>',
  'lang': '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c3 3.5 3 14.5 0 18M12 3c-3 3.5-3 14.5 0 18"/>',
  'out': '<path d="M15 4h4v16h-4M10 8l-4 4 4 4M6 12h11"/>',
  'plus': '<path d="M12 5v14M5 12h14"/>',
  'back': '<path d="m15 5-7 7 7 7"/>',
};

/// Extra icons used only by the notifications mockup
/// (design/mobile/notifications-mobile-mockup.html). Kept apart so
/// [lxIconNames] stays the shared client/staff set.
const Map<String, String> _notifPaths = {
  'bellOff': '<path d="M6 16V11c0-1.2.3-2.300.9-3.200M18 11v5l1.500 2H8"/><path d="M10 20.500a2.200 2.200 0 0 0 4 0M4 4l16 16"/>',
  'file': '<path d="M7 3h7l4 4v14H7z"/><path d="M14 3v4h4M10 12h5M10 16h5"/>',
  'verified': '<path d="m12 3 2.400 1.700 2.900-.1.900 2.800 2.300 1.800-.9 2.700.9 2.700-2.300 1.800-.9 2.800-2.900-.1L12 21l-2.400-1.700-2.900.1-.9-2.800-2.300-1.800.9-2.700-.9-2.700 2.300-1.800.9-2.800 2.900.1z"/><path d="m8.800 12 2.200 2.200 4.200-4.400"/>',
  'clock': '<circle cx="12" cy="12" r="8.500"/><path d="M12 7.500V12l3 2"/>',
  'cal': '<rect x="3.500" y="5" width="17" height="15" rx="2"/><path d="M3.500 10h17M8 3v4M16 3v4"/>',
  'msg': '<path d="M5 5h14a1 1 0 0 1 1 1v9a1 1 0 0 1-1 1H10l-5 4v-4H5a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1z"/>',
  'gift': '<rect x="4" y="9" width="16" height="11" rx="1.500"/><path d="M3 9h18M12 9v11M12 9c-3 0-4.500-1-4.500-2.500S9 4 10.500 5 12 9 12 9zm0 0c3 0 4.500-1 4.500-2.500S15 4 13.500 5 12 9 12 9z"/>',
  'trash': '<path d="M5 7h14M10 7V4h4v3M7 7l1 13h8l1-13"/>',
  'reply': '<path d="M9 7 4 12l5 5"/><path d="M4 12h9a6 6 0 0 1 6 6v1"/>',
  'refresh': '<path d="M20 11a8 8 0 0 0-14-4.500L4 9M4 4v5h5M4 13a8 8 0 0 0 14 4.500L20 15M20 20v-5h-5"/>',
  'alert': '<path d="M12 4 2.500 20h19z"/><path d="M12 10v4.500M12 17.500h.01"/>',
  'checks': '<path d="m3 12.500 4 4 7-8M11 16.500l1 1 8-9.500"/>',
};

/// Extra icons used only by the staff mockup's "More" sheet
/// (design/mobile/staff-mobile-mockup.html, `NAV_ICON`).
const Map<String, String> _staffPaths = {
  'chart': '<path d="M4 20V10M10 20V4M16 20v-7M21 20H3"/>',
  'list': '<path d="M8 6h12M8 12h12M8 18h12M4 6h.01M4 12h.01M4 18h.01"/>',
  'key': '<circle cx="9" cy="8" r="3.2"/><path d="M3.5 19c.6-3 2.8-4.6 5.5-4.6M15 13l5 5M18 16l1.5-1.5"/>',
  'layers': '<path d="m12 4 9 5-9 5-9-5z"/><path d="m3 14 9 5 9-5"/>',
};

/// Names available in [LxIcon].
Iterable<String> get lxIconNames => _paths.keys;

String _hex(Color c) {
  int ch(double v) => (v * 255).round().clamp(0, 255);
  return '#${ch(c.r).toRadixString(16).padLeft(2, '0')}${ch(c.g).toRadixString(16).padLeft(2, '0')}${ch(c.b).toRadixString(16).padLeft(2, '0')}';
}

/// One of the mockup's icons, drawn from its SVG path data.
class LxIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;
  const LxIcon(this.name, {super.key, this.size = 18, this.color});

  @override
  Widget build(BuildContext context) {
    final inner = _paths[name] ?? _notifPaths[name] ?? _staffPaths[name] ?? '';
    final c = color ?? IconTheme.of(context).color ?? Colors.white;
    final svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
        '<g fill="none" stroke="${_hex(c)}" stroke-opacity="${c.a.toStringAsFixed(3)}" stroke-width="1.4" '
        'stroke-linecap="round" stroke-linejoin="round">$inner</g></svg>';
    return SvgPicture.string(svg, width: size, height: size);
  }
}
