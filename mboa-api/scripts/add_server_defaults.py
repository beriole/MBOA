"""Ajoute les valeurs par defaut cote serveur aux colonnes NOT NULL.

Necessaire parce que MBOA insere aussi en SQL brut (seed, imports CMS, psql) :
un defaut Python seul ne protege que l'ORM.
Script ponctuel, conserve pour tracabilite.
"""

import pathlib

PATCHES = [
    (
        "app/shared/mixins.py",
        "default=ContentStatus.DRAFT,\n        nullable=False,",
        'default=ContentStatus.DRAFT,\n        server_default="DRAFT",\n        nullable=False,',
    ),
    (
        "app/modules/corpus/models.py",
        "row_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)",
        'row_count: Mapped[int] = mapped_column(\n        Integer, default=0, server_default="0", nullable=False\n    )',
    ),
    (
        "app/modules/corpus/models.py",
        'normalizer_version: Mapped[str] = mapped_column(String(32), default="1.0", nullable=False)',
        'normalizer_version: Mapped[str] = mapped_column(\n        String(32), default="1.0", server_default="1.0", nullable=False\n    )',
    ),
    (
        "app/modules/corpus/models.py",
        'state: Mapped[str] = mapped_column(String(16), default="RAW", nullable=False)',
        'state: Mapped[str] = mapped_column(\n        String(16), default="RAW", server_default="RAW", nullable=False\n    )',
    ),
    (
        "app/modules/corpus/models.py",
        "difficulty: Mapped[int] = mapped_column(Integer, default=1, nullable=False)",
        'difficulty: Mapped[int] = mapped_column(\n        Integer, default=1, server_default="1", nullable=False\n    )',
    ),
    (
        "app/modules/audio/models.py",
        "is_native: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)",
        'is_native: Mapped[bool] = mapped_column(\n        Boolean, default=True, server_default="true", nullable=False\n    )',
    ),
    (
        "app/modules/audio/models.py",
        "consent_scope: Mapped[list[str]] = mapped_column(ARRAY(Text), default=list, nullable=False)",
        'consent_scope: Mapped[list[str]] = mapped_column(\n        ARRAY(Text), default=list, server_default="{}", nullable=False\n    )',
    ),
    (
        "app/modules/audio/models.py",
        "default=SourceLicense.UNKNOWN,\n        nullable=False,",
        'default=SourceLicense.UNKNOWN,\n        server_default="UNKNOWN",\n        nullable=False,',
    ),
    (
        "app/modules/audio/models.py",
        "default=AudioQuality.ACCEPTABLE,\n        nullable=False,",
        'default=AudioQuality.ACCEPTABLE,\n        server_default="ACCEPTABLE",\n        nullable=False,',
    ),
    (
        "app/modules/learning/models.py",
        "position: Mapped[int] = mapped_column(Integer, default=0, nullable=False)",
        'position: Mapped[int] = mapped_column(\n        Integer, default=0, server_default="0", nullable=False\n    )',
    ),
    (
        "app/modules/learning/models.py",
        "estimated_minutes: Mapped[int] = mapped_column(Integer, default=5, nullable=False)",
        'estimated_minutes: Mapped[int] = mapped_column(\n        Integer, default=5, server_default="5", nullable=False\n    )',
    ),
    (
        "app/modules/learning/models.py",
        "xp_reward: Mapped[int] = mapped_column(Integer, default=10, nullable=False)",
        'xp_reward: Mapped[int] = mapped_column(\n        Integer, default=10, server_default="10", nullable=False\n    )',
    ),
    (
        "app/modules/learning/models.py",
        "schema_version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)",
        'schema_version: Mapped[int] = mapped_column(\n        Integer, default=1, server_default="1", nullable=False\n    )',
    ),
    (
        "app/modules/learning/models.py",
        "generated_from: Mapped[list] = mapped_column(JSONB, default=list, nullable=False)",
        'generated_from: Mapped[list] = mapped_column(\n        JSONB, default=list, server_default="[]", nullable=False\n    )',
    ),
    (
        "app/modules/learning/models.py",
        'generator_version: Mapped[str] = mapped_column(String(32), default="1.0", nullable=False)',
        'generator_version: Mapped[str] = mapped_column(\n        String(32), default="1.0", server_default="1.0", nullable=False\n    )',
    ),
    (
        "app/modules/learning/models.py",
        "difficulty: Mapped[int] = mapped_column(Integer, default=1, nullable=False)",
        'difficulty: Mapped[int] = mapped_column(\n        Integer, default=1, server_default="1", nullable=False\n    )',
    ),
    (
        "app/modules/learning/models.py",
        "is_current: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)",
        'is_current: Mapped[bool] = mapped_column(\n        Boolean, default=True, server_default="true", nullable=False\n    )',
    ),
    (
        "app/modules/learning/models.py",
        "target_vocab_ids: Mapped[list[uuid.UUID]] = mapped_column(\n        ARRAY(PGUUID(as_uuid=True)), default=list, nullable=False\n    )",
        'target_vocab_ids: Mapped[list[uuid.UUID]] = mapped_column(\n        ARRAY(PGUUID(as_uuid=True)), default=list, server_default="{}", nullable=False\n    )',
    ),
    (
        "app/modules/learning/models.py",
        "target_sentence_ids: Mapped[list[uuid.UUID]] = mapped_column(\n        ARRAY(PGUUID(as_uuid=True)), default=list, nullable=False\n    )",
        'target_sentence_ids: Mapped[list[uuid.UUID]] = mapped_column(\n        ARRAY(PGUUID(as_uuid=True)), default=list, server_default="{}", nullable=False\n    )',
    ),
    (
        "app/modules/iam/models.py",
        "default=UserRole.LEARNER,\n        nullable=False,",
        'default=UserRole.LEARNER,\n        server_default="LEARNER",\n        nullable=False,',
    ),
    (
        "app/modules/iam/models.py",
        "is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)",
        'is_active: Mapped[bool] = mapped_column(\n        Boolean, default=True, server_default="true", nullable=False\n    )',
    ),
    (
        "app/modules/iam/models.py",
        'locale: Mapped[str] = mapped_column(String(8), default="fr", nullable=False)',
        'locale: Mapped[str] = mapped_column(\n        String(8), default="fr", server_default="fr", nullable=False\n    )',
    ),
    (
        "app/modules/iam/models.py",
        'timezone: Mapped[str] = mapped_column(String(64), default="Africa/Douala", nullable=False)',
        'timezone: Mapped[str] = mapped_column(\n        String(64), default="Africa/Douala", server_default="Africa/Douala", nullable=False\n    )',
    ),
    (
        "app/modules/iam/models.py",
        "daily_goal_xp: Mapped[int] = mapped_column(default=20, nullable=False)",
        'daily_goal_xp: Mapped[int] = mapped_column(\n        default=20, server_default="20", nullable=False\n    )',
    ),
    (
        "app/modules/progress/models.py",
        "xp_awarded: Mapped[int] = mapped_column(Integer, default=0, nullable=False)",
        'xp_awarded: Mapped[int] = mapped_column(\n        Integer, default=0, server_default="0", nullable=False\n    )',
    ),
    (
        "app/modules/progress/models.py",
        'origin: Mapped[str] = mapped_column(String(16), default="ONLINE", nullable=False)',
        'origin: Mapped[str] = mapped_column(\n        String(16), default="ONLINE", server_default="ONLINE", nullable=False\n    )',
    ),
    (
        "app/modules/progress/models.py",
        "default=ProgressStatus.AVAILABLE,\n        nullable=False,",
        'default=ProgressStatus.AVAILABLE,\n        server_default="AVAILABLE",\n        nullable=False,',
    ),
    (
        "app/modules/progress/models.py",
        "best_score: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)",
        'best_score: Mapped[float] = mapped_column(\n        Float, default=0.0, server_default="0", nullable=False\n    )',
    ),
    (
        "app/modules/progress/models.py",
        "attempts: Mapped[int] = mapped_column(Integer, default=0, nullable=False)",
        'attempts: Mapped[int] = mapped_column(\n        Integer, default=0, server_default="0", nullable=False\n    )',
    ),
    (
        "app/modules/progress/models.py",
        "default=MasteryState.NEW,\n        nullable=False,",
        'default=MasteryState.NEW,\n        server_default="NEW",\n        nullable=False,',
    ),
    (
        "app/modules/progress/models.py",
        "times_seen: Mapped[int] = mapped_column(Integer, default=0, nullable=False)",
        'times_seen: Mapped[int] = mapped_column(\n        Integer, default=0, server_default="0", nullable=False\n    )',
    ),
    (
        "app/modules/progress/models.py",
        "correct_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)",
        'correct_count: Mapped[int] = mapped_column(\n        Integer, default=0, server_default="0", nullable=False\n    )',
    ),
    (
        "app/modules/progress/models.py",
        "wrong_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)",
        'wrong_count: Mapped[int] = mapped_column(\n        Integer, default=0, server_default="0", nullable=False\n    )',
    ),
    (
        "app/modules/progress/models.py",
        "interval_days: Mapped[int] = mapped_column(Integer, default=0, nullable=False)",
        'interval_days: Mapped[int] = mapped_column(\n        Integer, default=0, server_default="0", nullable=False\n    )',
    ),
    (
        "app/modules/progress/models.py",
        "mastery_score: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)",
        'mastery_score: Mapped[float] = mapped_column(\n        Float, default=0.0, server_default="0", nullable=False\n    )',
    ),
    (
        "app/modules/progress/models.py",
        "lapses: Mapped[int] = mapped_column(Integer, default=0, nullable=False)",
        'lapses: Mapped[int] = mapped_column(\n        Integer, default=0, server_default="0", nullable=False\n    )',
    ),
    (
        "app/modules/progress/models.py",
        "current_days: Mapped[int] = mapped_column(Integer, default=0, nullable=False)",
        'current_days: Mapped[int] = mapped_column(\n        Integer, default=0, server_default="0", nullable=False\n    )',
    ),
    (
        "app/modules/progress/models.py",
        "longest_days: Mapped[int] = mapped_column(Integer, default=0, nullable=False)",
        'longest_days: Mapped[int] = mapped_column(\n        Integer, default=0, server_default="0", nullable=False\n    )',
    ),
    (
        "app/modules/progress/models.py",
        "is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)",
        'is_active: Mapped[bool] = mapped_column(\n        Boolean, default=True, server_default="true", nullable=False\n    )',
    ),
]


def main() -> None:
    applied = missing = 0
    for path, old, new in PATCHES:
        file = pathlib.Path(path)
        content = file.read_text(encoding="utf-8")
        if old in content:
            file.write_text(content.replace(old, new, 1), encoding="utf-8")
            applied += 1
        else:
            print(f"  NON TROUVE : {path} | {old.splitlines()[0][:70]}")
            missing += 1
    print(f"\n{applied} remplacements appliques, {missing} introuvables")


if __name__ == "__main__":
    main()
