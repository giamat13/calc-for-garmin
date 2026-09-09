import Toybox.WatchUi;
import Toybox.Lang;

// Extends the low-level WatchUi.InputDelegate rather than BehaviorDelegate.
// On several touch+button devices, BehaviorDelegate silently converts any
// screen touch into a generic "select" behavior (activating whatever button
// is currently highlighted, ignoring where you actually tapped) before
// onTap ever runs - that's what made direct taps on numbers seem to do
// nothing. InputDelegate skips that translation, so onTap's own coordinate
// hit-test is what decides which button gets pressed. Physical buttons are
// handled directly via onKey() instead of BehaviorDelegate's onSelect/
// onBack/onNextPage/onPreviousPage.
class calc_for_garminDelegate extends WatchUi.InputDelegate {

    private var view as calc_for_garminView;

    function initialize(view as calc_for_garminView) {
        InputDelegate.initialize();
        me.view = view;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        var coords = clickEvent.getCoordinates();
        return handleTapAt(coords[0], coords[1]);
    }

    // Some devices report a quick press as a hold rather than a tap; handle
    // both the same way so a tap always registers.
    function onHold(clickEvent as WatchUi.ClickEvent) as Boolean {
        var coords = clickEvent.getCoordinates();
        return handleTapAt(coords[0], coords[1]);
    }

    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_ENTER || key == WatchUi.KEY_START) {
            return pressSelected();
        } else if (key == WatchUi.KEY_DOWN) {
            view.moveSelection(1);
            WatchUi.requestUpdate();
            return true;
        } else if (key == WatchUi.KEY_UP) {
            view.moveSelection(-1);
            WatchUi.requestUpdate();
            return true;
        } else if (key == WatchUi.KEY_ESC) {
            if (view.screen != view.SCREEN_BASIC) {
                view.switchScreen(view.screen - 1);
                WatchUi.requestUpdate();
                return true;
            }
            return false;
        }
        return false;
    }

    private function handleTapAt(x as Number, y as Number) as Boolean {
        var idx = view.buttonAt(x, y);
        if (idx == null) {
            return false;
        }
        var i = idx as Number;
        view.selectedIndex = i;
        view.activate(view.getButtons()[i]);
        WatchUi.requestUpdate();
        return true;
    }

    private function pressSelected() as Boolean {
        var buttons = view.getButtons();
        if (buttons.size() == 0) {
            return false;
        }
        view.activate(buttons[view.selectedIndex]);
        WatchUi.requestUpdate();
        return true;
    }

}
