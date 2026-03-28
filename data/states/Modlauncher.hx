import funkin.backend.assets.ModsFolder;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.text.FlxText.FlxTextAlign;
import flixel.addons.display.FlxBackdrop;
import funkin.backend.paths.Paths;
import flixel.sound.FlxSound;
import flixel.math.FlxRect;
import flixel.util.FlxTimer;
import sys.FileSystem;
import sys.io.File;
import haxe.Json;
import openfl.display.BitmapData;
import openfl.media.Sound;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.graphics.frames.FlxAtlasFrames;
import funkin.backend.MusicBeatTransition;
import hscript.Parser;
import hscript.Interp;

final DIRECTION_KEY:String = "__modlauncher_transition_direction__";
final MODLAUNCHER_TRANSITION_SCRIPT:String = 'data/transitions/transition.hx';
final DEFAULT_TRANSITION_SCRIPT_KEY:String = "__modlauncher_default_transition_script__";
final ADDON_DIRECTORY:String = "addons/Modlauncher-dev";
var mods:Array<String>;
var selection:Int = 0;
var menuMusic:FlxSound;
var entryTransitionBg:FlxSprite = null;
var entryTransitionCover:FlxSprite = null;
var entryTransitionTween:FlxTween = null;
var enteringFromState:Bool = false;
var entryGridWasVisible:Bool = true;
var exitingToMainMenu:Bool = false;

var bgImage:FlxSprite;
var bgmain:FlxSprite;
var grid:FlxBackdrop;
var middleBar:FlxSprite;
var modBgOverlay:FlxSprite;
var modBgAnim:FlxSprite;
var modBgIntroAnim:FlxSprite;
var instructionsText:FlxText;
var modlauncherText:FlxText;
var modNameText:FlxText;
var modIcon:FlxSprite;
var modBgShadow:FlxSprite;
var shine:FlxSprite;
var shader:CustomShader;

var acceptingInput:Bool = true;
var introDelay:Float = 0.3;
var hasIcon:Bool = true;
var playingIntro:Bool = false;
var canSwitchToMod:Bool = true;
var enterSound:FlxSound;
var currentIntroScript:Dynamic = null;

var originalIconScaleX:Float = 1;
var originalIconScaleY:Float = 1;
var safetyTimer:FlxTimer = null;

function create() {
    FlxG.camera.bgColor = FlxColor.BLACK;
    mods = ModsFolder.getModsList();
    mods.push(null);

    bgmain = new FlxSprite(0, 0);
    bgmain.makeGraphic(FlxG.width, FlxG.height + 100, FlxColor.WHITE);
    add(bgmain);

    bgImage = new FlxSprite(0, 0).loadGraphic(Paths.image("bg"));
    bgImage.setGraphicSize(FlxG.width, FlxG.height + 100);
    bgImage.updateHitbox();
    bgImage.alpha = 0.4;
    add(bgImage);

    grid = new FlxBackdrop(Paths.image("grid"));
    grid.scale.set(1.5, 1.5);
    grid.velocity.set(0, -15);
    grid.alpha = 0.1;
    add(grid);

    middleBar = new FlxSprite(-150, FlxG.height / 5 - 25);
    middleBar.makeGraphic(FlxG.width + 1000, 450, FlxColor.WHITE);
    add(middleBar);

    modBgOverlay = new FlxSprite(middleBar.x, middleBar.y);
    add(modBgOverlay);

    modBgAnim = new FlxSprite();
    modBgAnim.visible = false;
    add(modBgAnim);

    modBgIntroAnim = new FlxSprite();
    modBgIntroAnim.visible = false;
    add(modBgIntroAnim);

    modBgShadow = new FlxSprite().makeGraphic(1, 1, FlxColor.GRAY);
    modBgShadow.alpha = 0.1;
    add(modBgShadow);

    modIcon = new FlxSprite();
    modIcon.screenCenter();
    add(modIcon);

    shine = new FlxSprite();
    shine.loadGraphic(Paths.image("shine"));
    shine.scale(1, 0.5);
    shine.visible = false;
    add(shine);

    modlauncherText = new FlxText(470, 0, FlxG.width, "modlauncher");
    modlauncherText.setFormat(Paths.font("badpiggiesglowing.ttf"), 60, FlxColor.BLACK, FlxTextAlign.CENTER);
    add(modlauncherText);

    modNameText = new FlxText(0, FlxG.height * 0.825, FlxG.width, "");
    modNameText.setFormat(Paths.font("jetbrains.ttf"), 27, FlxColor.BLACK, FlxTextAlign.CENTER);
    add(modNameText);

    instructionsText = new FlxText(0, modNameText.y + 80, FlxG.width, "LEFT / RIGHT to navigation  |  ENTER to select  |  ~ for mod info  |  ESC to exit");
    instructionsText.setFormat(Paths.font("badpiggiesglowing.ttf"), 18, FlxColor.BLACK, FlxTextAlign.CENTER);
    add(instructionsText);

    menuMusic = new FlxSound();
    menuMusic.loadEmbedded(Paths.music("mlmusic"), true, true);
    menuMusic.persist = true;
    menuMusic.volume = 0;
    menuMusic.pitch = 0.5;
    menuMusic.play();
    FlxG.sound.list.add(menuMusic);
    FlxTween.tween(menuMusic, {volume: 0.7, pitch: 1}, transitionDuration, {ease: FlxEase.circOut});

    updateSelection();
    startEntryTransitionIfNeeded();
}

