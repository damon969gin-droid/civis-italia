import 'package:flutter/material.dart';

import '../../core/app_data.dart';
import '../auth/recovery_dialog.dart';
import '../chat/chat_page.dart';
import '../deadlines/deadlines_tab.dart';
import '../documents/documents_tab.dart';
import '../profile/profile_tab.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final scope = AppScope.of(context);
      scope.data.refresh();
      // Dopo la registrazione o il recupero: si mostra il nuovo codice, una volta sola.
      final code = scope.session.pendingRecoveryCode;
      if (code != null) {
        scope.session.pendingRecoveryCode = null;
        showRecoveryCodeDialog(context, code);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          DocumentsTab(),
          DeadlinesTab(),
          ChatPage(),
          ProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder), label: 'Documenti'),
          NavigationDestination(icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event), label: 'Scadenze'),
          NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Chiedi'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profilo'),
        ],
      ),
    );
  }
}
