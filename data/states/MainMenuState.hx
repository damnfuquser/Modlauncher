import flixel.FlxG;
import flixel.FlxSprite;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import openfl.display.BitmapData;
import funkin.backend.MusicBeatTransition;

final DIRECTION_KEY:String = "__modlauncher_transition_direction__";
final DEFAULT_TRANSITION_SCRIPT_KEY:String = "__modlauncher_default_transition_script__";
var exitTransitionSprite:FlxSprite = null;
var exitTransitionTween:FlxTween = null;

function create() {
    FlxG.sound.music.resume();    
    startReturnTransitionIfNeeded();
}

function startReturnTransitionIfNeeded() {
    if (getTransitionDirection() <= 0 || prevGameBitmap == null) {
        clearTransitionDirection();
        clearPrevGameBitmap();
        restoreDefaultTransition();
        return;
    }

    trace('[MainMenuState] start return transition');

    var currentMusic = FlxG.sound.music;
    
    if (currentMusic != null) {
        if (!currentMusic.active) currentMusic.play();
        currentMusic.volume = 0;
        currentMusic.pitch = 0;

        var volTween = {value:0.0};
        FlxTween.tween(volTween, {value:1.0}, 2, {
            ease: FlxEase.circOut,
            onUpdate: function(tween) {
                currentMusic.volume = volTween.value;
                currentMusic.pitch = volTween.value;
            }
        });
    }

    exitTransitionSprite = buildTransitionScreenshot(prevGameBitmap);
    add(exitTransitionSprite);

    exitTransitionTween = FlxTween.tween(exitTransitionSprite, {y: FlxG.height}, transitionDuration, {
        ease: FlxEase.circInOut,
        onComplete: function(_) {
            trace('[MainMenuState] return transition complete');
            if (exitTransitionSprite != null) {
                remove(exitTransitionSprite, true);
                exitTransitionSprite.destroy();
                exitTransitionSprite = null;
            }
            exitTransitionTween = null;
            clearPrevGameBitmap();
            clearTransitionDirection();
            restoreDefaultTransition();
        }
    });
}

function buildTransitionScreenshot(bitmap:BitmapData):FlxSprite {
    var sprite = new FlxSprite();
    sprite.pixels = bitmap;
    sprite.scrollFactor.set();

    var game = FlxG.game;
    var screenWidth = game.x * 2 + game.width;
    var aspectChange = bitmap.width * screenWidth;
    var edgeX = game.x / aspectChange;
    var edgeY = game.y / aspectChange;

    if (sprite.frame != null) {
        sprite.frame.frame = sprite.frame.frame.set(
            edgeX,
            edgeY,
            bitmap.width - edgeX * 2,
            bitmap.height - edgeY * 2
        );
        var frameCopy = sprite.frame;
        sprite.frame = null;
        sprite.frame = frameCopy;
    }

    sprite.setGraphicSize(FlxG.width, FlxG.height);
    sprite.updateHitbox();
    sprite.screenCenter();
    return sprite;
}

function getTransitionDirection():Int {
    var value = Reflect.field(FlxG.save.data, DIRECTION_KEY);
    return value == null ? 0 : Std.int(value);
}

function clearTransitionDirection() {
    Reflect.deleteField(FlxG.save.data, DIRECTION_KEY);
}

function clearPrevGameBitmap() {
    if (prevGameBitmap != null) {
        prevGameBitmap.dispose();
        prevGameBitmap = null;
    }
}

function restoreDefaultTransition() {
    var defaultScript = Reflect.field(FlxG.save.data, DEFAULT_TRANSITION_SCRIPT_KEY);
    MusicBeatTransition.script = defaultScript == null ? "" : Std.string(defaultScript);
    Reflect.deleteField(FlxG.save.data, DEFAULT_TRANSITION_SCRIPT_KEY);
}

function destroy() {
    if (exitTransitionTween != null) {
        exitTransitionTween.cancel();
        exitTransitionTween = null;
    }
    if (exitTransitionSprite != null) {
        remove(exitTransitionSprite, true);
        exitTransitionSprite.destroy();
        exitTransitionSprite = null;
    }
}