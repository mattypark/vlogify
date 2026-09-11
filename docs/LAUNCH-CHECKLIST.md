# Launch checklist — vlogify (native iOS mapping)

| # | Item | Status |
|---|---|---|
| 1 | Privacy policy page | done — `web/privacy.html` incl. local notes + profile colour + Resend; linked in-app and for ASC; **deploy pending** |
| 2 | Terms & conditions page | done — `web/terms.html`; deploy pending |
| 3 | Secrets off the frontend | done — `Secrets.xcconfig` gitignored, `.env.example` only, no keys in source |
| 4 | Force HTTPS | done — ATS on; `BackendConfig` rejects non-https; HSTS header in `web/vercel.json` |
| 5 | Cookie consent / ATT | n/a — no tracking, no analytics, no cookies on the static site |
| 6 | Meta titles + descriptions | done — every web page |
| 7 | Social preview image | done — `web/og.png` 1200×630 |
| 8 | Favicon / app icon | done — opaque 1024 icon; `web/favicon.png` |
| 9 | Sitemap + robots.txt | done |
| 10 | Alt text / VoiceOver labels | done — every control labelled incl. ring picker, font shuffle, note blocks; bursts hidden from VoiceOver |
| 11 | Compress images | done — icon 1024 PNG, og 1200×630; sample clip 150 KB |
| 12 | Page load speed / launch time | measured — `MetricTests.testColdLaunch` (see qa report) |
| 13 | Colour contrast | done — `PaletteTests` enforce AA/AAA, incl. every playful fill's ink |
| 14 | Mobile friendly / every device size | done — 16e / 17 Pro / 17 Pro Max in the matrix; web at 375/768/1440 by CSS |
| 15 | Custom 404 / dead screens | done — `web/404.html`; deep link `vlogify://join/<code>` handled |
| 16 | Broken links | pending deploy — pre-submit curls the three legal URLs |
| 17 | Form validation | done — email, code, name (20), room name (24), page title (60), invite code (checksum), support form |
| 18 | Spam protection | done — honeypot on the support form; code rate-limit is a backend task |
| 19 | Analytics | n/a by decision — none in v1, privacy label stays small |
| 20 | One clear CTA | done — the `+` on home; "Get vlogify" on the site |
