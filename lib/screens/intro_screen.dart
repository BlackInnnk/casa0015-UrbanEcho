part of urbanecho;

class _IntroGate extends StatefulWidget {
  const _IntroGate();

  @override
  State<_IntroGate> createState() => _IntroGateState();
}

class _IntroGateState extends State<_IntroGate> {
  Timer? _introTimer;
  bool _showIntro = true;

  @override
  void initState() {
    super.initState();
    _introTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) {
        return;
      }

      setState(() {
        _showIntro = false;
      });
    });
  }

  @override
  void dispose() {
    _introTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: _showIntro
          ? const _IntroSplash(key: ValueKey('intro'))
          : const AppShell(key: ValueKey('app')),
    );
  }
}

class _IntroSplash extends StatelessWidget {
  const _IntroSplash({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: _cream,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _LogoMark(),
                const SizedBox(height: 18),
                Text(
                  'UrbanEcho',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: _deepBrown,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sense the city through noise, light, and shared place notes.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _mutedInk,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 26),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
