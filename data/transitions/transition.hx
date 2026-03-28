import openfl.display.BitmapData;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import funkin.backend.MusicBeatTransition;

final DIRECTION_KEY:String = "__modlauncher_transition_direction__";
final DEFAULT_TRANSITION_SCRIPT_KEY:String = "__modlauncher_default_transition_script__";
final TRANSITION_TIME:Float = 0.5;

static var prevGameBitmap:BitmapData = null;

var prevStateSprite:FlxSprite = null;
var activeTween:FlxTween = null;
var defaultPersistentUpdate:Bool = true;
var defaultPersistentDraw:Bool = false;

function create(event)
{
    var direction = getTransitionDirection();

    if (!shouldUseModlauncherTransition(event))
    {
        return;
    }

    defaultPersistentUpdate = FlxG.state.persistentUpdate;
    defaultPersistentDraw = FlxG.state.persistentDraw;
    FlxG.state.persistentUpdate = false;
    FlxG.state.persistentDraw = true;

    event.cancel();
    transitionTween?.cancel();
    blackSpr?.destroy();
    transitionSprite?.destroy();

    if (event.transOut)
    {
        prevGameBitmap = BitmapData.fromImage(FlxG.stage.window.readPixels());
        restoreStatePersistence();
        finish();
        return;
    }

    if (prevGameBitmap == null)
    {
        clearTransitionDirection();
        restoreStatePersistence();
        restoreDefaultTransition();
        finish();
        return;
    }

    if (direction < 0)
    {
        restoreStatePersistence();
        finish();
        return;
    }

    prevStateSprite = buildScreenshotSprite(prevGameBitmap);
    prevStateSprite.cameras = [transitionCamera];
    add(prevStateSprite);

    activeTween = FlxTween.tween(prevStateSprite, {y: getTargetY()}, TRANSITION_TIME, {
        ease: FlxEase.circInOut,
        onComplete: function(_)
        {
            clearPrevGameBitmap();
            clearTransitionDirection();
            restoreStatePersistence();
            restoreDefaultTransition();
            finish();
        }
    });
}

function shouldUseModlauncherTransition(event):Bool
{
    if (event.transOut)
    {
        return getTransitionDirection() != 0;
    }
    return getTransitionDirection() != 0 && prevGameBitmap != null;
}

function buildScreenshotSprite(bitmap:BitmapData):FlxSprite
{
    var sprite = new FlxSprite();
    sprite.pixels = bitmap;
    sprite.scrollFactor.set();

    var game = FlxG.game;
    var screenWidth = game.x * 2 + game.width;
    var aspectChange = bitmap.width * screenWidth;
    var edgeX = game.x / aspectChange;
    var edgeY = game.y / aspectChange;

    if (sprite.frame != null)
    {
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

function getTargetY():Float
{
    return getTransitionDirection() * FlxG.height;
}

function clearPrevGameBitmap()
{
    if (prevGameBitmap != null)
    {
        prevGameBitmap.dispose();
        prevGameBitmap = null;
    }
}

function getTransitionDirection():Int
{
    var value = Reflect.field(FlxG.save.data, DIRECTION_KEY);
    return value == null ? 0 : Std.int(value);
}

function clearTransitionDirection()
{
    Reflect.deleteField(FlxG.save.data, DIRECTION_KEY);
}

function restoreStatePersistence()
{
    FlxG.state.persistentUpdate = defaultPersistentUpdate;
    FlxG.state.persistentDraw = defaultPersistentDraw;
}

function restoreDefaultTransition()
{
    var defaultScript = Reflect.field(FlxG.save.data, DEFAULT_TRANSITION_SCRIPT_KEY);
    MusicBeatTransition.script = defaultScript == null ? "" : Std.string(defaultScript);
    Reflect.deleteField(FlxG.save.data, DEFAULT_TRANSITION_SCRIPT_KEY);
}

function destroy()
{
    if (activeTween != null)
    {
        activeTween.cancel();
        activeTween = null;
    }
    if (prevStateSprite != null)
    {
        FlxTween.cancelTweensOf(prevStateSprite);
        prevStateSprite.destroy();
        prevStateSprite = null;
    }
    restoreStatePersistence();
}