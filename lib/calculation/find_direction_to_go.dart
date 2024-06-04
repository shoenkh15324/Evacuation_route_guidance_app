import 'dart:math';

import 'package:beacon_app/calculation/grid_processing.dart';

class FindDirectionToGo {
  FindDirectionToGo();

  List<double> findDeviceDirection(List<int> userPotision, double pii) {
    List<double> vectorN = [39.0, 10.0]; // 약 15도.

    double x =
        vectorN[0] * cos(pii * (pi / 180)) - vectorN[1] * sin(pii * (pi / 180));
    double y =
        vectorN[0] * sin(pii * (pi / 180)) + vectorN[1] * cos(pii * (pi / 180));

    List<double> device = [x + userPotision[0], y + userPotision[1]];

    return device;
  }

  double findPsi(List<double> device, Point<int> nextNode) {
    double psi = 0.0;

    double numerator = device[0] * nextNode.x + device[1] * nextNode.y;
    double dominator = sqrt(pow(device[0], 2) + pow(device[1], 2)) *
        sqrt(pow(nextNode.x, 2) + pow(nextNode.y, 2));

    psi = acos(numerator / dominator) * (180 / pi);

    return psi;
  }

  double findDirectionToGo(
      List<int> userPosition, Point<int> nextNode, double pii) {
    List<double> device = findDeviceDirection(userPosition, pii);
    double psi = findPsi(device, nextNode);
    return psi;
  }
}
