#!/bin/zsh

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
INSTALLED_APP="${1:-}"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"
REGISTER_SOURCE="$ROOT_DIR/build/register-input-source"
REGISTER_SOURCE_M="$ROOT_DIR/build/register-input-source.m"
PLIST_PATH=""

plist_string()
{
  local key="$1"
  /usr/bin/plutil -extract "$key" raw -o - "$PLIST_PATH" 2>/dev/null || true
}

plist_array_value()
{
  local key_path="$1"
  /usr/libexec/PlistBuddy -c "Print :$key_path" "$PLIST_PATH" 2>/dev/null || true
}

codesign_identity()
{
  /usr/bin/security find-identity -v -p codesigning 2>/dev/null |
    /usr/bin/awk '/Apple Development:/ { print $2; exit }'
}

sign_binary_or_die()
{
  local binary_path="$1"
  local identity

  identity="$(codesign_identity)"
  if [[ -n "$identity" ]]; then
    echo "Signing helper $(basename "$binary_path") with Apple Development identity."
    /usr/bin/codesign --force --sign "$identity" --timestamp=none "$binary_path"
  else
    echo "No Apple Development signing identity was found. Ad-hoc signing helper $(basename "$binary_path")."
    /usr/bin/codesign --force --sign - --timestamp=none "$binary_path"
  fi

  /usr/bin/codesign -dvvv "$binary_path" >/dev/null
}

if [[ -z "$INSTALLED_APP" ]]; then
  echo "usage: $0 /path/to/BanshInputMethod.app" >&2
  exit 2
fi

if [[ ! -d "$INSTALLED_APP" ]]; then
  echo "input method bundle not found at $INSTALLED_APP" >&2
  exit 1
fi

PLIST_PATH="$INSTALLED_APP/Contents/Info.plist"
if [[ ! -f "$PLIST_PATH" ]]; then
  echo "Info.plist not found at $PLIST_PATH" >&2
  exit 1
fi

BUNDLE_ID="$(plist_string CFBundleIdentifier)"
SOURCE_ID="$(plist_string TISInputSourceID)"
MODE_ID="$(plist_array_value "ComponentInputModeDict:tsVisibleInputModeOrderedArrayKey:0")"

if [[ -z "$BUNDLE_ID" ]]; then
  echo "CFBundleIdentifier is missing from $PLIST_PATH" >&2
  exit 1
fi

if [[ -z "$MODE_ID" ]]; then
  MODE_ID="$SOURCE_ID"
fi

if [[ -z "$SOURCE_ID" ]]; then
  SOURCE_ID="$BUNDLE_ID"
fi

echo "Registering input method bundle ID: $BUNDLE_ID"
if [[ -n "$SOURCE_ID" ]]; then
  echo "Primary input source ID: $SOURCE_ID"
fi
if [[ -n "$MODE_ID" ]]; then
  echo "Visible input mode ID: $MODE_ID"
fi

if [[ -x "$LSREGISTER" ]]; then
  "$LSREGISTER" -f -R -trusted "$INSTALLED_APP" >/dev/null 2>&1 || true
fi

mkdir -p "$ROOT_DIR/build"
cat >"$REGISTER_SOURCE_M" <<'EOF'
#import <Foundation/Foundation.h>
#import <Carbon/Carbon.h>

static NSString* StringProperty(TISInputSourceRef source, CFStringRef key)
{
    CFTypeRef value = TISGetInputSourceProperty(source, key);
    if (value == NULL) {
        return @"";
    }

    if (CFGetTypeID(value) == CFStringGetTypeID()) {
        return (__bridge NSString*)value;
    }

    return [(__bridge id)value description];
}

static BOOL BoolProperty(TISInputSourceRef source, CFStringRef key)
{
    CFTypeRef value = TISGetInputSourceProperty(source, key);
    return value != NULL &&
           CFGetTypeID(value) == CFBooleanGetTypeID() &&
           CFBooleanGetValue((CFBooleanRef)value);
}

static NSArray* SourceListMatching(CFStringRef key, NSString* value)
{
    NSDictionary* filter = @{(__bridge NSString*)key : value};
    return CFBridgingRelease(TISCreateInputSourceList((__bridge CFDictionaryRef)filter, true));
}

int main(int argc, const char* argv[])
{
    @autoreleasepool {
        if (argc < 5) {
            return 2;
        }

        NSString* path = [NSString stringWithUTF8String:argv[1]];
        NSString* bundleID = [NSString stringWithUTF8String:argv[2]];
        NSString* sourceID = [NSString stringWithUTF8String:argv[3]];
        NSString* modeID = [NSString stringWithUTF8String:argv[4]];
        NSURL* url = [NSURL fileURLWithPath:path];
        OSStatus status = TISRegisterInputSource((__bridge CFURLRef)url);
        if (status != noErr) {
            fprintf(stderr, "TISRegisterInputSource failed with status %d.\n", (int)status);
            return 1;
        }

        NSMutableOrderedSet* matches = [NSMutableOrderedSet orderedSet];
        for (id source in SourceListMatching(kTISPropertyBundleID, bundleID)) {
            [matches addObject:source];
        }
        for (id source in SourceListMatching(kTISPropertyInputSourceID, sourceID)) {
            [matches addObject:source];
        }
        if (modeID.length > 0) {
            for (id source in SourceListMatching(kTISPropertyInputSourceID, modeID)) {
                [matches addObject:source];
            }
        }

        if (matches.count == 0) {
            fprintf(stderr, "Registered the bundle, but no installed input sources matched %s, %s, or %s.\n",
                    bundleID.UTF8String,
                    sourceID.UTF8String,
                    modeID.UTF8String);
            return 1;
        }

        BOOL enabledAny = NO;
        for (id object in matches) {
            TISInputSourceRef source = (__bridge TISInputSourceRef)object;
            NSString* sourceID = StringProperty(source, kTISPropertyInputSourceID);
            BOOL enableCapable = BoolProperty(source, kTISPropertyInputSourceIsEnableCapable);
            BOOL enabled = BoolProperty(source, kTISPropertyInputSourceIsEnabled);

            printf("Discovered input source: %s\n", sourceID.UTF8String);

            if (enabled) {
                enabledAny = YES;
                continue;
            }

            if (enableCapable && !enabled) {
                OSStatus enableStatus = TISEnableInputSource(source);
                printf("Enable status for %s: %d\n", sourceID.UTF8String, (int)enableStatus);
                if (enableStatus == noErr) {
                    enabledAny = YES;
                } else {
                    fprintf(stderr, "Failed to enable input source %s with status %d.\n",
                            sourceID.UTF8String,
                            (int)enableStatus);
                }
            } else {
                fprintf(stderr, "Input source %s is not enable-capable and is not enabled.\n",
                        sourceID.UTF8String);
            }
        }

        if (!enabledAny) {
            fprintf(stderr, "Bansh was registered, but no matching input source is enabled.\n");
            return 1;
        }

        return 0;
    }
}
EOF

/usr/bin/clang -fmodules -fmodules-cache-path="$ROOT_DIR/build/clang-mod-cache" \
  -framework Foundation \
  -framework Carbon \
  "$REGISTER_SOURCE_M" \
  -o "$REGISTER_SOURCE"

sign_binary_or_die "$REGISTER_SOURCE"
"$REGISTER_SOURCE" "$INSTALLED_APP" "$BUNDLE_ID" "$SOURCE_ID" "$MODE_ID"

"$ROOT_DIR/scripts/restart-input-method-services.sh"
