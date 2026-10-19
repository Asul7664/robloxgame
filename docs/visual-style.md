# Яркая тропическая графика Quiet Cove

Палитра, вода, освещение, NPC и интерфейс связаны через
`src/shared/VisualTheme.luau`. Стиль вдохновлён выбранным направлением Fisch /
Steal An Egg: ясные силуэты, чистые насыщенные поверхности, мягкий дневной свет.
Это собственный пресет проекта, а не заявленные внутренние настройки этих игр.

| Элемент | Цвет |
| --- | --- |
| Трава | `#64CC58` |
| Листва | `#2CA568` |
| Море | `#2486C7` |
| Бирюзовые акценты | `#43CDE0` |
| Песок | `#FFE2A1` |
| Дерево | `#B77846` |
| Награды | `#FFCA58` |
| Редкие эффекты | `#B083FF` |

Бухта зелёная с бирюзовыми лавками, риф с розовыми кораллами, Мшистый остров
изумрудный, Пески Сахура золотистые, Лагуна Капуччино розовая, Штормовые скалы
сине-фиолетовые. Крупные поверхности оставлены спокойными, яркий Neon используется
на маяках и кристаллах. Terrain.WaterColor общий для всего океана.

## Как увидеть изменения

Заберите ветку `codex/quiet-cove-download`, синхронизируйте Rojo и перезапустите
Play. Сохранённая карта обновляется на месте; новые острова получают то же оформление.
Смена дня и ночи и ночной улов сохраняются; день начинается в 13:00.

Для просмотра всей палитры и декора **в редакторе вне Play** выполните в Command Bar:

```lua
require(game.ServerScriptService.QuietCove.WorldVisuals).ApplyAll()
```

Команда оформляет уже существующую карту. Если карта ещё не создана:

```lua
local s = game.ServerScriptService.QuietCove; require(s.Archipelago).Attach(require(s.World).Build())
```

Сам пресет Lighting синхронизируется через Rojo сразу, без Play. Если перед этим
запускали ApplyAll, после очередного редактирования модулей Studio может держать
старый результат require: для гарантированного обновления перезапустите сеанс Studio.

## Настройка и повторная сборка

В `VisualTheme` доступны `Lighting.Brightness`, `Effects.QCColor.Properties.Saturation`,
цвета `Palette`, `Biomes`, `UI` и параметры `Water`. После изменения палитры
пересоберите сохраняемые ассеты из корня репозитория:

```sh
lune run tools/build_visual_theme.luau
lune run tools/build_weapon_stall.luau
```

При изменении цветов нового декора увеличьте `VisualTheme.Version`: существующая
папка декора будет пересобрана. `WorldScenery` добавляет 381 статическую деталь
на текущие шесть островов. У деталей отключены коллизии, touch и raycast; нет
постоянных циклов обновления или новых текстур. Старые плоские листья скрываются,
их прежние прозрачность/query/touch сохраняются в атрибутах `QCOriginal…`.

`WorldVisuals` меняет только известные поверхности нашей карты и NPC. Размеры,
позиции и коллизии игровых поверхностей остаются прежними. Сторонняя модель Сахура,
персонажи и вложенные пользовательские модели не перекрашиваются. Старый Atmosphere
перемещается в `Lighting.QCPreviousAtmosphere`; активен один новый Atmosphere.
Чужие ColorCorrection/Bloom не удаляются: при ручных дополнительных фильтрах
проверьте, что они не усиливают насыщенность поверх пресета.

## Проверка

```sh
lune run tests/visual_theme.luau
lune run tests/island_balance.luau
rojo build default.project.json -o /tmp/quiet-cove-tropical.rbxlx
```

Автоматические проверки защищают геометрию, игровые ссылки, отсутствие дубликатов,
настройки эффектов и безопасность лучей. Окончательный свет, тени, дальность видимости
и FPS нужно оценить в Studio на низком и высоком качестве графики: облачная среда
не запускает Roblox Studio. Предпросмотр Blender показывает реальную геометрию
модулей с приблизительным освещением, не является скриншотом Roblox.

## Основа решений

Официальные рекомендации Roblox, изученные в creator-docs (`70a0110`, 17.10.2026):

- [LightingStyle: Soft — стилизованное освещение](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/Lighting.yaml)
- [Читаемые силуэты и единые правила ассетов](https://create.roblox.com/docs/tutorials/curriculums/environmental-art/develop-polished-assets)
- [Цветовые темы для навигации по миру](https://create.roblox.com/docs/tutorials/curriculums/environmental-art/construct-your-world)
- [Согласованные небо, атмосфера и наружное освещение](https://create.roblox.com/docs/tutorials/lighting/enhance-outdoor-environments)
- [Оптимизация и проверка на устройствах](https://create.roblox.com/docs/tutorials/curriculums/environmental-art/optimize-your-experience)
