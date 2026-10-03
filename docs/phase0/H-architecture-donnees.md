# MBOA — Phase 0 : Architecture de données (PostgreSQL)

Livrable **H**. Statut : soumis pour validation. Aucune migration n'a été écrite.

Conventions : PostgreSQL 16 ; clés `uuid` (v7) ; `created_at / updated_at` partout ; suppression logique (`deleted_at`) sur le contenu ; texte en Unicode **NFC** obligatoire (contrainte CHECK via fonction `is_nfc()`), collation `und-x-icu` pour le tri des langues nationales ; JSONB pour les payloads versionnés ; `pgvector` pour les embeddings de l'assistant.

---

## H1. Domaines et schémas

| Schéma PG | Domaine | Tables principales |
|---|---|---|
| `iam` | identité, rôles | users, roles, user_roles, refresh_tokens, devices, role_requests, kyc_documents |
| `ref` | référentiel linguistique et géographique | languages, language_variants, regions, cultural_areas, communities |
| `prov` | **provenance et validation** | sources, source_documents, source_references, contributors, content_validations, validation_assignments |
| `corpus` | données linguistiques brutes → validées | vocabulary_items, grammar_rules, example_sentences, dialogues, dialogue_turns, proverbs, stories, pronunciations, import_batches, raw_records |
| `audio` | actifs sonores | audio_assets, speakers, recording_sessions, pronunciation_references, user_recordings |
| `learn` | structure pédagogique publiée | courses, sections, units, lessons, lesson_blocks, activities, exercises, exercise_choices, content_releases |
| `progress` | progression apprenant | user_courses, lesson_progress, exercise_attempts, vocabulary_progress, review_items, sync_events |
| `game` | gamification | xp_ledger, streaks, daily_goals, achievements, user_achievements, certificates |
| `culture` | Culture Hub | cultural_categories, cultural_contents, cultural_media, cultural_sources, cultural_contributors, cultural_validations, cultural_links |
| `assist` | assistant RAG | conversations, messages, embeddings, retrieval_logs |
| `translate` | traduction | translation_requests, translation_models |
| `market` | marketplace | products, product_images, carts, cart_items, orders, order_items, order_status_history, deliveries, delivery_incidents, courier_availability, payouts |
| `billing` | paiements et abonnements | payments, plans, subscriptions, payment_webhooks |
| `notify` | notifications | notifications, notification_preferences |
| `admin` | administration | platform_settings, audit_logs, feature_flags |

---

## H2. Statuts de contenu (ENUM `content_status`)

```
DRAFT → SOURCE_FOUND → TO_VERIFY → HUMAN_REVIEW → VALIDATED → PUBLISHED
                                         ↘ REJECTED
```

Règles appliquées **en base** (triggers), pas seulement en code :
- Passage à `VALIDATED` impossible si `source_id IS NULL` **ou** si aucune ligne `content_validations` avec `decision = 'ACCEPT'` par un validateur ayant `validation_assignments.language_id` = langue de l'item.
- Passage à `PUBLISHED` impossible si `validated_by` = `created_by` (séparation saisie / validation).
- Un `Exercise` ne peut référencer (`generated_from`) que des items `VALIDATED` ou `PUBLISHED` (trigger de vérification).
- Toute transition écrit dans `admin.audit_logs`.

---

## H3. Provenance (schéma `prov`)

```
sources
  id, kind ENUM(BOOK, ARTICLE, THESIS, DICTIONARY_ONLINE, DATASET, RECORDING, INSTITUTION, ORAL_INFORMANT, MBOA_ORIGINAL)
  title, authors[], year, publisher, isbn_issn, url, license ENUM(CC0, CC_BY, CC_BY_SA, CC_BY_NC, NOODL, COPYRIGHT_AGREEMENT, COPYRIGHT_NO_AGREEMENT, PUBLIC_DOMAIN, UNKNOWN)
  agreement_ref (référence du contrat / courriel d'autorisation), agreement_expires_at
  usable_for ENUM[] (LEXICON, GRAMMAR, AUDIO, CULTURE, MT_TRAINING, ASR_TRAINING)
  consulted_at, notes

source_documents           -- un fichier / une page précise d'une source
  id, source_id, label, file_key (S3, accès restreint), url, pages, checksum

source_references          -- lien N-N entre un objet corpus et un endroit précis d'une source
  id, source_id, source_document_id, target_type, target_id
  locator (page, entrée, timestamp audio, URL d'entrée Webonary…), quote_excerpt (≤ 300 car., usage citation), consulted_at

contributors               -- personne physique ayant saisi / enregistré / validé
  id, user_id (nullable), display_name, role ENUM(LINGUIST, NATIVE_SPEAKER, TEACHER, RECORDIST, EDITOR), affiliation, languages[]

validation_assignments     -- qui a le droit de valider quoi
  id, contributor_id, language_id, scope ENUM[] (LEXICON, GRAMMAR, AUDIO, CULTURE, EXERCISE), active

content_validations        -- historique des décisions
  id, target_type, target_id, validator_contributor_id
  decision ENUM(ACCEPT, REJECT, REQUEST_CHANGES), comment, corrected_fields JSONB, decided_at
```

