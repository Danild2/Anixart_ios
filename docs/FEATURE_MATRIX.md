# Пользовательские сценарии

Статус «написан» означает наличие исполняемой логики, **не полную проверку сценария**. Облачный run 41057109715 проверил производственным Swift-кодом живые ответы каталога, поиска, релиза, озвучек, источников, серий и target; Дополнительный run 41057537419 проверил сейчас смотрят, коллекции и комментарии. HTTP403 остаётся ограничением Windows/VPN; аккаунт и воспроизведение на iPhone ещё требуют проверки. Ссылки на оригинал ниже относятся к локальной исключённой из Git декомпиляции `com/swiftsoft/anixartd/`.

| Экран / действие | Основание APK и запрос | Состояния iOS | Реализация | Проверка |
|---|---|---|---|---|
| Нижние 5 вкладок | res/menu/bottom.xml | Отдельные NavigationStack; Original / Glass | Написана | UI navigation tests; парные скриншоты отсутствуют |
| Главная / каталог | network/api/FilterApi.java; POST filter/{page} | Loading, empty, error, pagination, guest stale cache | Написана; исходная структура всех домашних вкладок ещё не восстановлена | Live production Swift decode + UI catalog navigation прошли; физический iPhone pending |
| Поиск | SearchApi.java, ReleaseSearchPresenter.java; POST search/releases/{page}; API-Version v2; query/searchBy | Debounce 350 мс; cancellation; empty/error | Написан глобальный поиск релизов | Fixture запроса + live production Swift decode прошли |
| Фильтр | FilterRequest.java, res/values/arrays.xml | Sort 0–7, диапазон лет, жанры | Частично: остальные фильтры не перенесены | Парсинг/валидность; требуется реальный ответ |
| Обзор / сейчас смотрят, рекомендации | DiscoverApi.java; POST discover/watching/{page}, discover/recommendations/{page} | Loading/error/pagination | Написан частично; interesting/discussing/comments и оригинальные секции не перенесены | Сервер + скриншоты |
| Коллекции / открыть релизы | CollectionApi.java; GET collection/all/{page}, collection/{id}/releases/{page} | Pagination/error/navigation | Чтение написано; создание/редактирование/подписки отсутствуют | Сервер + iPhone |
| Релиз / метаданные и связанные | ReleaseApi.java; GET release/{r_id}?extended_mode=true | Loading/error/content; restrictions respected | Написан основной экран; не все метаданные/виджеты | Live production Swift decode + UI переход в релиз прошли; парные Android screenshots pending |
| Релиз / избранное | FavoriteApi.java; GET favorite/add/{r_id}, favorite/delete/{r_id} | Auth required; no retries; refetch | Написано | Контролируемая ошибка GET mutation; сервер |
| Релиз / статус | ProfileListApi.java; GET profile/list/add/{status}/{r_id}, delete | Auth required; pending/error/refetch | 5 статусов написаны; ID подтверждены ProfileStatusNotificationPreference.Status | Сервер; сверить Android после изменения |
| Оценка релиза | ReleaseApi.java; GET release/vote/add/{r_id}/{vote} | Auth required; 1–5; error/refetch | Добавление написано; удаление оценки отсутствует | Сервер; нет тестового голоса в реальном аккаунте |
| Вход | AuthApi.java; POST auth/signIn form login/password | Busy/error/Keychain | Написан | Fixture login/restore/logout; реальный логин заблокирован |
| Восстановить сессию, профиль | ProfileApi.java; GET profile/{id} | Keychain restore, refresh, HTTP401 logout | Написано; автоматическое продление токена не обнаружено | MemoryVault fixture; настоящий Keychain/переподпись требует iPhone |
| Закладки / избранное, списки | FavoriteApi.java, ProfileListApi.java; GET favorite/all/{page}, profile/list/all/{status}/{page} | Guest login; pagination/errors | Написано; сортировка/поиск внутри списка не перенесены | Сервер; переключение аккаунта |
| История | HistoryApi.java; GET history/{page}, history/add/{r_id}/{s_id}/{position} | Server episode history; errors visible | Чтение/запись номера серии написаны, удаление отсутствует | Сервер; номер серии нельзя трактовать как секунды |
| Комментарии | ReleaseCommentApi.java; GET release/comment/all/{releaseId}/{page}, POST release/comment/add/{releaseId} | Pagination; spoiler reveal; auth; send/error | Чтение/добавление написаны; ответы/редактирование/удаление/голоса/жалобы отсутствуют | Сервер и iPhone keyboard/accessibility |
| Озвучка/субтитры | EpisodeApi.java; GET episode/{releaseId} | Loading/error/empty/types | Написано; закрепление озвучек отсутствует | Сервер + iPhone |
| Источник / серии | EpisodeApi.java; GET episode/{releaseId}/{typeId}, episode/{releaseId}/{typeId}/{sourceId}?sort=0 | Separate source/episode screens; error/empty | Написано | Live production Swift decode: sources/episodes прошёл; iPhone pending |
| Открыть видео | EpisodeApi.java; GET episode/target/{releaseId}/{sourceId}/{position} | Resolve→AVPlayer / explicit iframe→WKWebView / unsupported | Написана базовая обработка; ни один реальный поток пока не проверен | Live target decode → embedded прошёл; unit resolver; реальный playback/rotation/errors pending |
| Продолжить видео | database entity Episode; local progress seconds | Native seek; key includes account/release/type/source/episode | Написано для native, iframe provider-managed | Unit persistence/isolation/completion; реальный AVPlayer требует iPhone |
| Качество | Source.quality, Episode.quality; Parser adapters | HLS automatic/native controls; separate sources | Ручной выбор rendition не перенесён; quality Int не трактуется как точное разрешение | Реальный HLS/MP4; проверка адаптера |
| Источники Kodik/Sibnet/etc | parser/Parser.java | Unsupported unless explicit iframe/direct compatible URL | Специальные парсеры не перенесены | Требуется легитимный доступный источник; защиты не обходить |
| Лента | FeedApi.java; feed/all/{page}, feed/latest/all/{page}; articles models | Явное сообщение о незавершённом модуле | Не перенесена | Полный rich block renderer, channels и social tests отсутствуют |
| Настройки | Prefs, preference fragments | Theme, dark mode, two official API hosts | Частично | UI settings tests; все остальные preferences отсутствуют |
| Социальный вход, регистрация/restore | AuthApi.java | Явное ограничение на экране входа | Не перенесены | Требуется отдельная реализация провайдеров/flows |
| Друзья/каналы/статьи/значки/модерация | API_INVENTORY.json, SCREEN_INVENTORY.json | Соответствующих iOS screens нет | Не перенесены | Все действия перечислены в полном route index |
| Уведомления/фон/PiP | Manifest; player activities | Нет обязательных entitlements | Не включены | Возможности бесплатной подписи не проверены |
| IPA / SideStore | workflow + verify_ipa.py | Unsigned Release→Payload→artifact | Workflow написан; итог см. STATUS.md | CI + подпись/установка/7-дневное обновление на iPhone |

## Визуальное сопоставление

Для каталога, обзора, закладок, профиля, настроек, релиза, комментариев, выбора озвучки/источника/серии и плеера: Android screenshot отсутствует, iOS screenshot до запуска симулятора/устройства отсутствует. Основания — реальные XML, цвета и размеры APK; статус каждого визуального сравнения **не выполнено**. Минимальный набор парных кадров описан в IPHONE_TEST_PLAN.md.
