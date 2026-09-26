import 'dart:convert';

import 'package:http/http.dart' as http;

enum Weather { clear, cloudy, fog, rain, snow }

/// Open-Meteo needs no API key. Only called when the user enabled weather.
class WeatherService {
  WeatherService({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  Future<Weather?> current(double lat, double lng) async {
    try {
      // Coordinates are rounded: city-level accuracy is plenty for ambience.
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': lat.toStringAsFixed(1),
        'longitude': lng.toStringAsFixed(1),
        'current': 'weather_code',
      });
      final res = await _http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final code = (jsonDecode(res.body)['current']['weather_code'] as num).toInt();
      return fromCode(code);
    } catch (_) {
      return null;
    }
  }

  static Weather fromCode(int c) {
    if (c == 0 || c == 1) return Weather.clear;
    if (c == 2 || c == 3) return Weather.cloudy;
    if (c == 45 || c == 48) return Weather.fog;
    if ((c >= 71 && c <= 77) || c == 85 || c == 86) return Weather.snow;
    if ((c >= 51 && c <= 67) || (c >= 80 && c <= 82) || c >= 95) return Weather.rain;
    return Weather.clear;
  }
}
