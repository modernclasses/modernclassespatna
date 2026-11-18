import { moderationDataset, ModerationTerm } from "./moderation_terms.ts";

export interface ModerationResult {
  action: 'ALLOW' | 'BLOCK' | 'REVIEW';
  reason?: string;
  matchedTerm?: string;
}

function levenshtein(a: string, b: string): number {
    if (a.length === 0) return b.length;
    if (b.length === 0) return a.length;
    const matrix = Array.from({ length: a.length + 1 }, () => new Array(b.length + 1).fill(0));
    for (let i = 0; i <= a.length; i++) matrix[i][0] = i;
    for (let j = 0; j <= b.length; j++) matrix[0][j] = j;
    for (let i = 1; i <= a.length; i++) {
        for (let j = 1; j <= b.length; j++) {
            const cost = a[i - 1] === b[j - 1] ? 0 : 1;
            matrix[i][j] = Math.min(
                matrix[i - 1][j] + 1,
                matrix[i][j - 1] + 1,
                matrix[i - 1][j - 1] + cost
            );
        }
    }
    return matrix[a.length][b.length];
}

function escapeRegExp(string: string) {
  return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function isExactMatch(text: string, candidate: string): boolean {
    const regex = new RegExp(`(?:^|[^\\p{L}\\p{N}_])${escapeRegExp(candidate)}(?:[^\\p{L}\\p{N}_]|$)`, 'iu');
    return regex.test(text);
}

function getAllVariants(term: ModerationTerm): string[] {
    return [
        term.canonical_term.toLowerCase(),
        ...term.romanized_forms.map(r => r.toLowerCase()),
        ...term.common_misspellings.map(m => m.toLowerCase()),
        ...term.common_obfuscations.map(o => o.toLowerCase())
    ];
}

function getNormalizedTokens(term: ModerationTerm): string[] {
    return [
        term.canonical_term.toLowerCase(),
        ...term.romanized_forms.map(r => r.toLowerCase()),
        ...term.common_misspellings.map(m => m.toLowerCase()),
        ...term.common_obfuscations.map(o => o.toLowerCase().replace(/\s+/g, ''))
    ];
}

function getFuzzyTargets(term: ModerationTerm): string[] {
    return [
        term.canonical_term.toLowerCase(),
        ...term.romanized_forms.map(r => r.toLowerCase())
    ];
}

export function evaluateDisplayName(rawName: string): ModerationResult {
  const nfkcName = rawName.normalize('NFKC');
  const lowerName = nfkcName.toLowerCase();
  
  const inputVariants = [
    {
      name: lowerName,
      words: lowerName.split(/[\s_.-]+/),
      noSpaces: lowerName.replace(/\s+/g, '')
    }
  ];

  if (/(.)\1{2,}/u.test(lowerName)) {
    const c1 = lowerName.replace(/(.)\1{2,}/gu, '$1');
    inputVariants.push({
      name: c1,
      words: c1.split(/[\s_.-]+/),
      noSpaces: c1.replace(/\s+/g, '')
    });
    
    const c2 = lowerName.replace(/(.)\1{2,}/gu, '$1$1');
    if (c2 !== c1 && c2 !== lowerName) {
      inputVariants.push({
        name: c2,
        words: c2.split(/[\s_.-]+/),
        noSpaces: c2.replace(/\s+/g, '')
      });
    }
  }

  for (const term of moderationDataset) {
    if (term.matching_strategy === 'context_required') {
      const candidates = getAllVariants(term);
      for (const variant of inputVariants) {
        for (const candidate of candidates) {
          if (isExactMatch(variant.name, candidate)) {
            return { action: 'REVIEW', reason: 'High false positive risk term detected', matchedTerm: candidate };
          }
        }
      }
      continue;
    }

    if (term.matching_strategy === 'exact_word' || term.exact_match_appropriate || term.matching_strategy === 'fuzzy_candidate') {
       const exactCandidates = getAllVariants(term);
       for (const variant of inputVariants) {
         for (const candidate of exactCandidates) {
             if (variant.words.includes(candidate) || isExactMatch(variant.name, candidate)) {
                 return { action: 'BLOCK', reason: 'Exact prohibited term matched', matchedTerm: candidate };
             }
         }
       }
    }

    if (term.matching_strategy === 'normalized_token') {
        const tokenCandidates = getNormalizedTokens(term);
        for (const variant of inputVariants) {
          for (const candidate of tokenCandidates) {
             if (variant.noSpaces.includes(candidate)) {
                  if (variant.words.includes(candidate) || isExactMatch(variant.name, candidate) || isExactMatch(variant.noSpaces, candidate)) {
                     return { action: 'BLOCK', reason: 'Normalized token matched', matchedTerm: candidate };
                  }
             }
          }
       }
    }

    if (term.fuzzy_match_appropriate && term.matching_strategy === 'fuzzy_candidate') {
       const fuzzyTargets = getFuzzyTargets(term);
       for (const variant of inputVariants) {
         for (const word of variant.words) {
             for (const target of fuzzyTargets) {
                 if (target.length >= 4 && word.length >= 4) {
                     const distance = levenshtein(word, target);
                     const threshold = target.length >= 6 ? 1 : 0;
                     if (distance <= threshold) {
                         return { action: 'BLOCK', reason: 'Fuzzy match threshold exceeded', matchedTerm: target };
                     }
                 }
             }
         }
       }
    }
  }

  return { action: 'ALLOW' };
}
