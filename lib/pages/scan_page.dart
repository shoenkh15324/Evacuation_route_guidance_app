import 'package:beacon_app/data_folder/ble_data.dart';
import 'package:beacon_app/data_folder/database_control.dart';
import 'package:beacon_app/widgets/bluetooth_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:toggle_switch/toggle_switch.dart';

/* 
  스캔 페이지
    Bluetooth 장치를 스캔하고, 해당 장치들을 목록으로 표시하며, 사용자가 선택한 장치를 등록하거나 등록 취소할 수 있는 기능을 제공.
*/

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  @override
  void initState() {
    super.initState();
  }

  void _updateState() {
    if (mounted) {
      setState(() {});
    }
  }

  // 기기 등록 함수
  Future<void> enrollDevice(String mac) async {
    DatabaseHelper dbHelper = DatabaseHelper.instance;

    int? isExist = await dbHelper.getIndexByMac(mac);
    if (isExist == -1) {
      BeaconData temp = BeaconData(
        mac: mac,
        beaconId: 'ID',
        floor: 0,
        x: 0,
        y: 0,
        z: 0,
        nickname: 'N/A',
      );
      dbHelper.insertBeaconData(temp);
    }

    _updateState();
  }

  // 기기 등록 취소
  Future<void> cancelDevice(String mac) async {
    DatabaseHelper dbHelper = DatabaseHelper.instance;

    int? index = await dbHelper.getIndexByMac(mac);
    if (index != -1) {
      dbHelper.deleteBeaconData(mac);
    }
    _updateState();
  }

  int checkEnrollState(String mac) {
    BleController bleController = Get.put(BleController());

    int index = -1;
    int state = 0;

    for (var i = 0; i < bleController.enrolledState.length; i++) {
      if (mac == bleController.enrolledState[i]['mac']) {
        index = i;
      }
    }

    if (index != -1) {
      state = 1;
    }

    return state;
  }

  // 스캔 결과를 보여주는 리스트 위젯
  Widget scanList(ScanResult list, int listIndex) {
    return ExpansionTile(
      title: list.device.advName.isNotEmpty
          ? Text(
              list.device.advName.toString(),
              overflow: TextOverflow.ellipsis,
            )
          : const Text('N/A'),
      subtitle: Text(list.device.remoteId.str),
      leading: BleWidgets().bleIcon(),
      trailing: Text(
        list.rssi.toString(),
        style: const TextStyle(fontSize: 14),
      ),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              child: Text(
                'Enroll this device?',
                style: TextStyle(fontSize: 16),
              ),
            ),
            // 기기 등록 스위치 위젯
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: ToggleSwitch(
                initialLabelIndex: checkEnrollState(list.device.remoteId.str),
                minHeight: 43.0,
                minWidth: 70.0,
                cornerRadius: 20.0,
                activeFgColor: Colors.white,
                inactiveBgColor: Colors.grey,
                inactiveFgColor: Colors.white,
                totalSwitches: 2,
                labels: const ['No', 'Yes'],
                icons: const [Icons.clear, Icons.check_outlined],
                iconSize: 18,
                animate: true,
                curve: Curves.fastLinearToSlowEaseIn,
                radiusStyle: true,
                onToggle: (toggleIndex) {
                  if (toggleIndex == 1) {
                    enrollDevice(list.device.remoteId.str);
                  } else if (toggleIndex == 0) {
                    cancelDevice(list.device.remoteId.str);
                  }
                },
              ),
            )
          ],
        ),
      ],
    );
  }

  // UI
  @override
  Widget build(BuildContext context) {
    final bleController = Get.put(BleController());
    return Scaffold(
      body: Center(
        child: Obx(() {
          return ListView.builder(
            itemBuilder: (context, index) {
              return scanList(bleController.scanResultList[index], index);
            },
            itemCount: bleController.scanResultList.length,
          );
        }),
      ),
    );
  }
}
