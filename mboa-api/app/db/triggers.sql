-- =====================================================================
-- MBOA : regles d'integrite du contenu, appliquees par PostgreSQL.
--
-- Ces regles traduisent les SS2, SS4, SS5 et SS13 du cahier des charges.
-- Elles sont volontairement placees dans la base et non dans le code Python :
-- meme un acces direct par psql ou par un futur script d'import ne peut pas
-- publier un contenu sans source ni validation humaine.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Cycle de vie du contenu
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION prov.enforce_content_status()
RETURNS TRIGGER AS $$
DECLARE
    v_language_id   uuid;
    v_accepted      boolean;
    v_habilitated   boolean;
    v_payload       jsonb;
BEGIN
    -- On ne controle que les changements de statut.
    IF TG_OP = 'UPDATE' AND NEW.status IS NOT DISTINCT FROM OLD.status THEN
        RETURN NEW;
    END IF;

    -- REGLE 1 : pas de contenu exploitable sans source identifiee (SS4).
    IF NEW.status IN ('VALIDATED', 'PUBLISHED') AND NEW.source_id IS NULL THEN
        RAISE EXCEPTION
            'MBOA[source_manquante] % % : le statut % exige une source (SS4).',
            TG_TABLE_NAME, NEW.id, NEW.status
            USING ERRCODE = 'check_violation';
    END IF;

    -- REGLE 2 : PUBLISHED ne peut venir que de VALIDATED (SS2).
    -- "Aucun contenu linguistique genere automatiquement ne doit passer
    --  directement a PUBLISHED."
    IF NEW.status = 'PUBLISHED' THEN
        IF TG_OP = 'INSERT' OR OLD.status <> 'VALIDATED' THEN
            RAISE EXCEPTION
                'MBOA[publication_directe] % % : PUBLISHED exige un passage prealable par VALIDATED (SS2).',
                TG_TABLE_NAME, NEW.id
                USING ERRCODE = 'check_violation';
        END IF;
    END IF;

    -- REGLE 3 : validation humaine effective (SS5).
    IF NEW.status = 'VALIDATED' THEN
        IF NEW.validated_by IS NULL THEN
            RAISE EXCEPTION
                'MBOA[validateur_manquant] % % : VALIDATED exige un validateur humain (SS5).',
                TG_TABLE_NAME, NEW.id
                USING ERRCODE = 'check_violation';
        END IF;

        -- REGLE 4 : separation de la saisie et de la validation.
        IF NEW.created_by IS NOT NULL AND NEW.validated_by = NEW.created_by THEN
            RAISE EXCEPTION
                'MBOA[auto_validation] % % : le redacteur ne peut pas valider son propre contenu.',
                TG_TABLE_NAME, NEW.id
                USING ERRCODE = 'check_violation';
        END IF;

        -- REGLE 5 : une decision ACCEPT doit exister dans l'historique.
        SELECT EXISTS (
            SELECT 1 FROM prov.content_validations cv
            WHERE cv.target_type = TG_TABLE_NAME
              AND cv.target_id = NEW.id
              AND cv.validator_contributor_id = NEW.validated_by
              AND cv.decision = 'ACCEPT'
        ) INTO v_accepted;

        IF NOT v_accepted THEN
            RAISE EXCEPTION
                'MBOA[decision_absente] % % : aucune decision ACCEPT enregistree pour ce validateur (SS5).',
                TG_TABLE_NAME, NEW.id
                USING ERRCODE = 'check_violation';
        END IF;

        -- REGLE 6 : le validateur doit etre habilite pour cette langue.
        v_payload := to_jsonb(NEW);
        IF v_payload ? 'language_id' AND (v_payload->>'language_id') IS NOT NULL THEN
            v_language_id := (v_payload->>'language_id')::uuid;

            SELECT EXISTS (
                SELECT 1 FROM prov.validation_assignments va
                WHERE va.contributor_id = NEW.validated_by
                  AND va.language_id = v_language_id
                  AND va.is_active
            ) INTO v_habilitated;

            IF NOT v_habilitated THEN
                RAISE EXCEPTION
                    'MBOA[validateur_non_habilite] % % : validateur non habilite pour cette langue (SS5).',
                    TG_TABLE_NAME, NEW.id
                    USING ERRCODE = 'check_violation';
            END IF;
        END IF;

        NEW.validated_at := COALESCE(NEW.validated_at, now());
    END IF;

    IF NEW.status = 'PUBLISHED' THEN
        NEW.published_at := COALESCE(NEW.published_at, now());
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- ---------------------------------------------------------------------
-- 2. Un exercice ne peut citer que du contenu valide (SS13)
--    "Les mauvaises reponses ne doivent pas enseigner une information fausse."
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION learn.enforce_exercise_sources()
RETURNS TRIGGER AS $$
DECLARE
    v_ref        jsonb;
    v_type       text;
    v_id         uuid;
    v_status     text;
