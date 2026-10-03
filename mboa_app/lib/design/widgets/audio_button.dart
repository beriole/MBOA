import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/api_client.dart';

import '../tokens.dart';

/// Un seul lecteur pour toute l'application : on n'empile jamais les sons,
/// et on ne charge jamais des dizaines d'audios en même temps (SS45).
///
/// Le chargement d'une piste n'est pas instantané : il passe par le réseau. Si
/// l'apprenant répond et enchaîne pendant qu'une piste charge encore, la
/// demande précédente ne doit **pas** se mettre à jouer par-dessus la nouvelle.
/// Chaque demande porte donc un numéro d'ordre, et une demande dépassée est
/// abandonnée en silence.
class AudioService {
  AudioService() : _player = AudioPlayer();

  final AudioPlayer _player;
  String? _currentUrl;

  /// Numéro de la dernière demande. Une demande qui se termine alors qu'une
  /// plus récente est partie n'a plus rien à jouer.
  int _generation = 0;

  Stream<PlayerState> get state => _player.playerStateStream;
  String? get currentUrl => _currentUrl;

  /// L'API renvoie des chemins relatifs (`/api/v1/audio/<id>`) : le fichier
  /// est servi par identifiant, jamais par son nom d'origine.
  static String resolve(String url) =>
      url.startsWith('/') ? '$kApiBase$url' : url;

  /// `slow` : étape V2 de la prononciation (SS19) — réécouter plus lentement.
  Future<void> play(String url, {bool slow = false}) async {
    final demande = ++_generation;
    try {
      if (_currentUrl != url) {
        // Couper d'abord : sans cela, la piste précédente continue pendant
        // que la nouvelle charge.
        await _player.stop();
        _currentUrl = null;
        await _player.setUrl(resolve(url));
        if (demande != _generation) return;
        _currentUrl = url;
      } else {
        await _player.seek(Duration.zero);
      }
      if (demande != _generation) return;
      await _player.setSpeed(slow ? 0.75 : 1.0);
      await _player.play();
    } catch (e) {
      if (demande == _generation) _currentUrl = null;
      rethrow;
    }
  }

  Future<void> stop() {
    // Une coupure vaut aussi demande : elle annule un chargement en cours.
    _generation++;
    _currentUrl = null;
    return _player.stop();
  }

  void dispose() => _player.dispose();
}

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(service.dispose);
  return service;
});

/// Bouton de lecture. Toujours accompagné d'un libellé accessible (K9).
class AudioButton extends ConsumerStatefulWidget {
  const AudioButton({
    super.key,
    required this.url,
    this.size = 64,
    this.slow = false,
    this.autoplay = false,
    this.semanticLabel,
  });

  final String url;
  final double size;
  final bool slow;
  final bool autoplay;
  final String? semanticLabel;

  @override
  ConsumerState<AudioButton> createState() => _AudioButtonState();
}

class _AudioButtonState extends ConsumerState<AudioButton> {
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoplay) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _play());
    }
  }

  @override
  void didUpdateWidget(covariant AudioButton old) {
    super.didUpdateWidget(old);
    if (widget.autoplay && old.url != widget.url) _play();
  }

  Future<void> _play() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      await ref.read(audioServiceProvider).play(widget.url, slow: widget.slow);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label =
        widget.semanticLabel ?? (widget.slow ? 'Écouter lentement' : 'Écouter');
    final background = widget.slow
        ? MboaColors.forest100
        : MboaColors.forest500;
    final foreground = widget.slow ? MboaColors.forest900 : Colors.white;

    return Semantics(
      button: true,
      label: _failed ? '$label — audio indisponible' : label,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _play,
          child: SizedBox.square(
            dimension: widget.size < kMinTouchTarget
                ? kMinTouchTarget
                : widget.size,
            child: Center(
              child: _loading
                  ? SizedBox.square(
                      dimension: widget.size * 0.35,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: foreground,
                      ),
                    )
                  : Icon(
                      _failed
                          ? Icons.volume_off_rounded
                          : (widget.slow
                                ? Icons.slow_motion_video_rounded
                                : Icons.volume_up_rounded),
                      color: foreground,
                      size: widget.size * 0.46,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
