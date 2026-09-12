# Dependency decisions

## YAML lesson resources

Yams **6.2.2**, exact SwiftPM pin, is used only by Learning to decode authored `.yml` resources and by tests to write fixtures. It uses the existing Codable models, supports macOS and SwiftPM, and includes LibYAML as a statically linked C target without additional package dependencies. Domain, audio callbacks and persistence have no dependency on YAML. The app still works offline; initial package resolution requires access to GitHub or a populated SwiftPM cache.

The [upstream package manifest](https://github.com/jpsim/Yams/blob/6.2.2/Package.swift) requires Swift 5.7; its Swift-6 manifest is selected by our toolchain. Local macOS 14 deployment builds and CI verify integration. Both [Yams](https://github.com/jpsim/Yams/blob/6.2.2/LICENSE) and [LibYAML](https://github.com/yaml/libyaml/blob/master/License) use MIT licenses; their full notices ship in `Resources/ThirdPartyLicenses` in both app packaging paths. Upgrade deliberately with content, error-classification, Core/App and native build regression checks.

[PyYAML 6.0.3](https://pypi.org/project/PyYAML/6.0.3/) (MIT) is pinned in `Scripts/requirements.txt` for developer authoring and bundle checks. It is not embedded in the app. `lesson_yaml.py` uses SafeLoader with explicit duplicate-key rejection, and emits Unicode plus literal/folded text blocks. Set up `.venv` as documented in README. CI and tests invoke the same Python environment. No code-generation step is required to load lessons in the app.
