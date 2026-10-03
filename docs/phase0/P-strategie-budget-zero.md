# MBOA — Stratégie budget zéro

**Date : 2026-09-18** · Révise les livrables **C** (utilité des ressources) et **O** (roadmap). Les livrables D à N (pédagogie, données, architecture, design, écrans) restent valables sans changement : **l'architecture ne coûte rien**.

> Contrainte posée : aucun budget. Aucune licence achetée, aucun prestataire payé, aucun serveur payant.
> Conclusion de l'analyse : **le projet reste faisable**, mais son moteur change. On passe d'une logique **« acheter des licences »** à une logique **« construire avec les communs et la communauté »**.

---

## 1. Le constat qui débloque tout

La Phase 0 concluait que le chemin critique était l'achat de licences de dictionnaires. Avec la vérification des licences, ce n'est plus le cas :

> **Common Voice 27.0 fournit gratuitement, en CC0-1.0, tout le socle brut dont MBOA a besoin.**

Licence vérifiée mot à mot sur la fiche du dataset :
- Licence : **« Creative Commons Zero v1.0 Universal (CC0-1.0) »** → domaine public. **Aucune restriction commerciale, aucune obligation d'attribution.**
- Deux interdictions seulement : *« It is forbidden to attempt to determine the identity of speakers »* et *« It is forbidden to re-host or re-share this dataset »*.

Lecture retenue : intégrer des clips CC0 dans l'application pédagogique est un **usage dérivé autorisé** ; ce qui est interdit, c'est de republier l'archive du dataset. MBOA n'offrira donc **aucune fonction « télécharger le corpus Basaa »**.

| Ressource CC0 disponible | Ewondo | Basaa |
|---|---|---|
| Heures audio validées | **13,61 h** | **12,09 h** |
| Locuteurs | 31 | 57 |
| Clips validés | 7 571 | 12 496 |
| **Phrases validées** | **883** | **5 226** |

Rappel du besoin réel pour le niveau N0 : **~110 mots, ~30 phrases, ~10 dialogues par langue**. Le stock CC0 gratuit est donc **8× à 50× supérieur au besoin du MVP**.

**Ce qui manque n'est pas la donnée, c'est le travail humain** : ces phrases n'ont ni traduction française, ni découpage en mots, ni glose. Ce travail ne s'achète pas — il se fait avec des locuteurs natifs. C'est le seul vrai chantier.

---

## 2. Ressources gratuites et réellement utilisables

### 2.1 Retenues (🟢 gratuit + usage commercial autorisé)

