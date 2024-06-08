import "dart:math";
import "package:beacon_app/data_folder/ble_data.dart";
import "package:get/get.dart";
import "package:matrix2d/matrix2d.dart";

class Coordinate {
  double centerX;
  double centerY;
  double radius;
  String nickname;

  Coordinate({
    required this.centerX,
    required this.centerY,
    required this.radius,
    required this.nickname,
  });
}

class Trilateration {
  Trilateration();

  final bleController = Get.put(BleController());

  // 삼변측량 기법을 사용하여 위치를 계산하는 메서드
  List<int> trilaterationMethod(List<Coordinate> coordinateList) {
    const double maxDistance = 1000000000.0; // 최대 거리 상수
    var matrixA = [];
    var matrixB = [];
    const Matrix2d m2d = Matrix2d(); // 2D 행렬 객체

    // 좌표 리스트를 순회하며 행렬 A와 B를 생성
    for (int idx = 1; idx <= coordinateList.length - 1; idx++) {
      matrixA.add([
        coordinateList[idx].centerX - coordinateList[0].centerX,
        coordinateList[idx].centerY - coordinateList[0].centerY
      ]);
      matrixB.add([
        ((pow(coordinateList[idx].centerX, 2) +
                    pow(coordinateList[idx].centerY, 2) -
                    pow(
                        coordinateList[idx].radius > maxDistance
                            ? maxDistance
                            : coordinateList[idx].radius,
                        2)) -
                (pow(coordinateList[0].centerX, 2) +
                    pow(coordinateList[0].centerY, 2) -
                    pow(
                        coordinateList[0].radius > maxDistance
                            ? maxDistance
                            : coordinateList[0].radius,
                        2))) /
            2
      ]);
    }

    // 행렬 계산
    var matrixATranspose = transposeMatrix(matrixA); // 행렬 A의 전치
    var matrixInverse =
        invertNxNMatrix(m2d.dot(matrixATranspose, matrixA)); // 역행렬 계산
    var matrixDot = m2d.dot(matrixInverse, matrixATranspose); // 행렬 곱셈
    var tempPosition = m2d.dot(matrixDot, matrixB); // 최종 위치 계산

    // 계산된 위치를 정수 리스트로 반환
    List<int> position = [];

    if (tempPosition[0][0].isFinite) {
      position.add(tempPosition[0][0].toInt());
    } else {
      position.add(0);
    }

    if (tempPosition[1][0].isFinite) {
      position.add(tempPosition[1][0].toInt());
    } else {
      position.add(0);
    }

    return position;
  }

  // 행렬을 전치하는 메서드
  List transposeMatrix(List list) {
    var shape = list.shape;
    var temp = List.filled(shape[1], 0.0)
        .map((e) => List.filled(shape[0], 0.0))
        .toList();
    for (var i = 0; i < shape[1]; i++) {
      for (var j = 0; j < shape[0]; j++) {
        temp[i][j] = list[j][i];
      }
    }
    return temp;
  }

  // NxN 행렬의 역행렬을 계산하는 메서드
  List invertNxNMatrix(List list) {
    var shape = list.shape;
    var temp = List.filled(shape[1], 0.0)
        .map((e) => List.filled(shape[0], 0.0))
        .toList();
    var determinant = list[0][0] * list[1][1] - list[1][0] * list[0][1];
    temp[0][0] = list[1][1] / determinant;
    temp[0][1] = -list[0][1] / determinant;
    temp[1][0] = -list[1][0] / determinant;
    temp[1][1] = list[0][0] / determinant;

    return temp;
  }
}
