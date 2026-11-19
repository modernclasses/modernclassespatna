# Modern Classes Patna — Master Credentials & Handover Manifest

**Application Name:** Modern Classes Patna  
**Application Package ID:** `com.modernclasses.patna.modern_classes_patna`  
**Production Release Version:** `1.0.0+38` (Build `38`)  
**Date of Handover:** November 19, 2026  
**Account Setup:** Registered directly under Client's Google Account (`madhurendrayadav06@gmail.com`)  

---

## 1. Master Accounts & Services Inventory

All core services were set up under your email address. You already have primary root ownership.

| Service | Portal URL | Project / Account ID | Purpose |
| :--- | :--- | :--- | :--- |
| **Google Play Console** | [https://play.google.com/console](https://play.google.com/console) | `com.modernclasses.patna.modern_classes_patna` | App publishing, store listing, release management, user reviews |
| **Firebase Console** | [https://console.firebase.google.com/project/modern-classes-377d0](https://console.firebase.google.com/project/modern-classes-377d0) | `modern-classes-377d0` | Push notifications (FCM HTTP v1), app configurations |
| **Supabase Cloud** | [https://supabase.com/dashboard/project/ajwbifguifbzqmpaxvug](https://supabase.com/dashboard/project/ajwbifguifbzqmpaxvug) | `ajwbifguifbzqmpaxvug` | PostgreSQL database, GoTrue auth, video storage, edge functions |
| **Google Cloud Platform** | [https://console.cloud.google.com/welcome?project=118106266506](https://console.cloud.google.com/welcome?project=118106266506) | Project Number: `118106266506` | In-app billing verification API, service account keys |
| **Cloudflare** | [https://dash.cloudflare.com/](https://dash.cloudflare.com/) | Cloudflare Stream | Live lecture streaming and recorded video delivery |
| **GitHub** | [https://github.com/modernclasses/modernclassespatna](https://github.com/modernclasses/modernclassespatna) | User: `modernclasses` | Complete source code, migration scripts, and documentation |

---

## 2. Delivered Files Checklist

| File Name | Size | Purpose |
| :--- | :---: | :--- |
| `app-release-v38.aab` | ~70.2 MB | **Production App Bundle:** Upload this file directly to Google Play Console (Release -> Production or Closed Testing). |
| `modernclasses_release_credentials.zip` | ~3.1 KB | **Critical Signing Keys:** Contains `upload-keystore.jks`, `key.properties`, `google-services.json`, and `.env`. |
| `modernclassespatna_source_code.zip` | ~1.9 MB | **Clean Source Code Archive:** Complete offline zip of the entire codebase (without temporary build caches). |

---

## 3. Cryptographic Code Signing Credentials (CRITICAL)

Your application is signed with the following Android release keystore:
- **Keystore File:** `upload-keystore.jks` (inside `modernclasses_release_credentials.zip`)
- **Key Alias & Passwords:** Defined inside `key.properties` (inside `modernclasses_release_credentials.zip`)

> [!WARNING]
> **DO NOT LOSE `upload-keystore.jks`!**  
> Google Play strictly binds your app to this certificate. If this keystore is lost, Google Play will permanently reject any future updates to your application. Make multiple offline backups (USB drive, secure cloud drive).

---

## 4. Next Steps for the Client (Security Protocol)

To take exclusive control of your infrastructure:

1. **Rotate Passwords:**
   - Log into your Google / Gmail account, Supabase, GitHub, and Cloudflare, and update your passwords.
2. **Terminate Active Sessions:**
   - In Google Account -> Security -> Your Devices, click **"Sign out of all other sessions"**.
3. **Verify Billing Information:**
   - Check that your debit/credit card is on file for Google Play Console ($25 one-time registration), Supabase Cloud, and Cloudflare Stream.
4. **Upload the AAB:**
   - Go to Google Play Console -> Releases -> Upload `app-release-v38.aab` and submit for Google review.

---

## 5. Technical Documentation Links

- **System Architecture & Operations Manual:** [HANDOFF_MANUAL.md](https://github.com/modernclasses/modernclassespatna/blob/master/HANDOFF_MANUAL.md)
- **Final Delivery & Acceptance Receipt:** [FINAL_DELIVERY_RECEIPT.md](https://github.com/modernclasses/modernclassespatna/blob/master/FINAL_DELIVERY_RECEIPT.md)

*Project delivered complete, tested, and as-is. All development milestones are satisfied.*
