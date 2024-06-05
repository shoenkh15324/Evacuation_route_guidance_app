import 'dart:math';

import 'package:beacon_app/calculation/grid_processing.dart';

class FindDirectionToGo {
  FindDirectionToGo();

  List<double> findDeviceDirection(List<int> userPosition, double pii) {
    List<double> vectorN = [34.0, -9.0]; // 약 15도.

    double x =
        vectorN[0] * cos(pii * (pi / 180)) - vectorN[1] * sin(pii * (pi / 180));
    double y =
        vectorN[0] * sin(pii * (pi / 180)) + vectorN[1] * cos(pii * (pi / 180));

    List<double> device = [x + userPosition[0], y + userPosition[1]];

    return device;
  }

  double findPsi(
      List<double> device, Point<int> nextNode, List<int> userPosition) {
    ImageGridProcessor imageGridProcessor = ImageGridProcessor();

    double psi = 0.0;
    Point<int> nextNodePixel = imageGridProcessor.gridToPixel(nextNode);

    double numerator =
        (userPosition[0] - device[0]) * (userPosition[0] - nextNodePixel.x) +
            (userPosition[1] - device[1]) * (userPosition[1] - nextNodePixel.y);
    double denominator = sqrt(pow(userPosition[0] - device[0], 2) +
            pow(userPosition[1] - device[1], 2)) *
        sqrt(pow(userPosition[0] - nextNodePixel.x, 2) +
            pow(userPosition[1] - nextNodePixel.y, 2));

    if (denominator == 0) {
      throw Exception('Denominator is zero, cannot divide by zero');
    }

    psi = acos(numerator / denominator) * (180 / pi);

    return psi;
  }
}
