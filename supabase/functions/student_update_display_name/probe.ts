import { evaluateDisplayName } from "./moderation.ts";
import { moderationDataset } from "./moderation_terms.ts";

let functionalBugFound = false;

console.log("--- Automated collision probing ---");

for (let i = 0; i < moderationDataset.length; i++) {
    const term = moderationDataset[i];
    const expectedAction = term.matching_strategy === 'context_required' ? 'REVIEW' : 'BLOCK';
    
    const candidates = [
        term.canonical_term,
        ...term.romanized_forms,
        ...term.common_misspellings,
        ...term.common_obfuscations
    ];

    for (const rawCandidate of candidates) {
        // Evaluate the string
        const res = evaluateDisplayName(rawCandidate);
        
        // Expected: it should match its own strategy, or an earlier term's strategy if it's a legitimate overlapping block.
        if (res.action !== expectedAction) {
            console.log(`[POTENTIAL BUG] String '${rawCandidate}' from canonical '${term.canonical_term}' (expected ${expectedAction}) returned ${res.action} (matchedTerm: ${res.matchedTerm}).`);
            functionalBugFound = true;
        } else if (res.matchedTerm !== rawCandidate.toLowerCase() && res.matchedTerm?.replace(/\s+/g, '') !== rawCandidate.toLowerCase().replace(/\s+/g, '')) {
            // It might have matched an earlier term
            // Find the earlier term
            const matchedParent = moderationDataset.find(t => 
                t.canonical_term.toLowerCase() === res.matchedTerm ||
                t.romanized_forms.map(x=>x.toLowerCase()).includes(res.matchedTerm!) ||
                t.common_misspellings.map(x=>x.toLowerCase()).includes(res.matchedTerm!) ||
                t.common_obfuscations.map(x=>x.toLowerCase().replace(/\s+/g,'')).includes(res.matchedTerm!)
            );
            
            // if it's the exact same term, it's fine. If it's different, it's shadowing.
            if (matchedParent && matchedParent.canonical_term !== term.canonical_term) {
                console.log(`[SHADOWING] String '${rawCandidate}' from canonical '${term.canonical_term}' matched earlier term '${matchedParent.canonical_term}' via '${res.matchedTerm}'. Action: ${res.action}`);
                // If action is same, it might be DATA QUALITY or bypass depending on nuance, 
                // but since action is same, it's not a severe failure of policy.
            }
        }
    }
}

console.log("Probe complete.");
if (functionalBugFound) {
    Deno.exit(1);
} else {
    Deno.exit(0);
}
