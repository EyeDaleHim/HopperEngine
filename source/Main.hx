package;

import backend.DebugInfo;
import flixel.FlxG;
import flixel.FlxGame;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.events.Event;
import haxe.Timer;
import haxe.Json;
import sys.FileSystem;
import sys.thread.ElasticThreadPool;
import sys.thread.Mutex;
import lime.ui.Window;
import lime.app.Application;
#if sys
import sys.FileSystem;
import sys.io.File;
#end
import haxe.Json;
import backend.graphic.CacheManager;
import openfl.Assets;
import openfl.utils.AssetCache;

class Main extends Sprite
{
	var game = {
		width: 1280, // Game Width
		height: 720, // Game Height
		initialState: states.menus.TitleState, // The State when the game starts
		framerate: 60, // Default Framerate of the Game
		zoom: -1.0, // Zoom automatically calculates if -1
		skipSplash: true, // Skipping Flixel's Splash Screen
		startFullscreen: false // If the game should start fullscreen
	};

	public static var instance:Main;
	public static var gameInstance:FlxGame;

	// game version's number is 7 because of week 6
	public static final gameVersion:VersionScheme = {display: "0.2.7.1", number: 7}; // Version Of The Base Game (Friday Night Funkin')
	public static final engineVersion:VersionScheme = {display: "0.1.0A-1", number: 2}; // Version Of The Engine (Crow Engine)

	public static var fps:DebugInfo;

	public static function main():Void
	{
		Lib.current.addChild(new Main());
	}

	public function new()
	{
		super();

		instance = this;

		// splashScreen();

		if (game.framerate > 900)
		{
			game.framerate = 900;
		}

		if (stage != null)
		{
			init();
		}
		else
		{
			addEventListener(Event.ADDED_TO_STAGE, init);
		}
	}

	private function init(?E:Event):Void
	{
		if (hasEventListener(Event.ADDED_TO_STAGE))
		{
			removeEventListener(Event.ADDED_TO_STAGE, init);
		}
		setupGame();
	}

	#if ALLOW_FLIXEL_SLEEPING
	private var _SLEEP_TIMER:Timer;
	private var _THREADPOOL:ElasticThreadPool;
	private var _MUTEX:Mutex;
	#end

	private function setupGame():Void
	{
		var stageWidth:Int = Lib.current.stage.stageWidth;
		var stageHeight:Int = Lib.current.stage.stageHeight;

		// -1.0 to tell its a Float, instead of having -1 as an Int
		if (game.zoom == -1.0)
		{
			var ratioX:Float = stageWidth / game.width;
			var ratioY:Float = stageHeight / game.height;
			game.zoom = Math.min(ratioX, ratioY);
			game.width = Math.ceil(stageWidth / game.zoom);
			game.height = Math.ceil(stageHeight / game.zoom);
		}

		gameInstance = new FlxGame(game.width, game.height, game.initialState, #if (flixel < "5.0.0") game.zoom, #end game.framerate, game.framerate,
			game.skipSplash, game.startFullscreen);

		addChild(gameInstance);

		#if ALLOW_FLIXEL_SLEEPING
		_MUTEX = new Mutex();

		_THREADPOOL = new ElasticThreadPool(4, 20);

		_SLEEP_TIMER = new Timer(10000);
		_SLEEP_TIMER.run = function()
		{
			_THREADPOOL.run(function()
			{
				_MUTEX.acquire();

				try
				{
					if (FlxG.state != null)
					{
						FlxG.state.forEachOfType(flixel.FlxObject, function(object)
						{
							if (object != null && object.exists)
							{
								if (object.moves && object.velocity.x == 0 && object.velocity.y == 0)
									object.moves = false;
							}
						}, true);
					}
				}
				catch (e)
				{
					trace('whoops! prevented crash.');
				}
				_MUTEX.release();
			});
		};
		#end

		#if PRELOAD_CHARACTER
		var time = Lib.getTimer();

		_THREADPOOL.run(function()
		{
			_MUTEX.acquire();

			if (FileSystem.exists(Paths.getPath('images/characters', null, null)))
			{
				var characterList:Array<String> = FileSystem.readDirectory(Paths.getPath('images/characters', null, null));
				characterList.remove('icons');

				for (char in characterList)
				{
					var path:String = Paths.getPath('images/characters/' + char + '/' + char + '.json', TEXT, null);

					if (Assets.exists(path))
					{
						CacheManager.setDynamic('$char-jsonFile', Json.parse(Assets.getText(path)));
						if (Assets.exists(path.replace('json', 'xml')))
							CacheManager.cachedAssets[XML].set('$char-xmlFile',
								{type: XML, data: Xml.parse(Assets.getText(path.replace('json', 'xml'))), special: true});

						CacheManager.cachedAssets[DYNAMIC].get('$char-jsonFile').special = true;

						time = Lib.getTimer();
					}
				}
			}

			_MUTEX.release();
		});
		#end

		FlxG.fixedTimestep = false;

		#if (flixel >= "5.1.0")
		FlxG.game.soundTray.volumeDownSound = Paths.sound('backend/volume');
		FlxG.game.soundTray.volumeUpSound = Paths.sound('backend/volume');
		#end

		FlxG.console.registerClass(weeks.ScoreContainer);
		FlxG.console.registerClass(utils.Paths);
		FlxG.console.registerClass(utils.Tools);
		FlxG.console.registerClass(backend.data.Settings);
		FlxG.console.registerClass(music.Song);
		FlxG.console.registerClass(objects.notes.Note);
		FlxG.console.registerClass(Main);

		#if sys
		FlxG.console.registerFunction('checkCache', function()
		{
			var listOfCache:String = '---[BITMAP]---\n\n';

			for (bitmapCache in CacheManager.cachedAssets[BITMAP].keys())
			{
				listOfCache += 'FILE: "' + bitmapCache + '"';
				listOfCache += '\n';
			}

			listOfCache += '\n\n---[AUDIO]---\n\n';

			for (audioCache in CacheManager.cachedAssets[AUDIO].keys())
			{
				listOfCache += 'FILE: "' + audioCache + '"';
				listOfCache += '\n';
			}

			File.saveContent('listedCache.txt', listOfCache + '\n');
			trace('saved cache');
		});
		#end

		Settings.init();
		weeks.ScoreContainer.init();

		for (persistents in CacheManager.persistentAssets)
		{
			CacheManager.setBitmap(persistents);
			if (CacheManager.cachedAssets[BITMAP].exists(persistents))
				CacheManager.cachedAssets[BITMAP].get(persistents).special = true;
		}

		try
		{
			@:privateAccess
			Settings.prefs = Settings._save.data.settings;
		} catch (e)
		{
			Settings.prefs = new Map<String, Dynamic>();
		}

		#if !mobile
		addChild(fps = new DebugInfo(10, 5, 1.5));
		#end

		FlxG.game.stage.quality = openfl.display.StageQuality.LOW; // try and remove openfl's smoothing??
	}
}

/*Helper class to classify versions.
 * 
 * `display`: Display version
 * `number`: Number version
 * @return {display: '', number: 0}
 */
typedef VersionScheme =
{
	var display:String;
	var number:Int;
}
