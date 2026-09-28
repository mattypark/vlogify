# vlogify Worker

The relay behind the app: Hono on Cloudflare Workers, D1 for metadata, R2 for 7-day clip
copies, and the `../web` site served from the same origin. The API is tabulated in
`../docs/CONTRACT.md`; how to run, test, deploy and seed it is `../docs/BACKEND-README.md`.

```sh
npm install
npm test            # vitest in the Workers runtime
npx tsc --noEmit
npx wrangler dev    # needs .dev.vars (copy .dev.vars.example; names only there)
```

Deploying is `../scripts/deploy-worker.sh`, run by a person.
