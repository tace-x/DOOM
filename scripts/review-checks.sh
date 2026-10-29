#!/usr/bin/env bash
set -euo pipefail

# scripts/review-checks.sh
# Milestone-aware review greps from TESTING_STRATEGY.md §6.1 and §6.2.
# Prints file:line only, exits non-zero on any violation.

echo "Running code review checks..."

VIOLATIONS=0

check_pattern() {
    local rule="$1"
    local pattern="$2"
    shift 2
    local search_paths=("$@")

    local matches
    matches=$(grep -rnE "${pattern}" "${search_paths[@]}" 2>/dev/null || true)
    if [ -n "${matches}" ]; then
        echo "FAIL [${rule}]: Pattern '${pattern}' found in forbidden location:" >&2
        echo "${matches}" >&2
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
}

# R-LAYER-1: import SwiftUI|AppKit|Cocoa in DoomCore
check_pattern "R-LAYER-1" "^import (SwiftUI|AppKit|Cocoa)" DoomKit/Sources/DoomCore

# R-LAYER-2: import Carbon|ApplicationServices|Security outside DoomServices (none in M01)
if [ -d "DoomKit/Sources/DoomServices" ]; then
    check_pattern "R-LAYER-2" "^import (Carbon|ApplicationServices|Security)" DoomKit/Sources/DoomCore DoomKit/Sources/DoomFeatures
else
    check_pattern "R-LAYER-2" "^import (Carbon|ApplicationServices|Security)" DoomKit/Sources
fi

# R-LAYER-3: import DoomServices in DoomFeatures
check_pattern "R-LAYER-3" "^import DoomServices" DoomKit/Sources/DoomFeatures

# R-GLOBALS: Bundle.main|ProcessInfo in DoomKit/Sources
check_pattern "R-GLOBALS" "Bundle\.main|ProcessInfo" DoomKit/Sources

# R-UNSAFE: unsafe concurrency or runtime escape hatches
check_pattern "R-UNSAFE" "fatalError|try!|preconditionFailure|@unchecked Sendable|nonisolated\(unsafe\)|Task\.detached|print\(|NSLog" DoomKit/Sources DOOM

# R-OWN-QUEUE: DispatchQueue allowed only in AccessibilitySelectionReader.swift (documented exception P2-04)
for file in $(grep -rl "DispatchQueue" DoomKit/Sources DOOM 2>/dev/null || true); do
    if [ "$file" != "DoomKit/Sources/DoomServices/TextAcquisition/AccessibilitySelectionReader.swift" ]; then
        echo "FAIL [R-OWN-QUEUE]: DispatchQueue found outside AccessibilitySelectionReader.swift: $file" >&2
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
done

# R-NO-SYSTEM-AX-TIMEOUT: AXUIElementCreateSystemWide forbidden
check_pattern "R-NO-SYSTEM-AX-TIMEOUT" "AXUIElementCreateSystemWide" DoomKit/Sources DOOM

# R-OWN-CHROMIUM-AX: AXEnhancedUserInterface allowed only in AccessibilitySelectionReader.swift
for file in $(grep -rl "AXEnhancedUserInterface" DoomKit/Sources DOOM 2>/dev/null || true); do
    if [ "$file" != "DoomKit/Sources/DoomServices/TextAcquisition/AccessibilitySelectionReader.swift" ]; then
        echo "FAIL [R-OWN-CHROMIUM-AX]: AXEnhancedUserInterface found outside AccessibilitySelectionReader.swift: $file" >&2
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
done

# R-PASTEBOARD: NSPasteboard allowed only in ClipboardFallbackHandler.swift, PanelView.swift, and AppDelegate.swift
for file in $(grep -rl "NSPasteboard" DoomKit/Sources DOOM 2>/dev/null || true); do
    if [ "$file" != "DoomKit/Sources/DoomServices/TextAcquisition/ClipboardFallbackHandler.swift" ] && \
       [ "$file" != "DoomKit/Sources/DoomFeatures/Panel/PanelView.swift" ] && \
       [ "$file" != "DOOM/AppDelegate.swift" ]; then
        echo "FAIL [R-PASTEBOARD]: NSPasteboard found outside approved locations: $file" >&2
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
done

# R-PBXPROJ: forbidden build settings in project.pbxproj
check_pattern "R-PBXPROJ" "DEVELOPMENT_TEAM|SWIFT_DEFAULT_ACTOR_ISOLATION|SWIFT_APPROACHABLE_CONCURRENCY|PRODUCT_BUNDLE_IDENTIFIER|INFOPLIST_KEY_" DOOM.xcodeproj/project.pbxproj


# R-XCCONFIG: forbidden keys in Config/DOOM.xcconfig
check_pattern "R-XCCONFIG" "DEVELOPMENT_TEAM|SWIFT_TREAT_WARNINGS_AS_ERRORS" Config/DOOM.xcconfig

# R-BUNDLEID: hardcoded com.tace.doom in production Swift sources
check_pattern "R-BUNDLEID" "com\.tace\.doom" DoomKit/Sources DOOM

# R-OWN-PANEL: NSPanel allowed only in DoomFeatures/Panel/DoomPanel.swift and PanelController.swift
for file in $(grep -rl "NSPanel" DoomKit/Sources DOOM 2>/dev/null || true); do
    if [ "$file" != "DoomKit/Sources/DoomFeatures/Panel/DoomPanel.swift" ] && [ "$file" != "DoomKit/Sources/DoomFeatures/Panel/PanelController.swift" ]; then
        echo "FAIL [R-OWN-PANEL]: NSPanel found outside DoomPanel.swift/PanelController.swift: $file" >&2
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
done

