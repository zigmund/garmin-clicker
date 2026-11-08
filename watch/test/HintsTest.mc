import Toybox.Lang;
import Toybox.Test;

(:test)
function hintIconsFollowMappingAndTimer(logger as Logger) as Boolean {
    Test.assertEqual(Hints.icon(ButtonMap.ACTION_NEXT, false), Hints.ICON_NEXT);
    Test.assertEqual(Hints.icon(ButtonMap.ACTION_PREVIOUS, true), Hints.ICON_PREVIOUS);
    Test.assertEqual(Hints.icon(ButtonMap.ACTION_TIMER_TOGGLE, false), Hints.ICON_PLAY);
    Test.assertEqual(Hints.icon(ButtonMap.ACTION_TIMER_TOGGLE, true), Hints.ICON_PAUSE);
    Test.assertEqual(Hints.icon(ButtonMap.ACTION_TIMER_RESET, false), Hints.ICON_RESET);
    Test.assertEqual(Hints.icon(ButtonMap.ACTION_TIMER_RESET, true), Hints.ICON_NONE);
    Test.assertEqual(Hints.icon(ButtonMap.ACTION_NONE, false), Hints.ICON_NONE);
    return true;
}

(:test)
function hintPointsSitNextToButtons(logger as Logger) as Boolean {
    var up = Hints.point(260, 260, Hints.angle(ButtonMap.BUTTON_UP), 100.0);
    Test.assert((up[0] - 30.0).abs() < 0.01 && (up[1] - 130.0).abs() < 0.01);
    var start = Hints.point(260, 260, Hints.angle(ButtonMap.BUTTON_START), 100.0);
    Test.assert(start[0] > 130.0 && start[1] < 130.0); // upper right
    var back = Hints.point(260, 260, Hints.angle(ButtonMap.BUTTON_BACK), 100.0);
    Test.assert(back[0] > 130.0 && back[1] > 130.0); // lower right
    var down = Hints.point(260, 260, Hints.angle(ButtonMap.BUTTON_DOWN), 100.0);
    Test.assert(down[0] < 130.0 && down[1] > 130.0); // lower left
    return true;
}

(:test)
function flashLightsOnlyTheLastCommandBriefly(logger as Logger) as Boolean {
    Flash.pressed(ButtonMap.ACTION_NEXT, 1000);
    Test.assertEqual(Flash.stateFor(ButtonMap.ACTION_NEXT, 1100), Flash.PENDING);
    Test.assert(Flash.stateFor(ButtonMap.ACTION_PREVIOUS, 1100) == null);
    Flash.done(false, 1200);
    Test.assertEqual(Flash.stateFor(ButtonMap.ACTION_NEXT, 1600), Flash.FAILED);
    Test.assert(Flash.stateFor(ButtonMap.ACTION_NEXT, 1200 + Flash.FLASH_MS + 1) == null);
    Test.assert(!Flash.active(1200 + Flash.FLASH_MS + 1));
    Flash.action = null;
    return true;
}
