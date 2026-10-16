import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Limite del server per ogni pagina (1,2 MB).
const maxPageBytes = 1200 * 1024;

class ShrinkException implements Exception {
  ShrinkException(this.message);
  final String message;
}

/// Legge una foto e la riduce (JPEG) finché sta sotto il limite del server.
/// Il testo resta leggibile: lato lungo fino a 2000 px, qualità scalata da 82 a 55.
Future<Uint8List> shrinkForUpload(File file) async {
  final bytes = await file.readAsBytes();
  final out = await compute(_shrink, bytes);
  if (out == null) throw ShrinkException('Non riesco a leggere questa foto. Rifai la scansione.');
  if (out.length > maxPageBytes) {
    throw ShrinkException('La pagina è troppo pesante anche ridotta. Rifai la scansione con più luce.');
  }
  return out;
}

Uint8List? _shrink(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  var image = img.bakeOrientation(decoded);
  const sizes = [2000, 1700, 1400];
  const qualities = [82, 70, 55];
  Uint8List? last;
  for (final size in sizes) {
    final longEdge = image.width > image.height ? image.width : image.height;
    final work = longEdge > size
        ? img.copyResize(image,
            width: image.width >= image.height ? size : null,
            height: image.height > image.width ? size : null,
            interpolation: img.Interpolation.average)
        : image;
    for (final q in qualities) {
      last = Uint8List.fromList(img.encodeJpg(work, quality: q));
      if (last.length <= maxPageBytes) return last;
    }
  }
  return last;
}
