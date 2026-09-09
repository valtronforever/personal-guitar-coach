# 04 — Навігація, дизайн і двомовність

GitHub: [#4](https://github.com/valtronforever/personal-guitar-coach/issues/4)

Статус: `todo`
Етап: MVP
Залежності: 01

Контекст: [правила](../AGENTS.md), [продукт](../docs/PRODUCT.md), [архітектура](../docs/ARCHITECTURE.md), [аудіоконтракт](../docs/AUDIO-AND-ASSESSMENT.md).

## Мета

Зручна нативна оболонка з English/Українська від першого екрана.

## Робота

- NavigationSplitView і destinations Lessons, Practice, Tuner, Progress; нативне Settings window та меню.
- Ввести стриману систему spacing/typography/color, light/dark, адаптивний layout для тексту + грифа + табулатури.
- String Catalog en/uk, System/English/Українська, правила fallback та pluralization.
- Стан навігації і мову відокремити; додати клавіатурну навігацію, shortcuts та accessibility conventions.
- Підготувати UI previews для двох мов і станів loading/empty/error, без фальшивих результатів практики.

## Критерії приймання

- Перемикання мови оновлює app-owned UI та не скидає selection. Системні permission dialogs поводяться за правилами macOS; це описано.
- Українські тексти не обрізаються у визначеному мінімальному розмірі вікна.
- Розробник може додати feature screen без дублювання navigation/localization.
- Keyboard-only користувач відкриває основні destinations і Settings.

## Перевірка

UI smoke в en/uk, System fallback, світла/темна тема, window resize та VoiceOver labels. Перевірити відсутні localization keys.

## Докази виконання

Заповнюється під час реалізації: змінені компоненти, фактичні команди/перевірки та результати, hardware evidence за потреби, відкриті обмеження. Наразі реалізацію не розпочато.
