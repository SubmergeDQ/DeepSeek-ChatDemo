/// 轻量中英文文案。默认跟随系统语言。
class L10n {
  const L10n(this.zh);

  final bool zh;

  String get appName => 'DeepChat';
  String get newChat => zh ? '新对话' : 'New chat';
  String get currentModel => zh ? '当前模型' : 'Current model';
  String get localUser => zh ? '本地用户' : 'Local user';
  String get aiDisclaimer => zh ? '回答由 AI 生成，仅供参考' : 'AI-generated content, for reference only';
  String get searchSessions => zh ? '搜索对话内容…' : 'Search chats…';
  String get chat => zh ? '对话' : 'Chat';
  String get settings => zh ? '设置' : 'Settings';
  String get noSessions => zh ? '暂无对话' : 'No chats yet';
  String get today => zh ? '今天' : 'Today';
  String get yesterday => zh ? '昨天' : 'Yesterday';
  String get previous7Days => zh ? '近 7 天' : 'Previous 7 days';
  String get previous30Days => zh ? '近 30 天' : 'Previous 30 days';
  String get earlier => zh ? '更早' : 'Earlier';
  String get delete => zh ? '删除' : 'Delete';
  String get rename => zh ? '重命名' : 'Rename';
  String get cancel => zh ? '取消' : 'Cancel';
  String get confirm => zh ? '确定' : 'Confirm';
  String get copy => zh ? '复制' : 'Copy';
  String get copied => zh ? '已复制' : 'Copied';
  String get regenerate => zh ? '重新生成' : 'Regenerate';
  String get share => zh ? '分享' : 'Share';
  String get readAloud => zh ? '朗读' : 'Read aloud';
  String get stopReading => zh ? '停止朗读' : 'Stop reading';
  String get like => zh ? '有帮助' : 'Helpful';
  String get dislike => zh ? '没帮助' : 'Not helpful';
  String get edit => zh ? '编辑' : 'Edit';
  String get save => zh ? '保存' : 'Save';
  String get done => zh ? '完成' : 'Done';
  String get retry => zh ? '重试' : 'Retry';
  String get stop => zh ? '停止' : 'Stop';
  String get send => zh ? '发送' : 'Send';
  String get attach => zh ? '附件' : 'Attach';
  String get photo => zh ? '图片' : 'Photo';
  String get file => zh ? '文件' : 'File';
  String get voice => zh ? '语音' : 'Voice';
  String get recording => zh ? '正在录音' : 'Recording';
  String get recordingHint => zh ? '点击结束并转写' : 'Tap to stop and transcribe';
  String get transcribing => zh ? '正在识别…' : 'Transcribing…';
  String get micPermissionDenied => zh ? '需要麦克风权限才能语音输入' : 'Microphone permission is required';
  String get deepThink => zh ? '深度思考' : 'DeepThink';
  String get webSearch => zh ? '智能搜索' : 'Smart search';
  String get thinking => zh ? '思考中…' : 'Thinking…';
  String get thoughtFor => zh ? '已思考' : 'Thought for';
  String get thoughtSeconds => zh ? '秒' : 's';
  String thoughtForSeconds(int seconds) =>
      zh ? '已思考（用时 $seconds 秒）' : 'Thought for ${seconds}s';
  String get searchInProgress => zh ? '正在搜索…' : 'Searching…';
  String get readLinkInProgress => zh ? '正在阅读链接…' : 'Reading link…';
  String get sources => zh ? '参考来源' : 'Sources';
  String get searchResults => zh ? '搜索结果' : 'Search results';
  String webPagesCount(int count) => zh ? '$count 个网页' : '$count web pages';
  String get browsePages => zh ? '浏览页面' : 'Browse pages';
  String get searchedPages => zh ? '搜索到' : 'Found';
  String get checkForUpdates => zh ? '检查更新' : 'Check for updates';
  String get currentVersion => zh ? '当前版本' : 'Current version';
  String get alreadyLatest => zh ? '已是最新版本' : 'Already up to date';
  String get newVersionFound => zh ? '发现新版本' : 'New version available';
  String get downloadUpdate => zh ? '下载更新' : 'Download update';
  String get checkUpdateFailed => zh ? '检查更新失败' : 'Update check failed';
  String get serviceAgreement => zh ? '服务协议' : 'Terms of service';
  String get helpFeedback => zh ? '帮助与反馈' : 'Help & feedback';
  String get openRepository => zh ? '开源仓库' : 'Repository';
  String get apiAndModels => zh ? '账户与模型' : 'Account & models';
  String get appSection => zh ? '应用' : 'App';
  String get voiceSection => zh ? '语音' : 'Voice';
  String get aboutSection => zh ? '关于' : 'About';
  String get dataSection => zh ? '数据' : 'Data';
  String get expand => zh ? '展开' : 'Expand';
  String get collapse => zh ? '收起' : 'Collapse';
  String get welcomeTitle => zh ? '有什么可以帮你的？' : 'How can I help you?';
  String get welcomeSubtitle => zh
      ? '支持自定义 API，随时切换不同模型'
      : 'Bring your own API key and switch models anytime';
  String get suggestion1 => zh ? '解释一下量子纠缠' : 'Explain quantum entanglement';
  String get suggestion2 => zh ? '帮我写一封请假邮件' : 'Draft a leave request email';
  String get suggestion3 => zh ? '用 Python 实现快速排序' : 'Implement quicksort in Python';
  String get suggestion4 => zh ? '制定一周健身计划' : 'Make a one-week workout plan';
  String get inputHint => zh ? '发消息或按住说话' : 'Message or hold to talk';
  String get apiKeyRequired => zh ? '请先在设置中配置 API Key' : 'Please configure an API key in Settings';
  String get goSettings => zh ? '去设置' : 'Open settings';
  String get provider => zh ? '服务商' : 'Provider';
  String get providers => zh ? '模型服务商' : 'Model providers';
  String get addProvider => zh ? '添加服务商' : 'Add provider';
  String get editProvider => zh ? '编辑服务商' : 'Edit provider';
  String get providerName => zh ? '名称' : 'Name';
  String get baseUrl => zh ? '接口地址' : 'Base URL';
  String get apiKey => zh ? 'API Key' : 'API Key';
  String get apiKeyHint => zh ? '粘贴你的 API Key' : 'Paste your API key';
  String get apiKeyStoredLocally => zh
      ? 'API Key 仅保存在本机，不会上传到其他地方。'
      : 'Your API key is stored only on this device.';
  String get models => zh ? '模型' : 'Models';
  String get addModel => zh ? '添加模型' : 'Add model';
  String get modelId => zh ? '模型 ID' : 'Model ID';
  String get modelName => zh ? '显示名称' : 'Display name';
  String get fetchModels => zh ? '获取模型列表' : 'Fetch models';
  String get fetchingModels => zh ? '正在获取…' : 'Fetching…';
  String get modelsFetched => zh ? '模型列表已更新' : 'Models updated';
  String get builtinProvider => zh ? '内置服务商' : 'Built-in provider';
  String get deleteProvider => zh ? '删除服务商' : 'Delete provider';
  String get deleteProviderConfirm => zh ? '确定删除该服务商及其 API Key？' : 'Delete this provider and its API key?';
  String get defaultModel => zh ? '默认模型' : 'Default model';
  String get appearance => zh ? '外观' : 'Appearance';
  String get theme => zh ? '主题' : 'Theme';
  String get themeSystem => zh ? '跟随系统' : 'System';
  String get themeLight => zh ? '浅色' : 'Light';
  String get themeDark => zh ? '深色' : 'Dark';
  String get language => zh ? '语言' : 'Language';
  String get languageSystem => zh ? '跟随系统' : 'System';
  String get general => zh ? '通用' : 'General';
  String get data => zh ? '数据' : 'Data';
  String get exportData => zh ? '导出对话' : 'Export chats';
  String get importData => zh ? '导入对话' : 'Import chats';
  String get importConfirm => zh
      ? '导入将替换本机全部对话，是否继续？'
      : 'Importing will replace all chats on this device. Continue?';
  String get importSuccess => zh ? '导入成功' : 'Import complete';
  String get importFailed => zh ? '导入失败，文件格式不正确' : 'Import failed: invalid file';
  String get exportFailed => zh ? '导出失败' : 'Export failed';
  String get clearAll => zh ? '删除所有对话' : 'Delete all chats';
  String get clearAllConfirm => zh
      ? '将删除本机全部对话，且无法恢复。确定继续？'
      : 'All chats on this device will be deleted permanently. Continue?';
  String get about => zh ? '关于' : 'About';
  String get aboutText => zh
      ? 'DeepChat 是一个本地优先的多模型聊天客户端。你可以填写自己的 API Key，接入 DeepSeek、OpenAI、Anthropic、Gemini 或任意 OpenAI 兼容服务。'
      : 'DeepChat is a local-first multi-model chat client. Use your own API keys with DeepSeek, OpenAI, Anthropic, Gemini, or any OpenAI-compatible service.';
  String get version => zh ? '版本' : 'Version';
  String get disclaimer => zh
      ? '本应用与深度求索公司无关联。模型输出由对应服务商提供，请自行核对重要信息。'
      : 'This app is not affiliated with DeepSeek. Model output is provided by your chosen provider.';
  String get notSupported => zh ? '当前模型不支持' : 'Not supported by this model';
  String get selectModel => zh ? '选择模型' : 'Select model';
  String get systemPrompt => zh ? '系统提示词' : 'System prompt';
  String get systemPromptHint => zh ? '留空则使用默认设置' : 'Leave empty to use the default';
  String get testConnection => zh ? '测试连接' : 'Test connection';
  String get connectionOk => zh ? '连接成功' : 'Connected';
  String get connectionFailed => zh ? '连接失败' : 'Connection failed';
  String get copyFailed => zh ? '复制失败' : 'Copy failed';
  String get shareFailed => zh ? '分享失败' : 'Share failed';
  String get voiceFailed => zh ? '语音识别失败' : 'Speech recognition failed';
  String get voiceTooShort => zh ? '说话时间太短' : 'Recording too short';
  String get attachments => zh ? '附件' : 'Attachments';
  String get attachmentTooLarge => zh ? '文件过大（单个最大 20 MB）' : 'File too large (max 20 MB each)';
  String get unsupportedFile => zh
      ? '该服务商不支持此文件类型，请改用图片或文本文件'
      : 'This provider does not support this file type. Use images or text files.';
  String get uploadFailed => zh ? '附件上传失败' : 'Attachment upload failed';
  String get generating => zh ? '生成中' : 'Generating';
  String get errorOccurred => zh ? '出错了' : 'Something went wrong';
  String get deleteConversationConfirm => zh ? '确定删除此对话？' : 'Delete this chat?';
  String get emptyMessage => zh ? '请输入内容' : 'Type something first';
  String get stopGenerating => zh ? '停止生成' : 'Stop generating';
  String get maxTokensReached => zh ? '已达到最大输出长度' : 'Maximum output length reached';
  String get continueGeneration => zh ? '继续生成' : 'Continue';
  String get variantCount => zh ? '切换版本' : 'Switch version';
  String get noApiKeyForProvider => zh
      ? '请先为当前服务商填写 API Key'
      : 'Add an API key for the current provider';
  String get configureProvider => zh ? '配置服务商' : 'Configure provider';
  String get customProvider => zh ? '自定义服务商' : 'Custom provider';
  String get openaiCompatible => zh ? 'OpenAI 兼容' : 'OpenAI-compatible';
  String get selectProviderType => zh ? '接口类型' : 'API type';
  String get providerType => zh ? '接口类型' : 'API type';
  String get searchModelsPlaceholder => zh ? '搜索模型' : 'Search models';
  String get noModels => zh ? '暂无模型，请添加或在编辑页获取列表' : 'No models yet. Add one or fetch the list.';
  String get newChatTitle => zh ? '新对话' : 'New chat';
  String get deleteMessage => zh ? '删除' : 'Delete';
  String get editMessageHint => zh
      ? '编辑后将重新生成回复，此消息之后的对话会被移除。'
      : 'Editing resends this message and removes everything after it.';
  String get reasoningContent => zh ? '思考过程' : 'Reasoning';
  String get searchEmptyHint => zh ? '输入关键词筛选对话' : 'Filter chats by keyword';
  String get settingsSaved => zh ? '已保存' : 'Saved';
  String get modelListEmpty => zh ? '模型列表为空' : 'Model list is empty';
  String get loading => zh ? '加载中…' : 'Loading…';
  String get attachmentTextTruncated => zh ? '文本过长，已截断' : 'Text too long, truncated';
  String get continueHint => zh ? '已停止，可继续生成' : 'Stopped. You can continue.';
  String get copyMarkdown => zh ? '复制 Markdown' : 'Copy Markdown';
  String get plainText => zh ? '纯文本' : 'Plain text';
  String get openLinkFailed => zh ? '无法打开链接' : 'Could not open link';
  String get chooseFromGallery => zh ? '从相册选择' : 'Choose photo';
  String get chooseFile => zh ? '选择文件' : 'Choose file';
  String get searchProvider => zh ? '搜索服务商' : 'Search provider';
  String get defaultProvider => zh ? '默认服务商' : 'Default provider';
  String get deleteModel => zh ? '删除模型' : 'Remove model';
  String get selectProvider => zh ? '选择服务商' : 'Select provider';
  String get brandSubtitle => zh ? '多模型 AI 助手' : 'Multi-model AI assistant';
}
