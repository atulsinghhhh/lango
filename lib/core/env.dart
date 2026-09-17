/// Environment configuration.
///
/// Defaults point at the project's Supabase instance. The publishable key is
/// safe to ship in the client (data access is protected by RLS); never put
/// the service_role/secret key here. Override per environment with:
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xyz.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=sb_publishable_...
class Env {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://vihgppxftmemwtnzssmc.supabase.co',
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_WY3DYyvDonGKxC3JIURhGg_I2igCTbl',
  );

  /// Base URL of the Lango TTS service, e.g. `https://tts.example.com`.
  ///
  /// Public by design: the app authenticates to it with the learner's own
  /// Supabase access token, so there is no API key to leak here. Leave it
  /// empty and the app falls back to the on-device voice.
  static const ttsApiBaseUrl = String.fromEnvironment('TTS_API_BASE_URL');

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get hasRemoteTts => ttsApiBaseUrl.isNotEmpty;
}
