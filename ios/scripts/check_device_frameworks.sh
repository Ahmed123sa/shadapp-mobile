#!/bin/sh
# Fails a device build if any embedded framework was built for the Simulator.
#
# Flutter's `install_code_assets` step does not track the frameworks it copies
# into build/native_assets/ios/, so after a Simulator run a cached release
# build can embed the Simulator objective_c.framework. App Store Connect then
# rejects the upload ("unsupported architectures [x86_64]"). Catch it here
# instead. Fix: `flutter clean`, then rebuild.

[ "$PLATFORM_NAME" = "iphoneos" ] || exit 0

status=0
for fw in "$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH"/*.framework; do
  bin="$fw/$(basename "$fw" .framework)"
  [ -f "$bin" ] || continue
  if xcrun vtool -show-build "$bin" 2>/dev/null | grep -q IOSSIMULATOR; then
    echo "error: $(basename "$fw") was built for the iOS Simulator. Run 'flutter clean' and rebuild."
    status=1
  fi
done
exit $status
