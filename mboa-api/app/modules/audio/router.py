"""Service des fichiers audio par identifiant opaque.

Deux raisons de ne pas exposer l'URL d'origine dans le contenu des exercices :

1. Elle contient le nom du fichier, donc souvent le mot lui-meme : la bonne
   reponse d'un exercice d'ecoute serait lisible dans la reponse de l'API.
2. Elle lie l'application a un hebergeur precis.

Deux modes, selon ce que contient `file_key` :

- **fichier local** (`audio/<id>.wav`) : servi directement. C'est le mode normal
  apres `scripts.fetch_audio`. Une ecoute coute alors quelques millisecondes au
  lieu des une a deux secondes qu'imposait un aller-retour vers Wikimedia --
  assez pour que l'apprenant reponde avant d'avoir entendu le son.
- **URL distante** : redirection, tant que le fichier n'a pas ete rapatrie.

Dans les deux cas l'attribution accompagne la reponse : les licences CC BY-SA
l'exigent, et elle ne doit pas se perdre entre le stockage et l'ecran.
"""

import uuid

from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import FileResponse, RedirectResponse
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_session

router = APIRouter(prefix="/audio", tags=["audio"])

#: Racine des fichiers rapatries par `scripts.fetch_audio`.
MEDIA_ROOT = Path(__file__).resolve().parents[3] / "media"


@router.get("/{asset_id}", response_class=RedirectResponse)
async def get_audio(asset_id: uuid.UUID, db: AsyncSession = Depends(get_session)):
    """Renvoie le fichier audio correspondant.

    Volontairement public : une balise <audio> ne peut pas porter d'en-tete
    d'authentification, et ces enregistrements sont sous licence libre.
    """
    row = (
        await db.execute(
            text("SELECT file_key, attribution FROM audio.audio_assets WHERE id = :id"),
            {"id": asset_id},
        )
    ).one_or_none()

    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Audio introuvable.")

    file_key, attribution = row[0], row[1] or ""
    # L'attribution voyage avec le fichier : exigence des licences CC BY-SA.
    entetes = {"X-Attribution": attribution}

    if file_key.startswith("http"):
        return RedirectResponse(
            url=file_key,
            status_code=status.HTTP_307_TEMPORARY_REDIRECT,
            headers=entetes,
        )

    chemin = (MEDIA_ROOT / file_key).resolve()
    # Le chemin vient de la base, mais on verifie quand meme qu'il ne sort pas
    # du dossier des medias : une cle mal formee ne doit pas ouvrir le disque.
    if not chemin.is_relative_to(MEDIA_ROOT.resolve()) or not chemin.is_file():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Fichier audio absent du stockage local.",
        )

    return FileResponse(
        chemin,
        media_type="audio/wav",
        headers={
            **entetes,
            # Le contenu ne change jamais pour un identifiant donne.
            "Cache-Control": "public, max-age=604800, immutable",
        },
    )
