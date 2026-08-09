# Gikundiro App Store Fastlane package

The lanes intentionally do not submit an app for review or release a version.
They validate the controlled store package first and keep authentication outside
the repository.

```sh
bundle exec fastlane ios validate_metadata
bundle exec fastlane ios metadata
bundle exec fastlane ios upload_build
CONFIRM_APP_STORE_SUBMISSION=submit bundle exec fastlane ios submit_review
```

`metadata` and `upload_build` require the stronger `--release-ready` gate. They
will fail while artwork, portal values, policy decisions, or accountable
approvals remain pending. Actual App Review contact and demo credentials must be
entered only in App Store Connect. `submit_review` uses the stronger
`--submission-ready` gate and leaves release timing manual after review.
