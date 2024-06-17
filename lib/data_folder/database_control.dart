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

  // BeaconData를 Map 객체로 변환하는 함수
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

  // Map 객체를 BeaconData로 변환하는 함수
  factory BeaconData.fromMap(Map<String, dynamic> map) {
    return BeaconData(
      mac: map['mac'],
      beaconId: map['beaconId'],
      floor: map['floor'],
      x: map['x'],
      y: map['y'],
      z: map['z'],
      nickname: map['nickname'],
    );
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

  // 특정 MAC 주소의 데이터를 전체 업데이트
  Future<int> updateWholeBeaconDataByMac(
      String mac, Map<String, dynamic> updates) async {
    final db = await database;

    return await db.transaction((txn) async {
      return await txn.update(
        'beaconData',
        updates,
        where: 'mac = ?',
        whereArgs: [mac],
      );
    });
  }

  // mac주소를 받아서 해당 mac을 가진 데이터의 특정 데이터를 업데이트
  Future<void> updateSpecificDataByMac(
      String mac, String arg, dynamic value) async {
    final dbHelper = DatabaseHelper.instance;
    final beaconData = await dbHelper.getBeaconData(mac);

    if (beaconData != null) {
      final Map<String, dynamic> updates = {};
      switch (arg) {
        case 'id':
          updates['beaconId'] = value;
          break;
        case 'floor':
          updates['floor'] = value;
          break;
        case 'x':
          updates['x'] = value;
          break;
        case 'y':
          updates['y'] = value;
          break;
        case 'z':
          updates['z'] = value;
          break;
        case 'nickname':
          updates['nickname'] = value;
          break;
        default:
          throw ArgumentError('Invalid argument');
      }

      await dbHelper.updateWholeBeaconDataByMac(mac, updates);
    }
  }

  // mac주소로 데이터 가져오기
  Future<BeaconData?> getBeaconData(String mac) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'beaconData',
      where: 'mac = ?',
      whereArgs: [mac],
    );

    if (maps.isNotEmpty) {
      return BeaconData.fromMap(maps.first);
    } else {
      return null;
    }
  }

  // 특정 데이터 가져오기
  Future<dynamic> getSomethingInBeaconData(String mac, String arg) async {
    final beaconData = await getBeaconData(mac);

    if (arg == 'id') return beaconData?.beaconId;
    if (arg == 'floor') return beaconData?.floor;
    if (arg == 'x') return beaconData?.x;
    if (arg == 'y') return beaconData?.y;
    if (arg == 'z') return beaconData?.z;
    if (arg == 'nickname') return beaconData?.nickname;
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

  // 데이터베이스의 데이터 개수 반환.
  Future<int> getBeaconDataCount() async {
    final db = await database;
    return Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM beaconData')) ??
        0;
  }

  // mac주소를 가지고 데이터의 인덱스를 반환하는 메서드
  Future<int?> getIndexByMac(String mac) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'beaconData',
      columns: ['rowid'],
      where: 'mac = ?',
      whereArgs: [mac],
    );

    if (result.isNotEmpty) {
      return result.first['rowid'] as int?;
    } else {
      return -1;
    }
  }

  // 모든 비콘 데이터 가져오기
  Future<List<Map<String, dynamic>>> getAllBeaconData() async {
    final db = await database;
    return await db.query('beaconData');
  }

  Future<void> transaction(
      Future<void> Function(Transaction txn) action) async {
    // Check if _database is null
    if (_database == null) {
      throw Exception('Database not initialized');
    }

    try {
      await _database!.transaction((txn) async {
        await action(
            txn); // Call the action function with the Transaction object
      });
    } catch (e) {
      print('Transaction failed: $e');
      // Handle any transaction failure gracefully
      rethrow; // Optionally rethrow to propagate the error upwards
    }
  }
}
