import 'dart:math';
import 'dart:ui';

import 'package:beacon_app/calculation/a_star_algorithm.dart';
import 'package:beacon_app/calculation/find_direction_to_go.dart';
import 'package:beacon_app/calculation/grid_processing.dart';
import 'package:beacon_app/calculation/trilateration.dart';
import 'package:beacon_app/data_folder/beacon_data.dart';
import 'package:beacon_app/data_folder/ble_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:get/get.dart';

/*

  실내 지도 페이지
    BLE 비콘을 사용하여 사용자의 위치를 실시간으로 추적하고, A* 알고리즘을 통해 최적 경로를 계산하여 화면에 표시합니다.

    1. BLE 비콘을 통한 위치 추적:
      비콘 신호 강도(RSSI)를 측정하여 Trilateration 알고리즘을 사용해 사용자의 위치를 계산합니다.
      
    2. 최적 경로 계산:
      A* 알고리즘을 사용하여 사용자의 현재 위치와 목적지 사이의 최적 경로를 계산합니다.

    3. UI 업데이트:
      실내 지도 이미지를 표시하고, 비콘 위치, 사용자 위치, 최적 경로를 화면에 그립니다.

*/

class IndoorMapPage extends StatefulWidget {
  const IndoorMapPage({super.key});

  @override
  State<IndoorMapPage> createState() => IndoorMapPageState();
}

class IndoorMapPageState extends State<IndoorMapPage> {
  final bleController = Get.put(BleController());
  final beaconController = Get.put(BeaconController());

  int maxDevice = 3; // 최대 사용할 장치 수

  Worker? rssiListListener; // rssiList 리스너

  List<Coordinate> coordinateList = []; // 삼변측량 연산에 사용할 장치 리스트
  List<int> userPosition = [0, 0]; // 사용자의 위치
  List<Point<int>> optimalPath = []; // 최적 경로
  List<double> deviceCoordinate = [];

  double angle = 0.0;
  double angleToGo = 0.0;
  String directionToGo = '';

