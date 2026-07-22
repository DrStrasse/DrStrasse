# Анализ модулей GRM RP-сборки

**Дата:** 20.07.2026  
**Ветка:** arena/019f71e9-drstrasse  
**Всего файлов:** 281 Lua (без EasyChat)  
**Строк кода:** ~66,000

---

##  Структура проекта

### По категориям:
- **autorun:** 96 файлов (64 shared + 16 client + 16 server)
- **entities:** 119 файлов (40 entities × 3 файла)
- **weapons:** 16 файлов (SWEP + toolgun)

### Ключевые системы (11 блоков):

| Система | Файлов | Строк | Статус |
|---|---|---|---|
|  Экономика/Финансы | 8 | ~5,500 | ✅ Стабильно |
| 📞 Телефония | 12 | ~4,800 | ✅ Стабильно |
|  Торговля | 6 | ~3,200 | ⚠️ Мелкие баги |
| 🚗 Транспорт | 8 | ~4,100 | ✅ Стабильно |
| 📦 Логистика | 6 | ~3,500 | ✅ Стабильно |
|  Безопасность | 15 | ~6,000 | ✅ Стабильно |
| 👥 Фракции | 3 | ~7,000 | ✅ Стабильно |
| 🎭 RP | 10 | ~5,500 | ⚠️ continue/goto |
| 🎒 Инвентарь | 8 | ~4,200 | ✅ Стабильно |
| 📡 Радио/Связь | 9 | ~4,500 | ⚠️ continue/goto |
|  Дополнения | 11 | ~5,000 | ⚠️ continue/goto |

---

## 🐛 Найденные проблемы

### 1. СИНТАКСИС: `continue` и `goto` (9 файлов)

**Проблема:** Используется `continue` и `goto` (LuaJIT), но парсер проверяет на ванильном Lua.

**Файлы:**
1. `cl_grm_handcuffs.lua:231` — continue в hook
2. `sv_grm_food.lua:519` — continue в timer
3. `sh_faction_fixes.lua:597` — continue в цикле
4. `sh_grm_character.lua:224` — continue
5. `sh_grm_jobs.lua:1107` — goto
6. `sh_grm_rpdesc.lua:319` — continue в hook
7. `zz_grm_vehicle_antistuck.lua:441` — continue в timer
8. `grm_ore_buyer/cl_init.lua:22` — continue в hook
9. `sent_vehicle_dealer/init.lua:1263` — goto

**Решение:** Заменить `continue` на if-оборачивание (находка 125).

---

### 2. ДУБЛИРОВАНИЕ КОДА

**jsonT функция** — определяется в каждом модуле отдельно:
- `sh_grm_currency.lua`
- `sh_grm_economy.lua`
- `sh_grm_inventory.lua`
- `sh_grm_mobile.lua`
- `sh_grm_medical.lua`
- `sh_grm_perm_entities.lua`
- `sh_grm_phone_shop.lua`
- `sv_grm_cctv.lua`
- `sv_grm_logistics.lua`
- `sv_grm_roomtap.lua`

**Решение:** Вынести в общий модуль `sh_grm_json.lua`.

---

### 3. НЕИСПОЛЬЗУЕМЫЙ КОД

**sh_grm_shop_integration.lua** — интеграция магазина транспорта, но дилер теперь отдельный модуль.

**vehicle_dealer.lua** — старый патч дилера, дублируется sent_vehicle_dealer.

---

### 4. ЗАВИСИМОСТИ МЕЖДУ МОДУЛЯМИ

```
sh_factions.lua (ядро)
  ↓
sh_grm_economy.lua (бюджеты, ЗП)
sh_grm_doors.lua (доступ по фракциям)
sh_grm_wanted.lua (розыск)
sh_grm_board.lua (доска набора)
sh_grm_jobs.lua (биржа труда)

sh_grm_currency.lua (валюта)
  ↓
sh_grm_economy.lua (банк)
sh_grm_vendor.lua (торговля)
grm_money_drop (дроп денег)
grm_money_printer (принтер)

sh_grm_inventory.lua (инвентарь)
  ↓
sh_grm_encumbrance (вес)
sh_grm_food_kitchen (еда)
sh_grm_mobile.lua (телефоны)
sh_grm_medical.lua (медкарты)
```

