# GRM — Garry's Mod RP-сборка (DrStrasse)

> Передача дел новой сессии: **сначала `CHECKPOINT.md`**, потом `HANDOVER.md`.
> Актуальный архитектурный аудит и roadmap: **`ROADMAP_GRM_2026.md`**.
> Контракты общего ядра, правила и локализация: **`GRM_CORE.md`**.
> Рабочая ветка этой сессии — **`arena/01a00b1f-drstrasse`**.
> Master — старый пустой снапшот, с него не работать.

Набор Lua-модулей для Garry's Mod: фракции, экономика, инвентарь, логистика,
завод полного цикла, стамина, конфиг чата. Все модули общаются через
глобальный namespace `GRM` и глобальную таблицу `Factions`.

## GRM Core v1

Введён общий фундамент платформы: `GRM.Core`, русско-английский `GRM.Lang`,
capability-реестр `GRM.Access`, безопасный JSON и backend-реестр
`GRM.Persistence`, `GRM.Net.Guard` и append-only `GRM.Audit`. Старые
`Can*` и собственные базы систем сохраняются как адаптеры, поэтому переход
не меняет текущие права и данные. `/perminfo` теперь показывает реального
владельца persistence. Медицинский компьютер первым переведён на capability,
net guard и общий аудит. Общее большое меню прав открывается через
`/grm_access`, `/доступы` или `grm_access`: назначения для фракции, роли,
отдела, аккаунта и персонажа, отдельные разрешения/запреты. Fire, Wanted,
CCTV и Phone учитывают эти назначения поверх старых матриц; их admin-receiver
защищены Net Guard и пишут Audit. Полные правила и API: [`GRM_CORE.md`](GRM_CORE.md).

## Установка

Скопировать содержимое `lua/` в `garrysmod/addons/grm/lua/`
(или прямо в `garrysmod/lua/`). Файлы в `lua/autorun/` загружаются
автоматически на сервере и клиенте.

## Файлы (куски 1–5 + собственные наработки — 48 модулей)

> **Экономика переписана с нуля (Код 43):** старые модули Код 9
> (`sh_grm_faction_economy_plus.lua`) и Код 12 (`sh_grm_faction_economy.lua`)
> **удалены и заменены** единым аддоном `sh_grm_economy.lua`. Данные старых
> файлов (`grm_faction_budgets.json`, `grm_faction_economy_plus.json`)
> одноразово импортируются при первом запуске.

