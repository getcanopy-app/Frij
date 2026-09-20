fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios aso

```sh
[bundle exec] fastlane ios aso
```

Upload App Store metadata only (name, subtitle, keywords, description).

Takes effect on the next editable version — see fastlane/Deliverfile.

### ios aso_check

```sh
[bundle exec] fastlane ios aso_check
```

Check the API key authenticates, without changing anything.

### ios release_status

```sh
[bundle exec] fastlane ios release_status
```

Show exactly what 1.0.4 still needs before it can be submitted.

### ios prepare_release

```sh
[bundle exec] fastlane ios prepare_release
```

Attach the latest valid build to the editable version and upload release notes.

### ios submit

```sh
[bundle exec] fastlane ios submit
```

Submit the editable version to App Review. Irreversible-ish: pulling it

back means Developer Rejecting the submission.

### ios enable_capability

```sh
[bundle exec] fastlane ios enable_capability
```

Turn on a capability for the App ID (e.g. HealthKit) so signing can use it.

Xcode does this when you tick the box in Signing & Capabilities; the

entitlements file alone is not enough — export fails without it.

### ios review_audit

```sh
[bundle exec] fastlane ios review_audit
```

Pre-review audit: what is actually filled in, and what is missing.

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
