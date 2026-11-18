import { assertEquals, assert, fail } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { moderationDataset } from "./moderation_terms.ts";

Deno.test("Dataset Validation: No duplicate canonical terms", () => {
    const canonicals = new Set();
    for (const term of moderationDataset) {
        const canonical = term.canonical_term.toLowerCase();
        if (canonicals.has(canonical)) {
            fail(`Duplicate canonical term found: ${canonical}`);
        }
        canonicals.add(canonical);
    }
});

Deno.test("Dataset Validation: No duplicate variants within terms", () => {
    for (const term of moderationDataset) {
        const variants = [
            ...(term.romanized_forms || []),
            ...(term.common_misspellings || []),
            ...(term.common_obfuscations || [])
        ];
        
        const termVariantSet = new Set();
        for (const v of variants) {
            const vl = v.toLowerCase();
            if (termVariantSet.has(vl)) {
                fail(`Term ${term.canonical_term} has duplicate variant: ${v}`);
            }
            termVariantSet.add(vl);
        }
    }
});

Deno.test("Dataset Validation: No placeholders", () => {
    for (const term of moderationDataset) {
        const canonical = term.canonical_term.toLowerCase();
        if (canonical.includes('[') || canonical.includes(']') || canonical.includes('placeholder')) {
            fail(`Placeholder found in canonical term: ${canonical}`);
        }
        
        const variants = [
            ...(term.romanized_forms || []),
            ...(term.common_misspellings || []),
            ...(term.common_obfuscations || [])
        ];
        
        for (const v of variants) {
            if (v.includes('[') || v.includes(']')) {
                fail(`Placeholder found in variant: ${v}`);
            }
        }
    }
});

Deno.test("Dataset Validation: No empty entries", () => {
    for (const term of moderationDataset) {
        assert(term.canonical_term && term.canonical_term.trim() !== '', "Empty canonical term found");
    }
});

Deno.test("Dataset Validation: Valid enums", () => {
    const severities = ['low', 'medium', 'high', 'critical'];
    const confidences = ['low', 'medium', 'high'];
    const fpRisks = ['low', 'medium', 'high', 'extreme'];
    const strategies = ['exact_word', 'fuzzy_candidate', 'normalized_token', 'context_required'];

    for (const term of moderationDataset) {
        assert(severities.includes(term.severity), `Invalid severity '${term.severity}' for ${term.canonical_term}`);
        assert(confidences.includes(term.confidence), `Invalid confidence '${term.confidence}' for ${term.canonical_term}`);
        assert(fpRisks.includes(term.false_positive_risk), `Invalid fp_risk '${term.false_positive_risk}' for ${term.canonical_term}`);
        assert(strategies.includes(term.matching_strategy), `Invalid strategy '${term.matching_strategy}' for ${term.canonical_term}`);
    }
});

Deno.test("Dataset Validation: Fuzzy matching disabled on extreme false-positive-risk terms", () => {
    for (const term of moderationDataset) {
        if (term.false_positive_risk === 'extreme' && term.fuzzy_match_appropriate) {
            fail(`Fuzzy matching enabled on extreme false-positive-risk term: ${term.canonical_term}`);
        }
    }
});

Deno.test("Dataset Validation: context_required terms correctly configured", () => {
    for (const term of moderationDataset) {
        if (term.matching_strategy === 'context_required') {
            if (term.exact_match_appropriate || term.fuzzy_match_appropriate) {
                fail(`context_required term configured for automatic BLOCK (exact/fuzzy appropriate is true): ${term.canonical_term}`);
            }
        }
    }
});
