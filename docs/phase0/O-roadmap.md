# MBOA — Phase 0 : Roadmap d'implémentation

Livrable **O**. Statut : soumis pour validation.

Hypothèse d'équipe : 1 dev backend, 2 devs Flutter, 1 designer produit, 1 profil data/NLP à mi-temps (à partir de la Phase 9), 1 chef de projet contenu, **2 spécialistes culturels validateurs par langue** (externes, rémunérés), 1 ingénieur du son / preneur de son (ponctuel). Durées en semaines calendaires, deux pistes en parallèle : **piste CONTENU** (linguistique) et **piste PRODUIT** (logiciel).

> Le chemin critique n'est pas le code : c'est **l'obtention des licences et la constitution du corpus validé**. Une leçon ne peut pas exister avant son contenu. Les deux pistes démarrent donc simultanément.

---

## Vue d'ensemble

| # | Phase | Piste | Sem. | Fin attendue |
|---|---|---|---|---|
| 0 | Recherche documentaire | contenu | 0-2 | ✅ **livrée ce jour** (ce dossier) |
| 1 | Corpus & provenance | contenu + backend | 1-8 | corpus N0 validé, CMS minimal |
| 2 | Design System | design | 1-4 | `mboa_design` livré et testé |
| 3 | Prototype UX du parcours | design | 3-6 | prototype cliquable validé |
| 4 | Fondations techniques | produit | 3-6 | monorepo, CI, schéma, OpenAPI |
| 5 | Auth & profils | produit | 6-9 | inscription → accueil vide |
| 6 | Learning Engine | produit | 8-13 | parcours servi par l'API |
| 7 | Exercise Engine | produit | 11-16 | 15 types d'exercices |
| 8 | Progression & gamification | produit | 15-18 | XP, streak, SRS, certificats |
| 9 | Audio | contenu + produit | 9-20 | audio humain sur 100 % des items N0 |
| 10 | Offline | produit | 18-22 | unités téléchargeables + sync |
| 11 | **Culture Hub** | contenu + produit | 20-25 | 30 contenus culturels publiés |
| — | **🎯 JALON MVP** | — | **~26** | **scénario §49 excellent, sur 2 langues** |
| 12 | Assistant RAG | produit | 26-30 | assistant sourcé |
| 13 | Traduction | produit + NLP | 28-34 | lexique V1, ASR expérimental |
| 14 | Marketplace | produit | 30-40 | achat + livraison bout en bout |
| 15 | Back-office complet | produit | 36-42 | CMS et admin complets |
| 16 | QA & optimisation | tous | 42-46 | publication stores |

---

## PHASE 1 — Corpus et système de provenance *(sem. 1-8)*

