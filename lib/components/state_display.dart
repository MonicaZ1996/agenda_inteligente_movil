import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum DisplayStateEnum { loading, empty, error, content }

class StateDisplay extends StatelessWidget {
  final DisplayStateEnum state;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final Widget? child;

  const StateDisplay({
    super.key,
    required this.state,
    this.errorMessage,
    this.onRetry,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case DisplayStateEnum.loading:
        return const Center(child: CircularProgressIndicator());

      case DisplayStateEnum.empty:
        return Center(
          child: Text(
            'No hay tareas disponibles.',
            style: AppTextStyles.subtitle,
          ),
        );

      case DisplayStateEnum.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AppColors.error,
                  size: 48,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  errorMessage ?? 'Ocurrió un error inesperado.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  ElevatedButton(
                    onPressed: onRetry,
                    child: const Text('Reintentar'),
                  ),
                ],
              ],
            ),
          ),
        );

      case DisplayStateEnum.content:
        return child ?? const SizedBox.shrink();
    }
  }
}