import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleWidgets {
  // 기기 이름이 NULL인지 확인하는 함수
  String deviceNameCheck(ScanResult r) {
    String name;

    // 기기의 이름이 있으면 사용하고, 없으면 'N/A'로 설정
    if (r.device.advName.isNotEmpty) {
      name = r.device.advName;
    } else if (r.advertisementData.advName.isNotEmpty) {
      name = r.advertisementData.advName;
    } else {
      name = 'N/A';
    }
    return name;
  }

  // Bluetooth 아이콘을 나타내는 위젯
  Widget bleIcon() {
    return const CircleAvatar(
      backgroundColor: Colors.cyan,
      radius: 25,
      child: Icon(
        Icons.bluetooth,
        color: Colors.white,
        size: 30,
      ),
    );
  }
}
