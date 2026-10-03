# Q — Alignement du design sur les maquettes

Maquettes reçues : 13 planches, lots 3 à 12 (`docs/captures/maquette/`).
Ce document dit **ce qui a été repris**, **ce qui a été mesuré**, et **ce qui n'a
pas été repris tel quel** — avec la raison à chaque fois.

---

## 1. Ce qui a été repris

| Élément des maquettes | Traduction dans le code |
|---|---|
| En-tête dégradé indigo → violet | `MboaGradientHeader` (`lib/design/widgets/mboa_header.dart`) |
| Compteurs posés dans l'en-tête | `MboaStat`, variante `onLight` |
| Pastilles d'icônes colorées | `MboaIconTile`, `MboaTileRow`, `MboaTileTone` |
| Boutons d'action vert forêt, en gélule | `filledButtonTheme` |
| Bouton doré des moments d'entrée et de récompense | `MboaColors.or` |
| Cartes blanches, coins 20, bordure discrète | `cardTheme` |
| Navigation basse à 5 onglets, actif en indigo | `navigationBarTheme` |
| Encarts d'astuce colorés | `MboaNoteBox` |

La navigation des maquettes n'est pas uniforme d'une planche à l'autre :
les lots 4, 5, 6, 7, 9 et 10 montrent **Accueil · Apprendre · Culture · Boutique ·
Profil**, les lots 8, 11 et 12 montrent **Communauté** et **Services** à la place
de Boutique et Profil. La première répartition est majoritaire et correspond à ce
qui existe : c'est celle qui a été retenue.

## 2. Contrastes mesurés

Le design system MBOA annonce des contrastes **mesurés, pas estimés**. Les
couleurs relevées sur les maquettes ont donc toutes été passées au calcul WCAG 2.2
avant d'entrer dans les jetons.

| Paire | Ratio | Usage |
|---|---|---|
| blanc sur indigo600 `#4F46E5` | 6,29:1 | titre d'en-tête |
| blanc sur violet600 `#7C3AED` | 5,70:1 | fin du dégradé |
| blanc sur forest900 `#0F4C3A` | 9,93:1 | bouton d'action |
| encre900 sur or `#F5B800` | 10,05:1 | bouton doré |
| encre900 `#111827` sur fond `#F8F9FB` | 16,84:1 | texte courant |
| encre500 `#5B6478` sur fond | 5,63:1 | texte secondaire |
| encre400 `#8A90A6` sur fond | 3,01:1 | tertiaire uniquement |
| bordure `#8A90A6` sur fond | 3,01:1 | bouton secondaire, champ |

**Un écart avec les maquettes :** la fin du dégradé y tire vers un violet plus
clair (`#8B5CF6`), qui ne donne que **4,23:1** avec du texte blanc — sous le seuil
de 4,5:1. Le dégradé s'arrête donc à `#7C3AED`. La différence est invisible à
l'œil ; elle change tout pour qui lit mal.

Les pastilles d'icônes respectent 3:1 entre l'icône et son fond : ce sont des
éléments d'interface, pas de la décoration.

## 3. Ce qui n'a pas été repris, et pourquoi

Les maquettes montrent des contenus et des fonctions qui entrent en conflit
direct avec la règle fondatrice du projet — **ne rien affirmer sans source, ne
rien certifier qu'on n'a pas constaté**. La mise en page a été suivie ; le
contenu, non.

| Dans la maquette | Ce qui a été fait |
|---|---|
| **Dictionnaire** : entrée « Mboa [mboa] · Nom · 1. Pays, territoire, patrie » | Aucune entrée de dictionnaire n'est écrite sans source. L'écran de traduction existant interroge le corpus validé et affiche sa provenance. |
| **Traduction instantanée** de phrases (« Bonjour, comment vas-tu ? » → « Mba antu a wo ? ») | MBOA ne traduit pas de phrases : elle **retrouve** des formes attestées. Traduire une phrase supposerait un modèle qui inventerait. |
| **Reconnaissance vocale** avec écoute et onde | Le §19 interdit les faux scores de prononciation. Rien n'est branché tant qu'aucune évaluation réelle n'existe. |
| **Certificat « NIVEAU DÉBUTANT »** | Remplacé par une **attestation de parcours**, qui énonce des leçons terminées et un score, et écrit qu'elle ne certifie aucun niveau de langue. |
| **Paiement MTN / Orange / carte bancaire** | Toujours verrouillé en base (`MBOA[mode_de_paiement_non_branche]`), faute d'entité juridique. Deux règlements sont ouverts, et aucun ne déplace d'argent : les espèces à la livraison, et une **caisse de démonstration** (voir §7). |
| **Mots ewondo** affichés partout (Nnou, Mebe, Wo, Ngi, Angoua…) | Aucun de ces mots n'a de source dans le projet, et le corpus réel est **basaa** (Lingua Libre, CC BY-SA). Les écrans affichent le corpus réel. |
| **Recommandations IA / Assistant MBOA** | Tuile affichée comme « bientôt » plutôt que simulée. |

