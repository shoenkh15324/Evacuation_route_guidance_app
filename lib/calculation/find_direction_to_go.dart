import 'dart:math';

import 'package:beacon_app/calculation/grid_processing.dart';

class FindDirectionToGo {
  FindDirectionToGo();

  /* Flutter_compass 라이브러리를 활용하여 북쪽 방향과 사용자의 방향의 사잇각으로 
     사용자의 방향 벡터를 구하는 메서드 */
  List<double> findDeviceDirection(List<int> userPosition, double pii) {
    List<double> vectorN = [34.0, -9.0]; // 약 15도.

    // 회전 변환 행렬 적용.
    double x =
        vectorN[0] * cos(pii * (pi / 180)) - vectorN[1] * sin(pii * (pi / 180));
    double y =
        vectorN[0] * sin(pii * (pi / 180)) + vectorN[1] * cos(pii * (pi / 180));

    List<double> device = [x + userPosition[0], y + userPosition[1]];

    return device;
  }

  /* 사용자의 방향을 기준으로 사용자의 방향 벡터와 다음 노드 벡터 사이의 사잇각을
     구하는 메서드 */
  double findPsi(
      List<double> device, Point<int> nextNode, List<int> userPosition) {
    ImageGridProcessor imageGridProcessor = ImageGridProcessor();

    double psi = 0.0;
    Point<int> nextNodePixel = imageGridProcessor.gridToPixel(nextNode);

    // 분자
    double numerator =
        (userPosition[0] - device[0]) * (userPosition[0] - nextNodePixel.x) +
            (userPosition[1] - device[1]) * (userPosition[1] - nextNodePixel.y);
    // 분모
    double denominator = sqrt(pow(userPosition[0] - device[0], 2) +
            pow(userPosition[1] - device[1], 2)) *
        sqrt(pow(userPosition[0] - nextNodePixel.x, 2) +
            pow(userPosition[1] - nextNodePixel.y, 2));

    if (denominator == 0) {
      throw Exception('Denominator is zero, cannot divide by zero');
    }

    psi = acos(numerator / denominator) * (180 / pi); // 두 벡터의 내적

    return psi;
  }
}
