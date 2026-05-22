import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

/// Generates assets/icon/icon.png — a gradient tile with a white progress
/// ring (open at top) and a checkmark: "tracking" + "done".
void main() {
  const size = 1024;
  const cx = 512.0, cy = 512.0;
  final image = img.Image(width: size, height: size);

  const c1 = [0x6D, 0x5D, 0xF6]; // indigo
  const c2 = [0x93, 0x33, 0xEA]; // violet
  const c3 = [0xEC, 0x48, 0x99]; // pink

  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final t = (x + y) / (2 * size);
      int r, g, b;
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
      // White progress ring (radius ~331, thick), with a gap near the top.
      final dx = x - cx, dy = y - cy;
      final d = sqrt(dx * dx + dy * dy);
      if (d >= 300 && d <= 362) {
        final deg = atan2(dy, dx) * 180 / pi; // top = -90°
        if (!(deg > -116 && deg < -64)) {
          r = 255;
          g = 255;
          b = 255;
        }
      }
      image.setPixelRgb(x, y, r, g, b);
    }
  }

  // Checkmark inside the ring
  final white = img.ColorRgb8(255, 255, 255);
  img.drawLine(image, x1: 385, y1: 548, x2: 470, y2: 636, color: white, thickness: 58, antialias: true);
  img.drawLine(image, x1: 470, y1: 636, x2: 648, y2: 432, color: white, thickness: 58, antialias: true);

  Directory('assets/icon').createSync(recursive: true);
  File('assets/icon/icon.png').writeAsBytesSync(img.encodePng(image));
  // ignore: avoid_print
  print('Wrote assets/icon/icon.png');
}
