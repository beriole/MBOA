# MBOA — Phase 0 : Références UX (L), liste des écrans (M), parcours utilisateur (N)

Statut : soumis pour validation.

---

## L. Références UX utilisées

### L1. Sources effectivement consultables
| Source | Statut d'accès | Usage pour MBOA |
|---|---|---|
| Material 3 (m3.material.io) + docs Flutter design | 🟢 public | base des composants, des états et de l'accessibilité ; MBOA surcharge les couleurs, les rayons et le mouvement |
| WCAG 2.2 (contraste 1.4.3 / 1.4.11, cibles 2.5.8) | 🟢 public | seuils opposables du design system (mesurés, cf. K1) |
| Apple HIG (audio, VoiceOver) | 🟢 public | comportement du lecteur audio, annonces |

### L2. Sources à consulter en Phase 2 par le designer (accès restreint)
**Mobbin** et **Figma Community** nécessitent un compte ; ils n'ont pas pu être parcourus dans cette session. La méthode imposée reste en vigueur pour la Phase 2 : **avant chaque workflow important, réunir 3 à 5 références, identifier les patterns communs, comprendre pourquoi ils fonctionnent, puis produire une version MBOA.** Requêtes à lancer : `language learning app`, `education app`, `gamification`, `quiz app`, `audio learning`, `museum app`, `cultural app`, `marketplace mobile`, `onboarding education`, `progress tracker`, `paywall`, `checkout`.

### L3. Patterns retenus (observés dans la catégorie « apprentissage des langues »), et décision MBOA

| Pattern | Pourquoi il fonctionne | Décision MBOA |
|---|---|---|
| **Chemin vertical de nœuds** (Duolingo, Busuu) | rend la progression tangible ; l'utilisateur voit toujours « le prochain pas » | ✅ adopté — `PathNode`, chemin vertical, sections colorées, checkpoint en fin de section. Graphisme, mascotte et motifs 100 % MBOA |
| **Micro-leçons 3-7 min** | réduit la barrière d'entrée, compatible transport / pause | ✅ adopté — contrainte de conception, pas un slogan |
| **Feedback immédiat avec barre collante** | ferme la boucle d'apprentissage instantanément | ✅ adopté — `FeedbackBar` (bonne réponse + explication ≤ 140 car. + 🔊) |
| **Streak + objectif quotidien** (Duolingo, Headway) | habitude ; effet de série | ✅ adopté, **sans pression culpabilisante** : pas de compteur de perte agressif, « gel » de série disponible |
| **Répétition espacée** (Memrise, Quizlet) | consolide la mémoire à long terme | ✅ adopté — SRS serveur, révision proposée sur l'accueil |
| **Un seul objet d'apprentissage par écran** (Babbel) | charge cognitive minimale | ✅ adopté |
| **Système de vies / cœurs** | crée de la tension, monétise | ⚠️ **non adopté au MVP** (cahier des charges §16). À la place : après 3 erreurs sur un même item, une mini-explication s'affiche et l'item est ajouté à la révision |
| **Leaderboard / ligues** | compétition sociale | ❌ non adopté au MVP : risque de dérive « casino » et audience trop peu dense pour être motivante |
| **Carte « Le savais-tu ? » contextuelle** (Khan Academy, apps de musée) | contextualise, récompense la curiosité | ✅ **cœur de l'identité MBOA** — lie chaque unité au Culture Hub |
| **Affichage explicite de la source** (apps de musée, Wikipédia) | crédibilité | ✅ **différenciant MBOA** : `SourceChip` sur les contenus culturels et l'assistant |
| **Paywall après avoir goûté la valeur** | conversion sans frustrer | ✅ paywall après la Section 1 complétée, jamais pendant une leçon |

### L4. Ce que MBOA ne copie pas
Branding, illustrations, mascotte, sons, textes, contenus et courbes de progression exacts des applications citées. Aucun asset tiers n'est importé. Les kits Figma Community ne seront utilisés que comme inspiration, jamais assemblés entre eux (cahier des charges §31).

---

## M. Liste des écrans

### M1. Application mobile — Apprenant (MVP, Phases 5-11)

**Onboarding / accès (8)**
1. Splash + vérification de session
2. Carrousel de valeur (3 écrans) — « Apprends ta langue », « Écoute de vrais locuteurs », « Découvre ta culture »
3. Choix de la langue (Ewondo / Basaa) + variante
4. Niveau de départ (« Je débute » / « Je connais quelques mots » → mini-test de placement en Phase 2)
5. Objectif quotidien (10 / 20 / 30 / 50 XP)
6. Autorisation notifications + heure du rappel
7. Inscription (email ou téléphone) / Connexion
8. Mot de passe oublié → réinitialisation

