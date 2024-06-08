import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:beacon_app/calculation/a_star_algorithm.dart';
import 'package:beacon_app/calculation/find_direction_to_go.dart';
import 'package:beacon_app/calculation/grid_processing.dart';
import 'package:beacon_app/calculation/trilateration.dart';
import 'package:beacon_app/data_folder/ble_data.dart';
import 'package:beacon_app/data_folder/database_control.dart';
import 'package:beacon_app/tts/voice_guidance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:get/get.dart';

/*

  실내 지도 페이지
    BLE 비콘을 사용하여 사용자의 위치를 실시간으로 추적하고, A* 알고리즘을 통해 최적 경로를 계산하여 화면에 표시합니다.

    1. BLE 비콘을 통한 위치 추적:
      비콘 신호 강도(RSSI)를 측정하여 삼변측량을 사용해 사용자의 위치를 계산합니다.
      
    2. 최적 경로 계산:
      A* 알고리즘을 사용하여 사용자의 현재 위치와 목적지 사이의 최적 경로를 계산합니다.

    3. UI 업데이트:
      실내 지도 이미지를 표시하고, 비콘 위치, 사용자 위치, 최적 경로를 화면에 그립니다.

    4. 음성 안내:
      사용자가 가야 하는 방향을 음성으로 안내합니다.

*/

// TODO: 오류 및 버그 테스트

class IndoorMapPage extends StatefulWidget {
  const IndoorMapPage({super.key});

  @override
  State<IndoorMapPage> createState() => IndoorMapPageState();
}

class IndoorMapPageState extends State<IndoorMapPage> {
  final bleController = Get.put(BleController());

  late Timer _timer1; // 사용자 위치 및 경로 탐색 타이머
  late Timer _timer2; // 음성 안내 타이머
  int ms1 = 100; // 사용자 위치 및 경로 탐색 주기
  int ms2 = 3000; // 음성 안내 주기

  int maxDevice = 3; // 최대 사용할 장치 수

  Worker? rssiListListener; // rssiList 리스너 (GetX 라이브러리)

  List<Coordinate> coordinateList = []; // 삼변측량 연산에 사용할 장치 리스트
  List<int> userPosition = [0, 0]; // 사용자의 위치
  List<Point<int>> optimalPath = []; // 최적 경로
  List<double> deviceCoordinate = [0, 0]; // 사용자 디바이스 방향 좌표

  double angle = 0.0; // 사용자 디바이스 방향과 북쪽 방향의 사잇각.
  double angleToGo = 0.0; // 사용자 디바이스 방향과 다음 노드 방향의 사잇각.
  String directionToGo = ''; // 사용자가 가야 하는 방향.

  @override
  void initState() {
    super.initState();

    // 사용자 위치 및 경로 탐색 수행 부분
    _timer1 = Timer.periodic(Duration(milliseconds: ms1), (timer) {
      updateCoordinateList();
      if (coordinateList.length >= 3) {
        updateUserPositionList();
        updateOptimalPath(userPosition);
        updateAngle();
        if (optimalPath.isNotEmpty) {
          updataDirectionToGo(optimalPath, userPosition, angle);
        }
        if (mounted) {
          setState(() {});
        }
      }
    });

    // 음성 안내 기능 실행 부분
    _timer2 = Timer.periodic(Duration(milliseconds: ms2), (timer) {
      if (directionToGo.isNotEmpty && bleController.isScanning.value == true) {
        callTTS(directionToGo);
      }
    });
  }

  @override
  void dispose() {
    // 페이지 종료 시 리스너 및 subscription 해제
    rssiListListener?.dispose();
    _timer1.cancel();
    _timer2.cancel();
    super.dispose();
  }

