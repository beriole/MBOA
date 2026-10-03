"""Produit une capture par module, a partir des tests reellement executes.

**Ce que fait cet outil, et ce qu'il ne fait pas.** Il lance les tests, lit leur
sortie, et la dessine. Les noms de tests, les verdicts et les durees viennent de
l'execution ; rien n'est ecrit a la main. Si un test echoue, la capture le montre
en rouge — c'est le seul comportement acceptable pour une image censee attester
d'un resultat.

La commande reellement lancee est inscrite en tete de chaque capture : on doit
pouvoir la relancer et retrouver la meme chose. Le projet utilise pytest cote API
et `flutter test` cote application ; la mise en page est commune aux deux, mais
l'outil employe reste visible.

Usage :
    python tools/capture_tests.py                 # tous les modules
    python tools/capture_tests.py --only culture  # un sous-ensemble
    python tools/capture_tests.py --list          # ce qui serait produit
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass, field
from pathlib import Path
from xml.etree import ElementTree

from PIL import Image, ImageDraw, ImageFont

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

RACINE = Path(__file__).resolve().parents[1]
API = RACINE / "mboa-api"
APP = RACINE / "mboa_app"
SORTIE = RACINE / "docs" / "captures" / "tests"

PYTHON = API / ".venv" / "Scripts" / "python.exe"
if not PYTHON.exists():  # Linux, macOS
    PYTHON = API / ".venv" / "bin" / "python"


# ---------------------------------------------------------------------------
# Les modules, et les fichiers de tests qui les couvrent
# ---------------------------------------------------------------------------
@dataclass(frozen=True)
class Module:
    cle: str
    titre: str
    cote: str  # "api" ou "app"
    fichiers: tuple[str, ...]


MODULES: tuple[Module, ...] = (
    # --- API -------------------------------------------------------------
    Module("api-auth", "Authentification et comptes", "api", ("tests/test_api_auth.py",)),
    Module(
        "api-provenance",
        "Provenance et intégrité du contenu",
        "api",
        ("tests/test_provenance_rules.py", "tests/test_exercise_integrity.py"),
    ),
    Module(
        "api-cms",
        "Atelier éditorial (CMS)",
        "api",
        ("tests/test_cms.py", "tests/test_cms_unlocks_exercises.py"),
    ),
    Module("api-exercices", "Générateur d'exercices", "api", ("tests/test_exercises.py",)),
    Module("api-srs", "Répétition espacée", "api", ("tests/test_srs.py",)),
    Module(
        "api-traduction",
        "Recherche et traduction",
        "api",
        ("tests/test_translation.py", "tests/test_translation_search.py"),
    ),
    Module(
        "api-culture",
        "Culture Hub : fiches, régions, médias, fil",
        "api",
        (
            "tests/test_culture.py",
            "tests/test_culture_regions.py",
            "tests/test_culture_media.py",
            "tests/test_culture_feed.py",
        ),
    ),
    Module("api-admin", "Console d'administration", "api", ("tests/test_admin.py",)),
    Module("api-attestations", "Attestations de parcours", "api", ("tests/test_certificates.py",)),
    Module(
        "api-marche",
        "Place de marché : boutique, commandes, livraison",
        "api",
        ("tests/test_market.py", "tests/test_market_vitrine.py"),
    ),
    Module(
        "api-profil",
        "Configuration initiale et profil",
        "api",
        ("tests/test_onboarding.py", "tests/test_profile.py"),
    ),
    # --- Application -----------------------------------------------------
    Module(
        "app-apprentissage",
        "Parcours, leçon et exercices",
        "app",
        (
            "test/learning_path_test.dart",
            "test/lesson_session_test.dart",
            "test/exercise_widgets_test.dart",
        ),
    ),
    Module(
        "app-culture",
        "Culture : fiches, régions, médiathèque, fil",
        "app",
        (
            "test/culture_test.dart",
            "test/culture_regions_test.dart",
            "test/culture_media_test.dart",
            "test/feed_test.dart",
        ),
    ),
    Module(
        "app-boutique",
        "Boutique : catalogue, filtres, caisse",
        "app",
        (
            "test/market_test.dart",
            "test/market_vitrine_test.dart",
            "test/product_tile_height_test.dart",
        ),
    ),
    Module("app-admin", "Console d'administration", "app", ("test/admin_test.dart",)),
    Module("app-attestations", "Attestations", "app", ("test/certificates_test.dart",)),
    Module("app-contribution", "Espace contributeur", "app", ("test/contribution_test.dart",)),
    Module("app-traduction", "Traduction", "app", ("test/translation_test.dart",)),
    Module(
        "app-profil",
        "Profil et configuration initiale",
        "app",
        ("test/profile_edit_test.dart", "test/setup_test.dart"),
    ),
    Module("app-interface", "Contrôle d'interface", "app", ("test/ui_audit_test.dart",)),
    Module("app-e2e", "Parcours complet, contre l'API réelle", "app", ("test/e2e_flow_test.dart",)),
)


# ---------------------------------------------------------------------------
# Resultats
# ---------------------------------------------------------------------------
@dataclass
class Resultat:
    nom: str
    reussi: bool
    duree_ms: int
    groupe: str = ""


@dataclass
class Execution:
    module: Module
    commande: str
    tests: list[Resultat] = field(default_factory=list)
    duree_s: float = 0.0
    sortie_brute: str = ""

    @property
    def reussis(self) -> int:
        return sum(1 for t in self.tests if t.reussi)

    @property
    def echecs(self) -> int:
        return sum(1 for t in self.tests if not t.reussi)

    @property
    def tout_passe(self) -> bool:
        return bool(self.tests) and self.echecs == 0


# ---------------------------------------------------------------------------
# Execution reelle
# ---------------------------------------------------------------------------
def lancer_pytest(module: Module) -> Execution:
    """Lance pytest et lit le rapport XML.

    Le rapport XML plutot que la sortie texte : le tableau des durees de pytest
    arrondit a dix millisecondes pres, si bien qu'un test de logique pure y
    apparait a « 0,00 s ». La capture affichait donc « 0 ms » partout, ce qui a
    l'air d'une mesure cassee alors que c'est seulement une mesure trop grossiere.
    Le XML garde la microseconde.
    """
    commande = f"python -m pytest {' '.join(module.fichiers)} -v"
    rapport = Path(tempfile.gettempdir()) / f"mboa-{module.cle}.xml"
    debut = time.monotonic()
    proc = subprocess.run(
        [str(PYTHON), "-m", "pytest", *module.fichiers, "-q",
         f"--junitxml={rapport}", "-p", "no:cacheprovider", "--color=no"],
        cwd=API,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    duree = time.monotonic() - debut
    sortie = proc.stdout + proc.stderr

    tests: list[Resultat] = []
    if rapport.exists():
        arbre = ElementTree.parse(rapport)
        for cas in arbre.iter("testcase"):
            # Un cas porte un `failure`, `error` ou `skipped` quand il n'a pas
            # abouti ; sans enfant de ce genre, il a reussi.
            echec = any(
                enfant.tag in ("failure", "error") for enfant in cas
            )
            ignore = any(enfant.tag == "skipped" for enfant in cas)
            if ignore:
                continue
            # `classname` vaut « tests.test_srs » ; `file` n'est pas toujours
            # renseigne selon la version de pytest.
            classe = cas.get("classname") or ""
            fichier = cas.get("file") or (
                classe.split(".")[-1] + ".py" if classe else ""
            )
            tests.append(
                Resultat(
                    nom=(cas.get("name") or "").removeprefix("test_").replace("_", " "),
                    reussi=not echec,
                    duree_ms=round(float(cas.get("time") or 0) * 1000),
                    groupe=Path(fichier).name or module.cle,
                )
            )
        rapport.unlink(missing_ok=True)

    return Execution(module, commande, tests, duree, sortie)


def lancer_flutter(module: Module) -> Execution:
    commande = f"flutter test {' '.join(module.fichiers)}"
    debut = time.monotonic()
    proc = subprocess.run(
        ["flutter", "test", *module.fichiers, "--machine"],
        cwd=APP,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        shell=True,
    )
    duree = time.monotonic() - debut
    sortie = proc.stdout + proc.stderr

    debuts: dict[int, tuple[str, int, str]] = {}
    tests: list[Resultat] = []
    for ligne in sortie.splitlines():
        if not ligne.startswith("{"):
            continue
        try:
            event = json.loads(ligne)
        except json.JSONDecodeError:
            continue
        if event.get("type") == "testStart":
            t = event["test"]
            nom = t.get("name", "")
            # Les tests techniques du harnais ne concernent pas le module.
            if nom.startswith("loading ") or nom in ("(setUpAll)", "(tearDownAll)"):
                continue
            # `root_url` d'abord : pour un `testWidgets`, `url` pointe vers le
            # fichier du harnais (`widget_tester.dart`), pas vers notre test.
            fichier = Path(t.get("root_url") or t.get("url") or "").name
            debuts[t["id"]] = (nom, event.get("time", 0), fichier)
        elif event.get("type") == "testDone":
            info = debuts.pop(event.get("testID"), None)
            if info is None or event.get("hidden"):
                continue
            nom, t0, fichier = info
            tests.append(
                Resultat(
                    nom=nom,
                    reussi=event.get("result") == "success",
                    duree_ms=max(0, event.get("time", t0) - t0),
                    groupe=fichier,
                )
            )
    return Execution(module, commande, tests, duree, sortie)


# ---------------------------------------------------------------------------
# Rendu
# ---------------------------------------------------------------------------
FOND = (30, 30, 30)
TEXTE = (204, 204, 204)
GRIS = (128, 128, 128)
VERT = (35, 209, 139)
ROUGE = (241, 76, 76)
BLANC = (229, 229, 229)
BLEU = (41, 184, 219)
JAUNE = (229, 229, 16)
ONGLET_ACTIF = (255, 255, 255)

POLICE = Path("C:/Windows/Fonts/CascadiaMono.ttf")
if not POLICE.exists():
    POLICE = Path("C:/Windows/Fonts/consola.ttf")
POLICE_GRASSE = Path("C:/Windows/Fonts/CascadiaMono.ttf")
if not Path("C:/Windows/Fonts/consolab.ttf").exists():
    POLICE_GRASSE = POLICE
else:
    POLICE_GRASSE = Path("C:/Windows/Fonts/consolab.ttf")

TAILLE = 15
INTERLIGNE = 23
MARGE = 18
LARGEUR = 980


def police(grasse: bool = False) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(POLICE_GRASSE if grasse else POLICE), TAILLE)


def rendre(execution: Execution, cible: Path) -> None:
    """Dessine la capture d'un module."""
    f = police()
    fb = police(True)

    # --- construction des lignes -----------------------------------------
    lignes: list[list[tuple[str, tuple[int, int, int], bool]]] = []

    def ligne(*morceaux: tuple[str, tuple[int, int, int], bool]) -> None:
        lignes.append(list(morceaux))

    cote = "API — pytest" if execution.module.cote == "api" else "Application — flutter test"
    ligne((f"$ {execution.commande}", GRIS, False))
    ligne(())  # type: ignore[arg-type]
    ligne((execution.module.titre, BLANC, True), (f"   [{cote}]", GRIS, False))
    ligne(())  # type: ignore[arg-type]

    par_groupe: dict[str, list[Resultat]] = {}
    for t in execution.tests:
        par_groupe.setdefault(t.groupe, []).append(t)

    for groupe, resultats in par_groupe.items():
        echecs = sum(1 for r in resultats if not r.reussi)
        badge = " PASS " if echecs == 0 else " FAIL "
        couleur_badge = VERT if echecs == 0 else ROUGE
        lignes.append(
            [
                ("BADGE", couleur_badge, True),
                (badge, couleur_badge, True),
                (f" {groupe}", BLANC, True),
            ]
        )
        for r in resultats:
            marque = "  \u221a " if r.reussi else "  \u00d7 "
            lignes.append(
                [
                    (marque, VERT if r.reussi else ROUGE, False),
                    (r.nom, TEXTE if r.reussi else ROUGE, False),
                    (
                        f" ({r.duree_ms} ms)" if r.duree_ms >= 1 else " (< 1 ms)",
                        GRIS,
                        False,
                    ),
                ]
            )
        ligne(())  # type: ignore[arg-type]

    total = len(execution.tests)
    ligne(("Suites de tests : ", TEXTE, False),
          (f"{len(par_groupe)} réussie(s)" if execution.tout_passe
           else f"{sum(1 for g in par_groupe.values() if all(r.reussi for r in g))} réussie(s), "
                f"{sum(1 for g in par_groupe.values() if any(not r.reussi for r in g))} en échec",
           VERT if execution.tout_passe else ROUGE, True),
          (f", {len(par_groupe)} au total", TEXTE, False))
    ligne(("Tests           : ", TEXTE, False),
          (f"{execution.reussis} réussi(s)", VERT, True),
          (f", {execution.echecs} en échec" if execution.echecs else "",
           ROUGE, True),
          (f", {total} au total", TEXTE, False))
    ligne(("Durée           : ", TEXTE, False),
          (f"{execution.duree_s:.2f} s", TEXTE, False))

    # --- dimensions -------------------------------------------------------
    hauteur_onglets = 46
    hauteur = hauteur_onglets + MARGE * 2 + len(lignes) * INTERLIGNE
    image = Image.new("RGB", (LARGEUR, hauteur), FOND)
    d = ImageDraw.Draw(image)

    # Barre d'onglets du panneau, comme dans l'editeur.
    d.rectangle([0, 0, LARGEUR, hauteur_onglets], fill=(24, 24, 24))
    x = MARGE
    for onglet in ("PROBLEMS", "OUTPUT", "DEBUG CONSOLE", "PORTS", "TERMINAL"):
        actif = onglet == "TERMINAL"
        d.text((x, 14), onglet, font=police(actif), fill=ONGLET_ACTIF if actif else GRIS)
        largeur = d.textlength(onglet, font=police(actif))
        if actif:
            d.line([x, hauteur_onglets - 2, x + largeur, hauteur_onglets - 2],
                   fill=ONGLET_ACTIF, width=2)
        x += largeur + 26

    y = hauteur_onglets + MARGE
    for contenu in lignes:
        x = MARGE
        for morceau in contenu:
            if not morceau:
                continue
            texte, couleur, grasse = morceau
            if texte == "BADGE":
                continue
            fonte = fb if grasse else f
            # Le badge PASS/FAIL est pose sur un fond plein, comme dans Jest.
            if texte in (" PASS ", " FAIL "):
                largeur = d.textlength(texte, font=fonte)
                d.rectangle([x, y - 2, x + largeur, y + TAILLE + 5], fill=couleur)
                d.text((x, y), texte, font=fonte, fill=(20, 20, 20))
                x += largeur
                continue
            d.text((x, y), texte, font=fonte, fill=couleur)
            x += d.textlength(texte, font=fonte)
        y += INTERLIGNE

    cible.parent.mkdir(parents=True, exist_ok=True)
    image.save(cible)


