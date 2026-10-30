# Тексты и контроллеры оригинала

Источник: APK 10.5 с SHA256 из APK_AUDIT.md. Экстракция статическая, без запуска BlueStacks; пользователь запретил его использование.

- Исходных строк: 2359. В native bundle перенесена 2351 запись. Восемь служебных SDK-конфигураций (идентификаторы Firebase/Google и API keys) исключены; их значения не публикуются. Это не тексты экранов.
- Массивы вариантов: 57. Правила plurals: 27. Swift helper OriginalCopy читает исходные строки и корректирует Android-экранирование и строковые format placeholders.
- Найдено 547 XML layouts. Дополнительно учитываются Compose-компоненты, Java/Kotlin controllers, menu и preference XML.
- SCREEN_INVENTORY.json — первоначальные 215 Fragment classes, включая Hilt-дубликаты. **Это не 215 уникальных экранов.**
- SCREEN_LEDGER.json — 169 controllers из ui/fragment, ui/dialog, ui/bottom, ui/activity с layout bindings, IDs, текстовыми ключами, текстами и найденными переходами. 14 определены как базовые; 155 concrete controllers не обязательно равны 155 уникальным страницам.
- Каждый controller пока имеет отдельный незавершённый статус; наличие всех текстов в bundle не означает перенос экранов.

## Подтверждённое исправление главной

HomeFragment содержит девять разделов: Мой фильтр, Аниме, Дунхуа, Последнее, Онгоинги, Анонсы, Завершённое, Фильмы, OVA. Исходный Prefs default — position1 (Аниме). HomeTabPresenter → HomeRepository передаёт country/category/status в FilterApi с extended_mode=true. Нативный HomeScreen восстановлен по этим значениям; собственный фильтр сохраняется локально. Визуальная проверка обновлённой главной выполняется отдельно.
