import 'dart:typed_data';

/// VM stub used under `flutter test`.
void playPcmClip(Int16List pcm, int sampleRate, double gain) {}
void queueVoicePcm(int speaker, Int16List pcm, int sampleRate, double volume) {}
void setVoiceMasterVolume(double volume) {}
void stopAllVoice() {}
