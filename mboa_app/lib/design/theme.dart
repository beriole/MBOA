import 'package:flutter/material.dart';

import 'tokens.dart';

/// Police embarquee, declaree dans pubspec.yaml.
const String kMboaFont = 'Inter';

/// Thème Material 3 personnalisé MBOA, aligné sur les maquettes.
///
/// Deux choix structurent ce thème, et tous deux viennent des planches :
///
///  - la couleur **primaire** est l'indigo (identité, navigation, en-têtes) ;
///  - les **boutons d'action** restent verts, comme sur toutes les maquettes.
///
/// Material déduirait du `ColorScheme` un bouton indigo : on force donc le vert
/// dans `filledButtonTheme` plutôt que de tordre le schéma de couleurs.
ThemeData buildMboaTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: MboaColors.indigo600,
    onPrimary: Colors.white,
    primaryContainer: MboaColors.indigo100,
    onPrimaryContainer: MboaColors.indigo700,
    secondary: MboaColors.forest500,
    onSecondary: Colors.white,
    secondaryContainer: MboaColors.forest100,
    onSecondaryContainer: MboaColors.forest900,
    tertiary: MboaColors.ocre500,
    onTertiary: MboaColors.encre900,
    tertiaryContainer: MboaColors.ocre100,
    onTertiaryContainer: MboaColors.encre900,
    error: MboaColors.erreur,
    onError: Colors.white,
    surface: MboaColors.fond,
    onSurface: MboaColors.encre900,
    onSurfaceVariant: MboaColors.encre500,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: MboaColors.fond,
    surfaceContainer: MboaColors.sable100,
    surfaceContainerHigh: MboaColors.sable100,
    outline: MboaColors.sable600,
    outlineVariant: MboaColors.contour,
  );

  // Inter est embarquee dans l'application (pubspec) : aucun telechargement a
  // l'execution, donc un rendu identique et une ouverture rapide sur une
  // connexion faible. Sa couverture des lettres de l'alphabet camerounais
  // (ɓ Ɓ ɛ Ɛ ɔ Ɔ ŋ Ŋ ǝ ə) et des diacritiques tonales a ete verifiee glyphe
  // par glyphe.
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: kMboaFont,
  );
  final text = base.textTheme.apply(
    fontFamily: kMboaFont,
    bodyColor: MboaColors.encre900,
    displayColor: MboaColors.encre900,
  );

  return base.copyWith(
    scaffoldBackgroundColor: MboaColors.fond,
    textTheme: text.copyWith(
      headlineMedium: text.headlineMedium?.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: text.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: text.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: text.bodyLarge?.copyWith(fontSize: 17, height: 26 / 17),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 15, height: 22 / 15),
      bodySmall: text.bodySmall?.copyWith(fontSize: 13, height: 19 / 13),
      labelLarge: text.labelLarge?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: MboaColors.fond,
      foregroundColor: MboaColors.encre900,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: kMboaFont,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: MboaColors.encre900,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        // Vert forêt : c'est la couleur des actions dans toutes les maquettes.
        backgroundColor: MboaColors.forest900,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        // La famille doit etre repetee : un TextStyle sans `fontFamily` retombe
        // sur la police systeme, pas sur celle du theme.
        textStyle: const TextStyle(
          fontFamily: kMboaFont,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        side: const BorderSide(color: MboaColors.sable600),
        foregroundColor: MboaColors.encre900,
        backgroundColor: Colors.white,
        textStyle: const TextStyle(
          fontFamily: kMboaFont,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      // Material dessine un bouton texte sur 40 dp de haut. C'est en dessous du
      // seuil tactile que le projet s'est fixé, et un bouton texte n'a pas de
      // fond pour signaler qu'on l'a manqué : on relève le plancher plutôt que
      // de le rattraper écran par écran.
      style: TextButton.styleFrom(
        foregroundColor: MboaColors.indigo600,
        minimumSize: const Size(kMinTouchTarget, kMinTouchTarget),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: MboaColors.indigo100,
      side: const BorderSide(color: MboaColors.contour),
      labelStyle: const TextStyle(
        fontFamily: kMboaFont,
        fontSize: 14,
        color: MboaColors.encre900,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MboaRadius.xl),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MboaRadius.md),
        borderSide: const BorderSide(color: MboaColors.sable600),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MboaRadius.md),
        borderSide: const BorderSide(color: MboaColors.sable600),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MboaRadius.md),
        borderSide: const BorderSide(color: MboaColors.indigo600, width: 2),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MboaRadius.lg),
        side: const BorderSide(color: MboaColors.contour),
      ),
    ),
    dividerTheme: const DividerThemeData(color: MboaColors.contour, space: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: MboaColors.indigo100,
      elevation: 0,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: kMboaFont,
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w400,
          color: states.contains(WidgetState.selected)
              ? MboaColors.indigo600
              : MboaColors.encre500,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? MboaColors.indigo600
              : MboaColors.encre500,
        ),
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: MboaColors.indigo600,
      unselectedLabelColor: MboaColors.encre500,
      indicatorColor: MboaColors.indigo600,
      dividerColor: MboaColors.contour,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: MboaColors.forest500,
      linearTrackColor: MboaColors.sable100,
    ),
  );
}

/// Style des formes en langue nationale : interligne large pour les tons,
/// jamais en majuscules forcées ni en italique (K2).
TextStyle lexemeStyle(BuildContext context, {double size = 28}) {
  return TextStyle(
    fontFamily: kMboaFont,
    fontSize: size,
    height: 1.45,
    fontWeight: FontWeight.w600,
    color: MboaColors.forest900,
  );
}
