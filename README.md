# Modern Classes Patna - Official Website

This folder contains the complete, production-ready, accessible, and responsive official website for **Modern Classes Patna**, designed for institutional credibility and Google Play developer/app verification.

---

## 🏛️ Organization Profile
- **Institute Name:** Modern Classes Patna
- **Institute Type:** Educational Coaching Organization
- **Director / Founder:** Madhurendra Kumar Yadav
- **Official Email:** [madhurendrayadav06@gmail.com](mailto:madhurendrayadav06@gmail.com)
- **Verified Helpline Phone:** [+91 6209016951](tel:+916209016951) (Calling & WhatsApp)
- **Registered Headquarters:** P.S. Agamkuan, Bahadurpur Housing Colony, Madhu Sadan, Road Number 3, Near Bihar Urology Centre, Kumhrar, Patna - 800026, Bihar, India
- **Coaching Hubs / Branches:** Musallahpur Hat & Boring Road, Patna, Bihar

---

## 📄 Site Structure & Pages

1. **[`index.html`](index.html)** — **Home Page**
   - Official institutional identity, mission, and director overview.
   - Confirmed educational programs showcase (BPSC 71st, BSSC, Railway, 12th Board Science).
   - Android learning app features (Daily live lectures, test series, bilingual notes, doubts).
   - Quick inquiry call to action and direct contact badges.

2. **[`about.html`](about.html)** — **About Us**
   - Institutional background, educational philosophy, and pedagogical approach.
   - Director profile for Madhurendra Kumar Yadav.
   - Physical campus centers in Kumhrar, Musallahpur Hat, and Boring Road, Patna.
   - Code of ethics and anti-exaggeration transparency commitment.

3. **[`courses.html`](courses.html)** — **Courses & Academic Programs**
   - **BPSC 71st CCE Prelims & Mains Comprehensive Batch 2026**
   - **Bihar SSC (BSSC) Inter Level & CGL 4.0 Target Crash Course**
   - **Railway NTPC & Group D Comprehensive Science & Math Booster**
   - **12th Board Science Special & Academic Support**
   - Detailed syllabus breakdown, test methodology, and transparent enrollment guidelines.

4. **[`contact.html`](contact.html)** — **Contact Us & Admissions Desk**
   - Verified phone, WhatsApp, and official email links.
   - Confirmed registered address and center hours.
   - Functional, accessible enquiry form that prepares and dispatches inquiries directly via Email (`mailto:`) and WhatsApp (`+91 6209016951`) with zero silent discard.

5. **[`privacy-policy.html`](privacy-policy.html)** — **Privacy Policy**
   - Fully compliant with Google Play Developer Policy Standards.
   - Real technical data collection breakdown: Supabase Auth, profiles, attendance, doubts, and mock test scores.
   - Camera and storage media permission justifications.
   - Google Play In-App Billing disclosures (no raw card data stored).
   - Clear 30-day Account Deletion walkthrough.

6. **[`terms.html`](terms.html)** — **Terms of Use**
   - Reasonable educational service conditions and disclaimers.
   - Single-device active session policy for content security.
   - Strict intellectual property and anti-piracy provisions.
   - Governing law in Patna, Bihar.

7. **[`app-support.html`](app-support.html)** — **App Support & Help Center**
   - Practical troubleshooting for student login, session lockout reset, and password recovery.
   - Live class streaming and recorded video archive guidance.
   - Google Play order verification and purchase restore guide.
   - Step-by-step account deletion compliance guide.
   - Support SLA and operational hours.

---

## 🎨 Design System & Technologies
- **Technology:** Semantic HTML5, Modern Responsive CSS3 (CSS Variables, Flexbox, Grid), Vanilla ES6 JavaScript.
- **Colors:** Primary Gold/Amber (`#FFB703`), Deep Blue/Navy (`#023047`), Dark Canvas (`#0B0F19`), Card Surface (`#1A2234`).
- **Accessibility:** WCAG AA compliance, semantic landmark elements, `:focus-visible` styling, ARIA roles, and accessible skip link.
- **Zero Build Dependencies:** Can be served directly by any web server without requiring node build scripts or bundling steps.

---

## 🚀 Deployment Options

### 1. Local Preview
```bash
# Using Python built-in server:
python -m http.server 8080 --directory website
# Open http://localhost:8080 in your browser
```

### 2. Cloudflare Pages / Vercel / Netlify
- Set the root directory / publish directory to `website`.
- Zero build command required (`Build command: none`, `Output directory: .`).

### 3. GitHub Pages
- Host from repository directory `/website` or branch `gh-pages`.

### 4. Firebase Hosting
- Add to `firebase.json`:
```json
{
  "hosting": {
    "public": "website",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"]
  }
}
```
- Deploy: `firebase deploy --only hosting`

---

## 📱 Google Play Console URLs
When filling out the Google Play Developer Console App Content and Store Listing sections, use the following links:
- **Developer Website:** `https://your-domain.com/` (points to `index.html`)
- **Privacy Policy URL:** `https://your-domain.com/privacy-policy.html`
- **App Support URL / Email:** `https://your-domain.com/app-support.html` / `madhurendrayadav06@gmail.com`
- **Account Deletion URL:** `https://your-domain.com/app-support.html#account-deletion`
# modernclassespatna