**Piste juridique (bloquante, à lancer la semaine 1)**
1. Courrier + dossier de partenariat à **Dr Pierre Emmanuel Njock et SIL Cameroun** (dictionnaire Basaa, 15 667 entrées).
2. Contact **Emmanuel Ngue Um** (Université de Yaoundé 1 / Institute of African Digital Humanities) — dataset ALCAM Basaa sous NOODL-1.0 (contact obligatoire) et expertise scientifique.
3. Contact **Éditions Terre Africaine** (dictionnaire Ewondo 2007) et **Resulam** (syllabaire Ewondo).
4. Contact **UY1 / UCAC** pour Owona 2004 (orthographe harmonisée) et Essono 2000, et pour recruter les validateurs.
5. Relecture juridique des conditions Mozilla Data Collective (CC0 + interdiction de ré-héberger) pour l'usage de l'audio Common Voice **dans l'application**.
6. Contrats de contributeur et **formulaires de consentement des locuteurs** (portée : lecture dans l'app, entraînement ASR, publication de dataset).

**Piste technique**
7. Schémas `prov`, `ref`, `corpus`, `audio` + triggers de statut (H2/H11).
8. CMS minimal (Flutter Web) : sources, références, saisie de vocabulaire / phrases / grammaire, file de validation.
9. Import des phrases CC0 Common Voice (883 ewo, 5 226 bas) en `raw_records` → normalisation → `TO_VERIFY`.

**Piste linguistique**
10. Constitution des 13 briques du corpus (§6 du cahier des charges) pour le périmètre N0 uniquement :
    - cibles : ~110 `VocabularyItem`, ~30 `ExampleSentence`, ~10 `GrammarRule`, ~10 `Dialogue`, alphabet et sons complets, **par langue**.
11. Double validation par des locuteurs natifs habilités (saisie ≠ validation, imposé en base).

**Sortie de phase** : corpus N0 `VALIDATED` pour Ewondo **et** Basaa, chaque item relié à une source dont la licence est documentée. **Aucune leçon n'est construite avant.**

---

## PHASE 2 — Design System *(sem. 1-4)*
Tokens (K1-K5) implémentés dans `mboa_design`, composants (K6), mascotte originale (3 itérations + validation culturelle), 4 motifs redessinés et documentés, tests golden de contraste et de `textScaler`. **Sortie** : paquet publié, storybook widgetbook, audit d'accessibilité.

## PHASE 3 — Prototype UX complet du parcours *(sem. 3-6)*
Prototype cliquable (Figma) du scénario §49 de bout en bout, 5 utilisateurs testés (3 jeunes au Cameroun, 2 diaspora), itération. **Sortie** : parcours validé, écrans M1 figés pour le MVP.

## PHASE 4 — Fondations techniques *(sem. 3-6)*
Monorepo Flutter (melos) + `mboa_api`, dépôt FastAPI, Docker Compose (Postgres+pgvector, Redis, MinIO), Alembic, CI (ruff, mypy, pytest, dart analyze, tests), export OpenAPI → génération du client, environnements dev/staging, Sentry. **Sortie** : `/health` en staging, pipeline verte.

## PHASE 5 — Authentification & profils *(sem. 6-9)*
Inscription (rôle LEARNER imposé), connexion, refresh rotatif, mot de passe oublié, profil, devices/FCM, demande de rôle + KYC, revue KYC côté admin, RBAC + tests de permissions. **Sortie** : parcours d'entrée complet jusqu'à un accueil vide.

## PHASE 6 — Learning Engine *(sem. 8-13)*
API `languages/courses/sections/units/lessons`, assemblage d'unité depuis le corpus validé, `content_releases`, écrans Parcours / Aperçu d'unité / squelette du player, états de déverrouillage (serveur). **Sortie** : le parcours Ewondo N0 Section 1 s'affiche depuis l'API.

## PHASE 7 — Exercise Engine *(sem. 11-16)*
Schémas de payload versionnés, `QuestionGenerator` + revue par lot dans le CMS, correcteurs serveur par type, 15 widgets Flutter, `FeedbackBar`. **Sortie** : une leçon complète jouable avec feedback ; tests de correction par type.

## PHASE 8 — Progression & gamification *(sem. 15-18)*
`xp_ledger`, streak avec fuseau horaire, objectif quotidien, SRS (SM-2 simplifié), file de révision, badges, statistiques, certificats PDF (worker) avec code de vérification, rappels push. **Sortie** : « je reviens le lendemain et je révise » fonctionne.

## PHASE 9 — Audio *(sem. 9-20, démarre tôt car long)*
Protocole d'enregistrement (locuteurs par variante, consentement, qualité A/B/C), sessions studio, transcodage (worker : WAV maître privé → Opus servi), choix des références de prononciation, versions lentes, `AudioButton` et exercices audio, `SPEAK` V1-V4 (écouter → ralentir → s'enregistrer → comparer, **sans score**). **Sortie** : 100 % des items N0 des deux langues ont un audio de locuteur natif validé.

## PHASE 10 — Offline *(sem. 18-22)*
Paquets d'unité + manifest, Drift, SyncQueue, `POST /sync` idempotent, résolution de conflits, gestion des téléchargements et du stockage, bannière hors-ligne. **Sortie** : une unité téléchargée est entièrement jouable en mode avion, progression resynchronisée sans perte (test automatisé).

## PHASE 11 — Culture Hub *(sem. 20-25)*
Modèle `culture`, CMS culturel avec sources obligatoires, Hub + filtres (région / communauté / aire culturelle), détail avec sources citées, **cartes « Le savais-tu ? » liées aux unités**, avis. Contenus : contacts MINAC, Musée national, universités, associations reconnues ; 30 contenus validés au lancement. **Sortie** : langue et culture reliées dans le produit.

### 🎯 JALON MVP (~semaine 26)
Critères de sortie mesurables :
- Le scénario §49 se déroule sans accroc sur Android bas de gamme, en ligne **et** hors ligne.
- Ewondo N0 et Basaa N0 publiés : 12 unités, ~44 leçons, ~110 items, audio natif à 100 %, 30 contenus culturels.
- 100 % des items publiés ont une source et une validation humaine tracées.
- Rétention J7 ≥ 25 % et taux de complétion de l'unité 1 ≥ 70 % en bêta fermée (100 testeurs).
- 0 régression sur les suites : statuts, permissions, correction, SRS, sync.