Ces écarts ne sont pas des oublis : ce sont les mêmes règles qui ont fait refuser
105 enregistrements mal étiquetés et laisser treize rubriques culturelles vides.

## 4. Ce que les maquettes couvrent et que l'application ne fait pas encore

Les planches décrivent un périmètre plus large que le prototype. Par lot :

| Lot | Domaine | État |
|---|---|---|
| 3 | Configuration initiale (8 étapes) | **fait** — 4 avant compte, 5 après |
| 4 | Accueil apprenant | **fait**, d'après la planche |
| 5–6 | Parcours et leçon | **fait** ; 11 des 15 types d'exercices restent à écrire côté client |
| 7 | Suivi, badges, objectifs, comparaison, partage | partiel — statistiques et attestation existent ; badges, objectifs et partage non |
| 8 | Communauté (discussions, membres, sondages) | **non implémenté** |
| 9 | Culture par régions, vidéos, quiz, favoris | **fait**, sauf les vidéos : aucune n'existe sous licence établie |
| 10 | Boutique et **événements** | boutique **faite** ; événements non |
| 11 | Dictionnaire, reconnaissance vocale, mentorat, convertisseur | **non implémenté** (voir §3) |
| 12 | Mode hors ligne | **écarté** — voir §6 |

## 5. Le logo

Le logo a été fourni en PNG carré (1254 × 1254), sur fond crème opaque. Trois
déclinaisons en ont été tirées, dans `mboa_app/assets/brand/` :

| Fichier | Contenu | Où |
|---|---|---|
| `mboa-logo.png` | marque complète, mot-symbole et signature | écran d'accueil de l'onboarding |
| `mboa-embleme.png` | emblème seul, sans lettrage | splash, écrans de connexion et d'inscription |
| `mboa-icon.png` | source carrée de l'icône | icône Android et Web, générée |

Le fond crème a été **détouré par remplissage depuis les bords**, de sorte que
les liserés blancs *intérieurs* au dessin — autour de la feuille, du visage et
dans le « O » — restent intacts. La marque peut donc se poser aussi bien sur le
fond clair que sur le dégradé indigo.

Les fichiers sont quantifiés à 256 couleurs : 677 Ko → 85 Ko pour le logo
complet, sans perte visible sur les dégradés.

L'icône de lancement Android et Web est générée par `flutter_launcher_icons`
(`dart run flutter_launcher_icons`). iOS et macOS ne sont pas configurés dans ce
projet ; les activer ferait échouer la génération. Le fond adaptatif reprend le
crème du logo : un fond transparent laisserait du noir sous les masques ronds.

Les écrans secondaires (fiche culturelle, détail produit, formulaires) gardent un
en-tête clair plutôt que le dégradé. Les maquettes font les deux selon les lots ;
le dégradé a été réservé aux cinq écrans de premier niveau, pour qu'il garde sa
fonction de repère.

## 6. Mode hors ligne : écarté

Le cahier des charges qualifie le mode hors ligne d'« ESSENTIEL » au §35, et le
lot 12 des maquettes lui consacre dix écrans. **Le porteur du projet a décidé de
ne pas le réaliser.** La décision est notée ici pour qu'elle reste lisible : ce
n'est pas un oubli, et l'écart avec le §35 est assumé.

Ce qui subsiste dans le code n'est pas du travail perdu et ne promet rien :

