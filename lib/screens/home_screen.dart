import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:farmigrow_ai/theme/app_theme.dart';
import 'package:farmigrow_ai/screens/dashboard_screen.dart';
import 'package:farmigrow_ai/screens/satellite_screen.dart';
import 'package:farmigrow_ai/screens/leaf_doctor_screen.dart';
import 'package:farmigrow_ai/screens/agri_ai_screen.dart';
import 'package:farmigrow_ai/screens/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isAgri = true; // Toggle between Agri and Aqua

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(isAgri: _isAgri),
      const SatelliteScreen(),
      const LeafDoctorScreen(),
      const AgriAIScreen(),
    ];

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        elevation: 0,
        title: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          ),
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.eco, color: AppTheme.primaryGreen, size: 18),
              ),
              const SizedBox(width: 8),
              Text('FarmiGrow',
                  style: GoogleFonts.poppins(
                      color: AppTheme.textWhite,
                      fontWeight: FontWeight.w700,
                      fontSize: 18)),
            ],
          ),
        ),
        actions: [
          // Agri / Aqua toggle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _isAgri = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isAgri ? AppTheme.primaryGreen : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Agri',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _isAgri ? Colors.black : AppTheme.textGrey)),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _isAgri = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: !_isAgri ? Colors.blue : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Aqua',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: !_isAgri ? Colors.white : AppTheme.textGrey)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: const Icon(Icons.person, color: AppTheme.primaryGreen, size: 18),
            ),
          ),
        ],
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.bgCard,
          border: Border(top: BorderSide(color: AppTheme.borderColor)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          backgroundColor: AppTheme.bgCard,
          selectedItemColor: AppTheme.primaryGreen,
          unselectedItemColor: AppTheme.textGrey,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 10),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.show_chart),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.satellite_alt),
              label: 'Satellite',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.document_scanner),
              label: 'Leaf Doctor',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.smart_toy),
              label: 'Agri AI',
            ),
          ],
        ),
      ),
    );
  }
}
