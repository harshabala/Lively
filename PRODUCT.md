# Product

## Register

product

## Users

Mac users who keep multiple Spaces and displays for different workflows — focus work, messaging, music, creative sessions. They want live video wallpapers that feel native to macOS: quiet in the menu bar, independent per Space, and fully offline. They are comfortable dragging files from Finder and expect utility-grade clarity, not marketing fluff.

## Product Purpose

Lively assigns hardware-accelerated looping video wallpapers to each macOS Space and display. Success means: assign a video in seconds, switch Spaces and see the right clip playing, settings stay out of the way, and nothing leaves the machine. The UI exists only to configure assignments — the wallpaper is the hero.

## Brand Personality

**Voice:** measured, desktop-native, calm utility  
**Three words:** quiet, capable, fresh  
**Emotional goals:** confidence that it just works; calm control over a personal desktop; a small spark of delight when motion and glass feel alive without competing with the user's videos

## Anti-references

- SaaS dashboard clichés: purple gradients, hero metrics, identical icon+heading cards
- Marketing landing-page tone: hype, exclamation marks, "magical" or "revolutionary" copy
- Decorative glass stacks and nested cards that fight the actual wallpaper
- Electron/web-wrapper aesthetics that feel foreign on macOS
- Uppercase tracked section eyebrows and numbered section scaffolding (01 / 02 / 03)
- Bouncy, elastic motion on high-frequency controls (tabs, drag targets, mute toggles)

## Design Principles

1. **Serve the wallpaper, not the chrome.** Settings are a compact utility panel; visual noise stays low so the user's videos remain the focal point.
2. **Feel like a Mac utility.** SF Pro system typography, native controls, familiar destructive confirmations, and menu-bar-first interaction patterns.
3. **Honest affordances.** No fake network calls, no misleading labels, no health claims the app cannot verify. Say what Lively does in plain language.
4. **Motion with restraint.** Animate state changes that help comprehension; gate everything on Reduce Motion; keep durations under 300ms for repeated interactions.
5. **Tokens over literals.** Colors, type, spacing, and radius flow through `LivelyBrand` and `brand.md` — feature views should not invent one-off styles.

## Accessibility & Inclusion

- Respect `accessibilityReduceMotion` on all non-essential animation
- Minimum 32pt hit targets on repeated controls (tabs, pause, mute, destructive actions)
- VoiceOver labels and selected-state traits on icon-only and tab controls
- WCAG AA contrast on core text pairs (verified in `brand.md` for Mist Reef palette)
- No reliance on color alone for errors — pair destructive color with text and announcements