import 'dart:math';
import 'dart:ui';

import 'package:beacon_app/calculation/a_star_algorithm.dart';
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
  double angle = 0.0;

  double tempHeight = 0;
  double tempWidth = 0;

  @override
  void initState() {
    super.initState();

    // 일정 주기마다 RSSI 리스트를 확인하고, 좌표 및 최적 경로를 업데이트
    rssiListListener = interval(
        time: const Duration(milliseconds: 300), bleController.rssiList, (_) {
      updateCoordinateList();
      updateUserPositionList();
      //print('coor: $coordinateList');
      //print('user: $userPosition');
      updateOptimalPath(userPosition);
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    // 페이지 종료 시 리스너 및 subscription 해제
    rssiListListener?.dispose();
    super.dispose();
  }

  // void temp() {
  //   tempHeight = MediaQuery.of(context).size.height;
  //   tempWidth = MediaQuery.of(context).size.width;
  //   print('h: $tempHeight, w: $tempWidth');
  // }

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
    if (coordinateList.length >= 3) {
      List<int> position = trilateration.trilaterationMethod(coordinateList);

      // 계산된 위치가 도면 이미지의 범위를 넘지 않도록 조정
      if (position[0] > imageGridMarker.imageWidth) {
        position[0] = imageGridMarker.imageWidth - 1;
      }
      if (position[1] > imageGridMarker.imageHeight) {
        position[1] = imageGridMarker.imageHeight - 1;
      }

      userPosition = position;

      if (mounted) {
        setState(() {});
      }
    }
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

  // 나침반 위젯
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
                // 도착점을 화면에 표시
                CustomPaint(
                  painter: EndPoint(x: 550, y: 255),
                )
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: compass(),
          )
        ],
      ),
    );
  }
}

Widget compass() {
  return StreamBuilder<CompassEvent>(
    stream: FlutterCompass.events,
    builder: (context, snapshot) {
      // 에러 메시지 출력
      if (snapshot.hasError) {
        return Text('Error reading heading: ${snapshot.error}');
      }

      // 로딩 아이콘 출력
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      }

      double? direction = snapshot.data!.heading;

      // 나침반 반환
      return Transform.rotate(
        angle: direction! * (pi / 180),
        child: const Icon(
          Icons.arrow_upward,
          size: 60,
        ),
      );
    },
  );
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

class UserPosition extends CustomPainter {
  final double? x;
  final double? y;

  UserPosition({required this.x, required this.y});

  @override
  void paint(Canvas canvas, Size size) {
    // 사용자 위치를 나타내는 좌표 설정
    final Offset center = Offset(x!, y!);

    // 사용자 위치를 나타내는 점의 스타일
    final pointPaint = Paint()
      ..color = Colors.red.withOpacity(0.8)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8;

    // 사용자 위치에 점을 그리기
    canvas.drawPoints(PointMode.points, [center], pointPaint);

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
    textPainter.paint(canvas, Offset(x!.toDouble() - 33, y!.toDouble() + 7));
  }

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

    // 경로의 각 지점을 나타내는 점의 스타일
    final routeNode = Paint()
      ..color = Colors.amber
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    //print(path);

    // 사용자 위치에서 경로의 첫 지점까지 선을 그림
    canvas.drawLine(
        Offset(userPosition[0].toDouble(), userPosition[1].toDouble()),
        Offset(imageGridMarker.gridToPixel(path[0]).x.toDouble(),
            imageGridMarker.gridToPixel(path[0]).y.toDouble()),
        route);
    // 사용자 위치에 점을 찍음
    canvas.drawPoints(
        PointMode.points,
        [Offset(userPosition[0].toDouble(), userPosition[1].toDouble())],
        routeNode);

    // 경로의 각 지점을 순회하며 선을 그리고, 각 지점에 점을 찍음
    for (var i = 0; i < path.length - 1; i++) {
      final p1 = imageGridMarker.gridToPixel(path[i]);
      final p2 = imageGridMarker.gridToPixel(path[i + 1]);

      if (i != path.length - 2) {
        // 경로의 각 구간을 그림
        canvas.drawLine(Offset(p1.x.toDouble(), p1.y.toDouble()),
            Offset(p2.x.toDouble(), p2.y.toDouble()), route);
        canvas.drawPoints(PointMode.points,
            [Offset(p2.x.toDouble(), p2.y.toDouble())], routeNode);
      } else if (i == path.length - 2) {
        // 마지막 경로 지점에서 최종 목적지까지 선을 그림
        canvas.drawLine(Offset(p1.x.toDouble(), p1.y.toDouble()),
            Offset(endPoint[0].toDouble(), endPoint[1].toDouble()), route);
        canvas.drawPoints(
            PointMode.points,
            [Offset(endPoint[0].toDouble(), endPoint[1].toDouble())],
            routeNode);
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
      ..color = Colors.yellow
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke;

    canvas.drawPoints(
        PointMode.points, [Offset(x.toDouble(), y.toDouble())], endPoint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
