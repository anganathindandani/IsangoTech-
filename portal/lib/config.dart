/// Build-time settings, passed with `--dart-define`:
///
/// ```sh
/// flutter build web \
///   --dart-define=SUPABASE_URL=https://YOUR-REF.supabase.co \
///   --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR-PUBLISHABLE-KEY
/// ```
///
/// The publishable key (or the older "anon" key) is safe to ship in the app:
/// row-level security in the database decides what each signed-in person sees.
class Config {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
}