BEGIN
    IF NEW.generated_from IS NULL OR jsonb_array_length(NEW.generated_from) = 0 THEN
        IF NEW.status IN ('VALIDATED', 'PUBLISHED') THEN
            RAISE EXCEPTION
                'MBOA[exercice_sans_origine] exercice % : generated_from est vide (SS13).', NEW.id
                USING ERRCODE = 'check_violation';
        END IF;
        RETURN NEW;
    END IF;

    FOR v_ref IN SELECT * FROM jsonb_array_elements(NEW.generated_from)
    LOOP
        v_type := v_ref->>'type';
        v_id := (v_ref->>'id')::uuid;

        IF v_type = 'VOCAB' THEN
            SELECT status::text INTO v_status FROM corpus.vocabulary_items WHERE id = v_id;
        ELSIF v_type = 'SENTENCE' THEN
            SELECT status::text INTO v_status FROM corpus.example_sentences WHERE id = v_id;
        ELSIF v_type = 'GRAMMAR' THEN
            SELECT status::text INTO v_status FROM corpus.grammar_rules WHERE id = v_id;
        ELSE
            RAISE EXCEPTION
                'MBOA[origine_inconnue] exercice % : type d''origine inconnu %.', NEW.id, v_type
                USING ERRCODE = 'check_violation';
        END IF;

        IF v_status IS NULL THEN
            RAISE EXCEPTION
                'MBOA[origine_introuvable] exercice % : % % introuvable dans le corpus.',
                NEW.id, v_type, v_id
                USING ERRCODE = 'foreign_key_violation';
        END IF;

        IF v_status NOT IN ('VALIDATED', 'PUBLISHED') THEN
            RAISE EXCEPTION
                'MBOA[origine_non_validee] exercice % : % % est au statut % (SS13).',
                NEW.id, v_type, v_id, v_status
                USING ERRCODE = 'check_violation';
        END IF;
    END LOOP;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- ---------------------------------------------------------------------
