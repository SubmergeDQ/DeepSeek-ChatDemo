import 'package:flutter/material.dart';

import '../../core/ext.dart';
import '../widgets/common.dart';

class WelcomeView extends StatelessWidget {
  const WelcomeView({
    super.key,
    required this.modelName,
    required this.onModelTap,
  });

  final String modelName;
  final VoidCallback? onModelTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.scheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Logo(size: 68, radius: 21),
                    const SizedBox(height: 18),
                    Text(
                      l10n.welcomeTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                        height: 1.33,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: onModelTap,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: scheme.outlineVariant, width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.memory_rounded,
                                size: 14,
                                color: scheme.onSurface.withValues(alpha: 0.42),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                modelName.isEmpty ? l10n.selectModel : modelName,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: scheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 16,
                                color: scheme.onSurface.withValues(alpha: 0.4),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
