import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../design/tokens.dart';

/// Suivi de sa propre candidature (SS43).
///
/// La personne qui a candidaté voit où en est son dossier et, en cas de refus
/// ou de demande de complément, le motif tel qu'il a été écrit. Une décision
/// non motivée serait une décision qu'on ne peut pas discuter.
class MyApplication {
  const MyApplication({
    required this.id,
    required this.status,
    required this.languageName,
    this.reviewNote,
  });

  factory MyApplication.fromJson(Map<String, dynamic> j) => MyApplication(
    id: j['id'] as String,
    status: j['status'] as String,
    languageName: j['language_name'] as String,
    reviewNote: j['review_note'] as String?,
  );

  final String id;
  final String status;
  final String languageName;
  final String? reviewNote;

  bool get isPending => status == 'PENDING' || status == 'NEEDS_INFO';

  String get label => switch (status) {
    'PENDING' => 'Candidature en cours d’examen',
    'NEEDS_INFO' => 'Un complément t’est demandé',
    'ACCEPTED' => 'Candidature acceptée',
    'REJECTED' => 'Candidature refusée',
    _ => status,
  };
}

final myApplicationsProvider = FutureProvider<List<MyApplication>>((ref) async {
  final data =
      await ref.watch(apiClientProvider).get('/me/specialist-application')
          as List;
  return data
      .map((e) => MyApplication.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Encart affiché dans le profil quand une candidature existe.
class MyApplicationCard extends StatelessWidget {
  const MyApplicationCard({super.key, required this.application});

  final MyApplication application;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = switch (application.status) {
      'ACCEPTED' => MboaColors.succes,
      'REJECTED' => MboaColors.terre700,
      _ => MboaColors.info,
    };

    return Container(
      padding: const EdgeInsets.all(MboaSpace.lg),
      decoration: BoxDecoration(
        color: MboaColors.sable100,
        borderRadius: BorderRadius.circular(MboaRadius.lg),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(application.label, style: text.titleMedium),
          Text(application.languageName, style: text.bodySmall),
          if (application.reviewNote != null) ...[
            const SizedBox(height: MboaSpace.sm),
            Text(
              '« ${application.reviewNote!} »',
              style: text.bodyMedium?.copyWith(color: MboaColors.encre500),
            ),
          ],
        ],
      ),
    );
  }
}
