import { evaluateDisplayName } from "./moderation.ts";
import { assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { moderationDataset } from "./moderation_terms.ts";

Deno.test("Legacy cleanup regression tests", () => {
    // 1. Colliding abbreviation 'bc' now returns REVIEW.
    const resBc = evaluateDisplayName("bc");
    assertEquals(resBc.action, "REVIEW");
    assertEquals(resBc.matchedTerm, "bc"); // Proves the canonical 'bc' term works.
    
    // 2. Not blocked by the earlier 'behenchod' term.
    // Proved because it evaluates to REVIEW instead of BLOCK.
    
    // 4. Unrelated canonical/variant behavior of the earlier term remains unchanged.
    const resBehenchod = evaluateDisplayName("behenchod");
    assertEquals(resBehenchod.action, "BLOCK");
    assertEquals(resBehenchod.matchedTerm, "behenchod");
    
    const resBhenchod = evaluateDisplayName("bhenchod");
    assertEquals(resBhenchod.action, "BLOCK");
    // "bhenchod" should be a variant or fuzzy target that returns BLOCK

    // 5 & 6. No self-canonical variants remain and no duplicate variants remain.
    let selfCanonicalCount = 0;
    let duplicateVariantsCount = 0;
    const allVariants = new Set<string>();

    for (const term of moderationDataset) {
        const c = term.canonical_term.toLowerCase();
        const termVars = [
            ...term.romanized_forms,
            ...term.common_misspellings,
            ...term.common_obfuscations
        ].map(v => v.toLowerCase());

        for (const v of termVars) {
            if (v === c) selfCanonicalCount++;
            if (allVariants.has(v)) duplicateVariantsCount++;
            allVariants.add(v);
        }
    }

    assertEquals(selfCanonicalCount, 0, "No self-canonical variants should remain");
    assertEquals(duplicateVariantsCount, 0, "No duplicate variants should remain");
});
