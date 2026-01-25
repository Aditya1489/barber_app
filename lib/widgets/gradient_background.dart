import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:barber_sync/core/theme/app_theme.dart';

class GradientBackground extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const GradientBackground({
    super.key,
    required this.child,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    AppTheme.darkBGStart,
                    AppTheme.darkBGMiddle,
                    AppTheme.darkBGEnd,
                  ]
                : [
                    AppTheme.lightBGStart,
                    AppTheme.lightBGMiddle,
                    AppTheme.lightBGEnd,
                  ],
          ),
        ),
        child: child,
      ),
    );
  }
}
