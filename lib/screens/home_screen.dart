// ignore_for_file: invalid_use_of_protected_member

import 'package:beacon_app/data_folder/beacon_data.dart';
import 'package:beacon_app/data_folder/ble_data.dart';
import 'package:beacon_app/data_folder/database_control.dart';
import 'package:beacon_app/pages/indoor_map_page.dart';
import 'package:beacon_app/pages/scan_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinbox/flutter_spinbox.dart';
import 'package:get/get.dart';

/*
  홈 화면 페이지
    BLE 장치를 스캔하고 실내 지도를 표시하는 앱의 홈 화면을 구현하는 데 사용. 사용자는 BLE 장치를 추가하고, 스캔한 데이터를 실내 지도에 표시할 수 있다.

    1. **상단 앱 바 (AppBar)**:
      - 앱의 제목인 "Receiver App"이 표시됩니다.
      - 오른쪽에는 BLE(Bluetooth Low Energy) 장치 스캔을 시작하거나 중지할 수 있는 버튼이 있습니다.

    2. **바디 (Body)**:
      - 페이지뷰(PageView) 위젯을 사용하여 스캔 페이지(ScanPage)와 실내 지도 페이지(IndoorMapPage)를 표시합니다. 사용자는 화면 하단의 네비게이션 바를 통해 이 두 페이지를 전환할 수 있습니다.

    3. **하단 네비게이션 바 (Bottom Navigation Bar)**:
      - BLE 장치와 실내 지도 페이지로 전환할 수 있는 네비게이션 바가 있습니다.

    4. **플로팅 액션 버튼 (Floating Action Button)**:
      - 장치를 추가할 수 있는 플로팅 액션 버튼이 있습니다. 이 버튼을 누르면 장치 추가 다이얼로그가 나타납니다.

    5. **장치 추가 다이얼로그 (Add Device Dialog)**:
      - 닉네임, ID, MAC 주소 등을 입력할 수 있는 다이얼로그가 있습니다.
      - 사용자가 입력한 정보를 기반으로 새로운 장치를 생성하고, 이를 비콘 데이터 목록과 BLE 비콘 목록에 추가합니다.

    6. **스핀박스 (SpinBox)**:
      - 층, X, Y, Z 값 등을 입력할 수 있는 스핀박스 위젯이 있습니다.

    7. **컨트롤러 (Controller)**:
      - BLE 컨트롤러와 비콘 컨트롤러가 사용되며, GetX 패키지를 통해 관리됩니다.

    8. **데이터베이스 (Database)**:
      - SQFLite를 사용하여 데이터베이스를 제어합니다.
*/

// 홈 화면 위젯
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// 홈 화면 상태 클래스
class _HomeScreenState extends State<HomeScreen> {
  // 페이지 컨트롤러 초기화. (스크롤해서 페이지 넘길 때 필요)
  final PageController _pageController = PageController(initialPage: 0);

  // BleController, BeaconController를 이 파일에서 사용할 수 있도록 등록.
  final bleController = Get.put(BleController());
  final beaconController = Get.put(BeaconController());

  // 닉네임, ID, MAC주소 TextField 컨트롤러를 생성. (TextField 위젯의 값을 입력 받는데 필요)
  final TextEditingController addNicknameController = TextEditingController();
  final TextEditingController addIDController = TextEditingController();
  final TextEditingController addMACController = TextEditingController();

  // 데이터베이스(database_control.dart) 인스턴스 초기화.
  DatabaseHelper dbHelper = DatabaseHelper.instance;

  // 현재 페이지 번호 저장.
  int _selectedScreen = 0;

  // 기기를 등록할 때 사용하는 임시 변수들.
  String tempNickname = 'Nickname', tempID = 'ID', tempMAC = 'MAC';
  int tempFloor = 0, tempX = 0, tempY = 0, tempZ = 0;

  // 사용이 끝난 리소스 해제.
  @override
  void dispose() {
    addNicknameController.dispose();
    addIDController.dispose();
    addMACController.dispose();
    super.dispose();
  }

  // 페이지 변경 이벤트 핸들러.
  void pageChange(int index) {
    if (_selectedScreen != index) {
      setState(() {
        _selectedScreen = index;
      });
    }
  }

  // 기기 등록 버튼을 눌렀을 때의 이벤트 핸들러.
  void addButtonPressed(BuildContext context) {
    // 임시 리스트 생성.
    RxList<dynamic> tempList = RxList<dynamic>([
      tempMAC,
      tempID,
      tempFloor,
      tempX,
      tempY,
      tempZ,
      tempNickname,
    ]);

    // beaconDataList에 추가.
    beaconController.beaconDataList.add(tempList);

    // beaconList에 추가.
    bleController.beaconList.add(tempList[0]);

    // 다이얼로그 닫기.
    Navigator.pop(context);
  }

