/// Modèles de la console d'administration (SS43, SS44).
///
/// Rien n'est calculé ici : tous ces chiffres viennent du serveur, qui les lit
/// directement en base. La console montre l'état réel, pas une estimation.
library;

class IntegrityCheck {
  const IntegrityCheck({
    required this.code,
    required this.label,
    required this.anomalies,
    required this.isClean,
  });

  factory IntegrityCheck.fromJson(Map<String, dynamic> j) => IntegrityCheck(
    code: j['code'] as String,
    label: j['libelle'] as String,
    anomalies: j['anomalies'] as int,
    isClean: j['conforme'] as bool,
  );

  final String code;
  final String label;
  final int anomalies;
  final bool isClean;
}

class OpenWork {
  const OpenWork({
    required this.area,
    required this.state,
    required this.reason,
  });

  factory OpenWork.fromJson(Map<String, dynamic> j) => OpenWork(
    area: j['domaine'] as String,
    state: j['etat'] as String,
    reason: j['raison'] as String,
  );

  final String area;
  final String state;
  final String reason;
}

class LanguageCorpus {
  const LanguageCorpus({
    required this.name,
    required this.iso,
    required this.total,
    required this.published,
    required this.pending,
    required this.withoutGloss,
  });

  factory LanguageCorpus.fromJson(Map<String, dynamic> j) => LanguageCorpus(
    name: j['name'] as String,
    iso: j['iso639_3'] as String,
    total: j['total'] as int,
    published: j['publies'] as int,
    pending: j['en_attente'] as int,
    withoutGloss: j['sans_glose'] as int,
  );

  final String name;
  final String iso;
  final int total;
  final int published;
  final int pending;
  final int withoutGloss;

  /// Part du corpus effectivement publiée, dans [0, 1].
  double get publishedRatio => total == 0 ? 0 : published / total;
}

class LicenceLine {
  const LicenceLine({
    required this.licence,
    required this.sources,
    required this.publishedWords,
  });

  factory LicenceLine.fromJson(Map<String, dynamic> j) => LicenceLine(
    licence: j['licence'] as String,
    sources: j['sources'] as int,
    publishedWords: j['mots_publies'] as int,
  );

  final String licence;
  final int sources;
  final int publishedWords;
}

class AdminDashboard {
  const AdminDashboard({
    required this.accounts,
    required this.accountsByRole,
    required this.languages,
    required this.licences,
    required this.content,
    required this.activity,
    required this.workload,
    required this.checks,
    required this.openWork,
  });

  factory AdminDashboard.fromJson(Map<String, dynamic> j) {
    final integrity = j['integrite'] as Map<String, dynamic>;
    return AdminDashboard(
      accounts: j['comptes']['total'] as int,
      accountsByRole: {
        for (final r in j['comptes']['par_role'] as List)
          (r as Map)['role'] as String: r['total'] as int,
      },
      languages: (j['corpus']['par_langue'] as List)
          .map((e) => LanguageCorpus.fromJson(e as Map<String, dynamic>))
          .toList(),
      licences: (j['licences'] as List)
          .map((e) => LicenceLine.fromJson(e as Map<String, dynamic>))
          .where((l) => l.sources > 0)
          .toList(),
      content: Map<String, dynamic>.from(j['contenu'] as Map),
      activity: Map<String, dynamic>.from(j['activite'] as Map),
      workload: Map<String, dynamic>.from(j['a_traiter'] as Map),
      checks: (integrity['controles'] as List)
          .map((e) => IntegrityCheck.fromJson(e as Map<String, dynamic>))
          .toList(),
      openWork: (j['chantiers_ouverts'] as List)
          .map((e) => OpenWork.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final int accounts;
  final Map<String, int> accountsByRole;
  final List<LanguageCorpus> languages;
  final List<LicenceLine> licences;
  final Map<String, dynamic> content;
  final Map<String, dynamic> activity;
  final Map<String, dynamic> workload;
  final List<IntegrityCheck> checks;
  final List<OpenWork> openWork;

  /// Vrai seulement si AUCUN contenu publié n'échappe aux règles.
  bool get isClean => checks.every((c) => c.isClean);

  int get anomalies => checks.fold(0, (sum, c) => sum + c.anomalies);

  /// Ce qui attend une décision humaine, toutes natures confondues.
  ///
  /// `habilitations_actives` est un état, pas une file d'attente : il n'entre
  /// pas dans ce total.
  int get pendingDecisions => const [
    'mots_a_relire',
    'exercices_a_relire',
    'fiches_a_relire',
    'demandes_habilitation',
  ].fold(0, (sum, key) => sum + (workload[key] as int? ?? 0));
}

class AdminUser {
  const AdminUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.isActive,
    required this.habilitations,
  });

  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
    id: j['id'] as String,
    email: j['email'] as String,
    displayName: j['display_name'] as String,
    role: j['role'] as String,
    isActive: j['is_active'] as bool,
    habilitations: j['habilitations'] as int? ?? 0,
  );

