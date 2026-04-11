import 'package:flutter/material.dart';

class FantasyColors {
  static const background = Color(0xFF0D0D0D);
  static const surface = Color(0xFF1A1A1A);
  static const surfaceAlt = Color(0xFF242424);
  static const border = Color(0xFF2E2E2E);
  static const textPrimary = Color(0xFFF5F5F5);
  static const textSecondary = Color(0xFF8A8A8A);
  static const textMuted = Color(0xFF555555);

  static const plPurple = Color(0xFF38003C);
  static const wcGold = Color(0xFFC4A265);
  static const successGreen = Color(0xFF1A7A4E);
  static const warningAmber = Color(0xFFBA7517);
  static const dangerRed = Color(0xFFE24B4A);

  static const pitchGreen = Color(0xFF1B5E2B);
  static const pitchLineDark = Color(0xFF1E6830);
  static const pitchLineLight = Color(0xFF2A7A40);
}

class FantasyTypography {
  static const headingFamily = 'BricolageGrotesque';
  static const bodyFamily = 'Inter';

  static const h1 = TextStyle(
    fontFamily: headingFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );
  static const h2 = TextStyle(
    fontFamily: headingFamily,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  );
  static const h3 = TextStyle(
    fontFamily: headingFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );
  static const body = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
  );
  static const caption = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
  );
  static const label = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.8,
  );
  static const score = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -1,
  );
  static const scoreSm = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
  );
}

class FantasySpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

class FantasyDefaults {
  static const budgetUnitDivisor = 10;
  static const playerPageSize = 20;
  static const presetQuestions = <String>[
    'Should I wildcard?',
    'Best transfer?',
    'Captain pick?',
    'Fixture analysis',
  ];
  static const formationOptions = <String>[
    '3-4-3',
    '3-5-2',
    '4-4-2',
    '4-3-3',
    '4-5-1',
    '5-3-2',
    '5-4-1',
  ];
}

class FantasyRoutePaths {
  static const root = '/fantasy';
}