Chaque table de `corpus.*` et `culture.cultural_contents` porte les colonnes communes :
`status content_status, source_id (FK prov.sources, NOT NULL dès SOURCE_FOUND), created_by, validated_by, validated_at, published_at, version int, previous_version_id`.

---

## H4. Corpus (schéma `corpus`)

```
vocabulary_items
  id, language_id, variant_id
  lemma (NFC), lemma_toneless (généré : diacritiques tonales retirés, pour la recherche), orthography_version
  grammatical_category ENUM(NOUN, VERB, ADJ, ADV, PRON, NUM, PREP, CONJ, INTERJ, EXPR, OTHER)
  noun_class_sg, noun_class_pl (Basaa / Bantu : classes nominales, nullable)
  meaning_fr, meaning_en, gloss_short_fr, gloss_short_en
  ipa (nullable), tone_pattern (nullable, ex. "H-B"), variants[] (formes alternatives, chacune avec source_reference)
  image_asset_id (nullable), primary_audio_id (FK audio_assets, nullable)
  difficulty smallint (1-5), frequency_rank (nullable), tags[]
  + colonnes de statut / provenance communes
  UNIQUE (language_id, variant_id, lemma, grammatical_category, meaning_fr) -- anti-doublon

example_sentences
  id, language_id, variant_id, text (NFC), text_toneless, translation_fr, translation_en
  tokens JSONB (segmentation validée, utilisée par ORDER_WORDS / FILL_BLANK)
  vocabulary_item_ids[] (items illustrés), grammar_rule_ids[]
  primary_audio_id, difficulty, register ENUM(NEUTRAL, FORMAL, FAMILIAR)
  + statut / provenance

grammar_rules
  id, language_id, variant_id, title_fr, title_en, explanation_fr (≤ 600 car.), explanation_en
  category ENUM(PRONOUN, NOUN_CLASS, VERB_TENSE, NEGATION, QUESTION, POSSESSION, LOCATIVE, NUMERAL, OTHER)
  example_sentence_ids[] (≥ 2 exigés pour VALIDATED), difficulty
  + statut / provenance

dialogues
  id, language_id, variant_id, title_fr, context_fr, register, difficulty + statut / provenance
dialogue_turns
  id, dialogue_id, position, speaker_label, example_sentence_id (chaque réplique est une ExampleSentence validée)

proverbs
  id, language_id, text, literal_translation_fr, meaning_fr, usage_context_fr, cultural_content_id, primary_audio_id + statut / provenance
stories                 -- contes, textes
  id, language_id, title, body_segments JSONB [{text, translation_fr, audio_id}], summary_fr, cultural_content_id + statut / provenance
pronunciations
  id, target_type (VOCAB | SENTENCE), target_id, ipa, tone_pattern, notes, audio_asset_id + statut / provenance

import_batches          -- pipeline SOURCE EXTERNE → IMPORT → RAW → NORMALIZATION
  id, source_id, kind, file_key, row_count, imported_by, imported_at, normalizer_version, notes
raw_records
  id, import_batch_id, row_index, raw JSONB, normalized JSONB, mapped_target_type, mapped_target_id, status ENUM(RAW, NORMALIZED, MAPPED, DISCARDED)
```

Index : GIN trigram sur `lemma_toneless`, `meaning_fr` ; index partiel `WHERE status = 'PUBLISHED'` sur les colonnes servies à l'app.

---

## H5. Audio (schéma `audio`)