| # | Файл | Назначение |
|---|------|-----------|
| 1 | `lua/autorun/sh_grm_logistics_entities.lua` | Регистрация entity логистики: точка погрузки, склад фракции, оружейный шкаф, грузовой ящик |
| 2 | `lua/autorun/server/sv_grm_logistics.lua` | Сервер логистики: рейсы матовозок, ящики (2 пистолета + 5 автоматов), склады, шкафы, сохранение на карту |
| 3 | `lua/autorun/sh_grm_factory_fullcycle_config.lua` | Конфиг завода: рецепты GPU/компонентов/оружия ArcCW, переплавка брака, рынок, QTE |
| 4 | `lua/autorun/sh_grm_factory_fullcycle_entities.lua` | Регистрация entity завода: станки, мусорка, терминал, склад, скупщик, шкаф |
| 5 | `lua/autorun/server/sv_grm_factory_fullcycle.lua` | Сервер завода: крафт, QTE-сессии, лом, продажа GPU, скупщик/шкаф оружия, сохранение |
| 6 | `lua/autorun/sh_grm_inventory.lua` | Инвентарь: 24 слота, стаки, оружие/патроны/предметы, выброс `grm_item_drop`, JSON-персистентность |
| 7 | `lua/autorun/sh_grm_movement.lua` | Стамина: бег/прыжки, звук дыхания (CreateSound), HUD-полоса выносливости |
| 8 | `lua/autorun/sh_grm_chat_config.lua` | Конфиг чата: радиусы local/whisper/yell/LOOC, цвета, настройки контекстного меню |
| ~~9~~ | ~~`sh_grm_faction_economy_plus.lua`~~ | **УДАЛЁН** — заменён Кодом 43 |
| 10 | `lua/autorun/sh_factions.lua` | Ядро фракций: ранги, отделы, приглашения, `/fr`, единая бордово-тёмно-красная госволна `/dep` `/d`, OOC `/depb`, меню `/factions`; callback-формы ролей/отделов/создания/переименования очищают поля до `refreshAllUI` и проверяют `IsValid`, поэтому ответы сервера не вызывают `Tried to use a NULL Panel`. |
| 11 | `lua/autorun/sh_faction_fixes.lua` | Расширение фракций: комендантский час `/kom_hour`, модели+bodygroups, оружие по рангам, маскировка V2, `/gnews` |
| ~~12~~ | ~~`sh_grm_faction_economy.lua`~~ | **УДАЛЁН** — заменён Кодом 43 |
| 43 | `lua/autorun/sh_grm_economy.lua` | **Единая экономика v3.0.2 — ПЕРЕПИСАНО С НУЛЯ (+ «банк помнит» и «electro_balance по нику»):** бюджеты/налоги (только с ЗП!) фракций, зарплаты по ролям/отделам, штрафы `/fine`, история, импорт легаси-данных, админ-панель `/salary_admin` (обновляется без переоткрытия), банк-терминал; команды `!fbudget !fpay !fwithdraw !fpayall !fsettax /mysalary`; канал банка `GRM_Bank_Sync` в Double (без переполнения >4.29 млрд); автосохранение ≤8с, сверка с базой 15с + `/dbcheck`, страж-синглтон. **v3.0.2:** всё чтение JSON через jsonT(…, ignoreConversions=true) — голый util.JSONToTable калечил sid-ключи счетов (корень «на счету 0», находка 65); сверка по политике «память главнее» с мгновенным самолечением; банковские операции пишутся на диск СРАЗУ с печатью `SAVE ok: … [причина]`; загрузчик выбирает самый полный источник; рентген счетов при загрузке; зеркало счетов `grm_bank_nicks.json` по сиду/нику с полем `electro_balance` (счёт воскресает даже при вайпе treasury, записи без сида — по нику при входе); жёсткие рамки счёта [0..MaxBalance]; `GRM.GetElectroBalance` |
| 44–46 | `lua/entities/grm_bank_terminal/{shared,init,cl_init}.lua` | **Банкомат** (замена «недоделанного терминала», модель `models/starless/atm.mdl`): E → вкладки «Мой счёт» (личный банковский счёт для ВСЕХ игроков), «Перевод» (счёт→счёт), «Фракция» (бюджет/ЗП/история), 3D2D-табличка |
| 47 | `lua/autorun/sh_grm_tab_menu.lua` | Tab-меню v1.8 (scoreboard): список игроков с рангом/фракцией/балансом/пингом, поиск, сортировки, детальная панель (гаг/кик/бан/ULX-мут/спавн транспорта), личная заглушка голоса; команда `grm_tabmenu` |
| 48 | `lua/autorun/client/cl_grm_hud.lua` | **HUD v10.4:** HP/броня, наличка/счёт, патроны и подтверждаемый селектор оружия: колесо и 1–6 только перемещают подсветку, таймаут закрывает панель без смены; оружие выбирается исключительно ЛКМ. При удержании пропа физганом/гравиганом селектор полностью глушится. |
| 49 | `lua/autorun/client/cl_grm_inventory_ui.lua` | GUI инвентаря v2.1: сетка 6×4 со слотами, drag&drop перемещение, детальная панель предмета (использовать/выбросить/разделить), дефолтные иконки завода, учёт веса `GRM.Encumbrance` (если есть), защита переопределения `INV.OpenGUI` |
| 50 | `lua/autorun/sh_grm_perm_entities.lua` | **Пермы разворачиваемых энтити v1.6.0 (Код 50):** банкомат (`grm_bank_terminal`), вольт (`grm_bank_vault`), таксофон, АТС, терминал/прослушка, телефон теперь закрепляются на карте: прицел + `/permadd` `/permremove` `/permlist` в чат или `grm_perm_add/remove/list` в консоль (только суперадмин); переживают рестарт и cleanup (`InitPostEntity`/`PostCleanupMap`), заморожены; **`/permload` (`grm_perm_load`) — немедленная загрузка из базы без рестарта, с антидублем (не ставит второй энтити того же класса на занятое место)**; база-массив `data/grm_perm_entities.json` (без числовых ключей — урок находки 65), дедуп 6 юнитов, лимит 64/карту, карантин при битом файле; общий `GRM.Persistence` маршрутизирует Vendor/CCTV/RadioNet/Perm без двойных записей, `/perminfo` показывает backend |
| 51 | `lua/autorun/sh_grm_incassation.lua` + `lua/weapons/weapon_grm_incass_bag/shared.lua` | **Инкассация v2.0.0 (Код 126 / 51 — ПЕРЕПИСАНО С НУЛЯ):** старт рейса `/incass` в служебной машине фракции, сбор 5% накопительного фонда из банкоматов `grm_bank_terminal`, чемодан в руке `weapon_grm_incass_bag`, погрузка в багажник машины (до 250к), выгрузка у банка (гард радиуса 320 к вольту) и сдача в банковское хранилище `grm_bank_vault` (`HeldCash += N`, автообновление перм-записи); команды `/incass_off` `/incass_end` `/инкасс_стоп` `/сдать` |
| 52–54 | `lua/entities/grm_bank_vault/{shared,init,cl_init}.lua` | **Банковское хранилище** (`models/lt_c/sci_fi/ground_locker_small.mdl`): 3D2D-дисплей госбюджета и физических денег (`HeldCash` до 500к), E-меню загрузки/выгрузки, автообновление перма |
| 55–57 | `lua/entities/grm_vault_cash/{shared,init,cl_init}.lua` | **Паллета денег банка** (`models/props/cs_assault/moneypalleta.mdl`): 3D2D-подпись суммы, E — подобрать в кошелёк/сумку |
| 13 | `lua/autorun/sh_grm_admin_menu.lua` | Суперадмин-меню экономики v1.1: балансы, персональные налоги, переводы, журнал действий — `!grmmenu` |
| 14 | `lua/autorun/sh_grm_shop_integration.lua` | Интеграция магазина/дилера: сканер транспорта (GMod/SimFPhys/LVS/Glide), вкладка «Транспорт» в меню лидера, `/scanvehicles` `/vlist` |
| 15 | `lua/autorun/sh_spawn_points.lua` | Точки спавна фракций/глобальные (per-map JSON), админ-меню `/spawnmenu`, случайный спавн по точкам |
| 16 | `lua/autorun/sh_grm_vehicle_access.lua` | Доступ к транспорту: персональные покупки, доступ по фракции/рангу/отделу, магазин `/vshop`, админ цен `/vshop_admin` |
| 17 | `lua/autorun/vehicle_dealer.lua` | Патч дилера v3: проверка доступа перед спавном, фильтр списка, блок Q-меню, кулдаун 2с, лог спавнов |
| 18 | `lua/autorun/zz_grm_vehicle_antistuck.lua` | **Anti-Stuck v3:** после выхода ищет ближайшие точки у сиденья и граней машины; короткий ground trace не перескакивает на верхний этаж, hull-путь не проходит сквозь стены, дистанция ≤180, подъём ≤24. Непроверенный fallback и толчок удалены: если точки нет, остаётся временный NoCollide без телепорта на улицу. |
| 19 | `lua/autorun/sh_grm_phone_config.lua` | Конфиг телефонии: радиусы, номера 1000–9999, модели телефонов/АТС, звуки, доступ спецслужб |
| 20 | `lua/autorun/sh_grm_phone_access.lua` | Менеджер доступа к оборудованию связи (`/phone_access`), переопределяет `GRM.Phone.HasEquipmentAccess`, вкладка «Телефония» в админ-меню фракций |
| 21 | `lua/autorun/sh_grm_phone_shop.lua` | Магазин телефонии v2: каталог (телефон/таксофон/АТС/прослушка/терминал), покупка доступа, спавн, лимиты, `/phoneshop` |
| 22 | `lua/autorun/server/sv_grm_phone.lua` | Сервер телефонии: звонки, АТС-линии, прослушка (голос+текст), мониторинг, per-map сохранение, интеграция войса |
| 23 | `lua/autorun/client/cl_grm_phone.lua` | Клиент телефонии: UI телефона/АТС/прослушки/терминала связи |
| 24 | `lua/autorun/sh_grm_logistics_config.lua` | **Конфиг логистики** (закрывает жёсткую зависимость Кода 2): дистанции, ящики 2 пист. + 5 авт., награды, матовозка `simfphys_gta_sa_barracks` |
| 25–27 | `lua/entities/grm_payphone/{shared,init,cl_init}.lua` | Entity таксофона: NetworkVars линии, Use() → меню телефона, 3D2D-табличка |
| 28–30 | `lua/entities/grm_pbx_station/{shared,init,cl_init}.lua` | Entity АТС: ExchangeID/Active/MaxLines, Use() → меню АТС, табличка статуса |
| 31–33 | `lua/entities/grm_phone/{shared,init,cl_init}.lua` | Entity стационарного телефона: авто-номер при спавне, Use() → меню, табличка номера |
| 34–36 | `lua/entities/grm_phone_terminal/{shared,init,cl_init}.lua` | Entity терминала мониторинга связи: TerminalName, Use() → терминал |
| 37–39 | `lua/entities/grm_phone_wiretap/{shared,init,cl_init}.lua` | Entity прослушки: TargetNumber/ExchangeID/Active, Use() → меню прослушки, 3D2D-индикатор ON/OFF — **последний кусок телефонии** |
| 40 | `lua/autorun/client/cl_grm_faction_logistics.lua` | Клиент логистики: меню рейса/погрузки/ящика/склада/арсенала, админ-доступ, HUD-подписи и маршрут, анимация переноски ящика |
| 41 | `lua/autorun/client/cl_grm_factory_fullcycle.lua` | Клиент завода: крафт-меню (3D-превью оружия), склад, мусорка, терминал продажи GPU, скупщик/шкаф, QTE на стрелках, HUD прогресса |
| 42 | `lua/autorun/sh_grm_currency.lua` | **Ядро валюты v2.0.2 — ПЕРЕПИСАНО С НУЛЯ (чистый контур память→JSON→загрузка, детерминированный сериализатор, regex-спасение из битых файлов, всеядный загрузчик любых форматов кошелька, v2.0.2: всё чтение JSON через jsonT(…, ignoreConversions=true) — голый util.JSONToTable калечил ключи SteamID64, КОРНЕВАЯ причина всей саги потерь (находка 65); доказано юнит-тестом tools/luatest 12/12)** (сторож файла от чужих писателей + захват слотов + форензик-лог (v1.5.7)) (старый файл утерян): `GiveMoney/TakeMoney/HasMoney/GetBalance/SetBalance/Format/Notify` (+ опциональный `reason`), `GetAllBalances`, JSON-персистентность, офлайн-игроки, хуки `GRM_MoneyChanged`/`GRM_LocalMoneyChanged`, консоль `grm_money`, легаси-мост `grm_balance`/`grm_request_bal`/`grm_notify` + зеркало `GRM.PlayerBalance` для Tab/HUD; мгновенный пуш при вызове API по SteamID64-строке онлайн-игроку (v1.3, маркер `GRM._currencyReqBalRcv`) |
| 72a | `lua/autorun/sh_grm_character.lua` | **Меню персонажа v1.6.0:** единый singleton для меню персонажа и гардероба не допускает 2–3 одинаковых окна; live-refresh гардероба не заменяет его обычным меню. Нажатие на слот запрашивает серверный предпросмотр без переключения активного CharacterKey: имя, фракция, роль, отдел, duty и разрешённые модели берутся именно у выбранного `SteamID64:charN`. Карточки сразу показывают собственную фракцию каждого персонажа. Дубли моделей схлопываются, используется один выпадающий селектор; 3D-превью, скин/bodygroups сохранены. |
| 87 | `lua/autorun/sh_grm_documents.lua` | **Единая система документов GRM Documents & Identity Core v2.0.0 (+ лицензии на оружие и бизнес, госпошлины и теория-экзамен):** Паспорта, служебные удостоверения (ксивы), военные билеты, водительские удостоверения (Гражданские ГАИ и Военные ВАИ с категориями A–E+СПЕЦ и 6 войсковыми спецдопусками, сроки/баллы/приостановка), **лицензия на оружие** (категории гладкоствольное/нарезное/короткоствольное/травматическое/охотничье, `/weaponlicense` `/check_weapon`), **лицензия на ведение бизнеса** (вид деятельности, `/businesslicense` `/check_business`), **госпошлина** за выдачу (500/1500/3000, 80% в бюджет фракции + 20% в казну, через `GRM.Services.Charge`), **теория-экзамен на компьютере** (ПДД/оружие/бизнес, проходной 80%, без практики; сдача в `grm_doc_computer` и `grm_comp_traffic`), документы прикрытия для спецслужб, двухфазный интерактивный рендер (обложка ⇄ разворот), проверка прав при посадке в Т/С, C-меню, команды `/passport`, `/badge`, `/military`, `/license`, `/millicense`, `/medcard` + `/show*`, настраиваемое название государства и код страны в MRZ (без привязки к реальным странам) |
| 88 | `lua/entities/grm_doc_computer/` | **Служебный Компьютер оформления документов:** 6 вкладок («Паспортный стол», «Отдел кадров / Удостоверения», «Автошкола и ВАИ / Права», «Военкомат / Военный билет», «Документы прикрытия», «Реестр и архив»), 3D2D-интерфейс, поддержка в тулгане и пермах |
| 89 | `lua/autorun/sh_grm_medical.lua` + `lua/entities/grm_comp_medical/` | **Единая медицинская карта v2.0:** CharacterKey, кровь/ВВК, аллергии, журнал, физический бланк. Доступ к `grm_comp_medical` настраивается общей галочкой фракции в `/doc_admin → Права доступа к Компьютеру → Медицинский компьютер`; детальная матрица `/medcards` по ролям/отделам действует параллельно. |
| 90 | `lua/weapons/gmod_tool/stools/grm_service_tool.lua` | **STool «GRM Служебное оборудование»:** единый инструмент в категории GRM для расстановки и закрепления на карте (`data/grm_perm_entities.json`) специализированных служебных компьютеров ведомств |
| 91 | `lua/entities/grm_comp_police/` + `sv_grm_comp_terminal.lua` | **Компьютер OrdnungPolizei:** розыск, штрафы, паспортный стол, ксивы `POL-` и вкладка **«Лицензии на оружие»** — гражданин, категории, условия, срок, теория-экзамен и выдача через Documents Core с госпошлиной и физическим бланком. |
| 92 | `lua/entities/grm_comp_military_police/` | **Компьютер Feldgendarmerie v1.0.1:** Военный розыск дезертиров/СОЧ, взыскания комендатуры, реестр военных билетов, ксивы `FELD-`. Тот же trusted-путь и общий канал, что у полиции |
| 93 | `lua/entities/grm_comp_security/` + `sh_grm_special_service.lua` | **Спецслужбы / документы прикрытия:** до 5 легенд; при оформлении выбирается существующая фракция прикрытия либо ручное ведомство, ФИО/роль/отдел/номер, индивидуальный RGB обложки и gold/silver/bronze/white тиснение. Цвет хранится в легенде и применяется к её бланку независимо от шаблона фракции. |
| 94 | `lua/entities/grm_comp_military/` | **Компьютер Военкомата:** Выдача военных билетов, картотека призывников и мобрезерва (повестки), комиссия ВВК |
| 95 | `lua/entities/grm_comp_traffic/` | **Экзаменационный ПК Автоинспекции:** Дорожная Инспекция ПП (Права A–E+СПЕЦ), Военная Автоинспекция (ВАИ: права `A-В`–`СПЕЦ-В` и 6 спецдопусков) |
| 96 | `lua/entities/grm_comp_medical/` | **Медицинский Компьютер Госпиталя:** Электронные медкарты пациентов, категории годности, история приёмов врачей, справки |
| 97 | `lua/entities/grm_comp_fire/` | **Пожарная станция (диспетчерская):** исправлено E-открытие (`snapshot(ent, ply)`, раньше nil `self` обрывал net); singleton-окно и корректная отложенная раскладка кнопок; сводка живых очагов/vFire, дежурство, рукав, доступ/оповещение/машины/очаги/журнал. `/permadd` сохраняет класс и заголовок. Доступ: суперадмин, FightPro, Dispatch. |
| 98 | `lua/entities/grm_comp_cityhall/` | **Компьютер мэрии (городская администрация):** выдача/отзыв лицензий на ведение бизнеса (госпошлина + теория-экзамен через ядро документов), обзор городской казны (`GRM.Economy.StateBudgetGet`), каталога госуслуг и счетов (`GRM.Services`), реестр бизнес-лицензий |
| 99 | `lua/entities/grm_comp_court/` | **Компьютер юстиции (суд / прокуратура):** законы и статьи (каталог `GRM.Wanted`, гражданская юрисдикция), справочный список розыска, реестр штрафов — выписка судебного штрафа и аннулирование через `GRM.Wanted.Fines` (`F.Issue`/`F.Cancel`/`F.Page`). Доступ: суперадмин, фракция суда/прокуратуры (юстиц/суд/прокур…), либо `GRM.Wanted.CanEdit` |
| 100 | `lua/autorun/sh_grm_jobs.lua` + `sh_grm_jobs_config.lua` + `lua/entities/grm_jobcenter/` + `lua/entities/grm_depot/` | **Биржа труда v3.0.0 (Код 77):** курьер, мусоровоз и таксист; типизированные точки маршрутов (курьер/контейнер/свалка/посадка/назначение), проверка классов транспорта, меню таксиста `/taxi` с настраиваемой таксой, системные выплаты с резервом городской казны. `/jobs_admin` — точки, транспорт, диапазон таксы и финансирование. Заказы фракций сохраняют собственный эскроу бюджета. |
| 101 | `lua/autorun/sh_grm_911.lua` | **Система 911 v1.1.0:** летальный урон переводит игрока в физический ragdoll с таймером и крупной 3D2D-надписью «РАНЕН»; singleton-меню помощи без дублей, стабилизация и реанимация через E/`/aid`; вызовы `/911`, диспетчерский список `/911_calls` и маркеры; после смерти остаётся тело с причиной, оружием, нападавшим, следами повреждений и перенесённым инвентарём; E-обыск и изъятие предметов/физических документов (тип, номер, владелец); осмотр `/forensics`, опечатывание, доставка в морг и журнал `/911_cases`; единая медкарта получает записи, успешная реанимация субсидирует бюджет медслужбы из казны; `/911_admin`. |
| 102 | `lua/autorun/sh_grm_faction_duty.lua` + `lua/entities/grm_duty_npc/` + `stools/grm_duty_npc.lua` | **Служба фракций v1.0.0:** член фракции по умолчанию на службе и не может брать гражданские работы. У NPC «Служебный диспетчер» сотрудник завершает службу (гражданская модель/оружие, доступны курьер/такси/мусоровоз) или возвращается на службу (фракционная форма/вооружение). Статус хранится по CharacterKey; `/duty`; инструмент `GRM Служебный диспетчер`, обязательная отдельная привязка каждого NPC к одной фракции, админ-редактор по ПКМ, перм и крупная 3D2D-табличка с названием фракции. |
| 106 | `lua/autorun/sh_grm_faction_roster.lua` + `sh_factions.lua` | **Статусы фракций v1.1:** `/leaders` `/лидеры` доступны всем — фракции, лидеры, В СЕТИ/НЕ В СЕТИ. `/members` `/состав`: участник и лидер видят только собственную фракцию; суперадмин без аргумента получает аккуратно сгруппированные составы всех фракций, с аргументом — одну. Строки: роль, отдел, НА СЛУЖБЕ/ВНЕ СЛУЖБЫ/ВЫХОДНОЙ/НЕ В СЕТИ, координаты; заголовки содержат всего/онлайн/на службе. |
| 108 | `lua/autorun/sh_grm_sliding_door.lua` | **Раздвижные двери v1.1:** движение синхронно применяется к модели и замороженному PhysicsObject (`phys:SetPos` + `Entity:SetPos` + `CollisionRulesChanged`), поэтому физический collision box реально освобождает проезд для транспорта; возврат/перм/FFD сохраняются. |
| 107 | `cl_grm_customization.lua` | **Аксессуары UI/render v1.1:** гизмо масштабируется по расстоянию и габаритам модели, 64-сегментные кольца, центральный маркер; стабильный PostPlayerDraw + opaque fallback, FrameNumber-защита, очистка ClientsideModel при снятии/замене; сохранены серверные границы позиции/масштаба и снятие в Inventory. |
| 105 | `lua/autorun/sh_grm_vendor.lua` + `lua/entities/grm_vendor/` + `grm_vendor_tool` | **Торговцы v2.1:** оружейный торговец проверяет реестр лицензий по категориям `rifled/short/smooth`, показывает требуемую категорию и причину отказа; служебный товар — по фракции. Собственный per-map персист сохраняет тип/модель/название/ассортимент/цены/лимиты. `/permadd`, перм-тул и `/permremove` маршрутизируются в этот персист без двойной записи и дублей. |
| 104 | `lua/autorun/sh_grm_education.lua` | **Дипломы v2.0:** светлый государственный бланк с двойной золотой рамкой, тиснением, печатью, выделенными реквизитами и водяным знаком аннулирования; личный просмотр, выбор одного из нескольких дипломов, предъявление через C-меню и команды `/showdiploma [номер]` `/покдиплом [номер]`; отдельный rate-limit списка не блокирует немедленный показ. |
| 103 | `lua/autorun/sh_grm_physical_documents.lua` + `grm_item_drop` | **Физические документы v1.1.0:** паспорт, удостоверения, военник, права и лицензии — отдельные предметы. C-меню требует собственный бланк и для удостоверения предлагает выбор: официальное либо любая действующая легенда прикрытия (до 5), активная отмечена звездой; сервер проверяет индекс и статус. Инвентарь маркирует СВОЙ/ЧУЖОЙ, владельца и номер. |
| 96v5 | `lua/autorun/sh_grm_qmenu.lua` | **Большое безопасное Q-меню «Стройка» v5.1.0:** удержание Q; окно до 94%×92% экрана; только каталог пропов, без оружия/NPC/entity/транспорта для игроков; серверные spawn-гейты; безопасный набор строительных инструментов; три колонки «пропы / инструменты / параметры»; ручные схемы без чужого `BuildCPanel`; реальные ползунки/клавиши/материалы для верёвки, шкива, лебёдки, гидравлики, мышцы, оси, мотора, колеса, ускорителя, ховербола и шара; цветовая палитра `DColorMixer`; личные и серверные настройки; динамический выбор фракции для служебного диспетчера. |
| 58 | `lua/autorun/sh_grm_fire.lua` + `sh_grm_fire_access.lua` + `sh_grm_fire_truck.lua` + `sh_grm_fire_pump_ui.lua` + `sh_grm_fire_spots.lua` + `sh_grm_fire_status.lua` | **Пожары v1.4.1 / аддон 0.5.0 (Код 58):** учёт тушения — «Пожар локализован» / «Пожар потушен» (мягче 2.5с, peak≥1, оба при тушении), toast+ChatPrint SuperAdmin+Dispatch+FightPro+бойцы+рядом 1500, скан vfire на boot, журнал `data/grm_fire/log.json` + `/fire_log` `/журнал_пожаров` и кнопка «Журнал тушения», G без рейса ≠ инкассация. Рукава/насос |
| 59 | ~~`sh_grm_electronics.lua` + `grm_net_*` + `grm_network_tool`~~ | **УДАЛЕНО (находка 133):** компьютер со своей ОС (GRM NET OS), сетевые устройства (`grm_net_computer/router/printer/socket/plug`), сетевой принтер, фоторобот и свои форматы (GRMFACE/GRMML/GRMDB) снесены из сборки по требованию владельца — «сделаем проще». Ведомственные компьютеры (`grm_doc_computer`, `grm_comp_*`) остались |

