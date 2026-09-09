# 11 — Налаштування пристроїв і стабільний аудіовхід

GitHub: [#11](https://github.com/valtronforever/personal-guitar-coach/issues/11)

Статус: `todo`
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

Заповнюється під час реалізації: змінені компоненти, фактичні команди/перевірки та результати, hardware evidence за потреби, відкриті обмеження. Наразі реалізацію не розпочато.
