# Исследование Anixart 10.5

Дата: 2026-10-30. Источник: предоставленный пользователем `anixart.apk`.
SHA-256: `0116d39086b1cf6fa5362f0c14e655efda2103955c1f7c9d5e83099ea6209f66`.

## Подтверждено статически

- Manifest: `com.swiftsoft.anixartd`, versionName 10.5, versionCode 26101718, minSdk 23, targetSdk 37.
- Четыре DEX. JADX 1.5.6 прочитал 17988 классов; 123 ошибки декомпиляции отдельных методов. Наличие Java-текста не означает восстановление всех алгоритмов.
- Приложение смешанное: XML/View, Fragment, RecyclerView, Compose и Material 3. Наличие Compose-библиотеки не означает, что каждый экран написан на Compose.
- Нижняя навигация `res/menu/bottom.xml`: Главная → Обзор → Закладки → Лента → Профиль.
- Экран релиза: `res/layout/fragment_release.xml`, карточки `item_release.xml`, `item_release_card.xml`, история `item_release_history.xml`; обзор и закладки имеют отдельные XML.
- Light: primary #ffffff, accent #f04e5c; dark: navigation #252525, active #494458, active text #e8def7. Данные из values/colors.xml и values-night/colors.xml.
- Retrofit-интерфейсы сохранены с осмысленными именами. Основные интерфейсы находятся в classes3.dex. Полный индекс маршрутов — API_INVENTORY.json.
- `ConstantNetFetcher` задаёт `https://api-s.anixsekai.com/`. Список AnixHelper дополнительно содержит `https://api.anixsekai.com/` для RU.
- `Response.code == 0` означает успех; HTTP 200 сам по себе недостаточен. Вход: POST auth/signIn, application/x-www-form-urlencoded, login/password. SignInResponse: profile и profileToken. Пароль передаётся без обнаруженного преобразования в SignInEmailFragment.
- Поиск: POST search/releases/{page}, JSON query/searchBy, заголовок API-Version: v2. FilterRequest использует смесь явно названных snake_case полей и обычных полей sort/studio/country/source/season.
- Просмотр: episode/{releaseId} → types; episode/{releaseId}/{typeId} → sources; episode/{releaseId}/{typeId}/{sourceId} → episodes; episode/target/{releaseId}/{sourceId}/{position} → episode.
- Episode: url, iframe, position, name, quality, is_watched/is_filler. Номер серии и секунды воспроизведения — разные данные. history/add хранит номер серии, а не секунды.
- `player_default.html` — iframe-обёртка с подстановкой URL; `player_youtube.html` использует YouTube iframe API. Это не универсальный способ получить MP4.
- Parser.java выбирает адаптеры Kodik, Sibnet, SovetRomantica, MailRu, Myvi, Allvideo, AniLibria, StudioMir, VKVideo, RuTube, OK. Полный перенос их парсеров не выполнен; защищённые алгоритмы не обходятся.
- Room: пользователь, поиск, серии, последняя просмотренная серия, собственные фильтры, последнее прочтение каналов; Prefs содержит настройки. Перенос Android-базы автоматически невозможен без отдельного экспорта.
- Дополнительные модули: коллекции, комментарии и ответы, оценки, друзья, каналы, статьи, предложения статей, значки, уведомления, модерация, обращения, импорт/экспорт, управление аккаунтом и социальные провайдеры входа. Они включены в индекс и матрицу; наличие маршрута не считается реализацией iOS.

## Сетевая проверка

Прямые запросы filter/0, discover/interesting, discover/watching/0, search/releases/0, config/urls вернули HTTP 403, HTML от ddos-guard. Ответ не содержит каталога. Второй официальный домен также вернул 403. Пользователь подтвердил включённый VPN и неработающий оригинал. Обход защиты не предпринимался. Никакие пароли не использовались.

Дополнительная проверка с разрешённого GitHub-hosted runner получила настоящие HTTP200/code0. Run 41057109715 подтвердил **производственным Swift API-кодом** декодирование 25 релизов, поиска, релиза, 27 озвучек, источников, семи серий в каждой из двух озвучек и episode target с адаптером embedded. Пример публичной цепочки: release20290/type143/source153/position1; API вернул HTTPS iframe Kodik. Video URL, cookies и подписанные query-параметры в отчёты не записываются; видео не загружалось. В живом ответе Episode не содержит локального id: модель исправлена на position в рамках текущего source. Это уточнение имеет приоритет над предположениями по полям Android entity.

Вход и изменения аккаунта не выполнялись: пользователь не предоставлял сессию и не входил в iOS-приложение. Доступность API с облака не гарантирует доступность из сети iPhone. Реальное декодирование JSON не считается проверкой воспроизведения.

Сторонняя спецификация AniX-org/anixart-api-docs основана на 9.0 beta 9. Используется только как вспомогательная: APK 10.5 имеет приоритет. Нельзя считать неизвестную структуру подтверждённой живым ответом.

## Визуальная проверка

Входных скриншотов нет. ADB BlueStacks обнаружен, подключённых Android-устройств нет. Восстановление по XML/ресурсам возможно, сравнение реальных отрендеренных экранов пока не выполнено. Ни один экран не имеет статуса «пиксельно совпадает». Для каждого экрана нужен парный Android/iPhone screenshot в одинаковом состоянии.

## Среда сборки

Windows: Python 3.12.10, Git, Java 8; локально загружен Temurin JRE 21 для JADX. macOS/Xcode и Swift iOS SDK отсутствуют. Образ xcode-27 официально существует; workflow должен проверить фактические SDK и выбрать Xcode 27.1. CI и установка не считаются успешными до получения соответствующего результата.

APK, декомпилированный код и инструменты находятся только в исключённой из Git `.private/`. В публичный репозиторий отправляется самостоятельно написанный Swift и описание наблюдаемых контрактов, без APK, оригинальных графических ресурсов и секретов.