## Зависимости, которых пока НЕТ в репозитории

Эти модули упоминаются в коде, но ещё не присланы (ожидаются следующими кусками):

- ~~Ядро валюты~~ — **ВОССТАНОВЛЕНО С НУЛЯ** (Код 42): `GRM.GiveMoney / TakeMoney / HasMoney / GetBalance / SetBalance / Format / Notify` + `GRM.StartBalance` + `GRM.LocalBalance`
- **Entity дилера** (`entities/sent_vehicle_dealer/…`) — `vehicle_dealer.lua` это патч поверх неё
- Радио-модуль с глобальной таблицей `RadioFrequencies` (для телефонной интеграции рации)
- `GRM.Encumbrance` — система веса/перегруза
- ~~GUI инвентаря: `GRM.Inventory.OpenGUI()`~~ — **ПОЛУЧЕНО** (Код 49). Осталась entity `grm_item_drop`
- `GRM.Chat` — основная реализация чата (здесь только конфиг); вероятно, она же даёт хук `PlayerSayTransform`
- ~~Шрифты `GRM_HUD_Label`..`GRM_SlotNameActive`~~ — **ПОЛУЧЕНЫ** с HUD v10.0 (Код 48)
- Внешние: ArcCW (оружие), simfphys/LVS (матовозки/транспорт), ULX/ULib (опционально)
- Ресурс `sound/kom_hour.wav` — положить в `addons/grm/sound/`

