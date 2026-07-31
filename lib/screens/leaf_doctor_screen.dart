import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:farmigrow_ai/theme/app_theme.dart';

class LeafDoctorScreen extends StatefulWidget {
  const LeafDoctorScreen({super.key});
  @override
  State<LeafDoctorScreen> createState() => _LeafDoctorScreenState();
}

class _LeafDoctorScreenState extends State<LeafDoctorScreen> {
  bool _analyzing = false;
  String? _result;
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  final List<Map<String, dynamic>> _samples = [
    {
      'name': 'Rice Leaf Blast',
      'telugu': 'శిలీంధ్ర తెగులు',
      'crop': 'Rice',
      'desc': 'Spindle-shaped brown spots on rice leaf blades.',
      'color': Colors.orange,
    },
    {
      'name': 'Cotton Jassid Damage',
      'telugu': 'పచ్చదోమ కాటు',
      'crop': 'Cotton',
      'desc': 'Downward curling yellow margins on cotton foliage.',
      'color': Colors.yellow,
    },
    {
      'name': 'Algae Bloom',
      'telugu': 'ఆల్గే నాచు',
      'crop': 'Aquaculture',
      'desc': 'Thick viscous green coloration of pond water.',
      'color': Colors.green,
    },
  ];

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _selectedImage = File(picked.path);
          _result = null;
        });
        _analyzeUploadedImage();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not access camera/gallery: $e')),
        );
      }
    }
  }

  void _showPickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXL))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppTheme.primaryGreen),
                title: Text('Take Photo', style: AppTheme.body().copyWith(color: AppTheme.textWhite)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppTheme.accentBlue),
                title: Text('Choose from Gallery', style: AppTheme.body().copyWith(color: AppTheme.textWhite)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _analyzeUploadedImage() async {
    setState(() {
      _analyzing = true;
      _result = null;
    });
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _analyzing = false;
      _result = '🔬 AI Diagnosis: Possible Leaf Stress Detected\n\n'
          '📊 Confidence: 87%\n\n'
          '💊 Recommendation: Symptoms are consistent with early-stage nutrient '
          'deficiency or mild fungal onset. Apply a balanced foliar spray and '
          'monitor for 5-7 days. If spots spread, switch to a targeted fungicide.\n\n'
          '⚠️ Note: This is a demo analysis. Connect to live AI vision model for '
          'production-accurate results.';
    });
  }

  void _analyzeSample(Map<String, dynamic> sample) async {
    setState(() {
      _analyzing = true;
      _result = null;
      _selectedImage = null;
    });
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _analyzing = false;
      _result = '🔬 AI Diagnosis: ${sample['name']}\n\n'
          '📊 Confidence: 91%\n\n'
          '💊 Recommendation: Apply Carbendazim 50% WP @ 1g/L water. '
          'Spray during early morning. Repeat after 7 days if symptoms persist.\n\n'
          '⚠️ Affected Area: ~0.15 acres\n'
          '📅 Act within: 48 hours';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        title: Text('Leaf Doctor', style: AppTheme.h1()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spaceLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Upload area
            GestureDetector(
              onTap: _showPickerSheet,
              child: Container(
                width: double.infinity,
                height: 180,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                  border: Border.all(
                      color: AppTheme.primaryGreen.withOpacity(0.4), width: 1.5),
                ),
                child: _selectedImage != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(_selectedImage!, fit: BoxFit.cover),
                          Positioned(
                            right: 8, top: 8,
                            child: GestureDetector(
                              onTap: _showPickerSheet,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.edit, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, color: AppTheme.primaryGreen, size: 40),
                          const SizedBox(height: AppTheme.spaceSM),
                          Text('Upload Leaf Photo', style: AppTheme.h2()),
                          const SizedBox(height: 2),
                          Text('ఆకు ఫోటో అప్లోడ్ చేయండి', style: AppTheme.bodySmall()),
                          const SizedBox(height: 4),
                          Text('Tap to use camera or gallery', style: AppTheme.caption()),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: AppTheme.spaceXL),

            Text('SAMPLE DIAGNOSES', style: AppTheme.label()),
            const SizedBox(height: AppTheme.spaceMD),

            ..._samples.map((s) => GestureDetector(
                  onTap: () => _analyzeSample(s),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: AppTheme.spaceSM),
                    padding: AppTheme.cardPaddingSmall,
                    decoration: AppTheme.cardDecoration(),
                    child: Row(
                      children: [
                        Container(
                          width: AppTheme.iconBoxMD, height: AppTheme.iconBoxMD,
                          decoration: BoxDecoration(
                            color: (s['color'] as Color).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                          ),
                          child: Icon(Icons.eco, color: s['color'] as Color, size: 22),
                        ),
                        const SizedBox(width: AppTheme.spaceMD),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s['name'], style: AppTheme.h3()),
                              Text('${s['telugu']} · ${s['crop']}', style: AppTheme.bodySmall()),
                              Text(s['desc'], style: AppTheme.bodySmall()),
                            ],
                          ),
                        ),
                        const Icon(Icons.play_circle, color: AppTheme.primaryGreen, size: 28),
                      ],
                    ),
                  ),
                )),

            if (_analyzing)
              Container(
                margin: const EdgeInsets.only(top: AppTheme.spaceLG),
                padding: AppTheme.cardPadding,
                decoration: AppTheme.cardDecoration(),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(color: AppTheme.primaryGreen, strokeWidth: 2),
                    ),
                    const SizedBox(width: AppTheme.spaceLG),
                    Text('AI analyzing leaf sample...', style: AppTheme.body().copyWith(color: AppTheme.textGrey)),
                  ],
                ),
              ),

            if (_result != null)
              Container(
                margin: const EdgeInsets.only(top: AppTheme.spaceLG),
                padding: AppTheme.cardPadding,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C2A1E),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.4)),
                ),
                child: Text(_result!, style: AppTheme.body()),
              ),
          ],
        ),
      ),
    );
  }
}