  // 삼변측량 연산에 사용할 장치 리스트를 업데이트하는 메서드
  Future<void> updateCoordinateList() async {
    DatabaseHelper dbHelper = DatabaseHelper.instance;

    List topList = [];

    // beaconDataList에서 rssi가 강한 장치의 mac주소를 maxDevice만큼 찾음.
    for (var i = 0; i < bleController.rssiList.length; i++) {
      if (topList.length < maxDevice) {
        if (bleController.rssiList[i]['rssi'] != 0) {
          topList.add(bleController.rssiList[i]);
        }
      }
    }

    List<Coordinate> tempList = [];

    for (var i = 0; i < topList.length; i++) {
      String mac = topList[i]['mac'];

      BeaconData? beacon = await dbHelper.getBeaconData(mac);

      // 만약 X나 Y 좌표가 0이면 연산에서 제외 (오류 방지)
      if (beacon != null) {
        if (beacon.x != 0 && beacon.y != 0) {
          tempList.add(Coordinate(
            centerX: beacon.x.toDouble(),
            centerY: beacon.y.toDouble(),
            radius: bleController.rssiList[i]['rssi'].toDouble(),
            nickname: beacon.nickname,
          ));
        }
      }
    }

    coordinateList = tempList;
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

  // angle 변수를 업데이트하는 메서드
  void updateAngle() {
    FlutterCompass.events?.listen((CompassEvent event) {
      if (event.heading != null) {
        angle = event.heading!;
      }
    });
  }

  // directionToGo 변수를 업데이트하는 메서드
  void updataDirectionToGo(
      List<Point<int>> path, List<int> userPosition, double angle) {
    ImageGridProcessor imageGridProcessor = ImageGridProcessor();
    FindDirectionToGo findDirectionToGo = FindDirectionToGo();

    List<double> device =
        findDirectionToGo.findDeviceDirection(userPosition, angle);
    double psi = findDirectionToGo.findPsi(device, path[0], userPosition);

    // 사용자 방향 좌표가 이미지의 크기를 넘어갈 때 조정하는 부분.
    if (device[0] > imageGridProcessor.imageWidth) {
      device[0] = imageGridProcessor.imageWidth.toDouble();
    }
    if (device[0] < 0) {
      device[0] = 0.0;
    }
    if (device[1] > imageGridProcessor.imageWidth) {
      device[1] = imageGridProcessor.imageHeight.toDouble();
    }
    if (device[1] < 0) {
      device[1] = 0.0;
    }

    deviceCoordinate = device;

    Point<int> nextNode = imageGridProcessor.gridToPixel(path[0]);

    // 회전 방향 판단을 위해 외적 계산
    double crossProduct =
        (userPosition[0] - device[0]) * (userPosition[1] - nextNode.y) -
            (userPosition[1] - device[1]) * (userPosition[0] - nextNode.x);

    if (crossProduct > 0) {
      // CW
      if (psi >= 0 && psi < 15) directionToGo = '12시 방향';
      if (psi >= 15 && psi < 45) directionToGo = '1시 방향';
      if (psi >= 45 && psi < 75) directionToGo = '2시 방향';
      if (psi >= 75 && psi < 105) directionToGo = '3시 방향';
      if (psi >= 105 && psi < 135) directionToGo = '4시 방향';
      if (psi >= 135 && psi < 165) directionToGo = '5시 방향';
      if (psi >= 165 && psi < 180) directionToGo = '6시 방향';
    } else if (crossProduct < 0) {
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

  // 음성 안내 메서드
  void callTTS(String text) {
    VoiceGuidance voiceGuidance = VoiceGuidance();

    if (text.isNotEmpty) {
      voiceGuidance.speak(text);
    }
  }

  // UI
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
                ),
                // 각 비콘의 위치와 RSSI를 화면에 표시
                for (var i = 0; i < coordinateList.length; i++)
                  CustomPaint(
                    painter: BeaconCircle(
                      x: coordinateList[i].centerX.toInt(),
                      y: coordinateList[i].centerY.toInt(),
                      // rssi: calculateDistanceFromRssi(bleController.rssiList[i]['rssi'])
                      //     .toDouble(),
                      rssi: bleController.rssiList[i]['rssi'].toDouble(),
                      nickname: coordinateList[i].nickname,
                    ),
                  ),
                // 사용자 위치를 화면에 표시
                if (coordinateList.length >= 3 && optimalPath.isNotEmpty)
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

// 비콘의 반경을 표시하는 클래스.
class BeaconCircle extends CustomPainter {
  final int? x;
  final int? y;
  final double? rssi;
  final String? nickname;
  var coeffi = 1.3; // 반지름 확대 계수 (Default: 38)

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
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius * coeffi, circlePaint); // 원 그리기
    canvas.drawPoints(PointMode.points, [center], pointPaint); // 비콘 좌표에 점 그리기

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
    textPainter.paint(canvas, Offset(x!.toDouble() + 3, y!.toDouble() + 3));
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

    // 사용자 위치 포인트 스타일
    final user = Paint()
      ..color = Colors.red
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10;

    // 사용자 위치 그리기
    canvas.drawPoints(PointMode.points, [center], user);

    // 방향 궤도 스타일
    final virCircle = Paint()
      ..color = Colors.black54
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    // 방향 궤도 표시
    canvas.drawCircle(center, 35, virCircle);

    // 사용자 디바이스 방향 포인트 스타일
    final deviceDir = Paint()
      ..color = Colors.red
      ..strokeCap = StrokeCap.square
      ..strokeWidth = 4.5;

    // 사용자 디바이스 방향 포인트 표시
    canvas.drawPoints(
        PointMode.points, [Offset(deviceX!, deviceY!)], deviceDir);

    // 북쪽 방향 포인트 스타일
    final northDir = Paint()
      ..color = Colors.tealAccent
      ..strokeCap = StrokeCap.square
      ..strokeWidth = 4.5;

    // 북쪽 방향 표시
    canvas.drawPoints(
        PointMode.points, [Offset(x! + 34.0, y! - 9.0)], northDir);

    // 사용자 위치 좌표를 텍스트로 표시
    final formattedX = x!.toDouble().toStringAsFixed(0);
    final formattedY = y!.toDouble().toStringAsFixed(0);

    const textStyle = TextStyle(
      color: Colors.red,
      fontSize: 12,
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
    textPainter.paint(canvas, Offset(x!.toDouble() - 28, y!.toDouble() + 10));
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

//최적 경로를 표시하는 클래스
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

    // 도착지 포인트 스타일
    final point = Paint()
      ..color = Colors.purple
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10;

    // 최적 경로의 노드 포인트 스타일
    final nodePoint = Paint()
      ..color = Colors.yellow
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

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
