import 'dart:math';

import 'package:beacon_app/calculation/grid_processing.dart';
import 'package:a_star_algorithm/a_star_algorithm.dart';

class AStarAlgorithm {
  // 주어진 데이터를 Point 객체로 변환하는 메서드
  Point<int> listToPoint(List<dynamic> data) {
    if (data.length == 2) {
      return Point(data[0], data[1]);
    } else {
      throw ArgumentError('Invalid input format');
    }
  }

  // A* 알고리즘을 사용하여 최적 경로를 찾는 메서드
  List<Point<int>> computeAStarPath(List<int> userPositon) {
    ImageGridProcessor imageGridMarker = ImageGridProcessor();

    Iterable<Point<int>> optimalRoute = AStar(
      rows: imageGridMarker.imageHeight ~/ imageGridMarker.gridHeight,
      columns: imageGridMarker.imageWidth ~/ imageGridMarker.gridWidth,
      start: imageGridMarker.pixelToGrid(listToPoint(userPositon)),
      //start: imageGridMarker.pixelToGrid(const Point(380, 460)),
      end: imageGridMarker.pixelToGrid(const Point(550, 255)),
      barriers: imageGridMarker.barriers,
    ).findThePath();

    return optimalRoute.toList();
  }

  // 최적 경로를 찾는 메서드
  List<Point<int>> findOptimalRoute(List<int> userPosition, String assetPath) {
    ImageGridProcessor imageGridMarker = ImageGridProcessor();
    imageGridMarker.gridProcessing(assetPath);
    var path = computeAStarPath(userPosition);

    if (imageGridMarker.pixelToGrid(Point(userPosition[0], userPosition[1])) ==
        path[0]) {
      path.removeAt(0);
    }

    return path;
  }
}
