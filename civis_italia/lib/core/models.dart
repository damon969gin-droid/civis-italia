import 'format.dart';

class DocItem {
  DocItem({
    required this.id,
    required this.title,
    required this.pages,
    required this.status,
    required this.createdAt,
    this.analysis,
  });

  final String id;
  final String title;
  final int pages;

  /// draft = caricato ma non ancora letto, analyzed = letto, failed = errore o illeggibile.
  final String status;
  final DateTime createdAt;
  final Map<String, dynamic>? analysis;

  bool get isAnalyzed => status == 'analyzed' && analysis != null;

  factory DocItem.fromJson(Map<String, dynamic> j) => DocItem(
        id: j['id'] as String,
        title: j['title'] as String,
        pages: (j['pages'] as num).toInt(),
        status: j['status'] as String,
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '')?.toLocal() ?? DateTime.now(),
        analysis: j['analysis'] is Map ? Map<String, dynamic>.from(j['analysis'] as Map) : null,
      );
}

class DeadlineItem {
  DeadlineItem({
    required this.id,
    required this.title,
    required this.date,
    required this.note,
    required this.done,
    required this.auto,
    this.docId,
  });

  final String id;
  final String title;
  final DateTime date;
  final String note;
  final bool done;
  final bool auto;
  final String? docId;

  factory DeadlineItem.fromJson(Map<String, dynamic> j) => DeadlineItem(
        id: j['id'] as String,
        title: j['title'] as String,
        date: parseDay(j['date'] as String),
        note: (j['note'] as String?) ?? '',
        done: (j['done'] as bool?) ?? false,
        auto: (j['auto'] as bool?) ?? false,
        docId: j['docId'] as String?,
      );
}
