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

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
