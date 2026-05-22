import 'dart:io';
import 'package:image/image.dart' as img;

/// Generates assets/icon/icon.png — a gradient square with a white checkmark.
void main() {
  const size = 1024;
  final image = img.Image(width: size, height: size);

  // Diagonal gradient: indigo -> violet -> pink
  const c1 = [0x6D, 0x5D, 0xF6];
  const c2 = [0x93, 0x33, 0xEA];
  const c3 = [0xEC, 0x48, 0x99];
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final t = (x + y) / (2 * size);
      late int r, g, b;
      if (t < 0.5) {
        final u = t / 0.5;
        r = (c1[0] + (c2[0] - c1[0]) * u).round();
        g = (c1[1] + (c2[1] - c1[1]) * u).round();
        b = (c1[2] + (c2[2] - c1[2]) * u).round();
      } else {
        final u = (t - 0.5) / 0.5;
        r = (c2[0] + (c3[0] - c2[0]) * u).round();
        g = (c2[1] + (c3[1] - c2[1]) * u).round();
        b = (c2[2] + (c3[2] - c2[2]) * u).round();
      }
      image.setPixelRgb(x, y, r, g, b);
    }
  }

  // White rounded checkmark
  final white = img.ColorRgb8(255, 255, 255);
  img.drawLine(image, x1: 300, y1: 545, x2: 445, y2: 695, color: white, thickness: 78, antialias: true);
  img.drawLine(image, x1: 445, y1: 695, x2: 735, y2: 350, color: white, thickness: 78, antialias: true);

  Directory('assets/icon').createSync(recursive: true);
  File('assets/icon/icon.png').writeAsBytesSync(img.encodePng(image));
  // ignore: avoid_print
  print('Wrote assets/icon/icon.png');
}
