import 'dart:math';
import 'dart:ui';

// from https://github.com/roipeker/graphx
class ColorMatrixHSVC {
  static ColorFilter make({hue = 0.0, saturation = 1.0, brightness = 1.0, contrast = 1.0}) {
    List<double> matrix = [
      1, 0, 0, 0, 0,
      //
      0, 1, 0, 0, 0,
      //
      0, 0, 1, 0, 0,
      //
      0, 0, 0, 1, 0,
      //
      0, 0, 0, 0, 1,
    ];
    if (hue != 0.0) {
      matrix = multiplyMatrices(matrix, adjustHue(hue));
    }
    if (saturation != 1.0) {
      matrix = multiplyMatrices(matrix, adjustSaturation(saturation));
    }
    if (brightness != 1.0) {
      matrix = multiplyMatrices(matrix, adjustBrightness(brightness));
    }
    if (contrast != 1.0) {
      matrix = multiplyMatrices(matrix, adjustContrast(contrast));
    }
    return ColorFilter.matrix(matrix.sublist(0, 20));
  }

  static List<double> multiplyMatrices(List<double> a, List<double> b) {
    var col = List<double>.filled(25, 0);
    var ret = List<double>.filled(25, 0);
    for (var i = 0; i < 5; i++) {
      for (var j = 0; j < 5; j++) {
        col[j] = a[j + i * 5];
      }
      for (var j = 0; j < 5; j++) {
        var val = 0.0;
        for (var k = 0; k < 5; k++) {
          val += b[j + k * 5] * col[k];
        }
        ret[j + i * 5] = val;
      }
    }
    return ret;
  }

  static List<double> adjustHue(double percent) {
    percent *= 2 * pi;
    final cosVal = cos(percent);
    final sinVal = sin(percent);
    const lumR = 0.213;
    const lumG = 0.715;
    const lumB = 0.072;
    return [
      //
      lumR + cosVal * (1 - lumR) + sinVal * -lumR,
      lumG + cosVal * -lumG + sinVal * -lumG,
      lumB + cosVal * -lumB + sinVal * (1 - lumB),
      0,
      0,
      //
      lumR + cosVal * -lumR + sinVal * 0.143,
      lumG + cosVal * (1 - lumG) + sinVal * 0.140,
      lumB + cosVal * -lumB + sinVal * -0.283,
      0,
      0,
      //
      lumR + cosVal * -lumR + sinVal * -(1 - lumR),
      lumG + cosVal * -lumG + sinVal * lumG,
      lumB + cosVal * (1 - lumB) + sinVal * lumB,
      0,
      0,
      //
      0, 0, 0, 1, 0,
      //
      0, 0, 0, 0, 1,
    ];
  }

  static List<double> adjustSaturation(double x) {
    const lumR = 0.3086;
    const lumG = 0.6094;
    const lumB = 0.0820;
    return [
      //
      lumR * (1 - x) + x, lumG * (1 - x), lumB * (1 - x), 0, 0,
      //
      lumR * (1 - x), lumG * (1 - x) + x, lumB * (1 - x), 0, 0,
      //
      lumR * (1 - x), lumG * (1 - x), lumB * (1 - x) + x, 0, 0,
      //
      0, 0, 0, 1, 0,
      //
      0, 0, 0, 0, 1,
    ];
  }

  static List<double> adjustBrightness(double percent) {
    percent *= 100;
    return [
      1, 0, 0, 0, percent,
      //
      0, 1, 0, 0, percent,
      //
      0, 0, 1, 0, percent,
      //
      0, 0, 0, 1, 0,
      //
      0, 0, 0, 0, 1,
    ];
  }

  // from https://docs.rainmeter.net/tips/colormatrix-guide/
  static List<double> adjustContrast(double percent) {
    final t = (1 - percent ) / 2;
    return [
      //
      percent, 0, 0, 0, 0,
      //
      0, percent, 0, 0, 0,
      //
      0, 0, percent, 0, 0,
      //
      0, 0, 0, 1, 0,
      //
      t, t, t, 0, 1,
    ];
  }
}