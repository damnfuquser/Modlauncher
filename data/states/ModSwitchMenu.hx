import flixel.FlxG;
import flixel.FlxSprite;
import funkin.backend.ModState;
import funkin.backend.MusicBeatState;
import openfl.display.BitmapData;

var redirectCover:FlxSprite = null;
var redirectQueued:Bool = false;

function postCreate()
{
    if (prevGameBitmap != null)
    {
        redirectCover = buildTransitionScreenshot(prevGameBitmap);
        insert(members.length, redirectCover);
    }

    for (member in members)
    {
        if (member != redirectCover && member != null)
        {
            member.visible = false;
        }
    }

    redirectQueued = true;
}

function update()
{
    if (!redirectQueued) return;
    redirectQueued = false;
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

    sprite.setGraphicSize(FlxG.width * 2, FlxG.height * 2);
    sprite.updateHitbox();
    sprite.screenCenter();
    return sprite;
}