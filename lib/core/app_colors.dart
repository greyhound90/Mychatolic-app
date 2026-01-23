import 'package:flutter/material.dart';

class AppColors {
  // 1. Primary Brand (#0088CC Light | #4DA3D9 Dark/Muted)
  // Target: Header, Elev Button, Link, Active Icon, FAB.
  static const Color primaryBrand = Color(0xFF0088CC);
  static const Color primaryBrandDark = Color(0xFF4DA3D9);

  // 2. Primary Hover (#007AB8)
  // Target: Button Pressed State.
  static const Color primaryHover = Color(0xFF007AB8);

  // 3. Background Main (#FFFFFF Light | #121212 Dark)
  // Target: Scaffold.
  static const Color backgroundMain = Color(0xFFFFFFFF);
  static const Color backgroundMainDark = Color(0xFF121212);

  // 4. Background Surface (#F5F5F5 Light | #1C1C1C Dark)
  // Target: Card, Column Input, Bubble Chat.
  static const Color surface = Color(0xFFF5F5F5);
  static const Color surfaceDark = Color(0xFF1C1C1C);

  // 5. Text Primary (#000000 Light | #FFFFFF Dark)
  static const Color textPrimary = Color(0xFF000000);
  static const Color textPrimaryDark = Color(0xFFFFFFFF);

  // 6. Text Secondary (#555555 Light | #BBBBBB Dark)
  static const Color textSecondary = Color(0xFF555555);
  static const Color textSecondaryDark = Color(0xFFBBBBBB);

  // 7. Status
  static const Color success = Color(0xFF2ECC71);
  static const Color error = Color(0xFFE74C3C);

  // 8. Disabled (#9E9E9E Light | #555555 Dark)
  static const Color disabled = Color(0xFF9E9E9E);
  static const Color disabledDark = Color(0xFF555555);
}
