# MBOA — Phase 0 : Inventaire documentaire Ewondo & Basaa

**Date de consultation des sources : 2026-09-18**
**Statut du document : soumis pour validation (aucun code écrit)**

Règle appliquée : aucune donnée linguistique n'a été inventée. Ce document n'inventorie que des **ressources** et leur **provenance / licence**. Aucun mot Ewondo ou Basaa n'y figure en tant que donnée pédagogique. Les statuts utilisés sont ceux du cahier des charges : `DRAFT · SOURCE_FOUND · TO_VERIFY · HUMAN_REVIEW · VALIDATED · PUBLISHED · REJECTED`.

---

## 0. Identification des deux langues

Sources : Glottolog 5.3 (CC BY 4.0), Wikipédia (en), Hyman 2003.

| | EWONDO | BASAA |
|---|---|---|
| ISO 639-3 | `ewo` | `bas` |
| Glottocode | `ewon1239` | `basa1284` |
| Guthrie | A.72 (groupe Beti, zone A) | A.43 (A.43a Mbɛnɛ / A.43b Bakoko selon Guthrie) |
| Famille | Niger-Congo › Bantu › zone A | Niger-Congo › Bantu › zone A |
| Noms alternatifs | Ewundu, Jaunde, Yaounde, Yaunde ; « Beti » | Basa, Bassa, Basaa, Basa-um, Mbene |
| Localisation | Région du Centre ; nord de l'Océan (Sud). Langue véhiculaire (commerce) | Centre + Littoral (Nyong-et-Kellé, Sanaga-Maritime, Nkam, Wouri) ; véhiculaire en zone Bakoko/Tunen |
| Locuteurs (chiffres publiés) | 577 700 L1 (1982) | 300 000 (SIL 2005) ; 282 000 (SIL 1982 cité par Hyman 2003) ; Ngue Um (dataset ALCAM) avance 600–700 000 |
| Vitalité (Glottolog / AES) | 3 — *Wider communication*, non menacée | 5 — *Developing*, non menacée |
| Intelligibilité | mutuellement intelligible avec Bulu, Eton, Fang (à confirmer par spécialiste) | variation dialectale « relativement mineure » (Hyman 2003) |
| Dialectes listés | Badjia, Bafeuk, Bemvele, Bane, Beti, Enoah, Evouzom, Mbida-Bani, Mvete, Mvog-Niengue, Omvang, Yabekolo, Yabeka, Yabekanga | Bakem, Bon, Bibeng, Diboum, Log, Mpo, Mbang, Ndokama, Basso, Ndokbele, Ndokpenda, Nyamtam ; standard = zone de Pouma (Sanaga-Maritime) |
| Écriture | Alphabet Général des Langues Camerounaises (AGLC) ; lettres spéciales ǝ, ɛ, ɔ, ŋ ; orthographe harmonisée : Owona 2004 | Alphabet latin + Ɓɓ, Ɛɛ, Ŋŋ, Ɔɔ ; 10 multigraphes ; tons marqués par diacritiques dans les ouvrages de référence |
| Tons | Wikipédia mentionne 7 tons marqués par diacritiques — **TO_VERIFY** contre Essono 2000 / Owona 2004 | 4 tons contrastifs : haut, bas, descendant, montant (Makasso & Lee 2015 ; Bot Ba Njock 1964) |
| Voyelles / consonnes | 8 voyelles, ~28 consonnes (Wikipédia — TO_VERIFY) | 8 voyelles (courtes/longues) ; consonnes prénasalisées, implosive ɓ (Hyman 2003) |

