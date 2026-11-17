import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// 录音 + 系统朗读。
class SpeechService {
  final AudioRecorder _recorder = AudioRecorder();
  final FlutterTts _tts = FlutterTts();

  bool _recording = false;
  String? _recordPath;
  String? speakingMessageId;
  void Function(String? messageId)? onSpeakingChanged;

  bool get isRecording => _recording;
  String? get speakingId => speakingMessageId;

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
    return true;
  }

  Future<String?> stopRecording() async {
    if (!_recording) return null;
    _recording = false;
    final path = await _recorder.stop();
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
    speakingMessageId = messageId;
    onSpeakingChanged?.call(messageId);
    try {
      await _tts.setLanguage(zh ? 'zh-CN' : 'en-US');
      await _tts.setSpeechRate(rate.clamp(0.2, 0.9));
      await _tts.setPitch(1.0);
      _tts.setCompletionHandler(() {
        speakingMessageId = null;
        onSpeakingChanged?.call(null);
        onDone();
      });
      _tts.setCancelHandler(() {
        speakingMessageId = null;
        onSpeakingChanged?.call(null);
      });
      _tts.setErrorHandler((_) {
        speakingMessageId = null;
        onSpeakingChanged?.call(null);
      });
      await _tts.speak(text);
    } catch (_) {
      speakingMessageId = null;
      onSpeakingChanged?.call(null);
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {
      // ignore
    }
    if (speakingMessageId != null) {
      speakingMessageId = null;
      onSpeakingChanged?.call(null);
    }
  }

  Future<void> dispose() async {
    await stopSpeaking();
    try {
      await _recorder.dispose();
    } catch (_) {
      // ignore
    }
  }
}
