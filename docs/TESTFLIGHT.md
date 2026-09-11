# TestFlight

```sh
scripts/testflight.sh              # pre-submit → bump build → archive → export (no upload)
scripts/testflight.sh --upload     # same, then upload
scripts/testflight.sh --upload-only  # re-upload the ipa already in build/export
```

The bump happens **before** the archive, so `--upload-only` is how the build you tested
is the build people install.

## Authenticating (pick one; nothing is stored in the repo)

1. **App Store Connect API key** — export `ASC_KEY_ID` and `ASC_ISSUER_ID` in the shell;
   the .p8 lives in `~/.private_keys/AuthKey_<KEY_ID>.p8` where `altool` looks.
2. **Apple ID + app-specific password** — `ASC_USERNAME`, `ASC_APP_PASSWORD` (or
   `@keychain:AC_PASSWORD`).

## Before the first upload

- App Store Connect record for `com.matthewpark.vlogify` (team R43H5332KH).
- Age rating questionnaire answered (13+, user-generated content, messaging-adjacent).
- Export compliance is declared in Info.plist (`ITSAppUsesNonExemptEncryption = false`).
- Beta App Review needs: what to test, the demo account **review@vlogify.app / 000000**
  in the *Sign-In Required* fields (email code is fixed for that address in the mock and
  must be for the real backend too), and a support email.

## Order of operations

1. `scripts/pre-submit.sh` green.
2. `scripts/testflight.sh` — proves archive + export sign and package.
3. `scripts/testflight.sh --upload-only`.
4. Processing takes 5–20 minutes; add to a group in TestFlight.
