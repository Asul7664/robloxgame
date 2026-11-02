# Наша модель Сахура — замена в игре

Игровая версия созданного нами `OriginalSahur.blend`: один skinned mesh,
15 983 треугольника, 25 костей + 2 служебных маркера, запечённая текстура
2048×2048. Меши/текстуры прежнего импортированного Сахура не используются.
Полный скульпт сохранён отдельно без изменений.

1. Заберите ветку `codex/quiet-cove-download`, синхронизируйте Rojo, остановите Play.
2. В Studio через **3D Importer / Import 3D** импортируйте `OriginalSahur.fbx`
   из этой папки в Workspace. Сохраните скелет, skinning и текстуру. Если
   текстура не подхватилась, выберите соседний `OriginalSahur_Color.png`.
3. В Explorer выделите только новую модель целиком. В Command Bar вне Play:

   ```lua
   require(game.ServerScriptService.QuietCove.SahurStudioInstall).OriginalSelected()
   ```

4. Сохраните место и запустите новый Play. Для немедленной проверки
   переключите Command Bar на **Server**:

   ```lua
   local ok, reason = game.ServerStorage.StudioSahur:Invoke(game.Players:GetPlayers()[1])
   assert(ok, reason)
   ```

Установщик проверяет скелет до замены, нормализует высоту до 12 studs и
подключает `ServerStorage.SahurBoss` и модель улова
`ReplicatedStorage.QuietCove.CreatureAssets.sahur`. Прежние шаблоны и исходный
импорт сохраняются в `ServerStorage.QCSahurBackups`; лишняя статичная копия
не остаётся в Workspace. Установку уже установленного шаблона повторять не нужно.

Появление из воды, единственный прыжок, HP, погоня и награда остаются в
существующем SahurService. Новый `SahurOriginalRig` анимирует кости, отдельно
сгибает локоть/кисть и рассчитывает удар по маркерам нашей дубинки.
ID анимаций не требуются. Старый тип скелета поддерживается для отката.

## Проверки и ограничения

`lune run tests/sahur_original.luau` проверяет Bone-преобразования и общую
для клиента/сервера траекторию. `verify_game.py` проверяет настоящий обратный
импорт FBX в Blender, веса, иерархию и текстуру. Предпросмотр — рендер игровой
геометрии с запечённым атласом, не снимок Roblox Studio.

Загрузка меша в Roblox требует вашего Studio/аккаунта: Rojo сам не загружает
FBX и не выдаёт asset ID. До установки в вашем месте остаётся прежний босс.
Физика, вид текстуры и качество движений в реальном Studio пока не проверены;
анимацию нужно доводить после такого просмотра.

Пересборка из корня репозитория:

```sh
blender -b -t 6 --python-exit-code 1 --python tools/sahur_original/export_game.py
blender -b -t 6 --python-exit-code 1 --python tools/sahur_original/verify_game.py
```
