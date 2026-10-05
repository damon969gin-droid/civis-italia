import 'package:flutter/material.dart';

class CivisItaliaApp extends StatelessWidget {
  const CivisItaliaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Civis Italia',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF003366), // Blu istituzionale
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF003366),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePlaceholder(),
    );
  }
}

class HomePlaceholder extends StatelessWidget {
  const HomePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Civis Italia'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.document_scanner_outlined, size: 80),
            const SizedBox(height: 24),
            Text(
              'Civis Italia',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Il tuo assistente per la burocrazia',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 48),
            FilledButton.icon(
              onPressed: () {
                // TODO: aprire fotocamera / picker
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text('Fotografa documento'),
            ),
          ],
        ),
      ),
    );
  }
}
