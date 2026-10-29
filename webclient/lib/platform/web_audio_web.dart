import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

web.AudioContext? _ctx;
web.GainNode? _voiceGain;
final Map<int, double> _speakerEndTime = {};

web.AudioContext? _ensureContext() {
  try {
    final c = _ctx ??= web.AudioContext();
    if (c.state == 'suspended') {
      c.resume();
    }
    return c;
  } catch (_) {
    return null;
  }
}

web.AudioBuffer _toAudioBuffer(web.AudioContext ctx, Int16List pcm, int sampleRate) {
  final buf = ctx.createBuffer(1, pcm.length, sampleRate);
  final floats = Float32List(pcm.length);
  for (var i = 0; i < pcm.length; i++) {
    floats[i] = pcm[i] / 32768.0;
  }
  buf.copyToChannel(floats.toJS, 0);
  return buf;
}

void playPcmClip(Int16List pcm, int sampleRate, double gain) {
  if (pcm.isEmpty || gain <= 0) return;
  final ctx = _ensureContext();
  if (ctx == null) return;
  try {
    final buf = _toAudioBuffer(ctx, pcm, sampleRate);
    final src = ctx.createBufferSource()..buffer = buf;
    final g = ctx.createGain();
    g.gain.value = gain.clamp(0.0, 1.0);
    src.connect(g);
    g.connect(ctx.destination);
    src.start();
  } catch (_) {}
}

void queueVoicePcm(int speaker, Int16List pcm, int sampleRate, double volume) {
  if (pcm.isEmpty || volume <= 0) return;
  final ctx = _ensureContext();
  if (ctx == null) return;
  try {
    final master = _voiceGain ??= (ctx.createGain()..connect(ctx.destination));
    master.gain.value = volume.clamp(0.0, 2.0);
    final buf = _toAudioBuffer(ctx, pcm, sampleRate);
    final src = ctx.createBufferSource()..buffer = buf;
    src.connect(master);
    final now = ctx.currentTime;
    final prev = _speakerEndTime[speaker] ?? 0.0;
    // Small 40ms jitter cushion when starting a new talk burst.
    final startAt = prev > now ? prev : now + 0.04;
    src.start(startAt);
    _speakerEndTime[speaker] = startAt + pcm.length / sampleRate;
  } catch (_) {}
}

void setVoiceMasterVolume(double volume) {
  final g = _voiceGain;
  if (g != null) {
    try {
      g.gain.value = volume.clamp(0.0, 2.0);
    } catch (_) {}
  }
}

void stopAllVoice() {
  _speakerEndTime.clear();
  final ctx = _ctx;
  final g = _voiceGain;
  if (ctx != null && g != null) {
    try {
      g.disconnect();
    } catch (_) {}
    _voiceGain = null;
  }
}
