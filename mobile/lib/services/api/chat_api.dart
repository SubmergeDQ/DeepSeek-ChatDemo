import '../../models/models.dart';
import 'api_types.dart';
import 'anthropic_api.dart';
import 'deepseek_api.dart';
import 'gemini_api.dart';
import 'openai_api.dart';

abstract class ChatApi {
  Stream<ChatEvent> stream(ChatRequest request, CancelToken token);

  Future<List<ModelInfo>> fetchModels(ProviderConfig provider);

  /// 使用服务商的文件接口上传附件。不支持时抛出 [ApiException]。
  Future<Attachment> uploadAttachment(
    ProviderConfig provider,
    Attachment attachment,
    CancelToken token,
  ) async {
    throw ApiException('当前服务商不支持文件上传');
  }

  /// 语音转写。不支持时抛出 [ApiException]。
  Future<String> transcribe(
    ProviderConfig provider,
    String filePath,
    CancelToken token,
  ) async {
    throw ApiException('当前服务商不支持语音识别');
  }
}

ChatApi apiFor(ProviderType type) {
  switch (type) {
    case ProviderType.deepseek:
      return DeepSeekApi();
    case ProviderType.openai:
      return OpenAiApi();
    case ProviderType.anthropic:
      return AnthropicApi();
    case ProviderType.gemini:
      return GeminiApi();
  }
}

/// 历史消息里的文本附件统一拼进正文。
String appendTextAttachments(String text, List<Attachment> attachments) {
  final buffer = StringBuffer(text);
  for (final attachment in attachments) {
    if (attachment.isImage) continue;
    final content = attachment.textContent;
    if (content == null || content.trim().isEmpty) continue;
    buffer.writeln('\n\n[文件：${attachment.name}]');
    buffer.writeln('```');
    buffer.writeln(content);
    buffer.writeln('```');
  }
  return buffer.toString().trim();
}

String displayStopReason(String? stopReason, {required bool zh}) {
  switch (stopReason) {
    case 'max_tokens':
      return zh ? '已达到最大输出长度' : 'Maximum output length reached';
    case 'refusal':
      return zh ? '模型拒绝了本次请求' : 'The model refused this request';
    case 'safety':
      return zh ? '内容被安全策略拦截' : 'Blocked by safety policy';
    default:
      return '';
  }
}