# R-LSUIELEMENT: LSUIElement allowed only in Config/DOOM.xcconfig
for file in $(grep -rl "LSUIElement" DoomKit/Sources DOOM DOOM.xcodeproj Config 2>/dev/null || true); do
    if [ "$file" != "Config/DOOM.xcconfig" ]; then
        echo "FAIL [R-LSUIELEMENT]: LSUIElement found outside Config/DOOM.xcconfig: $file" >&2
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
done

# R-NO-CAPTURE: sharingType allowed only in DoomPanel.swift and PanelController.swift
for file in $(grep -rl "sharingType" DoomKit/Sources DOOM 2>/dev/null || true); do
    if [ "$file" != "DoomKit/Sources/DoomFeatures/Panel/DoomPanel.swift" ] && [ "$file" != "DoomKit/Sources/DoomFeatures/Panel/PanelController.swift" ]; then
        echo "FAIL [R-NO-CAPTURE]: sharingType found outside DoomPanel.swift/PanelController.swift: $file" >&2
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
done

# R-NO-TAP: CGEventTapCreate forbidden
check_pattern "R-NO-TAP" "CGEventTapCreate" DoomKit/Sources DOOM

# R-NO-CHARS: characters access forbidden in Shortcuts
check_pattern "R-NO-CHARS" "\.characters\b" DoomKit/Sources/DoomServices/Shortcuts

# R-OWN-MONITOR: NSEvent monitors allowed only in SystemShortcutMonitor.swift
for file in $(grep -rlE "addGlobalMonitorForEvents|addLocalMonitorForEvents" DoomKit/Sources DOOM 2>/dev/null || true); do
    if [ "$file" != "DoomKit/Sources/DoomServices/Shortcuts/SystemShortcutMonitor.swift" ]; then
        echo "FAIL [R-OWN-MONITOR]: Event monitor found outside SystemShortcutMonitor.swift: $file" >&2
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
done

# R-OWN-TRUST: AXIsProcessTrusted allowed only in SystemPermissionChecker.swift
for file in $(grep -rlE "AXIsProcessTrusted" DoomKit/Sources DOOM 2>/dev/null || true); do
    if [ "$file" != "DoomKit/Sources/DoomServices/SystemPermissionChecker.swift" ]; then
        echo "FAIL [R-OWN-TRUST]: AXIsProcessTrusted found outside SystemPermissionChecker.swift: $file" >&2
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
done

# R-OWN-HOTKEY: RegisterEventHotKey allowed only in SystemShortcutMonitor.swift
for file in $(grep -rlE "RegisterEventHotKey" DoomKit/Sources DOOM 2>/dev/null || true); do
    if [ "$file" != "DoomKit/Sources/DoomServices/Shortcuts/SystemShortcutMonitor.swift" ]; then
        echo "FAIL [R-OWN-HOTKEY]: RegisterEventHotKey found outside SystemShortcutMonitor.swift: $file" >&2
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
done

# R-OWN-TIS: TIS / UCKeyTranslate allowed only in KeyCodeResolver.swift
for file in $(grep -rlE "TISCopyCurrentASCIICapableKeyboardLayoutInputSource|UCKeyTranslate" DoomKit/Sources DOOM 2>/dev/null || true); do
    if [ "$file" != "DoomKit/Sources/DoomServices/Shortcuts/KeyCodeResolver.swift" ]; then
        echo "FAIL [R-OWN-TIS]: Keyboard layout resolution found outside KeyCodeResolver.swift: $file" >&2
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
done

# R-ONE-CALLSITE: .respond( allowed only once in production code, in AssistantController.swift (GEMINI-28)
RESPOND_CALLS=$(grep -rnF ".respond(" DoomKit/Sources DOOM 2>/dev/null || true)
RESPOND_COUNT=$(echo "${RESPOND_CALLS}" | grep -Fc ".respond(" || true)
if [ "${RESPOND_COUNT}" -ne 1 ]; then
    echo "FAIL [R-ONE-CALLSITE]: Expected exactly 1 call site to .respond( in production code, found ${RESPOND_COUNT}:" >&2
    echo "${RESPOND_CALLS}" >&2
    VIOLATIONS=$((VIOLATIONS + 1))
elif ! echo "${RESPOND_CALLS}" | grep -Fq "DoomKit/Sources/DoomFeatures/Assistant/AssistantController.swift"; then
    echo "FAIL [R-ONE-CALLSITE]: .respond( call site is not in AssistantController.swift:" >&2
    echo "${RESPOND_CALLS}" >&2
    VIOLATIONS=$((VIOLATIONS + 1))
fi

# R-NO-OPENURL: URL opening forbidden within DoomFeatures/Panel/ (SEC-11)
check_pattern "R-NO-OPENURL" "NSWorkspace\.shared\.open|openURL|OpenURLAction" DoomKit/Sources/DoomFeatures/Panel

# R-NO-FILE-WRITING: FileManager, write(to:, and temporaryDirectory forbidden in production code (SEC-05)
check_pattern "R-NO-FILE-WRITING" "FileManager|write\(to:|temporaryDirectory" DoomKit/Sources DOOM

# R-NO-SCREENCAPTUREKIT: ScreenCaptureKit forbidden in production sources (SEC-09)
check_pattern "R-NO-SCREENCAPTUREKIT" "ScreenCaptureKit" DoomKit/Sources DOOM

if [ ${VIOLATIONS} -gt 0 ]; then
    echo "Review checks failed with ${VIOLATIONS} violation(s)." >&2
    exit 1
fi

echo "Review checks passed: zero architectural or safety violations."
