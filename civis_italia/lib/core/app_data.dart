import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'api.dart';
import 'models.dart';
import 'session.dart';

/// Documenti e scadenze dell'utente, caricati dal server.
class AppData extends ChangeNotifier {
  AppData(this.api);

  final ApiClient api;

  List<DocItem> docs = [];
  List<DeadlineItem> deadlines = [];
  bool loading = false;
  bool loadedOnce = false;
  String? error;

  List<DeadlineItem> get openDeadlines {
    final list = deadlines.where((d) => !d.done).toList();
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  DocItem? docById(String id) {
    for (final d in docs) {
      if (d.id == id) return d;
    }
    return null;
  }

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait([api.documents(), api.deadlines()]);
      docs = results[0].map(DocItem.fromJson).toList();
      deadlines = results[1].map(DeadlineItem.fromJson).toList();
      loadedOnce = true;
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Non sono riuscito a caricare i dati. Riprova.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Inserisce o aggiorna un documento già ricevuto dal server.
  void upsertDoc(DocItem d) {
    final i = docs.indexWhere((x) => x.id == d.id);
    if (i == -1) {
      docs = [d, ...docs];
    } else {
      docs = [...docs]..[i] = d;
    }
    notifyListeners();
  }

  /// Toglie subito una scadenza dall'elenco (serve a Dismissible), prima della chiamata al server.
  void removeDeadlineLocal(String id) {
    deadlines = deadlines.where((d) => d.id != id).toList();
    notifyListeners();
  }

  Future<void> deleteDoc(String id) async {
    await api.deleteDocument(id);
    await refresh();
  }

  void clear() {
    docs = [];
    deadlines = [];
    loadedOnce = false;
    error = null;
    notifyListeners();
  }
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.session, required this.data, required super.child});

  final Session session;
  final AppData data;

  ApiClient get api => data.api;

  static AppScope of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope oldWidget) => session != oldWidget.session || data != oldWidget.data;
}
