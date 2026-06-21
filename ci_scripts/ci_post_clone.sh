#!/bin/sh
set -e

# Xcode Cloud exposes workflow environment variables (e.g. OPENAI_API_KEY,
# configured in App Store Connect → Xcode Cloud → Workflow → Environment)
# only as shell variables inside ci_scripts. They are NOT automatically
# substituted into Info.plist's $(OPENAI_API_KEY) build-setting placeholder
# — that substitution only works for actual Xcode build settings/xcconfig
# values, which Xcode Cloud env vars are not. Without this script, the
# Info.plist key is left as the literal string "$(OPENAI_API_KEY)" and
# APIConfig.openAIKey treats that as empty, silently disabling all AI
# features in the shipped build.
#
# This script runs after the repo is cloned and before the build, so we
# write the real key value directly into the committed Info.plist here.

INFO_PLIST="$CI_PRIMARY_REPOSITORY_PATH/RecallThat/Resources/Info.plist"

if [ -z "$OPENAI_API_KEY" ]; then
    echo "warning: OPENAI_API_KEY is not set in the Xcode Cloud workflow environment — AI features will be disabled in this build"
    exit 0
fi

/usr/libexec/PlistBuddy -c "Set :OpenAIAPIKey $OPENAI_API_KEY" "$INFO_PLIST"
echo "OpenAIAPIKey injected into Info.plist"
