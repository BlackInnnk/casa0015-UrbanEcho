part of urbanecho;

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _terracotta,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const SizedBox(
        width: 28,
        height: 28,
        child: Icon(Icons.place_outlined, color: Colors.white, size: 17),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: _mutedInk,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _HomeStatCard extends StatelessWidget {
  const _HomeStatCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _paperLine),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: _deepBrown,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(color: _mutedInk),
            ),
          ],
        ),
      ),
    );
  }
}

class _UseCaseChip extends StatelessWidget {
  const _UseCaseChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = switch (label) {
      'Study' => (background: _tealSoft, foreground: const Color(0xFF2A5C54)),
      'Rest' => (background: _amberSoft, foreground: const Color(0xFF6B4A20)),
      _ => (background: _terracottaSoft, foreground: const Color(0xFF7A3018)),
    };

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _placeTypeColor(label),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 5),
              Icon(icon, color: colors.foreground, size: 17),
              const SizedBox(height: 3),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeAllPlacesCta extends StatelessWidget {
  const _HomeAllPlacesCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _paper,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _paperLine),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _deepBrown,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.public, color: _cream, size: 17),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'All places',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Browse every shared city note',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: _mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward, color: _brown, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeMapCta extends StatelessWidget {
  const _HomeMapCta({required this.onOpenMap});

  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onOpenMap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _deepBrown,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Open map',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: _cream,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Explore & record places around you',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFFB0A090),
                      ),
                    ),
                  ],
                ),
              ),
              const CircleAvatar(
                radius: 14,
                backgroundColor: Color(0x22FFFFFF),
                child: Icon(Icons.arrow_forward, color: Colors.white, size: 17),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentEmpty extends StatelessWidget {
  const _RecentEmpty({required this.onOpenMap});

  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onOpenMap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: _terracotta,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No favorite places yet. Open All places and bookmark one.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: _mutedInk),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentPlaceItem extends StatelessWidget {
  const _RecentPlaceItem({required this.place});

  final SavedPlaceLog place;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rating = place.rating;

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _paperDark)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _placeTypeColor(place.placeType),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${place.placeType} · ${_formatTime(place.recordedAt)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _mutedInk,
                    ),
                  ),
                ],
              ),
            ),
            if (rating != null)
              Text(
                '★ ${rating.toStringAsFixed(1)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: _terracotta,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
