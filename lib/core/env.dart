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

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
