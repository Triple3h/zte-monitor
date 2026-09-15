# Repository Guidelines

ZTE Monitor is a macOS menu-bar + Windows tray companion for ZTE F50/V50 5G MiFi devices. It reads status from the device over three channels with automatic fallback: Router backend (80) → native ADB socket (5555) → UFI backend (2333).

## Project Structure & Module Organization

- `Sources/F50Core/` — shared Swift core: fetching, response parsing, `F50Status` models, Keychain, diagnostics, notifications.
- `Sources/F50Monitor/` — macOS SwiftUI app (executable target), plus `AppIcon.icns` and carrier logo assets.
- `windows/` — Tauri 2 desktop app: `src/` (Vue 3 UI, `stores/f50Store.js`), `src-tauri/src/` (Rust: `fetcher.rs`, `crypto.rs`, `tray.rs`, `scrcpy.rs`).
- `Tests/F50MonitorTests/` — XCTest suites and `Fixtures/` replay data.
- `cloudflare-worker/` — optional feedback relay; `docs/` — ADB/flashing and submission guides; `assets/` — README images.

## Build, Test, and Development Commands

macOS (macOS 13+):

```bash
swift build -c release   # compile
swift test               # run F50Core tests
./build.sh               # build, sign, install to /Applications, relaunch
```

Windows (Node 20+, Rust 1.75+):

```bash
cd windows && npm install
npm run dev                          # Vite UI with mock data
npm run tauri dev                    # full desktop app
npm run tauri build -- --no-bundle   # single-file exe
```

CI (`.github/workflows/`) builds macOS on `Sources/**` changes and Windows x64/arm64 on `windows/**`; pushing a `v*` tag publishes a release.

## Coding Style & Naming Conventions

- Swift: 4-space indent, `UpperCamelCase` types, `lowerCamelCase` members, `F50*` prefix for public core types, `// MARK: -` section dividers.
- Rust: rustfmt defaults, snake_case modules; Vue/JS: 2-space indent, `PascalCase.vue` components.
- Comments, commit messages, and user-facing strings are Chinese — keep them consistent. No SwiftLint/Prettier config; match surrounding code.

## Testing Guidelines

XCTest only, `@testable import F50Core`. Name tests `test<Behavior>()`, e.g. `testRejectsTruncatedADBQosResponseWithoutUplink`. Add regression tests whenever parsing payloads change; signature/QoS vectors come from real device captures, so never edit expected hashes to make a test pass. Run `swift test`. No coverage gate; UI changes are verified manually.

## Commit & Pull Request Guidelines

Commit subjects are Chinese, scoped with `|`-separated clauses: `设备控制 | 接入邻小区列表并支持选择锁定`, `Network Doctor | 居中开始诊断按钮…`. Keep commits scoped to one platform/feature.

PRs should state what and why, list affected platforms (macOS/Windows), include screenshots for UI changes, and describe manual verification. Releasing requires bumping versions in `build.sh` Info.plist, `windows/package.json`, `src-tauri/Cargo.toml`, and `tauri.conf.json`, then tagging `vX.Y`.

## Security & Configuration Tips

Credentials live in Keychain (`KeychainCredentialStore`), never on disk. Diagnostic uploads must pass `DiagnosticSanitizer` (IMEI/phone/password/SMS masking) — keep those tests green. Do not reintroduce the removed Android/iOS projects or commit device tokens.
