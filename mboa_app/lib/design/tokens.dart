import 'package:flutter/material.dart';

/// Jetons du design system MBOA (livrable K), alignés sur les maquettes
/// (lots 3 à 12, septembre 2026).
///
/// La direction visuelle des maquettes combine trois familles :
///
///  - **indigo → violet** pour l'identité, les en-têtes et la navigation ;
///  - **vert forêt** pour les actions principales, qui restent vertes dans
///    toutes les planches ;
///  - **or** pour les moments de récompense et les appels à commencer.
///
/// Les contrastes indiqués ont été mesurés (WCAG 2.2), pas estimés. Ils le sont
/// contre le fond d'écran (`fond`) ou contre le blanc des cartes, selon l'usage
/// réel du jeton.
abstract final class MboaColors {
  // --- Identité : indigo et violet -------------------------------------
  // Les en-têtes des maquettes vont d'un indigo profond à un violet.
  static const indigo700 = Color(0xFF4338CA); // blanc dessus : 7,90:1
  static const indigo600 = Color(0xFF4F46E5); // blanc dessus : 6,29:1
  static const indigo500 = Color(0xFF6366F1);
  static const violet600 = Color(0xFF7C3AED); // blanc dessus : 5,70:1
  static const indigo100 = Color(0xFFEDE9FE); // indigo600 dessus : 5,30:1

  /// Dégradé des en-têtes. Les deux extrémités portent du texte blanc à plus
  /// de 5,7:1 : un dégradé plus clair passerait sous le seuil.
  static const headerGradient = [indigo600, violet600];

  // --- Action : vert forêt ---------------------------------------------
  static const forest900 = Color(0xFF0F4C3A); // blanc dessus : 9,93:1
  static const forest700 = Color(0xFF145C43); // blanc dessus : 7,95:1
  static const forest500 = Color(0xFF1B7A57); // blanc dessus : 5,29:1
  static const forest300 = Color(0xFF5FAE8E);
  static const forest100 = Color(0xFFD9F2E6); // forest900 dessus : 8,41:1

  // --- Récompense : or --------------------------------------------------
  static const or = Color(0xFFF5B800); // encre900 dessus : 10,05:1
  static const ocre500 = Color(0xFFD99A16);
  static const ocre400 = Color(0xFFE9B33D);
  static const ocre100 = Color(0xFFFEF3C7);

  // --- Terre cuite : artisanat, déclarations non vérifiées --------------
  static const terre700 = Color(0xFFC2410C); // #FFEDD5 dessous : 4,52:1
  static const terre100 = Color(0xFFFFEDD5);

  // --- Fonds ------------------------------------------------------------
  /// Fond des écrans. Neutre très clair, comme dans les maquettes.
  static const fond = Color(0xFFF8F9FB);

  /// Conservé sous son ancien nom : de nombreux écrans le référencent.
  static const ivoire = fond;

  /// Surface secondaire (encarts, pastilles, blocs d'information).
  static const sable100 = Color(0xFFF1F3F9);

  /// Bordure porteuse de sens (bouton secondaire, champ) : 3,01:1.
  static const sable600 = Color(0xFF8A90A6);

  /// Bordure purement décorative (séparation de cartes).
  static const contour = Color(0xFFE4E7F0);

  // --- Texte ------------------------------------------------------------
  static const encre900 = Color(0xFF111827); // 16,84:1 sur le fond
  static const encre500 = Color(0xFF5B6478); // 5,63:1
  static const encre400 = Color(0xFF8A90A6); // 3,01:1 — tertiaire uniquement

  // --- Feedback ---------------------------------------------------------
  static const succes = Color(0xFF15803D);
  static const erreur = Color(0xFFDC2626);
  static const info = Color(0xFF2563EB);
}

/// Les sections de l'application, chacune avec sa couleur.
///
/// L'application était uniformément blanche : toutes les pages partageaient le
/// même fond neutre et le même dégradé indigo. On ne savait pas où l'on était.
/// Chaque section porte donc désormais son propre dégradé d'en-tête et son fond
/// légèrement teinté — la couleur devient un repère, pas une décoration.
///
/// **Tous les contrastes ci-dessous sont mesurés (WCAG 2.2), pas estimés.** Les
/// deux extrémités de chaque dégradé portent du texte blanc à 4,5:1 au moins, et
/// chaque fond teinté porte `encre900` à plus de 16:1 et `encre500` à plus de
/// 5,4:1. Un candidat a été écarté à ce titre : la terre cuite `#DC5A18` ne
/// donnait que 3,81:1 sous du blanc.
enum MboaSection {
  /// Indigo → violet : l'identité. C'est le dégradé des maquettes.
  accueil(
    debut: Color(0xFF4F46E5), // blanc dessus : 6,29:1
    fin: Color(0xFF7C3AED), // blanc dessus : 5,70:1
    fond: Color(0xFFF5F4FF), // encre900 : 16,28:1
    accent: Color(0xFF4F46E5),
  ),

