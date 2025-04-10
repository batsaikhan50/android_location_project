import 'package:flutter/material.dart';

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  final List<Map<String, String>> guideSteps = const [
    {
      'caption': 'Алхам 1: ("Always"/"Allow all the time") тохиргоог асаах',
      'asset': 'assets/guide/always.png',
    },
    {
      'caption': 'Алхам 2: "Battery" -> "Unrestricted" тохиргоог сонгох',
      'asset': 'assets/guide/battery.png',
    },
    {
      'caption': 'Алхам 3: "Remove permission if app is unused" тохиргоог унтраах',
      'asset': 'assets/guide/removepermission.png',
    },
    {
      'caption': 'Алхам 4: "Pause app activity if unused" тохиргоог унтраах',
      'asset': 'assets/guide/pauseapp.png',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Хэрэглэх заавар'),
        backgroundColor: Color(0xFF00CCCC),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: guideSteps.length,
        itemBuilder: (context, index) {
          final step = guideSteps[index];
          return _buildGuideAccordion(
            caption: step['caption']!,
            assetPath: step['asset']!,
          );
        },
      ),
    );
  }

  Widget _buildGuideAccordion({
    required String caption,
    required String assetPath,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          caption,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                assetPath,
                fit: BoxFit.fitWidth,
                width: double.infinity,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
