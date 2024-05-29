// ignore_for_file: invalid_use_of_protected_member

import 'package:beacon_app/data_folder/ble_data.dart';
import 'package:beacon_app/data_folder/beacon_data.dart';
import 'package:beacon_app/data_folder/database_control.dart';
import 'package:beacon_app/widgets/bluetooth_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinbox/flutter_spinbox.dart';
import 'package:get/get.dart';

/* 
  BLE 스캔 페이지
    BLE 장치를 스캔하고, 각 장치에 대한 세부 정보를 표시하며, 필요한 경우 이 정보를 수정하거나 삭제할 수 있는 기능을 제공.

    1. BLE 장치 스캔 및 표시:
      - BLE(Bluetooth Low Energy) 장치를 스캔하고, 각 장치의 정보를 화면에 표시합니다.
      - 각 장치에는 닉네임, ID, MAC 주소, 층 정보 및 좌표 정보가 포함됩니다.

    2. 비콘 정보 수정 및 삭제:
      - 각 장치의 정보를 수정할 수 있는 설정 버튼을 제공합니다.
      - 설정 버튼을 누르면 해당 장치의 세부 정보를 수정할 수 있는 다이얼로그가 표시됩니다.
      - 다이얼로그에서는 닉네임, ID, 층, 좌표 정보 등을 수정할 수 있습니다.

    3. 세부 기능:
      - 장치의 세부 정보를 수정한 후 설정 버튼을 누르면 변경된 정보가 적용됩니다.
      - 삭제 버튼을 누르면 해당 장치의 정보가 삭제됩니다.
    
    4. 비콘 데이터 관리:
      - 비콘 컨트롤러를 통해 비콘 데이터를 관리하고 업데이트합니다.
      - 데이터베이스를 사용하여 비콘 데이터를 저장하고 업데이트합니다.
 */

// 스캔 페이지 위젯
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

// 스캔 페이지 상태 클래스
class _ScanPageState extends State<ScanPage> {
  // BleController, BeaconController를 이 파일에서 사용할 수 있도록 등록.
  final bleController = Get.put(BleController());
  final beaconController = Get.put(BeaconController());

  // 닉네임, ID, TextField 컨트롤러를 생성. (TextField 위젯의 값을 입력 받는데 필요)
  TextEditingController beaconIdController = TextEditingController();
  TextEditingController beaconNicknameController = TextEditingController();

  // 기기 정보를 수정할 때 사용하는 임시 변수들.
  String? tempNickname, tempID;
  int? tempFloor, tempX, tempY, tempZ;

  // 사용이 끝난 리소스를 해제.
  @override
  void dispose() {
    beaconNicknameController.dispose();
    beaconIdController.dispose();
    super.dispose();
  }

  // 세팅 버튼 이벤트 핸들러.
  void settingButtonPressed(BuildContext context, String mac) {
    beaconController.edittingBeaconDataList(
      mac: mac,
      id: tempID,
      floor: tempFloor,
      x: tempX,
      y: tempY,
      z: tempZ,
      nickname: tempNickname,
    );

    // 데이터베이스에 업데이트.
    beaconController.updateDatabaseListFromBeaconDataList();

    // 상태 업데이트.
    setState(() {});

    // 다이얼로그 닫기.
    Navigator.pop(context);
  }

  // 삭제 버튼 이벤트 핸들러
  void deleteButtonPressed(BuildContext context, String mac) async {
    DatabaseHelper dhHelper = DatabaseHelper.instance;

    // MAC주소로 beaconDataList에서 삭제하려는 기기의 주소를 찾음
    int index = beaconController.findMACIndex(mac);
    if (index != -1) {
      // beaconDataList에 해당 기기 삭제.
      beaconController.beaconDataList.removeAt(index);
    }

    // beaconList에 업데이트.
    bleController.updateBeaconList();

    // 데이터베이스에서 해당 MAC주소를 가진 데이터 삭제
    dhHelper.deleteBeaconData(mac);

    // 상태 업데이트.
    setState(() {});
  }

  // 비콘 리스트 위젯
  Widget widgetBleList(RxList<dynamic> list) {
    final deviceMAC = list.value[0];

    return ExpansionTile(
      // 닉네임 표시.
      title: Text(
        beaconController.printBeaconNickname(deviceMAC),
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 17,
        ),
      ),
      leading: BleWidgets().bleIcon(),
      // 기기 ID 표시.
      subtitle: Obx(
        () => Text(
          beaconController.printBeaconID(deviceMAC),
          style: const TextStyle(
            fontSize: 15,
          ),
        ),
      ),
      // RSSI 표시.
      trailing: Obx(
        () => Text(
          bleController.getRssi(deviceMAC),
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
                  Text(
                      'Floor: ${beaconController.printBeaconFloor(deviceMAC).toString()}'),
                  // X, Y, Z 좌표 표시.
                  Text(
                      'X: ${beaconController.printBeaconXaxis(deviceMAC)}, Y: ${beaconController.printBeaconYaxis(deviceMAC)}, Z: ${beaconController.printBeaconZaxis(deviceMAC)}'),
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
                        child: beaconSettingDialog(context, deviceMAC));
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
  Widget beaconSettingDialog(BuildContext context, String mac) {
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
          value: beaconController.printBeaconFloor(mac).toDouble(),
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
          max: 1001,
          value: beaconController.printBeaconXaxis(mac).toDouble(),
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
          max: 701,
          value: beaconController.printBeaconYaxis(mac).toDouble(),
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
          value: beaconController.printBeaconZaxis(mac).toDouble(),
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
            settingButtonPressed(context, mac);
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

  // UI 위젯.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Obx(
          () {
            return ListView.builder(
              itemBuilder: (context, index) {
                var list = beaconController.beaconDataList.value[index];
                return widgetBleList(list);
              },
              itemCount: beaconController.beaconDataList.length,
            );
          },
        ),
      ),
    );
  }
}
