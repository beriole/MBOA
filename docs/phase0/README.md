# MBOA — Livrable initial obligatoire (Phase 0)

**Date : 2026-09-18** · Statut : **soumis pour validation avant toute écriture de code et avant toute génération de cours.**

Conformément au §51 du cahier des charges, aucune ligne de code applicatif n'a été écrite et aucun contenu linguistique n'a été généré. Aucun mot Ewondo ou Basaa n'a été inventé : ces documents ne contiennent **aucune donnée linguistique**, seulement des ressources, des licences, des structures et des architectures.

## Documents

| Livrable | Fichier |
|---|---|
| A. Inventaire des ressources Ewondo<br>B. Inventaire des ressources Basaa<br>C. Tableau source / URL / type / licence / utilité | [A-B-C-inventaire-ressources.md](A-B-C-inventaire-ressources.md) |
| D. Structure pédagogique proposée<br>E. Arbre du premier parcours Ewondo<br>F. Arbre du premier parcours Basaa<br>G. Liste des types d'exercices | [D-E-F-G-structure-pedagogique.md](D-E-F-G-structure-pedagogique.md) |
| H. Architecture de données | [H-architecture-donnees.md](H-architecture-donnees.md) |
| I. Architecture Flutter<br>J. Architecture FastAPI + contrat d'API | [I-J-architecture-flutter-fastapi.md](I-J-architecture-flutter-fastapi.md) |
| K. Design System | [K-design-system.md](K-design-system.md) |
| L. Références UX utilisées<br>M. Liste des écrans<br>N. Diagramme du parcours utilisateur | [L-M-N-ux-ecrans-parcours.md](L-M-N-ux-ecrans-parcours.md) |
| O. Roadmap d'implémentation | [O-roadmap.md](O-roadmap.md) |
| **P. Stratégie budget zéro** — révise C et O | [P-strategie-budget-zero.md](P-strategie-budget-zero.md) |

> ⚠️ **Lire P en premier.** La contrainte « aucun budget » a été posée après la remise des livrables A→O. Le document P révise l'utilité des ressources (C) et la roadmap (O) en conséquence. Les livrables D à N (pédagogie, données, architecture, design, écrans) restent valables tels quels : l'architecture ne coûte rien. Le document O décrit le scénario avec budget, conservé pour référence si un financement est obtenu plus tard.

## Les cinq constats qui déterminent la suite

1. **Aucun lexique Ewondo ou Basaa n'est disponible sous licence ouverte.** Le corpus MBOA devra être constitué par accords de licence, production originale et relecture humaine. C'est le chemin critique du projet — pas le développement.
2. **L'audio de locuteurs natifs existe sous CC0** : Common Voice 27.0 fournit 14,36 h pour l'Ewondo (31 locuteurs) et 13,56 h pour le Basaa (57 locuteurs), avec 883 et 5 226 phrases validées. Ces phrases sont les meilleurs candidats pour le corpus, après relecture humaine.
3. **Le Basaa dispose d'un dictionnaire de 15 667 entrées** (Njock 2019, SIL/Webonary) mais il est sous copyright : l'accord écrit de l'auteur et de SIL est le préalable n°1 côté Basaa.
4. **Aucun modèle ASR ou TTS n'est utilisable en production** : MMS n'a pas d'adaptateur Ewondo, son adaptateur Basaa est sous CC-BY-NC-4.0 (incompatible avec un produit à abonnement), et il n'existe pas de `mms-tts-bas`. La feuille de route « prononciation » reste donc en V1-V4 (écouter, ralentir, s'enregistrer, comparer) — **aucun score de prononciation ne sera affiché** tant qu'aucun modèle fiable ne le justifie.
5. **Plusieurs datasets Hugging Face présentés comme libres ne le sont pas** (texte biblique sous copyright de l'Alliance Biblique du Cameroun re-publié en CC-BY, datasets sans provenance). Ils sont explicitement écartés.

## Décisions attendues de votre part avant la Phase 1

*(version budget zéro — voir [P](P-strategie-budget-zero.md) pour le détail)*

1. **Accord pour démarrer le recrutement des contributeurs bénévoles** : communauté Common Voice Basaa (57 locuteurs ont déjà donné leur voix), Wikimedia Cameroun, UY1, associations culturelles. C'est le seul chemin critique restant.
2. Validation du périmètre réduit : **Basaa d'abord, Section 1 seulement** (5 unités, ~20 leçons, ~50 mots), Android + PWA, marketplace / assistant / traduction reportés.
3. Acceptation des deux seules dépenses éventuelles : **25 $ une fois** pour le Play Store (contournable par une distribution APK directe ou F-Droid) et **abandon d'iOS** (99 $/an).
4. Validation de la variante retenue par langue (Basaa Mbɛnɛ, puis Ewondo standard de Yaoundé) et de la norme orthographique.
5. Validation du nom et du concept de la mascotte, qui doit être approuvé culturellement avant production graphique.
6. Accord sur le principe non négociable inscrit dans la base de données : **aucun contenu sans source, aucune publication sans validation humaine, saisie et validation par deux personnes différentes.**
7. Accord de principe pour **reverser aux communs** (Common Voice, Lingua Libre, Wiktionnaire) les traductions produites — c'est l'argument qui convaincra les communautés bénévoles de contribuer.

## Ce qui reste à vérifier manuellement (accès bloqués pendant la recherche)

- Page de copyright de Webonary Basaa, listes de ressources SIL Cameroun par langue, Ethnologue, Global Recordings Network, OLAC : 403 / timeout / pages JavaScript.
- Les chiffres de tons et de voyelles de l'Ewondo issus de Wikipédia doivent être confirmés par un spécialiste contre Essono 2000 et Owona 2004 avant tout usage pédagogique.
