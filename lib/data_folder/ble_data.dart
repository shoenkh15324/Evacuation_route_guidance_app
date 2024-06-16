// ignore_for_file: file_names

import 'dart:async';

import 'package:beacon_app/data_folder/database_control.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';

/*
  BLE 기능 관련 코드
    BLE(Bluetooth Low Energy) 기기를 스캔하고 관리하는데 사용되는 여러 클래스와 기능을 포함.
    BLE 장치를 효율적으로 관리하고, 사용자 인터페이스를 통해 스캔된 장치 및 비콘을 관리할 수 있도록 한다.

    1. HomeScreen 클래스: 
      애플리케이션의 홈 화면을 정의합니다. 이 화면은 BLE 스캔을 시작하고 정지하고, 스캔된 장치 목록을       표시하고, 비콘을 추가하는 등의 작업을 수행할 수 있습니다.

    2. ScanPage 클래스: 
      BLE 장치를 스캔하고 그 결과를 표시하는 화면입니다. 각 장치에 대한 세부 정보를 보여주며, 설정 및 삭제 기능을 제공합니다.

    3. BleController 클래스: 
      BLE 스캔 및 관련 데이터 처리를 담당하는 GetX 컨트롤러입니다. 장치 스캔을 시작하고 중지하며, 스캔된 장치의 RSSI 값과 플랫폼 이름을 업데이트합니다.

    4. BeaconController 클래스: 
      비콘 데이터를 관리하는 GetX 컨트롤러입니다. 비콘을 추가하고 편집하며, 데이터베이스에서 비콘 정보를 읽고 쓰는 작업을 수행합니다.

    5. DatabaseHelper 클래스: 
      SQLite 데이터베이스를 사용하여 비콘 데이터를 영구 저장하는데 사용됩니다.
*/

/* 
    *** 주의! ***
      BleController 클래스에 'final beaconController = Get.put(BeaconData())'를 선언하면 안됨
        -> GetX 컨트롤러가 변경사항을 재귀함수 꼴로 무한 호출해서 스택 오버플로우가 발생!
        -> 함수에 local하게 선언하는 것은 가능.
 */

// GetX 라이브러리를 통해 BLE 기능을 관리하는 클래스
class BleController extends GetxController {
  // 스캔 상태 플래그
  final isScanning = RxBool(false);

  // 모든 BLE 기기 스캔 결과 리스트
  RxList<ScanResult> scanResultList = RxList<ScanResult>([]);

  // 등록된 비콘의 여러 정보들을 담고있는 리스트
  RxList<Map<String, dynamic>> beaconList = RxList<Map<String, dynamic>>([]);

  // 각 기기의 이전 RSSI 값을 저장하는 Map
  Map<String, List<int>> previousRssiValues = {};

  // 이동 평균 필터의 윈도우 크기
  final int windowSize = 5;

  // 스파이크를 감지하는 임계값
  int spikeThreshold = 10;

  // scanResultList의 변경 사항을 감지.
  BleController() {
    scanResultList.listen((_) {
      updateLists();
      //print(beaconList);
    });
  }

  // BLE 스캔 상태를 토글
  Future<void> toggleState() async {
    isScanning.value = !isScanning.value;

    if (isScanning.value) {
      FlutterBluePlus.startScan(
        androidScanMode: AndroidScanMode.balanced, // 안드로이드에서 저지연 모드로 스캔
        continuousUpdates: true, // 연속 업데이트 활성화
      );
      bleScan();
    } else {
      FlutterBluePlus.stopScan();
    }
  }

  // BLE 스캔 결과를 실시간으로 듣는 메서드.
  Future<void> bleScan() async {
    FlutterBluePlus.scanResults.listen((results) {
      scanResultList.value = results;
    });
  }

  // MAC에 해당하는 RSSI 값을 scanResultList에서 가져오는 함수
  int getRssi(String mac) {
    for (var item in scanResultList) {
      if (item.device.remoteId.str == mac) {
        return item.rssi;
      }
    }
    return 0;
  }

  // 이동 평균 필터를 적용한 RSSI 값을 가져오는 함수
  int getFilteredRssi(String mac) {
    int rssi = getRssi(mac);

    // previousRssiValues맵에 해당 MAC 주소가 없으면, 빈 리스트를 초기화하여 추가.
    if (!previousRssiValues.containsKey(mac)) {
      previousRssiValues[mac] = [];
    }

    // previousRssiValues 맵에서 해당 MAC 주소에 대한 리스트를 가져옴.
    List<int> rssiValues = previousRssiValues[mac]!;

    // 스파이크를 감지하는 로직
    if (rssiValues.length > windowSize) {
      int lastRssi = rssiValues.last;
      if ((rssi - lastRssi).abs() > spikeThreshold) {
        // 스파이크로 간주하여 현재 값을 무시하고 이전 값을 사용
        rssi = lastRssi;
      }
    }

    rssiValues.add(rssi);

    if (rssiValues.length > windowSize) {
      rssiValues.removeAt(0);
    }

    int sum = rssiValues.reduce((a, b) => a + b);
    return (sum / rssiValues.length).round();
  }

  // MAC 주소에 해당하는 기기 이름을 가져오는 함수
  String getPlatformName(String mac) {
    for (var item in scanResultList) {
      if (item.device.remoteId.str == mac) {
        return item.device.platformName;
      }
    }
    return "Unknown";
  }

  // 각 리스트를 업데이트하는 메서드
  Future<void> updateLists() async {
    DatabaseHelper dbHelper = DatabaseHelper.instance;

    List<Map<String, dynamic>> beacon = await dbHelper.getAllBeaconData();

    RxList<Map<String, dynamic>> tempBeaconList =
        RxList<Map<String, dynamic>>([]);

    for (int i = 0; i < beacon.length; i++) {
      String mac = beacon[i]['mac'];

      int rssi = getFilteredRssi(mac);
      bool state = true;
      int floor = beacon[i]['floor'];

      Map<String, dynamic> tempMap = {
        'mac': mac,
        'info': {'rssi': rssi, 'state': state, 'floor': floor}
      };

      if (rssi != 0) {
        tempBeaconList.add(tempMap);
      }
    }

    tempBeaconList
        .sort((a, b) => b['info']['rssi'].compareTo(a['info']['rssi']));

    beaconList = tempBeaconList;
  }
}
