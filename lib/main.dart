import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home_shell.dart';
import 'screens/lock.dart';
import 'store.dart';
import 'theme.dart';
import 'ui_keys.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  await store.load();
  runApp(VieTingApp(store: store));
}

class VieTingApp extends StatelessWidget {
  final AppStore store;
  const VieTingApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) => MaterialApp(
          title: 'VieTing',
          scaffoldMessengerKey: messengerKey,
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: store.dark ? ThemeMode.dark : ThemeMode.light,
          locale: const Locale('vi'),
          supportedLocales: const [Locale('vi'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const LockGate(child: HomeShell()),
        ),
      ),
    );
  }
}