- `learn.content_releases` (version publiée du contenu d'une langue) et
  `progress.exercise_attempts.client_attempt_id` rendent une synchronisation
  idempotente possible si la décision changeait un jour ;
- la police Inter reste **embarquée** plutôt que téléchargée : cela garantit un
  rendu identique et une ouverture rapide sur une connexion faible, ce qui vaut
  indépendamment du mode hors ligne.

Aucun écran ne propose de téléchargement, et aucune formulation de l'application
ne laisse entendre qu'elle fonctionne sans réseau.

## 7. Place de marché, fil du patrimoine, quiz : trois demandes et leurs limites

Trois demandes du porteur du projet ont été traitées ensemble. Chacune emprunte
la **forme** d'un produit grand public — une grille à la Alibaba, un fil à la
Facebook, un quiz fourni — et chacune se heurte au même endroit à la règle
fondatrice. Ce qui suit dit où passe la ligne, et pourquoi elle passe là.

### 7.1 La boutique en grille, avec photos

La liste est devenue une grille responsive (2 colonnes sur téléphone, jusqu'à 5
sur grand écran), avec vignette carrée, prix, note moyenne et pastille
d'affirmation culturelle. Les produits acceptent désormais **jusqu'à six photos**
(`market.product_images`), déposées par l'artisan et servies depuis
`media/products/`.

**Ce que MBOA ne fait pas : fournir les images.** Un produit sans photo affiche
un cadre qui dit « Pas de photo ». C'est moins avenant qu'une illustration
générique, et c'est délibéré — un objet artisanal est unique, et la photo d'un
autre panier ferait croire à l'acheteur qu'il a vu le sien. Le catalogue reste
donc visuellement pauvre tant que les artisans n'ont pas déposé leurs clichés ;
c'est un état du contenu, pas un défaut de l'écran.

Le format déposé est reconnu **dans les octets du fichier**, pas dans son nom ni
dans l'en-tête annoncé par le navigateur : les deux se falsifient.

### 7.2 La caisse de démonstration

Le porteur du projet a demandé un paiement simulé. Il est ouvert, sous un nom
qui ne laisse aucune place au doute.

| | Espèces à la livraison | Paiement simulé |
|---|---|---|
| Argent transitant par MBOA | aucun | aucun |
| Argent échangé | oui, entre l'acheteur et le livreur | **aucun** |
| Trace en base | `payment_mode = CASH_ON_DELIVERY` | `payment_mode = SIMULATION` + `simulated_paid_at` |

Trois garde-fous en base, parce qu'une démonstration qui se ferait passer pour
une vente ferait préparer un colis contre rien :

- `MBOA[encaissement_absent]` — le statut `PAID` reste interdit, dans tous les cas ;
- `MBOA[simulation_hors_simulation]` — la marque de règlement simulé ne peut pas
  être posée sur une commande réelle ;
- `MBOA[simulation_indelebile]` — une fois posée, elle ne peut plus être effacée.

La mention voyage avec chaque commande, et **l'artisan la voit avant l'acheteur**
dans son espace : c'est lui qui préparerait l'envoi.

Le mobile money et la carte bancaire restent refusés. Ouvrir la simulation n'a
rien ouvert d'autre.

### 7.3 Le quiz : de 4 à 33 questions

Le quiz ne tirait ses questions que des fiches culturelles publiées. Il y en a
**trois** : au mieux quatre questions, la plupart du temps moins. D'où
l'impression, juste, qu'il était vide.

Il puise désormais aussi dans les **treize enregistrements du vocabulaire**,
dont l'auteur et la licence sont connus (Lingua Libre, CC BY-SA 4.0) :

| Type | Origine | Questions |
|---|---|---|
| `CATEGORY`, `REGION`, `SUMMARY` | fiches publiées | 7 |
| `AUDIO_WORD` — entendre, reconnaître le mot | enregistrements sourcés | 13 |
| `WORD_AUDIO` — lire, retrouver la piste | enregistrements sourcés | 13 |

Le plancher de propositions est passé de 4 à 3 : avec trois fiches, une question
à quatre choix était impossible à former, et trois propositions testent encore
quelque chose.

**Ce qui reste impossible : demander la traduction d'un mot.** Quatre des treize
entrées portent une glose, et cette glose dit littéralement « sens à confirmer
par un locuteur ». Ce n'est pas un sens, c'est l'aveu qu'il manque. Poser la
question ferait valider une réponse que personne n'a établie.

Le plafond du quiz reste donc dicté par le corpus, et l'écran l'annonce au lieu
de compléter.

### 7.4 Le fil du patrimoine, et les commentaires

La découverte du patrimoine emprunte la forme d'un fil social : cartes pleine
largeur, média en tête, réactions dessous, commentaires dépliables.

La différence est dans ce qui l'alimente. Un fil social affiche ce que n'importe
qui publie ; celui-ci **met en page du contenu déjà validé** — une fiche porte sa
source, un enregistrement porte son auteur et sa licence. Aucune carte n'entre
sans répondant extérieur à MBOA.

Les commentaires et les avis ouvrent une porte nouvelle : du texte écrit par des
utilisateurs. Elle ne contredit pas la règle fondatrice, à une condition qui
structure tout le module — **un avis n'est pas une source** :

- un commentaire porte toujours son auteur et sa date ; il n'entre jamais dans le
  corps d'une fiche, ni dans un quiz ;
- la **note** n'existe que sur un objet vendu. Le serveur refuse (422) de noter
  une fiche culturelle : on ne vote pas sur un fait ;
- un contenu signalé est **masqué, pas supprimé** — la modération doit pouvoir
  le lire pour trancher, et un signalement abusif doit se voir.

### 7.5 Ce qui a été demandé et qui n'existe pas

Le porteur du projet a demandé « vidéo, annonces, chant, musique ». Le fil les
**annonce comme absents** au lieu de les simuler :

| Demandé | État | Pourquoi pas de substitut |
|---|---|---|
| Vidéo | aucune au catalogue | MBOA ne diffusera que sous licence établie. Une vidéo d'illustration sans provenance vaudrait moins qu'une case vide. |
| Chant, musique | rien de collecté | Les treize enregistrements sont des **mots isolés**. Les afficher sous une rubrique « chants » serait faux, et rendrait le reste du fil indigne de confiance. |
| Photographies de fiches | aucune | Une image sans provenance ni licence ne sera pas publiée. |

Le bandeau « Ce qui manque encore » est relu en base à chaque affichage : ces
phrases disparaîtront d'elles-mêmes le jour où le contenu arrivera.

## 8. Contrôle d'interface : ce que l'audit a trouvé

Un passage systématique sur les écrans livrés au §7, contre les critères
d'accessibilité et de tactile, a révélé **six défauts réels**. Ils partagent un
trait : aucun ne se voit sur un écran de bureau, à taille de texte normale, avec
une souris. Ils sont désormais tenus par `mboa_app/test/ui_audit_test.dart`.

| Défaut | Conséquence | Correction |
|---|---|---|
| Vignette de la boutique à proportion fixe (`childAspectRatio: 0.58`) | **Débordement de 43 px sur un téléphone standard**, avant même tout grossissement | Hauteur calculée depuis le thème et l'échelle de texte ; la photo occupe ce qui reste |
| Deux colonnes imposées quel que soit le grossissement | À 200 %, débordement de 227 px | Le nombre de colonnes suit la largeur **divisée par l'échelle** : une seule colonne quand le texte est grand |
| Étoiles de notation dans un `Row` | Débordement de 490 px à 200 % | `Wrap` |
| Rangée d'actions du fil dans un `Row` | Débordement dès 100 %, 343 px à 200 % | `Wrap` |
| Croix de retrait d'une photo posée en débord de sa `Stack` | Bouton **dessiné mais insensible au toucher** | Ramenée dans les limites du parent, zone portée à 48 dp |
| Boutons texte à 40 dp (défaut Material) | Sous le seuil tactile, sans fond pour signaler qu'on les a manqués | Plancher de 48 dp posé dans le thème, pas écran par écran |

Deux ajustements complémentaires : le champ de commentaire a reçu une **étiquette
persistante** (un intitulé en texte d'aide disparaît à la première lettre), et le
cadre « pas de photo » s'adapte à la place disponible au lieu de déborder dans
une vignette de 88 px.

### Ce que l'audit a écarté

Deux alertes initiales étaient fausses, et les écarter a autant compté que
corriger le reste :

- les puces de filtre et les boutons à icône apparaissaient à 40 dp. Material
  étend leur zone sensible au-delà du dessin : le doigt dispose bien de 48 dp.
  Mesurer l'effet d'encre plutôt que le composant porteur aurait fait corriger
  un défaut inexistant, et noyé les vrais dans le bruit ;
- un troisième signalement venait du banc d'essai lui-même, qui remplaçait tout
  le `MediaQueryData` et testait donc une fenêtre de zéro pixel.

### Sur le style recommandé

L'outil de recommandation propose, pour ce type de produit, un style
*claymorphism* violet avec la police Cormorant Garamond. Il n'a **pas** été
adopté : il contredit les maquettes fournies, et le design system actuel repose
sur des contrastes mesurés, alignés sur ces maquettes (§1 et §2). Changer de
langage visuel à ce stade reviendrait à défaire un travail validé pour suivre
une suggestion générique.

## 9. Refonte visuelle et mise en volume

Le porteur du projet a jugé l'application « trop blanche », la page profil et les
écrans de compte mauvais, la boutique et l'apprentissage mal structurés, et la
page culture sans attrait. Cette section consigne ce qui a été fait, et surtout
**les deux endroits où la demande a été adaptée plutôt que suivie à la lettre**.

### 9.1 La couleur devient un repère

Toutes les pages partageaient le même fond neutre et le même dégradé indigo : on
ne savait pas où l'on se trouvait. Chaque section porte désormais sa couleur, et
la pastille active de la barre de navigation reprend celle de la page où elle
mène — les deux repères se répondent.

| Section | Dégradé | Blanc dessus (mesuré) | Fond | `encre900` dessus |
|---|---|---|---|---|
| Accueil | indigo → violet | 6,29 / 5,70:1 | `#F5F4FF` | 16,28:1 |
| Apprendre | teal → vert | 5,47 / 5,02:1 | `#F1FAF6` | 16,68:1 |
| Culture | violet → rose | 7,10 / 6,04:1 | `#FBF4FA` | 16,41:1 |
| Boutique | orange → rose | 5,18 / 4,60:1 | `#FFF7F2` | 16,76:1 |
| Profil | bleu → cyan | 6,70 / 5,36:1 | `#F2F7FE` | 16,48:1 |

**Tous ces contrastes ont été calculés, pas estimés.** Un candidat a été écarté à
ce titre : la terre cuite `#DC5A18` ne donnait que 3,81:1 sous du blanc. La barre
de navigation (indigo 900 → violet 900) tient à 11,42 et 10,95:1, et son icône
inactive à 6,11 et 5,86:1.

### 9.2 Le type de compte passe à l'inscription

Le profil portait des invitations à devenir artisan, livreur ou spécialiste :
du recrutement sur une page personnelle, où un apprenant lisait surtout ce qu'il
n'était pas. Ces choix sont désormais proposés à l'inscription.

**Ce qui n'a pas bougé** : choisir « artisan » ou « livreur » ne donne pas le
rôle. Le compte est créé comme apprenant, et un dossier est ouvert que
l'administration examine. Cette vérification existe parce que MBOA ne conserve
aucune pièce d'identité (§7 de `H-architecture-donnees`) ; la contourner pour
raccourcir l'inscription aurait vidé de son sens le seul contrôle en place.

**Conséquence assumée** : un apprenant déjà inscrit n'a plus de chemin visible
pour devenir artisan. Les routes `/become/:role` et `/become-specialist` existent
toujours ; leur exposition dans les réglages est une décision qui revient au
porteur du projet.

### 9.3 Boutiques de démonstration : marquées, pas déguisées

Le catalogue comptait **un objet**. On ne juge pas une grille de place de marché,
une recherche ni des filtres sur si peu. Mais un artisan est une personne, et un
objet artisanal porte souvent une affirmation culturelle.

Quatre garde-fous encadrent les 8 boutiques et 35 objets ajoutés :

1. **`market.shops.is_demo`**, exposé par l'API et affiché sur **la photo** de
   chaque carte — pas en bas de la fiche. Un acheteur ne doit pas l'apprendre au
   moment de commander.
2. **`cultural_claim_fr` reste nul** sur tous les objets. Les titres décrivent une
   matière et une forme (« panier en raphia, grand format ») ; aucun ne dit
   « traditionnel », « rituel », ni n'attribue l'objet à un peuple.
3. **Aucun nom de personne.** Les boutiques portent des noms d'atelier.
4. **Effaçable d'une commande** : `python -m scripts.seed_market_demo --purge`.

Les photographies sont de vraies images d'artisanat camerounais issues de la
médiathèque Commons, créditées, et chaque ligne porte la légende « ce n'est pas
l'objet vendu ».

### 9.4 Médias : il y avait bien des vidéos

Le §7.5 annonçait qu'aucune vidéo n'était disponible. **C'était faux**, et la
correction mérite d'être notée : Wikimedia Commons héberge des vidéos de danse
camerounaise sous CC BY-SA, avec auteur nommé.

`scripts/fetch_commons_media.py` en a rapatrié **51 médias** — 47 photographies et
4 vidéos — dans `culture.media_library`. Trois garanties :

- **licence relue à chaque téléchargement**, comparée à une liste blanche. Être
  sur Commons ne prouve rien : certains fichiers y sont sous usage équitable.
  27 candidats refusés ;
- **auteur obligatoire.** Sans lui, CC BY et CC BY-SA sont inapplicables ;
- **filtre de rattachement.** La recherche Commons est lâche : « Cameroon
  traditional dance » remontait des vidéos indonésiennes. Un média doit mentionner
  le Cameroun dans son titre, sa description ou ses catégories.

Ce filtre a coûté une vidéo qu'on aurait voulu garder : « Jean René speaking
Medumba » (Wikitongues, CC BY-SA 4.0), la seule vidéo d'un locuteur d'une langue
camerounaise. Sa page Commons ne mentionne le Cameroun nulle part. La rattacher
aurait été **MBOA qui affirme le lien**. Elle passera par une fiche sourcée, ou
pas du tout.

Les titres et descriptions affichés sont ceux des auteurs, et l'écran le dit.
MBOA n'attribue ce qu'on voit à aucun peuple ni à aucune tradition.

### 9.5 Le parcours d'apprentissage : un problème de contenu, pas de mise en page

Le chemin comptait **un cours, une section, une unité, une leçon** — et cette
leçon portait 24 exercices. Aucun travail de design ne sauve un parcours à un
nœud, et 24 exercices contredisaient la règle du projet : une leçon dure 3 à
7 minutes (SS11).

`scripts/restructure_path.py` a réparti les 24 exercices **déjà validés** en
5 leçons de 3 à 6, regroupées par type d'exercice, avec progression verrouillée.
Aucun contenu n'a été créé : les exercices existaient et venaient du corpus
sourcé. Les titres décrivent la mécanique de l'exercice (« Reconnaître à
l'oreille »), jamais un contenu culturel.

Les nouvelles leçons ont suivi le circuit complet `DRAFT → PUBLISHED` avec
validation enregistrée. Les triggers d'intégrité n'ont pas été contournés.

### 9.6 Sur le style recommandé par l'outil de design

Interrogé sur ce type de produit, l'outil propose un style *claymorphism* violet
avec la police Cormorant Garamond, destiné aux « applications pour enfants et
produits sociaux pour adolescents ». Il n'a pas été adopté : il contredit les
maquettes fournies, et le design system repose sur des contrastes mesurés alignés
sur elles (§1 et §2). Ce qui a été retenu de l'outil, c'est sa grille de contrôle
d'accessibilité — elle a trouvé six défauts réels (§8).

## 10. L'espace d'administration

### 10.1 Pourquoi plusieurs couleurs, et pourquoi la console n'en avait aucune

La question posée est juste, et la réponse est que la console était une
**omission**, pas un choix.

Les cinq onglets publics — Accueil, Apprendre, Culture, Boutique, Profil —
portent chacun un dégradé d'en-tête et un fond légèrement teinté (§9.1). Ce
n'est pas de la décoration : la pastille active de la barre de navigation
reprend le dégradé de l'en-tête, si bien qu'on sait où l'on se trouve sans
lire. Cinq sections, cinq repères.

La console d'administration n'est pas l'un de ces cinq onglets. Elle n'avait
donc reçu aucune couleur, et retombait sur les valeurs par défaut de Material :
une `AppBar` grise, un `TabBar` souligné, un fond blanc. C'était le seul endroit
de l'application à ne ressembler à rien — d'où l'impression de pages blanches au
milieu d'une application colorée.

La correction n'est pas une sixième couleur dans la ronde : c'est **une seule
couleur pour tout l'espace**, posée sur les cinq onglets de la console sans
varier. Elle est délibérément hors gamme — ardoise `#1E293B` → indigo profond
`#3730A3`, la teinte du châssis de l'application plutôt que celle d'un contenu —
et plus sombre que les cinq autres, pour qu'on ne confonde jamais un écran
d'administration avec un écran d'apprenant.

Contrastes mesurés : blanc sur `#1E293B` à 14,47:1 et sur `#3730A3` à 10,03:1 ;
`encre900` sur le fond `#F1F4F9` à 16,11:1, `encre500` à 5,47:1.

### 10.2 Ce qui a été refait

Les cinq écrans s'étaient construits chacun de leur côté : l'un empilait des
blocs sable, l'autre des `Card`, le troisième des `ListTile` séparés par des
filets. Ils partagent désormais un même vocabulaire (`admin_widgets.dart`) —
panneau titré, tuile de chiffre, encart, étiquette, écran vide, écran d'erreur —
et un écran ajouté plus tard le reprendra sans rien réinventer.

- **Onglets** : le `TabBar` de Material exige un fond opaque sous un dégradé, ce
  qui produisait une bande blanche collée à l'en-tête. Des pastilles vivent
  maintenant dans le dégradé, avec le nombre d'éléments en attente sur celles
  qui ont une file. Jeton inactif mesuré à 6,20:1.
- **Tableau de bord** : les chiffres suivent la largeur et le grossissement du
  texte au lieu d'une largeur figée à 150 points ; les compteurs qui désignent
  un retard passent en rouge, ceux qui décrivent un état restent neutres.
- **Comptes** : cartes avec initiales et pastille de rôle, et le nombre de
  résultats, qui était invisible.
- **Paramètres** : l'écran affichait `review_required_before_publish` en gros
  comme titre. Le libellé français passe devant, la clé technique reste en
  petit — un administrateur qui ouvre un ticket a besoin de la citer. Seules les
  quatre clés que le serveur crée réellement ont un libellé ; une clé ajoutée
  plus tard s'affichera sous son nom technique plutôt que sous un libellé deviné.
- **Journal** : une chronologie, avec une icône et une couleur par famille
  d'acte.

### 10.3 Trois défauts trouvés, et comment

Un test monte les cinq écrans à 200 % de grossissement de texte et échoue au
moindre débordement. Il en a trouvé deux que l'œil n'avait pas vus :

1. l'étiquette « non implémenté » du tableau de bord mesurait 374 px pour 326
   disponibles. Les étiquettes peuvent désormais passer à la ligne, et l'état
   s'affiche sous le nom du module plutôt qu'à sa droite ;
2. le `FilterChip` des demandes mesurait 347 px pour 322. Il est remplacé par
   deux jetons courts dans un `Wrap`.

Le troisième a été vu sur la capture : le jeton de filtre *sélectionné* prenait
l'`indigo100` du thème et devenait, sur le lavande d'un encart, moins visible
que les jetons non sélectionnés, qui sont blancs. Il est maintenant plein.

### 10.4 Une déclaration du tableau de bord qui était fausse

Le tableau de bord annonçait « Modération des avis et signalements : non
implémenté — dépend de la place de marché ». C'était inexact sur les deux
points : le signalement existe et masque immédiatement le commentaire
(`POST /social/comments/{id}/report`), et les commentaires ne portent pas que
sur des produits, mais aussi sur les fiches culturelles.

Ce qui manque est autre chose, et plus gênant : **aucun écran ne permet de
relire ce qui a été signalé ni de trancher**, si bien que le masquage est
définitif de fait — l'inverse de la règle annoncée dans le code, qui veut qu'on
masque sans supprimer pour que l'administration puisse décider. La ligne du
tableau de bord le dit désormais ainsi. L'écran d'examen reste à écrire.
