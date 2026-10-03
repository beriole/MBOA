# MBOA — apprentissage des langues et du patrimoine camerounais

Prototype fonctionnel : **Flutter + FastAPI + PostgreSQL**, entièrement exécutable en local.

Le principe fondateur du projet est vérifiable, pas seulement déclaré : **aucun contenu
linguistique ne peut être publié sans source identifiée ni validation humaine**, et cette
règle est appliquée par PostgreSQL lui-même.

---

## 1. Ce qui fonctionne aujourd'hui

| Domaine | État |
|---|---|
| Schéma de données complet | 59 tables, 13 schémas, 28 types ENUM, 22 triggers |
| Circuit de validation du contenu | `DRAFT → SOURCE_FOUND → TO_VERIFY → HUMAN_REVIEW → VALIDATED → PUBLISHED` |
| API | authentification JWT, parcours, leçons, correction des réponses, progression, révision, provenance, audio |
| Corpus de démonstration | 13 formes **basaa réelles** issues de Lingua Libre (CC BY-SA 4.0), avec audio de locuteurs |
| Moteur d'exercices | 15 types définis, 4 implémentés côté client, correction 100 % serveur |
| Répétition espacée | SM-2 simplifié, calculé par le serveur |
| Application Flutter | onboarding, accueil, parcours, lecteur de leçon, feedback, résultat, révision, profil |
| **Espace contributeur** | file de travail, saisie des gloses, relecture par un second contributeur, publication, génération des exercices de sens |
| **Traduction** | recherche dans le corpus validé, tolérante aux tons et aux lettres spéciales, avec provenance et signalement |
| **Culture Hub** | rubriques, fiches sourcées, carte « Le savais-tu ? » à l'intérieur des leçons |
| **Administration** | tableau de bord d'intégrité, comptes, habilitations, paramètres, journal inaltérable |
| **Attestations** | PDF généré localement, vérifiable publiquement par code, révocable |
| **Profil** | nom, objectif quotidien, langue d'interface, mot de passe |
| **Place de marché** | boutique d'artisan, catalogue, commande, livraison suivie — sans qu'un franc transite par MBOA |
| **Culture par régions** | les dix régions, leurs fiches, leurs enregistrements sourcés, un quiz tiré des fiches publiées, des favoris |
| **Configuration initiale** | huit étapes : langue, motivation, niveau, rythme, centres d'intérêt, positionnement, notifications, récapitulatif |
| Tests | **225 backend** + **171 Flutter**, dont un parcours complet de bout en bout |

Ce que le prototype **ne fait pas** : traduction *automatique* (par modèle), assistant IA,
et **l'encaissement** — ce dernier par choix, faute d'entité juridique (voir plus bas). Le
**mode hors ligne** a été écarté par décision du porteur, bien que le cahier des charges le
qualifie d'essentiel au §35 : la décision est consignée dans `docs/phase0/Q-alignement-maquettes.md`.
La console d'administration liste elle-même ce qu'elle ne gère pas, et pourquoi.

### La boucle de contribution

C'est le mécanisme central du projet. Au départ, le corpus est **muet** : les mots sont
attestés et enregistrés, mais personne n'a encore dit ce qu'ils signifient. MBOA ne propose
donc que des exercices d'écoute.

```
forme attestée, sans traduction
        │  un contributeur saisit la glose        → repasse en relecture
        │  un SECOND contributeur relit et valide → VALIDATED
        │  publication                            → PUBLISHED
        ▼
les exercices de sens deviennent possibles
        │  génération depuis le corpus publié     → DRAFT
        │  revue humaine de chaque exercice       → PUBLISHED
        ▼
l'apprenant voit un nouveau type d'exercice
```

À aucun moment une seule personne ne peut écrire un contenu et le publier. Pour le voir
tourner :

```bash
cd mboa-api && .venv/Scripts/python scripts/demo_contribution.py
```

### La traduction ne traduit pas : elle retrouve

MBOA ne génère aucune traduction. L'outil cherche dans le corpus validé et répond par quatre
niveaux de certitude, du plus sûr au plus prudent :

