import Toybox.WatchUi;
import Toybox.Lang;

// Swipe to move the highlight between buttons, tap anywhere to confirm the
// highlighted one - this avoids depending on precise touch-coordinate
// hit-testing (which doesn't reliably line up with drawn button positions
// on every device), and mirrors physical-button navigation (up/down to
// move the highlight, select to press) so button watches work the same way.
class calc_for_garminDelegate extends WatchUi.BehaviorDelegate {

    private var view as calc_for_garminView;

    function initialize(view as calc_for_garminView) {
        BehaviorDelegate.initialize();
        me.view = view;
    }

    function onSelect() as Boolean {
        return pressSelected();
    }

    function onNextPage() as Boolean {
        view.moveSelection(1);
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() as Boolean {
        view.moveSelection(-1);
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() as Boolean {
        if (view.scientific) {
            view.switchScreen(false);
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }

    // A tap anywhere on the screen confirms the currently highlighted
    // button - swipe up/down first to move the highlight onto it.
    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        return pressSelected();
    }

    function onHold(clickEvent as WatchUi.ClickEvent) as Boolean {
        return pressSelected();
    }

    function onSwipe(swipeEvent as WatchUi.SwipeEvent) as Boolean {
        var dir = swipeEvent.getDirection();
        if (dir == WatchUi.SWIPE_DOWN) {
            view.moveSelection(1);
            WatchUi.requestUpdate();
            return true;
        } else if (dir == WatchUi.SWIPE_UP) {
            view.moveSelection(-1);
            WatchUi.requestUpdate();
            return true;
        }
        return false;
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
