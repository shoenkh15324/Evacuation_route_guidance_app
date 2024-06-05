import 'package:flutter_tts/flutter_tts.dart';

class VoiceGuidance {
  VoiceGuidance();

  final FlutterTts tts = FlutterTts();

  Future<void> speak(String text) async {
    if (text.isNotEmpty) {
      await tts.setLanguage("ko-KR"); // 말하는 언어 선택
      await tts.setSpeechRate(0.5); // 말하는 속도 조절
      await tts.setVolume(1.0); // 볼륨 조절
      await tts.setPitch(1.0); // 말하는 톤 조절
      await tts
          .setVoice({"name": "ko-kr-x-ism-local", "locale": "ko-KR"}); // 음성 선택
      await tts.speak(text); // TTS 출력
    }
  }
}
