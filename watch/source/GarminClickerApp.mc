import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class GarminClickerApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [new EmptyView()];
    }
}

class EmptyView extends WatchUi.View {
    function initialize() {
        View.initialize();
    }
}
