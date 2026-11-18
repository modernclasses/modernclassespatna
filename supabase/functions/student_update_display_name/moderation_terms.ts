export interface ModerationTerm {
  canonical_term: string;
  language_or_region: string;
  category: string;
  script: "Latin" | "Devanagari" | string;
  romanized_forms: string[];
  common_misspellings: string[];
  common_obfuscations: string[];
  severity: "low" | "medium" | "high" | "critical";
  confidence: "low" | "medium" | "high";
  false_positive_risk: "low" | "medium" | "high" | "extreme";
  exact_match_appropriate: boolean;
  fuzzy_match_appropriate: boolean;
  matching_strategy: "exact_word" | "fuzzy_candidate" | "normalized_token" | "context_required";
  notes: string;
}

export const moderationDataset: ModerationTerm[] = [
  {
    "canonical_term": "admin",
    "language_or_region": "English",
    "category": "impersonation",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [
      "admn"
    ],
    "common_obfuscations": [
      "@dmin",
      "adm1n",
      "a d m i n"
    ],
    "severity": "high",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "Impersonation of system administrator."
  },
  {
    "canonical_term": "moderator",
    "language_or_region": "English",
    "category": "impersonation",
    "script": "Latin",
    "romanized_forms": [
      "mod"
    ],
    "common_misspellings": [
      "modrator",
      "moderater"
    ],
    "common_obfuscations": [
      "m0derator",
      "m o d e r a t o r"
    ],
    "severity": "high",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "Impersonation of staff."
  },
  {
    "canonical_term": "principal",
    "language_or_region": "English",
    "category": "impersonation",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [
      "principle",
      "prinsipal"
    ],
    "common_obfuscations": [
      "pr1nc1pal"
    ],
    "severity": "high",
    "confidence": "high",
    "false_positive_risk": "medium",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "Impersonation of school authority."
  },
  {
    "canonical_term": "teacher",
    "language_or_region": "English",
    "category": "impersonation",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [
      "techer",
      "teecher"
    ],
    "common_obfuscations": [
      "t3ach3r",
      "t e a c h e r"
    ],
    "severity": "high",
    "confidence": "medium",
    "false_positive_risk": "low",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "Staff impersonation."
  },
  {
    "canonical_term": "sir",
    "language_or_region": "English",
    "category": "impersonation",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "medium",
    "confidence": "low",
    "false_positive_risk": "high",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "High FP risk with names like Siraj or Sirisha. Exact word boundary only."
  },
  {
    "canonical_term": "chhapri",
    "language_or_region": "Hindi/Hinglish",
    "category": "internet_slang",
    "script": "Latin",
    "romanized_forms": [
      "chapri",
      "chhapari",
      "chapari"
    ],
    "common_misspellings": [
      "chpri",
      "chapre"
    ],
    "common_obfuscations": [
      "c h a p r i",
      "ch@pri"
    ],
    "severity": "medium",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": true,
    "matching_strategy": "normalized_token",
    "notes": "Internet slang used to demean/harass. Historically caste-derived, heavily used as a slur."
  },
  {
    "canonical_term": "nibba",
    "language_or_region": "Indian Internet Slang",
    "category": "internet_slang",
    "script": "Latin",
    "romanized_forms": [
      "niba",
      "nibaa"
    ],
    "common_misspellings": [],
    "common_obfuscations": [
      "n1bba"
    ],
    "severity": "low",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "exact_word",
    "notes": "Demeaning term for an immature boy. Disruptive in classrooms."
  },
  {
    "canonical_term": "nibbi",
    "language_or_region": "Indian Internet Slang",
    "category": "internet_slang",
    "script": "Latin",
    "romanized_forms": [
      "nibi",
      "nibii"
    ],
    "common_misspellings": [],
    "common_obfuscations": [
      "n1bb1"
    ],
    "severity": "low",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "exact_word",
    "notes": "Demeaning term for an immature girl. Disruptive in classrooms."
  },
  {
    "canonical_term": "lafanga",
    "language_or_region": "Hindi/Urdu",
    "category": "hooligan_identity",
    "script": "Latin",
    "romanized_forms": [
      "lafange",
      "lufanga"
    ],
    "common_misspellings": [
      "lafnga",
      "laphanga"
    ],
    "common_obfuscations": [
      "l@fanga",
      "l4f4ng4"
    ],
    "severity": "low",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": true,
    "matching_strategy": "fuzzy_candidate",
    "notes": "Loafer/troublemaker identity."
  },
  {
    "canonical_term": "\u092c\u0926\u092e\u093e\u0936",
    "language_or_region": "Hindi/Maithili/Magahi",
    "category": "hooligan_identity",
    "script": "Devanagari",
    "romanized_forms": [
      "badmash",
      "badmaash",
      "bodmash"
    ],
    "common_misspellings": [
      "badmas",
      "bdmash"
    ],
    "common_obfuscations": [
      "\u092c \u0926 \u092e\u093e \u0936"
    ],
    "severity": "medium",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "exact_word",
    "notes": "Rogue/criminal identity."
  },
  {
    "canonical_term": "rangdar",
    "language_or_region": "Bhojpuri/Hindi",
    "category": "hooligan_identity",
    "script": "Latin",
    "romanized_forms": [
      "rangdaar"
    ],
    "common_misspellings": [
      "rngdar"
    ],
    "common_obfuscations": [],
    "severity": "medium",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": true,
    "matching_strategy": "fuzzy_candidate",
    "notes": "Extortionist/mafia don glorification common in UP/Bihar."
  },
  {
    "canonical_term": "gunda",
    "language_or_region": "Hindi",
    "category": "hooligan_identity",
    "script": "Latin",
    "romanized_forms": [
      "goonda"
    ],
    "common_misspellings": [
      "gonda"
    ],
    "common_obfuscations": [
      "g u n d a"
    ],
    "severity": "medium",
    "confidence": "high",
    "false_positive_risk": "medium",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "exact_word",
    "notes": "Hooligan. Must be exact_word to prevent blocking 'Gundappa'."
  },
  {
    "canonical_term": "mawali",
    "language_or_region": "Hindi/Marathi",
    "category": "hooligan_identity",
    "script": "Latin",
    "romanized_forms": [
      "mavali",
      "mawaali"
    ],
    "common_misspellings": [
      "mwali"
    ],
    "common_obfuscations": [],
    "severity": "medium",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": true,
    "matching_strategy": "fuzzy_candidate",
    "notes": "Street thug / uneducated troublemaker."
  },
  {
    "canonical_term": "bhai",
    "language_or_region": "Hindi/Urdu",
    "category": "hooligan_identity",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "medium",
    "confidence": "low",
    "false_positive_risk": "extreme",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "Gangster glorification when used as a suffix, but extreme FP risk as it means 'brother' and appears in names."
  },
  {
    "canonical_term": "bawal",
    "language_or_region": "Bhojpuri/Hindi",
    "category": "hooligan_identity",
    "script": "Latin",
    "romanized_forms": [
      "bawaal"
    ],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "low",
    "confidence": "medium",
    "false_positive_risk": "high",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "Chaos/troublemaker. Context required due to colloquial non-abusive usage."
  },
  {
    "canonical_term": "fuck",
    "language_or_region": "English",
    "category": "profanity",
    "script": "Latin",
    "romanized_forms": [
      "fck",
      "fuk"
    ],
    "common_misspellings": [
      "fukc"
    ],
    "common_obfuscations": [
      "f*ck",
      "f**k",
      "f u c k",
      "f@ck"
    ],
    "severity": "critical",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "exact_word",
    "notes": "Core profanity."
  },
  {
    "canonical_term": "shit",
    "language_or_region": "English",
    "category": "profanity",
    "script": "Latin",
    "romanized_forms": [
      "sht"
    ],
    "common_misspellings": [],
    "common_obfuscations": [
      "sh1t",
      "sh*t",
      "s h i t"
    ],
    "severity": "high",
    "confidence": "low",
    "false_positive_risk": "extreme",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "exact_word",
    "notes": "Extreme FP risk with Indian names (Harshit, Rakshit, Sheetal). MUST be exact_word."
  },
  {
    "canonical_term": "bitch",
    "language_or_region": "English",
    "category": "degrading_insults",
    "script": "Latin",
    "romanized_forms": [
      "btch"
    ],
    "common_misspellings": [
      "bich",
      "bitchh"
    ],
    "common_obfuscations": [
      "b!tch",
      "b*tch",
      "b i t c h"
    ],
    "severity": "critical",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "exact_word",
    "notes": "Core degrading insult."
  },
  {
    "canonical_term": "ass",
    "language_or_region": "English",
    "category": "profanity",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [],
    "common_obfuscations": [
      "@ss",
      "a$$",
      "a s s"
    ],
    "severity": "medium",
    "confidence": "low",
    "false_positive_risk": "extreme",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "exact_word",
    "notes": "Extreme FP risk with legitimate words (assassin, class, grass). Exact word only."
  },
  {
    "canonical_term": "asshole",
    "language_or_region": "English",
    "category": "degrading_insults",
    "script": "Latin",
    "romanized_forms": [
      "asshol"
    ],
    "common_misspellings": [
      "ashole"
    ],
    "common_obfuscations": [
      "@sshole",
      "a$$hole"
    ],
    "severity": "critical",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": true,
    "matching_strategy": "fuzzy_candidate",
    "notes": "Core insulting profanity."
  },
  {
    "canonical_term": "dick",
    "language_or_region": "English",
    "category": "sexual_vulgarity",
    "script": "Latin",
    "romanized_forms": [
      "dik"
    ],
    "common_misspellings": [
      "dic"
    ],
    "common_obfuscations": [
      "d1ck",
      "d*ck"
    ],
    "severity": "critical",
    "confidence": "low",
    "false_positive_risk": "extreme",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "exact_word",
    "notes": "Extreme FP risk with names like 'Hardik', 'Dixit'. Exact word boundary only."
  },
  {
    "canonical_term": "pussy",
    "language_or_region": "English",
    "category": "sexual_vulgarity",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [
      "pusi",
      "puss"
    ],
    "common_obfuscations": [
      "p*ssy",
      "p u s s y",
      "puss1"
    ],
    "severity": "critical",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "exact_word",
    "notes": "Sexual vulgarity / insult."
  },
  {
    "canonical_term": "slut",
    "language_or_region": "English",
    "category": "sexual_vulgarity",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [],
    "common_obfuscations": [
      "sl*t",
      "s l u t"
    ],
    "severity": "critical",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "exact_word",
    "notes": "Severe misogynistic slur."
  },
  {
    "canonical_term": "whore",
    "language_or_region": "English",
    "category": "sexual_vulgarity",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [
      "hore"
    ],
    "common_obfuscations": [
      "wh0re",
      "w h o r e",
      "wh*re"
    ],
    "severity": "critical",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "exact_word",
    "notes": "Severe misogynistic slur."
  },
  {
    "canonical_term": "chutiya",
    "language_or_region": "Hindi/Hinglish",
    "category": "degrading_insults",
    "script": "Latin",
    "romanized_forms": [
      "chutiye",
      "chutya"
    ],
    "common_misspellings": [
      "chtiya",
      "chuteeya"
    ],
    "common_obfuscations": [
      "c h u t i y a",
      "ch*tiya"
    ],
    "severity": "high",
    "confidence": "low",
    "false_positive_risk": "extreme",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "Extremely common insult, but exact spelling collision with legitimate 'Chutia' community/surname in Assam. Route to manual review."
  },
  {
    "canonical_term": "hutiya",
    "language_or_region": "Hindi/Hinglish",
    "category": "degrading_insults",
    "script": "Latin",
    "romanized_forms": [
      "hutiye"
    ],
    "common_misspellings": [
      "hutya"
    ],
    "common_obfuscations": [
      "h*tiya"
    ],
    "severity": "high",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": true,
    "matching_strategy": "fuzzy_candidate",
    "notes": "Common evasion of 'chutiya'. Does not collide with surnames."
  },
  {
    "canonical_term": "randi",
    "language_or_region": "Hindi/Telugu",
    "category": "sexual_vulgarity",
    "script": "Latin",
    "romanized_forms": [
      "randii",
      "rand"
    ],
    "common_misspellings": [
      "rndi"
    ],
    "common_obfuscations": [
      "r@ndi",
      "r*ndi",
      "r a n d i"
    ],
    "severity": "critical",
    "confidence": "low",
    "false_positive_risk": "extreme",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "Severe slur (prostitute) in Hindi, but a respectful welcome word ('come') in Telugu. High FP risk in South Indian contexts. Route to manual review."
  },
  {
    "canonical_term": "bhadwa",
    "language_or_region": "Hindi/Hinglish",
    "category": "sexual_vulgarity",
    "script": "Latin",
    "romanized_forms": [
      "bhadva",
      "bharwa"
    ],
    "common_misspellings": [
      "bhdwa"
    ],
    "common_obfuscations": [
      "b h a d w a"
    ],
    "severity": "critical",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": true,
    "matching_strategy": "fuzzy_candidate",
    "notes": "Slur meaning pimp."
  },
  {
    "canonical_term": "madarchod",
    "language_or_region": "Hindi/Hinglish",
    "category": "profanity",
    "script": "Latin",
    "romanized_forms": [
      "madarch*d",
      "madharchod"
    ],
    "common_misspellings": [
      "madarchd"
    ],
    "common_obfuscations": [
      "m a d a r c h o d"
    ],
    "severity": "critical",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": true,
    "matching_strategy": "fuzzy_candidate",
    "notes": "Severe profanity."
  },
  {
    "canonical_term": "behenchod",
    "language_or_region": "Hindi/Hinglish",
    "category": "profanity",
    "script": "Latin",
    "romanized_forms": [
      "bhenchod"
    ],
    "common_misspellings": [
      "bhnchod"
    ],
    "common_obfuscations": [
      "b e h e n c h o d"
    ],
    "severity": "critical",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": true,
    "matching_strategy": "fuzzy_candidate",
    "notes": "Severe profanity."
  },
  {
    "canonical_term": "gaandu",
    "language_or_region": "Hindi/Hinglish",
    "category": "profanity",
    "script": "Latin",
    "romanized_forms": [
      "gandu",
      "gandoo"
    ],
    "common_misspellings": [
      "gndu"
    ],
    "common_obfuscations": [
      "g@ndu",
      "g a n d u"
    ],
    "severity": "critical",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": true,
    "matching_strategy": "fuzzy_candidate",
    "notes": "Severe profanity/insult."
  },
  {
    "canonical_term": "lund",
    "language_or_region": "Hindi/Hinglish",
    "category": "sexual_vulgarity",
    "script": "Latin",
    "romanized_forms": [
      "lauda",
      "lawda",
      "lode"
    ],
    "common_misspellings": [
      "lwda",
      "louda"
    ],
    "common_obfuscations": [
      "l*nd",
      "l u n d"
    ],
    "severity": "critical",
    "confidence": "low",
    "false_positive_risk": "extreme",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "Anatomical vulgarity in Hindi. Extremely high FP risk with Western names (e.g., Lund University, surname Lund). Route to review."
  },
  {
    "canonical_term": "chut",
    "language_or_region": "Hindi/Hinglish",
    "category": "sexual_vulgarity",
    "script": "Latin",
    "romanized_forms": [
      "choo"
    ],
    "common_misspellings": [],
    "common_obfuscations": [
      "c h u t"
    ],
    "severity": "critical",
    "confidence": "low",
    "false_positive_risk": "extreme",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "exact_word",
    "notes": "Anatomical vulgarity. High FP risk with misspellings of ' \u091b\u0942\u091f' (discount) or names. Exact boundary only."
  },
  {
    "canonical_term": "jhantu",
    "language_or_region": "Hindi/Hinglish",
    "category": "degrading_insults",
    "script": "Latin",
    "romanized_forms": [
      "jhaatu",
      "jhatu"
    ],
    "common_misspellings": [
      "jhntu"
    ],
    "common_obfuscations": [],
    "severity": "high",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": true,
    "matching_strategy": "fuzzy_candidate",
    "notes": "Vulgar insult meaning useless/pubic hair."
  },
  {
    "canonical_term": "tharki",
    "language_or_region": "Hindi/Hinglish",
    "category": "sexual_vulgarity",
    "script": "Latin",
    "romanized_forms": [
      "tharkee"
    ],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "high",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": true,
    "matching_strategy": "fuzzy_candidate",
    "notes": "Slur for a pervert."
  },
  {
    "canonical_term": "gadha",
    "language_or_region": "Hindi/Hinglish",
    "category": "degrading_insults",
    "script": "Latin",
    "romanized_forms": [
      "gadhe"
    ],
    "common_misspellings": [
      "gdha"
    ],
    "common_obfuscations": [],
    "severity": "low",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "exact_word",
    "notes": "Mild insult (donkey/idiot)."
  },
  {
    "canonical_term": "bewakoof",
    "language_or_region": "Hindi/Urdu",
    "category": "degrading_insults",
    "script": "Latin",
    "romanized_forms": [
      "bewakuf",
      "bevkoof"
    ],
    "common_misspellings": [
      "bewkuf"
    ],
    "common_obfuscations": [],
    "severity": "low",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": true,
    "matching_strategy": "fuzzy_candidate",
    "notes": "Mild insult (fool)."
  },
  {
    "canonical_term": "kutta",
    "language_or_region": "Hindi/Hinglish",
    "category": "degrading_insults",
    "script": "Latin",
    "romanized_forms": [
      "kutte",
      "kutiya"
    ],
    "common_misspellings": [],
    "common_obfuscations": [
      "k u t t a"
    ],
    "severity": "medium",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "exact_word",
    "notes": "Insult (dog/bitch). Can escalate to severe harassment in classrooms."
  },
  {
    "canonical_term": "kamina",
    "language_or_region": "Hindi/Hinglish",
    "category": "degrading_insults",
    "script": "Latin",
    "romanized_forms": [
      "kameena",
      "kaminey"
    ],
    "common_misspellings": [
      "kamna"
    ],
    "common_obfuscations": [],
    "severity": "medium",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": true,
    "matching_strategy": "fuzzy_candidate",
    "notes": "Insult (scoundrel)."
  },
  {
    "canonical_term": "harami",
    "language_or_region": "Hindi/Urdu",
    "category": "degrading_insults",
    "script": "Latin",
    "romanized_forms": [
      "haraami"
    ],
    "common_misspellings": [
      "hrmi"
    ],
    "common_obfuscations": [],
    "severity": "medium",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": true,
    "matching_strategy": "fuzzy_candidate",
    "notes": "Insult (bastard)."
  },
  {
    "canonical_term": "suar",
    "language_or_region": "Hindi/Hinglish",
    "category": "degrading_insults",
    "script": "Latin",
    "romanized_forms": [
      "suwar"
    ],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "medium",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "exact_word",
    "notes": "Insult (pig)."
  },
  {
    "canonical_term": "ullu",
    "language_or_region": "Hindi/Hinglish",
    "category": "degrading_insults",
    "script": "Latin",
    "romanized_forms": [
      "ullu ke patthe"
    ],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "low",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "exact_word",
    "notes": "Mild insult (owl/fool)."
  },
  {
    "canonical_term": "bhikari",
    "language_or_region": "Hindi/Hinglish",
    "category": "degrading_insults",
    "script": "Latin",
    "romanized_forms": [
      "bhikhari"
    ],
    "common_misspellings": [
      "bhkari"
    ],
    "common_obfuscations": [],
    "severity": "low",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": true,
    "matching_strategy": "fuzzy_candidate",
    "notes": "Class-based insult (beggar)."
  },
  {
    "canonical_term": "nalla",
    "language_or_region": "Hindi/Hinglish",
    "category": "internet_slang",
    "script": "Latin",
    "romanized_forms": [
      "nalle"
    ],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "low",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "exact_word",
    "notes": "Slang for jobless/useless."
  },
  {
    "canonical_term": "dalal",
    "language_or_region": "Hindi/Hinglish",
    "category": "degrading_insults",
    "script": "Latin",
    "romanized_forms": [
      "dalaal"
    ],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "medium",
    "confidence": "high",
    "false_positive_risk": "medium",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "exact_word",
    "notes": "Slur for pimp/corrupt broker. High FP risk with surname Dalal. Exact boundary only."
  },
  {
    "canonical_term": "dogla",
    "language_or_region": "Hindi/Hinglish",
    "category": "degrading_insults",
    "script": "Latin",
    "romanized_forms": [
      "dogala"
    ],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "medium",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "exact_word",
    "notes": "Two-faced/bastard."
  },
  {
    "canonical_term": "kill",
    "language_or_region": "English",
    "category": "threats",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "critical",
    "confidence": "low",
    "false_positive_risk": "high",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "Extreme violence. FP risk due to gamer jargon / hyperbolic youth slang. Route to review."
  },
  {
    "canonical_term": "murder",
    "language_or_region": "English",
    "category": "threats",
    "script": "Latin",
    "romanized_forms": [
      "mader"
    ],
    "common_misspellings": [
      "murdr"
    ],
    "common_obfuscations": [],
    "severity": "critical",
    "confidence": "high",
    "false_positive_risk": "medium",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "Extreme violence."
  },
  {
    "canonical_term": "rape",
    "language_or_region": "English",
    "category": "threats",
    "script": "Latin",
    "romanized_forms": [
      "rapist"
    ],
    "common_misspellings": [],
    "common_obfuscations": [
      "r@pe",
      "r a p e"
    ],
    "severity": "critical",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "Sexual violence."
  },
  {
    "canonical_term": "suicide",
    "language_or_region": "English",
    "category": "harassment",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [
      "sucide",
      "suiside"
    ],
    "common_obfuscations": [],
    "severity": "critical",
    "confidence": "high",
    "false_positive_risk": "medium",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "Self-harm/harassment."
  },
  {
    "canonical_term": "marunga",
    "language_or_region": "Hindi/Hinglish",
    "category": "threats",
    "script": "Latin",
    "romanized_forms": [
      "marungi",
      "maarunga"
    ],
    "common_misspellings": [
      "marnga"
    ],
    "common_obfuscations": [],
    "severity": "high",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "Threat of physical violence (will hit/kill)."
  },
  {
    "canonical_term": "baklol",
    "language_or_region": "Bhojpuri/Magahi",
    "category": "degrading_insults",
    "script": "Latin",
    "romanized_forms": [
      "baklolwa",
      "bakloli"
    ],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "low",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": true,
    "matching_strategy": "fuzzy_candidate",
    "notes": "Regional insult for stupid."
  },
  {
    "canonical_term": "bhakchonhar",
    "language_or_region": "Bhojpuri",
    "category": "degrading_insults",
    "script": "Latin",
    "romanized_forms": [
      "bhakchonar"
    ],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "low",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": true,
    "matching_strategy": "fuzzy_candidate",
    "notes": "Regional insult for clumsy/idiot."
  },
  {
    "canonical_term": "bsdk",
    "language_or_region": "Hindi/Internet Slang",
    "category": "internet_slang",
    "script": "Latin",
    "romanized_forms": [
      "bsdke"
    ],
    "common_misspellings": [
      "bhosadike"
    ],
    "common_obfuscations": [
      "b s d k"
    ],
    "severity": "critical",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "exact_word",
    "notes": "Common abbreviation for severe profanity."
  },
  {
    "canonical_term": "mc",
    "language_or_region": "Hindi/Internet Slang",
    "category": "internet_slang",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "critical",
    "confidence": "low",
    "false_positive_risk": "extreme",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "Initial for severe profanity. Extreme FP risk as initials for real names (e.g., M.C. Mary Kom)."
  },
  {
    "canonical_term": "bc",
    "language_or_region": "Hindi/Internet Slang",
    "category": "internet_slang",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "critical",
    "confidence": "low",
    "false_positive_risk": "extreme",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "Initial for severe profanity. Extreme FP risk as initials or academic degrees (B.C.)."
  },
  {
    "canonical_term": "director",
    "language_or_region": "English",
    "category": "impersonation",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [
      "directer",
      "dirctor"
    ],
    "common_obfuscations": [
      "d1rector"
    ],
    "severity": "medium",
    "confidence": "high",
    "false_positive_risk": "high",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "System/institution impersonation. Context required as 'Director' may legitimately appear in institutional test accounts."
  },
  {
    "canonical_term": "manager",
    "language_or_region": "English",
    "category": "impersonation",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [
      "maneger",
      "manger"
    ],
    "common_obfuscations": [
      "m@nager"
    ],
    "severity": "medium",
    "confidence": "high",
    "false_positive_risk": "high",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "Impersonation risk. Requires context review."
  },
  {
    "canonical_term": "founder",
    "language_or_region": "English",
    "category": "impersonation",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [
      "foundr"
    ],
    "common_obfuscations": [
      "f0under"
    ],
    "severity": "medium",
    "confidence": "high",
    "false_positive_risk": "high",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "Impersonation risk."
  },
  {
    "canonical_term": "official",
    "language_or_region": "English",
    "category": "impersonation",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [
      "oficial",
      "offical"
    ],
    "common_obfuscations": [
      "0fficial"
    ],
    "severity": "medium",
    "confidence": "high",
    "false_positive_risk": "high",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "Suffix impersonation (e.g., 'Rohan Official'). Needs review."
  },
  {
    "canonical_term": "support",
    "language_or_region": "English",
    "category": "impersonation",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [
      "suport"
    ],
    "common_obfuscations": [
      "s u p p o r t"
    ],
    "severity": "high",
    "confidence": "high",
    "false_positive_risk": "medium",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "Impersonation of helpdesk staff."
  },
  {
    "canonical_term": "staff",
    "language_or_region": "English",
    "category": "impersonation",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [
      "staf"
    ],
    "common_obfuscations": [],
    "severity": "medium",
    "confidence": "high",
    "false_positive_risk": "medium",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "Impersonation."
  },
  {
    "canonical_term": "system",
    "language_or_region": "English",
    "category": "impersonation",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [
      "sistem"
    ],
    "common_obfuscations": [],
    "severity": "high",
    "confidence": "high",
    "false_positive_risk": "medium",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "Automated system impersonation."
  },
  {
    "canonical_term": "headmaster",
    "language_or_region": "English",
    "category": "impersonation",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [
      "hedmaster"
    ],
    "common_obfuscations": [],
    "severity": "high",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "School authority impersonation."
  },
  {
    "canonical_term": "guruji",
    "language_or_region": "Hindi",
    "category": "impersonation",
    "script": "Latin",
    "romanized_forms": [
      "gurujee"
    ],
    "common_misspellings": [
      "gurji"
    ],
    "common_obfuscations": [],
    "severity": "medium",
    "confidence": "high",
    "false_positive_risk": "high",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "Impersonation or legitimate respectful suffix. Context required."
  },
  {
    "canonical_term": "masterji",
    "language_or_region": "Hindi",
    "category": "impersonation",
    "script": "Latin",
    "romanized_forms": [
      "masterjee"
    ],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "medium",
    "confidence": "high",
    "false_positive_risk": "high",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "Impersonation or legitimate respect."
  },
  {
    "canonical_term": "don",
    "language_or_region": "Hindi/English",
    "category": "hooligan_identity",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "medium",
    "confidence": "low",
    "false_positive_risk": "extreme",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "exact_word",
    "notes": "Gangster glorification. Extreme FP risk with Western name 'Don'."
  },
  {
    "canonical_term": "dadagiri",
    "language_or_region": "Hindi/Marathi",
    "category": "hooligan_identity",
    "script": "Latin",
    "romanized_forms": [
      "dadagari"
    ],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "medium",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": true,
    "matching_strategy": "fuzzy_candidate",
    "notes": "Bullying/thuggery."
  },
  {
    "canonical_term": "dabang",
    "language_or_region": "Hindi/Bhojpuri",
    "category": "hooligan_identity",
    "script": "Latin",
    "romanized_forms": [
      "dabangg"
    ],
    "common_misspellings": [
      "dbang"
    ],
    "common_obfuscations": [],
    "severity": "low",
    "confidence": "high",
    "false_positive_risk": "medium",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "exact_word",
    "notes": "Bully/dominant figure. Sometimes legitimate pop culture reference."
  },
  {
    "canonical_term": "bhaukal",
    "language_or_region": "Hindi/Bhojpuri",
    "category": "hooligan_identity",
    "script": "Latin",
    "romanized_forms": [
      "bhaukaal",
      "bhoukal"
    ],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "low",
    "confidence": "high",
    "false_positive_risk": "medium",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": true,
    "matching_strategy": "fuzzy_candidate",
    "notes": "Showing off/dominance/threat. Regional slang."
  },
  {
    "canonical_term": "khachra",
    "language_or_region": "Hindi/Regional",
    "category": "degrading_insults",
    "script": "Latin",
    "romanized_forms": [
      "khachara"
    ],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "low",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": true,
    "matching_strategy": "fuzzy_candidate",
    "notes": "Stubborn/troublemaker."
  },
  {
    "canonical_term": "fraud",
    "language_or_region": "English",
    "category": "degrading_insults",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [
      "frod"
    ],
    "common_obfuscations": [],
    "severity": "medium",
    "confidence": "high",
    "false_positive_risk": "medium",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "exact_word",
    "notes": "Defamation/insult. Exact word to prevent substring issues."
  },
  {
    "canonical_term": "chor",
    "language_or_region": "Hindi/Urdu",
    "category": "degrading_insults",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "medium",
    "confidence": "high",
    "false_positive_risk": "extreme",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "exact_word",
    "notes": "Thief. Extreme FP risk in English words (anchor, chord, chore)."
  },
  {
    "canonical_term": "lutera",
    "language_or_region": "Hindi/Urdu",
    "category": "hooligan_identity",
    "script": "Latin",
    "romanized_forms": [
      "lootera"
    ],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "medium",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": true,
    "matching_strategy": "fuzzy_candidate",
    "notes": "Robber/thug."
  },
  {
    "canonical_term": "daku",
    "language_or_region": "Hindi",
    "category": "hooligan_identity",
    "script": "Latin",
    "romanized_forms": [
      "daaku"
    ],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "medium",
    "confidence": "high",
    "false_positive_risk": "medium",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "exact_word",
    "notes": "Bandit. Exact word to avoid substrings."
  },
  {
    "canonical_term": "mafia",
    "language_or_region": "English/Hindi",
    "category": "hooligan_identity",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [
      "mafiya"
    ],
    "common_obfuscations": [],
    "severity": "medium",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "exact_word",
    "notes": "Criminal identity. Exact word for short length."
  },
  {
    "canonical_term": "gangster",
    "language_or_region": "English/Hinglish",
    "category": "hooligan_identity",
    "script": "Latin",
    "romanized_forms": [
      "gangstar"
    ],
    "common_misspellings": [
      "gengster"
    ],
    "common_obfuscations": [],
    "severity": "high",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": true,
    "matching_strategy": "fuzzy_candidate",
    "notes": "Criminal identity."
  },
  {
    "canonical_term": "criminal",
    "language_or_region": "English",
    "category": "hooligan_identity",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [
      "crimnal"
    ],
    "common_obfuscations": [],
    "severity": "high",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": true,
    "matching_strategy": "fuzzy_candidate",
    "notes": "Criminal identity."
  },
  {
    "canonical_term": "terrorist",
    "language_or_region": "English",
    "category": "hooligan_identity",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [
      "terorist"
    ],
    "common_obfuscations": [],
    "severity": "critical",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": true,
    "matching_strategy": "fuzzy_candidate",
    "notes": "Extreme harassment / offensive identity."
  },
  {
    "canonical_term": "hacker",
    "language_or_region": "English",
    "category": "internet_slang",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [
      "haker"
    ],
    "common_obfuscations": [
      "h@cker"
    ],
    "severity": "medium",
    "confidence": "high",
    "false_positive_risk": "medium",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": true,
    "matching_strategy": "fuzzy_candidate",
    "notes": "Disruptive intent in tech platforms."
  },
  {
    "canonical_term": "spammer",
    "language_or_region": "English",
    "category": "internet_slang",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [
      "spamer"
    ],
    "common_obfuscations": [],
    "severity": "low",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": true,
    "matching_strategy": "fuzzy_candidate",
    "notes": "Disruptive intent."
  },
  {
    "canonical_term": "scammer",
    "language_or_region": "English",
    "category": "internet_slang",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [
      "scamer"
    ],
    "common_obfuscations": [],
    "severity": "low",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": true,
    "matching_strategy": "fuzzy_candidate",
    "notes": "Disruptive intent / insult."
  },
  {
    "canonical_term": "pelunga",
    "language_or_region": "Hindi/Hinglish",
    "category": "threats",
    "script": "Latin",
    "romanized_forms": [
      "pelenge",
      "pel_denge"
    ],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "high",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "Threat of physical violence/beating."
  },
  {
    "canonical_term": "thok",
    "language_or_region": "Hindi/Hinglish",
    "category": "threats",
    "script": "Latin",
    "romanized_forms": [
      "thok_denge",
      "thokunga"
    ],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "high",
    "confidence": "low",
    "false_positive_risk": "extreme",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "Threat to shoot/kill. Extreme FP risk as a substring. Exact boundary only."
  },
  {
    "canonical_term": "gaad",
    "language_or_region": "Hindi/Hinglish",
    "category": "threats",
    "script": "Latin",
    "romanized_forms": [
      "gaad_denge",
      "gaadunga"
    ],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "high",
    "confidence": "low",
    "false_positive_risk": "extreme",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "Threat to bury alive. Extreme FP risk with words/names."
  },
  {
    "canonical_term": "kaat",
    "language_or_region": "Hindi/Hinglish",
    "category": "threats",
    "script": "Latin",
    "romanized_forms": [
      "kaat_dalunga"
    ],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "high",
    "confidence": "low",
    "false_positive_risk": "extreme",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "Threat to cut/stab. High FP risk as a verb/noun. Exact word."
  },
  {
    "canonical_term": "goli",
    "language_or_region": "Hindi/Hinglish",
    "category": "threats",
    "script": "Latin",
    "romanized_forms": [
      "goli_maar"
    ],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "high",
    "confidence": "low",
    "false_positive_risk": "high",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "Threat to shoot. Context required due to meaning 'pill' or appearing in names."
  },
  {
    "canonical_term": "dhamki",
    "language_or_region": "Hindi/Hinglish",
    "category": "threats",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [
      "dhmki"
    ],
    "common_obfuscations": [],
    "severity": "medium",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "Literally means 'threat'."
  },
  {
    "canonical_term": "maut",
    "language_or_region": "Hindi/Urdu",
    "category": "threats",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "high",
    "confidence": "medium",
    "false_positive_risk": "medium",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "Death/threat context."
  },
  {
    "canonical_term": "murkh",
    "language_or_region": "Hindi",
    "category": "degrading_insults",
    "script": "Latin",
    "romanized_forms": [
      "moorkh"
    ],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "low",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "exact_word",
    "notes": "Insult (fool/idiot)."
  },
  {
    "canonical_term": "jhand",
    "language_or_region": "Hindi/Hinglish",
    "category": "degrading_insults",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "low",
    "confidence": "high",
    "false_positive_risk": "medium",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "exact_word",
    "notes": "Slang for ruined/useless. Exact word."
  },
  {
    "canonical_term": "lukkha",
    "language_or_region": "Hindi/Hinglish",
    "category": "degrading_insults",
    "script": "Latin",
    "romanized_forms": [
      "lukha"
    ],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "low",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": true,
    "matching_strategy": "fuzzy_candidate",
    "notes": "Insult (jobless/useless/loafer)."
  },
  {
    "canonical_term": "chomu",
    "language_or_region": "Hindi/Hinglish",
    "category": "degrading_insults",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "low",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "exact_word",
    "notes": "Insult (idiot/weirdo)."
  },
  {
    "canonical_term": "bhondu",
    "language_or_region": "Hindi/Hinglish",
    "category": "degrading_insults",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "low",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": true,
    "matching_strategy": "fuzzy_candidate",
    "notes": "Insult (dumb/gullible)."
  },
  {
    "canonical_term": "dhakkan",
    "language_or_region": "Hindi/Hinglish",
    "category": "degrading_insults",
    "script": "Latin",
    "romanized_forms": [
      "dhakan"
    ],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "low",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": true,
    "matching_strategy": "fuzzy_candidate",
    "notes": "Insult (idiot/lid)."
  },
  {
    "canonical_term": "fattu",
    "language_or_region": "Hindi/Hinglish",
    "category": "degrading_insults",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [
      "fatu"
    ],
    "common_obfuscations": [],
    "severity": "low",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "exact_word",
    "notes": "Insult (coward). Exact word for short length."
  },
  {
    "canonical_term": "darpok",
    "language_or_region": "Hindi/Hinglish",
    "category": "degrading_insults",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "low",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": true,
    "matching_strategy": "fuzzy_candidate",
    "notes": "Insult (coward)."
  },
  {
    "canonical_term": "namard",
    "language_or_region": "Hindi/Urdu",
    "category": "degrading_insults",
    "script": "Latin",
    "romanized_forms": [
      "namardd"
    ],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "high",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": true,
    "matching_strategy": "fuzzy_candidate",
    "notes": "High severity insult (impotent)."
  },
  {
    "canonical_term": "chakka",
    "language_or_region": "Hindi/Hinglish",
    "category": "degrading_insults",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [
      "chaka"
    ],
    "common_obfuscations": [],
    "severity": "critical",
    "confidence": "low",
    "false_positive_risk": "extreme",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "Severe homophobic/transphobic slur. Extreme FP risk with the surname 'Chacko' or South Indian names."
  },
  {
    "canonical_term": "meetha",
    "language_or_region": "Hindi/Hinglish",
    "category": "degrading_insults",
    "script": "Latin",
    "romanized_forms": [
      "mitha",
      "meethaa"
    ],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "high",
    "confidence": "low",
    "false_positive_risk": "extreme",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "Homophobic slur. Extreme FP risk as it literally means 'sweet' and is used in names/titles."
  },
  {
    "canonical_term": "randa",
    "language_or_region": "Hindi",
    "category": "degrading_insults",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "high",
    "confidence": "low",
    "false_positive_risk": "extreme",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "exact_word",
    "notes": "Insult (widower). Extreme FP risk with names like 'Miranda'. Exact word only."
  },
  {
    "canonical_term": "randwa",
    "language_or_region": "Hindi",
    "category": "degrading_insults",
    "script": "Latin",
    "romanized_forms": [
      "randwaa"
    ],
    "common_misspellings": [
      "rndwa"
    ],
    "common_obfuscations": [],
    "severity": "high",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": true,
    "matching_strategy": "fuzzy_candidate",
    "notes": "Insult (widower)."
  },
  {
    "canonical_term": "budbak",
    "language_or_region": "Bhojpuri/Magahi",
    "category": "degrading_insults",
    "script": "Latin",
    "romanized_forms": [
      "burbak"
    ],
    "common_misspellings": [
      "budbk"
    ],
    "common_obfuscations": [],
    "severity": "low",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": true,
    "matching_strategy": "fuzzy_candidate",
    "notes": "Regional insult (fool)."
  },
  {
    "canonical_term": "chinal",
    "language_or_region": "Hindi/Bhojpuri",
    "category": "sexual_vulgarity",
    "script": "Latin",
    "romanized_forms": [
      "chhinal"
    ],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "high",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": true,
    "matching_strategy": "fuzzy_candidate",
    "notes": "Slur for a woman."
  },
  {
    "canonical_term": "bhosad",
    "language_or_region": "Hindi/Hinglish",
    "category": "profanity",
    "script": "Latin",
    "romanized_forms": [
      "bhosada"
    ],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "critical",
    "confidence": "high",
    "false_positive_risk": "medium",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": true,
    "matching_strategy": "fuzzy_candidate",
    "notes": "Root for severe profanity. High FP risk with surname 'Bhosale', use conservative match."
  },
  {
    "canonical_term": "chod",
    "language_or_region": "Hindi/Hinglish",
    "category": "profanity",
    "script": "Latin",
    "romanized_forms": [
      "chodna"
    ],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "high",
    "confidence": "low",
    "false_positive_risk": "extreme",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "Root for many vulgarities, but extreme FP risk with legitimate names ending in 'chod' (e.g., Ranchod). Must review."
  },
  {
    "canonical_term": "chodu",
    "language_or_region": "Hindi/Hinglish",
    "category": "profanity",
    "script": "Latin",
    "romanized_forms": [
      "chodoo"
    ],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "high",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "exact_word",
    "notes": "Vulgar insult."
  },
  {
    "canonical_term": "choduram",
    "language_or_region": "Hindi/Hinglish",
    "category": "profanity",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "high",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": true,
    "matching_strategy": "fuzzy_candidate",
    "notes": "Vulgar insult masked as a name."
  },
  {
    "canonical_term": "mutthal",
    "language_or_region": "Hindi/Hinglish",
    "category": "sexual_vulgarity",
    "script": "Latin",
    "romanized_forms": [
      "muthal"
    ],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "high",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": true,
    "matching_strategy": "fuzzy_candidate",
    "notes": "Slur for a masturbator."
  },
  {
    "canonical_term": "raand",
    "language_or_region": "Hindi/Hinglish",
    "category": "sexual_vulgarity",
    "script": "Latin",
    "romanized_forms": [
      "rannd"
    ],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "critical",
    "confidence": "low",
    "false_positive_risk": "extreme",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "exact_word",
    "notes": "Severe slur. Extreme FP risk as a substring for many names. Exact word only."
  },
  {
    "canonical_term": "hijra",
    "language_or_region": "Hindi/Hinglish",
    "category": "degrading_insults",
    "script": "Latin",
    "romanized_forms": [
      "hijda",
      "hizra"
    ],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "critical",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "exact_word",
    "notes": "Transphobic slur."
  },
  {
    "canonical_term": "gawar",
    "language_or_region": "Hindi/Hinglish",
    "category": "degrading_insults",
    "script": "Latin",
    "romanized_forms": [
      "gawaar",
      "gavar"
    ],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "low",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "exact_word",
    "notes": "Classist insult (uneducated/uncouth)."
  },
  {
    "canonical_term": "dehati",
    "language_or_region": "Hindi/Hinglish",
    "category": "degrading_insults",
    "script": "Latin",
    "romanized_forms": [
      "dehaati"
    ],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "low",
    "confidence": "low",
    "false_positive_risk": "high",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "Classist insult (rural), but also has legitimate demographic uses. Context required."
  },
  {
    "canonical_term": "jahil",
    "language_or_region": "Hindi/Urdu",
    "category": "degrading_insults",
    "script": "Latin",
    "romanized_forms": [
      "jaahil"
    ],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "medium",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "exact_word",
    "notes": "Insult (ignorant/savage)."
  },
  {
    "canonical_term": "chaparganju",
    "language_or_region": "Hindi",
    "category": "degrading_insults",
    "script": "Latin",
    "romanized_forms": [
      "chaparganjoo"
    ],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "low",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": true,
    "matching_strategy": "fuzzy_candidate",
    "notes": "Slang for idiot/bald."
  },
  {
    "canonical_term": "lodu",
    "language_or_region": "Hindi/Hinglish",
    "category": "sexual_vulgarity",
    "script": "Latin",
    "romanized_forms": [
      "laudu",
      "lawdu",
      "lavdu"
    ],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "high",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "exact_word",
    "notes": "Vulgar insult. Exact word due to short length."
  },
  {
    "canonical_term": "rapiist",
    "language_or_region": "English",
    "category": "harassment",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "critical",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "Misspelling targeting harassment."
  },
  {
    "canonical_term": "pedophile",
    "language_or_region": "English",
    "category": "harassment",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [
      "pedo",
      "paedo"
    ],
    "common_obfuscations": [
      "p3do"
    ],
    "severity": "critical",
    "confidence": "high",
    "false_positive_risk": "low",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "Severe harassment/defamation terminology."
  },
  {
    "canonical_term": "muth",
    "language_or_region": "Hindi/Hinglish",
    "category": "sexual_vulgarity",
    "script": "Latin",
    "romanized_forms": [
      "muthh"
    ],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "high",
    "confidence": "low",
    "false_positive_risk": "extreme",
    "exact_match_appropriate": true,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "exact_word",
    "notes": "Vulgarity. Extreme FP risk as a substring for regional names (e.g., Muthu). Exact word only."
  },
  {
    "canonical_term": "muthu",
    "language_or_region": "Hindi/Hinglish",
    "category": "sexual_vulgarity",
    "script": "Latin",
    "romanized_forms": [],
    "common_misspellings": [],
    "common_obfuscations": [],
    "severity": "low",
    "confidence": "low",
    "false_positive_risk": "extreme",
    "exact_match_appropriate": false,
    "fuzzy_match_appropriate": false,
    "matching_strategy": "context_required",
    "notes": "Used as a slur in the North, but is a highly common and respectful personal name in South India. MUST be context_required."
  }
];
