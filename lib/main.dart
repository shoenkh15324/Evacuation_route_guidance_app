import 'package:beacon_app/data_folder/database_control.dart';
import 'package:beacon_app/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

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

  // 데이터베이스 초기화.
  await dbHelper.database;
}
