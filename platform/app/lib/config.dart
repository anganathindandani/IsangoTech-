/// Build-time settings, passed with `--dart-define`:
///
/// ```sh
/// flutter build web \
///   --dart-define=SUPABASE_URL=https://PLATFORM-REF.supabase.co \
///   --dart-define=SUPABASE_PUBLISHABLE_KEY=PLATFORM-PUBLISHABLE-KEY
/// ```
///
/// These are the client platform's project, not IsangoTech's own. The
/// publishable key is safe to ship: row-level security decides what each
/// signed-in person sees.
class Config {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
}
