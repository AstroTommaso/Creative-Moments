import 'dart:math' as math;
import 'dart:ui';

import '../../data/models/moment.dart';

class CNode {
  CNode(this.moment, this.pos);
  final Moment moment;
  Offset pos;
}

class CEdge {
  const CEdge(this.a, this.b, this.weight);
  final int a, b;
  final double weight;
}

class Constellation {
  const Constellation(this.nodes, this.edges, this.size);
  final List<CNode> nodes;
  final List<CEdge> edges;
  final Size size;
}

/// How related two moments feel: shared inspirations, mood, type, time, place.
double similarity(Moment a, Moment b) {
  var s = 0.0;
  s += 2 * a.inspirationTypes.intersection(b.inspirationTypes).length;
  if (a.mood != null && a.mood == b.mood) s += 2;
  if (a.type == b.type) s += 1;
  if (a.timeOfDay != null && a.timeOfDay == b.timeOfDay) s += 0.5;
  if (a.createdAt.difference(b.createdAt).inHours.abs() <= 36) s += 1;
  if (a.hasLocation && a.locationName == b.locationName) s += 1.5;
  return s;
}

/// Deterministic force-directed layout so the same history always looks the same.
Constellation layoutConstellation(
  List<Moment> moments, {
  Size size = const Size(1000, 1300),
  int maxNodes = 250,
  double minSimilarity = 2,
  int maxEdgesPerNode = 3,
}) {
  final list = moments.take(maxNodes).toList();
  final n = list.length;
  final center = Offset(size.width / 2, size.height / 2);
  final nodes = <CNode>[];
  for (var i = 0; i < n; i++) {
    final r = 60.0 * math.sqrt(i + 0.5) + 30;
    final ang = i * 2.399963;
    nodes.add(CNode(list[i], center + Offset(math.cos(ang) * r, math.sin(ang) * r)));
  }

  // edges: strongest few per node
  final edgeMap = <int, CEdge>{};
  for (var i = 0; i < n; i++) {
    final cands = <(int, double)>[];
    for (var j = 0; j < n; j++) {
      if (i == j) continue;
      final s = similarity(list[i], list[j]);
      if (s >= minSimilarity) cands.add((j, s));
    }
    cands.sort((a, b) => b.$2.compareTo(a.$2));
    for (final (j, s) in cands.take(maxEdgesPerNode)) {
      final a = math.min(i, j), b = math.max(i, j);
      edgeMap[a * 100000 + b] = CEdge(a, b, s);
    }
  }
  final edges = edgeMap.values.toList();

  if (n > 1) {
    final vel = List.filled(n, Offset.zero);
    for (var it = 0; it < 70; it++) {
      final cool = 1 - it / 70;
      final force = List.filled(n, Offset.zero);
      for (var i = 0; i < n; i++) {
        for (var j = i + 1; j < n; j++) {
          var d = nodes[i].pos - nodes[j].pos;
          var dist = d.distance;
          if (dist < 0.01) {
            d = Offset((i % 3 - 1) * 0.5 + 0.1, (j % 3 - 1) * 0.5 + 0.1);
            dist = d.distance;
          }
          if (dist < 260) {
            final f = d / dist * (5200 / (dist * dist + 40));
            force[i] += f;
            force[j] -= f;
          }
        }
      }
      for (final e in edges) {
        final d = nodes[e.b].pos - nodes[e.a].pos;
        final dist = d.distance;
        if (dist < 0.01) continue;
        final ideal = 90.0 - e.weight * 6;
        final f = d / dist * ((dist - ideal) * 0.04 * math.min(e.weight, 4) / 2);
        force[e.a] += f;
        force[e.b] -= f;
      }
      for (var i = 0; i < n; i++) {
        force[i] += (center - nodes[i].pos) * 0.004; // gentle gravity
        vel[i] = (vel[i] + force[i]) * 0.6;
        nodes[i].pos += vel[i] * cool;
      }
    }
  }
  return Constellation(nodes, edges, size);
}