  final String id;
  final String email;
  final String displayName;
  final String role;
  final bool isActive;
  final int habilitations;
}

class SpecialistApplication {
  const SpecialistApplication({
    required this.id,
    required this.status,
    required this.userId,
    required this.displayName,
    required this.email,
    required this.languageName,
    required this.claimedRole,
    required this.relationship,
    required this.requestedScope,
    this.affiliation,
    this.referees,
    this.evidenceUrl,
    this.reviewNote,
  });

  factory SpecialistApplication.fromJson(Map<String, dynamic> j) =>
      SpecialistApplication(
        id: j['id'] as String,
        status: j['status'] as String,
        userId: j['user_id'] as String,
        displayName: j['display_name'] as String,
        email: j['email'] as String,
        languageName: j['language_name'] as String,
        claimedRole: j['claimed_role'] as String,
        relationship: j['relationship_fr'] as String,
        requestedScope: (j['requested_scope'] as List).cast<String>(),
        affiliation: j['affiliation'] as String?,
        referees: j['referees_fr'] as String?,
        evidenceUrl: j['evidence_url'] as String?,
        reviewNote: j['review_note'] as String?,
      );

  final String id;
  final String status;
  final String userId;
  final String displayName;
  final String email;
  final String languageName;
  final String claimedRole;
  final String relationship;
  final List<String> requestedScope;
  final String? affiliation;
  final String? referees;
  final String? evidenceUrl;
  final String? reviewNote;

  bool get isPending => status == 'PENDING' || status == 'NEEDS_INFO';
}

class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.actor,
    required this.action,
    required this.reason,
    required this.createdAt,
    this.targetLabel,
    this.details = const {},
  });

  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
    id: j['id'] as String,
    actor: j['actor_label'] as String,
    action: j['action'] as String,
    reason: j['reason'] as String,
    createdAt: DateTime.parse(j['created_at'] as String),
    targetLabel: j['target_label'] as String?,
    details: j['details'] == null
        ? const {}
        : Map<String, dynamic>.from(j['details'] as Map),
  );

  final String id;
  final String actor;
  final String action;
  final String reason;
  final DateTime createdAt;
  final String? targetLabel;
  final Map<String, dynamic> details;

  /// Libellé lisible, pour ne pas afficher un verbe technique au jury.
  String get label => switch (action) {
    'USER_ROLE_CHANGED' => 'Rôle modifié',
    'USER_ACTIVATED' => 'Compte réactivé',
    'USER_DEACTIVATED' => 'Compte désactivé',
    'HABILITATION_GRANTED' => 'Habilitation accordée',
    'HABILITATION_REVOKED' => 'Habilitation retirée',
    'APPLICATION_ACCEPTED' => 'Candidature acceptée',
    'APPLICATION_REJECTED' => 'Candidature refusée',
    'APPLICATION_NEEDS_INFO' => 'Complément demandé',
    'SETTING_CHANGED' => 'Paramètre modifié',
    _ => action,
  };
}

class PlatformSetting {
  const PlatformSetting({
    required this.key,
    required this.value,
    required this.description,
    required this.isEditable,
  });

  factory PlatformSetting.fromJson(Map<String, dynamic> j) => PlatformSetting(
    key: j['key'] as String,
    value: j['value'],
    description: j['description_fr'] as String,
    isEditable: j['is_editable'] as bool,
  );

  final String key;
  final Object? value;
  final String description;
  final bool isEditable;
}
