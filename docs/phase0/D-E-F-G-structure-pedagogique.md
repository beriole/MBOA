# MBOA — Phase 0 : Structure pédagogique, arbres de parcours, types d'exercices

Livrables **D, E, F, G**. Statut : soumis pour validation.

> Principe : les arbres ci-dessous ne contiennent **aucun mot Ewondo ou Basaa**. Ils définissent des **objectifs communicatifs** et des **slots de contenu** (`vocab ×8`, `expr ×3`, `grammar ×1`, `dialogue ×1`, `culture ×1`). Chaque slot sera rempli exclusivement par des éléments du corpus au statut `VALIDATED`, via le pipeline de transformation pédagogique. Une leçon dont un slot n'est pas rempli ne peut pas être publiée.

---

## D. Structure pédagogique proposée

### D1. Niveaux internes MBOA (pas de correspondance CECRL revendiquée)

| Niveau | Nom | Objectif communicatif | Volume indicatif |
|---|---|---|---|
| N0 | **Initiation** | Reconnaître l'alphabet et les sons, saluer, se présenter, compter jusqu'à 10 | 1 section, 5 unités, ~20 leçons |
| N1 | **Débutant** | Communiquer dans les situations quotidiennes de base (famille, marché, temps, repas) | 2 sections, ~10 unités |
| N2 | **Élémentaire** | Raconter, décrire, demander / donner des informations, comprendre un dialogue simple | 2 sections, ~10 unités |
| N3 | **Intermédiaire** | Comprendre des textes et contes courts, exprimer opinions et projets | 2 sections, ~10 unités |

Le MVP livre **N0 complet** pour les deux langues, puis N1 section par section. Un `Certificate` n'est délivré qu'à la fin d'un niveau (checkpoint final réussi).

### D2. Hiérarchie de contenu

```
Language (ewo | bas)
└─ Course (par LanguageVariant + niveau d'entrée)
   └─ Section (thème macro, ~5 unités, se termine par un CHECKPOINT)
      └─ Unit (objectif communicatif, 3-5 leçons + révision + évaluation)
         └─ Lesson (3-7 min, 8-14 exercices)
            └─ LessonBlock (ordonné) : INTRO | TEACH | PRACTICE | CULTURE_CARD | RECAP
               └─ Activity → Exercise (type + payload généré depuis le corpus)
                  └─ Attempt → Result → ReviewItem (répétition espacée)
```

### D3. Anatomie d'une unité (règle d'assemblage)

