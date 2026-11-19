import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'data/conversation_repository.dart';
import 'data/settings_store.dart';
import 'services/backup_service.dart';
import 'services/files/attachment_service.dart';
import 'services/speech/speech_service.dart';
import 'state/chat_controller.dart';
import 'ui/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsStore();
  await settings.load();
  final speech = SpeechService();
  final attachmentService = AttachmentService();
  final chat = ChatController(
    settings: settings,
    repository: ConversationRepository(),
    attachmentService: attachmentService,
    speech: speech,
  );
  try {
    await chat.init();
  } catch (error, stack) {
    debugPrint('数据库初始化失败：$error\n$stack');
  }
  chat.newConversation();
  runApp(
    DeepChatApp(
      settings: settings,
      chat: chat,
      speech: speech,
      attachmentService: attachmentService,
      backupService: BackupService(),
    ),
  );
}

class DeepChatApp extends StatelessWidget {
  const DeepChatApp({
    super.key,
    required this.settings,
    required this.chat,
    required this.speech,
    required this.attachmentService,
    required this.backupService,
  });

  final SettingsStore settings;
  final ChatController chat;
  final SpeechService speech;
  final AttachmentService attachmentService;
  final BackupService backupService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsStore>.value(value: settings),
        ChangeNotifierProvider<ChatController>.value(value: chat),
        ChangeNotifierProvider<SpeechService>.value(value: speech),
        Provider<AttachmentService>.value(value: attachmentService),
        Provider<BackupService>.value(value: backupService),
      ],
      child: Consumer<SettingsStore>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'DeepChat',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: settings.themeMode,
            locale: settings.zh ? const Locale('zh', 'CN') : const Locale('en', 'US'),
            supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const HomePage(),
          );
        },
      ),
    );
  }
}
