import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class calc_for_garminApp extends Application.AppBase {

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
        var view = new calc_for_garminView();
        return [ view, new calc_for_garminDelegate(view) ];
    }

}

function getApp() as calc_for_garminApp {
    return Application.getApp() as calc_for_garminApp;
}