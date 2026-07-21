import 'dart:async';

import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Ports `playBellSound()` / `playMessageChime()` from `src/lib/tickbell.ts`.
///
/// NOTE ON FIDELITY: the web app synthesizes its bell/chime tones live with
/// the WebAudio `OscillatorNode` API — there's no audio *file* to port.
/// Flutter has no built-in oscillator/synth API, so the most faithful
/// low-effort port is: matching vibration patterns (which the original also
/// triggers via `navigator.vibrate`) + a system UI sound as an audible cue
/// while the app is foregrounded. When the app is backgrounded, the actual
/// "ring" sound users hear comes from the FCM notification's system sound
/// channel (see NotificationService), which you can point at a custom
/// `bell.mp3`/`chime.mp3` raw resource for a closer match — drop those files
/// into `android/app/src/main/res/raw/` and `ios/Runner/` and reference them
/// in the Android notification channel / APNs payload `sound` field.
class SoundService {
  const SoundService();

  Future<void> playBellSound() async {
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator) {
      unawaited(Vibration.vibrate(pattern: [0, 300, 200, 300, 200, 500], intensities: [255, 255]));
    }
    unawaited(SystemSound.play(SystemSoundType.alert));
  }

  Future<void> playMessageChime() async {
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator) {
      unawaited(Vibration.vibrate(pattern: [0, 120, 60, 120]));
    }
    unawaited(SystemSound.play(SystemSoundType.click));
  }
}

void unawaited(Future<void> future) {
  // Deliberately not awaited — fire-and-forget, matching the try/catch-and-
  // ignore semantics of the original `playBellSound`/`playMessageChime`.
}
