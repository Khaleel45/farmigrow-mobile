import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Dark theme colors matching the screenshots
  static const Color bgDark = Color(0xFF0D1117);
  static const Color bgCard = Color(0xFF161B22);
  static const Color bgCardLight = Color(0xFF1C2333);
  static const Color primaryGreen = Color(0xFF00C853);
  static const Color accentBlue = Color(0xFF1E88E5);
  static const Color accentCyan = Color(0xFF00BCD4);
  static const Color amber = Color(0xFFFFA000);
  static const Color dangerRed = Color(0xFFEF5350);
  static const Color textWhite = Color(0xFFE6EDF3);
  static const Color textGrey = Color(0xFF8B949E);
  static const Color textDark = Color(0xFFE6EDF3);
  static const Color cardWhite = Color(0xFF161B22);
  static const Color borderColor = Color(0xFF30363D);
  static const Color lightBlue = Color(0xFF1E88E5);
  static const Color warningOrange = Color(0xFFE65100);

  // ─── SPACING SCALE (use these everywhere instead of raw numbers) ───
  static const double spaceXS = 4;
  static const double spaceSM = 8;
  static const double spaceMD = 12;
  static const double spaceLG = 16;
  static const double spaceXL = 20;
  static const double spaceXXL = 24;

  // ─── RADIUS SCALE ───
  static const double radiusSM = 8;
  static const double radiusMD = 12;
  static const double radiusLG = 16;
  static const double radiusXL = 20;

  // ─── STANDARD CARD PADDING (use on every card-like container) ───
  static const EdgeInsets cardPadding = EdgeInsets.all(16);
  static const EdgeInsets cardPaddingSmall = EdgeInsets.all(12);

  // ─── STANDARD CARD DECORATION (use as base, override color if needed) ───
  static BoxDecoration cardDecoration({Color? color, Color? borderColor_}) =>
      BoxDecoration(
        color: color ?? bgCard,
        borderRadius: BorderRadius.circular(radiusMD),
        border: Border.all(color: borderColor_ ?? borderColor),
      );

  // ─── TYPOGRAPHY SCALE — use these instead of inline GoogleFonts.poppins() ───
  // Display: big hero numbers (health score 92/100)
  static TextStyle display() => GoogleFonts.poppins(
      fontSize: 48, fontWeight: FontWeight.w800, color: textWhite, height: 1.0);
  // H1: screen titles
  static TextStyle h1() => GoogleFonts.poppins(
      fontSize: 20, fontWeight: FontWeight.w700, color: textWhite);
  // H2: card titles, section headers
  static TextStyle h2() => GoogleFonts.poppins(
      fontSize: 15, fontWeight: FontWeight.w700, color: textWhite);
  // H3: sub-headers
  static TextStyle h3() => GoogleFonts.poppins(
      fontSize: 13, fontWeight: FontWeight.w600, color: textWhite);
  // Body: standard readable text
  static TextStyle body() => GoogleFonts.poppins(
      fontSize: 13, fontWeight: FontWeight.w400, color: textWhite, height: 1.5);
  // BodySmall: secondary text, captions
  static TextStyle bodySmall() => GoogleFonts.poppins(
      fontSize: 12, fontWeight: FontWeight.w400, color: textGrey, height: 1.4);
  // Label: tiny uppercase eyebrow labels
  static TextStyle label() => GoogleFonts.poppins(
      fontSize: 11, fontWeight: FontWeight.w600, color: textGrey, letterSpacing: 0.8);
  // Caption: smallest text (timestamps, hints)
  static TextStyle caption() => GoogleFonts.poppins(
      fontSize: 10, fontWeight: FontWeight.w500, color: textGrey);
  // Button: consistent button label size
  static TextStyle button() => GoogleFonts.poppins(
      fontSize: 14, fontWeight: FontWeight.w700);
  // StatValue: numbers in stat/metric cards
  static TextStyle statValue({Color? color}) => GoogleFonts.poppins(
      fontSize: 16, fontWeight: FontWeight.w700, color: color ?? textWhite);

  // ─── FIXED COMPONENT SIZES (use these so icon boxes/buttons match across screens) ───
  static const double iconBoxSM = 36;
  static const double iconBoxMD = 44;
  static const double iconBoxLG = 56;
  static const double avatarMD = 40;
  static const double buttonHeight = 48;
  static const double inputHeight = 52;

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: primaryGreen,
        scaffoldBackgroundColor: bgDark,
        colorScheme: ColorScheme.dark(
          primary: primaryGreen,
          secondary: accentBlue,
          surface: bgCard,
          background: bgDark,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        appBarTheme: AppBarTheme(
          backgroundColor: bgDark,
          foregroundColor: textWhite,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.poppins(
            color: textWhite,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryGreen,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          ),
        ),
        cardTheme: CardThemeData(
          color: bgCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: borderColor, width: 1),
          ),
        ),
      );
}