| Niveau | Ce qui s'est passé | Confiance |
|---|---|---|
| **exacte** | l'orthographe saisie correspond, diacritiques comprises | 1,00 |
| **tons ignorés** | correspond une fois les tons retirés — l'écriture exacte est rappelée | 0,80 |
| **lettres spéciales rétablies** | `basaa` retrouve `ɓasaá` : personne ne tape ɓ, ɛ, ɔ, ŋ sur un téléphone | 0,70 |
| **forme proche** | similarité approximative, à confirmer avant emploi | 0,30 – 0,70 |

Sous le seuil, rien n'est proposé : *« Aucune correspondance dans le corpus validé »* vaut mieux
qu'une suggestion plausible mais fausse. Chaque demande est tracée (`mode`, `model`,
`model_version`, `confidence`), et l'apprenant peut signaler un résultat douteux : il rejoint
alors la file des spécialistes.

Le mode reste `LEXICON` tant qu'aucun modèle n'a été entraîné **et évalué** pour la langue.

### La culture n'est pas un second menu

Le cahier des charges (§21) demandait explicitement d'éviter deux rubriques séparées. Une fiche
culturelle peut donc être rattachée à une unité : elle s'affiche alors **dans la leçon**, entre
le dernier exercice et le résultat, sous la forme d'une carte « Le savais-tu ? » — puis renvoie
vers la fiche complète.

Les fiches obéissent aux mêmes règles que le corpus linguistique : source obligatoire, validation
humaine, publication impossible autrement. Les triggers PostgreSQL s'appliquent à
`culture.cultural_contents` comme à `corpus.vocabulary_items`.

Trois fiches sont publiées (langue, peuples, traditions orales), rédigées à partir de sources
vérifiées dans ce projet. **Treize rubriques restent vides** et sont affichées comme telles :
montrer ce qui reste à documenter fait partie du propos.

### L'administration ne publie rien

La console d'administration gère les comptes, les habilitations et les paramètres. Elle ne
crée aucun contenu : un administrateur ne peut pas publier un mot en passant par là. Le
pouvoir d'administrer n'est pas le pouvoir d'affirmer qu'un mot existe.

Trois règles la traversent :

1. **Tout acte est motivé.** Changer un rôle, habiliter, désactiver un compte ou modifier un
   paramètre exige un motif, conservé au journal avec le nom de son auteur. La contrainte est
   posée en base (`ck_audit_log_reason_not_blank`) : elle tient même si le code l'oubliait.
   Aucune route ne permet d'effacer une ligne du journal.
2. **Un administrateur ne peut ni changer son propre rôle ni se désactiver**, pour qu'il reste
   toujours un compte capable de réparer une erreur.
3. **Habiliter suppose un dossier.** C'est le « KYC » de MBOA, mais il ne porte pas sur une
   identité bancaire : il porte sur la légitimité à répondre d'une langue. Rapport déclaré à
   la langue, rattachement, personnes pouvant en témoigner — le dossier reste attaché à la
   décision. Des années après, on sait sur quelle base un validateur a été habilité.

Le tableau de bord met l'**intégrité avant l'activité**. La première chose affichée n'est pas
le nombre d'inscrits, c'est le résultat de huit contrôles qui interrogent la base directement :
mots publiés sans source, mots validés par leur propre rédacteur, exercices publiés sans mot
d'origine, fiches culturelles auto-validées… Tous doivent valoir zéro. Un test vérifie cette
conformité sur l'ensemble de ce que la suite de tests a produit — c'est la vérification de bout
en bout que les triggers n'ont été contournés nulle part.

Enfin, la console affiche **ce qu'elle ne gère pas**, avec la raison : paiements et abonnements
(aucune entité juridique à ce stade), vérification d'identité des artisans et livreurs, modération
des avis. Une console qui prétend tout gérer se découvre en réunion.

Pour le voir se dérouler de bout en bout, sans application :

```bash
cd mboa-api && .venv/Scripts/python -m scripts.demo_administration
```

Une apprenante candidate, un motif de deux caractères est refusé, la décision est enregistrée
avec un périmètre plus étroit que celui demandé, l'espace contributeur s'ouvre avec le même
jeton, et le journal garde tout.

