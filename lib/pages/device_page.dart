// ignore_for_file: invalid_use_of_protected_member

import 'package:beacon_app/data_folder/ble_data.dart';
import 'package:beacon_app/data_folder/database_control.dart';
import 'package:beacon_app/widgets/bluetooth_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinbox/flutter_spinbox.dart';
import 'package:get/get.dart';

/*
  디바이스 페이지
    블루투스 비콘 장치의 정보를 표시하고 관리하는 페이지. 비콘 정보를 불러와 리스트로 표시하고, 비콘의 세부 정보를 수정하거나 삭제할 수 있도록 한다.
*/

class DevicePage extends StatefulWidget {
  const DevicePage({super.key});

  @override
  State<DevicePage> createState() => _ScanPageState();
}

// 스캔 페이지 상태 클래스
class _ScanPageState extends State<DevicePage> {
  // BleController, BeaconController를 이 파일에서 사용할 수 있도록 등록.
  final bleController = Get.put(BleController());

  // 닉네임, ID, TextField 컨트롤러를 생성. (TextField 위젯의 값을 입력 받는데 필요)
  TextEditingController beaconIdController = TextEditingController();
  TextEditingController beaconNicknameController = TextEditingController();

  // 기기 정보를 수정할 때 사용하는 임시 변수들.
  String? tempNickname, tempID;
  int? tempFloor, tempX, tempY, tempZ;

  @override
  void initState() {
    super.initState();
    getList();
  }

  // 상태 업데이트 메서드
  void _updateState() {
    if (mounted) {
      setState(() {
        getList();
      });
    }
  }

  // 사용이 끝난 리소스를 해제.
  @override
  void dispose() {
    super.dispose();
    beaconNicknameController.dispose();
    beaconIdController.dispose();
  }

  // 세팅 버튼 이벤트 핸들러.
  void settingButtonPressed(VoidCallback onDialogClose, String mac) async {
    final dbHelper = DatabaseHelper.instance;

    try {
      await dbHelper.transaction((txn) async {
        try {
          if (tempID != null) {
            //print('Updating beaconId with value: $tempID');
            await dbHelper.updateSpecificDataByMac(
                txn, mac, 'beaconId', tempID);
            tempID = null;
          }
          if (tempFloor != null) {
            //print('Updating floor with value: $tempFloor');
            await dbHelper.updateSpecificDataByMac(
                txn, mac, 'floor', tempFloor);
            tempFloor = null;
          }
          if (tempX != null) {
            //print('Updating x with value: $tempX');
            await dbHelper.updateSpecificDataByMac(txn, mac, 'x', tempX);
            tempX = null;
          }
          if (tempY != null) {
            //print('Updating y with value: $tempY');
            await dbHelper.updateSpecificDataByMac(txn, mac, 'y', tempY);
            tempY = null;
          }
          if (tempZ != null) {
            //print('Updating z with value: $tempZ');
            await dbHelper.updateSpecificDataByMac(txn, mac, 'z', tempZ);
            tempZ = null;
          }
          if (tempNickname != null) {
            //print('Updating nickname with value: $tempNickname');
            await dbHelper.updateSpecificDataByMac(
                txn, mac, 'nickname', tempNickname);
            tempNickname = null;
          }
        } catch (e) {
          //print('Error during transaction: $e');
          rethrow; // 예외를 다시 throw하여 트랜잭션 전체가 실패하도록 함
        }
      });

      // Call the callback to close the dialog
      onDialogClose();

      // Update the UI state
      _updateState();
    } catch (e) {
      //print('Transaction failed: $e');
      onDialogClose();
    }
  }

  // 삭제 버튼 이벤트 핸들러
  void deleteButtonPressed(BuildContext context, String mac) async {
    DatabaseHelper dbHelper = DatabaseHelper.instance;

    try {
      await dbHelper.transaction((txn) async {
        // 데이터 삭제
        await dbHelper.deleteBeaconData(txn, mac);
      });

      // 상태 업데이트.
      _updateState();
    } catch (e) {
      //print('Transaction failed: $e');
    }
  }

