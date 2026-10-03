import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../design/tokens.dart';
import '../domain/gallery_models.dart';
import 'gallery_screen.dart' show resolveMedia;

/// La fiche d'un média : ce qu'on voit, et tout ce qui permet de le vérifier.
///
/// Trois informations y sont obligatoires, et la fiche ne se construit pas sans
/// elles : l'auteur, la licence, et l'adresse de la page d'origine. Ce ne sont
/// pas des mentions légales reléguées en bas — ce sont elles qui rendent la
/// rediffusion licite, et qui permettent à quiconque d'aller vérifier.
///
/// Le titre et la description sont ceux de l'auteur sur Wikimedia Commons. La
/// fiche le dit explicitement, pour qu'on ne les prenne pas pour une
/// documentation produite par MBOA.
class MediaSheet extends StatelessWidget {
  const MediaSheet({super.key, required this.media});
  final GalleryMedia media;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MboaSpace.lg,
        0,
        MboaSpace.lg,
        MboaSpace.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(MboaRadius.md),
              child: media.isVideo
                  ? MediaVideo(media: media)
                  : AspectRatio(
                      aspectRatio: media.aspectRatio ?? 4 / 3,
                      child: Image.network(
                        resolveMedia(media.url),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stack) =>
                            const ColoredBox(
                              color: MboaColors.sable100,
                              child: Center(
                                child: Icon(Icons.broken_image_outlined),
                              ),
                            ),
                      ),
                    ),
            ),
            const SizedBox(height: MboaSpace.lg),
            Text(media.title, style: text.titleLarge),
            const SizedBox(height: MboaSpace.xs),
            Text(
              'Titre et description donnés par l’auteur sur Wikimedia Commons.',
              style: text.bodySmall?.copyWith(color: MboaColors.encre400),
            ),
            if (media.description != null &&
                media.description!.trim().isNotEmpty) ...[
              const SizedBox(height: MboaSpace.md),
              Text(media.description!, style: text.bodyMedium),
            ],
            const SizedBox(height: MboaSpace.lg),
            _Fact(
              icon: Icons.person_outline_rounded,
              label: 'Auteur',
              value: media.author,
            ),
            _Fact(
              icon: Icons.copyright_outlined,
              label: 'Licence',
              value: media.license,
            ),
            _Fact(
              icon: Icons.category_outlined,
              label: 'Rangé sous',
              value: media.theme,
              hint:
                  'Étiquette de classement choisie par MBOA pour l’affichage. '
                  'Ce n’est pas une affirmation sur ce qu’on voit.',
            ),
            const SizedBox(height: MboaSpace.md),
            SelectableText(
              media.sourceUrl,
              style: text.bodySmall?.copyWith(color: MboaColors.indigo700),
            ),
            const SizedBox(height: MboaSpace.xs),
            Text(
              'Cette adresse mène à la page d’origine : la licence, l’auteur et '
              'l’historique y restent vérifiables par n’importe qui.',
              style: text.bodySmall?.copyWith(color: MboaColors.encre500),
            ),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.label,
    required this.value,
    this.hint,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: MboaSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: MboaColors.encre500),
          const SizedBox(width: MboaSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: text.bodySmall?.copyWith(color: MboaColors.encre500),
                ),
                Text(value, style: text.bodyMedium),
                if (hint != null)
                  Text(
                    hint!,
                    style: text.bodySmall?.copyWith(color: MboaColors.encre400),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Le lecteur vidéo.
///
/// La vidéo n'est **pas** chargée avant qu'on le demande : ces fichiers pèsent
/// dix à quinze mégaoctets, et les précharger sur une connexion camerounaise
/// coûterait cher pour rien. On affiche donc une affiche noire avec un bouton,
/// et le téléchargement ne commence qu'au premier appui.
class MediaVideo extends StatefulWidget {
  const MediaVideo({super.key, required this.media});
  final GalleryMedia media;

  @override
  State<MediaVideo> createState() => _MediaVideoState();
}

class _MediaVideoState extends State<MediaVideo> {
  VideoPlayerController? _controller;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final controleur = VideoPlayerController.networkUrl(
      Uri.parse(resolveMedia(widget.media.url)),
    );
    try {
      await controleur.initialize();
      await controleur.setLooping(false);
      await controleur.play();
      if (!mounted) {
        await controleur.dispose();
        return;
      }
      setState(() {
        _controller = controleur;
        _loading = false;
      });
    } catch (e) {
      await controleur.dispose();
      if (mounted) {
        setState(() {
          _error = 'La vidéo n’a pas pu être lue. $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controleur = _controller;
    if (controleur != null && controleur.value.isInitialized) {
      return Column(
        children: [
          AspectRatio(
            aspectRatio: controleur.value.aspectRatio,
            child: VideoPlayer(controleur),
          ),
          VideoProgressIndicator(
            controleur,
            allowScrubbing: true,
            colors: const VideoProgressColors(
              playedColor: MboaColors.violet600,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 32,
                tooltip: controleur.value.isPlaying ? 'Pause' : 'Lire',
                onPressed: () async {
                  controleur.value.isPlaying
                      ? await controleur.pause()
                      : await controleur.play();
                  if (mounted) setState(() {});
                },
                icon: Icon(
                  controleur.value.isPlaying
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_fill_rounded,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return AspectRatio(
      aspectRatio: widget.media.aspectRatio ?? 16 / 9,
      child: ColoredBox(
        color: MboaColors.encre900,
        child: Center(
          child: _loading
              ? const CircularProgressIndicator(color: Colors.white)
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      iconSize: 56,
                      tooltip: 'Lire la vidéo',
                      onPressed: _start,
                      icon: const Icon(
                        Icons.play_circle_fill_rounded,
                        color: Colors.white,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MboaSpace.lg,
                      ),
                      child: Text(
                        _error ??
                            'La vidéo se télécharge au premier appui : une '
                                'dizaine de mégaoctets, à ne pas dépenser sans '
                                'le vouloir.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _error == null ? Colors.white70 : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