**Accueil & parcours (7)**
9. **Accueil** — en-tête (avatar, salutation, streak, cloche) · bloc « Continuer mon parcours » · anneau d'objectif quotidien · « Révision recommandée » · « Découverte culturelle » · accès rapides (Traduction, Assistant)
10. **Parcours** — chemin vertical, sections, checkpoints, état de téléchargement par unité
11. Aperçu d'unité (objectif, contenu, bouton Commencer, télécharger)
12. **Player de leçon** (conteneur à états : intro → exercices → carte culture → récap)
13. Écran de résultat de leçon (score, XP, items à revoir, série)
14. Checkpoint (écran d'évaluation + résultat + certificat si fin de niveau)
15. Révision du jour

**Exercices (15 vues internes au player)** — une vue par type : `MULTIPLE_CHOICE`, `IMAGE_CHOICE`, `WORD_MATCHING`, `TRANSLATION`, `ORDER_WORDS`, `FILL_BLANK`, `LISTEN_AND_CHOOSE`, `LISTEN_AND_TYPE`, `SPEAK`, `WORD_TO_AUDIO`, `AUDIO_TO_WORD`, `TRUE_FALSE`, `DIALOGUE`, `MEMORY_GAME`, (`PRONUNCIATION` en V5)

**Culture (4)**
16. Culture Hub (catégories + mise en avant)
17. Liste filtrée (région, communauté, aire culturelle, langue)
18. Détail d'un contenu culturel (médias, texte, **sources citées**, contenus liés, avis)
19. Carte « Le savais-tu ? » (feuille modale depuis une leçon)

**Traduction & assistant (3)**
20. Traduction (saisie ou micro, sélecteur de langues, résultat avec audio et source, historique)
21. Détail d'une correspondance lexicale (mot, phonétique, exemples, audio, source)
22. Assistant (chat, réponses avec sources, suggestions ; message explicite quand les sources manquent)

**Progression & profil (6)**
23. Statistiques personnelles (XP par semaine, leçons, items maîtrisés, temps d'écoute)
24. Badges / réussites
25. Certificats (liste + détail + partage + code de vérification)
26. Profil / paramètres (compte, langue de l'interface FR/EN, notifications, accessibilité, téléchargements, stockage)
27. Gestion des téléchargements hors-ligne
28. Notifications

**Abonnement (3)**
29. Paywall (plans, avantages)
30. Paiement Mobile Money (webview / statut)
31. Mon abonnement

**Marketplace (Phase 14 — 8)**
32. Boutique (catalogue, filtres) · 33. Détail produit (avec l'histoire de l'œuvre et son lien culturel) · 34. Panier · 35. Adresse & livraison · 36. Paiement · 37. Confirmation · 38. Mes commandes · 39. Suivi de commande + confirmation de réception

### M2. Espaces des autres rôles (mobile)
**Artisan (5)** : tableau de bord ventes · liste produits · éditeur produit · commandes · détail commande + statut
**Livreur (4)** : disponibilité · livraisons assignées · détail livraison + mise à jour de statut + preuve · signalement d'incident
**Spécialiste culturel (6, mobile léger)** : file de validation · fiche à valider (voir la source, écouter l'audio, corriger, accepter / rejeter / demander modification) · mes contributions · enregistrement audio guidé · ajout rapide de vocabulaire · notifications de validation
**Commun à tous les rôles (3)** : demande de changement de rôle · dépôt KYC · statut KYC

### M3. Back-office Flutter Web — Spécialiste & Administrateur
**CMS éditorial (12)** : langues & variantes · cours · sections · unités · leçons (éditeur de blocs) · vocabulaire (tableur) · phrases · règles de grammaire · dialogues · contes & proverbes · générateur d'exercices (revue par lot) · publication de version de contenu (`content_release`)
**Provenance (4)** : sources · documents source · références (liens vers les items) · contributeurs & habilitations de validation
**Audio (3)** : locuteurs & consentements · sessions d'enregistrement · bibliothèque audio (qualité, référence)
**Culture (3)** : contenus culturels · médias · liens leçon ↔ culture
**Import (2)** : lots d'import · mapping des enregistrements bruts
**Administration (7)** : comptes utilisateurs · KYC · statistiques · paiements · paramètres · journaux d'audit · feature flags

**Total MVP (Phases 0-11) : ≈ 58 écrans mobiles + 31 vues back-office.** Marketplace et espaces artisan / livreur portent le total final à ≈ 100 vues — d'où l'ordre de priorité de la roadmap.

---

## N. Diagramme du parcours utilisateur

### N1. Parcours de référence (cahier des charges §49) — objectif n°1 du produit

```
  Installation
      │
      ▼
  Carrousel de valeur ──► Choix de la langue (Ewondo | Basaa)
      │                            │
      │                            ▼
      │                   « Je débute » / « Je connais quelques mots »
      │                            │
      │                            ▼
      │                   Objectif quotidien (10/20/30/50 XP)
      │                            │
      │                            ▼
      │                   Inscription (rôle LEARNER imposé)
      │                            │
      ▼                            ▼
  ┌─────────────────── ACCUEIL ───────────────────┐
  │ Continuer · Objectif du jour · Révision · Culture │
  └───────────────────────┬───────────────────────┘
                          ▼
                     PARCOURS (chemin vertical)
                          │  Section 1 ▸ Unité 1 « Saluer »
                          ▼
                  Aperçu d'unité ──(option)──► Télécharger pour le hors-ligne
                          │
                          ▼
  ┌──────────────── PLAYER DE LEÇON (3-7 min) ────────────────┐
  │ INTRO → TEACH (voir + 🔊 écouter) → PRACTICE (8-12 ex.)     │
  │   chaque réponse ──► FEEDBACK immédiat                      │
  │        ✓ Correct : + XP, animation légère                   │
  │        ✗ Pas encore : bonne réponse + explication + 🔊       │
  │                        └─► item ajouté à la révision         │
  │ → CARTE CULTURE « Le savais-tu ? » → RECAP                  │
  └───────────────────────────┬────────────────────────────────┘
                              ▼
                  RÉSULTAT : score, XP, série, items à revoir
                              │
                              ├──► Leçon suivante (nœud suivant du chemin)
                              └──► Accueil (objectif du jour mis à jour)
                              
        ─────────── le lendemain (notification à l'heure choisie) ───────────
                              ▼
                  ACCUEIL : « Révision recommandée (7 items) »
                              ▼
              RÉVISION : items WEAK réapparaissent en priorité
                              ▼
                  Reprise du parcours ▸ Unité 2 …
                              ▼
              Fin de Section 1 ──► 🏆 CHECKPOINT (seuil 80 %)
                              ▼
              Fin de Niveau N0 ──► 📜 CERTIFICAT (PDF + code de vérification)
```

### N2. États de la progression
```
Unité :   LOCKED ──(unité précédente complétée)──► AVAILABLE ──► IN_PROGRESS ──► COMPLETED
Leçon :   LOCKED ──► AVAILABLE ──► IN_PROGRESS ──► COMPLETED (score conservé au max)
Item :    NEW ──► LEARNING ──┬──► REVIEW ──► MASTERED
                             └──► WEAK ──(réapparaît en révision)──┘
```

### N3. Parcours hors-ligne
```
En ligne : l'utilisateur télécharge l'Unité 3  ──► paquet (leçons + exercices + audio Opus + images WebP) + manifest
Hors ligne : leçon jouable, progression écrite localement (local_attempts, sync_queue)
Retour du réseau : SyncQueue ──► POST /sync ──► le serveur rejoue les événements dans l'ordre
                 ◄── état canonique (progress, XP, streak, review) qui écrase l'état local
Conflit : attempts append-only (aucun conflit) ; lesson_progress = meilleur score ; SRS recalculé serveur
```

### N4. Parcours du contenu (spécialiste ↔ apprenant)
```
SOURCE EXTERNE (avec licence vérifiée)
   └─► IMPORT (lot) ─► RAW ─► NORMALISATION ─► DRAFT
                                                 │
                        saisie / enregistrement par un contributeur
                                                 ▼
                          SOURCE_FOUND ─► TO_VERIFY ─► HUMAN_REVIEW
                                                 │
                        validation par un spécialiste habilité pour la langue
                              ┌──────────────────┼──────────────────┐
                              ▼                  ▼                  ▼
                          REJECTED      REQUEST_CHANGES          VALIDATED
                                                 │                  │
                                         (retour DRAFT)             ▼
                                                        Transformation pédagogique
                                                        (QuestionGenerator, assemblage d'unité)
                                                                    ▼
                                                            QA éditoriale (checklist §44)
                                                                    ▼
                                                              PUBLISHED
                                                                    ▼
                                                  content_release ─► API ─► app mobile
```

### N5. Parcours des autres rôles (résumé)
```
Visiteur ──► consulte les services ──► s'inscrit (LEARNER) ──► demande de rôle + KYC
                                                                   ▼
                                          Admin examine ──► ACCEPTÉ ──► rôle ARTISAN / SPÉCIALISTE / LIVREUR activé
Spécialiste : file de validation ──► fiche (source, audio, correction) ──► accepter / rejeter / demander modification ──► publier
Artisan : produits ──► commande reçue ──► préparation ──► assignation livreur ──► suivi
Livreur : disponibilité ──► livraisons assignées ──► statut ──► preuve de livraison (ou incident)
Admin : comptes · KYC · statistiques · paiements · paramètres · audit
```
