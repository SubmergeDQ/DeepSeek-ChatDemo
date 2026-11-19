import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// 录音 + 系统朗读。
class SpeechService extends ChangeNotifier {
  final AudioRecorder _recorder = AudioRecorder();
  final FlutterTts _tts = FlutterTts();

  bool _recording = false;
  String? _recordPath;
  String? _speakingMessageId;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  final ValueNotifier<double> _micLevel = ValueNotifier<double>(0);

  bool get isRecording => _recording;
  String? get speakingId => _speakingMessageId;

  /// 0~1 的实时麦克风音量，用于录音波形动画。
  ValueListenable<double> get micLevel => _micLevel;

  void _setSpeaking(String? id) {
    if (_speakingMessageId == id) return;
    _speakingMessageId = id;
    notifyListeners();
  }

  Future<bool> startRecording() async {
    if (_recording) return true;
    final granted = await _recorder.hasPermission();
    if (!granted) return false;
    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, 'rec_${DateTime.now().millisecondsSinceEpoch}.wav');
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    _recordPath = path;
    _recording = true;
    _micLevel.value = 0;
    try {
      await _amplitudeSubscription?.cancel();
      _amplitudeSubscription = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 80))
          .listen(
        (amplitude) {
          final db = amplitude.current;
          _micLevel.value = db >= 0 ? 0.12 : ((db + 60) / 60).clamp(0.0, 1.0);
        },
        onError: (_) {},
      );
    } catch (_) {
      // 部分平台不支持实时振幅，保持 0，波形仍会做基础动画。
    }
    return true;
  }

  Future<String?> stopRecording() async {
    if (!_recording) return null;
    _recording = false;
    final path = await _recorder.stop();
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    _micLevel.value = 0;
    final result = path ?? _recordPath;
    _recordPath = null;
    return result;
  }

  Future<void> cancelRecording() async {
    if (!_recording) return;
    _recording = false;
    try {
      await _recorder.cancel();
    } catch (_) {
      // ignore
    }
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    _micLevel.value = 0;
    final path = _recordPath;
    _recordPath = null;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<void> speak(
    String text, {
    required String messageId,
    required bool zh,
    required double rate,
    required void Function() onDone,
  }) async {
    await stopSpeaking();
    _setSpeaking(messageId);
    try {
      await _tts.setLanguage(zh ? 'zh-CN' : 'en-US');
      await _tts.setSpeechRate(rate.clamp(0.2, 0.9));
      await _tts.setPitch(1.0);
      _tts.setCompletionHandler(() {
        _setSpeaking(null);
        onDone();
      });
      _tts.setCancelHandler(() => _setSpeaking(null));
      _tts.setErrorHandler((_) => _setSpeaking(null));
      await _tts.speak(text);
    } catch (_) {
      _setSpeaking(null);
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {
      // ignore
    }
    _setSpeaking(null);
  }

  @override
  void dispose() {
    _speakingMessageId = null;
    _amplitudeSubscription?.cancel();
    _micLevel.dispose();
    _tts.stop().catchError((_) {});
    _recorder.dispose().catchError((_) {});
    super.dispose();
  }
}
