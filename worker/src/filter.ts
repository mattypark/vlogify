/// The word filter for the text people show each other: display names and room names.
///
/// Guideline 1.2 asks for "a method for filtering objectionable material". Clips are filtered
/// by people (report hides a clip from the whole room until a moderator decides); the only
/// free text vlogify shows to others is a name, so names go through this before they are
/// stored. A match is masked, not refused: the person still gets a name, just not that word.
///
/// Matching is on a folded copy of the text -- lowercased, common character swaps undone
/// (0->o, 1->i, 3->e, 4->a, 5->s, 7->t, @->a, $->s), separators dropped -- so "b.i.t.c.h" and
/// "sh1t" are caught. Short words that are also parts of ordinary words are matched only as
/// whole words, so "spicy", "classic" and "dickens" survive.

const ANYWHERE = [
  "fuck", "shit", "bitch", "cunt", "nigger", "nigga", "faggot", "retard", "whore", "slut",
  "motherfucker", "asshole", "dickhead", "pussy", "porn", "rapist", "tranny", "wetback",
  "cocksucker", "jizz", "nazi", "hitler",
];

const WHOLE_WORD = [
  "ass", "cum", "dick", "cock", "fag", "rape", "sex", "tits", "twat", "kys", "nig", "spic", "chink",
  "kike", "dyke", "gook",
];

const SWAPS: Record<string, string> = { "0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "@": "a", "$": "s", "!": "i" };

function fold(ch: string): string {
  const lower = ch.toLowerCase();
  return SWAPS[lower] ?? lower;
}

/// Replaces every offending run with asterisks of the same length. Everything else is kept
/// exactly as typed, including case, spacing and emoji.
export function maskProfanity(text: string): string {
  const chars = [...text];
  // Letters only, with each folded letter's index in the original text.
  const letters: { ch: string; at: number }[] = [];
  chars.forEach((ch, at) => {
    const folded = fold(ch);
    if (/[a-z]/.test(folded)) letters.push({ ch: folded, at });
  });
  const joined = letters.map((l) => l.ch).join("");
  const masked = new Set<number>();

  const maskRange = (start: number, length: number) => {
    const from = letters[start]!.at;
    const to = letters[start + length - 1]!.at;
    for (let i = from; i <= to; i++) masked.add(i);
  };

  for (const word of ANYWHERE) {
    let from = joined.indexOf(word);
    while (from !== -1) {
      maskRange(from, word.length);
      from = joined.indexOf(word, from + 1);
    }
  }

  // Whole words: judged on the original text's own word boundaries.
  const wordPattern = /[\p{L}\p{N}@$!]+/gu;
  for (const match of text.matchAll(wordPattern)) {
    const folded = [...match[0]].map(fold).join("").replace(/[^a-z]/g, "");
    if (WHOLE_WORD.includes(folded)) {
      const start = [...text.slice(0, match.index)].length;
      for (let i = 0; i < [...match[0]].length; i++) masked.add(start + i);
    }
  }

  if (masked.size === 0) return text;
  return chars.map((ch, i) => (masked.has(i) && /\S/.test(ch) ? "*" : ch)).join("");
}