```
speakers
  id, contributor_id, display_code (anonymisé : "EWO-F-03"), language_id, variant_id, region_id, gender (nullable, facultatif), age_band, is_native, consent_document_key, consent_scope ENUM[] (APP_PLAYBACK, ASR_TRAINING, PUBLIC_DATASET), active
recording_sessions
  id, speaker_id, recorded_at, location, device, sample_rate, engineer_contributor_id, notes, quality_grade ENUM(A, B, C)
audio_assets
  id, session_id (nullable pour audio importé), speaker_id, language_id, variant_id
  file_key_original (wav, bucket privé), file_key_opus (servi à l'app), duration_ms, loudness_lufs, sample_rate
  target_type (VOCAB | SENTENCE | DIALOGUE_TURN | LETTER | TONE_EXAMPLE | STORY_SEGMENT), target_id
  license, source_id, reviewed_by, reviewed_at, quality ENUM(REFERENCE, GOOD, ACCEPTABLE, REJECTED)
  + statut
pronunciation_references     -- l'audio « de référence » choisi pour un item quand plusieurs existent
  id, target_type, target_id, audio_asset_id, is_slow_version, chosen_by, chosen_at
user_recordings              -- enregistrements des apprenants (SPEAK), rétention limitée
  id, user_id, exercise_id, file_key, duration_ms, created_at, expires_at, consent_for_research bool
```

---

## H6. Pédagogie publiée (schéma `learn`)

```
courses            id, language_id, variant_id, level ENUM(N0, N1, N2, N3), title_fr, title_en, description, cover_asset_id, status, position
sections           id, course_id, position, title_fr, title_en, objective_fr, status
units              id, section_id, position, title_fr, title_en, objective_fr, target_vocab_ids[], target_sentence_ids[], grammar_rule_id, dialogue_id, cultural_content_id, status
lessons            id, unit_id, position, kind ENUM(LESSON, REVIEW, CHECKPOINT), title_fr, estimated_minutes, xp_reward, status
lesson_blocks      id, lesson_id, position, kind ENUM(INTRO, TEACH, PRACTICE, CULTURE_CARD, RECAP), payload JSONB
activities         id, lesson_block_id, position, exercise_id
exercises          id, language_id, type exercise_type, schema_version, payload JSONB, answer_spec JSONB
                   generated_from JSONB [{type, id}], generator_version, difficulty, status, reviewed_by
exercise_choices   id, exercise_id, position, vocabulary_item_id | example_sentence_id | audio_asset_id | image_asset_id, is_correct
content_releases   id, language_id, version, published_at, manifest JSONB (hash par unité → utilisé par le téléchargement hors-ligne), notes
```

`content_releases.manifest` permet au client de savoir quelles unités ont changé et de ne re-télécharger que le delta.

---

## H7. Progression (schéma `progress`)

```
user_courses        user_id, course_id, started_at, current_lesson_id, completed_at, PRIMARY KEY (user_id, course_id)
lesson_progress     id, user_id, lesson_id, status ENUM(LOCKED, AVAILABLE, IN_PROGRESS, COMPLETED), best_score, attempts, first_completed_at, last_completed_at
exercise_attempts   id, user_id, exercise_id, lesson_session_id, answer JSONB, is_correct, response_ms, attempted_at, client_attempt_id (UUID généré côté client, UNIQUE → idempotence de la sync), origin ENUM(ONLINE, OFFLINE_SYNC)
vocabulary_progress user_id, vocabulary_item_id, state ENUM(NEW, LEARNING, WEAK, REVIEW, MASTERED), times_seen, correct_count, wrong_count, last_seen_at, next_review_at, mastery_score numeric(4,3), PRIMARY KEY (user_id, vocabulary_item_id)
review_items        id, user_id, target_type (VOCAB | SENTENCE | GRAMMAR), target_id, state, next_review_at, interval_days, ease numeric, lapses
sync_events         id, user_id, device_id, client_seq bigint, kind, payload JSONB, received_at, applied bool, conflict_resolution
```

Résolution de conflit (offline) : `exercise_attempts` = append-only (jamais de conflit) ; `lesson_progress` = max(score), earliest first_completed ; `vocabulary_progress` = recalculé **serveur** à partir des attempts rejoués dans l'ordre `client_seq`. Le client n'envoie jamais un `mastery_score`, seulement des événements.

---

## H8. Gamification (schéma `game`)

