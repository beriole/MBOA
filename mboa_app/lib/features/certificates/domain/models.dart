/// Attestations de parcours (SS15).
///
/// Une attestation MBOA est un constat : des leçons terminées, un score, des
/// dates. Elle ne dit pas un niveau de langue, et le porte écrit.
library;

class Certificate {
  const Certificate({
    required this.id,
    required this.code,
    required this.learnerName,
    required this.courseTitle,
    required this.sectionTitle,
    required this.languageName,
    required this.lessonsCompleted,
    required this.lessonsTotal,
    required this.averageScore,
    required this.exercisesAnswered,
    required this.completedAt,
    required this.issuedAt,
    this.revokedAt,
    this.revokedReason,
  });

  factory Certificate.fromJson(Map<String, dynamic> j) => Certificate(
    id: j['id'] as String,
    code: j['code'] as String,
    learnerName: j['learner_name'] as String,
    courseTitle: j['course_title'] as String,
    sectionTitle: j['section_title'] as String,
    languageName: j['language_name'] as String,
    lessonsCompleted: j['lessons_completed'] as int,
    lessonsTotal: j['lessons_total'] as int,
    averageScore: (j['average_score'] as num).toDouble(),
    exercisesAnswered: j['exercises_answered'] as int? ?? 0,
    completedAt: DateTime.parse(j['completed_at'] as String),
    issuedAt: DateTime.parse(j['issued_at'] as String),
    revokedAt: j['revoked_at'] == null
        ? null
        : DateTime.parse(j['revoked_at'] as String),
    revokedReason: j['revoked_reason'] as String?,
  );

  final String id;
  final String code;
  final String learnerName;
  final String courseTitle;
  final String sectionTitle;
  final String languageName;
  final int lessonsCompleted;
  final int lessonsTotal;
  final double averageScore;
  final int exercisesAnswered;
  final DateTime completedAt;
  final DateTime issuedAt;
  final DateTime? revokedAt;
  final String? revokedReason;

  bool get isRevoked => revokedAt != null;

  /// Score en pourcentage entier, arrondi comme sur le PDF.
  int get scorePercent => (averageScore * 100).round();
}

/// Une section terminée, dont l'attestation n'a pas encore été demandée.
class AvailableCertificate {
  const AvailableCertificate({
    required this.sectionId,
    required this.sectionTitle,
    required this.courseTitle,
    required this.languageName,
    required this.lessonsTotal,
  });

  factory AvailableCertificate.fromJson(Map<String, dynamic> j) =>
      AvailableCertificate(
        sectionId: j['section_id'] as String,
        sectionTitle: j['section_title'] as String,
        courseTitle: j['course_title'] as String,
        languageName: j['language_name'] as String,
        lessonsTotal: j['lessons_total'] as int,
      );

  final String sectionId;
  final String sectionTitle;
  final String courseTitle;
  final String languageName;
  final int lessonsTotal;
}

class CertificateList {
  const CertificateList({required this.issued, required this.available});

  factory CertificateList.fromJson(Map<String, dynamic> j) => CertificateList(
    issued: (j['delivrees'] as List)
        .map((e) => Certificate.fromJson(e as Map<String, dynamic>))
        .toList(),
    available: (j['disponibles'] as List)
        .map((e) => AvailableCertificate.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  final List<Certificate> issued;
  final List<AvailableCertificate> available;

  bool get isEmpty => issued.isEmpty && available.isEmpty;
}
