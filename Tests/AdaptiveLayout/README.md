# Adaptive layout regression checks

Run the empty-state geometry and call-site checks:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ruby Tests/AdaptiveLayout/run-empty-layout-tests.rb
```

The script compiles the production `EmptyContentLayout` helper, exercising zero
bounds during transitions, insets larger than the viewport, normal/wide windows,
and content taller than the screen. It also checks that all five local-library
and download controllers use the viewport-aware sizing path.

With an iOS simulator booted, run the UIKit probe:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ruby Tests/AdaptiveLayout/run-empty-cell-probe.rb
```

The probe compiles both production empty cells with SnapKit and tests their real
Auto Layout fitting in four viewport sizes. Only non-layout application services
are stubbed. It also compiles all five production inset-change callbacks into
small controller harnesses and invokes them during lazy view construction to
catch recursive initialization. Use `--build-only` to compile without a simulator.

These checks do not substitute for UIKit layout testing. On iPhone Duo, test an
empty library and Downloads before/after folding and rotating. Open the empty
artist, album, and genre screens; verify the illustration fits the width, the
import/format buttons remain reachable by scrolling in a short window, and no
invalid row-size or unsatisfiable-constraint exception occurs. Repeat with large
accessibility text on iPad and a resized Mac Catalyst window.

Additional checks (set `DEVELOPER_DIR` to the Xcode version under test):

```sh
ruby Tests/AdaptiveLayout/run-player-layout-regressions.rb
ruby Tests/AdaptiveLayout/run-minibar-tests.rb
LAYOUT_SIMULATOR_UDID=<booted-device-id> ruby Tests/AdaptiveLayout/run-empty-cell-probe.rb
ruby Tests/AdaptiveLayout/run-header-resize-regressions.rb
ADAPTIVE_SIMULATOR_UDID=<booted-device-id> bash Tests/AdaptiveLayout/run-navigation-probe.sh
```

The empty-cell UIKit probe also forces inset callbacks during lazy initialization
to catch recursive view creation. The header probe exercises consecutive wide /
narrow sizes using the production queue and settings layout methods. The
navigation probe extracts the production adaptive root and sidebar, with offline
session/tab stubs, and verifies real UIKit collapse/expand behavior and retained
navigation stacks. Its offscreen window is not a full application scene; UIKit
may emit appearance-transition warnings, so visual/lifecycle acceptance still
requires running the application itself.
