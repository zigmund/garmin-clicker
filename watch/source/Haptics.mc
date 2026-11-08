import Toybox.Attention;
import Toybox.Lang;

module Haptics {
    function play(profile as Array<Attention.VibeProfile>) as Void {
        if (Attention has :vibrate) {
            Attention.vibrate(profile);
        }
    }

    function success() as Void {
        play([new Attention.VibeProfile(50, 60)]);
    }

    function error() as Void {
        play([
            new Attention.VibeProfile(80, 120),
            new Attention.VibeProfile(0, 100),
            new Attention.VibeProfile(80, 120)
        ]);
    }
}
