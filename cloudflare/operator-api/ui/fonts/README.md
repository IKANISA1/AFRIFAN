# Inter font distribution

The operator interface self-hosts the unchanged Latin variable Inter WOFF2 from
`@fontsource-variable/inter` 5.3.0. This binary was recovered from the installed
reference gallery dependency, not from Revolut artwork or proprietary typefaces.
Its SIL Open Font License 1.1 is retained in `LICENSE.txt`.

- Upstream: https://github.com/rsms/inter
- Redistribution package: https://www.npmjs.com/package/@fontsource-variable/inter/v/5.3.0
- SHA-256: `3100e775e8616cd2611beecfa23a4263d7037586789b43f035236a2e6fbd4c62`

`build-ui.mjs` embeds the bytes and records their source hash. The same Worker
serves the font through its existing Access-protected asset route, with no
external runtime font request.
