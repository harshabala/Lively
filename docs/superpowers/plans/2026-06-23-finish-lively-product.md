# Finish Lively Product Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move Lively from a working prototype to a clean, verifiable local product build with branded native SwiftUI UI, tidy repository state, and repeatable launch/package checks.

**Architecture:** Keep the existing Swift Package structure. Extract native SwiftUI presentation pieces from the oversized settings view without changing wallpaper playback/config behavior. Keep generated app bundles out of source control and use `/private/tmp/LivelyOutput/Lively.app` as the packaged runtime artifact.

**Tech Stack:** Swift 6.2 Package Manager, macOS 14+, SwiftUI/AppKit/AVFoundation/Combine, Swift Testing via `./test.sh`, ad-hoc code signing via `package.sh`.

---

## File Structure

- `Sources/Lively/UI/LivelyBrand.swift`: brand tokens and adaptive colors.
- `Sources/Lively/UI/GlassEffect.swift`: reusable glass and button styling.
- `Sources/Lively/UI/SettingsView.swift`: top-level settings orchestration only after decomposition.
- `Sources/Lively/UI/SettingsHeaderView.swift`: title/header view.
- `Sources/Lively/UI/SettingsFooterView.swift`: launch-at-login, pause/resume, quit, version footer.
- `Sources/Lively/UI/ScreenCardView.swift`: display card, mode picker, drop zones, display settings.
- `Sources/Lively/UI/VideoThumbnailView.swift`: thumbnail cache and preview rendering.
- `.gitignore`: ignore generated previews, build caches, and app bundle outputs.
- `README.md`: document current build/test/package/open flow.
- `docs/superpowers/plans/2026-06-23-finish-lively-product.md`: this plan.

## Task 1: Repository Hygiene And Generated Artifact Cleanup

**Files:**
- Modify: `.gitignore`
- Modify: `README.md`
- No source behavior changes.

- [ ] **Step 1: Inspect generated/tracked artifacts**

Run:

```bash
git status --short
git ls-files Output .brand-preview .build 2>/dev/null
```

Expected: `Output/Lively.app/Contents/MacOS/Lively` is currently tracked/modified, `.brand-preview/` and `Output/Lively.app/Contents/Info.plist` are untracked, and `.build` is not tracked.

- [ ] **Step 2: Update ignore rules**

Ensure `.gitignore` contains exactly these project-specific generated artifact rules:

```gitignore
.build/
.brand-preview/
Output/
Output.nosync/
*.xcuserstate
.DS_Store
```

If `.gitignore` does not exist, create it with those entries. If it exists, append only missing entries.

- [ ] **Step 3: Remove generated outputs from the working tree**

Remove generated preview and output app directories from disk:

```bash
rm -rf .brand-preview Output Output.nosync
```

If tracked `Output/...` files become deleted in git status, leave them deleted; the product artifact now belongs in `/private/tmp/LivelyOutput`, not the repository.

- [ ] **Step 4: Update README artifact language**

Ensure `README.md` says:

```markdown
Generated artifacts are intentionally ignored:

- `.build/` for SwiftPM output
- `.brand-preview/` for temporary brand previews
- `Output*/` for old in-repository app bundles
- `/private/tmp/LivelyOutput/Lively.app` for the current packaged app
```

- [ ] **Step 5: Verify hygiene**

Run:

```bash
git status --short
```

Expected: no untracked `.brand-preview/`, no untracked `Output/`, and no modified binary app artifact under `Output/`. Source/docs changes may remain.

## Task 2: Decompose The Branded SwiftUI Settings UI

**Files:**
- Modify: `Sources/Lively/UI/SettingsView.swift`
- Create: `Sources/Lively/UI/SettingsHeaderView.swift`
- Create: `Sources/Lively/UI/SettingsFooterView.swift`
- Create: `Sources/Lively/UI/ScreenCardView.swift`
- Create: `Sources/Lively/UI/VideoThumbnailView.swift`
- Modify only if needed: `Sources/Lively/UI/GlassEffect.swift`

- [ ] **Step 1: Move header into `SettingsHeaderView.swift`**

Create `SettingsHeaderView` with:

