import { evaluateDisplayName } from "./moderation.ts";
import { assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";

Deno.test("bc collision proves functional bug", () => {
    // If the 'bc' canonical term was respected, it should return REVIEW because 'bc' is context_required.
    // However, because 'behenchod' (index 29) appears before 'bc' (index 55) and contains 'bc' as a variant
    // with a fuzzy_candidate/exact_match strategy, it intercepts the check and returns BLOCK.
    
    const res = evaluateDisplayName("bc");
    
    // We assert it returns BLOCK, which proves it bypasses the context_required intent of the 'bc' canonical term.
    assertEquals(res.action, "BLOCK");
});
