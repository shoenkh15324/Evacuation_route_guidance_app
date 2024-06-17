import 'dart:math';

class FloorInfo {
  FloorInfo();

  List<dynamic> settingFloorInfo(int floor) {
    List<dynamic> floorInfoList = [];
    String floorImagePath = '';
    List<Point> endPoint = [];

    switch (floor) {
      case 1:
        floorImagePath = 'assets/images/1st_floor.png';
        endPoint = [const Point<int>(553, 263), const Point<int>(184, 20)];
        break;
      case 2:
        floorImagePath = 'assets/images/2nd_floor.png';
        endPoint = [const Point<int>(553, 263), const Point<int>(184, 20)];
        break;
      case 3:
        floorImagePath = 'assets/images/3rd_floor.png';
        endPoint = [const Point<int>(428, 263), const Point<int>(184, 20)];
        break;
      case 4:
        floorImagePath = 'assets/images/4th_floor.png';
        endPoint = [const Point<int>(553, 263), const Point<int>(184, 20)];
        break;
      case 5:
        floorImagePath = 'assets/images/5th_floor.png';
        endPoint = [const Point<int>(553, 263), const Point<int>(184, 20)];
        break;
      case 6:
        floorImagePath = 'assets/images/6th_floor.png';
        endPoint = [const Point<int>(553, 263), const Point<int>(184, 20)];
        break;
      default:
        floorImagePath = 'assets/images/6th_floor.png';
        endPoint = [const Point<int>(553, 263), const Point<int>(184, 20)];
        break;
    }

    floorInfoList.add(floorImagePath);
    floorInfoList.add(endPoint);

    return floorInfoList;
  }
}