---

### 5. СЕТЬ: NET-КАНАЛЫ

**Всего зарегистрировано:** ~80 net-каналов

**Потенциальные конфликты:**
- `GRM_Bank_Sync` используется в economy и hud
- `Factions_SyncAll` может быть тяжёлым при большом онлайне
- `GRM_CCTV_View` — нет лимита на количество зрителей

---

### 6. ПРОИЗВОДИТЕЛЬНОСТЬ

**Таймеры:**
- `GRM_StaminaTick` — 0.1с (10 раз/сек)
- `GRM_Economy_SalaryTick` — 10с
- `GRM_Economy_Reconcile` — 15с
- `GRM_CCTV_ViewGuard` — каждый кадр (Think)
- `GRM_Mob_NavTick` — каждый кадр

**Хуки Think:**
- CCTV ViewGuard — проверка всех игроков каждый кадр
- Mobile NavTick — навигация телефона

**Рекомендация:** Увеличить интервалы где возможно.

---

### 7. БЕЗОПАСНОСТЬ

**Проверки прав:**
- ✅ Большинство команд проверяют `IsSuperAdmin()`
- ✅ Net-обработчики валидируют данные
- ⚠️ Некоторые команды используют только `IsAdmin()` (слабее)

**SQL:** Отключён (находка 46) — всё на JSON.

---

### 8. ПЕРСИСТЕНТНОСТЬ

**Файлы данных:**
```
data/
── grm_wallet.json (валюта)
├── grm_treasury.json (экономика)
├── grm_bank_nicks.json (зеркало банка)
├── factions.json (фракции)
├── grm_inventories.json (инвентари)
├── grm_cctv/<map>.json (камеры)
├── grm_logistics/maps/<map>.json (логистика)
├── grm_phone/ (телефония)
├── grm_roomtap/ (прослушка)
└── grm_perm_entities.json (перманенты)
```

**Защиты:**
- ✅ Антисвайп (пустая память не затирает файл)
- ✅ Read-back проверка после записи
- ✅ Бэкапы (_backup.json)
- ✅ Карантин битых файлов

---

##  ПРИОРИТЕТЫ ИСПРАВЛЕНИЙ

### Высокий приоритет:
1. **continue/goto** → if-оборачивание (9 файлов)
2. **jsonT** → вынести в общий модуль
3. **CCTV ViewGuard** → оптимизировать (не каждый кадр)

### Средний приоритет:
4. **sh_grm_shop_integration** — удалить или интегрировать
5. **vehicle_dealer.lua** — удалить (дубль)
6. **Таймеры** — увеличить интервалы где возможно

### Низкий приоритет:
7. **Документация** — добавить комментарии к API
8. **Тесты** — добавить unit-тесты для критичных модулей

---

## 📈 СТАТИСТИКА КОДА

**Самые большие модули:**
1. `sh_faction_fixes.lua` — 2,880 строк
2. `sh_factions.lua` — 2,436 строк
3. `sh_grm_economy.lua` — 2,352 строк
4. `sh_grm_mobile.lua` — 1,943 строк
5. `sh_grm_radionet.lua` — 1,652 строк

**Средний размер файла:** ~300 строк  
**Медиана:** ~200 строк

---

## 🔍 РЕКОМЕНДАЦИИ

1. **Рефакторинг:** Вынести jsonT, notify, vecToTable в утилиты
2. **Оптимизация:** Уменьшить частоту Think-хуков
3. **Безопасность:** Унифицировать проверки прав
4. **Тестирование:** Добавить сим-тесты для экономики/инвентаря
5. **Документация:** Swagger-like API docs для хуков

---

**Заключение:** Проект стабильный, 222/231 файл проходит синтаксис. Основные проблемы — continue/goto (критично для ванильного Lua) и дублирование jsonT.