**Décision de variante MVP (à valider par les spécialistes)** : Ewondo « standard » de Yaoundé (base de l'orthographe harmonisée Owona 2004) ; Basaa standard Mbɛnɛ (zone de Pouma), orthographe du dictionnaire Njock 2019 / SIL. Le modèle de données prévoit `LanguageVariant` pour ne pas figer ce choix.

---

## A. Inventaire des ressources EWONDO

Légende utilité : 🟢 exploitable directement (licence ouverte) · 🟡 exploitable avec accord / partenariat · 🔴 consultation seulement (référence bibliographique, pas de réutilisation du contenu) · ⚫ non exploitable / à écarter.

### A1. Dictionnaires et lexiques

| # | Ressource | Auteur / éditeur | Année | Type | Accès | Licence | Utilité | Statut |
|---|---|---|---|---|---|---|---|---|
| E-01 | *Dictionnaire ewondo-français* | Abbé Théodore Tsala, Imprimerie E. Vitte, Lyon | 1955/56 | Dictionnaire | Édition rare (4 ex. en archives publiques FR) ; scans non autorisés circulent (Scribd, Calaméo) | Droits d'auteur (auteur † 1979 → pas domaine public) | 🔴 référence historique ; ne pas réutiliser les scans | TO_VERIFY (ayants droit) |
| E-02 | *Le nouveau dictionnaire ewondo : ewondo-français, français-ewondo* | Siméon Basile Atangana Ondigui, Éd. Terre Africaine, Yaoundé | 2007 | Dictionnaire bidirectionnel | Livre (WorldCat OCLC 973940799) | © éditeur | 🟡 partenariat éditeur à négocier — **source lexicale principale candidate** | SOURCE_FOUND |
| E-03 | *Syllabaire et dictionnaire visuel en langue ewondo* | Claude Lionel Mvondo & Rodrigue Tchamna, Resulam | 2019 | Syllabaire + dictionnaire illustré | Livre commercial (Amazon / resulam.com) | © Resulam | 🟡 Resulam = éditeur camerounais spécialisé langues nationales → partenaire contenu potentiel | SOURCE_FOUND |
| E-04 | *Favourez/french_ewondo_dictionary* (Hugging Face) | Favourez | n.d. | Dataset | HF | **Aucune licence, aucune provenance** | ⚫ ne pas utiliser | REJECTED |
| E-05 | *Favourez/ewondo_english* (HF) | Favourez | n.d. | 112 paires mots/phrases | HF, CSV | **Aucune licence, aucune provenance**, doublons | ⚫ ne pas utiliser (au mieux : pistes de vérification pour un spécialiste) | REJECTED |

### A2. Grammaires, phonologie, orthographe

| # | Ressource | Auteur / éditeur | Année | Type | Accès | Licence | Utilité | Statut |
|---|---|---|---|---|---|---|---|---|
| E-10 | *A Descriptive Grammar of Ewondo* (Occasional Papers on Linguistics 4) | James E. Redden, Dept. of Linguistics, Southern Illinois University | 1979 | Grammaire descriptive **avec exercices, lexique et bibliographie** | ERIC ED185833 ; Internet Archive (prêt numérique) ; Open Library | © SIU 1979 | 🟡 base pédagogique majeure pour la grammaire ; contacter SIU pour droits ; sinon 🔴 référence | SOURCE_FOUND |
| E-11 | *L'ewondo, langue bantu du Cameroun : phonologie, morphologie, syntaxe* | Jean-Marie Essono, Presses de l'UCAC, Yaoundé | 2000 | Description linguistique complète (issue de la thèse Paris 3, 1993) | Livre | © UCAC | 🟡 référence scientifique n°1 en français ; partenariat UCAC | SOURCE_FOUND |
| E-12 | *L'orthographe harmonisée de l'ewondo* | Antoine Owona, thèse, Université de Yaoundé | 2004 | Orthographe / alphabet | Thèse (bibliothèque UY1) | Thèse universitaire | 🟡 **source normative pour l'orthographe MBOA** ; obtenir copie via UY1 | SOURCE_FOUND |
| E-13 | *La grammaire de l'ewondo* / *Grammaire Ewondo* (2e éd.) | P. Abéga, Université fédérale du Cameroun, Section de linguistique appliquée | 1969 / 1971 | Grammaire | Bibliothèques | © | 🔴 référence | SOURCE_FOUND |
| E-14 | *Aspects de la phonétique et de la morphologie de l'ewondo* | Jean-Pierre Angenot | 1971 | Phonétique / morphologie | Bibliothèques | © | 🔴 référence | SOURCE_FOUND |
| E-15 | *Lehrbuch der Jaunde-Sprache* | Hermann Nekes | 1911 | Manuel (allemand) | Domaine public probable | DP à vérifier | 🔴 référence historique (orthographe obsolète) | TO_VERIFY |
| E-16 | *Le temps en langue ewondo* | J. Tabi-Manga, Cahiers de Sémiotique Textuelle 1 | 1984 | Article (temps verbaux) | Revue | © | 🔴 référence | SOURCE_FOUND |
| E-17 | *Vers une grammaire minimaliste de certains aspects syntaxiques de la langue ewondo* | O. Manga & C. Ledoux, thèse Paris 8 | 2012 | Thèse syntaxe | theses.fr / HAL à vérifier | Thèse | 🔴 référence | SOURCE_FOUND |
| E-18 | *La dénomination des langues au Cameroun : le cas de l'ewondo, du tuki et du kenyang* | E. Biloa & G. Echu, BCILL 124 | 2009 | Article sociolinguistique | Revue | © | 🔴 contexte | SOURCE_FOUND |
| E-19 | Bibliographie Afranaph — Ewondo | Afranaph Project (Rutgers) | n.d. | Liste de références | https://afranaphproject.afranaphdatabase.com/images/bibliographies/Ewondo__Afranaph-Bibliography.pdf | — | 🟢 point d'entrée bibliographique | SOURCE_FOUND |
| E-20 | *Bibliographie des langues camerounaises* | Barreteau, Ngangtchui & Scruggs, ORSTOM | 1993 | Bibliographie | Bibliothèques / IRD | © IRD | 🟢 index de +50 titres par langue | SOURCE_FOUND |

### A3. Alphabétisation / pédagogie

| # | Ressource | Auteur / éditeur | Année | Type | Accès | Licence | Utilité | Statut |
|---|---|---|---|---|---|---|---|---|
| E-30 | *Bií ayǝ́gǝ láŋ ewondo [2]* | Akonga A.-S., Abomo S. A., Nomo E. N., Université de Yaoundé | 1982 | Syllabaire (72 p.) | SIL Cameroun archives n° 32930 — https://www.silcam.org/resources/archives/32930 | Conditions SIL (sil.org/terms-use) ; PDF à vérifier | 🟡 modèle de progression d'alphabétisation ; demander droits SIL / UY1 | SOURCE_FOUND |
| E-31 | Archives SIL Cameroun — Ewondo (7 ressources) | SIL Cameroun | — | Liste | https://www.silcam.org/resources/search/language/ewo (accès instable pendant la recherche) | Conditions SIL | 🟡 à inventorier manuellement (7 entrées) | TO_VERIFY |
| E-32 | *Alphabets of Cameroon* (Alphabets of Africa, Hartell 1993) | SIL | 1993 | Alphabets nationaux (AGLC) | https://www.silcam.org/resources/archives/5177 | Conditions SIL | 🟢 référence pour l'AGLC | SOURCE_FOUND |
| E-33 | Bloom Library — *sil-ai/bloom-lm* (1 document Ewondo) | SIL / CABTAL | — | Livre(s) enfants | HF | Mixte CC-BY / CC-BY-NC / CC-BY-NC-SA (par document) | 🟡 vérifier la licence du document ewo précis | TO_VERIFY |

### A4. Audio / parole

| # | Ressource | Producteur | Année | Contenu | Accès | Licence | Utilité | Statut |
|---|---|---|---|---|---|---|---|---|
| E-40 | **Common Voice Scripted Speech 27.0 — Ewondo** | Mozilla Foundation / contributeurs | 2026-09-11 | **14,36 h** (13,61 h validées) ; 31 locuteurs ; 7 991 clips (7 571 validés) ; **883 phrases validées** ; MP3, 281 MB | https://mozilladatacollective.com/datasets/cmu6256q100mmo107kx3ckjvw | **CC0-1.0** + conditions MDC : interdiction de ré-héberger le dataset tel quel et d'identifier les locuteurs | 🟢 ASR (entraînement / éval) ; 🟡 les 883 phrases CC0 = candidats corpus « phrases » après HUMAN_REVIEW ; audio réutilisable dans l'app uniquement si conforme aux conditions MDC (relecture juridique) | SOURCE_FOUND |
| E-41 | *OlameMend/Ewondo-TTS* (HF) | OlameMend | — | 7 967 clips audio + transcriptions ; 3,75 GB ; contenu biblique | HF | **Aucune licence, aucune provenance** (probable NT Ewondo © Alliance Biblique du Cameroun) | ⚫ ne pas utiliser sans clarification | REJECTED (provisoire) |
| E-42 | *OlameMend/mms-tts-ewo* (HF) | OlameMend | — | Modèle TTS VITS fine-tuné sur E-41 | HF | Hérite de MMS (CC-BY-NC-4.0) + données non licenciées | ⚫ non utilisable en production | REJECTED |
| E-43 | Meta MMS ASR (`facebook/mms-1b-all`) | Meta | 2023 | Adaptateurs ASR par langue | HF | **CC-BY-NC-4.0** | ⚫ **pas d'adaptateur `ewo`** (vérifié dans la liste des fichiers : evn → ewe → eza) ; licence non commerciale de toute façon | REJECTED |
| E-44 | Global Recordings Network — Ewondo | GRN | — | Audio + scripts (contenu religieux) | globalrecordings.net (403 lors de la consultation) | © GRN / CC selon programmes | 🟡 à vérifier manuellement | TO_VERIFY |

### A5. Textes / corpus

| # | Ressource | Producteur | Année | Contenu | Accès | Licence | Utilité | Statut |
|---|---|---|---|---|---|---|---|---|
| E-50 | *ELRs/Ewondo_Bible* (HF) | « Ewondo Language Resources » | — | 16 785 lignes de texte biblique | HF | Déclaré CC-BY-4.0 **mais** texte sous-jacent = très probablement NT Ewondo © Alliance Biblique du Cameroun (2012) → licence non opposable | ⚫ ne pas utiliser | REJECTED |
| E-51 | Nouveau Testament en Ewondo | Alliance Biblique du Cameroun | 2012 | Texte parallèle potentiel | biblesociety-cameroon.org | © ABC — accord de partage de données requis ; absent d'eBible.org | 🟡 corpus parallèle uniquement via accord écrit ; registre religieux peu adapté au MVP | SOURCE_FOUND |
| E-52 | Mbouopda, Yonta & Lombo (2020), *Neural networks for projecting named entities from English to Ewondo*, arXiv:2004.13841 | — | 2020 | Article + dataset éventuel | arXiv | arXiv (article) ; dataset à vérifier | 🔴 état de l'art NLP Ewondo | SOURCE_FOUND |
| E-53 | Wikipédia / Wiktionnaire (incubateur ewo) | Wikimedia | — | Peu de contenu | — | CC BY-SA | ⚫ trop faible, non vérifié | REJECTED |

### A6. Bilan Ewondo

- **Point fort** : littérature descriptive solide (Redden 1979, Essono 2000, Owona 2004) et **14 h d'audio CC0** (Common Voice 27.0).
- **Point faible** : **aucun lexique numérique sous licence ouverte**. Le corpus lexical MBOA devra être **construit** (saisie depuis les ouvrages avec accord, ou production originale par les spécialistes) — c'est le chemin critique.
- **Aucun modèle ASR/TTS exploitable commercialement** pour l'Ewondo aujourd'hui.

---

## B. Inventaire des ressources BASAA

### B1. Dictionnaires et lexiques

| # | Ressource | Auteur / éditeur | Année | Type | Accès | Licence | Utilité | Statut |
|---|---|---|---|---|---|---|---|---|
| B-01 | **Dictionnaire ɓàsàa – français – anglais – allemand** | Dr Pierre Emmanuel Njock ; SIL International / Webonary | 2019 (éd. HTML 2005) | **15 667 entrées** + nombreuses phrases d'exemple | En ligne : https://www.webonary.org/basaa/ ; fiche SIL : https://www.silcam.org/resources/archives/84434 ; éd. 2005 en ZIP HTML : https://www.silcam.org/resources/archives/47253 | **« © 2019 Dr. Pierre Emmanuel Njock »** — aucune licence ouverte affichée ; conditions SIL (sil.org/terms-use). Page copyright Webonary inaccessible (403) lors de la consultation | 🟡 **source lexicale principale du corpus Basaa**, mais uniquement après **accord écrit de l'auteur / SIL**. Pas d'aspiration automatique. | SOURCE_FOUND — accord à obtenir |
| B-02 | *Dictionnaire basaa-français* | Pierre Lemb & François de Gastines, Collège Libermann, Douala | 1973 | Dictionnaire | Bibliothèques | © | 🔴 référence / contre-vérification | SOURCE_FOUND |
| B-03 | *Die Sprache der Basa in Kamerun: Grammatik und Wörterbuch* | Georg Schürle, Hamburg | 1912 | Grammaire + lexique (allemand) | Domaine public probable | DP à vérifier | 🔴 référence historique (orthographe obsolète) | TO_VERIFY |
| B-04 | **Basaa-ALCAM-MultimodalDataset** | Institute of African Digital Humanities ; propriétaire : Emmanuel Ngue Um (UY1) ; financé par Mozilla | 2025 | **350 entrées lexicales** (transcription API, gloses mot à mot, traduction FR) + **336 clips audio** (1 locuteur H ~50 ans) ; TSV + MP3 ; 15 MB | https://mozilladatacollective.com/datasets/cmind910n0096nx07gme9v3wj | **NOODL-1.0** : contact obligatoire avec le propriétaire avant usage ; IA générative, redistribution, dérivés interdits sans permission | 🟡 petit mais **très bien documenté** (issu du questionnaire ALCAM 1970-80 de Bot Ba Njock) ; **Emmanuel Ngue Um = partenaire scientifique prioritaire** | SOURCE_FOUND — contact requis |
| B-05 | *LeMisterIA/basaa-models* (HF) | LeMisterIA | — | Dataset non documenté | HF | Aucune | ⚫ | REJECTED |

### B2. Grammaires, phonologie, orthographe

| # | Ressource | Auteur / éditeur | Année | Type | Accès | Licence | Utilité | Statut |
|---|---|---|---|---|---|---|---|---|
| B-10 | **« Basaá (A.43) »**, in *The Bantu Languages* (Nurse & Philippson éd.), ch. 15, p. 257-282 | Larry M. Hyman, Routledge | 2003 | Description complète : phonologie, tons, classes nominales, dérivation verbale, syntaxe (38 p.) + bibliographie | Pré-print : https://linguistics.berkeley.edu/~hyman/Basaa_Chapter.pdf | © Routledge (pré-print diffusé par l'auteur) | 🟢 référence grammaticale n°1 pour rédiger les `GrammarRule` (avec citation) | SOURCE_FOUND |
| B-11 | **« Basaá » — Illustrations of the IPA**, JIPA 45(1) | Emmanuel-Moselly Makasso & Seunghun J. Lee, Cambridge | 2015 | Inventaire phonétique + **enregistrements audio** | https://www.cambridge.org/core/journals/journal-of-the-international-phonetic-association/article/basaa/630CB83A1DB4851CE043540DFCEF2F0A | © Cambridge UP ; audio JIPA sous conditions | 🟢 référence pour `01 Alphabet / 02 Sons / 03 Tons` ; 🔴 audio non réutilisable sans accord | SOURCE_FOUND |
| B-12 | *Aspects du basaa* (Bibliographie de la SELAF 96) | Gerrit Dimmendaal, trad. L. Bouquiaux, Peeters/SELAF | 1988 | Description | Livre | © | 🔴 référence | SOURCE_FOUND |
| B-13 | *Le système verbal du basaa* | Denis Zachée Bitjaa Kody, thèse 3e cycle, Université de Yaoundé | 1990 | Morphologie verbale | Thèse | Thèse | 🔴 référence (conjugaison) | SOURCE_FOUND |
| B-14 | *Nexus et nominaux en basaa* ; *Les tons en basaa* (JAL 3) | Henri-Marcel Bot Ba Njock | 1970 ; 1964 | Thèse d'État ; article tons | Bibliothèques | © | 🔴 référence (tons, nominaux) | SOURCE_FOUND |
| B-15 | *Éléments de phonologie et de morphologie historique du basaa* (Africana Linguistica X) | Baudouin Janssens, MRAC Tervuren | 1986 | Phonologie historique | Revue | © | 🔴 référence | SOURCE_FOUND |
| B-16 | *Revisiting Basaa verbal derivation* | (ResearchGate) | 2021 | Article | ResearchGate | © | 🔴 référence | SOURCE_FOUND |
| B-17 | Schmidt 1994, 1996 (*Phonology* 11 & 13) ; Buckley 1997 ; Voorhoeve 1980 ; Boum 1983 | divers | — | Articles phonologie / dérivation / localisation | Revues | © | 🔴 références spécialisées | SOURCE_FOUND |
| B-18 | *Alphabets of Cameroon* (Hartell 1993) | SIL | 1993 | Alphabet Basaa officiel | https://www.silcam.org/resources/archives/5177 | Conditions SIL | 🟢 référence alphabet | SOURCE_FOUND |
| B-19 | Archives SIL Cameroun — Basaa (7 ressources) | SIL Cameroun | — | Liste | https://www.silcam.org/resources/search/language/bas (403 lors de la consultation) | Conditions SIL | 🟡 à inventorier manuellement | TO_VERIFY |

### B3. Audio / parole

| # | Ressource | Producteur | Année | Contenu | Accès | Licence | Utilité | Statut |
|---|---|---|---|---|---|---|---|---|
| B-40 | **Common Voice Scripted Speech 27.0 — Basaa** | Mozilla / contributeurs | 2026-09-11 | **13,56 h** (12,09 h validées) ; **57 locuteurs** ; 12 496 clips ; **5 226 phrases validées** ; MP3, 243 MB | https://mozilladatacollective.com/datasets/cmu61xynu00n7nq079r4v8398 | **CC0-1.0** + conditions MDC (pas de ré-hébergement, pas d'identification des locuteurs) | 🟢 ASR ; 🟡 5 226 phrases CC0 = **plus gros vivier de phrases Basaa** → HUMAN_REVIEW | SOURCE_FOUND |
| B-41 | Common Voice **Spontaneous** Speech 5.0 — Basaa | Mozilla | 2026 | Parole spontanée (heures non affichées) | https://mozilladatacollective.com/datasets/cmu5z0yn400fho1079n6b5czp | CC0-1.0 + conditions MDC | 🟢 ASR (parole naturelle) | SOURCE_FOUND |
| B-42 | Basaa-ASR-Dataset | (voir MDC) | — | 1 h 54 min | https://mozilladatacollective.com/datasets/cmq9hwfbr02gfmk07m1jgvwje | NOODL-1.0 (contact requis) | 🟡 ASR | TO_VERIFY |
| B-43 | Meta MMS ASR (`facebook/mms-1b-all`) | Meta | 2023 | **Adaptateur `bas` présent** (vérifié : `adapter.bas.bin`, `vocabs/bas.txt`) | HF | **CC-BY-NC-4.0** | 🟡 prototypage / recherche uniquement ; **interdit en prod commerciale** (abonnements MBOA) | SOURCE_FOUND — usage R&D |
| B-44 | Meta MMS TTS | Meta | 2023 | **Pas de modèle `facebook/mms-tts-bas`** (vérifié ; `mms-tts-bsq` = Bassa du Liberia, langue différente) | HF | — | ⚫ | REJECTED |
| B-45 | Audio JIPA (Makasso & Lee 2015) | Cambridge | 2015 | Enregistrements de l'illustration IPA | Cambridge Core | © | 🔴 référence, pas de réutilisation | SOURCE_FOUND |

### B4. Textes / corpus

| # | Ressource | Producteur | Année | Contenu | Accès | Licence | Utilité | Statut |
|---|---|---|---|---|---|---|---|---|
| B-50 | *michsethowusu/english-basaa_sentence-pairs_mt560* (HF) | dérivé d'OPUS MT560 | — | **27 771 paires EN–BAS** ; contenu majoritairement religieux / instructif | HF | Déclaré CC-BY-4.0 ; **provenance réelle = MT560 (agrégat OPUS) dont la licence des textes sources n'est pas garantie** | 🟡 utile pour **expérimentations MT** ; ⚫ pas comme source pédagogique | TO_VERIFY |
| B-51 | Bible complète en Basaa | Alliance Biblique du Cameroun | — | Texte | ABC | © ABC — accord requis | 🟡 corpus parallèle via accord uniquement | SOURCE_FOUND |
| B-52 | Wikipédia Basaa | Wikimedia | — | Très peu de contenu | — | CC BY-SA | ⚫ | REJECTED |

### B5. Bilan Basaa

- **Point fort** : un **dictionnaire de référence de 15 667 entrées avec exemples** (Njock / SIL), une description grammaticale de référence (Hyman 2003), une illustration IPA avec audio (Makasso & Lee 2015), **13,5 h d'audio CC0 avec 5 226 phrases validées** (Common Voice), un adaptateur ASR existant (MMS, R&D seulement), et un chercheur identifié (Emmanuel Ngue Um, UY1).
- **Point faible** : le dictionnaire n'est **pas sous licence ouverte** → l'accord Njock / SIL est le chemin critique Basaa.

---

## C. Tableau synthétique Source / URL / Type / Licence / Utilité (ressources retenues)

| Source | URL | Langue | Type | Licence | Utilité MBOA | Action |
|---|---|---|---|---|---|---|
| Glottolog | https://glottolog.org/resource/languoid/id/ewon1239 · …/basa1284 | ewo, bas | Identification | CC BY 4.0 | Métadonnées `Language` | 🟢 intégrer |
| Common Voice Scripted 27.0 Ewondo | https://mozilladatacollective.com/datasets/cmu6256q100mmo107kx3ckjvw | ewo | Audio + phrases | CC0 + CGU MDC | ASR ; phrases candidates | 🟢 télécharger, relire CGU, HUMAN_REVIEW des phrases |
| Common Voice Scripted 27.0 Basaa | https://mozilladatacollective.com/datasets/cmu61xynu00n7nq079r4v8398 | bas | Audio + phrases | CC0 + CGU MDC | ASR ; phrases candidates | 🟢 idem |
| Common Voice Spontaneous 5.0 Basaa | https://mozilladatacollective.com/datasets/cmu5z0yn400fho1079n6b5czp | bas | Audio | CC0 + CGU MDC | ASR | 🟢 télécharger |
| Dictionnaire ɓàsàa (Njock 2019) — Webonary | https://www.webonary.org/basaa/ | bas | Dictionnaire 15 667 entrées | © Njock 2019 / SIL | Lexique principal | 🟡 **demande d'accord écrit** (Njock + SIL Cameroun) |
| Dictionnaire Basaa éd. 2005 (ZIP HTML) | https://www.silcam.org/resources/archives/47253 | bas | Dictionnaire | Conditions SIL | Lexique | 🟡 même accord |
| Basaa-ALCAM-Multimodal | https://mozilladatacollective.com/datasets/cmind910n0096nx07gme9v3wj | bas | 350 entrées + 336 audio | NOODL-1.0 | Lexique / audio de référence ; partenariat | 🟡 **contacter E. Ngue Um** |
| Hyman 2003 « Basaá (A.43) » | https://linguistics.berkeley.edu/~hyman/Basaa_Chapter.pdf | bas | Grammaire | © (pré-print public) | Rédaction des `GrammarRule` citées | 🟢 citer |
| Makasso & Lee 2015, JIPA | https://www.cambridge.org/core/journals/journal-of-the-international-phonetic-association/article/basaa/630CB83A1DB4851CE043540DFCEF2F0A | bas | Phonétique + audio | © CUP | Alphabet / sons / tons | 🟢 citer ; 🔴 audio |
| Redden 1979 | https://eric.ed.gov/?id=ED185833 · https://archive.org/details/descriptivegramm0000redd | ewo | Grammaire + exercices + lexique | © SIU | Grammaire, structure pédagogique | 🟡 demander droits SIU ; sinon citer |
| Essono 2000 | https://books.google.com/books?id=sHtkAAAAMAAJ | ewo | Description linguistique | © UCAC | Grammaire, phonologie | 🟡 partenariat UCAC |
| Owona 2004 (thèse UY1) | — (bibliothèque UY1) | ewo | Orthographe harmonisée | Thèse | **Norme orthographique MBOA** | 🟡 obtenir via UY1 |
| Atangana Ondigui 2007 | https://search.worldcat.org/fr/title/oclc/973940799 | ewo | Dictionnaire bidirectionnel | © Terre Africaine | Lexique principal candidat | 🟡 contacter l'éditeur |
| Mvondo & Tchamna 2019 (Resulam) | https://resulam.com/product/syllabaire-et-dictionnaire-visuel-en-langue-ewondo-french-edition/ | ewo | Syllabaire illustré | © Resulam | Partenaire contenu | 🟡 contacter Resulam |
| Syllabaire *Bií ayǝ́gǝ láŋ ewondo* 1982 | https://www.silcam.org/resources/archives/32930 | ewo | Syllabaire | Conditions SIL | Progression d'alphabétisation | 🟡 demander PDF / droits |
| Alphabets of Cameroon (Hartell 1993) | https://www.silcam.org/resources/archives/5177 | ewo, bas | Alphabets AGLC | Conditions SIL | Référence alphabet | 🟢 citer |
| Bibliographie Afranaph Ewondo | https://afranaphproject.afranaphdatabase.com/images/bibliographies/Ewondo__Afranaph-Bibliography.pdf | ewo | Bibliographie | — | Pistes | 🟢 |
| MMS ASR `facebook/mms-1b-all` | https://huggingface.co/facebook/mms-1b-all | bas (pas ewo) | Modèle ASR | **CC-BY-NC-4.0** | R&D uniquement | 🟡 prototypage hors prod |
| MT560 EN–BAS pairs | https://huggingface.co/datasets/michsethowusu/english-basaa_sentence-pairs_mt560 | bas | Paires parallèles | CC-BY-4.0 déclaré (à vérifier) | Expérimentation MT | 🟡 R&D |
| Alliance Biblique du Cameroun | https://biblesociety-cameroon.org/ | ewo, bas | NT / Bible | © ABC | Corpus parallèle | 🟡 accord de partage de données |
| SIL Cameroun (listes ewo / bas) | https://www.silcam.org/resources/search/language/ewo · …/bas | ewo, bas | 7 + 7 ressources | Conditions SIL | À inventorier | 🟡 consultation manuelle (site instable) |
| MINAC | https://www.minac.gov.cm/ | culture | Portail institutionnel (Musée national, Archives nationales, INAC, textes de loi sur le patrimoine) | Aucune CGU visible | Sources culturelles institutionnelles ; partenariat | 🟡 contact |

### Ressources écartées (REJECTED) et pourquoi
- `Favourez/*`, `LeMisterIA/basaa-models`, `OlameMend/Ewondo-TTS`, `OlameMend/mms-tts-ewo`, `ELRs/Ewondo_Bible` : **absence de licence vérifiable et/ou texte sous-jacent sous copyright tiers**. Un dataset Hugging Face n'est pas libre de droits parce qu'il est en ligne.
- Scans Scribd / Calaméo du Tsala 1955 : diffusion non autorisée.
- `facebook/mms-tts-bsq` : Bassa du **Liberia** (bsq), pas le Basaa du Cameroun (bas). Confusion à éviter dans toutes les recherches futures.
- Modèles MMS en production : licence **non commerciale**, incompatible avec un produit à abonnement.

---

## D0. Constats structurants pour la suite

1. **Il n'existe aucun lexique Ewondo ou Basaa sous licence ouverte.** Le corpus MBOA sera constitué (a) par accords de licence avec les ayants droit (Njock / SIL, Atangana Ondigui, Resulam, SIU, UCAC), (b) par production originale des spécialistes culturels MBOA (saisie, enregistrement, validation), (c) par les phrases CC0 de Common Voice après relecture humaine.
2. **L'audio de vrais locuteurs existe** (≈ 14 h par langue, CC0) mais il est conçu pour l'ASR, pas pour la pédagogie : les `AudioAsset` pédagogiques (mots isolés, dialogues) devront être **enregistrés en studio par MBOA** avec les métadonnées `Speaker / RecordingSession`.
3. **ASR / TTS** : rien d'exploitable commercialement au lancement. Roadmap prononciation limitée à V1–V4 (écouter, ralentir, s'enregistrer, comparer). V5 (ASR) uniquement après entraînement d'un modèle sur Common Voice (CC0) avec un modèle de base sous licence compatible (ex. wav2vec2 / XLS-R — à vérifier au moment du choix).
4. **Partenariats prioritaires à lancer immédiatement (Phase 1)** : ① Dr P. E. Njock & SIL Cameroun (dictionnaire Basaa) ; ② Emmanuel Ngue Um / UY1 (ALCAM Basaa, expertise) ; ③ éditeur Terre Africaine (dictionnaire Ewondo 2007) ; ④ Resulam ; ⑤ Département de langues africaines UY1 (thèse Owona 2004, validateurs) ; ⑥ Alliance Biblique du Cameroun (corpus parallèle, secondaire).
5. **Points à trancher par le porteur du projet** : budget d'enregistrement studio ; recrutement d'au moins 2 validateurs natifs par langue ; mandat pour négocier les licences.

## Limites de cette recherche
- Webonary (`/basaa/overview/copyright/`), les listes SIL Cameroun par langue, Ethnologue, Global Recordings Network et OLAC ont renvoyé 403 / timeout / pages JS pendant la session : ces entrées sont marquées TO_VERIFY et doivent être consultées manuellement.
- Google Scholar, ResearchGate, HAL et Zenodo n'ont pas été interrogés exhaustivement (recherche via moteur général) ; la bibliographie de Hyman 2003 et celle d'Afranaph ont servi d'index.
- Les chiffres de tons / voyelles Ewondo cités depuis Wikipédia sont à confirmer par un spécialiste contre Essono 2000 / Owona 2004 avant toute utilisation pédagogique.
