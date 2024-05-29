import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/*
  등록된 기기 관련 데이터 모델과 데이터베이스 관리를 담당하는 클래스를 정의.

  *** BeaconData 클래스 ***
    - 비콘 데이터 모델: BeaconData 클래스는 비콘의 MAC 주소, ID, 층 정보, X좌표, Y좌표, Z좌표, 닉네임 등을  저장하는 모델을 정의합니다.
    - toMap() 함수: BeaconData 객체를 데이터베이스에 삽입하기 위해 Map 형태로 변환합니다.

  *** DatabaseHelper 클래스 ***
    - SQLite 데이터베이스 관리: DatabaseHelper 클래스는 SQLite 데이터베이스와의 상호작용을 담당합니다.
    - 데이터베이스 초기화: 앱이 처음 실행될 때 데이터베이스를 초기화하고 필요한 테이블을 생성합니다.
    - BeaconData 삽입: 새로운 비콘 데이터를 데이터베이스에 삽입합니다. 이미 존재하는 경우에는 덮어씁니다.
    - BeaconData 업데이트: 기존 비콘 데이터를 업데이트합니다.
    - BeaconData 삭제: 특정 MAC 주소를 가진 비콘 데이터를 삭제합니다.
    - BeaconData 클리어: 데이터베이스의 모든 비콘 데이터를 삭제합니다.
    - 모든 비콘 데이터 가져오기: 데이터베이스에 저장된 모든 비콘 데이터를 가져옵니다.

  *** 기능 요약 ***
    - 비콘 데이터 관리: BeaconData 클래스를 사용하여 비콘의 정보를 표현하고 다룰 수 있습니다.
    - 데이터베이스 상호작용: DatabaseHelper 클래스를 통해 비콘 데이터를 SQLite 데이터베이스에 저장, 업데이트, 삭제하고, 데이터를 가져올 수 있습니다.
    - 데이터 유효성 검사: 새로운 비콘 데이터를 데이터베이스에 추가할 때 유효성을 검사하여 적절한 데이터 형식으로 변환합니다.
    - SQLite 데이터베이스 관리: 데이터베이스의 초기화, 테이블 생성 및 데이터 조작 기능을 제공하여 앱에서 비콘 데이터를 효과적으로 관리할 수 있습니다.
*/

// 데이터 모델 정의
class BeaconData {
  final String mac;
  final String beaconId;
  final int floor;
  final int x;
  final int y;
  final int z;
  final String nickname;

  BeaconData({
    required this.mac,
    required this.beaconId,
    required this.floor,
    required this.x,
    required this.y,
    required this.z,
    required this.nickname,
  });

  // BeaconData 객체를 Map으로 변환하는 함수
  Map<String, dynamic> toMap() {
    return {
      'mac': mac,
      'beaconId': beaconId,
      'floor': floor,
      'x': x,
      'y': y,
      'z': z,
      'nickname': nickname,
    };
  }
}

// 데이터베이스 헬퍼 클래스 정의
class DatabaseHelper {
  // private 생성자 (다른 파일에서 해당 클래스 생성자를 만들지 못하게 함)
  DatabaseHelper._privateConstructor();

  // 싱글톤 인스턴스 생성
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  // SQLite 데이터베이스를 저장하는 변수
  static Database? _database;

  // 데이터베이스 인스턴스 반환
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // 데이터베이스 초기화
  _initDatabase() async {
    // 데이터베이스 파일 경로 설정
    String path = join(await getDatabasesPath(), 'device_database.db');

    // 데이터베이스 열기
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDatabase,
    );
  }

  // 데이터베이스 테이블 생성
  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''CREATE TABLE beaconData(
      mac TEXT PRIMARY KEY,
      beaconId TEXT,
      floor INTEGER,
      x INTEGER,
      y INTEGER,
      z INTEGER,
      nickname TEXT
    )''');
  }

  // 데이터 추가
  Future<int> insertBeaconData(BeaconData data) async {
    final db = await database;
    return await db.insert(
      'beaconData',
      data.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // 데이터 업데이트
  Future<int> updateBeaconData(BeaconData data) async {
    final db = await database;
    return await db.update(
      'beaconData',
      data.toMap(),
      where: 'mac=?',
      whereArgs: [data.mac],
    );
  }

  // 데이터 삭제
  Future<int> deleteBeaconData(String mac) async {
    final db = await database;
    return await db.delete(
      'beaconData',
      where: 'mac=?',
      whereArgs: [mac],
    );
  }

  // 데이터베이스 클리어
  Future<void> clearBeaconData() async {
    final db = await database;
    await db.delete('beaconData');
  }

  // 모든 비콘 데이터 가져오기
  Future<List<Map<String, dynamic>>> getAllBeaconData() async {
    final db = await database;
    return await db.query('beaconData');
  }

  // 데이터베이스에 데이터 추가 함수(다른 파일에서 사용하는 용도)
  Future<void> addDataToDatabase(List<dynamic> newDevice) async {
    // 데이터베이스 인스턴스 생성
    final dbHelper = DatabaseHelper.instance;

    // 데이터 유효성 검사 및 타입 변환
    if (newDevice.length == 7 &&
        newDevice.every((element) => element is String || element is int)) {
      final mac = newDevice[0] as String;
      final beaconId = newDevice[1] as String;
      final floor = newDevice[2] as int;
      final x = newDevice[3] as int;
      final y = newDevice[4] as int;
      final z = newDevice[5] as int;
      final nickname = newDevice[6] as String;

      final beacon = BeaconData(
        mac: mac,
        beaconId: beaconId,
        floor: floor,
        x: x,
        y: y,
        z: z,
        nickname: nickname,
      );

      // 데이터 추가
      await dbHelper.insertBeaconData(beacon);
    }
  }
}
