// ignore_for_file: file_names

import 'dart:async';

import 'package:beacon_app/data_folder/beacon_data.dart';
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
  // BLE 스캔 결과를 구독하는 Subscription
  //StreamSubscription<List<ScanResult>>? _scanSubscription;

  final isScanning = RxBool(false); // 스캔 상태 플래그
  RxList<ScanResult> scanResultList = RxList<ScanResult>([]); // BLE 기기 스캔 결과
  final rssiList = RxList<Map<String, dynamic>>([]); // RSSI 값 목록
  final platformNameList = RxList<Map<String, String>>([]); // 기기명 목록

  final int windowSize = 10; // 이동 평균 윈도우 크기
  Map<String, List<int>> rssiHistory = {}; // 각 MAC 주소에 대한 RSSI 히스토리

  /* 스캔할 기기의 MAC 주소 리스트 */
  RxList<String> beaconList = RxList<String>([
    'C8:0F:10:B3:5D:D5', // TEST1
    '54:44:A3:EB:E7:E1', // TEST2
    'E0:9D:13:86:A9:63', // TEST3
    'C4:F3:12:51:AE:21', // BEACON1
    'BC:6A:29:C3:44:E2', // BEACON2
    '34:15:13:88:8A:60', // BEACON3
    'D4:36:39:6F:BA:D5', // BEACON4
    'F8:30:02:4A:E4:5F', // BEACON5
  ]);

  // scanResultList의 변경 사항을 감지하고 변경될 때마다 updateLists를 호출.
  BleController() {
    scanResultList.listen((_) {
      updateLists(scanResultList);
    });
    // platformNameList.listen((_) {
    //   print(platformNameList);
    // });
  }

  // BLE 스캔 상태를 토글
  Future<void> toggleState() async {
    isScanning.value = !isScanning.value;

    if (isScanning.value) {
      FlutterBluePlus.startScan(
        androidScanMode: AndroidScanMode.lowLatency, // 안드로이드에서 저지연 모드로 스캔
        continuousUpdates: true, // 연속 업데이트 활성화
        withRemoteIds: beaconList, // 지정된 비콘만 포함하도록 스캔 결과 필터링
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

  // 스캔 결과를 업데이트하는 함수
  void updateLists(List<ScanResult> results) {
    try {
      List<Map<String, dynamic>> tempRssiList = [];
      List<Map<String, String>> tempPlatformNameList = [];

      for (var result in results) {
        final macAddress = result.device.remoteId.toString();
        final rssi = result.rssi;
        final platformName = result.device.platformName;

        // RSSI 히스토리 업데이트
        if (!rssiHistory.containsKey(macAddress)) {
          rssiHistory[macAddress] = [];
        }
        rssiHistory[macAddress]!.add(rssi);
        if (rssiHistory[macAddress]!.length > windowSize) {
          rssiHistory[macAddress]!.removeAt(0);
        }

        // 이동 평균 계산
        final avgRssi = rssiHistory[macAddress]!.reduce((a, b) => a + b) ~/
            rssiHistory[macAddress]!.length;

        Map<String, dynamic> tempRssiMap = {
          'macAddress': macAddress,
          'rssi': avgRssi,
        };
        Map<String, String> tempPlatformNameMap = {
          'macAddress': macAddress,
          'platformname': platformName,
        };

        tempRssiList.add(tempRssiMap);
        tempPlatformNameList.add(tempPlatformNameMap);
      }
      rssiList.value = tempRssiList;
      platformNameList.value = tempPlatformNameList;

      rssiList.sort((a, b) => b['rssi'].compareTo(a['rssi']));
    } catch (e) {
      //print("Error in updataList: $e");
    }
  }

  // beaconList를 업데이트하는 함수
  void updateBeaconList() {
    try {
      final beaconController = Get.put(BeaconController());
      RxList<String> tempList = RxList<String>([]);
      for (var data in beaconController.beaconDataList) {
        String mac = data[0];
        tempList.add(mac);
      }
      beaconList = tempList;
    } catch (e) {
      //print("Error in updateBeaconList: $e");
    }
  }

  // MAC 주소에 해당하는 RSSI 값을 가져오는 함수
  dynamic getRssi(String mac) {
    for (var item in rssiList) {
      if (item['macAddress'] == mac) {
        return item['rssi'].toString();
      }
    }
    return '0';
  }

  // MAC 주소에 해당하는 기기 이름을 가져오는 함수
  String getPlatformName(String mac) {
    for (var item in platformNameList) {
      if (item['macAddress'] == mac) {
        return item['platformname'].toString();
      }
    }
    return "Unknown";
  }
}