### Une attestation dit ce qu'elle n'atteste pas

Terminer toutes les leçons d'une section donne droit à une **attestation de parcours** : un PDF
généré localement, sans service externe, qui énonce des faits vérifiables — leçons terminées,
nombre de réponses, score moyen, dates.

Elle porte, au même corps que le reste du document, la phrase qui la limite :

> *« Cette attestation certifie un parcours accompli dans l'application MBOA. Elle ne constitue
> pas une certification de niveau de langue : MBOA n'organise aucun examen et n'évalue pas la
> production orale. »*

C'est le même principe que pour le corpus, appliqué à l'apprenant : **on n'atteste que ce qu'on
a constaté**. Prétendre certifier un niveau A1 sans faire passer d'épreuve orale reviendrait à
inventer une donnée.

Trois propriétés la rendent utilisable par un tiers :

1. **Elle ne peut pas être forgée.** La condition qu'elle affirme est vérifiée par un trigger
   PostgreSQL (`progress.enforce_certificate_completion`), pas seulement par l'API : un INSERT
   direct qui annoncerait un parcours inexistant est rejeté (`MBOA[parcours_incomplet]`), et des
   chiffres gonflés le sont aussi (`MBOA[chiffres_incoherents]`).
2. **Elle est vérifiable sans compte.** `GET /api/v1/certificates/verify/{code}` est public :
   un employeur saisit le code imprimé et obtient les mêmes faits, plus la phrase de portée.
   Le code évite les caractères ambigus (ni `0`/`O`, ni `1`/`I`) : il se lit au téléphone.
3. **Elle se révoque, elle ne s'efface pas.** Une attestation révoquée continue de répondre à
   la vérification en disant qu'elle l'a été. Un document qui disparaîtrait laisserait sans
   réponse le tiers qui le détient.

Les libellés sont figés à l'émission : renommer son profil ne réécrit pas une attestation déjà
délivrée. Le PDF embarque Inter pour écrire correctement ɓ ɛ ɔ ŋ ǝ et les tons — un test vérifie
cette couverture, faute de quoi un nom de langue s'imprimerait en carrés vides.

```bash
cd mboa-api && .venv/Scripts/python -m scripts.demo_attestation
```

produit `docs/captures/25-attestation.pdf` et son aperçu.

### La place de marché ne touche pas à l'argent

Un artisan ouvre boutique, un acheteur commande, un livreur remet le colis. Le circuit va
jusqu'au bout — **et aucun franc ne transite par MBOA**.

Deux règlements sont ouverts, et **aucun des deux ne déplace d'argent par MBOA** :

- **les espèces à la livraison**, remises au livreur. C'est le mode dominant au Cameroun, et le
  seul paiement réel que la plateforme puisse honnêtement proposer sans entité juridique ni
  compte marchand ;
- **une caisse de démonstration**, pour parcourir l'achat d'un bout à l'autre sans rien payer.
  Elle est nommée en toutes lettres, jamais derrière un mot flou comme « test », et la commande
  en porte la marque de bout en bout.

Quatre verrous sont posés en base, pas dans le code :

| Tentative | Réponse de PostgreSQL |
|---|---|
| Passer une commande à `PAID` | `MBOA[encaissement_absent]` |
| Choisir un règlement par mobile money ou par carte | `MBOA[mode_de_paiement_non_branche]` |
| Marquer une vente réelle comme réglée en simulation | `MBOA[simulation_hors_simulation]` |
| Effacer la marque d'un règlement simulé | `MBOA[simulation_indelebile]` |

Les deux derniers protègent l'artisan : c'est lui qui prépare le colis, et il voit la mention
« paiement simulé » avant même l'acheteur dans son espace. Une démonstration qui se ferait passer
pour une vente lui ferait expédier un objet contre rien.

Le statut `PAID` existe dans l'énumération **pour nommer ce que MBOA ne sait pas faire**. Un
bouton « payer par mobile money » qui ne débiterait rien ferait perdre de l'argent à quelqu'un ;
un statut « payé » sans encaissement serait un mensonge de la même famille qu'un mot inventé.

