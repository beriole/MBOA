# MBOA — Phase 0 : Architecture Flutter (I) et FastAPI (J)

Statut : soumis pour validation. Aucun code écrit.

---

## I. Architecture Flutter

### I1. Principes
- **Feature-first**, séparation `data / domain / presentation` dans chaque feature dont la complexité le justifie (learning, exercises, review, offline, marketplace). Les features simples (profile, notifications) restent en `presentation + data`.
- **Aucune règle métier critique dans le client** : correction des exercices, calcul XP, SRS, déverrouillage, prix → serveur. Le client applique une **copie locale déterministe** des règles uniquement pour le mode hors-ligne, et le serveur a toujours le dernier mot lors de la sync.
- **Aucun contenu de cours codé en dur** : tout vient de l'API ou du cache local d'une `content_release` téléchargée.
- Android d'abord (minSdk 24, optimisé pour appareils modestes : ≤ 150 MB d'installation, images WebP, audio Opus 32 kbps), iOS compatible.
- Deux cibles depuis la même codebase : `mboa_app` (mobile) et `mboa_admin` (Flutter Web, back-office) partageant `packages/mboa_core` et `packages/mboa_api`.

### I2. Organisation du dépôt

```
mboa_flutter/                      (melos monorepo)
├─ apps/
│  ├─ mboa_app/                     application mobile
│  │  └─ lib/
│  │     ├─ app/                    MboaApp, router, theme wiring, bootstrap, DI (ProviderScope)
│  │     ├─ core/                   (spécifique app) : connectivité, permissions, analytics, audio player/recorder services, l10n
│  │     └─ features/
│  │        ├─ auth/                data · domain · presentation
│  │        ├─ onboarding/          presentation (choix langue, niveau, objectif quotidien)
│  │        ├─ home/                presentation (assemblage des widgets des autres features)
│  │        ├─ languages/           data · presentation
│  │        ├─ learning/            data · domain · presentation   (parcours, sections, unités, leçons, player de leçon)
│  │        ├─ exercises/           domain · presentation           (moteur d'exercices : 1 widget par type, registre de types)
│  │        ├─ review/              data · domain · presentation   (SRS local, révision quotidienne)
│  │        ├─ progress/            data · domain · presentation   (XP, streak, objectif, stats)
│  │        ├─ pronunciation/       presentation                    (écouter / ralentir / s'enregistrer / comparer)
│  │        ├─ offline/             data · domain                   (téléchargement d'unités, SyncQueue, résolution)
│  │        ├─ culture/             data · presentation
│  │        ├─ translation/         data · presentation
│  │        ├─ assistant/           data · presentation
│  │        ├─ marketplace/  cart/  checkout/  orders/
│  │        ├─ subscription/
│  │        ├─ notifications/
│  │        └─ profile/
│  └─ mboa_admin/                   back-office Flutter Web (CMS éditorial, validation, KYC, stats)
└─ packages/
   ├─ mboa_design/                  design system : tokens, ThemeData M3, composants (MboaButton, MboaCard, FeedbackBanner, PathNode…), mascotte, icônes
   ├─ mboa_api/                     client généré depuis l'OpenAPI FastAPI (dio + freezed + json_serializable), interceptors (auth refresh, retry, ETag)
   ├─ mboa_core/                    modèles de domaine partagés, Result/Failure, utilitaires NFC, formatage
   └─ mboa_storage/                 Drift : schéma local (content cache, progress, sync queue), DAOs
```

### I3. Couches d'une feature (exemple `learning`)

```
features/learning/
├─ data/
│  ├─ datasources/   learning_remote_ds.dart (mboa_api) · learning_local_ds.dart (Drift)
│  ├─ repositories/  learning_repository_impl.dart  (stratégie : cache-first si unité téléchargée, sinon network-first)
│  └─ mappers/
├─ domain/
│  ├─ entities/      Course, Section, Unit, Lesson, LessonBlock
│  ├─ repositories/  learning_repository.dart (interface)
│  └─ usecases/      get_path.dart · start_lesson.dart · complete_lesson.dart
└─ presentation/
   ├─ providers/     path_provider.dart (AsyncNotifier), lesson_session_controller.dart (StateNotifier : machine à états de la session)
   ├─ screens/       path_screen.dart · unit_intro_screen.dart · lesson_player_screen.dart · lesson_result_screen.dart
   └─ widgets/       path_node.dart · section_header.dart · progress_ring.dart
```

