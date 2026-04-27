/// Environment values injected at build time via `--dart-define`.
/// Example:
/// flutter run --dart-define=SUPABASE_URL=https://x.supabase.co \
///             --dart-define=SUPABASE_ANON_KEY=eyJh...
class Env {
  static const supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
