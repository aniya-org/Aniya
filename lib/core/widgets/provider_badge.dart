import 'package:flutter/material.dart';

/// A badge widget that displays provider attribution
class ProviderBadge extends StatelessWidget {
  final String providerId;
  final VoidCallback? onTap;
  final bool isSmall;

  const ProviderBadge({
    super.key,
    required this.providerId,
    this.onTap,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final providerInfo = _getProviderInfo(providerId);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 6 : 8,
          vertical: isSmall ? 2 : 4,
        ),
        decoration: BoxDecoration(
          color: providerInfo.color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: providerInfo.color.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              providerInfo.icon,
              size: isSmall ? 12 : 14,
              color: providerInfo.color,
            ),
            SizedBox(width: isSmall ? 3 : 4),
            Text(
              providerInfo.name,
              style: theme.textTheme.labelSmall?.copyWith(
                color: providerInfo.color,
                fontWeight: FontWeight.w600,
                fontSize: isSmall ? 10 : 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  _ProviderInfo _getProviderInfo(String providerId) {
    switch (providerId.toLowerCase()) {
      case 'tmdb':
        return _ProviderInfo(
          name: 'TMDB',
          icon: Icons.movie,
          color: const Color(0xFF01B4E4),
        );
      case 'anilist':
        return _ProviderInfo(
          name: 'AniList',
          icon: Icons.list_alt,
          color: const Color(0xFF02A9FF),
        );
      case 'jikan':
        return _ProviderInfo(
          name: 'MAL',
          icon: Icons.star,
          color: const Color(0xFF2E51A2),
        );
      case 'kitsu':
        return _ProviderInfo(
          name: 'Kitsu',
          icon: Icons.pets,
          color: const Color(0xFFFF6B35),
        );
      case 'simkl':
        return _ProviderInfo(
          name: 'Simkl',
          icon: Icons.tv,
          color: const Color(0xFF0B0F10),
        );
      default:
        return _ProviderInfo(
          name: providerId.toUpperCase(),
          icon: Icons.source,
          color: Colors.grey,
        );
    }
  }
}

class _ProviderInfo {
  final String name;
  final IconData icon;
  final Color color;

  _ProviderInfo({required this.name, required this.icon, required this.color});
}

/// A widget that displays multiple provider badges
class ProviderBadgeList extends StatelessWidget {
  final List<String> providers;
  final Function(String)? onProviderTap;
  final bool isSmall;

  const ProviderBadgeList({
    super.key,
    required this.providers,
    this.onProviderTap,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    if (providers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: providers.map((provider) {
        return ProviderBadge(
          providerId: provider,
          onTap: onProviderTap != null ? () => onProviderTap!(provider) : null,
          isSmall: isSmall,
        );
      }).toList(),
    );
  }
}
