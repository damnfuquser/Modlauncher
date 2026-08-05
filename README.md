# modlauncher by ![lunacynne](https://github.com/lunacynne)
> [!CAUTION]
> This is a fork of the original repository by ![lunacynne](https://github.com/lunacynne). Since the original was deleted, it has been restored here. Work on backporting the latest version of vslice from the old version of polymod has just begun! The libraries are currently unstable!
If you would like to help with development, feel free to submit a pull request, and I will review it.

ingame launcher for fnf mod states

---

## Overview

Just drag `modlauncher.zip` into your mods folder and you're good to go!

When in the main menu, press `TAB` to open the launcher UI and your `BACK` key to close it. While it's open, you'll see banners of any mods that have bound to the launcher. You can navigate between them with your `UI_LEFT` and `UI_RIGHT` keys, and press your `ACCEPT` key to "launch" the selected mod. You can also cancel the selection by pressing `BACK` before the state transition starts.

---

## Screenshots

<img width="1911" height="1069" alt="empty" src="https://github.com/user-attachments/assets/68f068da-ebf1-4da3-a945-7de065e4e0c8" />
<img width="1909" height="1071" alt="buckslop" src="https://github.com/user-attachments/assets/618fc99b-7b8d-4943-91bc-e60dd5e6143c" />


---

## Dependencies

- beast-engine v1.x

---

## For developers

The following documentation is also available in the `modlauncher.Registry` code, but here it is for your convenience:

To bind your mod, you must call `bind` from the `modlauncher.Registry` module and pass in an anonymous struct which requires the following fields of `LauncherData`:

### Fields

| Field | Type | Description |
|------|------|------------|
| name | String | The name of your mod as it will appear in the launcher. |
| target | String | Full class name of the ScriptedMusicBeatState you want to open after your mod is selected. For example, `"exampleMod.states.InitState"`. |
| logoPath | String | The path to your mod's logo (will be passed into Paths.image). Defaults to the modlauncher icon. |
| selectSoundPath | Null<String> | The path to your mod's select sound (will be passed into Paths.sound). Defaults to `"confirmMenu"`. |
| selectDuration | Null<Float> | The time in seconds from when the player selcts your mod to the end of the state transition, minimum 1.5. The selection is cancellable until 0.5 seconds before this duration (when the state transition starts). Defaults to 1.5. |
| onSetup | Null<(LauncherData)->Void> | Callback to run when modlauncher is injected into the main menu. Useful for setting up your mod banner in the launcher. |
| onUpdate | Null<(LauncherData, Float)->Void> | Callback to run every frame while the launcher is open. Useful for animating your banner. The 2nd parameter is delta-time in seconds. |
| onFocus | Null<(LauncherData)->Void> | Callback to run when your mod is "focused" on. |
| onUnfocus | Null<(LauncherData)->Void> | Callback to run when another mod is focused on away from yours. |
| onSelect | Null<(LauncherData)->Void> | Callback to run when your mod is initially selected, before the state transition starts. |
| onCancel | Null<(LauncherData)->Void> | Callback to run when your mod selection is cancelled before the state transition starts. |
| onInit | Null<(LauncherData)->Void> | Callback to run after your mod is selected, and right before your target state is initialized. Useful for "initializing" your mod if you're not using an initialization state (I recommend the latter, though). |

---

The `LauncherData` parameter passed into the callbacks is the same as the struct you passed into bind, but with a few more fields used for the banner:

### Banner Fields

| Field | Type | Description |
|------|------|------------|
| camera | FunkinCamera | The camera of your mod's banner in the launcher. The size you have to work with is 1280x450. |
| groupBG | FlxTypedSpriteGroup | The background group of your mod's banner. |
| groupUI | FlxTypedSpriteGroup | The UI group of your mod's banner. |
| logo | FunkinSprite | The logo sprite of your mod's banner, part of groupUI. Initially auto-resized to 350px height. |

So, if you add to this struct in one of your callbacks, it will carry over into the other callbacks.

---

## Example binding

```haxe
package exampleMod;

import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;

import funkin.graphics.FunkinSprite;
import funkin.modding.module.ModuleHandler;
import funkin.modding.module.ScriptedModule;

class LauncherBinding extends ScriptedModule {
	public function new() {
		super("exampleMod.LauncherBinding");
	}
	
	override public function onCreate(event:ScriptEvent):Void {
		active = false;
		
		tryBindModlauncher();
		// Bind to other FNF mod launchers as well? Up to you...
		
		hook();
	}
	
	private function hook():Void {
		ModuleHandler.getModule("be.reloader.Reloader").scriptGet("reloadPre").set("exampleMod.LauncherBinding", {
			callback: "onReload"
		});
	}
	
	public function onReload():Void {
		tryBindModlauncher();
		// Bind to other FNF mod launchers as well? Up to you...
		
		hook();
	}
	
	private var bound:Bool = false; 
	public function tryBindModlauncher():Void {
		if (bound) {
			return;
		}
		
		if (ModuleHandler.getModule("modlauncher.Registry") != null) {
			ModuleHandler.getModule("modlauncher.Registry").scriptCall("bind", [{
				name: "Example Mod",
				
				target: "exampleMod.states.InitState",
				
				logoPath: "exampleMod/logo",
				
				selectSoundPath: "exampleMod/launcherSelectSound",
				selectSoundLength: 2.5,
				
				onSetup: function(data:Dynamic):Void {
					data.camera.bgColor = 0xff808080;
					
					data.logo.scale.set(0.5, 0.5);
					data.logo.updateHitbox();
					
					var mySprite:FunkinSprite = new FunkinSprite().loadTexture("exampleMod/mySprite");
					data.groupBG.add(mySprite);
					data.mySprite = mySprite;
				},
				
				onSelect: function(data:Dynamic):Void {
					data.camera.flash(0xffffffff, 0.5, null, true);
					
					FlxTween.globalManager.cancelTweensOf(data.logo.scale, ["x", "y"]);
					data.logo.scale.set(0.45, 0.45);
					FlxTween.tween(data.logo.scale, {x: 0.75, y: 0.75}, 1.5, {ease: FlxEase.expoOut});
				},
				
				onCancel: function(data:Dynamic):Void {
					FlxTween.globalManager.cancelTweensOf(data.logo.scale, ["x", "y"]);
					FlxTween.tween(data.logo.scale, {x: 0.5, y: 0.5}, 0.5, {ease: FlxEase.expoOut});
				},
				
				onUpdate: function(data:Dynamic, elapsed:Float):Void {
					data.mySprite.angle += 90 * elapsed;
				},
				
				onInit: function(data:Dynamic):Void {
					ModuleHandler.getModule("exampleMod.Globals").scriptSet("myVariable", true);
				}
			}]);
			
			bound = true;
		}
	}
}
```
> [!IMPORTANT]
> Bound mods do not persist through polymod reload! You must re-bind your mods using the `be.reloader.Reloader` module like in the example above.
