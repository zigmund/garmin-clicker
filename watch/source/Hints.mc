import Toybox.Lang;
import Toybox.Math;

// Geometry and content of the button hints on the main screen. Angles are degrees
// counter-clockwise from 3 o'clock (the Dc.drawArc convention); the positions match the
// five-button Garmin layout (fenix / Forerunner / epix …): Start upper right, Back lower right,
// Up on the left, Down lower left.
module Hints {
    enum {
        ICON_NONE,
        ICON_NEXT,
        ICON_PREVIOUS,
        ICON_PLAY,
        ICON_PAUSE,
        ICON_RESET
    }

    function angle(button as Number) as Number {
        if (button == ButtonMap.BUTTON_START) {
            return 30;
        } else if (button == ButtonMap.BUTTON_BACK) {
            return 330;
        } else if (button == ButtonMap.BUTTON_DOWN) {
            return 210;
        }
        return 180; // BUTTON_UP
    }

    // Point at distance r from the screen centre in direction angleDeg.
    function point(w as Number, h as Number, angleDeg as Number, r as Float) as [Float, Float] {
        var a = Math.toRadians(angleDeg);
        return [w / 2.0 + r * Math.cos(a), h / 2.0 - r * Math.sin(a)];
    }

    // Icon for the action mapped to a button. Reset shows only while paused (it does nothing
    // while the timer runs); the start/pause toggle shows what pressing it will do.
    function icon(action as Number, running as Boolean) as Number {
        if (action == ButtonMap.ACTION_NEXT) {
            return ICON_NEXT;
        } else if (action == ButtonMap.ACTION_PREVIOUS) {
            return ICON_PREVIOUS;
        } else if (action == ButtonMap.ACTION_TIMER_TOGGLE) {
            return running ? ICON_PAUSE : ICON_PLAY;
        } else if (action == ButtonMap.ACTION_TIMER_RESET && !running) {
            return ICON_RESET;
        }
        return ICON_NONE;
    }
}
