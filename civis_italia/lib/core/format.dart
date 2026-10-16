const _months = [
  'gennaio',
  'febbraio',
  'marzo',
  'aprile',
  'maggio',
  'giugno',
  'luglio',
  'agosto',
  'settembre',
  'ottobre',
  'novembre',
  'dicembre',
];

/// Esempio: 6 ottobre 2026
String itDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// Data AAAA-MM-GG, come la usa il server.
String isoDay(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

DateTime parseDay(String s) {
  final p = s.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// Giorni di calendario da oggi (negativo se già passata).
int daysUntil(DateTime d) {
  final now = DateTime.now();
  final a = DateTime.utc(now.year, now.month, now.day);
  final b = DateTime.utc(d.year, d.month, d.day);
  return b.difference(a).inDays;
}

String relativeDays(DateTime d) {
  final n = daysUntil(d);
  if (n == 0) return 'oggi';
  if (n == 1) return 'domani';
  if (n == -1) return 'ieri';
  if (n > 1) return 'tra $n giorni';
  return 'scaduta da ${-n} giorni';
}

/// Esempio: € 1.234,50
String euro(num value) {
  final fixed = value.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final intPart = parts[0];
  final buffer = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    final fromEnd = intPart.length - i;
    buffer.write(intPart[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) buffer.write('.');
  }
  final sign = value < 0 ? '-' : '';
  return '$sign€ ${buffer.toString()},${parts[1]}';
}

String pagesLabel(int n) => '$n ${n == 1 ? 'pagina' : 'pagine'}';
