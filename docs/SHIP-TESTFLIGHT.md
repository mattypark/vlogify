# Ship vlogify to TestFlight — brief for the session that does it

Paste this whole file as the opening prompt. It is written for a Claude with App Store
Connect access, working in `~/Downloads/current-projects/appscurrent/vlogify`.

**The goal:** get build 1 of vlogify onto TestFlight and into testers' hands.

---

## Read this before touching anything

The App Store Connect credentials on this machine are a **real Apple Developer account
(HMU, INC., team `R43H5332KH`) with 12 other live apps on it.**

- Only ever act on **app id `6811419336`** (`com.matthewpark.vlogify`). Nothing else.
- **Never submit for App Store release.** TestFlight only. Beta App Review is a different
  thing from App Review and is the only review this session may trigger.
- Never touch pricing, in-app purchases, or availability. Never delete anything.
- **Never push to git.** Matthew pushes. Commit after every step.
- **Never open, read, print, or echo `.env*`, `Secrets.xcconfig`, or the `.p8` key.**
  Matthew exports credentials into the shell himself; you use them without seeing them.

---

## What is already true (verified 2026-09-17, not assumed)

Do not re-litigate these. They were checked against the live API and a real build.

| | state |
|---|---|
| App record | exists, `6811419336`, v1.0 `PREPARE_FOR_SUBMISSION` |
| Builds uploaded | **0.** TestFlight is empty |
| Beta review details | **filled** — Matthew Park, `matthew.parkk0@gmail.com`, `+15029998282` |
| Demo account | `review@vlogify.app` / `000000` — **real**, pinned in `MockBackend`, no mail sent |
| TestFlight feedback email | `matthew.parkk0@gmail.com` |
| Beta group | one **external** group `friends`, id `7def471f-f714-453b-847a-7dd83b47f805`, 0 testers, no public link |
| Export compliance | correctly absent; `ITSAppUsesNonExemptEncryption = false` answers it at each upload |
| `pre-submit.sh` | 22 checks pass, 3 warn (dead URLs) |
| Archive → export | **works.** Produces a 2.4 MB ipa with `aps-environment: production`, `beta-reports-active: true`, `get-task-allow: false` |

An exported ipa from build 1 may still be sitting at `build/export/Vlogify.ipa`. It is
gitignored and may be stale — prefer building fresh.

## The one decision to make first

**Internal and external TestFlight are not the same amount of work.**

| | internal | external |
|---|---|---|
| Who | up to 100 people **on the HMU, INC. team** (they need an ASC user account) | up to 10,000 by email or public link |
| Beta App Review | **not required** | **required**, 1–2 days |
| Live privacy policy URL | not required | expected — and vlogify's currently 404s |
| Time to a tester's phone | ~30 min after upload processes | 1–2 days |

Right now there is **no internal group** — `friends` is external. If Matthew wants the app
on his own phone today, make an internal group and skip review entirely. Ask him which he
wants before creating anything; don't assume.

### The external blocker worth naming

`vlogify.app` is **not registered** (`dig` returns no NS). The privacy policy URL saved on
the TestFlight localization is `https://vlogify.app/privacy`, which returns nothing. For
external testing Apple wants a working privacy policy URL, and a dead one is a plausible
beta-review rejection. It is not certain Apple fetches it — but the fix is cheap.

`web/` is written, recoloured to the current design, and has `vercel.json` ready. It does
**not** need a purchased domain: a free `*.vercel.app` subdomain works. **Matthew deploys
it himself** — the Vercel MCP on this Mac is signed into Andrew's account, not his. Once
it is live, update the three URLs on the app record and on the beta localization.

---

## What Matthew has to supply

**One upload credential.** `scripts/testflight.sh` reads whichever pair is in the
environment and never stores either. Ask for one; do not go looking for it.

Option A — App Store Connect API key (preferred, no 2FA prompts):