## Файлы данных (garrysmod/data)

`factions.json`, `invites.json`, `factions_extended.json`, `fw_faction_extras.json`,
`default_models.json`, `default_weapons.json`, `grm_inventories.json`,
`grm_economy.json` (+ legacy `grm_faction_budgets.json`, `grm_faction_economy_plus.json` — импортируются один раз), `gnews_log.txt`,
`grm_logistics/{access.json, inventory_crates.json, maps/<map>.json}`,
`grm_factory_fullcycle/{weapon_lockers.json, weapon_market.json, weapon_buyers.json, maps/<map>.json}`,
`grm_admin_log.json`, `grm_player_taxes.json`, `grm_currency.json`,
`spawn_points_global_<map>.json`, `spawn_points_factions_<map>.json`,
`grm_vehicle_purchases.json`, `grm_vehicle_prices.json`, `grm_faction_vehicle_access.json`, `vd_spawn_log.txt`,
`grm_phone/{access.json, shop_catalog.json, shop_purchases.json, player_equipment.json, <map>.json}`,
`grm_phone_records/<YYYY-MM-DD>.txt`

## Основные команды

**Игрок:** `/inv`, `/store`, `/fjoin`, `/fleave`, `/fr`, `/dep`, `/depb`, `/mask`,
`/model`, `/gnews`, `/kom_hour`, `/logistics_start`, `/logistics_crates`,
`!fbudget`, `!fpay`, `!fwithdraw`, `!fpayall`, `!fsettax`, `/mysalary`, `/fine <сумма> [причина]`, `/vlist`, `/myvehicles`,
`/vshop`, `/phoneshop` (`/teleshop`), `/phone_remove`

**Лидер фракции:** `/vaccess` (доступ транспорта для рангов/отделов)

**Админ:** `/factions`, `/door_access`, `/door`, `/warrant`, `/salary_admin`, `/logistics_admin`, `/models_admin`,
`/weapons_admin`, `/mask_admin`, `!grmmenu`/`!grmadmin`/`!econadmin`, `/scanvehicles`,
`/spawnmenu`, `/vshop_admin`, `/phoneshop_admin`, `/phone_access`,
`/phone_admin_remove`, консоль: `grm_logistics_place_*`, `grm_logistics_save/load`,
`grm_logistics_admin_menu`, `grm_logistics_crates`,
`grm_fc_save/load`, `grm_weapon_buyer_admin`, `grm_adminmenu`, `econadmin`, `grm_antistuck_vehicle`,
`grm_phone_save/load`, `grm_phone_remove_look`, `grm_phone_admin_remove`,
`grm_phone_shop_admin`, `grm_phone_shop_add_look`, `grm_phone_shop_reload`,
`grm_phone_access_reload`, `grm_phone_access_debug`,
`grm_money <give|take|set|info|list|save>`, `grm_balance`, `grm_economy <save|list>`

Подробный разбор архитектуры и замеченных проблем — в `ANALYSIS.md`.
