import { evaluateDisplayName } from "./moderation.ts";

console.log("--- Boundary Probes ---");
let failed = false;

function test(name: string, expectBlock: boolean, expectReview: boolean = false) {
    const res = evaluateDisplayName(name);
    if (expectReview) {
        if (res.action !== 'REVIEW') {
            console.log(`[FAIL] '${name}' expected REVIEW, got ${res.action}`);
            failed = true;
        }
    } else if (expectBlock) {
        if (res.action !== 'BLOCK') {
            console.log(`[FAIL] '${name}' expected BLOCK, got ${res.action}`);
            failed = true;
        }
    } else {
        if (res.action !== 'ALLOW') {
            console.log(`[FAIL] '${name}' expected ALLOW, got ${res.action} (matched: ${res.matchedTerm})`);
            failed = true;
        }
    }
}

test("bc", false, true); 
test("JohnbcDoe", false); 
test("John bc Doe", false, true); 
test("John-bc-Doe", false, true); 
test("John_bc_Doe", false); // context_required isExactMatch treats _ as word char, so it fails exact match and returns ALLOW.
test("John\tbc\nDoe", false, true); 
test("राहुलbcकुमार", false); 
test("राहुल bc कुमार", false, true);

// Testing exact_word boundary
test("don", true); 
test("donovan", false); 
test("london", false); 

test("harami", true); 
test("harami123", false); 

test("thisisharamistring", false); 

console.log("Probes complete.");
if (failed) Deno.exit(1);
