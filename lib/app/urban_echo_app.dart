part of urbanecho;

class UrbanEchoApp extends StatelessWidget {
  const UrbanEchoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UrbanEcho',
      debugShowCheckedModeBanner: false,
      theme: _buildUrbanEchoTheme(),
      home: const AppShell(),
    );
  }
}