| Élément | Règle |
|---|---|
| Objectif pédagogique | 1 phrase « À la fin de cette unité, je peux … » |
| Vocabulaire cible | 8 à 12 `VocabularyItem` VALIDATED, avec audio |
| Expressions | 2 à 4 `ExampleSentence` / expressions figées VALIDATED |
| Notion grammaticale | 1 `GrammarRule` VALIDATED, expliquée en ≤ 3 phrases + 2 exemples sourcés |
| Écoute | ≥ 3 exercices audio (`LISTEN_AND_CHOOSE`, `AUDIO_TO_WORD`) |
| Oral | ≥ 1 exercice `SPEAK` (V1 : écouter-répéter-s'enregistrer, sans score) |
| Contexte culturel | 0-1 `CulturalContent` VALIDATED lié (carte « Le savais-tu ? ») |
| Leçons | 3 à 5 leçons de 3-7 min |
| Révision | 1 leçon de révision générée automatiquement depuis les `ReviewItem` faibles de l'unité |
| Évaluation | 1 mini-test (10 exercices, seuil 80 %) → débloque l'unité suivante |

### D4. Anatomie d'une leçon (3-7 minutes)

```
INTRO      (10 s)  objectif en une ligne + mascotte
TEACH      (4×)    présentation d'un item : image + mot écrit + 🔊 audio + traduction
PRACTICE   (8-12×) exercices en alternance, difficulté croissante :
                   reconnaissance → association → production
CULTURE    (opt.)  carte « Le savais-tu ? » après un exercice réussi
RECAP      (20 s)  récap des items vus, XP gagnés, items à revoir
```

Contraintes : pas plus de 2 écrans de théorie consécutifs ; chaque item nouveau est vu ≥ 3 fois dans la leçon sous ≥ 2 formes d'exercice ; l'audio est disponible sur chaque écran qui affiche un mot.

### D5. Boucle pédagogique (VOIR → ÉCOUTER → ASSOCIER → COMPRENDRE → RÉPÉTER → PRODUIRE → ÊTRE CORRIGÉ → RÉVISER)

| Étape | Types d'exercice |
|---|---|
| VOIR / ÉCOUTER | TEACH card, `WORD_TO_AUDIO` |
| ASSOCIER | `IMAGE_CHOICE`, `WORD_MATCHING`, `MEMORY_GAME` |
| COMPRENDRE | `MULTIPLE_CHOICE`, `LISTEN_AND_CHOOSE`, `AUDIO_TO_WORD`, `TRUE_FALSE` |
| RÉPÉTER / PRODUIRE | `SPEAK`, `PRONUNCIATION`, `LISTEN_AND_TYPE`, `ORDER_WORDS`, `FILL_BLANK`, `TRANSLATION`, `DIALOGUE` |
| ÊTRE CORRIGÉ | feedback immédiat (bonne réponse + explication courte + 🔊) |
| RÉVISER | `ReviewItem` → leçon de révision quotidienne |

### D6. Répétition espacée (SRS)

États d'un `ReviewItem` : `NEW → LEARNING → (WEAK | REVIEW) → MASTERED`.

- Algorithme MVP : variante simplifiée de SM-2. Intervalles : 1 j → 3 j → 7 j → 14 j → 30 j. Une erreur ramène à `WEAK` et à l'intervalle 1 j.
- `mastery_score` ∈ [0, 1] = fonction de `correct_count / times_seen` pondérée par la récence.
- « Révision recommandée » sur l'accueil = jusqu'à 10 items dont `next_review ≤ now`, priorisés par `WEAK` puis par ancienneté.
- Les règles sont calculées **côté serveur** ; le client ne fait qu'appliquer localement en mode hors-ligne puis se resynchronise.

---

## E. Arbre complet du premier parcours EWONDO — Niveau N0 « Initiation »

`Course: ewo-N0` · Variante : Ewondo standard (Yaoundé), orthographe harmonisée (Owona 2004) · Sources cibles pour remplir les slots : E-02 / E-03 / E-10 / E-11 / E-12 (après accord), Common Voice ewo (phrases CC0 après HUMAN_REVIEW), enregistrements MBOA.

### Section 0 — Les sons de l'ewondo (pré-requis, facultatif mais recommandé)
Objectif : reconnaître l'alphabet AGLC utilisé pour l'ewondo (dont ǝ, ɛ, ɔ, ŋ) et entendre les tons.
- Unité 0.1 **Alphabet et lettres spéciales** — 3 leçons : voyelles ; consonnes et digraphes ; lettres spéciales. Slots : `alphabet_letters` (source : Owona 2004, Hartell 1993), audio par lettre.
- Unité 0.2 **Les tons** — 2 leçons : entendre haut / bas ; paires minimales tonales (uniquement si des paires VALIDATED existent). Slots : `tone_examples ×6`, audio.
- ★ Révision 0

### Section 1 — Premiers contacts
Objectif : établir un premier contact poli en ewondo.

| Unité | Objectif « Je peux… » | Vocab | Expr | Grammaire (slot) | Dialogue | Culture (slot) | Leçons |
|---|---|---|---|---|---|---|---|
| 1 **Saluer** | saluer selon le moment de la journée et répondre | 8 | 3 | formule de salutation / réponse | 1 (2 répliques ×2) | contexte social de la salutation (aînés, ordre de parole) | 4 |
| 2 **Se présenter** | dire mon nom, demander le nom de quelqu'un, dire d'où je viens | 8 | 3 | pronoms personnels sujets (1re/2e pers.) | 1 | les noms ewondo et leur signification (si source validée) | 4 |
| 3 **La famille** | nommer les membres de la famille proche | 10 | 2 | possession (« mon / ton ») | 1 | organisation familiale, place des aînés | 4 |
| 4 **Les nombres 1-10** | compter jusqu'à 10, donner mon âge | 10 | 2 | numéraux et accord (si pertinent) | 1 | — | 3 |
| 5 **Vie quotidienne** | dire ce que je fais (manger, boire, dormir, aller), remercier, dire au revoir | 10 | 4 | verbe au présent (forme de base) | 1 | repas et hospitalité | 4 |
| ★ **Révision S1** | items faibles des unités 1-5 | auto | | | | | 1 |
| 🏆 **CHECKPOINT S1** | 15 exercices mixtes, seuil 80 % | | | | | | 1 |

### Section 2 — Communiquer au quotidien
Objectif : se débrouiller dans les échanges simples.

| Unité | Objectif | Vocab | Expr | Grammaire (slot) | Dialogue | Culture (slot) | Leçons |
|---|---|---|---|---|---|---|---|
| 6 **Au marché** | nommer 8 aliments, demander le prix, dire « c'est cher » | 10 | 3 | question simple (« combien ? ») | 1 | le marché comme lieu social | 4 |
| 7 **Le temps et la journée** | dire matin / midi / soir, aujourd'hui / demain, jours | 10 | 2 | adverbes de temps | 1 | — | 3 |
| 8 **Le corps et la santé** | nommer les parties du corps, dire « j'ai mal à » | 10 | 2 | expression de l'état | 1 | médecine traditionnelle (si source validée) | 3 |
| 9 **La maison et le village** | nommer les lieux du village et de la maison, dire où je suis | 10 | 2 | locatifs (« à / dans ») | 1 | habitat traditionnel | 3 |
| 10 **Demander et remercier** | demander de l'aide, s'excuser, remercier, accepter / refuser | 8 | 4 | impératif poli / négation simple | 1 | politesse et respect des aînés | 4 |
| ★ **Révision S2** | | | | | | | 1 |
| 🏆 **CHECKPOINT S2 — fin N0** | 20 exercices, seuil 80 % → `Certificate N0` | | | | | | 1 |

**Total N0 Ewondo : 12 unités, ~44 leçons, ~110 VocabularyItem, ~30 ExampleSentence, ~10 GrammarRule, ~10 Dialogue, ~8 CulturalContent — tous à statut VALIDATED avant publication.**

---

## F. Arbre complet du premier parcours BASAA — Niveau N0 « Initiation »

`Course: bas-N0` · Variante : Basaa standard Mbɛnɛ (Pouma), orthographe du dictionnaire Njock 2019 · Sources cibles : B-01 (après accord), B-04 (après contact Ngue Um), B-10 / B-11 pour alphabet, sons, tons, classes nominales ; Common Voice bas (5 226 phrases CC0 après HUMAN_REVIEW) ; enregistrements MBOA.

### Section 0 — Les sons du basaa
- Unité 0.1 **Alphabet** — 3 leçons : voyelles (dont ɛ, ɔ) et longueur ; consonnes dont ɓ implosif et ŋ ; multigraphes. Sources : Makasso & Lee 2015, Hyman 2003, Hartell 1993.
- Unité 0.2 **Les 4 tons** — 2 leçons : haut / bas ; descendant / montant, avec paires minimales VALIDATED uniquement.
- ★ Révision 0

### Section 1 — Premiers contacts

| Unité | Objectif | Vocab | Expr | Grammaire (slot) | Dialogue | Culture (slot) | Leçons |
|---|---|---|---|---|---|---|---|
| 1 **Saluer** | saluer et répondre selon le moment | 8 | 3 | salutation / réponse | 1 | contexte social de la salutation | 4 |
| 2 **Se présenter** | nom, origine, demander le nom | 8 | 3 | pronoms sujets | 1 | le nom et le clan (si source validée) | 4 |
| 3 **La famille** | membres de la famille proche | 10 | 2 | classes nominales : singulier / pluriel des noms de personnes (Hyman 2003 §3) | 1 | organisation familiale | 4 |
| 4 **Les nombres 1-10** | compter, donner l'âge | 10 | 2 | accord des numéraux | 1 | — | 3 |
| 5 **Vie quotidienne** | actions de base, remercier, au revoir | 10 | 4 | verbe au présent | 1 | repas, hospitalité | 4 |
| ★ Révision S1 | | | | | | | 1 |
| 🏆 CHECKPOINT S1 | | | | | | | 1 |

### Section 2 — Communiquer au quotidien

| Unité | Objectif | Vocab | Expr | Grammaire (slot) | Dialogue | Culture (slot) | Leçons |
|---|---|---|---|---|---|---|---|
| 6 **Au marché** | aliments, prix | 10 | 3 | question « combien » | 1 | marché | 4 |
| 7 **Le temps et la journée** | moments, jours | 10 | 2 | adverbes de temps | 1 | — | 3 |
| 8 **Le corps et la santé** | parties du corps, « j'ai mal » | 10 | 2 | expression de l'état | 1 | — | 3 |
| 9 **La maison et le village** | lieux, localisation | 10 | 2 | locatifs (Boum 1983) | 1 | habitat | 3 |
| 10 **Demander et remercier** | aide, excuses, refus / acceptation | 8 | 4 | impératif poli / négation | 1 | politesse | 4 |
| ★ Révision S2 | | | | | | | 1 |
| 🏆 CHECKPOINT S2 — fin N0 → `Certificate N0` | | | | | | | 1 |

Les deux arbres sont volontairement **parallèles** (mêmes objectifs communicatifs) : cela permet un seul jeu d'illustrations, un seul générateur d'exercices et une comparaison de progression entre langues. Les **slots grammaticaux diffèrent** là où les langues diffèrent (ex. classes nominales explicites en Basaa dès l'unité 3, d'après Hyman 2003).

---

## G. Liste des types d'exercices (moteur générique)

Chaque `Exercise` = `type` + `payload` JSON (schéma versionné par type) + `answer_spec` + `generated_from` (liste des IDs corpus sources) + `validation_status`. Le client Flutter possède un **widget par type** ; ajouter un type = ajouter un schéma + un widget, sans toucher au reste.

| # | Type | Consigne type | Payload (généré depuis) | Réponse / correction | Distracteurs | MVP |
|---|---|---|---|---|---|---|
| 1 | `MULTIPLE_CHOICE` | « Que signifie … ? » (texte ou 🔊) | 1 VocabularyItem ou ExampleSentence + 3 distracteurs | choix unique, serveur | items VALIDATED de même catégorie grammaticale et même unité / section ; jamais un item non validé | ✅ |
| 2 | `IMAGE_CHOICE` | « Quel mot correspond à cette image ? » | 1 VocabularyItem avec image + 3 images d'autres items | choix unique | items concrets (noms) de la même unité | ✅ |
| 3 | `WORD_MATCHING` | « Associe les paires » | 4-5 VocabularyItem | toutes les paires correctes | — | ✅ |
| 4 | `TRANSLATION` | « Traduis » (langue cible ↔ FR/EN) | ExampleSentence | banque de mots (word bank) au MVP ; saisie libre plus tard | mots des autres phrases de l'unité | ✅ (word bank) |
| 5 | `ORDER_WORDS` | « Remets les mots dans l'ordre » | ExampleSentence tokenisée | ordre exact (tolérance orthographique nulle) | 1-2 mots intrus validés | ✅ |
| 6 | `FILL_BLANK` | « Complète » | ExampleSentence avec 1 token masqué | choix parmi 3-4 | même catégorie grammaticale | ✅ |
| 7 | `LISTEN_AND_CHOOSE` | 🔊 « Qu'as-tu entendu ? » | AudioAsset d'un item + 3 items écrits | choix unique | items phonétiquement proches si tag disponible, sinon même unité | ✅ |
| 8 | `LISTEN_AND_TYPE` | 🔊 « Écris ce que tu entends » | AudioAsset + forme écrite | comparaison normalisée (NFC, casse) ; tons : tolérance configurable par niveau | — | ✅ (N1+) |
| 9 | `SPEAK` | « Écoute puis répète » | AudioAsset de référence | V1-V4 : pas de score ; l'utilisateur s'enregistre, réécoute, valide lui-même (« Je l'ai dit » / « Encore une fois ») | — | ✅ (sans score) |
| 10 | `PRONUNCIATION` | idem avec comparaison de forme d'onde côte à côte | AudioAsset + enregistrement | V5+ uniquement (ASR validé) ; **aucun pourcentage affiché avant** | — | ⏳ |
| 11 | `WORD_TO_AUDIO` | « Quel audio correspond à ce mot ? » | item écrit + 3 AudioAsset | choix unique | même unité | ✅ |
| 12 | `AUDIO_TO_WORD` | 🔊 → choisir l'image / le mot | AudioAsset + 3 items | choix unique | même unité | ✅ |
| 13 | `TRUE_FALSE` | « Vrai ou faux : … signifie … » | item + traduction correcte ou fausse (distracteur validé) | booléen | traduction d'un autre item validé | ✅ |
| 14 | `DIALOGUE` | « Complète la conversation » | Dialogue VALIDATED (2-4 répliques), 1 réplique à choisir | choix unique | répliques d'autres dialogues validés | ✅ |
| 15 | `MEMORY_GAME` | « Retrouve les paires » (mot ↔ image ou mot ↔ audio) | 4-6 items | toutes les paires | — | ✅ (jeu de fin d'unité) |

**Règles du `QuestionGenerator`**
1. Entrée : uniquement des objets `VALIDATED` (vérifié par contrainte en base, pas seulement en code).
2. Un distracteur est toujours un item validé réel ; il ne « fabrique » jamais de forme. Une mauvaise réponse n'enseigne donc jamais une forme fausse.
3. Chaque exercice généré est stocké avec `generated_from[]` et `generator_version` ; il passe par `HUMAN_REVIEW` (revue par lot dans le CMS) avant `PUBLISHED`.
4. Tolérance de correction (tons, casse, espaces) définie par niveau dans `platform_settings`, pas dans le client.
5. Feedback : correct → « ✓ Correct » + XP ; incorrect → « ✗ Pas encore » + bonne réponse + explication (≤ 140 caractères, issue du corpus) + 🔊 + « Revoir ».
