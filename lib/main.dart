import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'package:mytime/features/app_blocking_new/providers/app_blocking_provider_v2.dart';
import 'package:mytime/core/services/notification_service.dart';
import 'package:mytime/core/services/storage_service.dart';
import 'package:mytime/core/services/tts_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytime/core/config/app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize core services
    final storageService = StorageService();
    await storageService.init();

    final ttsService = TTSService();
    await ttsService.init();
    
    final notificationService = NotificationService();
    await notificationService.init(ttsService);

    runApp(
      MultiProvider(
        providers: [

          ChangeNotifierProvider(
            create: (context) => AppBlockingProviderV2(),
          ),
        ],
        child: const MyTimeApp(),
      ),
    );
  } catch (e, stackTrace) {
    debugPrint('Error initializing MyTime app: $e');
    debugPrint('Stack trace: $stackTrace');
    
    // Show error screen
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to initialize app',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    e.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyTimeApp extends StatefulWidget {
  const MyTimeApp({super.key});

  @override
  State<MyTimeApp> createState() => _MyTimeAppState();
}

class _MyTimeAppState extends State<MyTimeApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProviders();
    });
  }
  
  void _initializeProviders() {
    try {
      final appBlockingProvider = Provider.of<AppBlockingProviderV2>(context, listen: false);
      appBlockingProvider.initialize();
    } catch (e) {
      debugPrint('Error initializing providers: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MyTime',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF6B35),
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
      ),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'),
      ],
      routerConfig: AppRoutes.router,
    );
  }
}

class MyTimeHome extends StatelessWidget {
  const MyTimeHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MyTime'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.block,
              size: 80,
              color: Color(0xFFFF6B35),
            ),
            const SizedBox(height: 16),
            Text(
              'MyTime',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'App Blocking & Usage Limiter',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Migration in progress...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
