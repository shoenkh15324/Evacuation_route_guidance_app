// ignore_for_file: invalid_use_of_protected_member

import 'package:beacon_app/data_folder/database_control.dart';
import 'package:get/get.dart';

/*
  등록된 기기의 데이터를 관리하는 코드
    GetX 라이브러리를 사용하여 등록된 기기를 관리하는 클래스인 BeaconController를 정의한다. 등록된 기기를 관리하고, 필요한 정보를 데이터베이스에 저장하고, 출력 및 설정할 수 있다.

    1. 기기 정보 관리: 
      beaconDataList라는 RxList를 사용하여 등록된 기기의 정보를 저장합니다. 각 기기는 MAC 주소, ID, 층 정보, X좌표, Y좌표, Z좌표 및 닉네임으로 식별됩니다.

    2. 기기 정보 수정: 
      edittingBeaconDataList 함수를 사용하여 비콘의 정보를 수정할 수 있습니다. MAC 주소를 기준으로 해당 비콘의 정보를 업데이트합니다.

    3. 데이터베이스 갱신: 
      beaconDataListUpdated 함수를 사용하여 beaconDataList에 있는 기기 정보를 데이터베이스에 갱신합니다. updateBeaconDataListFromDatabase 함수를 사용하여 데이터베이스에서 기기 정보를 불러와 beaconDataList를 업데이트합니다.

    4. 기기 정보 출력 및 설정: 
      각 기기에 대한 닉네임, ID, 층 정보, X좌표, Y좌표, Z좌표를 출력하고 설정할 수 있는 함수들이 제공됩니다.

    5. 기타 유틸리티 함수: 
      findMACIndex 함수는 주어진 MAC 주소의 인덱스를 반환합니다.  
*/

/* 
    *** 주의! ***
      BeaconController 클래스에 'final beaconController = Get.put(BeaconData())'를 선언하면 안됨
        -> GetX 컨트롤러가 변경사항을 재귀함수 꼴로 무한 호출해서 스택 오버플로우가 발생!
        -> 함수에 local하게 선언하는 것은 가능.
 */

// GetX 라이브러리를 통해 등록된 기기를 관리하는 클래스
class BeaconController extends GetxController {
  /* 등록된 기기 정보 리스트 */
  RxList<RxList<dynamic>> beaconDataList = RxList<RxList<dynamic>>([
    //                       MAC           ID   F  X  Y  Z   Nickname
    RxList<dynamic>(['C8:0F:10:B3:5D:D5', 'ID', 6, 450, 250, 0, 'Test1']),
    RxList<dynamic>(['54:44:A3:EB:E7:E1', 'ID', 6, 345, 363, 0, 'Test2']),
    RxList<dynamic>(['E0:9D:13:86:A9:63', 'ID', 6, 200, 150, 0, 'Test3']),
    RxList<dynamic>(['C4:F3:12:51:AE:21', 'HM1', 0, 0, 0, 0, 'BEACON1']),
    RxList<dynamic>(['BC:6A:29:C3:44:E2', 'HM2', 6, 490, 365, 0, 'BEACON2']),
    RxList<dynamic>(['34:15:13:88:8A:60', 'HM3', 0, 0, 0, 0, 'BEACON3']),
    RxList<dynamic>(['D4:36:39:6F:BA:D5', 'HM4', 0, 0, 0, 0, 'BEACON4']),
    RxList<dynamic>(['F8:30:02:4A:E4:5F', 'HM5', 0, 500, 350, 0, 'BEACON5']),
  ]);

  // beaconDataList가 업데이트 되는지 감지.
  BeaconController() {
    beaconDataList.listen((_) {
      updateDatabaseListFromBeaconDataList();
    });
  }

  // beaconDataList를 수정하는 함수
  void edittingBeaconDataList({
    String? mac,
    String? id,
    int? floor,
    int? x,
    int? y,
    int? z,
    String? nickname,
  }) {
    int index = beaconDataList.indexWhere((data) => data[0] == mac);

    if (index != -1) {
      if (id != null) beaconDataList[index].value[1] = id;
      if (floor != null) beaconDataList[index].value[2] = floor;
      if (x != null) beaconDataList[index].value[3] = x;
      if (y != null) beaconDataList[index].value[4] = y;
      if (z != null) beaconDataList[index].value[5] = z;
      if (nickname != null) beaconDataList[index].value[6] = nickname;
    }
  }

