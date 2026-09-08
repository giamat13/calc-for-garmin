import Toybox.WatchUi;
import Toybox.Lang;

// Multi-input support:
// - Physical buttons: up/down to navigate, select to activate, back to exit scientific
// - Touch with buttons: tap to activate, up/down/select for navigation
// - Touch only (no buttons): swipe up/down to navigate, tap to activate
class calc_for_garminDelegate extends WatchUi.BehaviorDelegate {

    private var view as calc_for_garminView;

    function initialize(view as calc_for_garminView) {
        BehaviorDelegate.initialize();
        me.view = view;
    }

    function onSelect() as Boolean {
        var buttons = view.getButtons();
        if (buttons.size() == 0) {
            return false;
        }
        view.activate(buttons[view.selectedIndex]);
        WatchUi.requestUpdate();
        return true;
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

    // Swipe navigation for touch-only watches: swipe down = next, swipe up = previous.
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

}
