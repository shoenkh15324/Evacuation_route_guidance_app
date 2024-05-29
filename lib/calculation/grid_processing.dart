import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;

class ImageGridProcessor {
  int imageWidth = 850; // 이미지의 가로 길이
  int imageHeight = 500; // 이미지의 세로 길이
  int gridWidth = 10; // 그리드의 가로 길이
  int gridHeight = 10; // 그리드의 세로 길이

  img.Image? background; // 불러올 이미지
  List<List<int>> markedGrid = []; // 마킹된 그리드 리스트
  List<Point<int>> barriers = []; // 장애물 리스트

  ImageGridProcessor();

  // 이미지 로드 메서드
  Future<void> loadImage(String assetPath) async {
    final ByteData data = await rootBundle.load(assetPath);
    img.Image? image = img.decodeImage(Uint8List.view(data.buffer));
    if (image == null) {
      throw Exception("Failed to decode image");
    }
    background = image;
  }

  // 검은색 픽셀을 가진 그리드를 마킹하는 메서드
  void markBlackGrids(img.Image image) {
    int gridCols = imageWidth ~/ gridWidth;
    int gridRows = imageHeight ~/ gridHeight;
    List<List<int>> isMarked =
        List.generate(gridRows, (i) => List.filled(gridCols, 0));

    for (var i = 0; i < imageWidth; i += gridWidth) {
      for (var j = 0; j < imageHeight; j += gridHeight) {
        bool isBlackFound = false;

        for (var ii = 0; ii < gridWidth; ii++) {
          for (var jj = 0; jj < gridHeight; jj++) {
            if (i + ii < image.width && j + jj < image.height) {
              var pixel = image.getPixelSafe(i + ii, j + jj);
              num r = pixel.r;
              num g = pixel.g;
              num b = pixel.b;

              if (r < 128 && g < 128 && b < 128) {
                isMarked[j ~/ gridHeight][i ~/ gridWidth] = 1;
                isBlackFound = true;
                break;
              }
            }
          }
          if (isBlackFound) break;
        }
      }
    }
    //print('markGridsWithBlack: $isMarked');
    markedGrid = isMarked;
  }

  // 마킹된 그리드를 찾는 메서드
  void findMarkedGrid(List<List<int>> isMarked) {
    List<Point<int>> isBlacked = [];

    for (var i = 0; i < isMarked.length; i++) {
      for (var j = 0; j < isMarked[i].length; j++) {
        if (isMarked[i][j] != 0) {
          isBlacked.add(Point<int>(j, i));
        }
      }
    }
    //print(isBlacked);
    barriers = isBlacked;
  }

  // 픽셀 좌표를 그리드 좌표로 변환하는 메서드
  Point<int> pixelToGrid(Point<int> pixel) {
    int gridX = (pixel.x / gridWidth).floor();
    int gridY = (pixel.y / gridHeight).floor();

    //print('pixelToGrid: $gridX, $gridY');
    return Point<int>(gridX, gridY);
  }

  // 그리드 좌표를 픽셀 좌표로 변환하는 메서드
  Point<int> gridToPixel(Point<int> grid) {
    int pixelX = grid.x * gridWidth + gridWidth ~/ 2;
    int pixelY = grid.y * gridHeight + gridHeight ~/ 2;

    return Point<int>(pixelX, pixelY);
  }

  // 그리드 처리 메서드
  Future<void> gridProcessing(String assetPath) async {
    await loadImage(assetPath);
    markBlackGrids(background!);
    findMarkedGrid(markedGrid);
  }
}
