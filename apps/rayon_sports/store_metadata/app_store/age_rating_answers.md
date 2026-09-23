# Apple age-rating working sheet

Do not enter a preselected age rating. App Store Connect calculates the result
from the current questionnaire and applies regional variants. Complete this
sheet only after the exact production feature configuration is frozen.

## In-app controls and capabilities

| Question area | Working answer | Evidence / decision needed |
| --- | --- | --- |
| Parental controls | No dedicated parental control found | Product/legal approval |
| Age assurance | No age-gate implementation found | Required decision before selecting youth audiences |
| User-generated content | No cross-user UGC in this candidate | Production policy uses system aliases; social/challenge client RPCs are revoked. Private profile nickname and structured answers remain privacy-declaration inputs, not cross-user content |
| Messaging/chat | No | No shipping chat module; social/friend RPCs are unavailable to public release clients |
| Advertising | No ads found | Exact archive/SDK reconciliation |
| In-app purchases | No | No StoreKit/IAP SDK; paid digital membership is fail-closed and candidate membership submission is restricted to free physical packages |

## Content descriptors

| Descriptor | Working answer | Notes |
| --- | --- | --- |
| Violence | None found in app mechanics | Review remotely supplied news/media and screenshots |
| Profanity/crude humor | None in controlled source copy | Confirm remotely supplied club content |
| Mature/suggestive/sexual content | None found in controlled source copy | Confirm remotely supplied club content |
| Horror/fear | None found | Confirm remote content |
| Alcohol/tobacco/drugs | None found | Confirm offers/news/content |
| Medical/treatment | None found | Not a health app |
| Gambling/simulated gambling | No for this candidate | Staked challenge, jackpot, transfer, redemption, and prize/value client paths are fail-closed and RPC-revoked |
| Contests | No enabled contest/prize path | Ordinary free sports-prediction context may remain; challenges, partner pools, jackpot, rewards, and related feeds are disabled |
| Loot boxes/random rewards | No | Reward catalog, offers, and redemption are disabled for public clients |

## Final gate

- Record the full questionnaire output and calculated regional ratings.
- If product terms impose a higher minimum age, apply the supported override.
- Ensure marketing, privacy policy, terms, onboarding, and store territories
  match the final rating.
- Obtain product/legal approval with the exact build and config reference.
