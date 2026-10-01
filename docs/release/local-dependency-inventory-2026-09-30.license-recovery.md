# Package license recovery — current closure 2026-10-01

**All 41 original findings are retained and recovered. Zero license evidence gaps remain.** The first 19 were recovered from local caches; the final 22 required saved publisher evidence. Applying that evidence performs no network requests or dependency upgrades. Publisher retrieval used the network. Legal approval is not claimed.

| Final recovery method | Component records |
| --- | ---: |
| exact-maven-pom | 5 |
| exact-maven-source-grants | 1 |
| exact-npm-release | 13 |
| identical-debian-upstream | 1 |
| locked-jsr-declaration | 1 |
| publisher-package-source-grant | 1 |

## Final 22 recovered component records

| Selected component | Version | License | Relationship |
| --- | --- | --- | --- |
| https://esm.sh/ws@8.21.1?target=denonext | 8.21.1 | MIT | exact-npm-release |
| https://esm.sh/@supabase/node-fetch@2.6.15/denonext/node-fetch.mjs | 2.6.15 | MIT | exact-npm-release |
| https://esm.sh/@supabase/storage-js@2.7.1/denonext/storage-js.mjs | 2.7.1 | MIT | exact-npm-release |
| https://esm.sh/@supabase/postgrest-js@1.19.4/denonext/postgrest-js.mjs | 1.19.4 | MIT | exact-npm-release |
| org.tensorflow:tensorflow-lite-metadata | 0.1.0-rc2 | Apache-2.0 | publisher-package-source-grant |
| https://esm.sh/@supabase/node-fetch@2.6.15?target=denonext | 2.6.15 | MIT | exact-npm-release |
| https://esm.sh/@supabase/auth-js@2.69.1/denonext/auth-js.mjs | 2.69.1 | MIT | exact-npm-release |
| com.android:zipflinger | 8.11.0 | Apache-2.0 | exact-maven-pom |
| com.android:zipflinger | 8.13.2 | Apache-2.0 | exact-maven-pom |
| https://esm.sh/node-gyp-build@4.8.4?target=denonext | 4.8.4 | MIT | exact-npm-release |
| io.netty:netty-tcnative-classes | 2.0.46.Final | Apache-2.0 | exact-maven-source-grants |
| https://esm.sh/ws@8.21.1/denonext/ws.mjs | 8.21.1 | MIT | exact-npm-release |
| com.android:zipflinger | 8.11.1 | Apache-2.0 | exact-maven-pom |
| https://esm.sh/node-gyp-build@4.8.4/denonext/node-gyp-build.mjs | 4.8.4 | MIT | exact-npm-release |
| @supabase/functions-js | 2.110.7 | MIT | locked-jsr-declaration |
| https://esm.sh/@supabase/functions-js@2.4.4/denonext/functions-js.mjs | 2.4.4 | MIT | exact-npm-release |
| https://esm.sh/@supabase/realtime-js@2.11.2/denonext/realtime-js.mjs | 2.11.2 | MIT | exact-npm-release |
| com.android:zipflinger | 8.13.1 | Apache-2.0 | exact-maven-pom |
| https://esm.sh/@supabase/supabase-js@2.49.4/denonext/supabase-js.mjs | 2.49.4 | MIT | exact-npm-release |
| buffers | 0.1.1 | MIT | identical-debian-upstream |
| https://esm.sh/@supabase/supabase-js@2.49.4 | 2.49.4 | MIT | exact-npm-release |
| com.android:zipflinger | 8.1.4 | Apache-2.0 | exact-maven-pom |

The Netty evidence covers all 23 Java source files and 27 compiled classes in the exact published release. All six files in buffers 0.1.1 equal the licensed Debian upstream distribution byte for byte. TensorFlow has explicit immutable publisher package grants and coverage for all 301 compiled classes; its binary release commit is not asserted. Neighboring package versions and differing fork archives were rejected.

The companion JSON retains every original finding and each evidence association. The current inventory, license TSV and CycloneDX SBOM include these recovered declarations. See [the closure report](local-dependency-gaps-closure-2026-10-01.md).