Ce que le livreur saisit à la remise est une **déclaration**, jamais un paiement enregistré. Si
la somme déclarée s'écarte du total, un motif est exigé : une différence silencieuse serait un
litige que personne ne verrait passer.

### Un objet vendu affirme quelque chose

« Masque traditionnel bamiléké » n'est pas un nom de produit, c'est une affirmation culturelle.
La règle du §3 s'applique donc aussi à la boutique. Chaque fiche produit porte le statut de son
affirmation :

- **Déclaration de l'artisan** — affichée comme telle : *« Cette description vient du vendeur.
  MBOA ne l'a pas vérifiée et ne la présente pas comme un fait établi. »*
- **Documenté par une fiche MBOA** — rattaché à une fiche du Culture Hub publiée, donc sourcée
  et validée, avec un lien vers elle.

Un trigger interdit de se réclamer d'une fiche qui n'est pas `PUBLISHED`
(`MBOA[source_non_publiee]`) : se prévaloir d'un brouillon reviendrait à fabriquer une source.

### La vérification d'identité, sans conserver de pièce

MBOA ne demande **aucun document officiel en ligne** et n'en stocke aucun : cela supposerait un
responsable de traitement et une déclaration que le projet n'a pas encore. La vérification se
fait lors d'une rencontre, et l'administrateur consigne **ce qui a été présenté**, pas une copie.

Accepter un dossier sans renseigner cette base est refusé (422) : une habilitation sans base
vérifiable n'en est pas une. La décision part au journal d'administration avec son motif.

Pour voir le circuit se dérouler, sans application :

```bash
cd mboa-api && .venv/Scripts/python -m scripts.demo_marche
```

Le script montre surtout ce que la plateforme refuse : une acceptation non motivée, un statut
payé, un mode de paiement non branché, et un écart de caisse sans explication.

### Un quiz ne s'invente pas

Le lot 9 des maquettes prévoit un « quiz culture générale ». Une question de
culture générale est une affirmation : chaque question de MBOA est donc **dérivée
d'une fiche publiée**, donc sourcée et validée.

Cinq formes sont produites automatiquement, sans qu'une ligne de contenu soit
écrite à la main. Trois viennent des fiches : la rubrique d'une fiche, la région
dont elle parle, l'affirmation qu'elle porte. Deux viennent des **enregistrements
du vocabulaire**, dont l'auteur et la licence sont connus : entendre et
reconnaître le mot, lire et retrouver la piste. Les mauvaises réponses sont
d'autres rubriques, d'autres régions ou d'autres mots **réels**, jamais fabriqués.

Ce second gisement n'est pas un raffinement : avec trois fiches publiées, le quiz
plafonnait à quatre questions. Il en propose trente-trois, toutes sourcées.

**Ce qui reste impossible : demander la traduction d'un mot.** Les gloses
disponibles disent « sens à confirmer par un locuteur » — ce n'est pas un sens,
c'est l'aveu qu'il manque. Poser la question ferait valider une réponse que
personne n'a établie.

La correction se fait côté serveur — la bonne réponse ne descend jamais jusqu'au
client — et renvoie la fiche et sa source, pour qu'on puisse vérifier plutôt que
croire. Quand le Culture Hub ne permet pas assez de questions, le quiz le dit au
lieu de compléter.

L'exploration par région suit la même logique : les dix régions sont toujours
listées, y compris les neuf où rien n'est encore publié. Et une région sans média
affiche « ni vidéo ni enregistrement pour l'instant » plutôt qu'une illustration
sans provenance.

### Les enregistrements sont servis en local

Les fichiers Lingua Libre étaient d'abord référencés par leur adresse Commons
`Special:FilePath`. Cette adresse est stable, mais elle enchaîne **quatre
redirections** avant d'atteindre le fichier : mesuré à **1,5 à 2 secondes** par
écoute. Pendant une leçon, l'apprenant répond souvent avant que le son soit
arrivé — et entend la piste précédente.

Deux corrections :

1. `scripts/fetch_audio.py` rapatrie les enregistrements une fois pour toutes
   dans `mboa-api/media/audio/` (1,3 Mo pour treize fichiers). L'API les sert
   alors directement : **1 900 ms → 8 ms**. La licence CC BY-SA autorise cette
   redistribution ; l'attribution reste en base, à l'écran, et dans l'en-tête
   `X-Attribution` de chaque réponse.