  // 장치 추가 다이얼로그 위젯.
  Widget addDeviceDialog(BuildContext context) {
    return Center(
      // 기기 등록 창 위젯.
      child: AlertDialog(
        title: const Text('Add Device',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
        actions: [
          // 닉네임을 입력받는 텍스트필드 위젯.
          TextField(
            controller: addNicknameController,
            decoration: const InputDecoration(label: Text('Nickname')),
            onChanged: (value) {
              tempNickname = addNicknameController.text;
            },
          ),
          // ID를 입력받는 텍스트필드 위젯.
          TextField(
            controller: addIDController,
            decoration: const InputDecoration(label: Text('ID')),
            onChanged: (value) {
              tempID = addIDController.text;
            },
          ),
          // MAC 주소를 입력받는 텍스트필드 위젯.
          TextField(
            controller: addMACController,
            decoration: const InputDecoration(label: Text('MAC Address')),
            onChanged: (value) {
              tempMAC = addMACController.text;
            },
          ),
          const SizedBox(height: 30),
          // 층 정보를 입력받는 스핀박스 위젯.
          SpinBox(
            min: -100,
            max: 100,
            value: 0,
            decimals: 0,
            step: 1,
            onChanged: (value) {
              tempFloor = value.toInt();
            },
            decoration: const InputDecoration(
                label: Text(
                  'Floor',
                  style: TextStyle(fontSize: 20),
                ),
                border: OutlineInputBorder(borderSide: BorderSide.none)),
          ),
          // X좌표를 입력받는 스핀박스 위젯.
          SpinBox(
            min: -100,
            max: 100,
            value: 0,
            decimals: 0,
            step: 1,
            onChanged: (value) {
              tempX = value.toInt();
            },
            decoration: const InputDecoration(
                label: Text(
                  'X',
                  style: TextStyle(fontSize: 20),
                ),
                border: OutlineInputBorder(borderSide: BorderSide.none)),
          ),
          // Y좌표를 입력받는 스핀박스 위젯.
          SpinBox(
            min: -100,
            max: 100,
            value: 0,
            decimals: 0,
            step: 1,
            onChanged: (value) {
              tempY = value.toInt();
            },
            decoration: const InputDecoration(
                label: Text(
                  'Y',
                  style: TextStyle(fontSize: 20),
                ),
                border: OutlineInputBorder(borderSide: BorderSide.none)),
          ),
          // Z좌표를 입력받는 스핀박스 위젯.
          SpinBox(
            min: -100,
            max: 100,
            value: 0,
            decimals: 0,
            step: 1,
            onChanged: (value) {
              tempZ = value.toInt();
            },
            decoration: const InputDecoration(
                label: Text(
                  'Z',
                  style: TextStyle(fontSize: 20),
                ),
                border: OutlineInputBorder(borderSide: BorderSide.none)),
          ),
          // Add 버튼 위젯
          TextButton(
            onPressed: () => addButtonPressed(context),
            style: ButtonStyle(
              backgroundColor:
                  MaterialStatePropertyAll(Colors.deepPurple.shade100),
              fixedSize: const MaterialStatePropertyAll(Size(60, 40)),
            ),
            child: const Text(
              'Add',
              style: TextStyle(color: Colors.black, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // UI 위젯.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.blue,
        elevation: 1,
        shadowColor: Colors.black,
        title: const Text(
          'Receiver App',
          style: TextStyle(
            color: Colors.white,
            fontSize: 25,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Obx(
            // 스캔 시작/정지 버튼
            () => IconButton(
              icon: Icon(
                bleController.isScanning.value ? Icons.stop : Icons.search,
              ),
              iconSize: 30,
              color: Colors.white,
              onPressed: () {
                bleController.toggleState();
              },
            ),
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        allowImplicitScrolling: false,
        onPageChanged: pageChange,
        children: const [
          ScanPage(), // 스캔 페이지.
          IndoorMapPage(), // 실내 지도 페이지.
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.bluetooth),
            label: "BLE Device",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: "IndoorMap",
          ),
        ],
        currentIndex: _selectedScreen,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white,
        backgroundColor: Colors.blue,
        onTap: (int index) {
          _pageController.jumpToPage(index); // 페이지 이동.
        },
      ),
      floatingActionButton: FloatingActionButton(
        elevation: 1,
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) {
              return SingleChildScrollView(
                  child: addDeviceDialog(context)); // 다이얼로그 띄우기
            },
          );
        },
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