| Ressource | Licence vérifiée | Apport |
|---|---|---|
| **Common Voice 27.0 Ewondo** ([fiche](https://mozilladatacollective.com/datasets/cmu6256q100mmo107kx3ckjvw)) | **CC0-1.0** | 883 phrases + 13,6 h d'audio natif |
| **Common Voice 27.0 Basaa** ([fiche](https://mozilladatacollective.com/datasets/cmu61xynu00n7nq079r4v8398)) | **CC0-1.0** | 5 226 phrases + 12,1 h d'audio natif |
| **Common Voice Spontaneous 5.0 Basaa** | CC0-1.0 | parole naturelle (ASR plus tard) |
| **Lingua Libre / Wikimedia Commons — `pronunciation-bas`** | **CC BY-SA 4.0** | **123 enregistrements de mots Basaa isolés**, déjà en ligne, hébergés gratuitement par Wikimedia |
| **Lingua Libre (l'outil)** | service gratuit Wikimedia France | **remplace le studio d'enregistrement** : un bénévole enregistre des centaines de mots en une session depuis son navigateur ; l'audio est hébergé gratuitement sur Commons |
| **Glottolog 5.3** | CC BY 4.0 | métadonnées des langues |
| **Hyman 2003, « Basaá (A.43) »** ([pré-print](https://linguistics.berkeley.edu/~hyman/Basaa_Chapter.pdf)) | pré-print public | **faits** grammaticaux (tons, classes nominales, dérivation verbale) |
| **Makasso & Lee 2015, JIPA** | article accessible | **faits** phonétiques (4 tons, inventaire) |
| **Redden 1979** (Internet Archive, prêt gratuit) | consultation gratuite | **faits** grammaticaux Ewondo |
| **Alphabets of Cameroon**, Hartell 1993 (SIL) | consultation gratuite | alphabet AGLC |
| Oracle Cloud Always Free, Cloudflare R2, GitHub, Firebase FCM, Figma/Penpot, Google Fonts | gratuit | infrastructure (§4) |

**Point juridique essentiel** : le droit d'auteur protège **l'expression**, pas les **faits**. Qu'une langue possède quatre tons, ou qu'un mot donné signifie « eau », est un fait. Lire Hyman 2003 puis **rédiger nos propres explications**, en citant la source, est légal et gratuit. Ce qui serait illégal, c'est de **recopier** les définitions ou de **réimporter en masse** un dictionnaire sous copyright. Le système de provenance (livrable H) enregistre déjà cette distinction : `source_reference` = « vérifié contre Hyman 2003, §3.2 », pas une copie.

### 2.2 Abandonnées faute de budget (⚫)

| Ressource | Raison |
|---|---|
| Dictionnaire Basaa Njock 2019 (15 667 entrées) | © auteur ; l'import en masse nécessiterait un accord. **Reste consultable gratuitement en ligne pour *vérifier* un mot** — c'est tout, et c'est suffisant. |
| Dictionnaires Ewondo (Atangana Ondigui 2007, Tsala, Resulam) | ouvrages payants |
| Dataset ALCAM Basaa (NOODL-1.0) | contact obligatoire ; à tenter tout de même — **c'est gratuit d'écrire un courriel** |
| PanLex | **CC BY-NC-SA** : non commercial → incompatible avec les abonnements prévus. Écarté. |
| MMS (Meta) | CC-BY-NC-4.0 → même raison |
| Studio d'enregistrement professionnel | remplacé par Common Voice + Lingua Libre + smartphones |
| Validateurs rémunérés | remplacés par des contributeurs bénévoles (§3) |

### 2.3 Démarches gratuites à tenter quand même
Écrire un courriel ne coûte rien et peut tout changer. Par ordre de rendement attendu :
1. **Communauté Common Voice Basaa et Ewondo** — 57 et 31 personnes ont déjà donné leur voix bénévolement pour ces langues. Ce sont les contributeurs les plus qualifiés et les plus motivés qui existent. Les contacter via les canaux communautaires Mozilla / Mozilla Data Collective.
2. **Wikimedia Cameroun / Lingua Libre** — groupe déjà actif sur les langues camerounaises (projet Lingua Libre + Wiktionnaire présenté à WikIndaba 2019). Partenariat naturel, sans argent.
3. **Emmanuel Ngue Um** (UY1, Institute of African Digital Humanities) — sa licence NOODL *impose* un contact : c'est une invitation au dialogue, pas un péage.
4. **Département de langues africaines, UY1 / UCAC** — proposer des sujets de mémoire et des stages : gratuit pour MBOA, valorisant pour les étudiants.
5. **Dr P. E. Njock / SIL Cameroun** — demander une autorisation d'usage pédagogique non lucratif. Un refus ne bloque plus rien.
6. **Associations culturelles Basaa et Beti** (Cameroun et diaspora) — contenus culturels et validateurs.

---

## 3. Le nouveau moteur : contribution communautaire

Le budget disparaît, le travail reste. Il est réalisé par des bénévoles, dans le CMS **déjà prévu** au livrable J (donc sans coût de développement supplémentaire).

### 3.1 Chaîne de production gratuite du corpus

```
Phrases CC0 Common Voice (5 226 bas / 883 ewo) + audio natif CC0
        │  import automatique → statut TO_VERIFY
        ▼
Locuteur natif bénévole, dans le CMS :
    écoute l'audio → traduit en français → découpe en mots → glose
        │  → statut HUMAN_REVIEW
        ▼
Second bénévole (validation ≠ saisie, imposé en base) :
    vérifie, corrige l'orthographe, confirme la traduction
        │  → statut VALIDATED
        ▼
Mots isolés manquants → enregistrés via Lingua Libre (gratuit)
        │  → audio CC BY-SA hébergé gratuitement sur Wikimedia Commons
        ▼
Assemblage automatique en leçons + exercices (QuestionGenerator)
        ▼
PUBLISHED
```

Effet de levier : chaque phrase traduite fournit **plusieurs mots** au lexique. Traduire ~300 phrases suffit largement à couvrir les ~110 mots du niveau N0.

### 3.2 Charge de travail réelle (mesurable)

| Tâche | Volume N0 | Rythme réaliste | Total |
|---|---|---|---|
| Traduire + gloser des phrases CC0 | 300 phrases | ~20 phrases/heure | **~15 h** |
| Valider (2e relecture) | 300 phrases | ~30 phrases/heure | ~10 h |
| Enregistrer les mots isolés (Lingua Libre) | ~110 mots | ~100 mots/heure | ~2 h |
| Rédiger 10 règles de grammaire (d'après les sources) | 10 | ~1 h chacune | ~10 h |
| Rédiger 15 fiches culturelles sourcées | 15 | ~1,5 h | ~22 h |
| **Total par langue** | | | **~60 heures de bénévolat** |

**60 heures par langue.** Réparties sur 4 bénévoles à 4 h/semaine, cela représente **moins de 4 mois**. C'est atteignable — et c'est la vraie donnée à retenir : le blocage n'était jamais financier.

### 3.3 Rémunérer autrement que par l'argent
- **Crédit visible** : le `SourceChip` prévu au design system affiche déjà la provenance ; ajouter une page « Contributeurs » et le nom du locuteur (code anonymisé s'il le souhaite) sur chaque audio.
- **Certificat de contribution** signé (le générateur PDF existe déjà pour les certificats d'apprentissage : coût de développement nul).
- **Restitution aux communs** : les traductions produites par MBOA sont reversées en CC0 à Common Voice / Lingua Libre / Wiktionnaire. Argument décisif pour convaincre les communautés Wikimedia et Mozilla de contribuer.
- **Valorisation académique** : co-signature d'un article décrivant le corpus ; sujets de mémoire pour les étudiants de l'UY1.

---

## 4. Infrastructure à coût zéro

| Besoin | Solution gratuite | Limite (vérifiée 2026) | Suffisant ? |
|---|---|---|---|
| Serveur API + worker | **Oracle Cloud Always Free** (ARM Ampere) | 2 OCPU / 12 Go RAM + 200 Go de stockage (réduit de 4/24 le 15 juin 2026) | ✅ largement — héberge API, Postgres, Redis, MinIO |
| Base PostgreSQL | sur la même VM (gratuit) — secours : **Neon** (0,5 Go) ou **Supabase** (500 Mo) | | ✅ le corpus N0 pèse < 50 Mo |
| Stockage audio / images | **Cloudflare R2** : 10 Go, **egress gratuit** | 10 Go-mois, 1 M opérations A | ✅ le N0 des 2 langues ≈ 300 Mo en Opus |
| CDN audio CC BY-SA | **Wikimedia Commons** (via Lingua Libre) | gratuit, illimité | ✅ |
| CI/CD | **GitHub Actions** | 2 000 min/mois (illimité en dépôt public) | ✅ |
| Notifications push | **Firebase Cloud Messaging** | gratuit | ✅ |
| Suivi d'erreurs | **Sentry** free tier | 5 000 erreurs/mois | ✅ |
| Design | **Figma** free / **Penpot** (libre) | 3 fichiers Figma | ✅ |
| Polices | **Google Fonts** (Inter, open source) | — | ✅ |
| Nom de domaine | sous-domaine gratuit au départ (`*.pages.dev`) | — | ✅ |

> ⚠️ **Risque connu** : les inscriptions Oracle Cloud Always Free sont fréquemment refusées et les quotas ont été réduits en juin 2026. **Plan B** entièrement gratuit : Neon (Postgres) + Koyeb ou Render (API) + Upstash (Redis) + R2 (fichiers).

### 4.1 Les seules dépenses réellement incompressibles

Il faut être franc : **deux postes ne sont pas gratuits.**

| Poste | Coût | Décision proposée |
|---|---|---|
| **Compte développeur Google Play** | **25 $ une seule fois, à vie** | inévitable pour publier sur le Play Store. **Alternative gratuite en attendant : distribuer l'APK en téléchargement direct**, et/ou publier sur **F-Droid** (gratuit) |
| **Compte développeur Apple** | 99 $/an | ❌ **iOS abandonné** dans cette version du plan. Android d'abord était déjà la priorité ; la version web (PWA) couvre les utilisateurs iOS de la diaspora |
| API LLM (assistant) | à l'usage | **assistant reporté après le MVP** ; à ce moment-là, un petit modèle tournant sur la VM Oracle ou un palier gratuit seront évalués |
| Agrégateur Mobile Money | commission par transaction (pas d'avance) mais **exige une entité juridique enregistrée** | **marketplace et abonnements reportés** tant qu'il n'y a pas de structure juridique |

---

## 5. Périmètre révisé du MVP

Sans budget, tenir 2 langues + marketplace + assistant + traduction n'est pas réaliste. Voici le périmètre que je recommande, par ordre de renoncement :

### ✅ Conservé (le cœur, §49 du cahier des charges)
Onboarding · parcours d'apprentissage · moteur d'exercices · audio de locuteurs natifs · progression, XP, série · répétition espacée · hors-ligne · Culture Hub · CMS de contribution et de validation.

### 🔻 Réduit
| Élément | Plan initial | Plan budget zéro |
|---|---|---|
| Langues au lancement | Ewondo **et** Basaa | **Basaa d'abord** (6× plus de phrases CC0, 123 audios Lingua Libre déjà disponibles, 57 locuteurs identifiables), **Ewondo dès que 2 validateurs bénévoles sont trouvés**. L'architecture reste générique : ajouter l'Ewondo ne demande aucun développement. |
| Contenu au lancement | Niveau N0 complet (12 unités) | **Section 1 seulement (5 unités, ~20 leçons, ~50 mots)** — puis extension continue |
| Contenus culturels | 30 | **10**, tous sourcés |
| Plateformes | Android + iOS | **Android + PWA** |

### ⏸️ Reporté après le MVP
Assistant RAG (coût LLM) · traduction automatique (coût GPU) · marketplace, paiements, livraison, abonnements, KYC (nécessitent une entité juridique) · certificats officiels · ASR et score de prononciation.

> Ce renoncement n'est pas une perte. Le cahier des charges dit lui-même (§49) : *« TANT QUE CE WORKFLOW N'EST PAS EXCELLENT, NE PAS disperser les efforts sur des fonctionnalités secondaires. »* L'absence de budget impose exactement la discipline que le cahier des charges réclamait.

---

## 6. Roadmap révisée (budget zéro)

Hypothèse : **1 développeur** (vous, éventuellement avec l'assistance de cet agent) + **2 à 4 contributeurs bénévoles natifs**. Durées en semaines, à temps partiel.

| # | Phase | Sem. | Résultat |
|---|---|---|---|
| **0** | Recherche documentaire | ✅ | fait |
| **0-bis** | **Recrutement des contributeurs** — contacter la communauté Common Voice Basaa, Wikimedia Cameroun, UY1, associations | **1-4** *(démarre maintenant, en parallèle du code)* | **≥ 2 locuteurs natifs Basaa engagés** |
| 1 | Infrastructure gratuite + socle | 1-3 | Oracle/Neon + R2 + CI, schéma `prov`/`ref`/`corpus`, auth |
| 2 | **CMS de contribution** *(priorité haute — sans lui, aucun bénévole ne peut travailler)* | 3-7 | import CC0, écran de traduction/glose, file de validation, statuts verrouillés en base |
| 3 | Import du corpus CC0 + début des traductions bénévoles | 6-12 | 300 phrases Basaa traduites et validées |
| 4 | Design System | 4-7 | `mboa_design` (tokens déjà définis et contrastes déjà mesurés au livrable K) |
| 5 | Learning Engine + parcours | 8-13 | Section 1 servie par l'API |
| 6 | Exercise Engine (10 types d'abord, 5 ensuite) | 12-17 | leçon complète jouable |
| 7 | Progression, XP, série, SRS | 16-19 | « je reviens demain et je révise » |
| 8 | Audio : intégration CC0 + Lingua Libre | 10-20 | 100 % des items avec audio natif |
| 9 | Hors-ligne | 19-22 | unité jouable en mode avion |
| 10 | Culture Hub (10 fiches) | 20-24 | langue et culture reliées |
| — | **🎯 MVP Basaa Section 1** | **~24** | APK distribuable, Play Store à 25 $ quand vous le souhaitez |
| 11 | Ewondo (même code, corpus seul à produire) | dès que les bénévoles sont là | 2e langue |
| 12+ | Extension N0 complet, puis assistant / traduction / marketplace | selon ressources | |

---

## 7. Ce qui change, ce qui ne change pas

| | Avant | Maintenant |
|---|---|---|
| Chemin critique | acheter des licences | **recruter 2 locuteurs natifs bénévoles** |
| Source du lexique | dictionnaires sous copyright | **phrases CC0 Common Voice, traduites par la communauté** |
| Source de l'audio | studio payant | **Common Voice CC0 + Lingua Libre (gratuit)** |
| Validateurs | rémunérés | **bénévoles, crédités et certifiés** |
| Hébergement | VPS payant | **Oracle Always Free + Cloudflare R2** |
| Langue au lancement | 2 | **1 (Basaa), la 2e suit sans redéveloppement** |
| Coût total avant publication | plusieurs milliers | **0 € — puis 25 $ une seule fois pour le Play Store** |
| **Architecture (D→N)** | | **inchangée** |
| **Principe « aucun contenu sans source ni validation humaine »** | | **inchangé et toujours verrouillé en base** |

---

## 8. Une conséquence stratégique à mesurer

Ce modèle n'est pas un pis-aller. Il rend MBOA **plus solide** :

- Les données produites sont reversées aux communs (Common Voice, Lingua Libre, Wiktionnaire), ce qui attire d'autres contributeurs et rend le corpus indépendant d'un ayant droit unique.
- Un corpus bâti avec la communauté Basaa appartient à cette communauté — c'est exactement la « résistance culturelle numérique » revendiquée dans le cahier des charges.
- Un projet à licence ouverte est éligible à des financements qu'un projet fermé n'obtiendrait pas : Mozilla Data Collective / Common Voice, Wikimedia (rapid grants), Lacuna Fund, UNESCO. **Ce sont des candidatures gratuites** qui peuvent débloquer un budget plus tard.

**La seule question qui décide de l'avenir du projet n'est pas « combien d'argent ? » mais « qui, parmi les locuteurs natifs du basaa, acceptera de traduire 300 phrases ? ».** Les 57 personnes qui ont déjà donné leur voix à Common Voice pour cette langue sont la meilleure réponse existante.
