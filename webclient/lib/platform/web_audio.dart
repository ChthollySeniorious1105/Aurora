import 'dart:typed_data';

import 'web_audio_io.dart' if (dart.library.js_interop) 'web_audio_web.dart' as impl;

/// Plays a mono 16-bit signed PCM clip at [sampleRate] Hz with [gain] (0..1).
void playPcmClip(Int16List pcm, int sampleRate, double gain) =>
    impl.playPcmClip(pcm, sampleRate, gain);

/// Queues a mono 16-bit signed PCM voice frame from [speaker] at [sampleRate]
/// Hz with master [volume] (0..1).
void queueVoicePcm(int speaker, Int16List pcm, int sampleRate, double volume) =>
    impl.queueVoicePcm(speaker, pcm, sampleRate, volume);

/// Updates master voice output volume (0..1).
void setVoiceMasterVolume(double volume) => impl.setVoiceMasterVolume(volume);

/// Stops and clears any queued voice audio.
void stopAllVoice() => impl.stopAllVoice();