2. Le lecteur numérote ses demandes. Une piste dont le chargement se termine
   alors que l'apprenant a déjà changé d'exercice est abandonnée au lieu de se
   mettre à jouer par-dessus la suivante.

Le parcours de bout en bout vérifie désormais que la leçon fait entendre
**plusieurs enregistrements distincts** — c'est le défaut qui avait été signalé.

```bash
cd mboa-api && .venv/Scripts/python -m scripts.fetch_audio
```

### Le fil du patrimoine emprunte une forme, pas une méthode

La découverte du patrimoine se présente comme un fil social : cartes pleine
largeur, média en tête, réactions dessous, commentaires dépliables. La forme est
reprise des maquettes parce qu'elle se parcourt bien et donne envie d'ouvrir.

Ce qui l'alimente ne suit pas la même règle. Un fil social affiche ce que
n'importe qui publie ; celui-ci **met en page du contenu déjà validé** — une
fiche porte sa source, un enregistrement porte son auteur et sa licence. Aucune
carte n'entre sans répondant extérieur à MBOA, et un test l'exige.

Là où il n'y a rien, le fil le dit. Le bandeau « Ce qui manque encore » est relu
en base à chaque affichage — et il s'est vidé en partie depuis, ce qui était le
but :

| Demandé | État | Pourquoi pas de substitut |
|---|---|---|
| Vidéo | **4 danses camerounaises**, rapatriées de Commons sous CC BY-SA | — |
| Photographies | **47 images**, auteurs nommés, licences libres | — |
| Chant, musique enregistrés | rien de collecté | Les treize enregistrements du vocabulaire sont des **mots isolés**. Les ranger sous « chants » serait faux, et rendrait le reste du fil indigne de confiance. |

### Un avis n'est pas une source

Les commentaires et les avis ouvrent une porte nouvelle : du texte écrit par des
utilisateurs. Elle ne contredit pas la règle fondatrice, à une condition qui
structure tout le module.

- Un commentaire porte toujours son auteur et sa date. Il n'entre **jamais** dans
  le corps d'une fiche, ni dans un quiz, ni dans un compte de documentation.
  L'avertissement du serveur voyage avec les avis et s'affiche **avant** eux.
- La **note** n'existe que sur un objet vendu. Le serveur refuse (422) de noter
  une fiche culturelle : une note mesure une appréciation, pas l'exactitude d'un
  fait. On ne vote pas sur ce qui est.
- Un contenu signalé est **masqué, pas supprimé**. La modération doit pouvoir le
  lire pour trancher, et un signalement abusif doit se voir — son auteur et son
  motif sont conservés.

### Une photo de produit vient de l'artisan, ou de personne

La boutique s'affiche en grille, avec jusqu'à six photos par objet, déposées par
l'artisan et servies depuis `media/products/`. Le format est reconnu **dans les
octets du fichier**, pas dans son nom ni dans l'en-tête annoncé par le navigateur :
les deux se falsifient.

Un produit sans photo affiche un cadre qui dit « Pas de photo ». C'est moins
avenant qu'une illustration générique, et c'est délibéré : un objet artisanal est
unique, et la photo d'un autre panier ferait croire à l'acheteur qu'il a vu le
sien. Le catalogue reste donc visuellement pauvre tant que les artisans n'ont pas
déposé leurs clichés — c'est un état du contenu, pas un défaut de l'écran.

### La médiathèque ne décrit pas ce qu'elle montre

Cinquante et un médias — quarante-sept photographies et quatre vidéos de danse —
viennent de Wikimedia Commons. Chacun porte trois choses sans lesquelles la
rediffusion serait illicite : **l'auteur, la licence, et l'adresse de sa page
d'origine**. Ce ne sont pas des mentions reléguées en bas de fiche : le crédit est
sur la vignette, dès la grille.