function update(elapsed:Float) {
    if (enteringFromState && entryTransitionBg != null) {
        entryTransitionBg.y = FlxG.camera.scroll.y;
        updateEntryTransitionCover();
    }

    if (enteringFromState || exitingToMainMenu) {
        return;
    }

    if (playingIntro && currentIntroScript != null) {
        try {
            callIntroScriptFunction(["update", "ONUPDATE"], [elapsed], true);
        } catch (e:Dynamic) {
            cancelIntro();
            return;
        }
    }

    if (FlxG.keys.justPressed.ESCAPE || controls.BACK) {
        if (playingIntro) {
            cancelIntro();
        }
        else if (!playingIntro && !exitingToMainMenu) {
            startExitToMainMenu();
        }
        return;
    }

    if (!acceptingInput) return;

    if (controls.RIGHT_P || FlxG.keys.justPressed.RIGHT)
        changeSelectionAnimated(1);

    if (controls.LEFT_P || FlxG.keys.justPressed.LEFT)
        changeSelectionAnimated(-1);

    if (controls.ACCEPT || FlxG.keys.justPressed.ENTER) {
        acceptingInput = false;
        playEnterSound(mods[selection]);
        playSelectAnimation(mods[selection]);
    }
}

function setIntroScriptGlobals(interp:Interp, path:String, ?modName:String) {
    var overlayBounds = getIntroOverlayBounds();
    var parentBridge = {
        modName: modName,
        state: this,
        overlayBounds: overlayBounds,
        introDuration: getIntroDuration(0),
        add: function(object:Dynamic) {
            return add(object);
        },
        insert: function(position:Int, object:Dynamic) {
            return insert(position, object);
        },
        insertBehindOverlay: function(object:Dynamic) {
            return insertBehindOverlay(object);
        },
        remove: function(object:Dynamic, splice:Bool) {
            return remove(object, splice);
        },
        finishIntro: function(name:String) {
            return finishIntro(name);
        },
        cancelIntro: function() {
            return cancelIntro();
        },
        fadeMenuBackgroundsForOutro: function() {
            return fadeMenuBackgroundsForOutro();
        },
        resolveAddonFile: function(relativePath:String) {
            return resolveAddonFile(relativePath);
        },
        getIntroDuration: function(minDuration:Float = 0) {
            return getIntroDuration(minDuration);
        }
    };

    interp.variables.set("parent", parentBridge);
    interp.variables.set("modName", modName);
    interp.variables.set("scriptPath", path);
    interp.variables.set("finishIntro", function(name:String) {
        return finishIntro(name);
    });
    interp.variables.set("cancelIntro", function() {
        return cancelIntro();
    });
    interp.variables.set("FlxG", FlxG);
    interp.variables.set("FlxSprite", FlxSprite);
    interp.variables.set("FlxColor", FlxColor);
    interp.variables.set("FlxTween", FlxTween);
    interp.variables.set("FlxEase", FlxEase);
    interp.variables.set("FlxTimer", FlxTimer);
    interp.variables.set("Paths", Paths);
    interp.variables.set("FileSystem", FileSystem);
    interp.variables.set("File", File);
    interp.variables.set("BitmapData", BitmapData);
    interp.variables.set("Sound", Sound);
    interp.variables.set("sys", {
        FileSystem: FileSystem,
        io: {
            File: File
        }
    });
    interp.variables.set("openfl", {
        display: {
            BitmapData: BitmapData
        },
        media: {
            Sound: Sound
        }
    });
    interp.variables.set("StringTools", StringTools);
    interp.variables.set("Math", Math);
    interp.variables.set("Std", Std);
    interp.variables.set("Reflect", Reflect);
}

