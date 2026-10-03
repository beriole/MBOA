# MBOA — Phase 0 : Design System

Livrable **K**. Statut : soumis pour validation. Le design system est défini **avant** les écrans ; il vit dans `packages/mboa_design`.

Direction artistique : **patrimoine camerounais + technologie contemporaine + apprentissage ludique**. Base technique Material 3 (Flutter), identité MBOA propre. Pas de motif traditionnel en fond d'écran : les motifs sont des **accents** (en-tête, badge, séparateur, illustration, filigrane ≤ 6 % d'opacité).

---

## K1. ColorTokens

Palette : vert forêt (identité, croissance, langue vivante), terre cuite (chaleur, artisanat), ocre/or (récompense, XP), ivoire & sable (fonds), encre (texte).

### Couches primitives (light)

| Token | Hex | Usage |
|---|---|---|
| `forest.900` | `#0F3D2E` | texte sur fonds verts clairs, titres de section |
| `forest.700` | `#145C43` | bouton primaire pressé, en-têtes |
| `forest.500` | `#1B7A57` | **couleur primaire** (boutons, nœud actif du parcours) |
| `forest.300` | `#5FAE8E` | états secondaires, primaire en thème sombre |
| `forest.100` | `#D7EDE3` | conteneurs, chips, fond de progression |
| `terre.700` | `#993A22` | bouton secondaire (texte blanc) |
| `terre.600` | `#B4462A` | accent marketplace / artisanat |
| `terre.300` | `#E9A98F` | conteneur |
| `terre.100` | `#FBE7DE` | fond de carte culture |
| `ocre.700` | `#966D09` | texte sur ivoire quand l'or est nécessaire |
| `ocre.500` | `#D99A16` | badges, streak |
| `ocre.400` | `#E9B33D` | **XP, récompenses** (texte encre.900 dessus) |
| `ocre.100` | `#FCF0D6` | fond de badge |
| `ivoire` | `#FDFBF6` | **fond principal** (jamais blanc pur) |
| `sable.100` | `#F4EDE1` | surface alternative, cartes |
| `sable.200` | `#E7DCC9` | séparateurs décoratifs |
| `sable.600` | `#9A8769` | **bordures d'éléments d'interface** (3,36:1 ✔ WCAG 1.4.11) |
| `encre.900` | `#1A1613` | texte principal (17,38:1 ✔ AAA) |
| `encre.700` | `#3D362F` | texte fort sur sable |
| `encre.500` | `#6B6157` | texte secondaire (5,85:1 ✔ AA) |
| `encre.400` | `#857A6D` | texte tertiaire / désactivé (4,06:1 — **jamais** pour une information essentielle) |
| `succes` | `#2E7D4F` | réponse correcte |
| `erreur` | `#B3261E` | réponse incorrecte |
| `info` | `#1F6FB2` | information, assistant |

### Thème sombre

| Token | Hex | Contraste vérifié |
|---|---|---|
| `nuit.900` `#12100E` (fond) · `nuit.800` `#1C1916` (surface) · `nuit.700` `#2A2622` (surface élevée) | | |
| texte principal `sable.100` sur `nuit.900` | | **16,32:1 ✔ AAA** |
| primaire `forest.300` sur `nuit.900` | | **7,17:1 ✔ AAA** (texte `nuit.900` sur bouton : 7,17:1 ✔) |
| XP `ocre.400` sur `nuit.900` | | **9,93:1 ✔ AAA** |
| erreur `#F2B8B5` sur `nuit.900` | | **11,12:1 ✔ AAA** |
| bordure `#B3A184` sur `nuit.800` | | **6,96:1 ✔** |

### Contrastes vérifiés (light) — mesures réelles, pas déclaratives

| Combinaison | Ratio | Verdict |
|---|---|---|
| `encre.900` / `ivoire` | 17,38 | AAA |
| `encre.500` / `ivoire` | 5,85 | AA |
| `blanc` / `forest.500` (bouton primaire) | 5,29 | AA |
| `blanc` / `terre.700` (bouton secondaire) | 7,04 | AAA |
| `encre.900` / `ocre.400` (badge XP) | 9,40 | AAA |
| `forest.900` / `forest.100` (chip) | 9,91 | AAA |
| `blanc` / `succes` | 5,05 | AA |
| `blanc` / `erreur` | 6,54 | AA |
| `erreur` / `ivoire` (texte) | 6,32 | AA |
| `sable.600` / `ivoire` (bordure) | 3,36 | ✔ 1.4.11 (≥ 3:1) |

