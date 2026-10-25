/// Profanity and foul language filter for customer comments and feedback.
/// Supports English and Filipino / Tagalog colloquial foul words, slurs,
/// and common leetspeak / obfuscations.
class ProfanityFilter {
  ProfanityFilter._();

  /// Normalized list of prohibited words.
  /// Matched on word boundaries to avoid false positives (e.g., 'classic', 'passionate').
  static const List<String> _foulWords = [
    // ── English Profanities & Slurs ──────────────────────────────────────────
    'fuck',
    'fucker',
    'fucking',
    'fucked',
    'fuckin',
    'motherfucker',
    'shit',
    'shitty',
    'bullshit',
    'dipshit',
    'bitch',
    'bitches',
    'bitchy',
    'asshole',
    'assholes',
    'jackass',
    'dumbass',
    'bastard',
    'bastards',
    'dickhead',
    'dick',
    'dicks',
    'cunt',
    'cunts',
    'pussy',
    'pussies',
    'cocksucker',
    'slut',
    'sluts',
    'whore',
    'whores',
    'nigger',
    'nigga',
    'stfu',
    'fag',
    'faggot',

    // ── Filipino / Tagalog Profanities & Insults ──────────────────────────────
    'tanga',
    'tangang',
    'katangahan',
    'napakatanga',
    'tatanga-tanga',
    'tatangatanga',
    'bobo',
    'boba',
    'bobohan',
    'kabobohan',
    'putangina',
    'tangina',
    'tanginamo',
    'potangina',
    'putang',
    'puta',
    'pota',
    'gago',
    'gaga',
    'gaguhan',
    'kagaguhan',
    'tarantado',
    'tarantada',
    'katarantaduhan',
    'ulol',
    'ulul',
    'kaululan',
    'pakyu',
    'fakyu',
    'pakshet',
    'pakchet',
    'paksyet',
    'kupal',
    'kupalan',
    'bwisit',
    'buwisit',
    'bwiset',
    'leche',
    'letse',
    'punyeta',
    'punyetero',
    'hinayupak',
    'inutil',
    'hudas',
    'kantot',
    'kantutan',
    'kinantot',
    'tamod',
    'pokpok',
    'pukinangina',
    'shuta',
    'tite',
    'titi',
    'puki',
    'puke',
    'pepe',
    'engot',
    'ungas',
    'ogag',
    'salot',
    'gunggong',
    'siraulo',
    'peste',
    'pesteng',
    'lintik',
    'hayop',
    'hayup',
    'demonyo',
    'pucha',
    'kingina',
    'burat',
    'pekpek',
    'bilat',
    'bayag',
    'etits',
    'otits',
    'jakol',
    'chupa',
    'tsupa',
  ];

  /// Multi-word foul phrases. Checked directly on normalized text.
  static const List<String> _foulPhrases = [
    'putang ina',
    'tang ina',
    'potang ina',
    'tang ina mo',
    'putang ina mo',
    'king ina',
    'pucha ka',
    'ina mo',
    'hayop ka',
    'hayup ka',
    'gago ka',
    'tanga ka',
    'bobo ka',
    'ulol ka',
    'tarantado ka',
    'sira ulo',
    'fuck you',
    'pak you',
    'fak you',
    'fck you',
  ];

  /// Normalizes characters by converting leetspeak/substitutions to standard letters.
  static String _normalize(String input) {
    var s = input.toLowerCase();

    // Map common symbol substitutions
    s = s
        .replaceAll('@', 'a')
        .replaceAll(r'$', 's')
        .replaceAll('0', 'o')
        .replaceAll('1', 'i')
        .replaceAll('!', 'i')
        .replaceAll('3', 'e')
        .replaceAll('5', 's')
        .replaceAll('+', 't');

    // Remove punctuation between letters (e.g. t.a.n.g.a or t-a-n-g-a or f*u*c*k)
    s = s.replaceAll(RegExp(r'(?<=[a-z])[._\-*#~^/\\|](?=[a-z])'), '');

    // Collapse single-spaced letters (e.g. "t a n g a" -> "tanga", "f u c k" -> "fuck")
    s = s.replaceAllMapped(
      RegExp(r'\b([a-z])(?:\s+([a-z]))+\b'),
      (m) => m[0]!.replaceAll(RegExp(r'\s+'), ''),
    );

    return s;
  }

  /// Returns true if [text] contains any foul words or prohibited phrases.
  static bool hasProfanity(String text) {
    if (text.trim().isEmpty) return false;
    return getDetectedWords(text).isNotEmpty;
  }

  /// Returns a list of detected prohibited words or phrases found in [text].
  static List<String> getDetectedWords(String text) {
    if (text.trim().isEmpty) return const [];

    final normalized = _normalize(text);
    // Collapsed version where duplicate consecutive letters are reduced to 1
    // e.g. "tangaaaaa" -> "tanga", "fuuuuuck" -> "fuck", "booooboooo" -> "bobo"
    final collapsed = normalized.replaceAllMapped(RegExp(r'(.)\1+'), (m) => '${m[1]}');

    final detected = <String>{};

    // 1. Check multi-word phrases on both normalized and collapsed text
    for (final phrase in _foulPhrases) {
      final phraseNorm = phrase.toLowerCase();
      final phraseCollapsed =
          phraseNorm.replaceAllMapped(RegExp(r'(.)\1+'), (m) => '${m[1]}');
      if (normalized.contains(phraseNorm) || collapsed.contains(phraseCollapsed)) {
        detected.add(phrase);
      }
    }

    // 2. Check whole words using regex word boundaries
    for (final word in _foulWords) {
      final wordNorm = word.toLowerCase();
      final pattern = RegExp('\\b${RegExp.escape(wordNorm)}\\b', caseSensitive: false);
      if (pattern.hasMatch(normalized)) {
        detected.add(word);
        continue;
      }

      // Check on collapsed text
      final wordCollapsed =
          wordNorm.replaceAllMapped(RegExp(r'(.)\1+'), (m) => '${m[1]}');
      final collapsedPattern =
          RegExp('\\b${RegExp.escape(wordCollapsed)}\\b', caseSensitive: false);
      if (collapsedPattern.hasMatch(collapsed)) {
        detected.add(word);
      }
    }

    return detected.toList();
  }

  /// Returns a friendly validation error string if foul language is detected,
  /// or null if the text is clean and respectful.
  static String? validate(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final detected = getDetectedWords(text);
    if (detected.isNotEmpty) {
      return 'Please keep your feedback respectful. Inappropriate or foul language is not permitted.';
    }
    return null;
  }

  /// Masks detected foul words with asterisks (e.g. f***) for safe rendering.
  static String maskProfanity(String text) {
    var result = text;
    final words = getDetectedWords(text);
    for (final w in words) {
      final replacement = w.length <= 2
          ? '**'
          : '${w[0]}${'*' * (w.length - 2)}${w[w.length - 1]}';
      result = result.replaceAll(RegExp(RegExp.escape(w), caseSensitive: false), replacement);
    }
    return result;
  }
}