-- 3. Traçabilite : toute transition de statut est journalisee
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS prov.status_transitions (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    target_type    text        NOT NULL,
    target_id      uuid        NOT NULL,
    from_status    text,
    to_status      text        NOT NULL,
    actor          uuid,
    occurred_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_status_transitions_target
    ON prov.status_transitions (target_type, target_id);

CREATE OR REPLACE FUNCTION prov.log_status_transition()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' AND NEW.status IS NOT DISTINCT FROM OLD.status THEN
        RETURN NEW;
    END IF;

    INSERT INTO prov.status_transitions (target_type, target_id, from_status, to_status, actor)
    VALUES (
        TG_TABLE_NAME,
        NEW.id,
        CASE WHEN TG_OP = 'UPDATE' THEN OLD.status::text ELSE NULL END,
        NEW.status::text,
        COALESCE(NEW.validated_by, NEW.created_by)
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- ---------------------------------------------------------------------
-- 4. Attestations de parcours (SS15)
--
-- Une attestation ne doit pas pouvoir naitre d'un INSERT direct : la
-- condition qu'elle affirme - « toutes les lecons de cette section ont ete
-- terminees » - est verifiee ici, au plus pres de la donnee.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION progress.enforce_certificate_completion()
RETURNS TRIGGER AS $$
DECLARE
    v_total     integer;
    v_done      integer;
BEGIN
    SELECT count(*) INTO v_total
    FROM learn.lessons l
    JOIN learn.units u ON u.id = l.unit_id
    WHERE u.section_id = NEW.section_id;

    IF v_total = 0 THEN
        RAISE EXCEPTION
            'MBOA[section_vide] attestation % : une section sans lecon ne s''atteste pas.',
            NEW.id
            USING ERRCODE = 'check_violation';
    END IF;

    SELECT count(*) INTO v_done
    FROM learn.lessons l
    JOIN learn.units u ON u.id = l.unit_id
    JOIN progress.lesson_progress p
      ON p.lesson_id = l.id AND p.user_id = NEW.user_id
    WHERE u.section_id = NEW.section_id
      AND p.status = 'COMPLETED';

    IF v_done < v_total THEN
        RAISE EXCEPTION
            'MBOA[parcours_incomplet] attestation % : % lecon(s) terminee(s) sur % (SS15).',
            NEW.id, v_done, v_total
            USING ERRCODE = 'check_violation';
    END IF;

    -- Le nombre atteste doit etre celui du parcours reel, pas un chiffre libre.
    IF NEW.lessons_completed <> v_done OR NEW.lessons_total <> v_total THEN
        RAISE EXCEPTION
            'MBOA[chiffres_incoherents] attestation % : % / % ne correspond pas au parcours (% / %).',
            NEW.id, NEW.lessons_completed, NEW.lessons_total, v_done, v_total
            USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- ---------------------------------------------------------------------
-- 5. Place de marche (SS45 a SS48)
--
-- Deux regles, posees ici parce qu'elles ne doivent dependre d'aucun code
-- applicatif ni d'aucune bonne intention.
-- ---------------------------------------------------------------------

-- 5.1 L'argent ne passe pas par MBOA.
--
-- La plateforme n'a ni entite juridique ni compte marchand. Le seul reglement
-- possible est donc l'espece remise au livreur a la livraison. Deux choses sont
-- verrouillees ici : le statut PAID, que MBOA ne peut pas constater faute
-- d'avoir rien encaisse, et tout mode de paiement qui n'est pas branche. Un
-- bouton « payer par mobile money » qui ne debiterait rien ferait perdre de
-- l'argent a quelqu'un ; un statut « paye » sans encaissement serait un
-- mensonge de la meme famille qu'un mot invente.
CREATE OR REPLACE FUNCTION market.enforce_no_payment()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'PAID' THEN
        RAISE EXCEPTION
            'MBOA[encaissement_absent] commande % : MBOA n''encaisse rien, elle ne peut pas '
            'declarer une commande payee. Le reglement se fait en especes a la livraison.',
            NEW.reference
            USING ERRCODE = 'check_violation';
    END IF;

    IF NEW.payment_mode NOT IN ('CASH_ON_DELIVERY', 'SIMULATION') THEN
        RAISE EXCEPTION
            'MBOA[mode_de_paiement_non_branche] commande % : le mode % n''est pas raccorde.',
            NEW.reference, NEW.payment_mode
            USING ERRCODE = 'check_violation';
    END IF;

    -- Une commande ne peut pas porter la marque d'un reglement simule si elle
    -- n'est pas une simulation. Sans cela, le marqueur pourrait etre pose sur
    -- une vraie commande, et l'acheteur croire qu'il a deja paye.
    IF NEW.simulated_paid_at IS NOT NULL AND NEW.payment_mode <> 'SIMULATION' THEN
        RAISE EXCEPTION
            'MBOA[simulation_hors_simulation] commande % : un reglement simule ne '
            'peut etre porte que par une commande en mode SIMULATION.',
            NEW.reference
            USING ERRCODE = 'check_violation';
    END IF;

    -- Et on n'efface pas la marque : une commande simulee le reste. La retirer
    -- ferait passer une demonstration pour une vente reelle.
    IF TG_OP = 'UPDATE'
       AND OLD.simulated_paid_at IS NOT NULL
       AND NEW.simulated_paid_at IS NULL THEN
        RAISE EXCEPTION
            'MBOA[simulation_indelebile] commande % : une commande reglee en '
            'simulation ne peut pas etre presentee ensuite comme une vente reelle.',
            NEW.reference
            USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- 5.2 Un objet ne se reclame pas d'une source qui n'en est pas une.
--
-- Une fiche produit qui annonce « rattache a la fiche culturelle X » ne peut
-- pointer que vers une fiche PUBLISHED, donc sourcee et validee (SS3, SS20).
-- Sinon, l'affirmation reste une declaration de l'artisan, affichee comme telle.
CREATE OR REPLACE FUNCTION market.enforce_cultural_claim()
RETURNS TRIGGER AS $$
DECLARE
    v_status text;
BEGIN
    IF NEW.cultural_claim_status = 'LINKED_TO_SOURCE' THEN
        IF NEW.cultural_content_id IS NULL THEN
            RAISE EXCEPTION
                'MBOA[rattachement_absent] produit % : un rattachement a une source '
                'exige une fiche culturelle.',
                NEW.id
                USING ERRCODE = 'check_violation';
        END IF;

        SELECT status::text INTO v_status
        FROM culture.cultural_contents WHERE id = NEW.cultural_content_id;

        IF v_status IS DISTINCT FROM 'PUBLISHED' THEN
            RAISE EXCEPTION
                'MBOA[source_non_publiee] produit % : la fiche culturelle invoquee est au '
                'statut %, elle ne peut pas servir de caution.',
                NEW.id, COALESCE(v_status, 'introuvable')
                USING ERRCODE = 'check_violation';
        END IF;
    END IF;

    -- Une affirmation culturelle sans texte n'a rien a qualifier.
    IF NEW.cultural_claim_status <> 'NONE'
       AND (NEW.cultural_claim_fr IS NULL OR length(btrim(NEW.cultural_claim_fr)) = 0) THEN
        RAISE EXCEPTION
            'MBOA[affirmation_vide] produit % : le statut % suppose une affirmation redigee.',
            NEW.id, NEW.cultural_claim_status
            USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
