# Технічні джерела

Перевірено під час планування 2026-09-09. Це основа вибору API, а не доказ, що конкретний аудіомаршрут або метрики DSP уже працюють. У задачах 01/02 додати результати перевірки з обраним Xcode SDK.

- [SwiftUI: Preparing views for localization](https://developer.apple.com/documentation/swiftui/preparing-views-for-localization) — локалізовані SwiftUI labels і підказки для перекладу.
- [Xcode: Localizing and varying text with a string catalog](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog) — каталоги рядків, мови та plural variants. У проєкті обираємо їх для `en`/`uk`.
- [NSMicrophoneUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nsmicrophoneusagedescription) — опис причини доступу до аудіовходу в app bundle.
- [Audio Input Entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.device.audio-input) — перевірка entitlement для цільової sandbox/hardened-конфігурації.
- [AVAudioEngine.inputNode](https://developer.apple.com/documentation/avfaudio/avaudioengine/inputnode) — вузол входу, recording tap та перевірка валідного hardware format перед capture.
- [TN2091: Device input using the HAL Output Audio Unit](https://developer.apple.com/library/archive/technotes/tn2091/_index.html) — архівне пояснення AUHAL, вибору пристрою та каналів. Приклад старий: не копіювати deprecated API без перевірки сучасного SDK. Кілька пристроїв потребують окремого опрацювання потоків.
- [AVAudioTime](https://developer.apple.com/documentation/avfaudio/avaudiotime) — API часових значень, який потрібно звірити з timeline контрактом бекенда.
- [AVAudioPlayerNode.scheduleBuffer](https://developer.apple.com/documentation/avfaudio/avaudioplayernode/schedulebuffer(_:at:options:completionhandler:)) — кандидат для планування кліків та еталонних нот.
- [AVAudioEngineConfigurationChangeNotification](https://developer.apple.com/documentation/avfaudio/avaudioengineconfigurationchangenotification) — точка перевірки відновлення аудіосистеми після зміни конфігурації.

Алгоритм pitch/onset detection ще не обрано. Задача 12 повинна додати первинні джерела обраного алгоритму, ліцензії залежностей і benchmark evidence. macOS 14+, формула score, числові performance targets і межі MVP — рішення цього проєкту, а не рекомендації, приписані Apple.
