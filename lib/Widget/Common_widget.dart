import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Labeled text input matching `.field` + `.input-wrap` from the prototype.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.hint,
    this.icon,
    this.obscure = false,
    this.keyboardType,
    this.controller,
    this.onChanged,
    this.showToggle = false,
  });

  final String label;
  final String hint;
  final IconData? icon;
  final bool obscure;
  final bool showToggle;
  final TextInputType? keyboardType;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscured = widget.obscure;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: AppTextStyles.body(
            size: 11,
            weight: FontWeight.w700,
            color: AppColors.slate600,
          ).copyWith(letterSpacing: 0.9),
        ),
        const SizedBox(height: 7),
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: _focused ? AppColors.blue500 : AppColors.slate200,
              width: 1.5,
            ),
            boxShadow: _focused
                ? [
              BoxShadow(
                color: AppColors.blue500.withOpacity(0.12),
                blurRadius: 0,
                spreadRadius: 4,
              ),
            ]
                : null,
          ),
          child: Row(
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 18, color: AppColors.slate400),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Focus(
                  onFocusChange: (f) => setState(() => _focused = f),
                  child: TextField(
                    controller: widget.controller,
                    obscureText: _obscured,
                    keyboardType: widget.keyboardType,
                    onChanged: widget.onChanged,
                    style: AppTextStyles.body(size: 14.5),
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      hintStyle: AppTextStyles.body(
                        size: 14.5,
                        color: const Color(0xFFAEB8CF),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ),
              if (widget.showToggle)
                GestureDetector(
                  onTap: () => setState(() => _obscured = !_obscured),
                  child: Icon(
                    _obscured
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                    color: AppColors.slate400,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Primary gradient button matching `.btn-primary`.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon = Icons.arrow_forward_rounded,
    this.gold = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool gold;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        decoration: BoxDecoration(
          gradient: gold ? AppColors.goldGradient : AppColors.blueGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: (gold ? AppColors.gold500 : AppColors.blue600)
                  .withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: AppTextStyles.body(
                size: 14.5,
                weight: FontWeight.w700,
                color: gold ? AppColors.navy950 : Colors.white,
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: 8),
              Icon(icon, size: 16, color: gold ? AppColors.navy950 : Colors.white),
            ],
          ],
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: child) : child;
  }
}

/// Dark hero header used at the top of auth screens matching `.auth-hero`.
class AuthHero extends StatelessWidget {
  const AuthHero({
    super.key,
    required this.title,
    required this.subtitle,
    this.showBack = false,
    this.onBack,
    this.showBadge = true,
    this.height = 200,
  });

  final String title;
  final String subtitle;
  final bool showBack;
  final VoidCallback? onBack;
  final bool showBadge;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(26, 22, 26, 26),
      decoration: BoxDecoration(
        gradient: AppColors.navyGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(0),
          bottomRight: Radius.circular(0),
        ),
      ),
      child: Stack(
        children: [
          // subtle radial glow
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold400.withOpacity(0.12),
              ),
            ),
          ),
          if (showBack)
            Positioned(
              top: 0,
              left: 0,
              child: GestureDetector(
                onTap: onBack,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: Colors.white.withOpacity(0.14)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 16, color: Colors.white),
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showBadge) ...[
                  Container(
                    width: 44,
                    height: 44,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      gradient: AppColors.blueGradient,
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.blue600.withOpacity(0.45),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text('FR',
                        style: AppTextStyles.display(
                            size: 15, weight: FontWeight.w800, color: Colors.white)),
                  ),
                ],
                Text(title,
                    style: AppTextStyles.display(
                        size: 23, weight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 5),
                Text(subtitle,
                    style: AppTextStyles.body(size: 13, color: AppColors.slate400)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