function createIntroScript(path:String, ?modName:String):Dynamic {
    if (!FileSystem.exists(path)) return null;

    var parser = new Parser();
    parser.allowJSON = true;
    parser.allowMetadata = true;
    parser.allowTypes = true;

    var interp = new Interp();
    setIntroScriptGlobals(interp, path, modName);

    var scriptContent = File.getContent(path);
    var expr = parser.parseString(scriptContent, path);

    interp.execute(expr);

    return {
        path: path,
        parser: parser,
        interp: interp,
        expr: expr
    };
}

function hasIntroScriptFunction(name:String):Bool {
    if (currentIntroScript == null || currentIntroScript.interp == null) return false;

    var value = currentIntroScript.interp.variables.get(name);
    return value != null && Reflect.isFunction(value);
}

function callIntroScriptFunction(names:Array<String>, ?parameters:Array<Dynamic>, rethrowErrors:Bool = false):Bool {
    if (currentIntroScript == null || currentIntroScript.interp == null) return false;

    if (parameters == null) {
        parameters = [];
    }

    for (name in names) {
        var func = currentIntroScript.interp.variables.get(name);
        if (func != null && Reflect.isFunction(func)) {
            try {
                Reflect.callMethod(null, func, parameters);
                return true;
            } catch (e:Dynamic) {
                trace('[Modlauncher] intro script call failed (' + currentIntroScript.path + ' -> ' + name + '): ' + e);
                if (rethrowErrors) {
                    throw e;
                }
                return false;
            }
        }
    }

    return false;
}

function loadIntroScript(path:String, ?modName:String) {
    if (!FileSystem.exists(path)) return null;

    try {
        var script = createIntroScript(path, modName);
        trace('[Modlauncher] loaded intro script: ' + path);
        return script;
    } catch(e:Dynamic) {
        trace('[Modlauncher] intro script error (' + path + '): ' + e);
        return null;
    }
}

function getIntroOverlayBounds():Dynamic {
    var width = modBgOverlay != null ? modBgOverlay.width : 0;
    var height = modBgOverlay != null ? modBgOverlay.height : 0;
    var x = modBgOverlay != null ? modBgOverlay.x : 0;
    var y = modBgOverlay != null ? modBgOverlay.y : 0;

    if (width <= 0 || height <= 0) {
        width = FlxG.width;
        height = FlxG.height;
        x = 0;
        y = 0;
    }

    return {
        x: x,
        y: y,
        width: width,
        height: height,
        centerX: x + width * 0.5,
        centerY: y + height * 0.5
    };
}

function getIntroDuration(minDuration:Float = 0):Float {
    var duration = Math.max(minDuration, introDelay);

    if (enterSound != null && enterSound.length > 0) {
        duration = Math.max(duration, enterSound.length / 1000);
    }

    return duration;
}

function insertBehindOverlay(object:Dynamic) {
    var overlayIndex = modBgOverlay != null ? members.indexOf(modBgOverlay) : -1;
    if (overlayIndex < 0) {
        add(object);
        return object;
    }

    insert(overlayIndex, object);
    return object;
}

function resolveAddonFile(relativePath:String):String {
    var normalized = StringTools.replace(relativePath, "\\", "/");
    if (StringTools.startsWith(normalized, "/")) {
        normalized = normalized.substr(1);
    }

    var candidates = [
        ADDON_DIRECTORY + "/" + normalized,
        "./" + ADDON_DIRECTORY + "/" + normalized,
        normalized
    ];

    for (candidate in candidates) {
        if (FileSystem.exists(candidate)) {
            return candidate;
        }
    }

    return candidates[0];
}

