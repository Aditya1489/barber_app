import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:barber_sync/widgets/gradient_background.dart';
import 'package:barber_sync/core/theme/app_theme.dart';
import 'package:barber_sync/core/providers/theme_provider.dart';
import 'package:barber_sync/core/providers/locale_provider.dart';
import 'package:barber_sync/l10n/app_localizations.dart';

class LanguageSelectionScreen extends ConsumerWidget {
  const LanguageSelectionScreen({super.key});

  String _getCurrentLanguageName(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return 'English';
      case 'hi':
        return 'हिंदी';
      case 'es':
        return 'Español';
      case 'ar':
        return 'العربية';
      default:
        return 'English';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider);
    final currentLocale = ref.watch(localeProvider);

    // Indian languages first (English, Hindi), then other languages
    final languages = [
      {'code': 'en', 'name': 'English', 'flag': '🇬🇧'},
      {'code': 'hi', 'name': 'हिंदी (Hindi)', 'flag': '🇮🇳'},
      {'code': 'es', 'name': 'Español (Spanish)', 'flag': '🇪🇸'},
      {'code': 'ar', 'name': 'العربية (Arabic)', 'flag': '🇸🇦'},
    ];

    return Scaffold(
      body: GradientBackground(
        isDark: isDark,
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => context.pop(),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(LucideIcons.arrowLeft, size: 20),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Text(
                      AppLocalizations.of(context)!.selectLanguage,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              
              // Language List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: languages.length,
                  itemBuilder: (context, index) {
                    final lang = languages[index];
                    final isSelected = currentLocale.languageCode == lang['code'];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
                        borderRadius: BorderRadius.circular(24),
                        border: isSelected
                            ? Border.all(color: AppTheme.emerald, width: 2)
                            : null,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: Text(
                          lang['flag']!,
                          style: const TextStyle(fontSize: 32),
                        ),
                        title: Text(
                          lang['name']!,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(LucideIcons.checkCircle, color: AppTheme.emerald, size: 24)
                            : null,
                        onTap: () {
                          ref.read(localeProvider.notifier).setLocale(
                                Locale(lang['code']!),
                              );
                          // Small delay to show selection before popping
                          Future.delayed(const Duration(milliseconds: 200), () {
                            if (context.mounted) {
                              context.pop();
                            }
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
