import 'package:audioplayers/audioplayers.dart';

class SfxPlayer {
  SfxPlayer._();

  static final SfxPlayer instance = SfxPlayer._();
  static const double _volume = 0.78;

  final AudioPlayer _player = AudioPlayer(playerId: 'chen_sfx_player');

  Future<void> playCoin() => _playAsset('audio/coin.wav');

  Future<void> playUseSuccess() => _playAsset('audio/use_success.wav');

  Future<void> _playAsset(String path) async {
    try {
      await _player.play(
        AssetSource(path),
        volume: _volume,
        mode: PlayerMode.lowLatency,
      );
    } catch (_) {
      // Audio failures should never block gameplay flow.
    }
  }
}
