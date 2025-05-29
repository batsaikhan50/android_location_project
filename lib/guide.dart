import 'package:flutter/material.dart';

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  final List<Map<String, String>> guideSteps = const [
    {
      'caption': 'Алхам 1: "Location" -> ("Always"/"Allow all the time") тохиргоог асаах',
      'asset': 'assets/guide/always.png',
    },
    {
      'caption': 'Алхам 2: "Location" -> "Use precise location" тохиргоог асаах',
      'asset': 'assets/guide/precision.png',
    },
    {
      'caption': 'Алхам 3: "Battery" -> "Unrestricted" тохиргоог сонгох',
      'asset': 'assets/guide/battery.png',
    },
    {
      'caption': 'Алхам 4: "Remove permission if app is unused" тохиргоог унтраах',
      'asset': 'assets/guide/removePermission.png',
    },
    {
      'caption': 'Алхам 5: "Pause app activity if unused" тохиргоог унтраах',
      'asset': 'assets/guide/pauseApp.png',
    },
    {
      'caption': 'Алхам 6: "Mobile data" -> "Allow background data usage" болон "Allow data usage while Data save is on" тохиргоог асаах',
      'asset': 'assets/guide/allowBgAndDataSaver.png',
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
            context: context,
            caption: step['caption']!,
            assetPath: step['asset']!,
          );
        },
      ),
    );
  }

  Widget _buildGuideAccordion({
    required BuildContext context,
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
            child: GestureDetector(
              onTap: () {
                showGeneralDialog(
                  context: context,
                  barrierDismissible: true,
                  barrierLabel: "Close",
                  barrierColor: Colors.black87,
                  transitionDuration: const Duration(milliseconds: 200),
                  pageBuilder: (context, animation, secondaryAnimation) {
                    return GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Scaffold(
                        backgroundColor: Colors.black87,
                        body: Stack(
                          children: [
                            InteractiveViewer(
                              panEnabled: true,
                              minScale: 1.0,
                              maxScale: 4.0,
                              child: Center(
                                child: Image.asset(
                                  assetPath,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 32,
                              right: 16,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 30,
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  assetPath,
                  fit: BoxFit.fitWidth,
                  width: double.infinity,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
