import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class calc_for_garminApp extends Application.AppBase {

    private var view as calc_for_garminView?;

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
    }

    // Return the initial view of your application here
    function getInitialView() as [Views] or [Views, InputDelegates] {
        var v = new calc_for_garminView();
        view = v;
        var ds = System.getDeviceSettings();
        if ((ds has :isGlanceModeEnabled) && ds.isGlanceModeEnabled) {
            // Opened from a glance - already a full app, Back and swipes are ours.
            return [ v, new calc_for_garminDelegate(v) ];
        }
        // No glances (e.g. vivoactive 4S): the initial view sits inside the
        // widget loop, where the system owns Back (exit to watch face) and
        // up/down swipes (next widget). Show an entry page there and push the
        // calculator as its own view, which does get Back and swipes.
        // CalcLaunchView auto-pushes it the first time it's shown, so this
        // doesn't cost an extra tap to get in - only Back-ing all the way
        // out (which pops the calculator back to this splash) leaves it
        // showing, at which point it behaves like a normal launcher tile
        // and a further Back or a tap/START does what you'd expect.
        return [ new CalcLaunchView(v), new CalcLaunchDelegate(v) ];
    }

    // Fires when the phone pushes a Settings change (e.g. a new SEED code
    // pasted into the "Theme & menu code" field) - re-parse it and repaint
    // without requiring an app restart.
    function onSettingsChanged() as Void {
        SeedConfig.reload();
        var v = view;
        if (v != null) {
            (v as calc_for_garminView).refreshTheme();
            (v as calc_for_garminView).refreshLayout();
            WatchUi.requestUpdate();
        }
    }

}

class CalcLaunchView extends WatchUi.View {

    private var calcView as calc_for_garminView;
    // Only auto-enter the very first time this is shown - if the user
    // backs all the way out of the calculator (popping it back to here),
    // showing again should behave like a normal launcher tile, not
    // immediately shove them back in.
    private var autoEntered as Boolean = false;

    function initialize(v as calc_for_garminView) {
        View.initialize();
        calcView = v;
    }

    function onShow() as Void {
        if (!autoEntered) {
            autoEntered = true;
            WatchUi.pushView(calcView, new calc_for_garminDelegate(calcView), WatchUi.SLIDE_IMMEDIATE);
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var icon = WatchUi.loadResource(Rez.Drawables.LauncherIcon) as WatchUi.BitmapResource;
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        dc.drawBitmap(cx - icon.getWidth() / 2, cy - icon.getHeight() - 4, icon);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + 4, Graphics.FONT_SMALL, WatchUi.loadResource(Rez.Strings.AppName) as String, Graphics.TEXT_JUSTIFY_CENTER);
    }
}

// Tap or START opens the calculator; Back/swipes stay with the widget loop.
class CalcLaunchDelegate extends WatchUi.BehaviorDelegate {

    private var calcView as calc_for_garminView;

    function initialize(v as calc_for_garminView) {
        BehaviorDelegate.initialize();
        calcView = v;
    }

    function onSelect() as Boolean {
        WatchUi.pushView(calcView, new calc_for_garminDelegate(calcView), WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}

function getApp() as calc_for_garminApp {
    return Application.getApp() as calc_for_garminApp;
}