`scripts/fetch_commons_media.py` refuse plus qu'il n'accepte. Vingt-sept candidats
ont été écartés : licence non libre, auteur absent, poids excessif, ou **aucun
rattachement au Cameroun**. Ce dernier filtre n'est pas du zèle : la recherche
Commons est lâche, et « Cameroon traditional dance » remontait des vidéos
indonésiennes. Les ranger sous « danse camerounaise » aurait été exactement ce que
la règle fondatrice interdit.

Il a coûté une vidéo qu'on aurait voulu garder — la seule d'un locuteur d'une
langue camerounaise (« Jean René speaking Medumba », Wikitongues, CC BY-SA 4.0).
Sa page Commons ne mentionne le Cameroun nulle part. La rattacher aurait été MBOA
qui affirme le lien : elle passera par une fiche sourcée, ou pas du tout.

Les titres affichés sont ceux des auteurs, et l'écran le dit. MBOA n'attribue ce
qu'on voit à aucun peuple ni à aucune tradition.

### Une boutique de démonstration ne se déguise pas

Le catalogue comptait un objet : de quoi juger ni une grille, ni une recherche, ni
des filtres. Huit boutiques et trente-cinq objets de **démonstration** ont donc été
ajoutés — sous quatre conditions, parce qu'un artisan est une personne et qu'un
objet artisanal affirme souvent quelque chose :

| | |
|---|---|
| `market.shops.is_demo` | exposé par l'API, affiché **sur la photo** de chaque carte |
| `cultural_claim_fr` | nul sur tous les objets. Les titres décrivent une matière et une forme, jamais une origine ni un usage rituel |
| Noms | des ateliers, jamais des personnes |
| Retrait | `python -m scripts.seed_market_demo --purge` |

### Une leçon dure trois à sept minutes, et le parcours a plus d'un nœud

Le chemin comptait un cours, une section, une unité et **une leçon** — laquelle
portait vingt-quatre exercices. Un parcours à un nœud ne ressemble à rien, et
vingt-quatre exercices contredisaient la règle de durée que le projet s'est donnée
(SS11).

`scripts/restructure_path.py` les a répartis en cinq leçons de trois à six,
regroupées par type d'exercice. **Aucun contenu n'a été créé** : les exercices
existaient, validés, issus du corpus sourcé. Les nouvelles leçons ont suivi le
circuit complet avec validation enregistrée — les triggers n'ont pas été
contournés.

### D'où viennent les voix d'une région

Le lot 9 prévoit d'écouter le patrimoine région par région. Mais **MBOA ne décrète
pas quelles langues se parlent où**. Ce rattachement vient d'une **fiche publiée**,
donc sourcée : c'est elle qui relie une langue à une région, et l'écran le dit —
« Basaa, établi par *Où parle-t-on le basaa ?* », avec un lien vers la fiche.

Les treize enregistrements du Littoral sont donc réels : ce sont les voix
Lingua Libre du corpus basaa, sous CC BY-SA 4.0. L'attribution voyage avec chaque
piste jusqu'à l'écran, parce que la licence l'exige.

Deux nuances que l'écran garde visibles :

- un mot peut être **attesté et enregistré sans que son sens soit écrit** : il
  affiche « sens non renseigné » plutôt qu'une glose inventée ;
- **aucune vidéo n'est au catalogue**, et l'encart le dit : MBOA n'en diffusera
  que sous licence établie, jamais d'illustration de remplissage.

Les favoris couvrent les deux natures — fiches et enregistrements. Un contenu
retiré du catalogue disparaît des favoris : on ne ressert pas ce qui a été
dépublié, même s'il a été aimé.

### Une configuration qui ne promet rien

Les huit étapes du lot 3 sont en place : les quatre premières avant l'inscription
(valeur, langue, niveau, rythme), les cinq suivantes juste après, car leurs
réponses s'enregistrent sur le compte.

Deux d'entre elles disent franchement ce qu'elles sont :

- **les notifications** recueillent un consentement ; aucun envoi n'est branché,
  et l'écran l'écrit ;
- **le test de positionnement** n'existe pas encore. L'étape distingue deux
  choses : ce que le corpus publié *permettrait* — le serveur le calcule, en
  exigeant assez de questions **et** au moins deux types d'exercices — et le fait
  que le test lui-même n'est pas construit. Un test bâti sur un seul type
  mesurerait une seule compétence, pas un niveau.