### I4. Machine à états de la session de leçon (`LessonSessionController`)

```
idle → loading → ready(block[0]) → answering(exercise) → feedback(correct|incorrect) → (next) … → recap → completed(result)
                                                       ↘ paused (app en arrière-plan : état persisté en local)
```
Chaque `attempt` est écrit localement (Drift) **avant** l'envoi réseau ; `client_attempt_id` UUID garantit l'idempotence côté serveur.

### I5. Offline-first

- **Téléchargement** : `POST /content/units/{id}/package` → manifest (JSON des leçons/exercices publiés + liste d'assets). Le client télécharge les assets (Opus, WebP) dans le stockage app, vérifie les checksums, marque l'unité `downloaded(version)`.
- **Stockage** : Drift (SQLite) — tables `cached_units`, `cached_lessons`, `cached_exercises`, `cached_assets`, `local_attempts`, `local_lesson_progress`, `local_review_items`, `sync_queue`.
- **SyncQueue** : événements ordonnés (`client_seq`), envoyés par lots à `POST /sync` dès retour réseau (`connectivity_plus`) ; réponse serveur = état canonique (`progress`, `review`, `xp`, `streak`) qui **écrase** l'état local.
- **Conflits** : voir H7 ; le client ne fait que rejouer, il n'arbitre pas.
- **Éviction** : l'utilisateur choisit les unités à garder ; alerte si < 200 MB libres.

### I6. Packages retenus et justification

| Package | Usage | Justification |
|---|---|---|
| `flutter_riverpod` + `riverpod_annotation` | état, DI | testable, compile-safe, pas de BuildContext dans la logique |
| `go_router` | navigation, deep links, guards de rôle | standard Flutter, typed routes |
| `dio` | HTTP | interceptors (refresh JWT, retry, cache ETag), upload multipart |
| `freezed` + `json_serializable` | modèles immuables | génération depuis OpenAPI |
| `drift` | base locale | SQL typé, migrations, requêtes réactives (préféré à Isar : maintenance active, SQL standard) |
| `flutter_secure_storage` | tokens | Keystore / Keychain |
| `just_audio` | lecture audio (vitesse 0.75× pour « ralentir ») | fiable, gapless, playback rate |
| `record` | enregistrement voix | simple, formats compatibles |
| `cached_network_image` + `flutter_svg` | images, icônes | cache disque, SVG du design system |
| `connectivity_plus` | détection réseau | déclenche la sync |
| `permission_handler` | micro, notifications | |
| `intl` + `flutter_localizations` | i18n FR / EN de l'interface | |
| `flutter_animate` | micro-animations de feedback | léger, déclaratif ; désactivé si « réduire les animations » |
| `firebase_messaging` | push | rappels quotidiens |
| `sentry_flutter` | crash reporting | |
| non retenus pour le MVP | `video_player` (pas de vidéo en N0), toute lib de charts (stats en widgets custom), lib d'ASR embarquée (pas de modèle validé) | |

### I7. Accessibilité et performance (règles de build)
- Tout widget interactif : `Semantics(label)`, cible ≥ 48 dp, contraste ≥ 4.5:1 vérifié par test golden.
- Information jamais portée uniquement par la couleur : icône ✓/✗ + texte + couleur.
- `MediaQuery.textScaler` respecté jusqu'à 1.3× sans débordement (tests widget dédiés).
- Sous-titre / transcription affichée pour chaque audio ; option « alternative au son » (afficher la forme écrite d'abord).
- Budgets : premier écran < 2 s sur Android bas de gamme ; leçon chargée depuis le cache < 300 ms ; jamais plus de 3 audios préchargés (le suivant et le précédent).

---

## J. Architecture FastAPI

### J1. Principes
- **Monolithe modulaire** : un déploiement, des modules à frontières nettes (`router → service → repository`), communication inter-modules par services (pas d'accès direct aux tables d'un autre module).
- Python 3.12, FastAPI, Pydantic v2, SQLAlchemy 2.0 async (asyncpg), Alembic, Redis (cache + files d'attente), workers **ARQ**, stockage S3 compatible (MinIO en dev), OpenAPI exportée pour générer `mboa_api` (Flutter).
- Sécurité : JWT access (15 min) + refresh rotatif (30 j, révocation en base), Argon2id, RBAC + permissions par ressource, rate limiting (Redis, par IP et par utilisateur), validation stricte des uploads (type MIME sniffé, taille, antivirus optionnel), audit des actions admin, journaux de sécurité structurés.

### J2. Arborescence

```
mboa_api/
├─ app/
│  ├─ main.py                      création app, middlewares, montage des routers, /health, /metrics
│  ├─ core/
│  │  ├─ config.py                 pydantic-settings
│  │  ├─ db.py                     engine async, session, base declarative, fonctions is_nfc
│  │  ├─ security.py               JWT, hashing, dépendances current_user / require_roles / require_permission
│  │  ├─ storage.py                S3 (URLs signées, buckets : public-media, private-audio-master, kyc, sources)
│  │  ├─ cache.py                  Redis
│  │  ├─ errors.py                 exceptions → réponses problem+json
│  │  ├─ pagination.py, i18n.py, audit.py, rate_limit.py
│  ├─ modules/
│  │  ├─ auth/            router · service · repository · schemas · models
│  │  ├─ users/           profils, devices, rôles, role_requests
│  │  ├─ languages/       languages, variants, regions, cultural_areas, communities
│  │  ├─ provenance/      sources, source_documents, references, contributors, validations  ← utilisé par corpus, culture, audio
│  │  ├─ corpus/          vocabulary, sentences, grammar, dialogues, proverbs, stories, import pipeline, workflow de statuts
│  │  ├─ audio/           speakers, sessions, assets, transcodage (worker), références de prononciation, user_recordings
│  │  ├─ learning/        courses, sections, units, lessons, blocks, content_releases, packaging hors-ligne
│  │  ├─ exercises/       types, schémas de payload, QuestionGenerator, correction (answer checker par type)
│  │  ├─ progress/        sessions de leçon, attempts, lesson_progress, calcul XP, sync
│  │  ├─ review/          SRS (SM-2 simplifié), file de révision
│  │  ├─ gamification/    streaks, daily goals, achievements, certificates (worker PDF)
│  │  ├─ culture/         contenus, catégories, médias, liens vers leçons
│  │  ├─ translation/     lexicon lookup (V1), interface modèle (V2+), traçabilité
│  │  ├─ assistant/       RAG : indexation (worker), retrieval pgvector, génération LLM, citations
│  │  ├─ marketplace/     products, images
│  │  ├─ orders/          cart, orders, machine à états
│  │  ├─ payments/        agrégateur Mobile Money, webhooks idempotents
│  │  ├─ delivery/        couriers, deliveries, incidents, preuve de livraison
│  │  ├─ subscriptions/   plans, entitlements (ce que débloque un plan), expiration (worker cron)
│  │  ├─ kyc/             documents, revue admin
│  │  ├─ notifications/   FCM, préférences, rappels (worker cron)
│  │  └─ administration/  settings, audit, stats, gestion comptes, feature flags
│  ├─ shared/             enums (content_status, exercise_type…), mixins SQLAlchemy (provenance, timestamps), schémas communs
│  └─ workers/            arq settings ; tâches : transcode_audio, generate_certificate, index_embeddings, send_push, expire_subscriptions, build_unit_package, import_batch_normalize
├─ alembic/
├─ tests/                 unit · api (httpx) · repository · permissions · workflow de validation · sync · paiements (mock provider)
├─ scripts/               export_openapi.py, seed_reference_data.py (langues, régions, catégories — pas de contenu linguistique)
└─ docker-compose.yml     api, worker, postgres(pgvector), redis, minio
```

### J3. Contrat d'API (v1) — extrait structurant

Préfixe `/api/v1`. Réponses JSON ; erreurs au format `application/problem+json`. Pagination par curseur. Toutes les routes de contenu public renvoient **uniquement** `status = PUBLISHED`.

**Auth & profil**
```
POST /auth/register            → rôle LEARNER imposé
POST /auth/login · POST /auth/refresh · POST /auth/logout · POST /auth/password/forgot · POST /auth/password/reset
GET  /me · PATCH /me · POST /me/devices · DELETE /me · GET /me/export   (RGPD)
POST /me/role-requests         (ARTISAN | CULTURAL_SPECIALIST | COURIER) + KYC
```

**Langues & parcours (public / apprenant)**
```
GET  /languages                                  → [{id, iso639_3, name, variants[], courses_count}]
GET  /languages/{id}/courses
GET  /courses/{id}                               → cours + sections (résumé)
GET  /courses/{id}/sections                      → sections avec unités et état par utilisateur (LOCKED/AVAILABLE/…)
GET  /units/{id}                                 → unité + leçons + objectif + carte culture liée
GET  /lessons/{id}                               → blocs + exercices (payload sans la réponse)
POST /lessons/{id}/start                         → lesson_session_id
POST /exercises/{id}/attempt                     {session_id, client_attempt_id, answer} → {is_correct, correct_answer, explanation, audio_url, xp_delta}
POST /lessons/{id}/complete                      {session_id} → {score, xp_total, streak, achievements_unlocked[], review_items_created}
GET  /progress                                   → parcours courant, XP, streak, objectif du jour, stats
GET  /review                                     → items dus aujourd'hui (≤ 10) sous forme d'exercices générés
POST /review/complete
POST /sync                                       {device_id, events[]} → état canonique (progress, review, xp, streak, conflicts[])
GET  /content/releases?language_id=              → manifest des versions publiées
POST /content/units/{id}/package                 → URL signée du paquet hors-ligne + manifest d'assets
```

**Audio & prononciation**
```
GET  /audio/{asset_id}                           → URL signée Opus (+ version lente si existante)
POST /audio/pronunciation                        multipart {exercise_id, file} → {recording_id, playback_url}   (V1-V4 : aucun score)
```

**Culture**
```
GET  /culture/categories
GET  /culture?category=&region=&community=&language=&cursor=
GET  /culture/{id}                               → contenu + médias + sources citées
GET  /culture/{id}/related
POST /reviews                                    {target_type, target_id, rating, comment}
```

**Assistant & traduction**
```
POST /assistant/conversations · POST /assistant/conversations/{id}/messages   → réponse + sources[] (ids corpus/culture) ou message « pas assez de sources validées »
POST /translate                                  {source_language, target_language, text | audio_id} → {text, mode: LEXICON|MODEL, confidence, model, model_version, matches[]}
```

**CMS / spécialiste (`role: CULTURAL_SPECIALIST` + `validation_assignments`)**
```
GET/POST/PATCH /cms/languages · /cms/courses · /cms/sections · /cms/units · /cms/lessons · /cms/lesson-blocks
GET/POST/PATCH /cms/vocabulary · /cms/sentences · /cms/grammar-rules · /cms/dialogues · /cms/proverbs · /cms/stories
POST /cms/{type}/{id}/transition                 {to: TO_VERIFY | HUMAN_REVIEW | VALIDATED | PUBLISHED | REJECTED, comment, corrections}
GET  /cms/review-queue?language=&type=           → file de validation du spécialiste
GET/POST /cms/sources · /cms/sources/{id}/documents · POST /cms/references
POST /cms/imports                                (fichier + source_id) → batch ; GET /cms/imports/{id}/records ; POST /cms/imports/{id}/map
POST /cms/audio/sessions · POST /cms/audio/assets (multipart wav) · POST /cms/audio/assets/{id}/set-reference
POST /cms/exercises/generate                     {unit_id, types[]} → lot d'exercices HUMAN_REVIEW
POST /cms/culture · PATCH /cms/culture/{id} · POST /cms/culture/{id}/links
POST /cms/releases                               → publie une version de contenu (calcule le manifest)
```

**Marketplace, commandes, paiements, livraison, abonnements** (Phase 14, structure conforme au cahier des charges initial)
```
GET /products · GET /products/{id} · POST /cart/items · GET /cart · POST /orders · GET /orders/{id} · POST /orders/{id}/confirm-receipt
POST /payments/initiate · POST /payments/webhook/{provider}
GET /artisan/products · POST /artisan/products · PATCH /artisan/products/{id} · GET /artisan/orders · PATCH /artisan/orders/{id}/status
PATCH /courier/availability · GET /courier/deliveries · PATCH /courier/deliveries/{id}/status · POST /courier/deliveries/{id}/proof · POST /courier/deliveries/{id}/incident
GET /plans · POST /subscriptions · GET /me/subscription
```

**Administration**
```
GET /admin/users · PATCH /admin/users/{id} (block, activate, roles) · GET /admin/kyc · PATCH /admin/kyc/{id}
GET /admin/stats · GET /admin/payments · GET/PATCH /admin/settings · GET /admin/audit-logs · GET/PATCH /admin/feature-flags
```

### J4. Règles métier côté serveur (non déléguées au client)
1. Correction d'un exercice (`answer_checker` par type, tolérances lues dans `platform_settings`).
2. Attribution d'XP, mise à jour du streak (fuseau horaire de l'utilisateur), objectif quotidien.
3. SRS : création / mise à jour des `review_items` après chaque attempt.
4. Déverrouillage des leçons / unités / checkpoints.
5. Génération des exercices (`QuestionGenerator`) et choix des distracteurs.
6. Transitions de statut de contenu (avec vérification des habilitations).
7. Prix, stock, statut des commandes, confirmation de paiement (webhook uniquement).
8. Droits d'accès au contenu premium (`entitlements`).

### J5. Assistant RAG — contrat de comportement
```
question → détection de langue → retrieval hybride (pgvector cosinus + full-text) sur assist.embeddings
        → filtre : status_snapshot ∈ {VALIDATED, PUBLISHED} ET langue/culture pertinente
        → si score max < seuil : réponse « Je n'ai pas encore suffisamment de sources validées pour répondre. » + suggestions de leçons
        → sinon : prompt système (ne jamais produire de mot ou de traduction absent du contexte ; citer les ids) → LLM → post-vérification : tout mot en langue nationale présent dans la réponse doit exister dans le contexte récupéré, sinon la phrase est retirée
        → réponse + sources[] affichées à l'utilisateur
```
Modèle LLM : accès par API, choisi en Phase 12 ; le module est écrit derrière une interface `LLMProvider` pour rester interchangeable.

### J6. Traduction — V1 réaliste
- **Mode LEXICON** : recherche exacte / floue (`lemma_toneless`, trigram) dans `vocabulary_items` et `example_sentences` VALIDATED ; renvoie les correspondances avec audio et source. Aucune génération.
- **Mode MODEL** (V2+) : uniquement après entraînement / évaluation documentée ; chaque réponse porte `model`, `model_version`, `confidence`, et un bouton « signaler / demander validation humaine » qui crée une tâche dans la file du spécialiste.
- Voix : ASR uniquement après un modèle entraîné sur Common Voice (CC0) avec licence de base compatible ; TTS : **pas de synthèse générique** pour ewo/bas au lancement (audio humain seulement).

### J7. Observabilité, qualité, déploiement
- Logs structurés (structlog) avec `request_id`, Sentry, métriques Prometheus (latence par route, taille des files ARQ, taux d'erreurs de sync, taux de succès webhook).
- Tests : pytest + httpx `AsyncClient` + testcontainers PostgreSQL ; suites obligatoires : workflow de statuts, permissions par rôle, correction d'exercices par type, SRS, sync idempotente, paiements (provider mocké).
- CI GitHub Actions : ruff + mypy + pytest ; `alembic upgrade head` sur base éphémère ; export OpenAPI → génération client Flutter → `dart analyze` + tests widget.
- Déploiement V1 : Docker Compose sur VPS (API ×2, worker, Postgres, Redis, MinIO ou R2, Traefik TLS) ; sauvegardes PG quotidiennes + WAL ; bucket `sources` et `kyc` chiffrés, jamais publics.
