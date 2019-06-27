stdlib = {}
stdlib.area = require('__stdlib__/stdlib/area/area')
stdlib.color = require('__stdlib__/stdlib/utils/color')
stdlib.event = require('__stdlib__/stdlib/event/event')
stdlib.gui = require('__stdlib__/stdlib/event/gui')
stdlib.math = require('__stdlib__/stdlib/utils/math')
stdlib.logger = require('__stdlib__/stdlib/misc/logger').new('Tapeline_Debug', true)
stdlib.position = require('__stdlib__/stdlib/area/position')
stdlib.string = require('__stdlib__/stdlib/utils/string')
stdlib.table = require('__stdlib__/stdlib/utils/table')
stdlib.tile = require('__stdlib__/stdlib/area/tile')

require('scripts/gui')
require('scripts/player')
require('scripts/rendering')
require('scripts/tilegrid')

mod_gui = require('mod-gui')