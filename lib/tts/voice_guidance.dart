import 'package:flutter_tts/flutter_tts.dart';

class VoiceGuidance {
  VoiceGuidance();

  final FlutterTts tts = FlutterTts();

  /* 언어 설정
    한국어    =   "ko-KR"
    일본어    =   "ja-JP"
    영어      =   "en-US"
    중국어    =   "zh-CN"
    프랑스어  =   "fr-FR"
  */

  /* 음성 설정
    한국어 여성 {"name": "ko-kr-x-ism-local", "locale": "ko-KR"}
	  영어 여성 {"name": "en-us-x-tpf-local", "locale": "en-US"}
    일본어 여성 {"name": "ja-JP-language", "locale": "ja-JP"}
    중국어 여성 {"name": "cmn-cn-x-ccc-local", "locale": "zh-CN"}
    중국어 남성 {"name": "cmn-cn-x-ccd-local", "locale": "zh-CN"}
  */


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
