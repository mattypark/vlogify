# App Store Connect — the vlogify record

**Status 2026-09-17 (second pass): the record EXISTS.** App id `6811419336`, bundle
`com.matthewpark.vlogify`, SKU `vlogify-v1`, version 1.0 `PREPARE_FOR_SUBMISSION`.
Steps 1, 2 and 3 are **done**, beta review details included. Step 4 is still entirely
open and needs a browser. Blockers to submission are listed in `docs/NEXT-SESSION.md`.

Verified live rather than assumed: `builds_list` returns 0, `contentRightsDeclaration` is
`null`, and the beta review block was blank in *every* field, not just `contactPhone`.

---

## (history) creating the record

The asc-mcp build on this Mac cannot create apps or register bundle IDs (no such
tools), so the record is created in the browser — by Claude driving Chrome with the
extension connected, screenshotting each step and **stopping before the final Create
for Matthew's OK**, or by Matthew directly. Everything after that is done through the
MCP against the new app ID only.

## Step 1 — register the bundle ID (developer.apple.com)

`Certificates, Identifiers & Profiles → Identifiers → +` → App IDs → App

| field | value |
|---|---|
| Description | vlogify |
| Bundle ID (explicit) | `com.matthewpark.vlogify` |
| Capabilities | Sign in with Apple · App Groups (`group.com.matthewpark.vlogify`) · Push Notifications |

## Step 2 — the app record (appstoreconnect.apple.com → My Apps → +)

| field | value |
|---|---|
| Platforms | iOS |
| Name | `vlogify` (fallback if taken: `vlogify – hourly vlog with friends`) |
| Primary language | English (U.S.) |
| Bundle ID | `com.matthewpark.vlogify` (from step 1) |
| SKU | `vlogify-v1` |
| User access | Full Access |

Paste the resulting app ID (a 10-digit number in the URL) back to the session.

## Step 3 — filled by Claude via MCP (app ID only; nothing else is touched)

- `apps_list_versions` → the 1.0 version id → `apps_update_metadata` / `apps_create_localization` (en-US):
  - description: from README ("new moment every hour, vlog it with your friends…")
  - keywords: `vlog,friends,daily,hourly,clips,camera,video,journal,bereal,log`
  - support URL `https://vlogify.app/support` · marketing URL `https://vlogify.app` · privacy `https://vlogify.app/privacy`
  - promotional text: "a private room of friends. one 2-second clip an hour. your whole day, side by side."
- `beta_app_create_localization` (en-US): description for testers, feedback `hello@vlogify.app`, privacy URL.
- `beta_app_update_review_details`: **done.** Demo account required, `review@vlogify.app` / `000000` -- which is real: `MockBackend.testEmail` and `testCode` are pinned in the build and no mail is sent. Contact Matthew Park / `matthew.parkk0@gmail.com` / `+15029998282`, notes expanded from `docs/APP-STORE-CHECKLIST.md`.
- `beta_app_update_localization`: feedback email moved off `hello@vlogify.app`, which has no MX and would have bounced both tester feedback and Apple's own beta-review mail.
- `export_compliance_create_declaration`: no proprietary or third-party cryptography beyond HTTPS; available in France.
- `beta_groups_create` "friends" (internal off, public link off).

## Step 4 — browser only (no MCP tool exists)

- Category: Social Networking (secondary: Photo & Video).
- Age rating questionnaire: 13+ — user-generated content yes, unrestricted web access no, messaging-adjacent no (no chat in v1).
- App Privacy: Data Linked to You = Contact Info (Name, Email), User Content (Photos or Videos), Identifiers (User ID); none used for tracking. Must match `PrivacyInfo.xcprivacy`.
- Content rights: does not use third-party content.
- EU DSA trader status: decide (address becomes public) or turn off EU availability.

## Never in this flow

No build upload, no submission for review, no pricing/IAP, nothing on the other 12 apps.
