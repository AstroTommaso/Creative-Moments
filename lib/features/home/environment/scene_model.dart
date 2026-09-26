import 'package:flutter/foundation.dart';

import '../../../core/services/weather_service.dart';

/// Mutable render state shared between the ticker and the painter.
class SceneModel extends ChangeNotifier {
  double t = 0; // seconds, wraps at 60 so every loop is seamless
  double hour = 22;
  String atmosphere = 'dreamy';
  double density = 1;
  double quality = 1; // particle multiplier (lower on calm screens)
  double parallax = 0; // px scrolled
  Weather? weather;
  double starBoost = 0; // 0..1 from moment history
  Map<String, double> presence = {}; // current, animated
  Map<String, double> target = {};

  void tick() => notifyListeners();
}