  // 비콘 리스트 위젯
  Widget widgetBleList(Map<String, dynamic> list) {
    final deviceMAC = list['mac'];

    return ExpansionTile(
      // 닉네임 표시.
      title: Text(
        list['nickname'],
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 17,
        ),
      ),
      leading: BleWidgets().bleIcon(),
      // 기기 ID 표시.
      subtitle: Text(
        list['beaconId'],
        style: const TextStyle(
          fontSize: 15,
        ),
      ),

      // RSSI 표시.
      trailing: Obx(
        () => Text(
          bleController.getRssi(deviceMAC).toString(),
          style: const TextStyle(
            fontSize: 15,
          ),
        ),
      ),

      children: [
        Row(
          children: [
            const SizedBox(
              width: 15,
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 기기 이름 표시.
                  SizedBox(
                    width: 250,
                    child: Obx(
                      () => Text(
                        'Name: ${bleController.getPlatformName(deviceMAC)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  // MAC 표시.
                  Text('MAC: $deviceMAC'),
                  // 층 정보 표시.
                  Text('Floor: ${list['floor']}'),
                  // X, Y, Z 좌표 표시.
                  Text('X: ${list['x']},  Y: ${list['y']},  Z: ${list['z']}'),
                ],
              ),
            ),
            const Spacer(),
            // 세팅 버튼 위젯.
            IconButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    // 세팅 다이얼로그 위젯.
                    return SingleChildScrollView(
                        child: beaconSettingDialog(context, list));
                  },
                );
              },
              icon: const Icon(Icons.settings),
              iconSize: 40,
            ),
            // 삭제 버튼 위젯.
            IconButton(
              onPressed: () {
                deleteButtonPressed(context, deviceMAC);
              },
              icon: const Icon(Icons.delete),
              iconSize: 40,
            ),
            const SizedBox(
              width: 10,
            ),
          ],
        ),
      ],
    );
  }

  // 기기 세팅 다이얼로그 위젯.
  Widget beaconSettingDialog(BuildContext context, Map<String, dynamic> list) {
    return AlertDialog(
      title: const Text(
        'Beacon Setting',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      ),
      actions: [
        // 닉네임 입력을 받는 위젯.
        TextField(
          controller: beaconNicknameController,
          onChanged: (value) {
            tempNickname = beaconNicknameController.text;
          },
          decoration: const InputDecoration(
              labelText: 'Nickname',
              labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
        // ID 입력을 받는 위젯.
        TextField(
          controller: beaconIdController,
          onChanged: (value) {
            tempID = beaconIdController.text;
          },
          decoration: const InputDecoration(
              labelText: 'ID',
              labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(
          height: 30,
        ),
        // 층 정보를 입력받는 위젯.
        SpinBox(
          min: -100,
          max: 100,
          value: list['floor'].toDouble(),
          decimals: 0,
          step: 1,
          onChanged: (value) {
            tempFloor = value.toInt();
          },
          decoration: const InputDecoration(
            label: Text(
              'Floor',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            border: OutlineInputBorder(borderSide: BorderSide.none),
          ),
        ),
        // X좌표를 입력받는 위젯.
        SpinBox(
          min: 0,
          max: 831,
          value: list['x'].toDouble(),
          decimals: 0,
          step: 1,
          onChanged: (value) {
            tempX = value.toInt();
          },
          decoration: const InputDecoration(
            label: Text(
              'X-axis',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            border: OutlineInputBorder(borderSide: BorderSide.none),
          ),
        ),
        // Y좌표를 입력받는 위젯.
        SpinBox(
          min: 0,
          max: 501,
          value: list['y'].toDouble(),
          decimals: 0,
          step: 1,
          onChanged: (value) {
            tempY = value.toInt();
          },
          decoration: const InputDecoration(
            label: Text(
              'Y-axis',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            border: OutlineInputBorder(borderSide: BorderSide.none),
          ),
        ),
        // Z좌표를 입력받는 위젯.
        SpinBox(
          min: -100,
          max: 100,
          value: list['z'].toDouble(),
          decimals: 0,
          step: 1,
          onChanged: (value) {
            tempZ = value.toInt();
          },
          decoration: const InputDecoration(
            label: Text(
              'Z-axis',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            border: OutlineInputBorder(borderSide: BorderSide.none),
          ),
        ),
        // Setting 버튼 위젯.
        TextButton(
          onPressed: () {
            settingButtonPressed(() {
              Navigator.pop(context);
            }, list['mac']);
          },
          style: const ButtonStyle(
              backgroundColor: MaterialStatePropertyAll(Colors.blue)),
          child: const Text(
            'Setting',
            style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  // 데이터베이스의 데이터 리스트를 가져오는 메서드
  Future<void> getList() async {
    DatabaseHelper dbHelper = DatabaseHelper.instance;
    List<Map<String, dynamic>> temp = await dbHelper.getAllBeaconData();
    list = temp;
    _updateState();
  }

  // 등록된 기기 리스트
  List<Map<String, dynamic>> list = [];

  // UI 위젯.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ListView.builder(
          itemBuilder: (context, index) {
            return widgetBleList(list[index]);
          },
          itemCount: list.length,
        ),
      ),
    );
  }
}
