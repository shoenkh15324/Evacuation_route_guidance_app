import 'package:beacon_app/data_folder/beacon_data.dart';
import 'package:beacon_app/data_folder/database_control.dart';
import 'package:beacon_app/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/*
    ** 소스 코드로 BLE 기기 등록하는 방법 **

    1. beacon_data.dart 파일의 beaconDataList에 BLE 기기 정보 추가.

    2. BLE_data.dart 파일의 beaconList에 BLE 기기의 MAC 주소 추가.

    3. main.dart 파일의 initializeApp 함수에서   
          await beaconController.updateBeaconDataListFromDatabase();
       를 주석 처리.

    4. main.dart 파일의 initializeApp 함수에서 
          dbHelper.clearBeaconData();
          beaconController.updateDatabaseListFromBeaconDataList();
       위 두 코드의 주석 제거.

    5. 디버깅 다시 시작.

    6. main.dart 파일의 initializeApp 함수에서   
          await beaconController.updateBeaconDataListFromDatabase();
       의 주석을 제거.

    7. main.dart 파일의 initializeApp 함수에서 
          dbHelper.clearBeaconData();
          beaconController.updateDatabaseListFromBeaconDataList();
       위 두 코드의 주석 추가.
*/

void main() {
  // Flutter 앱을 실행하기 전, 필요한 바인딩을 초기화.
  WidgetsFlutterBinding.ensureInitialized();

  // 앱을 초기화.
  initializeApp();

  // MyApp을 실행합니다.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const GetMaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeScreen(),
    );
  }
}

void initializeApp() async {
  // 데이터베이스 헬퍼 클래스의 인스턴스 생성.
  DatabaseHelper dbHelper = DatabaseHelper.instance;

  // BeaconController를 사용할 수 있도록 GetX에 등록.
  final beaconController = Get.put(BeaconController());

  // 데이터베이스 초기화.
  await dbHelper.database;

  // 데이터베이스에서 데이터를 불러와서 beaconDataList를 업데이트.
  await beaconController.updateBeaconDataListFromDatabase();

  // beaconDataList를 데이터베스에 업데이트(소스 코드로 기기 등록시 필요)
  // dbHelper.clearBeaconData();
  // beaconController.updateDatabaseListFromBeaconDataList();
}