  // beaconDataList에 있는 값들을 데이터베이스에 갱신하는 함수
  void updateDatabaseListFromBeaconDataList() {
    // 데이터베이스 인스턴스 생성
    DatabaseHelper dhHelper = DatabaseHelper.instance;

    // 데이터베이스 클리어
    dhHelper.clearBeaconData();

    // beaconDataList의 각 요소에 대해 데이터베이스에 추가
    for (var data in beaconDataList.value) {
      dhHelper.addDataToDatabase(data);
    }
  }

  // 데이터베이스에서 데이터를 불러와서 beaconDataList를 갱신하는 함수
  Future<void> updateBeaconDataListFromDatabase() async {
    // 데이터베이스 인스턴스 생성
    DatabaseHelper dbHelper = DatabaseHelper.instance;

    // 데이터베이스에서 모든 데이터 가져오기
    List<Map<String, dynamic>> rows = await dbHelper.getAllBeaconData();

    // 데이터베이스에서 가져온 데이터를 beaconDataList에 덮어씌우기
    List<RxList<dynamic>> updatedList = [];
    for (Map<String, dynamic> row in rows) {
      RxList<dynamic> rowData = RxList<dynamic>([
        row['mac'],
        row['beaconId'],
        row['floor'],
        row['x'],
        row['y'],
        row['z'],
        row['nickname']
      ]);
      updatedList.add(rowData);
    }

    // beaconDataList 갱신
    beaconDataList.assignAll(updatedList);
  }

  // beaconDataList에 찾으려는 mac주소의 인덱스를 확인하는 함수
  int findMACIndex(String mac) {
    for (int i = 0; i < beaconDataList.value.length; i++) {
      if (beaconDataList.value[i].isNotEmpty &&
          beaconDataList.value[i].value[0] == mac) {
        return i;
      }
    }
    return -1;
  }

  /* 
      ** 비콘 정보 출력 및 세팅 함수들 ** 
  */

  // 기기 닉네임을 반환하는 함수
  String printBeaconNickname(String mac) {
    int index = findMACIndex(mac);
    String nickname =
        (index == -1) ? 'N/A' : beaconDataList.value[index].value[6];
    return nickname;
  }

  // 기기 닉네임을 설정하는 함수
  void settingBeaconNickname(String mac, String nickname) {
    int index = findMACIndex(mac);
    beaconDataList.value[index].value[6] = nickname;
  }

  // ID를 반환하는 함수
  String printBeaconID(String mac) {
    int index = findMACIndex(mac);
    String beaconID =
        (index == -1) ? 'ID' : beaconDataList.value[index].value[1];
    return beaconID;
  }

  // ID를 설정하는 함수
  void settingBeaconID(String mac, String id) {
    int index = findMACIndex(mac);
    beaconDataList.value[index].value[1] = id;
  }

  // 층 정보를 반환하는 함수
  int printBeaconFloor(String mac) {
    int index = findMACIndex(mac);
    int floor = (index == -1) ? 0 : beaconDataList.value[index].value[2];
    return floor;
  }

  // 층 정보를 설정하는 함수
  void settingBeaconFloor(String mac, int floor) {
    int index = findMACIndex(mac);
    beaconDataList.value[index].value[2] = floor;
  }

  // X좌표를 반환하는 함수
  int printBeaconXaxis(String mac) {
    int index = findMACIndex(mac);
    int x = (index == -1) ? 0 : beaconDataList.value[index].value[3];
    return x;
  }

  // X좌표를 설정하는 함수
  void settingBeaconXaxis(String mac, int x) {
    int index = findMACIndex(mac);
    beaconDataList.value[index].value[3] = x;
  }

  // Y좌표를 반환하는 함수
  int printBeaconYaxis(String mac) {
    int index = findMACIndex(mac);
    int y = (index == -1) ? 0 : beaconDataList.value[index].value[4];
    return y;
  }

  // Y좌표를 설정하는 함수
  void settingBeaconYaxis(String mac, int y) {
    int index = findMACIndex(mac);
    beaconDataList.value[index].value[4] = y;
  }

  // Z좌표를 반환하는 함수
  int printBeaconZaxis(String mac) {
    int index = findMACIndex(mac);
    int z = (index == -1) ? 0 : beaconDataList.value[index].value[5];
    return z;
  }

  // Z좌표를 설정하는 함수
  void settingBeaconZaxis(String mac, int z) {
    int index = findMACIndex(mac);
    beaconDataList.value[index].value[5] = z;
  }
}
