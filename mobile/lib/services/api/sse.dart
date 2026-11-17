import 'dart:async';
import 'dart:convert';

class SseEvent {
  const SseEvent({this.event, required this.data});

  final String? event;
  final String data;
}

/// 解析 text/event-stream，按空行分帧；忽略注释与无法识别的字段。
Stream<SseEvent> parseSse(Stream<List<int>> bytes) async* {
  String? eventName;
  final dataLines = <String>[];
  await for (final line in bytes.transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.isEmpty) {
      if (dataLines.isNotEmpty) {
        yield SseEvent(event: eventName, data: dataLines.join('\n'));
        dataLines.clear();
      }
      eventName = null;
      continue;
    }
    if (line.startsWith(':')) continue;
    if (line.startsWith('event:')) {
      eventName = line.substring(6).trim();
      continue;
    }
    if (line.startsWith('data:')) {
      var data = line.substring(5);
      if (data.startsWith(' ')) data = data.substring(1);
      dataLines.add(data);
    }
  }
  if (dataLines.isNotEmpty) {
    yield SseEvent(event: eventName, data: dataLines.join('\n'));
  }
}