  /// Teal → vert : la progression, la pousse. Vert comme les actions.
  apprendre(
    debut: Color(0xFF0F766E), // blanc dessus : 5,47:1
    fin: Color(0xFF15803D), // blanc dessus : 5,02:1
    fond: Color(0xFFF1FAF6), // encre900 : 16,68:1
    accent: Color(0xFF0F766E),
  ),

  /// Violet → rose : le patrimoine. Le plus chaud des cinq.
  culture(
    debut: Color(0xFF6D28D9), // blanc dessus : 7,10:1
    fin: Color(0xFFBE185D), // blanc dessus : 6,04:1
    fond: Color(0xFFFBF4FA), // encre900 : 16,41:1
    accent: Color(0xFF6D28D9),
  ),

  /// Orange → rose : le marché, la terre cuite et le tissu.
  boutique(
    debut: Color(0xFFC2410C), // blanc dessus : 5,18:1
    fin: Color(0xFFDB2777), // blanc dessus : 4,60:1
    fond: Color(0xFFFFF7F2), // encre900 : 16,76:1
    accent: Color(0xFFC2410C),
  ),

  /// Bleu → cyan : le compte, plus calme que le reste.
  profil(
    debut: Color(0xFF1D4ED8), // blanc dessus : 6,70:1
    fin: Color(0xFF0E7490), // blanc dessus : 5,36:1
    fond: Color(0xFFF2F7FE), // encre900 : 16,48:1
    accent: Color(0xFF1D4ED8),
  ),

  /// Ardoise → indigo profond : l'arrière-boutique.
  ///
  /// Ce n'est pas une sixième couleur de plus dans la ronde : c'est la
  /// *seule* couleur de l'espace d'administration, et elle est volontairement
  /// hors de la gamme des cinq précédentes. Les cinq sections publiques sont
  /// claires et vives parce qu'elles disent *où l'on est* dans un parcours
  /// qu'on choisit ; la console, elle, n'est pas un lieu de parcours, c'est un
  /// outil. Elle emprunte donc l'indigo profond de la barre de navigation —
  /// la couleur du châssis de l'application — pour qu'on ne confonde jamais
  /// un écran d'administration avec un écran d'apprenant.
  administration(
    debut: Color(0xFF1E293B), // blanc dessus : 14,47:1
    fin: Color(0xFF3730A3), // blanc dessus : 10,03:1
    fond: Color(0xFFF1F4F9), // encre900 : 16,11:1 · encre500 : 5,47:1
    accent: Color(0xFF3730A3), // sur blanc : 10,03:1
  );

  const MboaSection({
    required this.debut,
    required this.fin,
    required this.fond,
    required this.accent,
  });

  /// Départ du dégradé d'en-tête.
  final Color debut;

  /// Arrivée du dégradé d'en-tête.
  final Color fin;

  /// Fond de la page, très légèrement teinté de la couleur de la section.
  final Color fond;

  /// Couleur d'appui pour les accents de la section (liens, pastilles actives).
  final Color accent;

  List<Color> get gradient => [debut, fin];
}

/// Dégradé de la barre de navigation : indigo profond → violet profond.
///
/// Mesuré à 11,42:1 et 10,95:1 sous du blanc. Une barre sombre sous des pages
/// claires ancre l'écran, et les icônes blanches y restent lisibles même en
/// plein soleil — ce qui n'est pas un détail au Cameroun.
const List<Color> kMboaNavGradient = [Color(0xFF312E81), Color(0xFF4C1D95)];

/// Pastilles colorées des tuiles d'icônes (maquettes, lots 4, 9 et 11).
///
/// Chaque paire respecte 3:1 entre l'icône et sa pastille : ce sont des
/// éléments d'interface, pas de la décoration.
enum MboaTileTone {
  indigo(Color(0xFF4F46E5), Color(0xFFEDE9FE)),
  bleu(Color(0xFF2563EB), Color(0xFFDBEAFE)),
  vert(Color(0xFF15803D), Color(0xFFDCFCE7)),
  orange(Color(0xFFC2410C), Color(0xFFFFEDD5)),
  ambre(Color(0xFFB45309), Color(0xFFFEF3C7)),
  rose(Color(0xFFDB2777), Color(0xFFFCE7F3));

  const MboaTileTone(this.icon, this.background);

  final Color icon;
  final Color background;
}

abstract final class MboaSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
}

abstract final class MboaRadius {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 28.0;
}

abstract final class MboaMotion {
  static const instant = Duration(milliseconds: 100);
  static const quick = Duration(milliseconds: 180);
  static const standard = Duration(milliseconds: 260);
  static const celebrate = Duration(milliseconds: 600);
}

/// Cible tactile minimale (K9) : 48 dp.
const double kMinTouchTarget = 48;

/// Ombre douce des cartes, telle qu'on la voit dans les maquettes : très peu
/// marquée, elle sépare la carte du fond sans l'en détacher.
const List<BoxShadow> kMboaCardShadow = [
  BoxShadow(color: Color(0x0D111827), blurRadius: 12, offset: Offset(0, 2)),
];