function startEntryTransitionIfNeeded() {
    if (getTransitionDirection() >= 0) {
        clearTransitionDirection();
        clearPrevGameBitmap();
        restoreDefaultTransition();
        return;
    }

    if (prevGameBitmap == null) {
        finishEntryTransition();
        clearTransitionDirection();
        restoreDefaultTransition();
        return;
    }

    enteringFromState = true;
    acceptingInput = false;
    entryGridWasVisible = grid.visible;
    grid.visible = false;

    entryTransitionBg = buildTransitionScreenshot(prevGameBitmap);
    entryTransitionBg.scrollFactor.set(1, 1);
    insert(0, entryTransitionBg);

    entryTransitionCover = buildTransitionScreenshot(prevGameBitmap);
    entryTransitionCover.scrollFactor.set(1, 1);
    insert(members.indexOf(grid) + 1, entryTransitionCover);

    FlxG.camera.scroll.set(0, -FlxG.height);
    entryTransitionBg.y = FlxG.camera.scroll.y;
    entryTransitionCover.y = FlxG.camera.scroll.y;
    updateEntryTransitionCover();

    entryTransitionTween = FlxTween.tween(FlxG.camera.scroll, {y: 0}, transitionDuration, {
        ease: FlxEase.circInOut,
        onComplete: function(_) {
            finishEntryTransition();
        }
    });
}

function finishEntryTransition() {
    enteringFromState = false;
    acceptingInput = true;
    FlxG.camera.scroll.set();
    grid.visible = entryGridWasVisible;

    if (entryTransitionTween != null) {
        entryTransitionTween.cancel();
        entryTransitionTween = null;
    }

    if (entryTransitionBg != null) {
        remove(entryTransitionBg, true);
        entryTransitionBg.destroy();
        entryTransitionBg = null;
    }

    if (entryTransitionCover != null) {
        entryTransitionCover.clipRect = null;
        remove(entryTransitionCover, true);
        entryTransitionCover.destroy();
        entryTransitionCover = null;
    }

    clearPrevGameBitmap();
    clearTransitionDirection();
    restoreDefaultTransition();
}

function updateEntryTransitionCover() {
    if (entryTransitionCover == null) return;

    var coverHeight = Std.int(Math.max(0, Math.min(FlxG.height, -FlxG.camera.scroll.y)));
    entryTransitionCover.y = FlxG.camera.scroll.y;
    entryTransitionCover.visible = coverHeight > 0;
    entryTransitionCover.clipRect = coverHeight > 0 ? new FlxRect(0, 0, entryTransitionCover.width, coverHeight) : null;
}

function startExitToMainMenu() {
    exitingToMainMenu = true;
    acceptingInput = false;
    useModlauncherTransition();
    Reflect.setField(FlxG.save.data, DIRECTION_KEY, 1);
    grid.visible = true;
    
    if (menuMusic != null)
    {
        FlxTween.tween(menuMusic, {volume: 0, pitch: 0}, 0.5, {
            ease: FlxEase.circIn,
            onComplete: function(_)
            {
                finishExitToMainMenu();
            }
        });
    }
    else
    {
        finishExitToMainMenu();
    }
}

