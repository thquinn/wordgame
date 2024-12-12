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

  static const List<double> kDeltaIndex = <double>[
    //
    0, 0.01, 0.02, 0.04, 0.05, 0.06, 0.07, 0.08, 0.1, 0.11,
    //
    0.12, 0.14, 0.15, 0.16, 0.17, 0.18, 0.20, 0.21, 0.22, 0.24,
    //
    0.25, 0.27, 0.28, 0.30, 0.32, 0.34, 0.36, 0.38, 0.40, 0.42,
    //
    0.44, 0.46, 0.48, 0.5, 0.53, 0.56, 0.59, 0.62, 0.65, 0.68,
    //
    0.71, 0.74, 0.77, 0.80, 0.83, 0.86, 0.89, 0.92, 0.95, 0.98,
    //
    1.0, 1.06, 1.12, 1.18, 1.24, 1.30, 1.36, 1.42, 1.48, 1.54,
    //
    1.60, 1.66, 1.72, 1.78, 1.84, 1.90, 1.96, 2.0, 2.12, 2.25,
    //
    2.37, 2.50, 2.62, 2.75, 2.87, 3.0, 3.2, 3.4, 3.6, 3.8,
    //
    4.0, 4.3, 4.7, 4.9, 5.0, 5.5, 6.0, 6.5, 6.8, 7.0,
    //
    7.3, 7.5, 7.8, 8.0, 8.4, 8.7, 9.0, 9.4, 9.6, 9.8,
    //
    10.0
  ];
  static List<double> adjustContrast(double percent) {
    double x;
    final idx = percent.toInt();
    if (percent < 0) {
      x = 127 + percent / 100 * 127;
    } else {
      x = percent % 1;
      if (x == 0) {
        x = kDeltaIndex[idx];
      } else {
        //x = DELTA_INDEX[(p_val<<0)]; // this is how the IDE does it.
        x = kDeltaIndex[(idx << 0)] * (1 - x) +
            kDeltaIndex[(idx << 0) + 1] *
                x; // use linear interpolation for more granularity.
      }
      x = x * 127 + 127;
    }
    return [
      //
      x / 127, 0, 0, 0, 0.5 * (127 - x),
      //
      0, x / 127, 0, 0, 0.5 * (127 - x),
      //
      0, 0, x / 127, 0, 0.5 * (127 - x),
      //
      0, 0, 0, 1, 0,
      //
      0, 0, 0, 0, 1,
    ];
  }
}