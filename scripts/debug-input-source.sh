#!/bin/zsh

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
BUILD_DIR="$ROOT_DIR/build"
PROBE_SOURCE="$BUILD_DIR/tis-probe.m"
PROBE_BINARY="$BUILD_DIR/tis-probe"
QUERY="${1:-bansh}"

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

mkdir -p "$BUILD_DIR"

echo "TIS input sources:"

cat >"$PROBE_SOURCE" <<'EOF'
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

int main(int argc, const char* argv[])
{
    @autoreleasepool {
        NSString* query = argc >= 2 ? [NSString stringWithUTF8String:argv[1]] : @"bansh";
        NSArray* sources = CFBridgingRelease(TISCreateInputSourceList(NULL, true));
        BOOL found = NO;

        for (id object in sources) {
            TISInputSourceRef source = (__bridge TISInputSourceRef)object;

            NSString* bundleID = StringProperty(source, kTISPropertyBundleID);
            NSString* sourceID = StringProperty(source, kTISPropertyInputSourceID);
            NSString* name = StringProperty(source, kTISPropertyLocalizedName);

            if (![bundleID localizedCaseInsensitiveContainsString:query] &&
                ![sourceID localizedCaseInsensitiveContainsString:query] &&
                ![name localizedCaseInsensitiveContainsString:query]) {
                continue;
            }

            found = YES;

            printf("name=%s\n", name.UTF8String);
            printf("bundle=%s\n", bundleID.UTF8String);
            printf("source=%s\n", sourceID.UTF8String);
            printf("category=%s\n", StringProperty(source, kTISPropertyInputSourceCategory).UTF8String);
            printf("type=%s\n", StringProperty(source, kTISPropertyInputSourceType).UTF8String);
            printf("enabled=%d\n", BoolProperty(source, kTISPropertyInputSourceIsEnabled));
            printf("enableCapable=%d\n", BoolProperty(source, kTISPropertyInputSourceIsEnableCapable));
            printf("selectCapable=%d\n", BoolProperty(source, kTISPropertyInputSourceIsSelectCapable));
            printf("selected=%d\n", BoolProperty(source, kTISPropertyInputSourceIsSelected));
            printf("---\n");
        }

        if (!found) {
            fprintf(stderr, "No installed input sources matched '%s'.\n", query.UTF8String);
            return 1;
        }
    }

    return 0;
}
EOF

/usr/bin/clang -fmodules -fmodules-cache-path="$BUILD_DIR/clang-mod-cache" \
    -framework Foundation \
    -framework Carbon \
    "$PROBE_SOURCE" \
    -o "$PROBE_BINARY"

sign_binary_or_die "$PROBE_BINARY"

"$PROBE_BINARY" "$QUERY"
