# Captures des tests par module

Images produites par `python tools/capture_tests.py`, à partir de **l'exécution
réelle** des tests. Les noms, les verdicts et les durées viennent du rapport
JUnit de pytest et du flux JSON de `flutter test` ; rien n'est saisi à la main.
Un test en échec apparaît en rouge, avec le badge `FAIL`.

Chaque image porte la commande exacte qui la produit : elle est rejouable.

Dernière série : 21 modules, 379 tests,
**374 réussis**, **5 en échec**.

## API — pytest

225/225 tests.

| Module | Capture | Tests | Durée | État |
|---|---|---|---|---|
| Authentification et comptes | `api-auth.png` | 6/6 | 6.4 s | ✅ tout passe |
| Provenance et intégrité du contenu | `api-provenance.png` | 14/14 | 5.3 s | ✅ tout passe |
| Atelier éditorial (CMS) | `api-cms.png` | 17/17 | 22.3 s | ✅ tout passe |
| Générateur d'exercices | `api-exercices.png` | 14/14 | 2.7 s | ✅ tout passe |
| Répétition espacée | `api-srs.png` | 7/7 | 3.7 s | ✅ tout passe |
| Recherche et traduction | `api-traduction.png` | 20/20 | 11.9 s | ✅ tout passe |
| Culture Hub : fiches, régions, médias, fil | `api-culture.png` | 42/42 | 29.8 s | ✅ tout passe |
| Console d'administration | `api-admin.png` | 23/23 | 22.9 s | ✅ tout passe |
| Attestations de parcours | `api-attestations.png` | 16/16 | 24.5 s | ✅ tout passe |
| Place de marché : boutique, commandes, livraison | `api-marche.png` | 43/43 | 86.2 s | ✅ tout passe |
| Configuration initiale et profil | `api-profil.png` | 23/23 | 15.4 s | ✅ tout passe |

## Application — flutter test

149/154 tests.

| Module | Capture | Tests | Durée | État |
|---|---|---|---|---|
| Parcours, leçon et exercices | `app-apprentissage.png` | 17/17 | 10.0 s | ✅ tout passe |
| Culture : fiches, régions, médiathèque, fil | `app-culture.png` | 46/46 | 14.6 s | ✅ tout passe |
| Boutique : catalogue, filtres, caisse | `app-boutique.png` | 25/29 | 15.7 s | ❌ 4 échec(s) |
| Console d'administration | `app-admin.png` | 14/14 | 9.7 s | ✅ tout passe |
| Attestations | `app-attestations.png` | 9/9 | 7.4 s | ✅ tout passe |
| Espace contributeur | `app-contribution.png` | 8/8 | 8.9 s | ✅ tout passe |
| Traduction | `app-traduction.png` | 8/8 | 12.8 s | ✅ tout passe |
| Profil et configuration initiale | `app-profil.png` | 14/14 | 13.4 s | ✅ tout passe |
| Contrôle d'interface | `app-interface.png` | 8/8 | 16.7 s | ✅ tout passe |
| Parcours complet, contre l'API réelle | `app-e2e.png` | 0/1 | 51.3 s | ❌ 1 échec(s) |

> Les fichiers `*_captures_test.dart`, qui produisent les captures d'écran du
> dossier, ne sont pas inclus ici : ils fabriquent des images, ils ne vérifient
> pas de comportement. Ils expliquent l'écart entre les 154 tests
> ci-dessus et les 171 de la suite complète.

## Comment lire une durée

Le premier test d'un fichier porte une durée bien plus élevée que les suivants
(1 586 ms contre 1 ms, par exemple). Ce n'est pas lui qui est lent : la mise en
place de la base de test lui est imputée, comme le fait Jest. Les suivants
mesurent le test seul.
