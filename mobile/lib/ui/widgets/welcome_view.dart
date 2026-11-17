import 'package:flutter/material.dart';

import '../../core/ext.dart';
import '../widgets/common.dart';

class WelcomeView extends StatelessWidget {
  const WelcomeView({
    super.key,
    required this.onSuggestion,
    required this.modelName,
  });

  final ValueChanged<String> onSuggestion;
  final String modelName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.scheme;
    final suggestions = [
      (Icons.science_outlined, l10n.suggestion1),
      (Icons.mail_outline_rounded, l10n.suggestion2),
      (Icons.code_rounded, l10n.suggestion3),
      (Icons.fitness_center_rounded, l10n.suggestion4),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            children: [
              const Logo(size: 62, radius: 20),
              const SizedBox(height: 20),
              Text(
                l10n.welcomeTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.welcomeSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: scheme.onSurface.withValues(alpha: 0.5),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: scheme.outlineVariant, width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.memory_rounded, size: 13, color: scheme.onSurface.withValues(alpha: 0.45)),
                    const SizedBox(width: 5),
                    Text(
                      modelName,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 34),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 420;
                  if (compact) {
                    return Column(
                      children: [
                        for (final item in suggestions)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _SuggestionCard(
                              icon: item.$1,
                              text: item.$2,
                              onTap: () => onSuggestion(item.$2),
                            ),
                          ),
                      ],
                    );
                  }
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final item in suggestions)
                        SizedBox(
                          width: (constraints.maxWidth - 10) / 2,
                          child: _SuggestionCard(
                            icon: item.$1,
                            text: item.$2,
                            onTap: () => onSuggestion(item.$2),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outlineVariant, width: 0.8),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: scheme.onSurface.withValues(alpha: 0.55)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.35,
                    color: scheme.onSurface.withValues(alpha: 0.82),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
