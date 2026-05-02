part of urbanecho;

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.savedPlaces,
    required this.onOpenMap,
    required this.onOpenFavorites,
    required this.onBrowseActivity,
  });

  final List<SavedPlaceLog> savedPlaces;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenFavorites;
  final ValueChanged<String> onBrowseActivity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final favoritePlaceCount = savedPlaces.length;
    final weekStart = DateTime.now().subtract(const Duration(days: 7));
    final addedThisWeek = savedPlaces
        .where((place) => place.recordedAt.isAfter(weekStart))
        .length;
    final recentPlaces = savedPlaces.take(2).toList();

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: _paper,
              border: const Border(bottom: BorderSide(color: _paperLine)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _LogoMark(),
                      const SizedBox(width: 8),
                      Text(
                        'UrbanEcho',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your city, your notes.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _mutedInk,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel('Your places'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _HomeStatCard(
                        value: '$favoritePlaceCount',
                        label: 'Favorite places',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _HomeStatCard(
                        value: '$addedThisWeek',
                        label: 'Added this week',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _SectionLabel('Browse by activity'),
                const SizedBox(height: 10),
                _HomeAllPlacesCta(onTap: () => onBrowseActivity('All')),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _UseCaseChip(
                    icon: Icons.menu_book_outlined,
                    label: 'Study',
                    onTap: () => onBrowseActivity('Study'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _UseCaseChip(
                    icon: Icons.spa_outlined,
                    label: 'Rest',
                    onTap: () => onBrowseActivity('Rest'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _UseCaseChip(
                    icon: Icons.groups_outlined,
                    label: 'Social',
                    onTap: () => onBrowseActivity('Social'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _HomeMapCta(onOpenMap: onOpenMap),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                const Expanded(child: _SectionLabel('Recent favorites')),
                TextButton(
                  onPressed: onOpenFavorites,
                  child: const Text('View favorites'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: recentPlaces.isEmpty
                ? _RecentEmpty(onOpenMap: onOpenMap)
                : Column(
                    children: recentPlaces
                        .map((place) => _RecentPlaceItem(place: place))
                        .toList(),
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
