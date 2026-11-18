import { evaluateDisplayName } from "./moderation.ts";
import { assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { moderationDataset } from "./moderation_terms.ts";

const originalDataset = [...moderationDataset];

// Document that these tests are stateful: they modify the global moderationDataset,
// but we guarantee restoration with try/finally so no test can observe another test's temporary dataset.

Deno.test("context_required tests", () => {
    moderationDataset.length = 0;
    moderationDataset.push({
        canonical_term: "mockadmin",
        language_or_region: "English",
        category: "impersonation",
        script: "Latin",
        romanized_forms: ["mockadm1n"],
        common_misspellings: ["mokadmin"],
        common_obfuscations: ["m0ckadmin"],
        severity: "medium",
        confidence: "high",
        false_positive_risk: "high",
        exact_match_appropriate: false,
        fuzzy_match_appropriate: false,
        matching_strategy: "context_required",
        notes: "Mock for context_required",
    });

    try {
        // canonical -> REVIEW
        let res = evaluateDisplayName("mockadmin");
        assertEquals(res.action, "REVIEW");

        // romanized form -> REVIEW
        res = evaluateDisplayName("mockadm1n");
        assertEquals(res.action, "REVIEW");

        // common misspelling -> REVIEW
        res = evaluateDisplayName("mokadmin");
        assertEquals(res.action, "REVIEW");

        // common obfuscation -> REVIEW
        res = evaluateDisplayName("m0ckadmin");
        assertEquals(res.action, "REVIEW");

        // unrelated name -> ALLOW
        res = evaluateDisplayName("ordinaryname");
        assertEquals(res.action, "ALLOW");
    } finally {
        moderationDataset.length = 0;
        moderationDataset.push(...originalDataset);
    }
});

Deno.test("exact_word tests", () => {
    moderationDataset.length = 0;
    moderationDataset.push({
        canonical_term: "mockbadword",
        language_or_region: "English",
        category: "profanity",
        script: "Latin",
        romanized_forms: ["mockbadw0rd"],
        common_misspellings: ["mockbadwrd"],
        common_obfuscations: ["m0ckbadword"],
        severity: "high",
        confidence: "high",
        false_positive_risk: "low",
        exact_match_appropriate: true,
        fuzzy_match_appropriate: false,
        matching_strategy: "exact_word",
        notes: "Mock exact_word",
    });

    try {
        // canonical -> BLOCK
        let res = evaluateDisplayName("mockbadword");
        assertEquals(res.action, "BLOCK");

        // romanized form -> BLOCK
        res = evaluateDisplayName("mockbadw0rd");
        assertEquals(res.action, "BLOCK");

        // common misspelling -> BLOCK
        res = evaluateDisplayName("mockbadwrd");
        assertEquals(res.action, "BLOCK");

        // common obfuscation -> BLOCK
        res = evaluateDisplayName("m0ckbadword");
        assertEquals(res.action, "BLOCK");

        // substring inside an unrelated larger token -> ALLOW
        res = evaluateDisplayName("thisismockbadwordtest");
        assertEquals(res.action, "ALLOW");
    } finally {
        moderationDataset.length = 0;
        moderationDataset.push(...originalDataset);
    }
});

Deno.test("fuzzy_candidate tests", () => {
    moderationDataset.length = 0;
    moderationDataset.push({
        canonical_term: "fuzzyword", // length 9 -> threshold 1
        language_or_region: "English",
        category: "profanity",
        script: "Latin",
        romanized_forms: ["fuzzyw0rd"],
        common_misspellings: ["notherfuzzy"],
        common_obfuscations: ["f0zzyword"],
        severity: "high",
        confidence: "high",
        false_positive_risk: "low",
        exact_match_appropriate: true,
        fuzzy_match_appropriate: true,
        matching_strategy: "fuzzy_candidate",
        notes: "Mock fuzzy_candidate",
    });

    try {
        // canonical fuzzy distance allowed by the configured threshold -> BLOCK
        // fuzzyword (len 9, threshold 1), try 1 diff "fuzzzword"
        let res = evaluateDisplayName("fuzzzword");
        assertEquals(res.action, "BLOCK");

        // curated common_misspellings -> BLOCK (via exact path)
        res = evaluateDisplayName("notherfuzzy");
        assertEquals(res.action, "BLOCK");

        // curated obfuscation -> BLOCK (via exact path)
        res = evaluateDisplayName("f0zzyword");
        assertEquals(res.action, "BLOCK");

        // long concatenated substring without token separation -> ALLOW
        res = evaluateDisplayName("thisisafuzzywordthatishidden");
        assertEquals(res.action, "ALLOW");
    } finally {
        moderationDataset.length = 0;
        moderationDataset.push(...originalDataset);
    }
});

Deno.test("Evasion: Repeated character normalization tests", () => {
    moderationDataset.length = 0;
    moderationDataset.push({
        canonical_term: "mockbadword",
        language_or_region: "English",
        category: "profanity",
        script: "Latin",
        romanized_forms: [],
        common_misspellings: [],
        common_obfuscations: [],
        severity: "high",
        confidence: "high",
        false_positive_risk: "low",
        exact_match_appropriate: true,
        fuzzy_match_appropriate: false,
        matching_strategy: "exact_word",
        notes: "Mock exact_word for evasion test",
    });

    moderationDataset.push({
        canonical_term: "mockreview",
        language_or_region: "English",
        category: "impersonation",
        script: "Latin",
        romanized_forms: [],
        common_misspellings: [],
        common_obfuscations: [],
        severity: "medium",
        confidence: "high",
        false_positive_risk: "high",
        exact_match_appropriate: false,
        fuzzy_match_appropriate: false,
        matching_strategy: "context_required",
        notes: "Mock context_required for evasion test",
    });

    moderationDataset.push({
        canonical_term: "fuzzybad", // length 8, threshold 1
        language_or_region: "English",
        category: "profanity",
        script: "Latin",
        romanized_forms: [],
        common_misspellings: [],
        common_obfuscations: [],
        severity: "high",
        confidence: "high",
        false_positive_risk: "low",
        exact_match_appropriate: true,
        fuzzy_match_appropriate: true,
        matching_strategy: "fuzzy_candidate",
        notes: "Mock fuzzy_candidate for evasion test",
    });

    moderationDataset.push({
        canonical_term: "bassword", // double 's'
        language_or_region: "English",
        category: "profanity",
        script: "Latin",
        romanized_forms: [],
        common_misspellings: [],
        common_obfuscations: [],
        severity: "high",
        confidence: "high",
        false_positive_risk: "low",
        exact_match_appropriate: true,
        fuzzy_match_appropriate: false,
        matching_strategy: "exact_word",
        notes: "Mock double-letter exact_word",
    });

    try {
        // repeated trailing-character evasion
        assertEquals(evaluateDisplayName("mockbadwordddd").action, "BLOCK");

        // repeated internal-character evasion
        assertEquals(evaluateDisplayName("moooockbaaaadword").action, "BLOCK");
        
        // evasion on a word that naturally has a double letter
        assertEquals(evaluateDisplayName("bassssword").action, "BLOCK");

        // benign repeated letters
        assertEquals(evaluateDisplayName("emma aaron").action, "ALLOW");
        assertEquals(evaluateDisplayName("emmma").action, "ALLOW");

        // context_required + repeated-character variant
        assertEquals(evaluateDisplayName("mockrevieeeew").action, "REVIEW");
        
        // exact_word boundary preservation
        assertEquals(evaluateDisplayName("thisismockbadwordddddtest").action, "ALLOW");

        // fuzzy substring preservation (fuzzy target is fuzzybad len 8 -> thresh 1)
        // input: fuzzybaadddd -> collapsed1: fuzzybad (exact match, distance 0)
        // input: fuzzybaadddd -> collapsed1: fuzzybaad (distance 1) -> matches
        assertEquals(evaluateDisplayName("fuzzybaadddd").action, "BLOCK");
    } finally {
        moderationDataset.length = 0;
        moderationDataset.push(...originalDataset);
    }
});
