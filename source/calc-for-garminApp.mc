import Toybox.Application;
import Toybox.Lang;
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
        return [ v, new calc_for_garminDelegate(v) ];
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

function getApp() as calc_for_garminApp {
    return Application.getApp() as calc_for_garminApp;
}