# Contributing to Macventory

[Issues](https://github.com/vadimtanel/MacVentory/issues) and focused pull requests are welcome. Describe the concrete behavior, platform, reproduction steps and actual verification. Never attach personal inventories, diagnostics with private data, credentials or real-machine screenshots.

- Preserve the native SwiftUI/shared-core/scanner architecture and minimal dependencies.
- Discovery stays read-only. Use native APIs and documented offline manager interfaces; never infer ownership from a name alone.
- Add meaningful synthetic tests for changed behavior. Run package tests and a native build. Full Xcode/XCUITest results must be labeled pending when unavailable.
- Use `--demo` for public screenshots: fictional records, isolated configuration/cache, no live removal. Never remove installed software or clear a real inventory cache during QA.
- Uninstall tests inject mock/simulated executors. A successful test proves planning/confirmation/simulation, not deletion. Actual destructive testing requires separate owner authorization in a controlled environment.
- Document provider formats and limitations in the source matrix. Apple Silicon is the release focus; preserve harmless Intel compatibility without making unsupported claims.

## License and attribution

Contributions are under Apache-2.0. For redistribution, follow its section4 requirements: supply the license, mark modified files, retain pertinent source notices and reproduce relevant NOTICE attributions in an allowed readable location. The appendix placeholders in LICENSE are the official template; project attribution belongs in NOTICE.

We also ask forks to credit [Macventory](https://github.com/vadimtanel/MacVentory) and [Vadim Tanel](https://www.linkedin.com/in/vadim-tanel/) when practical. This is a courtesy request, not an added license restriction. Apache-2.0 does not mandate clickable GitHub/LinkedIn links in every derivative UI. See the [official license](https://www.apache.org/licenses/LICENSE-2.0).
