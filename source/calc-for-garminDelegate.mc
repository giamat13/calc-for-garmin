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
    // both the same way by default so a tap always registers. The one
    // exception is the counter's "-1" button: long-pressing it subtracts a
    // whole bulk step instead of 1 (touch-only, like onSwipe below -
    // physical buttons have no hold/duration info via onKey, so there's no
    // equivalent gesture to wire up for them).
    function onHold(clickEvent as WatchUi.ClickEvent) as Boolean {
        var coords = clickEvent.getCoordinates();
        var idx = view.buttonAt(coords[0], coords[1]);
        if (idx != null && view.getButtons()[idx as Number].action.equals("counterDec")) {
            view.selectedIndex = idx as Number;
            view.activate(new CalcButton("-1", "counterDecMulti"));
            WatchUi.requestUpdate();
            return true;
        }
        return handleTapAt(coords[0], coords[1]);
    }

    // Touch-only: a swipe moves the cursor exactly like the "<"/">"
    // buttons (curLeft/curRight). No isTouchScreen check needed - a
    // button-only device has no touchscreen to swipe on, so onSwipe
    // simply never fires there.
    function onSwipe(swipeEvent as WatchUi.SwipeEvent) as Boolean {
        var dir = swipeEvent.getDirection();
        var onListScreen = view.isListScreen();
        if (onListScreen && dir == WatchUi.SWIPE_UP) {
            view.scrollList(1);
        } else if (onListScreen && dir == WatchUi.SWIPE_DOWN) {
            view.scrollList(-1);
        } else if (dir == WatchUi.SWIPE_LEFT) {
            view.engine.moveCursorLeft();
        } else if (dir == WatchUi.SWIPE_RIGHT) {
            view.engine.moveCursorRight();
        } else if (dir == WatchUi.SWIPE_UP) {
            view.switchScreen(view.SCREEN_HISTORY);
        } else {
            return false;
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_ENTER || key == WatchUi.KEY_START) {
            return pressSelected();
        } else if (key == WatchUi.KEY_DOWN) {
            if (view.isListScreen()) {
                view.scrollList(1);
            } else {
                view.moveSelection(1);
            }
            WatchUi.requestUpdate();
            return true;
        } else if (key == WatchUi.KEY_UP) {
            if (view.isListScreen()) {
                view.scrollList(-1);
            } else {
                view.moveSelection(-1);
            }
            WatchUi.requestUpdate();
            return true;
        } else if (key == WatchUi.KEY_ESC) {
            return goBack();
        }
        return false;
    }

    // Where BACK goes from each screen, indexed by view.SCREEN_* id (see
    // the list at the top of calc-for-garminView.mc). A table rather than
    // an if/else chain to stay under older watches' 64KB widget limit.
    // BASE/COUNTER (19/21) and the currency autocomplete screens (5/6) are
    // handled separately below; their slots here are unused.
    private const BACK_TARGET = [0, 10, 1, 10, 3, 4, 5, 10, 10, 10, 0, 10, 14, 14, 1, 10, 0, 16, 14, 14, 3, 14, 10, 22, 22, 24] as Array<Number>;

    // Steps `view.screen` back one logical screen. Returns false only from
    // SCREEN_BASIC, letting the platform's default Back (pop/exit) proceed.
    private function goBack() as Boolean {
        var s = view.screen;
        if (s == view.SCREEN_BASIC) {
            return false;
        } else if (s == view.SCREEN_CUR_RESULTS) {
            view.goToScreen(view.SCREEN_CUR_LETTER);
        } else if (s == view.SCREEN_CUR_LETTER) {
            view.goToScreen(view.SCREEN_UNIT_PICK);
        } else if (s == view.SCREEN_BASE) {
            // BASE's own BACK is stage-aware (cancels out of radix entry
            // first, then exits to MORE) - reuse that instead of duplicating it.
            view.activate(new CalcButton("BACK", "baseBack"));
        } else if (s == view.SCREEN_COUNTER) {
            // COUNTER's own BACK is stage-aware (cancels out of "+N" entry
            // first, then exits to MORE) - reuse that instead of duplicating it.
            view.activate(new CalcButton("BACK", "counterBack"));
        } else {
            view.switchScreen(s < BACK_TARGET.size() ? BACK_TARGET[s] : s - 1);
        }
        WatchUi.requestUpdate();
        return true;
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
