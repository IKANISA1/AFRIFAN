# Local Inter font input

The website uses the existing Latin variable Inter distribution already retained
in `cloudflare/operator-api/ui/fonts`. The WOFF2 and SIL Open Font License were
copied byte for byte. The local font keeps the existing `--font-inter` variable
and 100–900 weight range while removing the Google Fonts build request.

- Local source: `cloudflare/operator-api/ui/fonts/inter-latin-wght-normal.woff2`
- WOFF2 SHA-256: `3100e775e8616cd2611beecfa23a4263d7037586789b43f035236a2e6fbd4c62`
- Distribution and license provenance: the source folder's `README.md` and `LICENSE.txt`.
- License copy: `LICENSE.txt`, unchanged from the retained source.

The production source seal hashes the WOFF2, license, and importing layout.
The guarded build must compile this font with no outbound font request.
