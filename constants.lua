-- constants

local constants = {}

constants.modName = 'Tapeline'
constants.modAssetName = '__' .. constants.modName .. '__'

constants.tapelineItemName = 'tapeline-tool'
constants.tapelineShortcutName = 'tapeline-shortcut'

-- file paths
constants.itemAssetPath = constants.modAssetName .. '/graphics/icons/item/'
constants.shortcutAssetPath = constants.modAssetName .. '/graphics/icons/shortcut-bar/'
constants.scriptAssetPath = constants.modAssetName .. '/graphics/icons/script/'

constants.stdlib = '__stdlib__/stdlib/'

constants.isDebugMode = true

-- colors
constants.colors = {}
constants.colors.tilegrid_div = {}

constants.colors.tilegrid_div[1] = {r=0.3,g=0.3,b=0.7,a=0.5}
constants.colors.tilegrid_div[5] = {r=0.3,g=0.8,b=0.3,a=0.5}
constants.colors.tilegrid_div[25] = {r=0.9,g=0.3,b=0.3,a=0.5}
constants.colors.tilegrid_div[100] = {r=0.8,g=0.8,b=0.3,a=0.5}
constants.colors.tilegrid_border = {r=0.7,g=0.7,b=0.7,a=0.5}
constants.colors.tilegrid_label = {r=0.7,g=0.7,b=0.7,a=0.8}

-- positioning / graphics
constants.tilegrid_width = 1.4

return constants