import 'package:flutter/material.dart';

class AppColors {
  static const Color backgroundGreen = Color(0xFFCCFF00); // Strict Lime Green
  static const Color borderBlack = Colors.black;
  static const Color surfaceWhite = Colors.white;
}

class NeoCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  const NeoCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderBlack, width: 2.5), // Thick 2.5px
          boxShadow: const [
            BoxShadow(
              color: Colors.black, // Hard Solid Shadow
              offset: Offset(4, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class NeoInputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool isPassword;
  final IconData? icon;

  const NeoInputField({
    super.key,
    required this.label,
    required this.controller,
    this.isPassword = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            color: Colors.black,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderBlack, width: 2.5), // Thick 2.5px
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
            decoration: InputDecoration(
              prefixIcon: icon != null ? Icon(icon, color: Colors.black) : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              hintText: "Enter ${label.toLowerCase()}...",
              hintStyle: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.normal),
            ),
          ),
        ),
      ],
    );
  }
}

class NeoButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const NeoButton({super.key, required this.text, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: const [
          BoxShadow(
            color: Colors.black, // Hard Shadow for button too
            offset: Offset(4, 4),
            blurRadius: 0,
          ),
        ],
        borderRadius: BorderRadius.circular(16),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 60,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.black, width: 2.5),
            ),
          ),
          child: Text(
            text.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1),
          ),
        ),
      ),
    );
  }
}
