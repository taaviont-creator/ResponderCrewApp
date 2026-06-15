import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class OrganizationHeader extends StatelessWidget {
  const OrganizationHeader({
    super.key,
    required this.organizationName,
    this.roleLabel,
    this.userInitials,
    this.onOrganizationPressed,
    this.onProfilePressed,
  });

  final String organizationName;
  final String? roleLabel;
  final String? userInitials;
  final VoidCallback? onOrganizationPressed;
  final VoidCallback? onProfilePressed;

  @override
  Widget build(BuildContext context) {
    final hasProfile = userInitials != null && userInitials!.trim().isNotEmpty;

    return Material(
      color: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.screenPadding,
            vertical: 8,
          ),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.border),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 390;

              return Row(
                children: [
                  const Icon(
                    Icons.anchor,
                    color: AppColors.navy,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    compact ? 'RC' : 'RESPONDCREW',
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 20,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: onOrganizationPressed,
                      borderRadius:
                          BorderRadius.circular(AppTheme.controlRadius),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    organizationName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.end,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(color: AppColors.navy),
                                  ),
                                  if (roleLabel != null &&
                                      roleLabel!.trim().isNotEmpty)
                                    Text(
                                      roleLabel!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                    ),
                                ],
                              ),
                            ),
                            if (onOrganizationPressed != null) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_drop_down,
                                color: AppColors.navy,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (hasProfile) ...[
                    const SizedBox(width: 8),
                    Semantics(
                      button: onProfilePressed != null,
                      label: 'Kasutaja profiil',
                      child: InkWell(
                        onTap: onProfilePressed,
                        customBorder: const CircleBorder(),
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.deepSeaBlue,
                          foregroundColor: Colors.white,
                          child: Text(
                            userInitials!.trim().toUpperCase(),
                            maxLines: 1,
                            style:
                                Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: Colors.white,
                                    ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