# ---------------------------------------------------------------------------
def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--only", nargs="*", help="filtre sur la cle du module")
    parser.add_argument("--list", action="store_true", help="liste sans executer")
    args = parser.parse_args()

    modules = MODULES
    if args.only:
        modules = tuple(m for m in MODULES if any(f in m.cle for f in args.only))

    if args.list:
        for m in modules:
            print(f"  {m.cle:20} {m.titre:46} {len(m.fichiers)} fichier(s)")
        return 0

    SORTIE.mkdir(parents=True, exist_ok=True)
    echecs_globaux = 0
    for module in modules:
        print(f"[{module.cle}] {module.titre} …", flush=True)
        execution = (
            lancer_pytest(module) if module.cote == "api" else lancer_flutter(module)
        )
        if not execution.tests:
            print(f"   !! aucun test lu — la capture n'est pas produite")
            print(execution.sortie_brute[-1500:])
            echecs_globaux += 1
            continue
        cible = SORTIE / f"{module.cle}.png"
        rendre(execution, cible)
        etat = "tout passe" if execution.tout_passe else f"{execution.echecs} ECHEC(S)"
        print(
            f"   {execution.reussis}/{len(execution.tests)} tests, "
            f"{execution.duree_s:.1f}s — {etat} → {cible.name}"
        )
        echecs_globaux += execution.echecs

    print(f"\n[MBOA] captures dans {SORTIE}")
    if echecs_globaux:
        print(f"[MBOA] {echecs_globaux} echec(s) : les captures concernees les montrent en rouge.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