**Écarté après mesure** : `terre.500 #C85A3C` avec texte blanc (4,21 — insuffisant) → remplacé par `terre.700` ; `encre.300 #9C9285` (2,96) → dégradé en usage purement décoratif ; `sable.400` en bordure (1,96) → remplacé par `sable.600`.

### Rôles sémantiques (mappés sur `ColorScheme` M3)
`primary = forest.500` · `onPrimary = #FFFFFF` · `primaryContainer = forest.100` · `onPrimaryContainer = forest.900` · `secondary = terre.700` · `tertiary = ocre.500` · `surface = ivoire` · `surfaceContainer = sable.100` · `outline = sable.600` · `error = erreur`.

**Règle absolue** : aucune information n'est portée par la seule couleur. Correct = ✓ + texte « Correct » + vert. Incorrect = ✗ + texte « Pas encore » + rouge. Verrouillé = 🔒 + opacité + libellé.

---

## K2. TypographyTokens

Police : **Inter** (UI, excellente couverture latine étendue) + **Fraunces** ou **Bricolage Grotesque** (titres, caractère éditorial). Contrainte obligatoire : la police doit rendre correctement `ǝ ɛ ɔ ŋ ɓ` et les diacritiques tonales empilées (aigu, grave, macron, caron, circonflexe). **Inter couvre ces glyphes ; à vérifier avec un rendu réel avant de figer** (test golden sur une chaîne de contrôle).

| Token | Taille / hauteur | Graisse | Usage |
|---|---|---|---|
| `display` | 32 / 38 | 700 (titre) | écran de réussite, checkpoint |
| `headline` | 26 / 32 | 700 | titres d'écran |
| `title` | 20 / 26 | 600 | titres de carte, nom d'unité |
| `bodyLarge` | 17 / 26 | 400 | corps, consignes |
| `body` | 15 / 22 | 400 | corps secondaire |
| `label` | 13 / 18 | 600 | boutons, chips |
| `caption` | 12 / 16 | 400 | métadonnées, sources |
| `lexeme` | 28 / 40 (interligne large) | 500 | **mot en langue nationale** : interligne large pour les diacritiques tonales, `fontFeatures: [ss01]`, jamais en majuscules forcées (les diacritiques se perdent) |
| `lexemeSmall` | 19 / 28 | 500 | mot en langue nationale dans une liste |

Règles : taille minimale 12 ; `textScaler` supporté jusqu'à 1,3× sans débordement ; pas d'italique sur les formes en langue nationale (déformation des diacritiques) — on distingue par la couleur `forest.900` et la police.

---

## K3. SpacingTokens, RadiusTokens, ElevationTokens

