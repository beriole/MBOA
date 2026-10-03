import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'design/theme.dart';

void main() {
  runApp(const ProviderScope(child: MboaApp()));
}

class MboaApp extends ConsumerWidget {
  const MboaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'MBOA',
      debugShowCheckedModeBanner: false,
      theme: buildMboaTheme(),
      routerConfig: ref.watch(routerProvider),
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