```swift
import SwiftUI

struct SettingsHeaderView: View {
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Image(systemName: "play.tv.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(10)
            }
            .background(LivelyBrand.accentGradient, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: LivelyBrand.primary.opacity(0.22), radius: 14, y: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text("Lively")
                    .font(.system(size: 18, weight: .semibold))
                Text("Video wallpapers for every Space")
                    .font(.system(size: 12))
                    .foregroundStyle(LivelyBrand.mutedForeground)
            }

            Spacer()
        }
    }
}
```

Replace `titlebar` in `SettingsView` with `SettingsHeaderView()`.

- [ ] **Step 2: Move footer into `SettingsFooterView.swift`**

Create `SettingsFooterView` that owns:

- `@ObservedObject var wallpaperController: WallpaperController`
- `let launchAtLoginBinding: Binding<Bool>`
- Launch at Login toggle
- Pause/resume button
- Quit button
- `Lively v1.0` footer text

Keep the same actions as current `SettingsView`. Use `LivelyBrand.primary`, `LivelyBrand.primarySoft`, and `LivelyBrand.destructive`.

- [ ] **Step 3: Move screen card into `ScreenCardView.swift`**

Move the current private `ScreenCard` implementation into `ScreenCardView` with the same behavior:

```swift
struct ScreenCardView: View {
    let space: ScreenSpace
    @ObservedObject var configStore: ConfigStore
    @EnvironmentObject var wallpaperController: WallpaperController
    ...
}
```

Do not change mode switching, assigning videos, bookmark/config calls, pause behavior, display settings updates, or playback error handling.

- [ ] **Step 4: Move thumbnail support into `VideoThumbnailView.swift`**

Move:

- `thumbnailCache`
- `generateThumbnail(for:)`
- `VideoThumbnailView`

Keep the same cache, AVFoundation behavior, reduce-motion animation, and branded placeholders.

- [ ] **Step 5: Simplify `SettingsView.swift`**

After extraction, `SettingsView.swift` should retain:

- `SettingsView`
- `supportedVideoTypes`
- `sectionLabel`
- `launchAtLoginBinding`
- top-level layout and screen list

It should use `ScreenCardView(space:configStore:)`, `SettingsHeaderView()`, and `SettingsFooterView(...)`.

- [ ] **Step 6: Verify compile**

Run:

```bash
swift build
```

Expected: build succeeds.

## Task 3: Product Verification And Launch Readiness

**Files:**
- Modify: `README.md`
- Create: `scripts/smoke_verify.sh`
- Optional modify: `package.sh` if verification command is missing.

- [ ] **Step 1: Create smoke verification script**

Create executable `scripts/smoke_verify.sh`:

```bash
#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== Swift build =="
swift build

echo "== Tests =="
./test.sh

echo "== Package =="
bash package.sh

APP="/private/tmp/LivelyOutput/Lively.app"

echo "== Bundle checks =="
test -x "$APP/Contents/MacOS/Lively"
plutil -lint "$APP/Contents/Info.plist"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "Smoke verification passed: $APP"
```

- [ ] **Step 2: Make script executable**

Run:

```bash
chmod +x scripts/smoke_verify.sh
```

- [ ] **Step 3: Update README with final local QA flow**

Add a section:

```markdown
## Local product verification

Run the full local verification:

```bash
./scripts/smoke_verify.sh
```

Then launch the packaged app:

```bash
open /private/tmp/LivelyOutput/Lively.app
```

Manual checks before calling a build finished:

- Menu bar icon appears.
- Settings opens from the menu bar.
- Dropping or selecting `.mp4`, `.mov`, or `.m4v` assigns a wallpaper.
- Pause/Resume updates playback state and menu label.
- Quit relaunches cleanly and persisted assignments load.
```

- [ ] **Step 4: Run smoke verification**

Run:

```bash
./scripts/smoke_verify.sh
```

Expected: script exits 0 and prints `Smoke verification passed`.

## Task 4: Final Product Readiness Review

**Files:**
- No required edits unless review finds a blocking issue.

- [ ] **Step 1: Run final commands**

Run:

```bash
./scripts/smoke_verify.sh
git status --short
```

- [ ] **Step 2: Review current working tree**

Confirm:

- No generated `.app` bundle is tracked or untracked in the repository.
- New SwiftUI files are focused and compile.
- Existing behavior tests pass.
- README tells the next operator how to build, test, package, open, and manually QA the app.

- [ ] **Step 3: Report product status**

Report whether Lively is:

- `working local product build`
- `ready for visual/manual QA`
- `not yet ready to ship`

Include any remaining manual checks that cannot be completed headlessly.
