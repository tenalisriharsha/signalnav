/// SignalNav - Audio Service
///
/// Manages text-to-speech (TTS), voice command recognition, and haptic feedback.
/// All audio output is designed for hands-free driving.
/// Force-stops audio guidance if headphones disconnect mid-trip.

import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:vibration/vibration.dart';
import '../../core/constants.dart';
import '../../core/errors.dart';
import '../../core/logger.dart';

/// Result of a voice command recognition.
class VoiceCommandResult {
  final bool recognized;
  final String? rawText;
  final String? command; // "red", "green", "yellow"
  final double confidence;

  const VoiceCommandResult({
    required this.recognized,
    this.rawText,
    this.command,
    this.confidence = 0.0,
  });
}

/// Central audio service.
class AudioService {
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _speech = SpeechToText();

  bool _ttsInitialized = false;
  bool _speechInitialized = false;
  bool _headphonesConnected = true;
  bool _isSpeaking = false;

  /// Whether audio guidance is currently active
  bool get isSpeaking => _isSpeaking;

  /// Whether headphones are connected
  bool get headphonesConnected => _headphonesConnected;

  /// Stream of recognized voice commands
  final StreamController<VoiceCommandResult> _commandController =
      StreamController<VoiceCommandResult>.broadcast();
  Stream<VoiceCommandResult> get commandStream => _commandController.stream;

  /// Initialize TTS and speech recognition.
  Future<void> initialize() async {
    await _initTts();
    await _initSpeech();
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5); // Slightly slower for clarity in cars
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      _tts.setStartHandler(() {
        _isSpeaking = true;
      });
      _tts.setCompletionHandler(() {
        _isSpeaking = false;
      });
      _tts.setErrorHandler((msg) {
        logError(LogCategory.audio, 'TTS error: $msg');
        _isSpeaking = false;
      });

      _ttsInitialized = true;
      logInfo(LogCategory.audio, 'TTS initialized');
    } catch (e, st) {
      logError(LogCategory.audio, 'TTS init failed: $e');
      throw UnexpectedException('Audio initialization failed', stackTrace: st);
    }
  }

  Future<void> _initSpeech() async {
    try {
      _speechInitialized = await _speech.initialize(
        onError: (error) => logWarning(LogCategory.audio, 'Speech error: $error'),
        onStatus: (status) => logDebug(LogCategory.audio, 'Speech status: $status'),
      );
      if (_speechInitialized) {
        logInfo(LogCategory.audio, 'Speech recognition initialized');
      } else {
        logWarning(LogCategory.audio, 'Speech recognition not available');
      }
    } catch (e, st) {
      logError(LogCategory.audio, 'Speech init failed: $e');
    }
  }

  /// Speak a message. Safe to call from anywhere; queues if already speaking.
  Future<void> speak(String message, {bool critical = false}) async {
    if (!_ttsInitialized) {
      logWarning(LogCategory.audio, 'TTS not initialized, skipping: $message');
      return;
    }

    // Safety: if headphones disconnected, only speak critical safety messages
    if (!_headphonesConnected && !critical) {
      logSafety(
        'Audio suppressed - headphones disconnected (non-critical: $message)',
      );
      return;
    }

    try {
      // Stop current speech for critical messages
      if (critical && _isSpeaking) {
        await _tts.stop();
      }

      await _tts.speak(message);
      logDebug(LogCategory.audio, 'Speaking: $message');
    } catch (e, st) {
      logError(LogCategory.audio, 'Speak failed: $e');
    }
  }

  /// Stop all audio output immediately.
  Future<void> stop() async {
    if (_ttsInitialized) {
      await _tts.stop();
      _isSpeaking = false;
    }
  }

  /// Play a haptic pattern.
  Future<void> haptic(List<int> pattern) async {
    try {
      final hasVibrator = await Vibration.hasVibrator() ?? false;
      if (!hasVibrator) return;

      await Vibration.vibrate(pattern: pattern);
      logDebug(LogCategory.audio, 'Haptic: $pattern');
    } catch (e) {
      logWarning(LogCategory.audio, 'Haptic failed: $e');
    }
  }

  /// Convenience: stopped at red haptic
  Future<void> hapticStoppedAtRed() => haptic(kHapticStoppedAtRed);

  /// Convenience: green soon haptic
  Future<void> hapticGreenSoon() => haptic(kHapticGreenSoon);

  /// Convenience: reroute available haptic
  Future<void> hapticRerouteAvailable() => haptic(kHapticRerouteAvailable);

  /// Listen for a voice command (with wake phrase detection).
  /// Call this when the user is prompted (e.g., after geofence trigger).
  Future<VoiceCommandResult> listenForCommand({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (!_speechInitialized) {
      return const VoiceCommandResult(recognized: false);
    }

    if (!_speech.isAvailable) {
      return const VoiceCommandResult(recognized: false);
    }

    try {
      String? recognizedText;
      double confidence = 0.0;

      final completer = Completer<VoiceCommandResult>();
      Timer? timeoutTimer;

      await _speech.listen(
        onResult: (result) {
          if (result.hasConfidenceRating) {
            confidence = result.confidence;
          }
          if (result.finalResult) {
            recognizedText = result.recognizedWords.toLowerCase();
            timeoutTimer?.cancel();
            if (!completer.isCompleted) {
              completer.complete(
                _parseCommand(recognizedText!, confidence),
              );
            }
          }
        },
        listenFor: timeout,
        pauseFor: const Duration(seconds: 2),
        partialResults: false,
      );

      // Fallback timeout
      timeoutTimer = Timer(timeout, () {
        if (!completer.isCompleted) {
          _speech.stop();
          completer.complete(
            VoiceCommandResult(
              recognized: recognizedText != null,
              rawText: recognizedText,
              confidence: confidence,
            ),
          );
        }
      });

      return await completer.future;
    } catch (e, st) {
      logError(LogCategory.audio, 'Voice listen failed: $e');
      return VoiceCommandResult(
        recognized: false,
        rawText: null,
        confidence: 0,
      );
    }
  }

  /// Parse recognized text for wake phrase + command.
  VoiceCommandResult _parseCommand(String text, double confidence) {
    // Check for wake phrase
    if (!text.contains(kVoiceWakePhrase.replaceAll(' ', '')) &&
        !text.contains(kVoiceWakePhrase)) {
      // Also accept commands without wake phrase in the 5-second window
      // (user was already prompted)
    }

    // Extract color command
    String? command;
    for (final word in text.split(' ')) {
      if (kVoiceCommandsRed.contains(word)) {
        command = 'red';
        break;
      }
      if (kVoiceCommandsGreen.contains(word)) {
        command = 'green';
        break;
      }
      if (kVoiceCommandsYellow.contains(word)) {
        command = 'yellow';
        break;
      }
    }

    return VoiceCommandResult(
      recognized: command != null,
      rawText: text,
      command: command,
      confidence: confidence,
    );
  }

  /// Update headphone connection status.
  /// If disconnected, non-critical audio is suppressed.
  void setHeadphonesConnected(bool connected) {
    if (_headphonesConnected && !connected) {
      logSafety('HEADPHONES DISCONNECTED - audio guidance stopped');
      stop();
    }
    _headphonesConnected = connected;
  }

  /// Dispose resources.
  Future<void> dispose() async {
    await _tts.stop();
    await _speech.stop();
    await _commandController.close();
  }
}