  @override
  void initState() {
    super.initState();

    // 일정 주기마다 RSSI 리스트를 확인하고, 좌표 및 최적 경로를 업데이트
    rssiListListener = interval(
        time: const Duration(milliseconds: 300), bleController.rssiList, (_) {
      if (bleController.rssiList.length >= 3) {
        updateCoordinateList();
        updateUserPositionList();
        //print('coor: $coordinateList');
        //print('user: $userPosition');
        updateOptimalPath(userPosition);
        //print(optimalPath);
        updateAngle();
        if (optimalPath.isNotEmpty) {
          updataDirectionToGo(optimalPath, userPosition, angle);
        }
        //print(directionToGo);

        if (mounted) {
          setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    // 페이지 종료 시 리스너 및 subscription 해제
    rssiListListener?.dispose();
    super.dispose();
  }

  // 삼변측량 연산에 사용할 장치 리스트를 업데이트하는 메서드
  void updateCoordinateList() {
    coordinateList.clear();

    // RSSI 리스트를 순회하며 좌표를 업데이트
    for (var i = 0; i < bleController.rssiList.length && i < maxDevice; i++) {
      var index = beaconController
          .findMACIndex(bleController.rssiList[i]['macAddress']);

      // 장치의 MAC주소에 해당하는 좌표를 찾고 리스트에 추가
      if (index != -1 && index < beaconController.beaconDataList.length) {
        coordinateList.add(Coordinate(
          centerX: beaconController.beaconDataList[index][3].toDouble(),
          centerY: beaconController.beaconDataList[index][4].toDouble(),
          //radius: findDistance(bleController.rssiList[i]['rssi']).toInt(),
          radius: bleController.rssiList[i]['rssi'].toDouble(),
        ));
      }
    }
  }

  // 사용자 위치를 업데이트하는 메서드
  void updateUserPositionList() {
    Trilateration trilateration = Trilateration();
    ImageGridProcessor imageGridMarker = ImageGridProcessor();

    // 3개 이상의 비콘 좌표가 있어야 Trilateration 가능

    List<int> position = trilateration.trilaterationMethod(coordinateList);

    // 계산된 위치가 도면 이미지의 범위를 넘지 않도록 조정
    if (position[0] > imageGridMarker.imageWidth) {
      position[0] = imageGridMarker.imageWidth - 1;
    }
    if (position[0] < 0) {
      position[0] = 0;
    }
    if (position[1] > imageGridMarker.imageHeight) {
      position[1] = imageGridMarker.imageHeight - 1;
    }
    if (position[1] < 0) {
      position[1] = 0;
    }

    userPosition = position;

    // if (mounted) {
    //   setState(() {});
    // }
  }

  // 최적 경로를 업데이트하는 메서드
  void updateOptimalPath(List<int> userPosition) {
    AStarAlgorithm astarAgorithm = AStarAlgorithm();

    // 사용자 위치가 유효한 경우에만 최적 경로 계산
    if (userPosition[0] != 0 && userPosition[1] != 0) {
      List<Point<int>> temp = astarAgorithm.findOptimalRoute(
          userPosition, 'assets/images/6th_floor.png');
      optimalPath = temp;
    }

    if (mounted) {
      setState(() {});
    }
  }

  // RSSI 값을 거리로 변환하는 메서드
  double calculateDistanceFromRssi(int rssi) {
    const int alpha = -60;
    const int constantN = 2;
    double distance = pow(10.0, (alpha - rssi) / (10 * constantN)).toDouble();
    return distance;
  }

  void updateAngle() {
    FlutterCompass.events?.listen((CompassEvent event) {
      if (event.heading != null) {
        angle = event.heading!;
        //angle = -angle;
        //print(angle);
      }
    });
  }

  void updataDirectionToGo(
      List<Point<int>> path, List<int> userPosition, double angle) {
    FindDirectionToGo findDirectionToGo = FindDirectionToGo();

    double psi =
        findDirectionToGo.findDirectionToGo(userPosition, path[0], angle);

    if (userPosition[0] < path[0].x) {
      // CW
      if (psi >= 0 && psi < 15) directionToGo = '12시 방향';
      if (psi >= 15 && psi < 45) directionToGo = '1시 방향';
      if (psi >= 45 && psi < 75) directionToGo = '2시 방향';
      if (psi >= 75 && psi < 105) directionToGo = '3시 방향';
      if (psi >= 105 && psi < 135) directionToGo = '4시 방향';
      if (psi >= 135 && psi < 165) directionToGo = '5시 방향';
      if (psi >= 165 && psi < 180) directionToGo = '6시 방향';
    } else if (userPosition[0] > path[0].x) {
      // CCW
      if (psi >= 0 && psi < 15) directionToGo = '12시 방향';
      if (psi >= 15 && psi < 45) directionToGo = '11시 방향';
      if (psi >= 45 && psi < 75) directionToGo = '10시 방향';
      if (psi >= 75 && psi < 105) directionToGo = '9시 방향';
      if (psi >= 105 && psi < 135) directionToGo = '8시 방향';
      if (psi >= 135 && psi < 165) directionToGo = '7시 방향';
      if (psi >= 165 && psi < 180) directionToGo = '6시 방향';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Stack(
              children: [
                Image.asset(
                  'assets/images/6th_floor.png',
                  fit: BoxFit.cover,
                  //height: MediaQuery.of(context).size.height,
                ),

                // 각 비콘의 위치와 RSSI를 화면에 표시
                for (var i = 0;
                    i < bleController.rssiList.length && i < maxDevice;
                    i++)
                  CustomPaint(
                    painter: BeaconCircle(
                      x: beaconController.beaconDataList[
                          beaconController.findMACIndex(
                              bleController.rssiList[i]['macAddress'])][3],
                      y: beaconController.beaconDataList[
                          beaconController.findMACIndex(
                              bleController.rssiList[i]['macAddress'])][4],
                      // rssi: calculateDistanceFromRssi(bleController.rssiList[i]['rssi'])
                      //     .toDouble(),
                      rssi: bleController.rssiList[i]['rssi'].toDouble(),
                      nickname: beaconController.beaconDataList[
                          beaconController.findMACIndex(
                              bleController.rssiList[i]['macAddress'])][6],
                    ),
                  ),
                // 사용자 위치를 화면에 표시
                if (coordinateList.length >= 3)
                  CustomPaint(
                    painter: UserPosition(
                      x: userPosition[0].toDouble(),
                      y: userPosition[1].toDouble(),
                      pii: angle,
                      psi: angleToGo,
                      deviceX: deviceCoordinate[0],
                      deviceY: deviceCoordinate[1],
                    ),
                  ),
                // 최적 경로를 화면에 표시
                CustomPaint(
                  painter: OptimalRoute(
                    path: optimalPath,
                    userPosition: userPosition,
                    endPoint: [550, 255],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BeaconCircle extends CustomPainter {
  final int? x;
  final int? y;
  final double? rssi;
  final String? nickname;
  var coeffi = 1.3; //  // 반지름 확대 계수 (Default: 38)

  BeaconCircle({
    required this.x,
    required this.y,
    required this.rssi,
    this.nickname,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 비콘의 좌표 또는 RSSI 값이 없는 경우 그리지 않음
    if (x == null || y == null || rssi == null) return;

    const double maxDistance = 9999999.0;
    final double distance = rssi!.abs().toDouble();

    // 반지름 값을 설정 (최대 거리를 넘지 않도록 제한)
    final double radius = (distance > maxDistance ? maxDistance : distance);
    final Offset center = Offset(x!.toDouble(), y!.toDouble());

    // 비콘 위치를 나타내는 점의 스타일
    final pointPaint = Paint()
      ..color = Colors.blue.withOpacity(0.8)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5;

    // 비콘 신호의 범위를 나타내는 원의 스타일
    final circlePaint = Paint()
      ..color = Colors.blue.withOpacity(0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // 원 그리기
    canvas.drawCircle(center, radius * coeffi, circlePaint);
    // 비콘 좌표에 점 그리기
    canvas.drawPoints(PointMode.points, [center], pointPaint);

    // 비콘 닉네임을 텍스트로 표시
    const textStyle = TextStyle(
      color: Colors.blue,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    final textSpan = TextSpan(
      text: nickname,
      style: textStyle,
    );
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(canvas, Offset(x!.toDouble(), y!.toDouble()));
    //print(distance);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

// 사용자의 위치를 표현하는 클래스
class UserPosition extends CustomPainter {
  final double? x;
  final double? y;
  final double? pii;
  final double? psi;
  final double? deviceX;
  final double? deviceY;

  UserPosition({
    required this.x,
    required this.y,
    required this.pii,
    this.psi,
    this.deviceX,
    this.deviceY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 사용자 위치를 나타내는 좌표 설정
    final Offset center = Offset(x!, y!);

    // 가상 원 스타일
    final virCircle = Paint()
      ..color = Colors.pink
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // 가상 원 표시
    canvas.drawCircle(Offset(x!, y!), 40, virCircle);

    // 사용자 디바이스 방향 포인트 스타일
    final deviceDir = Paint()
      ..color = Colors.red
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5;

    // 사용자 디바이스 방향 포인트 표시
    canvas.drawPoints(
        PointMode.points, [Offset(deviceX!, deviceY!)], deviceDir);

    // 북쪽 방향 포인트 스타일
    final northDir = Paint()
      ..color = Colors.lightBlue
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5;

    // 북쪽 방향 표시
    canvas.drawPoints(
        PointMode.points, [Offset(x! + 39.0, y! + 10.0)], northDir);

    // 사용자 위치 좌표를 텍스트로 표시
    final formattedX = x!.toDouble().toStringAsFixed(0);
    final formattedY = y!.toDouble().toStringAsFixed(0);

    const textStyle = TextStyle(
      color: Colors.red,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    final textSpan = TextSpan(
      text: '($formattedX, $formattedY)',
      style: textStyle,
    );
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(canvas, Offset(x!.toDouble() - 33, y!.toDouble() + 10));

    // 사용자의 위치와 방향을 나타내는 아이콘 표시
    // canvas.save();
    // canvas.translate(center.dx, center.dy);

    // 현재 위치 아이콘 표시 (빨간색)
    // canvas.save();
    // canvas.rotate((pii! - 90) * (pi / 180));
    // _drawIcon(canvas, Icons.trending_flat, 30, Colors.red);
    // canvas.restore();

    //이동할 각도에 해당하는 아이콘 표시 (파란색)
    // canvas.save();
    // _drawIcon(canvas, Icons.trending_flat, 30, Colors.blue);
    // canvas.restore();
  }

  // void _drawIcon(Canvas canvas, IconData icon, double iconSize, Color color) {
  //   final textPainterIcon = TextPainter(
  //     text: TextSpan(
  //       text: String.fromCharCode(icon.codePoint),
  //       style: TextStyle(
  //         fontSize: iconSize,
  //         fontFamily: icon.fontFamily,
  //         color: color, // 아이콘 색상 설정
  //       ),
  //     ),
  //     textAlign: TextAlign.center,
  //     textDirection: TextDirection.ltr,
  //   );

  //   textPainterIcon.layout();
  //   textPainterIcon.paint(canvas, Offset(-iconSize / 2, -iconSize / 2));
  // }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

class OptimalRoute extends CustomPainter {
  final List<Point<int>> path;
  final List<int> userPosition;
  final List<int> endPoint;

  ImageGridProcessor imageGridMarker = ImageGridProcessor();

  OptimalRoute({
    required this.path,
    required this.userPosition,
    required this.endPoint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 경로를 나타내는 선의 스타일
    final route = Paint()
      ..color = Colors.green
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final point = Paint()
      ..color = Colors.purple
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10;

    final nodePoint = Paint()
      ..color = Colors.yellow
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    //print(path);

    // 사용자 위치에서 경로의 첫 지점까지 선을 그림
    canvas.drawLine(
        Offset(userPosition[0].toDouble(), userPosition[1].toDouble()),
        Offset(imageGridMarker.gridToPixel(path[0]).x.toDouble(),
            imageGridMarker.gridToPixel(path[0]).y.toDouble()),
        route);

    // 경로의 각 지점을 순회하며 선을 그리고, 각 지점에 점을 찍음
    for (var i = 0; i < path.length - 1; i++) {
      final p1 = imageGridMarker.gridToPixel(path[i]);
      final p2 = imageGridMarker.gridToPixel(path[i + 1]);

      if (i != path.length - 2) {
        // 경로의 각 구간을 그림
        canvas.drawLine(Offset(p1.x.toDouble(), p1.y.toDouble()),
            Offset(p2.x.toDouble(), p2.y.toDouble()), route);
        canvas.drawPoints(PointMode.points,
            [Offset(p1.x.toDouble(), p1.y.toDouble())], nodePoint);
      } else if (i == path.length - 2) {
        // 마지막 경로 지점에서 최종 목적지까지 선을 그림
        canvas.drawLine(Offset(p1.x.toDouble(), p1.y.toDouble()),
            Offset(endPoint[0].toDouble(), endPoint[1].toDouble()), route);
        canvas.drawPoints(PointMode.points,
            [Offset(endPoint[0].toDouble(), endPoint[1].toDouble())], point);
        canvas.drawPoints(PointMode.points,
            [Offset(p1.x.toDouble(), p1.y.toDouble())], nodePoint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class EndPoint extends CustomPainter {
  int x;
  int y;

  EndPoint({required this.x, required this.y});

  @override
  void paint(Canvas canvas, Size size) {
    final endPoint = Paint()
      ..color = Colors.purple
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPoints(
        PointMode.points, [Offset(x.toDouble(), y.toDouble())], endPoint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