function finishExitToMainMenu() {
    if (!exitingToMainMenu) return;
    FlxG.switchState(new MainMenuState());
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

function useModlauncherTransition() {
    if (Reflect.field(FlxG.save.data, DEFAULT_TRANSITION_SCRIPT_KEY) == null && MusicBeatTransition.script != MODLAUNCHER_TRANSITION_SCRIPT) {
        Reflect.setField(FlxG.save.data, DEFAULT_TRANSITION_SCRIPT_KEY, MusicBeatTransition.script);
    }
    MusicBeatTransition.script = MODLAUNCHER_TRANSITION_SCRIPT;
}

function restoreDefaultTransition() {
    var defaultScript = Reflect.field(FlxG.save.data, DEFAULT_TRANSITION_SCRIPT_KEY);
    MusicBeatTransition.script = defaultScript == null ? "" : Std.string(defaultScript);
    Reflect.deleteField(FlxG.save.data, DEFAULT_TRANSITION_SCRIPT_KEY);
}

function fadeMenuForegroundForIntro() {
    var tweenTime = 0.25;
    var ease = FlxEase.cubeOut;

    FlxTween.cancelTweensOf(modlauncherText);
    FlxTween.cancelTweensOf(instructionsText);
    FlxTween.cancelTweensOf(modNameText);
    FlxTween.cancelTweensOf(modIcon);
    FlxTween.tween(modlauncherText, { alpha: 0 }, tweenTime, { ease: ease });
    FlxTween.tween(instructionsText, { alpha: 0 }, tweenTime, { ease: ease });
    FlxTween.tween(modNameText, { alpha: 0 }, tweenTime, { ease: ease });
    FlxTween.tween(modIcon, { alpha: 0 }, tweenTime, { ease: ease });

    if (menuMusic != null) {
        FlxTween.cancelTweensOf(menuMusic);
        FlxTween.tween(menuMusic, { volume: 0 }, tweenTime, { ease: ease });
    }
}

function fadeMenuBackgroundsForOutro() {
    var tweenTime = 0.3;
    var ease = FlxEase.cubeInOut;

    FlxTween.cancelTweensOf(bgmain);
    FlxTween.cancelTweensOf(bgImage);
    FlxTween.cancelTweensOf(grid);
    FlxTween.cancelTweensOf(middleBar);
    FlxTween.cancelTweensOf(modBgShadow);
    FlxTween.cancelTweensOf(modBgOverlay);
    FlxTween.cancelTweensOf(modBgAnim);
    FlxTween.cancelTweensOf(modBgIntroAnim);

    FlxTween.tween(bgmain, { alpha: 0 }, tweenTime, { ease: ease });
    FlxTween.tween(bgImage, { alpha: 0 }, tweenTime, { ease: ease });
    FlxTween.tween(grid, { alpha: 0 }, tweenTime, { ease: ease });
    FlxTween.tween(middleBar, { alpha: 0 }, tweenTime, { ease: ease });
    FlxTween.tween(modBgShadow, { alpha: 0 }, tweenTime, { ease: ease });
    FlxTween.tween(modBgOverlay, { alpha: 0 }, tweenTime, { ease: ease });
    FlxTween.tween(modBgAnim, { alpha: 0 }, tweenTime, { ease: ease });
    FlxTween.tween(modBgIntroAnim, { alpha: 0 }, tweenTime, { ease: ease });
}

function playSelectAnimation(modName:String) {

    acceptingInput = false;
    playingIntro = true;

    if (modName == null) {
        ModsFolder.switchMod(null);
        resetIntroState();
        return;
    }

    var introPath = 'mods/' + modName + '/meta/intro.hxs';
    var defaultIntroPath = resolveAddonFile('data/scripts/default_intro.hxs');
    var scriptPath:String = null;

    trace('[Modlauncher] checking intro path: ' + introPath);
    if (FileSystem.exists(introPath)) {
        scriptPath = introPath;
    } else if (FileSystem.exists(defaultIntroPath)) {
        scriptPath = defaultIntroPath;
    } else {
        ModsFolder.switchMod(modName);
        resetIntroState();
        return;
    }

    fadeMenuForegroundForIntro();
    showIntroAnimatedBg(modName);

    try {
        currentIntroScript = loadIntroScript(scriptPath, modName);
        if (currentIntroScript == null) {
            throw 'Failed to load intro script: ' + scriptPath;
        }

        var createSucceeded = true;
        var startSucceeded = true;

        if (hasIntroScriptFunction('create')) {
            createSucceeded = callIntroScriptFunction(['create']);
        } else if (hasIntroScriptFunction('ONCREATE')) {
            createSucceeded = callIntroScriptFunction(['ONCREATE'], [modName]);
        } else if (hasIntroScriptFunction('new')) {
            createSucceeded = callIntroScriptFunction(['new']);
        }

        if (!createSucceeded) {
            throw 'Intro create phase failed: ' + scriptPath;
        }

        if (hasIntroScriptFunction('start')) {
            startSucceeded = callIntroScriptFunction(['start']);
        } else if (hasIntroScriptFunction('ONSTART')) {
            startSucceeded = callIntroScriptFunction(['ONSTART']);
        }

        if (!startSucceeded) {
            throw 'Intro start phase failed: ' + scriptPath;
        }

    } catch(e:Dynamic) {
        trace('[Modlauncher] intro script error: ' + e);
        ModsFolder.switchMod(modName);
        resetIntroState();
        return;
    }

    startIntroSafety(modName);
}

function startIntroSafety(modName:String) {
    if (safetyTimer != null) {
        safetyTimer.cancel();
    }
    
    safetyTimer = new FlxTimer();
    safetyTimer.start(30, function(_) {
        if (playingIntro) {
            finishIntro(modName);
        }
    });
}

function finishIntro(modName:String) {

    playingIntro = false;

    if (currentIntroScript != null) {
        callIntroScriptFunction(['finish', 'ONCOMPLETE']);
        callIntroScriptFunction(['cancel', 'ONCANCEL', 'DESTROY']);
        currentIntroScript = null;
    }

    new FlxTimer().start(0.05, function(_) {
        trace('[Modlauncher] switching mod: ' + modName);
        ModsFolder.switchMod(modName);
        resetIntroState();
    });
}

function resetIntroState() {
    playingIntro = false;
    acceptingInput = true;
    currentIntroScript = null;

    if (safetyTimer != null) {
        safetyTimer.cancel();
        safetyTimer = null;
    }
}

function cancelIntro() {
    playingIntro = false;

    if (currentIntroScript != null) {
        callIntroScriptFunction(['cancel', 'ONCANCEL', 'DESTROY']);
        currentIntroScript = null;
    }

    if (safetyTimer != null) {
        safetyTimer.cancel();
        safetyTimer = null;
    }

    var tweenTime = 0.25;
    var ease = FlxEase.cubeIn;

    FlxTween.cancelTweensOf(bgImage);
    FlxTween.cancelTweensOf(grid);
    FlxTween.cancelTweensOf(middleBar);
    FlxTween.cancelTweensOf(modBgShadow);
    FlxTween.cancelTweensOf(modlauncherText);
    FlxTween.cancelTweensOf(instructionsText);
    FlxTween.cancelTweensOf(modNameText);
    FlxTween.cancelTweensOf(modBgOverlay);
    FlxTween.cancelTweensOf(modIcon);
    FlxTween.cancelTweensOf(modBgAnim);
    FlxTween.cancelTweensOf(modBgIntroAnim);

    if (enterSound != null) {
        FlxTween.tween(enterSound, { volume: 0 }, tweenTime + 0.45, {
            onComplete: (_) -> {
                enterSound.stop();
            }
        });
    }

    menuMusic.volume = 0;
    menuMusic.resume();
    FlxTween.tween(menuMusic, { volume: 0.7 }, tweenTime + 0.6);

    shine.visible = false;

    FlxTween.tween(bgmain, { alpha: 1 }, tweenTime, { ease: ease });
    FlxTween.tween(bgImage, { alpha: 0.4 }, tweenTime, { ease: ease });
    FlxTween.tween(grid, { alpha: 0.1 }, tweenTime, { ease: ease });
    FlxTween.tween(middleBar, { alpha: 1 }, tweenTime, { ease: ease });
    FlxTween.tween(modBgShadow, { alpha: 0.1 }, tweenTime, { ease: ease });
    FlxTween.tween(modlauncherText, { alpha: 1 }, tweenTime, { ease: ease });
    FlxTween.tween(instructionsText, { alpha: 1 }, tweenTime, { ease: ease });
    FlxTween.tween(modNameText, { alpha: 1 }, tweenTime, { ease: ease });
    FlxTween.tween(modIcon, { alpha: 1 }, tweenTime, { ease: ease });
    FlxTween.tween(modBgOverlay, { alpha: 1 }, tweenTime, { ease: ease });
    FlxTween.color(modBgOverlay, tweenTime, modBgOverlay.color, FlxColor.WHITE, { ease: ease });
    FlxTween.tween(modBgAnim, { alpha: modBgAnim.visible ? 1 : 0 }, tweenTime, { ease: ease});
    FlxTween.tween(modBgIntroAnim, { alpha: 0 }, tweenTime, {
        ease: ease,
        onComplete: (_) -> {
            modBgIntroAnim.visible = false;
        }
    });

    modIcon.screenCenter();
    FlxTween.tween(modIcon.scale, { x: originalIconScaleX, y: originalIconScaleY }, tweenTime, {
        ease: ease,
        onComplete: (_) -> {
            modIcon.scale.set(originalIconScaleX, originalIconScaleY);
            acceptingInput = true;
            updateSelection();
            modIcon.updateHitbox();
            modIcon.screenCenter();
        }
    });
}

function changeSelectionAnimated(change:Int) {
    acceptingInput = false;

    selection += change;
    if (selection < 0) selection = mods.length - 1;
    if (selection >= mods.length) selection = 0;

    FlxG.sound.play(Paths.sound("switch"));

    var direction = change > 0 ? -1 : 1;
    var moveDistance = FlxG.width * 0.5;

    updateSelection();

    var targetIconX = modIcon.x;
    var targetIconY = modIcon.y;
    var targetOverlayX = modBgOverlay.x;
    var targetOverlayY = modBgOverlay.y;
    var targetAnimX = modBgAnim.x;
    var targetAnimY = modBgAnim.y;

    modIcon.x = targetIconX - direction * moveDistance;
    modIcon.y = targetIconY;
    modBgOverlay.x = targetOverlayX - direction * moveDistance;
    modBgOverlay.y = targetOverlayY;
    modBgAnim.x = targetAnimX - direction * moveDistance;
    modBgAnim.y = targetAnimY;

    FlxTween.tween(modIcon, { x: targetIconX }, 0.25, { ease: FlxEase.quadOut });
    FlxTween.tween(modBgOverlay, { x: targetOverlayX }, 0.25, {
        ease: FlxEase.quadOut,
        onComplete: function() acceptingInput = true
    });
    FlxTween.tween(modBgAnim, { x: targetAnimX }, 0.25, { ease: FlxEase.quadOut });
}

function updateSelection() {
    modNameText.text = mods[selection] != null ? mods[selection] : "Disable Mods";
    loadModIcon(mods[selection]);
    loadModBg(mods[selection]);
}

function getLoopPrefixFromFrameName(frameName:String):String {
    var prefix = frameName;

    while (prefix.length > 1) {
        var lastChar = prefix.charAt(prefix.length - 1);
        var isDigit = lastChar >= "0" && lastChar <= "9";

        if (!isDigit && lastChar != " " && lastChar != "_" && lastChar != "-") {
            break;
        }

        prefix = prefix.substr(0, prefix.length - 1);
    }

    return prefix.length > 0 ? prefix : frameName;
}

function setupBgSprite(sprite:FlxSprite) {
    sprite.setGraphicSize(FlxG.width + 500, 450);
    sprite.updateHitbox();
    sprite.x = middleBar.x;
    sprite.y = middleBar.y;
}

function clearAnimatedBgSprite(sprite:FlxSprite) {
    sprite.visible = false;
    sprite.alpha = 0;
    sprite.animation.destroyAnimations();
}

function loadAnimatedBgSprite(sprite:FlxSprite, basePaths:Array<String>):Bool {
    clearAnimatedBgSprite(sprite);

    for (basePath in basePaths) {
        var animImagePath = basePath + '.png';
        var animXmlPath = basePath + '.xml';

        if (!FileSystem.exists(animImagePath) || !FileSystem.exists(animXmlPath)) {
            continue;
        }

        sprite.frames = FlxAtlasFrames.fromSparrow(BitmapData.fromFile(animImagePath), File.getContent(animXmlPath));

        var frameNames:Array<String> = [];
        for (frame in sprite.frames.frames) {
            if (frame.name != null) {
                frameNames.push(frame.name);
            }
        }

        if (frameNames.length > 0) {
            var animPrefix = getLoopPrefixFromFrameName(frameNames[0]);
            sprite.animation.addByPrefix("loop", animPrefix, 18, true);
            sprite.animation.play("loop", true);
            sprite.visible = true;
            sprite.alpha = 1;
            setupBgSprite(sprite);
            return true;
        }
    }

    return false;
}

function showIntroAnimatedBg(modName:String) {
    if (!modBgAnim.visible) {
        clearAnimatedBgSprite(modBgIntroAnim);
        return;
    }

    modBgAnim.visible = false;
    modBgAnim.alpha = 0;
    loadAnimatedBgSprite(modBgIntroAnim, ['mods/' + modName + '/meta/bg-anim-intro', 'mods/' + modName + '/bg-anim-intro']);
}

function loadModIcon(modName:String) {
    var sizeX = 200;
    var sizeY = 200;
    introDelay = 0.3;
    hasIcon = true;

    var isMain = false;
    var isNoIcon = false;

    if (modName != null) {
        var infoPath = 'mods/' + modName + '/meta/info.json';
        if (FileSystem.exists(infoPath)) {
            var data = Json.parse(File.getContent(infoPath));
            if (data.iconSize != null) {
                sizeX = data.iconSize.x;
                sizeY = data.iconSize.y;
            }
            if (data.introDelay != null)
                introDelay = data.introDelay;
        }
    }

    if (modName == null) {
        modIcon.loadGraphic(Paths.image("main"));
        isMain = true;
    } else {
        var loaded = false;
        for (p in ['mods/' + modName + '/meta/icon.png', 'mods/' + modName + '/icon.png']) {
            if (FileSystem.exists(p)) {
                modIcon.loadGraphic(BitmapData.fromFile(p));
                loaded = true;
                break;
            }
        }
        if (!loaded) {
            modIcon.loadGraphic(Paths.image("no-icon"));
            hasIcon = false;
            isNoIcon = true;
        }
    }

    modIcon.offset.set(0, 0);
    modIcon.setGraphicSize(sizeX, sizeY);
    modIcon.updateHitbox();
    modIcon.screenCenter();

    originalIconScaleX = modIcon.scale.x;
    originalIconScaleY = modIcon.scale.y;
}

function loadModBg(modName:String) {
    modBgOverlay.visible = false;
    modBgOverlay.alpha = 1;
    clearAnimatedBgSprite(modBgAnim);
    clearAnimatedBgSprite(modBgIntroAnim);
    modBgShadow.visible = false;
    modBgShadow.alpha = 0.1;

    if (modName == null) {
        modBgOverlay.visible = true;
        modBgOverlay.loadGraphic(Paths.image("main-bg"));
    } else {
        var loadedAnim = loadAnimatedBgSprite(modBgAnim, ['mods/' + modName + '/meta/bg-anim', 'mods/' + modName + '/bg-anim']);

        if (!loadedAnim) {
            var loaded = false;
            for (p in ['mods/' + modName + '/meta/bg.png', 'mods/' + modName + '/bg.png']) {
                if (FileSystem.exists(p)) {
                    modBgOverlay.loadGraphic(BitmapData.fromFile(p));
                    modBgOverlay.visible = true;
                    loaded = true;
                    break;
                }
            }

            if (!loaded) {
                if (!hasIcon) {
                    modBgOverlay.loadGraphic(Paths.image("no-bg"));
                    modBgOverlay.visible = true;
                } else {
                    return;
                }
            }
        }
    }

    var bgTarget = modBgAnim.visible ? modBgAnim : modBgOverlay;
    setupBgSprite(bgTarget);

    modBgShadow.visible = true;
    modBgShadow.setGraphicSize(bgTarget.width + 30, bgTarget.height + 40);
    modBgShadow.updateHitbox();
    modBgShadow.x = middleBar.x - 15;
    modBgShadow.y = middleBar.y - 20;
}

function playEnterSound(modName:String) {
    if (modName == null) return;

    var folderPath = 'mods/' + modName + '/meta/enter/';
    var defaultPath = 'mods/' + modName + '/meta/default.ogg';

    if (!FileSystem.exists(folderPath)) {
        if (FileSystem.exists(defaultPath)) {
            enterSound = FlxG.sound.play(Sound.fromFile(defaultPath));
        }
        return;
    }

    var soundFiles:Array<String> = [];
    
    for (file in FileSystem.readDirectory(folderPath)) {
        if (StringTools.endsWith(file, ".ogg")) {
            var name = file.substr(0, file.length - 4);
            if (Std.parseInt(name) != null)
                soundFiles.push(file);
        }
    }

    if (soundFiles.length == 0) {
        if (FileSystem.exists(defaultPath)) {
            enterSound = FlxG.sound.play(Sound.fromFile(defaultPath));
        }
        return;
    }

    var randomFile = soundFiles[FlxG.random.int(0, soundFiles.length - 1)];
    enterSound = FlxG.sound.play(Sound.fromFile(folderPath + randomFile));
}

function destroy() {
    if (entryTransitionTween != null) {
        entryTransitionTween.cancel();
        entryTransitionTween = null;
    }
    if (entryTransitionBg != null) {
        remove(entryTransitionBg, true);
        entryTransitionBg.destroy();
        entryTransitionBg = null;
    }
    if (entryTransitionCover != null) {
        entryTransitionCover.clipRect = null;
        remove(entryTransitionCover, true);
        entryTransitionCover.destroy();
        entryTransitionCover = null;
    }
    if (menuMusic != null) {
        menuMusic.stop();
        menuMusic.destroy();
        menuMusic = null;
    }
    if (modBgIntroAnim != null) {
        remove(modBgIntroAnim, true);
        modBgIntroAnim.destroy();
        modBgIntroAnim = null;
    }

    if (safetyTimer != null) {
        safetyTimer.cancel();
        safetyTimer = null;
    }

    if (currentIntroScript != null) {
        callIntroScriptFunction(['cancel', 'ONCANCEL', 'DESTROY']);
        currentIntroScript = null;
    }

    grid.visible = true;
    FlxG.camera.scroll.set();
}
