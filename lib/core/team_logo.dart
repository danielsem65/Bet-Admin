import 'dart:convert';

import 'package:http/http.dart' as http;

import 'supabase_service.dart';

/// Searches TheSportsDB for a team crest (badge) image URL by name.
/// Returns null when nothing is found.
Future<String?> fetchTeamLogoFromWeb(String name) async {
  final t = name.trim();
  if (t.isEmpty) return null;
  final res = await http.get(
    Uri.parse(
      'https://www.thesportsdb.com/api/v1/json/3/searchteams.php?t=${Uri.encodeQueryComponent(t)}',
    ),
  );
  if (res.statusCode != 200) return null;
  final body = jsonDecode(res.body) as Map<String, dynamic>;
  final teams = body['teams'];
  if (teams is! List || teams.isEmpty) return null;
  return (teams.first as Map<String, dynamic>)['strTeamBadge']?.toString();
}

/// Mirrors the website's `ensure_team_logo()`: makes sure a team row exists
/// in the `teams` table with a crest, fetching one from the web when missing
/// (and never overwriting an already-saved crest with an empty value).
/// Returns the resolved logo URL, or null when none could be found.
Future<String?> ensureTeamLogo(String name) async {
  final t = name.trim();
  if (t.isEmpty) return null;
  final existing = await SupabaseService.client
      .from('teams')
      .select('id,logo_url')
      .eq('name', t)
      .maybeSingle();
  final logo = existing?['logo_url']?.toString() ?? '';
  if (logo.isNotEmpty) return logo;
  final fetched = await fetchTeamLogoFromWeb(t);
  if (fetched == null || fetched.isEmpty) return null;
  if (existing != null) {
    await SupabaseService.client.from('teams').update({'logo_url': fetched}).eq('id', existing['id']);
  } else {
    await SupabaseService.client
        .from('teams')
        .insert({'name': t, 'sport': 'Football', 'logo_url': fetched});
  }
  return fetched;
}

/// Ensures crests for a list of team names, swallowing individual failures so
/// a broken lookup never blocks the rest of the flow.
Future<void> ensureTeamLogos(Iterable<String> names) async {
  for (final n in names) {
    try {
      await ensureTeamLogo(n);
    } catch (_) {}
  }
}