Le rythme choisi en minutes fixe l'objectif en XP du profil : les deux écrans ne
doivent pas se contredire, et un test le vérifie.

---

## 2. Prérequis

- **PostgreSQL 16+** (testé sur 18) — aucun Docker nécessaire
- **Python 3.12+**
- **Flutter 3.35+**

## 3. Installation

### 3.1 Base de données

```bash
# Créer le rôle applicatif et les deux bases (une seule fois)
psql -U postgres -c "CREATE ROLE mboa LOGIN PASSWORD 'mboa'"
psql -U postgres -c "CREATE DATABASE mboa_dev  OWNER mboa ENCODING 'UTF8'"
psql -U postgres -c "CREATE DATABASE mboa_test OWNER mboa ENCODING 'UTF8'"
```

### 3.2 API

```bash
cd mboa-api
python -m venv .venv
.venv/Scripts/python -m pip install -r requirements.txt   # Linux/macOS : .venv/bin/python

# Schéma : schémas, types, tables, triggers d'intégrité
.venv/Scripts/python -m app.db.init_db --reset

# Corpus de démonstration (télécharge la liste Lingua Libre si absente)
.venv/Scripts/python -m app.seed.seed_basaa

# Culture Hub : rubriques et fiches sourcées
.venv/Scripts/python -m app.seed.seed_culture

# Enregistrements servis en local : 13 fichiers, 1,3 Mo, une fois pour toutes
.venv/Scripts/python -m scripts.fetch_audio

# Médiathèque : photos et vidéos libres depuis Wikimedia Commons (~124 Mo)
# `--dry-run` liste les candidats et les motifs de refus, sans rien télécharger
.venv/Scripts/python -m scripts.fetch_commons_media

# Répartit les exercices validés en leçons de 3 à 7 minutes (SS11)
.venv/Scripts/python -m scripts.restructure_path

# Boutiques de démonstration, marquées comme telles. `--purge` les retire.
.venv/Scripts/python -m scripts.seed_market_demo

# Démarrage
.venv/Scripts/python -m uvicorn app.main:app --port 8010
```

Les deux derniers ne sont pas indispensables : ils donnent du volume pour juger
les écrans. `restructure_path` corrige en revanche un défaut réel — sans lui, le
parcours ne compte qu'une leçon de vingt-quatre exercices.

- Documentation interactive : <http://127.0.0.1:8010/docs>
- État du système : <http://127.0.0.1:8010/health>

Les réglages se font dans `mboa-api/.env` (hôte, port, base, secret JWT).

### 3.3 Application

```bash
cd mboa_app
flutter pub get
flutter run -d chrome                 # test local rapide
flutter run -d <appareil-android>     # cible réelle
```

Pour un émulateur Android, l'API n'est pas sur `127.0.0.1` :

```bash
flutter run --dart-define=API_BASE=http://10.0.2.2:8010
```

---

## 4. Tests

```bash
# Backend — règles d'intégrité, répétition espacée, générateur, correcteurs, API
cd mboa-api && .venv/Scripts/python -m pytest -q

# Flutter — logique, widgets, et parcours complet contre l'API réelle
cd mboa_app && flutter test
```

> Le test `test/e2e_flow_test.dart` interroge la **vraie API** : elle doit tourner sur le
> port 8010. Il déroule le scénario complet : onboarding → inscription → parcours → leçon →
> écoute → réponses → feedback → fin de leçon → XP → révision du lendemain → profil.

Pour régénérer les captures d'écran de `docs/captures/` :

```bash
cd mboa_app && flutter test test/e2e_flow_test.dart --dart-define=CAPTURE=true
```

Démonstrations en ligne de commande, sans application :

```bash
cd mboa-api
.venv/Scripts/python scripts/demo_parcours.py        # parcours de l'apprenant
.venv/Scripts/python scripts/demo_contribution.py    # la contribution débloque les exercices
.venv/Scripts/python -m scripts.demo_administration  # candidature, décision motivée, journal
.venv/Scripts/python -m scripts.demo_attestation     # attestation PDF + aperçu
.venv/Scripts/python -m scripts.demo_marche          # boutique, commande, livraison
```

