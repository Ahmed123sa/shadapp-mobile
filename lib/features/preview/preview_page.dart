import 'package:flutter/material.dart';

class _Direction {
  final String name;
  final String thesis;
  final String bestFor;
  final Color primaryColor;
  final Color surfaceColor;
  final Color cardColor;
  final Color accentColor;
  final Color? secondaryAccent;
  final double radius;
  final double borderWidth;
  final String headingFont;
  final String bodyFont;
  final bool useElevation;
  final bool sharpBorders;
  final String vibeWord;

  const _Direction({
    required this.name,
    required this.thesis,
    required this.bestFor,
    required this.primaryColor,
    required this.surfaceColor,
    required this.cardColor,
    required this.accentColor,
    this.secondaryAccent,
    required this.radius,
    required this.borderWidth,
    required this.headingFont,
    required this.bodyFont,
    required this.useElevation,
    required this.sharpBorders,
    required this.vibeWord,
  });
}

final _directions = [
  _Direction(
    name: '1 — Crimson Edge',
    thesis: 'Bauhaus جريء — زوايا حادة، borders حمرا صريحة، شخصية قوية',
    bestFor: 'AM Dashboard — جرأة وثقة',
    primaryColor: const Color(0xFF941414),
    surfaceColor: const Color(0xFF1C1C1C),
    cardColor: const Color(0xFF1C1C1C),
    accentColor: const Color(0xFF941414),
    radius: 4,
    borderWidth: 2,
    headingFont: 'PlayfairDisplay',
    bodyFont: 'Archivo',
    useElevation: false,
    sharpBorders: true,
    vibeWord: 'جريء',
  ),
  _Direction(
    name: '2 — Dark Luxe',
    thesis: 'Editorial فاخر — مساحات كبيرة، عناوين ضخمة، إيقاع بطيء',
    bestFor: 'Login, Client Home — أناقة',
    primaryColor: const Color(0xFF941414),
    surfaceColor: const Color(0xFF1C1C1C),
    cardColor: const Color(0xFF2A2A2A),
    accentColor: const Color(0xFFF0F0F0),
    radius: 16,
    borderWidth: 0.5,
    headingFont: 'PlayfairDisplay',
    bodyFont: 'Archivo',
    useElevation: false,
    sharpBorders: false,
    vibeWord: 'فاخر',
  ),
  _Direction(
    name: '3 — Bento Workspace',
    thesis: 'Bento Grid — بطاقات بأحجام مختلفة، كثافة معلومات عالية',
    bestFor: 'AM Workspace tabs — معلوماتي',
    primaryColor: const Color(0xFFB71C1C),
    surfaceColor: const Color(0xFF1C1C1C),
    cardColor: const Color(0xFF222222),
    accentColor: const Color(0xFF22C55E),
    radius: 8,
    borderWidth: 1,
    headingFont: 'Archivo',
    bodyFont: 'NotoSansArabic',
    useElevation: true,
    sharpBorders: false,
    vibeWord: 'عملي',
  ),
  _Direction(
    name: '4 — Swiss Minimal',
    thesis: 'Swiss — Flat، محاذاة صارمة، spacing 8px، بدون زينة',
    bestFor: 'Chat, Approvals — سرعة ووضوح',
    primaryColor: const Color(0xFF941414),
    surfaceColor: const Color(0xFF141414),
    cardColor: const Color(0xFF1A1A1A),
    accentColor: const Color(0xFFF0F0F0),
    radius: 0,
    borderWidth: 0,
    headingFont: 'Archivo',
    bodyFont: 'NotoSansArabic',
    useElevation: false,
    sharpBorders: true,
    vibeWord: 'نظيف',
  ),
  _Direction(
    name: '5 — Neo-Noir',
    thesis: 'سينمائي — Glow خفيف، Glass-morphism، immersive',
    bestFor: 'كل الشاشات — Client و AM',
    primaryColor: const Color(0xFF941414),
    surfaceColor: const Color(0xFF111111),
    cardColor: const Color(0xFF1E1E1E).withAlpha(220),
    accentColor: const Color(0xFFF0F0F0),
    secondaryAccent: Colors.red.shade900,
    radius: 12,
    borderWidth: 0.5,
    headingFont: 'PlayfairDisplay',
    bodyFont: 'Archivo',
    useElevation: true,
    sharpBorders: false,
    vibeWord: 'غامق',
  ),
  _Direction(
    name: '6 — Crimson + Bento (مدمج)',
    thesis: 'Bento + Crimson Edge — جرأة الـ Bauhaus مع كثافة Bento',
    bestFor: 'AM Dashboard + Workspace — جرأة عملية',
    primaryColor: const Color(0xFF941414),
    surfaceColor: const Color(0xFF1C1C1C),
    cardColor: const Color(0xFF222222),
    accentColor: const Color(0xFFB71C1C),
    radius: 6,
    borderWidth: 1.5,
    headingFont: 'PlayfairDisplay',
    bodyFont: 'Archivo',
    useElevation: false,
    sharpBorders: true,
    vibeWord: 'ديناميكي',
  ),
  _Direction(
    name: '7 — Royal Noir',
    thesis: 'Luxe — مستوحى من Patek و Bentley، فخامة هادية، تفاصيل دقيقة',
    bestFor: 'Login, Client Home, Signature — أول إنطباع',
    primaryColor: const Color(0xFF881212),
    surfaceColor: const Color(0xFF161618),
    cardColor: const Color(0xFF1E1E22),
    accentColor: const Color(0xFFC9A96E),
    radius: 6,
    borderWidth: 0.5,
    headingFont: 'PlayfairDisplay',
    bodyFont: 'Archivo',
    useElevation: true,
    sharpBorders: false,
    vibeWord: 'فخم',
  ),
  _Direction(
    name: '8 — Executive Suite',
    thesis: 'Corporate — بنكي، حرفي، strict alignment، كثافة عالية',
    bestFor: 'AM Dashboard, Contracts, Reports — Professional',
    primaryColor: const Color(0xFF7A1010),
    surfaceColor: const Color(0xFF1C1C1C),
    cardColor: const Color(0xFF181818),
    accentColor: const Color(0xFFC0C0C0),
    radius: 4,
    borderWidth: 1,
    headingFont: 'Archivo',
    bodyFont: 'NotoSansArabic',
    useElevation: false,
    sharpBorders: true,
    vibeWord: 'حرفي',
  ),
  _Direction(
    name: '9 — Arabian Heritage',
    thesis: 'عربي فاخر — Amiri calligraphic + gold + أقواس عربية',
    bestFor: 'كل الشاشات — هوية عربية قوية مع لمسة عصرية',
    primaryColor: const Color(0xFF941414),
    surfaceColor: const Color(0xFF1A1A1A),
    cardColor: const Color(0xFF222222),
    accentColor: const Color(0xFFD4AF37),
    radius: 10,
    borderWidth: 0.5,
    headingFont: 'Amiri',
    bodyFont: 'NotoSansArabic',
    useElevation: true,
    sharpBorders: false,
    vibeWord: 'أصيل',
  ),
];

