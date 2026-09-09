# 09 — Табулатура та послідовність нот

GitHub: [#9](https://github.com/valtronforever/personal-guitar-coach/issues/9)

Статус: `todo`
Етап: MVP
Залежності: 03, 04

Контекст: [правила](../AGENTS.md), [продукт](../docs/PRODUCT.md), [архітектура](../docs/ARCHITECTURE.md), [аудіоконтракт](../docs/AUDIO-AND-ASSESSMENT.md).

## Мета

Відображати послідовність нот на кшталт навчального табулатурного програвача.

## Робота

- Шість ліній: string1 зверху, string6 знизу; fret numbers, barlines, meter, rests і ритмічні значення.
- Четверті/восьмі/шістнадцяті, видимі duration/grouping; одночасні позиції для display-only акордів.
- Event hit testing, selection/range, scroll/zoom, auto-scroll transport cursor.
- API отримує canonical events і transport position; layout не використовує власну BPM clock.
- Accessibility description ноти/такту і keyboard event navigation.

## Критерії приймання

- Гама читається зліва направо; click повертає правильний stable event ID.
- Пауза займає правильний часовий інтервал; кілька нот в одному tick вирівняні.
- Курсор відповідає переданому tick незалежно від zoom.
- Довгі вправи не обрізають ноти; усі лади та такти можна переглянути.

## Перевірка

Fixtures 3/4, 4/4, змішані тривалості, паузи, scale, chord display; hit testing після scroll/zoom; два розміри вікна і обидві мови. Playback audio підключається в задачі 14.

## Докази виконання

Заповнюється під час реалізації: змінені компоненти, фактичні команди/перевірки та результати, hardware evidence за потреби, відкриті обмеження. Наразі реалізацію не розпочато.