```bash
# Matthew runs this himself. The .p8 goes in ~/.appstoreconnect/private_keys/
export ASC_KEY_ID=XXXXXXXXXX
export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

Option B — app-specific password from appleid.apple.com:

```bash
export ASC_USERNAME=matthew.parkk0@gmail.com
export ASC_APP_PASSWORD=xxxx-xxxx-xxxx-xxxx
```

If neither is set the script exits with a message rather than guessing. That is correct
behaviour, not a bug — don't work around it.

---

## The steps

### 1. Confirm the tree is clean and the design tests pass

```bash
cd ~/Downloads/current-projects/appscurrent/vlogify
git status --short
swift test --package-path ios/VlogifyDesign     # 53 tests
```

### 2. Decide internal vs external with Matthew, and set the group up

For internal, create an internal group and add him as a tester. For external, `friends`
already exists. Use `beta_groups_*` / `beta_testers_*`. Adding a tester **sends them an
email** — confirm the address list with Matthew before any call that invites anyone.

### 3. Archive, export, upload

```bash
scripts/testflight.sh              # archive + export only, proves the chain
scripts/testflight.sh --upload     # and send it
```

The script bumps `CURRENT_PROJECT_VERSION` in `ios/project.yml` on every run, because App
Store Connect rejects a re-used build number. `MARKETING_VERSION` stays `0.1.0` until
Matthew says otherwise. **Commit the bump** — that file is the source of truth and the
`.xcodeproj` is generated and gitignored.

`--upload-only` re-sends the ipa already in `build/` without rebuilding or bumping.

### 4. Wait for processing, then check it landed

```
builds_list app_id=6811419336
builds_get_processing_state
```

Processing usually takes 5–15 minutes. `VALID` is what you want. `INVALID` means read the
email Apple sends — it names the exact entitlement or asset that failed.

### 5. Attach the build and set what testers see

- `builds_update_encryption` if Apple asks despite the Info.plist key (it sometimes does
  on the first build of an app).
- `builds_set_beta_localization` — "what to test" for this build.
- `builds_add_to_beta_groups` with the group id.

### 6. External only — submit for Beta App Review

`beta_app_submit_for_review`. This is **not** an App Store submission and is the only
review this session may start. Everything it needs is already filled in; if it errors,
read the field name in the error rather than guessing.

### 7. Write it down

Update `docs/NEXT-SESSION.md` with what actually happened, and commit.

---

## Things that will go wrong, and what they mean

**`No profiles for 'com.matthewpark.vlogify' were found`** — already fixed:
`-allowProvisioningUpdates` is on both `xcodebuild` calls in `testflight.sh`. If you ever
run `xcodebuild -exportArchive` by hand, you need that flag too. Archiving signs with the
team *development* profile; the App Store distribution profile does not exist until
something asks Xcode to create one.

**`pre-submit.sh` fails on three URLs** — expected until `web/` is deployed.
`testflight.sh` passes `--testflight`, which downgrades exactly those three to warnings.
Do not "fix" it by deleting the check; it is a hard gate for App Store submission on
purpose.

**`altool` asks for a 2FA code** — you are on Option B. Matthew has to type it. Prefer
Option A.

**Build number already used** — a previous run bumped and uploaded. Run `testflight.sh`
again (it bumps) rather than editing the number by hand.

**A reviewer says rooms don't sync** — they are right. The binary talks to `MockBackend`;
there is no server. Everything works on one device, which is what a lone reviewer sees, so
beta review should pass. **The App Store listing is a different matter**: its description
promises multi-phone rooms, which is a Guideline 2.3.1 problem the day anyone submits for
release. That is a backend session (`docs/BACKEND-README.md`) or a rewrite of the copy —
not this session's job, and not something to quietly paper over.

---

## Still open after this, for the record

1. **Backend.** The app is on a mock. Blocks App Store release, not TestFlight.
2. **Domain.** `vlogify.app` unregistered; four launch-checklist items are all this one
   thing. Blocks App Store release and puts external beta review at some risk.
3. **Browser-only ASC fields** — category, content rights, age rating (13+, UGC = Yes),
   App Privacy labels. No MCP tool exists for any of them; they need the Claude Chrome
   extension connected, and they must match `PrivacyInfo.xcprivacy` exactly. Not needed
   for TestFlight. See `docs/ASC-SETUP.md` §Step 4.
4. **Screenshots** 1320×2868. Not needed for TestFlight.