- **Spacing** (base 4) : `xs 4 · sm 8 · md 12 · lg 16 · xl 24 · 2xl 32 · 3xl 48`. Gouttière d'écran = 16. Espacement vertical entre blocs = 24.
- **Radius** : `sm 8` (chips, champs) · `md 12` (cartes) · `lg 20` (cartes principales, feuilles) · `xl 28` (boutons pilule) · `full` (avatars, nœuds de parcours).
- **Elevation** : `flat 0` (défaut — on privilégie le trait et la teinte au lieu de l'ombre) · `raised 1` (carte cliquable) · `sticky 3` (barre de feedback, bottom bar) · `modal 6`. Les ombres sont teintées `forest.900` à 8 % et non noires.

## K4. MotionTokens

| Token | Durée | Courbe | Usage |
|---|---|---|---|
| `instant` | 100 ms | easeOut | changement d'état de bouton |
| `quick` | 180 ms | easeOutCubic | apparition du feedback |
| `standard` | 260 ms | easeInOutCubic | transitions d'écran |
| `celebrate` | 600 ms | elasticOut | validation de leçon, badge |
| `pathAdvance` | 450 ms | easeOutBack | progression du nœud sur le chemin |

Toutes les animations sont désactivées si `MediaQuery.disableAnimations` (TalkBack / VoiceOver, réglage système). Aucune animation ne bloque l'interaction plus de 600 ms. Pas de clignotement > 3 Hz.

## K5. Iconographie
Jeu SVG propriétaire, trait 2 dp, extrémités arrondies, grille 24. Icônes métier : parcours, révision, prononciation, culture, marché, assistant, traduction, streak, XP, certificat, source. Les icônes culturelles (danse, tenue, gastronomie) sont dessinées spécifiquement pour MBOA — pas de pictogrammes génériques importés.

## K6. Composants (`mboa_design`)

| Composant | Variantes | Règles |
|---|---|---|
| `MboaButton` | `primary` (forest.500, plein) · `secondary` (terre.700) · `tonal` (forest.100) · `ghost` · `destructive` | hauteur 52, radius `xl`, label `label`, état `loading` avec spinner, cible ≥ 48 dp, **un seul bouton primaire par écran** |
| `MboaCard` | `surface` · `culture` (terre.100 + filigrane motif) · `lesson` · `product` | radius `lg`, bordure `sable.600` 1 dp, pas d'ombre par défaut |
| `PathNode` | `locked` · `available` · `current` · `completed` · `review` (★) · `checkpoint` (🏆) | 64 dp, anneau de progression, icône + état textuel pour l'accessibilité |
| `ProgressRing` / `ProgressBar` | — | valeur annoncée par sémantique (« 3 leçons sur 4 ») |
| `AudioButton` | `normal` · `slow` (0,75×) | 48 dp, état lecture animé, label « Écouter » / « Écouter lentement » |
| `LexemeText` | — | applique `lexeme`, garantit NFC, ne coupe jamais un mot diacrité |
| `ExerciseShell` | — | structure commune : consigne, zone d'exercice, `FeedbackBar` collante |
| `FeedbackBar` | `correct` · `incorrect` | icône + titre + bonne réponse + explication + 🔊 + bouton « Continuer » ; ton bienveillant, jamais « Faux ! » |
| `XpChip`, `StreakChip`, `Badge` | — | ocre, texte encre.900 |
| `SourceChip` | — | affiche la provenance d'un contenu (« Source : Hyman 2003 ») — élément d'identité MBOA |
| `MboaInput` | text · password · search | bordure `sable.600`, focus `forest.500` 2 dp, message d'erreur textuel + icône |
| `EmptyState`, `ErrorState`, `OfflineBanner` | — | illustration mascotte + action |
| `MascotteView` | états : neutre, encourage, félicite, réfléchit | SVG animé léger (pas de Lottie lourd) |

## K7. Mascotte
**Ngum** *(nom de travail, à valider culturellement)* — silhouette originale inspirée du **calao** (oiseau présent dans l'iconographie de plusieurs cultures camerounaises, à faire valider par les spécialistes avant usage). Attributs : curiosité, transmission, progrès. 4 poses maximum au MVP, format SVG. **Interdit** : toute ressemblance avec Duo ou tout personnage d'une application existante. La mascotte n'apparaît jamais pour humilier (pas de pose triste en cas d'erreur — elle encourage).

## K8. Motifs et textures
Bibliothèque de 4 motifs géométriques dérivés de traditions camerounaises, **redessinés** pour MBOA et documentés (origine, communauté, source, validation par un spécialiste). Usage : bandeau d'en-tête (hauteur ≤ 96), séparateur de section, fond de badge, filigrane de carte culture à 6 % d'opacité. Jamais en fond d'écran plein, jamais derrière du texte long.

## K9. Accessibilité (règles opposables, testées)
1. Contraste texte ≥ 4,5:1, éléments d'interface ≥ 3:1 — valeurs mesurées ci-dessus, test automatisé dans la CI.
2. Cibles tactiles ≥ 48×48 dp, espacement ≥ 8 dp.
3. `Semantics` sur chaque contrôle ; ordre de lecture explicite dans le player de leçon ; annonce du feedback via `SemanticsService.announce`.
4. Chaque audio a une **transcription visible** et l'exercice reste réalisable sans son (mode « alternative au son » : la forme écrite est affichée d'abord).
5. Aucun exercice n'exige uniquement la voix pour progresser (`SPEAK` est toujours passable).
6. `textScaler` jusqu'à 1,3× ; pas de texte dans les images.
7. Mode sombre complet ; option « réduire les animations » ; option « interface simplifiée » (masque la gamification pour les utilisateurs qu'elle distrait).