```
xp_ledger          id, user_id, amount, reason ENUM(LESSON_COMPLETE, EXERCISE_CORRECT, REVIEW, STREAK_BONUS, CHECKPOINT, ACHIEVEMENT), ref_type, ref_id, created_at   -- append-only ; total = SUM
streaks            user_id PK, current_days, longest_days, last_activity_date (date locale utilisateur), timezone, freeze_available int
daily_goals        user_id PK, target_xp (10 | 20 | 30 | 50), reminder_time, updated_at
achievements       id, code UNIQUE, title_fr, description_fr, icon_asset_id, rule JSONB (ex. {"type":"lessons_completed","count":10}), is_active
user_achievements  user_id, achievement_id, earned_at, PRIMARY KEY (user_id, achievement_id)
certificates       id, user_id, course_id, level, issued_at, verification_code UNIQUE, pdf_file_key, issued_by
```

---

## H9. Culture (schéma `culture`)

```
cultural_areas        id, code, name_fr (les 4 aires culturelles), description
communities           id, name, cultural_area_id, region_ids[], language_ids[]
regions               (ref) id, code, name — les 10 régions
cultural_categories   id, code ENUM(PEOPLES, HISTORY, TALES, PROVERBS, DANCES, MUSIC, GASTRONOMY, ATTIRE, CRAFTS, RITES, FESTIVALS, SYMBOLS, PERSONALITIES, ARCHITECTURE, ORAL_TRADITIONS), name_fr, name_en, icon
cultural_contents     id, category_id, title_fr, title_en, summary_fr (≤ 280 car. pour la carte « Le savais-tu ? »), body_fr (markdown), body_en
                      cultural_area_id, community_id, region_id, language_id (nullable), author_contributor_id, validator_contributor_id
                      + statut / provenance, published_at, reading_minutes
cultural_media        id, cultural_content_id, kind ENUM(IMAGE, AUDIO, VIDEO), file_key, caption, credit, license, source_id
cultural_sources      = vue sur prov.source_references WHERE target_type = 'CULTURAL_CONTENT'
cultural_links        id, cultural_content_id, target_type (UNIT | LESSON | VOCAB | PROVERB | STORY | PRODUCT), target_id, placement ENUM(DID_YOU_KNOW, RELATED, INTRO)
```

---

## H10. Assistant, traduction, marketplace, billing (résumé)

```
assist.embeddings       id, source_type (VOCAB | SENTENCE | GRAMMAR | CULTURE | LESSON | PRODUCT), source_id, language_id, chunk_text, embedding vector(1024), status_snapshot (seuls VALIDATED/PUBLISHED sont indexés), indexed_at
assist.conversations    id, user_id, started_at, last_message_at
assist.messages         id, conversation_id, role, content, cited_source_ids[], retrieval_log_id, model, model_version, created_at
translate.translation_requests  id, user_id, source_language_id, target_language_id, input_text, input_audio_id, output_text, output_audio_id, mode ENUM(LEXICON, MODEL), model, model_version, confidence, human_validation ENUM(NONE, REQUESTED, VALIDATED, CORRECTED), created_at
market.products         id, artisan_id, title, story_fr (histoire de l'œuvre), price_xaf, stock, status, cultural_content_id (lien Culture Hub), community_id
market.orders / order_items / deliveries / delivery_incidents / courier_availability / payouts
billing.plans           id, code (MONTHLY | YEARLY | PREMIUM), price_xaf, features JSONB
billing.subscriptions   id, user_id, plan_id, status, starts_at, ends_at, provider, provider_ref, auto_renew
billing.payments        id, user_id, purpose (ORDER | SUBSCRIPTION), amount_xaf, provider, provider_ref UNIQUE, status, initiated_at, confirmed_at
billing.payment_webhooks id, provider, event_id UNIQUE, payload, processed_at   -- idempotence
```

---

## H11. Contraintes d'intégrité clés (récapitulatif)

| Règle | Mécanisme |
|---|---|
| Aucun contenu généré ne passe directement à PUBLISHED | trigger : transition `→ PUBLISHED` uniquement depuis `VALIDATED` |
| Un item VALIDATED a une source | CHECK `status IN ('DRAFT') OR source_id IS NOT NULL` + trigger sur `content_validations` |
| Saisie ≠ validation | trigger `validated_by <> created_by` |
| Validateur habilité pour la langue | trigger vérifiant `validation_assignments` |
| Exercices ne citent que du validé | trigger sur `exercises.generated_from` |
| Texte NFC | CHECK `is_nfc(lemma)` |
| Idempotence sync | UNIQUE `exercise_attempts.client_attempt_id` |
| Idempotence paiement | UNIQUE `payments.provider_ref`, `payment_webhooks.event_id` |
| Locuteur anonyme côté app | l'app ne reçoit jamais `speakers.contributor_id`, seulement `display_code` |
