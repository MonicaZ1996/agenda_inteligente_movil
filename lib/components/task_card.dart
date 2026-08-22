import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TaskCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool isCompleted;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const TaskCard({
    super.key,
    required this.title,
    this.subtitle,
    this.isCompleted = false,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isCompleted ? AppColors.success : AppColors.textSecondary,
        ),
        title: Text(
          title,
          style: TextStyle(
            decoration: isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: onDelete != null
            ? IconButton(
                icon: const Icon(Icons.delete, color: AppColors.error),
                onPressed: onDelete,
              )
            : null,
      ),
    );
  }
}