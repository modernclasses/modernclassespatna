import { assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { evaluateDisplayName } from "./moderation.ts";
import { handler } from "./index.ts";

// --- UNIT TESTS ---

Deno.test("Unit: evaluateDisplayName - exact_word BLOCK", () => {
    assertEquals(evaluateDisplayName("rangdar").action, 'BLOCK');
    assertEquals(evaluateDisplayName("Rangdar").action, 'BLOCK');
    assertEquals(evaluateDisplayName("RANGDAR").action, 'BLOCK');
    
    // Devanagari exact match
    assertEquals(evaluateDisplayName("बदमाश").action, 'BLOCK');
});

Deno.test("Unit: evaluateDisplayName - REVIEW handling", () => {
    // 'chutia' is context_required, should return REVIEW
    assertEquals(evaluateDisplayName("chutia").action, 'REVIEW');
});

Deno.test("Unit: evaluateDisplayName - ALLOW handling (safe names)", () => {
    assertEquals(evaluateDisplayName("Rohan Kumar").action, 'ALLOW');
    assertEquals(evaluateDisplayName("रोहन वर्मा").action, 'ALLOW');
});

Deno.test("Unit: evaluateDisplayName - legitimate substring cases (Gundappa)", () => {
    assertEquals(evaluateDisplayName("Gundappa").action, 'ALLOW');
});

Deno.test("Unit: evaluateDisplayName - punctuation/spacing variants (explicitly supported)", () => {
    // 'admin' has "a d m i n" explicitly declared as an obfuscation for a normalized_token
    assertEquals(evaluateDisplayName("a d m i n").action, 'BLOCK');
    // 'lafanga' has "l@fanga" explicitly declared
    assertEquals(evaluateDisplayName("l@fanga").action, 'BLOCK');
});

Deno.test("Unit: evaluateDisplayName - fuzzy matching only for approved terms", () => {
    // lafanga is fuzzy approved. 'lafunga' (distance 1) should be blocked.
    assertEquals(evaluateDisplayName("lafunga").action, 'BLOCK');
});

Deno.test("Unit: evaluateDisplayName - high-risk terms not being fuzzy matched", () => {
    // 'ass' is exact match only.
    // 'as' (distance 1) should not be blocked.
    assertEquals(evaluateDisplayName("as").action, 'ALLOW');
    assertEquals(evaluateDisplayName("assassin").action, 'ALLOW');
});

// --- INTEGRATION TESTS (Requires Deno & mock/live Supabase environment) ---
Deno.test("Integration: unauthenticated request rejection", async () => {
    const req = new Request("http://localhost/student_update_display_name", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ new_name: "Test" })
    });
    const res = await handler(req);
    assertEquals(res.status, 401);
    const body = await res.json();
    assertEquals(body.error, "Missing authorization header");
});

Deno.test("Integration: empty payload rejection", async () => {
    const req = new Request("http://localhost/student_update_display_name", {
        method: "POST",
        headers: { 
            "Content-Type": "application/json",
            "Authorization": "Bearer dummy_token"
        },
        body: JSON.stringify({ new_name: "   " })
    });
    const res = await handler(req);
    assertEquals(res.status, 401); 
});