---

## PHASE 12 — Assistant RAG *(sem. 26-30)*
Indexation pgvector du corpus **validé uniquement**, retrieval hybride, garde-fous (refus explicite en l'absence de sources, post-vérification qu'aucun mot en langue nationale n'est inventé), affichage des sources, historique. **Sortie** : l'assistant répond ou dit qu'il ne sait pas — jamais d'invention.

## PHASE 13 — Traduction *(sem. 28-34)*
V1 mode LEXICON (recherche dans le corpus validé, avec audio et source). En parallèle piste NLP : entraînement ASR sur Common Voice CC0 (modèle de base à licence commerciale compatible), évaluation WER documentée ; MT expérimentale (MT560 EN-BAS) **hors production**. Traçabilité complète (`model`, `model_version`, `confidence`, validation humaine). **Aucune promesse de traduction libre ni de TTS générique.**

## PHASE 14 — Marketplace *(sem. 30-40)*
Produits artisans (avec l'histoire de l'œuvre liée au Culture Hub), panier, commandes et machine à états, agrégateur Mobile Money (MTN MoMo / Orange Money) avec webhooks idempotents, livraison (disponibilité, assignation, preuve, incidents), confirmation de réception, abonnements et paywall, payouts artisans. **Sortie** : un achat réel de bout en bout en sandbox puis en production limitée.

## PHASE 15 — Back-office complet *(sem. 36-42)*
CMS complet (tous types de contenu, éditeur de blocs, générateur d'exercices, publication de versions), gestion audio, statistiques admin, paiements, paramètres, journaux d'audit, feature flags.

## PHASE 16 — QA, optimisation, publication *(sem. 42-46)*
Tests de charge, budgets de performance sur appareils modestes, audit sécurité (OWASP MASVS + ASVS), RGPD (export / suppression de compte pour la diaspora européenne), audit d'accessibilité externe, bêta fermée puis ouverte, publication Play Store puis App Store, documentation (technique, éditoriale, contributeur).

---

## Jalons de décision (Go / No-Go)

| Sem. | Décision | Critère |
|---|---|---|
| 4 | **Go corpus Basaa** | accord Njock/SIL obtenu, ou bascule sur production 100 % originale (budget +) |
| 4 | **Go corpus Ewondo** | accord Terre Africaine / Resulam / UY1, ou production originale |
| 6 | Go architecture | prototype UX validé + pipeline CI verte |
| 8 | **Go construction des leçons** | corpus N0 VALIDATED disponible pour au moins une langue |
| 20 | Go MVP | audio natif complet, offline fonctionnel |
| 30 | Go marketplace | agrégateur de paiement contractualisé, politique KYC validée |
| 34 | Go ASR | WER mesuré acceptable **et** licence du modèle de base compatible avec un usage commercial ; sinon `SPEAK` reste sans score |

## Risques principaux et parades

| Risque | Impact | Parade |
|---|---|---|
| Refus ou lenteur des ayants droit (dictionnaires) | bloque le corpus | démarrer les 6 contacts dès la semaine 1 ; plan B = production originale par les spécialistes (prévoir le budget) |
| Pénurie de validateurs natifs qualifiés | bloque tout passage à VALIDATED | conventionner UY1 / UCAC dès la Phase 1 ; rémunérer ; prévoir 2 validateurs par langue minimum |
| Qualité audio insuffisante | produit incomplet (§18) | protocole d'enregistrement, grade qualité, réenregistrement des items grade C |
| Tentation d'utiliser un LLM comme source linguistique | **atteinte à l'intégrité du projet** | contrainte en base (source obligatoire) + revue humaine + post-vérification de l'assistant |
| Licences non commerciales (MMS, datasets HF) utilisées par erreur | risque juridique | champ `license` + `usable_for` obligatoire sur chaque source ; contrôle en CI sur les datasets importés |
| Dérive de périmètre vers la marketplace avant un MVP d'apprentissage excellent | échec produit (§49) | jalon MVP bloquant : aucune ligne de marketplace avant la semaine 30 |
| Appareils Android modestes | abandon | budgets de performance mesurés dès la Phase 6 sur un appareil de référence bas de gamme |
