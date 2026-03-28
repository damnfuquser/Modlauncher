import funkin.backend.MusicBeatTransition;
import flixel.FlxG;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.sound.FlxSound;
import funkin.backend.ModState;
import openfl.display.BitmapData;

final DIRECTION_KEY:String = "__modlauncher_transition_direction__";
final MODLAUNCHER_TRANSITION_SCRIPT:String = 'data/transitions/transition.hx';
final DEFAULT_TRANSITION_SCRIPT_KEY:String = "__modlauncher_default_transition_script__";
static var prevGameBitmap:BitmapData = null;
static var transitionDuration:Float = 0.5;

function useModlauncherTransition()
{
    if (Reflect.field(FlxG.save.data, DEFAULT_TRANSITION_SCRIPT_KEY) == null && MusicBeatTransition.script != MODLAUNCHER_TRANSITION_SCRIPT)
    {
        Reflect.setField(FlxG.save.data, DEFAULT_TRANSITION_SCRIPT_KEY, MusicBeatTransition.script);
    }
    MusicBeatTransition.script = MODLAUNCHER_TRANSITION_SCRIPT;
}

function restoreDefaultTransition()
{
    var defaultScript = Reflect.field(FlxG.save.data, DEFAULT_TRANSITION_SCRIPT_KEY);
    MusicBeatTransition.script = defaultScript == null ? "" : Std.string(defaultScript);
    Reflect.deleteField(FlxG.save.data, DEFAULT_TRANSITION_SCRIPT_KEY);
}

function update()
{
    if (FlxG.keys.justPressed.TAB)
    {
        useModlauncherTransition();
        Reflect.setField(FlxG.save.data, DIRECTION_KEY, -1);
        var currentMusic = FlxG.sound.music;
        if (currentMusic != null)
        {
            trace('[Modlauncher] global TAB -> set direction=-1, switch to Modlauncher');
            currentMusic.volume = 1;
            currentMusic.pitch = 1;
            FlxTween.tween(currentMusic, {volume: 0, pitch: 0}, 2, {ease: FlxEase.circOut});
            new FlxTimer().start(0.5, function(timer:FlxTimer) {FlxG.sound.music.pause();});
            new FlxTimer().start(0.5, function(timer:FlxTimer) {FlxG.switchState(new ModState("Modlauncher"));});
        }
    }
}

function destroy()
{
    prevGameBitmap = null;
}