class PreviewPage extends StatefulWidget {
  const PreviewPage({super.key});

  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final d = _directions[_selected];
    return Scaffold(
      backgroundColor: d.surfaceColor,
      appBar: AppBar(
        title: Text(d.name, style: TextStyle(fontFamily: d.headingFont, fontWeight: FontWeight.bold)),
        backgroundColor: d.surfaceColor,
      actions: [
        Row(children: [
          for (int i = 0; i < _directions.length; i++)
            GestureDetector(
              onTap: () => setState(() => _selected = i),
              child: Container(
                padding: const EdgeInsets.all(6),
                child: Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _selected == i ? d.primaryColor : const Color(0xFF3A3A3A),
                    border: _selected == i ? Border.all(color: const Color(0xFFF0F0F0), width: 2) : null,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 8),
          Text('${_selected + 1} / ${_directions.length}', style: const TextStyle(fontSize: 12, color: Color(0xFF606060))),
          const SizedBox(width: 12),
        ]),
      ],
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! < 0) {
            setState(() => _selected = (_selected + 1) % _directions.length);
          } else if (details.primaryVelocity! > 0) {
            setState(() => _selected = (_selected - 1 + _directions.length) % _directions.length);
          }
        },
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildInfoCard(d),
          const SizedBox(height: 16),
          _buildPalette(d),
          const SizedBox(height: 16),
          _buildCardPreview(d),
          const SizedBox(height: 16),
          _buildButtons(d),
          const SizedBox(height: 16),
          _buildChatBubble(d),
          const SizedBox(height: 16),
          _buildLoginPreview(d),
          const SizedBox(height: 16),
          _buildDashboardPreview(d),
          const SizedBox(height: 16),
          _buildTypographySample(d),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: d.primaryColor,
                foregroundColor: const Color(0xFFF0F0F0),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () => Navigator.pop(context, _selected),
              child: Text('اختيار هذا الاتجاه (${d.vibeWord})'),
            ),
          ),
          const SizedBox(height: 32),
        ]),
      ),
      ),
    );
  }

  Widget _buildInfoCard(_Direction d) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: d.cardColor,
        borderRadius: BorderRadius.circular(d.radius.clamp(0, 16)),
        border: Border.all(color: d.primaryColor.withAlpha(60), width: d.borderWidth),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(d.name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: d.headingFont, color: const Color(0xFFF0F0F0))),
        const SizedBox(height: 8),
        Text(d.thesis, style: TextStyle(fontSize: 14, color: const Color(0xFFA0A0A0), fontFamily: d.bodyFont)),
        const SizedBox(height: 8),
        Text('الأنسب لـ: ${d.bestFor}', style: TextStyle(fontSize: 13, color: d.primaryColor, fontFamily: d.bodyFont, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildPalette(_Direction d) {
    final colors = [d.primaryColor, d.surfaceColor, d.cardColor, d.accentColor];
    if (d.secondaryAccent != null) colors.add(d.secondaryAccent!);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('الألوان', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFFA0A0A0))),
      const SizedBox(height: 8),
      Row(children: colors.map((c) => Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Container(width: 40, height: 40, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(d.radius.clamp(0, 8)), border: Border.all(color: const Color(0xFF3A3A3A)))),
      )).toList()),
    ]);
  }

  Widget _buildCardPreview(_Direction d) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('بطاقة نموذجية', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFFA0A0A0))),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: d.cardColor,
          borderRadius: BorderRadius.circular(d.radius.clamp(0, 16)),
          border: d.borderWidth > 0 ? Border.all(color: d.primaryColor, width: d.borderWidth) : null,
          boxShadow: d.useElevation ? [BoxShadow(color: Colors.black26, blurRadius: 8, offset: const Offset(0, 4))] : null,
        ),
        child: Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: d.primaryColor, borderRadius: BorderRadius.circular(d.sharpBorders ? 4 : 20))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(height: 14, width: 140, decoration: BoxDecoration(color: const Color(0xFFF0F0F0).withAlpha(80), borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 6),
            Container(height: 10, width: 100, decoration: BoxDecoration(color: const Color(0xFFA0A0A0).withAlpha(80), borderRadius: BorderRadius.circular(4))),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: d.primaryColor.withAlpha(25), borderRadius: BorderRadius.circular(d.radius.clamp(0, 12))), child: Text('نشط', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: d.primaryColor))),
        ]),
      ),
    ]);
  }

  Widget _buildButtons(_Direction d) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('الأزرار', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFFA0A0A0))),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(color: d.primaryColor, borderRadius: BorderRadius.circular(d.radius.clamp(0, 12))),
          child: Text('إجراء رئيسي', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFFF0F0F0), fontFamily: d.bodyFont)),
        )),
        const SizedBox(width: 8),
        Expanded(child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(border: Border.all(color: d.primaryColor, width: d.borderWidth), borderRadius: BorderRadius.circular(d.radius.clamp(0, 12))),
          child: Text('إجراء ثانوي', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: d.primaryColor, fontFamily: d.bodyFont)),
        )),
      ]),
    ]);
  }

  Widget _buildChatBubble(_Direction d) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('الشات', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFFA0A0A0))),
      const SizedBox(height: 8),
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: d.primaryColor, borderRadius: d.sharpBorders ? BorderRadius.circular(0) : BorderRadius.only(topLeft: const Radius.circular(16), topRight: const Radius.circular(16), bottomLeft: const Radius.circular(16), bottomRight: const Radius.circular(4))), child: Text('رسالة العميل', style: TextStyle(fontSize: 14, color: const Color(0xFFF0F0F0), fontFamily: d.bodyFont))),
      const SizedBox(height: 6),
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: d.cardColor, borderRadius: d.sharpBorders ? BorderRadius.circular(0) : BorderRadius.only(topLeft: const Radius.circular(4), topRight: const Radius.circular(16), bottomLeft: const Radius.circular(16), bottomRight: const Radius.circular(16)), border: d.borderWidth > 0 ? Border.all(color: const Color(0xFF3A3A3A)) : null), child: Text('رسالة الـ AM', style: TextStyle(fontSize: 14, color: const Color(0xFFA0A0A0), fontFamily: d.bodyFont))),
    ]);
  }

  Widget _buildLoginPreview(_Direction d) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('شاشة الدخول', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFFA0A0A0))),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: d.cardColor, borderRadius: BorderRadius.circular(d.radius.clamp(0, 16)), border: d.borderWidth > 0 && d.name.contains('Edge') ? Border.all(color: d.primaryColor, width: d.borderWidth) : null),
        child: Column(children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: d.primaryColor, borderRadius: BorderRadius.circular(d.sharpBorders ? 4 : 24)), child: Center(child: Text('d.', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFFF0F0F0), fontFamily: d.headingFont)))),
          const SizedBox(height: 12),
          Text('ShadApp', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFFF0F0F0), fontFamily: d.headingFont)),
          const SizedBox(height: 20),
          Container(height: 44, decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(d.radius.clamp(0, 12))), child: const Center(child: Text('البريد الإلكتروني', style: TextStyle(fontSize: 14, color: Color(0xFF606060))))),
          const SizedBox(height: 12),
          Container(height: 44, decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(d.radius.clamp(0, 12))), child: const Center(child: Text('كلمة المرور', style: TextStyle(fontSize: 14, color: Color(0xFF606060))))),
          const SizedBox(height: 16),
          Container(height: 48, decoration: BoxDecoration(color: d.primaryColor, borderRadius: BorderRadius.circular(d.radius.clamp(0, 12))), child: Center(child: Text('تسجيل الدخول', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFFF0F0F0), fontFamily: d.bodyFont)))),
        ]),
      ),
    ]);
  }

  Widget _buildDashboardPreview(_Direction d) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('لوحة التحكم', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFFA0A0A0))),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: d.cardColor, borderRadius: BorderRadius.circular(d.radius.clamp(0, 16)), border: d.borderWidth > 0 ? Border.all(color: const Color(0xFF3A3A3A), width: d.borderWidth / 2) : null),
        child: Column(children: [
          Row(children: [
            for (final s in ['12', '3', '5'])
              Expanded(child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: d.surfaceColor, borderRadius: BorderRadius.circular(d.radius.clamp(0, 10)), border: d.borderWidth > 0 ? Border.all(color: const Color(0xFF3A3A3A)) : null),
                child: Column(children: [
                  Text(s, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: d.primaryColor, fontFamily: d.headingFont)),
                  const SizedBox(height: 2),
                  Container(height: 6, width: 30, decoration: BoxDecoration(color: const Color(0xFFA0A0A0).withAlpha(60), borderRadius: BorderRadius.circular(3))),
                ]),
              )),
          ]),
          const SizedBox(height: 12),
          ...List.generate(3, (i) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(border: d.borderWidth > 0 ? Border.all(color: const Color(0xFF3A3A3A), width: d.borderWidth / 2) : null, borderRadius: BorderRadius.circular(d.radius.clamp(0, 12))),
            child: Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: d.primaryColor, shape: d.sharpBorders ? BoxShape.rectangle : BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Container(height: 10, decoration: BoxDecoration(color: const Color(0xFFF0F0F0).withAlpha(50), borderRadius: BorderRadius.circular(4)))),
              Container(width: 40, height: 6, decoration: BoxDecoration(color: d.accentColor.withAlpha(80), borderRadius: BorderRadius.circular(3))),
            ]),
          )),
        ]),
      ),
    ]);
  }

  Widget _buildTypographySample(_Direction d) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('الخطوط', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFFA0A0A0))),
      const SizedBox(height: 8),
      Text(d.headingFont, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: d.headingFont, color: const Color(0xFFF0F0F0))),
      const SizedBox(height: 4),
      Text('العناوين بـ ${d.bodyFont} نص عادي', style: TextStyle(fontSize: 14, color: const Color(0xFFA0A0A0), fontFamily: d.bodyFont)),
    ]);
  }
}