## 4 bis. Premier administrateur, puis habilitations

Le premier administrateur ne peut pas être créé depuis la console : il faut bien que quelqu'un
ouvre la porte. Ce geste se fait en ligne de commande, sur la machine qui héberge la base, et
il est **inscrit au journal** comme n'importe quel autre — avec la mention qu'il vient de la
ligne de commande :

```bash
cd mboa-api
.venv/Scripts/python -m scripts.grant_admin --email ana@example.com --reason "Porteuse du projet"
.venv/Scripts/python -m scripts.grant_admin --list
```

Le lien « Administration » apparaît alors sur l'écran Profil. Les habilitations suivantes se
donnent depuis la console, via les candidatures : un apprenant dépose sa demande depuis son
profil, l'administrateur statue avec un motif.

L'habilitation directe reste possible en ligne de commande, pour amorcer une base vide :

```bash
.venv/Scripts/python -m scripts.grant_specialist --email ana@example.com --language bas
.venv/Scripts/python -m scripts.grant_specialist --list
```

---

## 5. Organisation du dépôt

```
docs/phase0/     livrables d'étude (inventaire des sources, pédagogie, architecture, design,
                 roadmap, alignement sur les maquettes)
docs/captures/   captures d'écran produites par les tests
docs/captures/maquette/  maquettes de référence (lots 3 à 12)
mboa-api/        API FastAPI
  app/db/        schéma, triggers d'intégrité, initialisation
  app/modules/   provenance, corpus, audio, apprentissage, exercices, progression, révision,
                 cms, traduction, culture (fiches, régions, fil, quiz, commentaires),
                 administration, attestations, place de marché (boutique, photos, logistique),
                 configuration initiale
  app/seed/      corpus de démonstration issu de sources réelles
  media/         enregistrements, photos et vidéos servis localement (125 Mo, hors dépôt)
  tests/         225 tests
mboa_app/        application Flutter
  lib/design/    design system (jetons, thème, composants) — aligné sur les maquettes
  lib/features/  onboarding, auth, accueil, parcours, leçon, exercices, progression, profil,
                 contribution, traduction, culture (fil, régions, médias, quiz), social
                 (commentaires et avis), administration, habilitation, attestations,
                 place de marché
  test/          171 tests, dont le parcours complet et un audit d'interface
```

---

## 6. Provenance des données

Aucun mot basaa n'a été inventé. Le corpus de démonstration provient de :

| Source | Licence | Usage |
|---|---|---|
| [Lingua Libre — prononciations basaa](https://commons.wikimedia.org/wiki/Category:Lingua_Libre_pronunciation-bas) | **CC BY-SA 4.0** | 13 formes + audio de locuteurs (attribution affichée dans l'application) |
| [Common Voice 27.0 — Basaa](https://mozilladatacollective.com/datasets/cmu61xynu00n7nq079r4v8398) | **CC0-1.0** | 12 h validées, 5 226 phrases — enregistré comme source, import à venir |
| [Hyman 2003, « Basaá (A.43) »](https://linguistics.berkeley.edu/~hyman/Basaa_Chapter.pdf) | © Routledge | faits linguistiques ; les explications MBOA sont rédigées à nouveau, jamais recopiées |
| [Glottolog — basa1284](https://glottolog.org/resource/languoid/id/basa1284) | CC BY 4.0 | métadonnées de la langue |

Deux points de rigueur visibles dans la démonstration :

1. **105 enregistrements sont bloqués en `TO_VERIFY`** : leurs étiquettes sont en français et
   rien ne permet de savoir, sans écoute par un locuteur natif, si la forme écrite est du basaa.
   Le système refuse de les publier.
2. **Aucune glose française n'est renseignée.** Les formes sont attestées et enregistrées, mais
   leur sens reste à saisir par un locuteur natif. Conséquence directe et voulue : le générateur
   ne produit que des exercices d'écoute, et **aucun exercice de sens**.

La validation du corpus de démonstration est signée « DEMO — validateur de démonstration, à
remplacer par un locuteur natif » : elle est tracée comme telle dans le journal d'audit.
