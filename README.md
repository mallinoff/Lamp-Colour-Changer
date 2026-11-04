# Lamp Colour Changer

A Factorio 2.1 mod with a shortcut colour picker and a drag selection tool. Space Age is not required.

The colour preview uses a live, always-on lamp in Factorio's native checkerboard entity preview. Changing sliders or favourites updates its colour. Preview lamps live on a separate internal surface and are removed when the picker closes.

## Install

Copy `lamp-colour-changer_1.1.0.zip` into `%APPDATA%\Factorio\mods`, then start Factorio and enable **Lamp Colour Changer**. Alternatively, copy the entire `lamp-colour-changer_1.1.0` folder into that directory. Install only one copy.

## Use

1. Click the lamp icon in the shortcut bar, or press **Ctrl+Shift+L**. If the icon is hidden, enable it in the shortcut bar's overflow menu.
2. Drag the red/green/blue sliders, or enter RGB values from 0 to 255. Sliders and number fields stay in sync, with a live colour preview.
3. Optionally click **Add current colour to favourites** below the preview. Saved colours appear underneath with a swatch, editable name, and **Select** and **Delete** buttons. Edit a name to save it automatically; blank names keep the previous saved name. **Select** loads that favourite into the picker; favourites are personal to each player and persist in the game save.
4. Set **Always on** beside the RGB sliders: checked applies daytime lighting, unchecked restores normal day/night operation. This setting is remembered per player. Lamps still require power, and circuit on/off conditions remain active. Click **Select lamps**.
5. Hold the left mouse button and drag over an area. Release to apply the colour to lamps belonging to your force.
6. Select more areas with the same tool, or reopen the picker to change colour. Press **Q** to put the tool away.

Each player's chosen colour is saved with the game. Changing colour disables circuit-controlled lamp colours so the chosen colour can show. Wiring and circuit on/off conditions are preserved. Lamps still need power and must be on to show their light. Built lamps and lamp ghosts are supported; ghost settings carry over when constructed. Shift-drag also applies the selected settings.

## Additional controls

- **Gradient** is optional and starts unchecked. The RGB picker is the start colour. Tick **Gradient** to show an end hex colour and direction selector. **Use current** copies the picker colour to the end field, so you can choose the end using sliders first, capture it, then choose the start colour. Blending runs between the outermost selected lamps/ghosts, left to right or top to bottom. A selection with no span in that direction uses the start colour. Gradient only applies when **Change colour** is enabled.
- Favourite **↑ / ↓** buttons move a colour up or down in your saved list.
- Each area selection prints a summary with total lamp and ghost counts, solid/gradient/unchanged colour, and the always-on setting applied. An empty selection preserves your previous undo step. Undo can restore ghosts while they still exist; once a ghost has been built, its old undo reference is skipped.

- **Undo** keeps the last 20 nonempty selections per player, saved with the game. Click repeatedly to step backwards through previous colours, circuit colour modes, and always-on values for settings each operation changed. The button shows the remaining step count. Existing single-step history is preserved on upgrade. Removed lamps and lamps now belonging to another force are skipped. Undo restores recorded values even if another player has since edited that lamp.
- **Eyedropper** equips a sampling tool. Click a lamp or drag over exactly one friendly lamp to reopen the picker with its colour. Circuit-controlled lamps use their currently reported light colour when available, otherwise their manually configured colour. Sampling leaves application toggles and favourites unchanged.
- **Change colour** and **Change always-on** independently control which properties a selection changes. Both start enabled to preserve the previous behaviour. Clear either checkbox to preserve that property on selected lamps.
- **Hex colour** accepts six hexadecimal digits with or without `#`, such as `#00FFFF`. It stays in sync with RGB sliders, number fields, favourites, and the preview. Incomplete hex values cannot be applied or saved as favourites.

## Checks

Lua syntax and mocked prototype/runtime checks can be run with `luac -p` and `lua tests/smoke.lua`. The smoke test checks prototype registration, lamp filtering, RGB application, and player-state cleanup. In-game GUI and lighting validation still requires Factorio.

In-game checklist: load an existing save, open the shortcut, test presets and custom RGB, paint a mixed area of lamps and other machines, test wired lamps, save/reload, and test two players choosing different colours.


