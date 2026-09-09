# 20 — Перевірка MVP та локальна release-збірка

GitHub: [#20](https://github.com/valtronforever/personal-guitar-coach/issues/20)

Статус: `todo`
Етап: MVP
Залежності: 01–19

Контекст: [правила](../AGENTS.md), [продукт](../docs/PRODUCT.md), [архітектура](../docs/ARCHITECTURE.md), [аудіоконтракт](../docs/AUDIO-AND-ASSESSMENT.md).

## Мета

Підтвердити, що додаток придатний до реального використання, і підготувати відтворювану release-збірку.

## Робота

- Перевірити всі критерії PRODUCT.md та task evidence; consolidated docs/VALIDATION.md з відомими обмеженнями.
- Повний hardware сценарій на Mac і USB-інтерфейсі: channel → tuning → tuner → lesson → practice → calibrated assessment → retry → history.
- Перевірити permission denial/recovery, hot-plug, sleep/wake, rate/buffer changes, corrupt storage, unsupported route.
- 15-хвилинна практика: callback underruns/dropped buffers, bounded memory, CPU, timing drift; визначити baseline hardware.
- EN/UK, клавіатура/VoiceOver, light/dark, мінімальний розмір вікна, довгі тексти.
- Release archive/app bundle, entitlements, icons/resources, offline запуск і build instructions. Локальний ad-hoc підпис. За уточненням користувача signing для розповсюдження, notarization та публікація не входять у задачу.

## Критерії приймання

- Релевантні automated tests і build пройдено; реальний USB hardware gate закрито.
- Немає критичних збоїв, оманливих оцінок або непрацюючих основних сценаріїв.
- Доступна локальна Release .app/архів із точними командами відтворення.
- Локальна .app має валідний ad-hoc підпис; зовнішнє розповсюдження та notarization не вимагаються.
- Жоден потрібний hardware check не прихований за mock test.

## Перевірка

Заповнений checklist з hardware/software versions, fixtures, метриками та фактичними build/test результатами. Якщо доступний лише один Mac або один інтерфейс, compatibility claims обмежити саме перевіреною матрицею.

## Докази виконання

Заповнюється під час реалізації: змінені компоненти, фактичні команди/перевірки та результати, hardware evidence за потреби, відкриті обмеження. Наразі реалізацію не розпочато.

