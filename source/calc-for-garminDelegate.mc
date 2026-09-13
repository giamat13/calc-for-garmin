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
    // both the same way so a tap always registers. (A long-press gesture
    // isn't used for anything here: physical buttons have no equivalent -
    // onKey fires once per press with no hold/duration info - so inserting
    // "=" is a plain button (EQ, on the scientific screen)
    // instead, which works identically for touch and physical navigation.)
    function onHold(clickEvent as WatchUi.ClickEvent) as Boolean {
        var coords = clickEvent.getCoordinates();
        return handleTapAt(coords[0], coords[1]);
    }

    // Touch-only: a swipe moves the cursor exactly like the "<"/">"
    // buttons (curLeft/curRight). No isTouchScreen check needed - a
    // button-only device has no touchscreen to swipe on, so onSwipe
    // simply never fires there.
    function onSwipe(swipeEvent as WatchUi.SwipeEvent) as Boolean {
        var dir = swipeEvent.getDirection();
        var onListScreen = view.screen == view.SCREEN_HISTORY || view.screen == view.SCREEN_HISTORY_DETAIL;
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
            if (view.screen == view.SCREEN_HISTORY || view.screen == view.SCREEN_HISTORY_DETAIL) {
                view.scrollList(1);
            } else {
                view.moveSelection(1);
            }
            WatchUi.requestUpdate();
            return true;
        } else if (key == WatchUi.KEY_UP) {
            if (view.screen == view.SCREEN_HISTORY || view.screen == view.SCREEN_HISTORY_DETAIL) {
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

    // Steps `view.screen` back one logical screen. Returns false only from
    // SCREEN_BASIC, letting the platform's default Back (pop/exit) proceed.
    private function goBack() as Boolean {
        if (view.screen == view.SCREEN_CUR_RESULTS) {
            view.goToScreen(view.SCREEN_CUR_LETTER);
        } else if (view.screen == view.SCREEN_CUR_LETTER) {
            view.goToScreen(view.SCREEN_UNIT_PICK);
        } else if (view.screen == view.SCREEN_UNIT_PICK) {
            view.switchScreen(view.SCREEN_UNITS);
        } else if (view.screen == view.SCREEN_RANDOM || view.screen == view.SCREEN_TIP) {
            view.switchScreen(view.SCREEN_MENU);
        } else if (view.screen == view.SCREEN_PCT || view.screen == view.SCREEN_DATE) {
            view.switchScreen(view.SCREEN_MORE);
        } else if (view.screen == view.SCREEN_MORE) {
            view.switchScreen(view.SCREEN_SCIENTIFIC);
        } else if (view.screen == view.SCREEN_UNITS) {
            view.switchScreen(view.SCREEN_MENU);
        } else if (view.screen == view.SCREEN_VAR) {
            view.switchScreen(view.SCREEN_MENU);
        } else if (view.screen == view.SCREEN_NAV) {
            // Falls into the generic screen-1 fallback below otherwise,
            // landing on SCREEN_MORE (14) - but NAV is only ever entered
            // from MENU (see the "nav" action in activate()).
            view.switchScreen(view.SCREEN_MENU);
        } else if (view.screen == view.SCREEN_HISTORY) {
            view.switchScreen(view.SCREEN_BASIC);
        } else if (view.screen == view.SCREEN_HISTORY_DETAIL) {
            view.switchScreen(view.SCREEN_HISTORY);
        } else if (view.screen == view.SCREEN_BASE) {
            // BASE's own BACK is stage-aware (cancels out of radix entry
            // first, then exits to MORE) - reuse that instead of duplicating it.
            view.activate(new CalcButton("BACK", "baseBack"));
        } else if (view.screen == view.SCREEN_GRAPH || view.screen == view.SCREEN_COLOR) {
            view.switchScreen(view.SCREEN_MORE);
        } else if (view.screen == view.SCREEN_SCIENTIFIC) {
            view.switchScreen(view.SCREEN_MENU);
        } else if (view.screen == view.SCREEN_MENU) {
            view.switchScreen(view.SCREEN_BASIC);
        } else if (view.screen != view.SCREEN_BASIC) {
            view.switchScreen(view.screen - 1);
        } else {
            return false;
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
