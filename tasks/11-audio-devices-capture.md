# 11 — Налаштування пристроїв і стабільний аудіовхід

GitHub: [#11](https://github.com/valtronforever/personal-guitar-coach/issues/11)

Статус: `pending_user`
Етап: MVP
Залежності: 02, 04, 05

Контекст: [правила](../AGENTS.md), [продукт](../docs/PRODUCT.md), [архітектура](../docs/ARCHITECTURE.md), [аудіоконтракт](../docs/AUDIO-AND-ASSESSMENT.md).

## Мета

Перетворити прототип на надійний користувацький audio setup.

## Робота

- Реалізувати AudioDeviceService/Coordinator на обраному бекенді: permission, UID selection, channel map, output route.
- Показувати actual format, доступні налаштування buffer/sample rate, level meter, clipping/silence; capability-aware hardware gain.
- Preallocated bounded buffer і timestamps, worker boundary, overflow diagnostics; capture lifecycle єдиний для features.
- Стан відсутнього/зайнятого пристрою, permission denial, unsupported route/format, format changes, hot-plug, sleep/wake.
- Зберігати вибір; не змінювати системний default audio device без потреби.

## Критерії приймання

- Input channel 2 багатоканального інтерфейсу аналізується окремо від інших.
- Switch device безпечно зупиняє та реконфігурує capture; немає подвійних taps/callbacks.
- Від'єднання сигналізує interruption, не перемикає practice на інший мікрофон.
- Сире аудіо не пишеться на диск; software monitoring за замовчуванням off.

## Перевірка

Hardware matrix з задачі 02, permission flows у .app, explicit channel, 44.1/48 kHz, repeated start/stop, unplug/replug, format change і sleep/wake. Fake service tests покривають рідкі помилки, але не заміняють hardware evidence.

## Докази виконання

Реалізовано один `AudioSessionCoordinator`/`AudioSessionStore` для всіх scenes, серіалізований input/output lifecycle, explicit UID/channel selection, HAL capability queries/controls, notifications + discovery fallback, permission/cancellation/busy/format/hot-plug/sleep/stall/data-loss стани. Додано envelope v1 `audio-selection.json`; немає automatic fallback, зміни system defaults, software monitoring чи raw audio recording.

Перевірки: 58 core tests / 9 suites та 30 AppTests / 8 suites; 243 en/uk keys; generator/UI-source checks; Debug/Release native builds і strict signature validation. Native en/uk dark/light walkthrough підтвердив shared setup state, 48 kHz/512 frames built-in input capabilities, explicit output channel 2 і очищення вибору. Scarlett у поточному переліку відсутній; capture/control mutations не запускалися.

[Локальний review](../docs/reviews/11-review.md) містить race/cleanup/interruption fixes. Статус `pending_user`: програмна частина реалізована, фізичні критерії залишаються U01/U04/U08 до фінальної сесії після всіх 22 задач. U07 — actual UI XCTest execution. Fake runtime і C buffer tests не заміняють physical USB evidence.
