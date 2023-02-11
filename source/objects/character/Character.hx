package objects.character;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxPoint;
import flixel.math.FlxMath;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.util.FlxStringUtil;
import flixel.util.FlxSort;
import haxe.Json;
import openfl.Assets;
import sys.FileSystem;
import objects.character.CharacterData;
import music.Song;
import music.Song.SongInfo;
import backend.Script;

using StringTools;

@:allow(states.PlayState)
class Character extends FlxSprite
{
	// basic info
	public var name:String = 'bf';
	public var isPlayer:Bool = true;
	public var healthColor:Int = 0;
	public var scripts:Array<Script> = [];

	// ok i removed some of the variables because i got lazier over time
	// simple controls for your character
	public var controlIdle:Bool = true; // Whether or not your character should keep playing the idle when it finishes an animation.
	public var forceIdle:Bool = false;
	// public var singAnimsUsesMulti:Bool = false; // If this is enabled, the sing animation will hold for (Conductor.crochet / 1000) * idleDuration, else, it'll just be idleDuration
	public var _animationOffset:Float = 0.3;
	public var overridePlayer:Bool = false; // If you set this to true, the enemy will be treated as a player

	// animation stuff
	public var animOffsets:Map<String, FlxPoint> = [];
	public var idleList:Array<String> = []; // automatically defaults to the character data idle list
	public var missList:Array<String> = [];
	public var singList:Array<String> = [];
	public var behaviorType:String = '';

	// handled by this class
	private var _idleIndex:Int = 0;
	private var _animationTimer:Float = 0.0;
	private var _characterData:CharacterData;

	public function new(x:Float, y:Float, name:String, isPlayer:Bool)
	{
		super(x, y);

		// quickCharacterMaker();

		this.name = name;
		this.isPlayer = isPlayer;

		var charPath:String = 'characters/${this.name}/${this.name}';
		var calledPath:String = Paths.imagePath(charPath);

		var imageExists:Bool = FileSystem.exists(calledPath);
		var xmlExists:Bool = FileSystem.exists(calledPath.replace('png', 'xml'));
		var jsonExists:Bool = FileSystem.exists(calledPath.replace('png', 'json'));
		var failedChar:Bool = false;

		if (!imageExists || !xmlExists || !jsonExists)
		{
			FlxG.log.error('Character $name doesn\'t exist! Please check your files!');
			failedChar = true;
			this.name = 'bf';
		}

		charPath = 'characters/${this.name}/${this.name}';

		_characterData = Json.parse(Assets.getText(Paths.imagePath(charPath).replace('png', 'json')));

		frames = switch (_characterData == null ? 'sparrow' : _characterData.atlasType)
		{
			case 'packer':
				Paths.getPackerAtlas(charPath);
			default:
				Paths.getSparrowAtlas(charPath);
		}

		if (failedChar)
			this.healthColor = !isPlayer ? 0xFFFF0000 : 0xFF33FF00;
		else
			this.healthColor = _characterData.healthColor;

		scale.set(_characterData.scale.x, _characterData.scale.y);

		setupCharacter();

		for (script in scripts)
		{
			script.executeFunction("create", [false]);
		}

		flipX = _characterData.flip.x;
		flipY = _characterData.flip.y;

		if (Song.currentSong != null)
			generateSingSchedule(Song.currentSong.song.formatToReadable());
	}

	public var containsSchedule:Bool = false;

	override function update(elapsed:Float)
	{
		for (script in scripts)
		{
			script.executeFunction("update", [elapsed, false]);
		}

		super.update(elapsed);

		if (animation.curAnim != null && controlIdle)
		{
			_animationTimer += elapsed;
		}

		if (singSchedules.length > 0)
		{
			for (i in 0...singSchedules.length)
			{
				if (singSchedules[i] != null && Conductor.songPosition > singSchedules[i].time)
				{
					playAnim(singSchedules[i].anim, true);
					singSchedules.shift();
				}
				else
					break;
			}
		}

		for (script in scripts)
		{
			script.executeFunction("update", [elapsed, true]);
		}
	}

	public function dance(?forcePlay:Bool = false):Void
	{
		if (idleList.length != 0) // what animations we playing today?
		{
			if (animation.curAnim != null)
			{
				// 0.3 offset
				var playIdleAnim:Bool = (singList.contains(animation.curAnim.name)
					&& (-_animationOffset + _animationTimer) >= Conductor.stepCrochet * 4.5 * 0.001);

				if (overridePlayer)
					playIdleAnim = ((singList.contains(animation.curAnim.name)
						&& (-_animationOffset + _animationTimer) >= Conductor.stepCrochet * 1.15 * 0.001)
						|| (missList.contains(animation.curAnim.name)
							&& (-_animationOffset + _animationTimer) >= Conductor.stepCrochet * 4 * 0.001));

				if ((playIdleAnim || !singList.contains(animation.curAnim.name)) || forceIdle)
				{
					if (controlIdle || forceIdle)
					{
						if ((name == 'tankman'
							&& (animation.curAnim.name != 'singDOWN-alt'
								|| (animation.curAnim.name == 'singDOWN-alt' && animation.curAnim.finished))
							|| name != 'tankman')) // dammit man... ill figure something out
						{
							_idleIndex++;
							_idleIndex = FlxMath.wrap(_idleIndex, 0, idleList.length - 1);

							var animToPlay:String = idleList[_idleIndex];

							playAnim(animToPlay, forceIdle);
						}
					}

					_animationTimer = 0.0;
				}
			}
		}

		forceIdle = false;

		for (script in scripts)
		{
			script.executeFunction("dance", []);
		}
	}

	public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0)
	{
		if (AnimName == '')
			return;

		animation.play(AnimName, Force, Reversed, Frame);

		var offsetAnim:FlxPoint = FlxPoint.get();
		if (animOffsets.exists(AnimName))
			offsetAnim.set(animOffsets[AnimName].x, animOffsets[AnimName].y);

		offset.set(offsetAnim.x, offsetAnim.y);
	}

	public function setupCharacter():Void
	{
		for (animData in _characterData.animationList)
		{
			if (animData.indices != null && animData.indices.length > 0)
				animation.addByIndices(animData.name, animData.prefix, animData.indices, "", animData.fps, animData.looped);
			else
				animation.addByPrefix(animData.name, animData.prefix, animData.fps, animData.looped);

			if (_characterData.singList.contains(animData.name))
				singList[_characterData.singList.indexOf(animData.name)] = animData.name;

			if (_characterData.idleList.contains(animData.name))
				idleList[_characterData.idleList.indexOf(animData.name)] = animData.name;

			if (_characterData.missList.contains(animData.name))
				missList[_characterData.idleList.indexOf(animData.name)] = animData.name;

			if (animData.offset.x != 0 || animData.offset.y != 0)
				animOffsets.set(animData.name, FlxPoint.get(animData.offset.x, animData.offset.y));
		}

		if (_characterData.behaviorType != null)
		{
			switch (_characterData.behaviorType)
			{
				case 'hair':
					{
						// i know loop points exist, idk how to use it yet and dont tell me how
						for (animData in _characterData.animationLoopPoint)
						{
							var animName = animation.getByName(animData.animation.name);

							animation.addByIndices(animData.animation.name + '-hair_loop', animData.animation.prefix, [
								for (i in animData.index...animName.frames[animName.frames.length - 1])
									i
							], "", animData.animation.fps, true);

							if (animData.animation.offset.x != 0 || animData.animation.offset.y != 0)
								animOffsets.set(animData.animation.name + '-hair_loop',
									FlxPoint.get(animData.animation.offset.x, animData.animation.offset.y));
						}

						animation.finishCallback = function(name:String)
						{
							if (animation.getByName(name + '-hair_loop') != null)
								playAnim(name + '-hair_loop', true);
						}
					}
			}
		}

		antialiasing = Settings.getPref('antialiasing', true);

		if (idleList.length > 0)
			playAnim(idleList[0]);
		else if (containsSchedule)
			playAnim(singList[0] + '-hair_loop');
	}

	public var singSchedules:Array<CharacterSingTask> = [];

	public function generateSingSchedule(song:String):Void
	{
		var path:String = Paths.data('charts/$song/charSchedule/$name');

		if (FileSystem.exists(path))
		{
			containsSchedule = true;

			var parsedData:SongInfo = Json.parse(Assets.getText(path));

			for (section in parsedData.sectionList)
			{
				for (note in section.notes)
				{
					var noteData:Int = 1;
					if (note.direction > 2)
						noteData = 3;

					noteData += FlxG.random.int(0, 1);

					singSchedules.push({anim: 'shoot${noteData}', direction: noteData, time: note.strumTime});
				}
			}

			singSchedules.sort(function(note1:CharacterSingTask, note2:CharacterSingTask)
			{
				return FlxSort.byValues(FlxSort.ASCENDING, note1.time, note2.time);
			});
		}
	}

	override function destroy()
	{
		super.destroy();

		animOffsets = null;
		idleList = null;
		singList = null;
		missList = null;

		_characterData = null;
	}

	private function quickCharacterMaker()
	{
		var data:CharacterData;

		var idleList:Array<String> = ['idle'];
		var missList:Array<String> = [];
		var singList:Array<String> = ['shoot1', 'shoot2', 'shoot3', 'shoot4'];

		var animationList:Array<Animation> = [];
		var quickAnimAdd:(String, String, Array<Int>, Int, Bool,
			{x:Int, y:Int}) -> Void = function(name:String, prefix:String, indices:Array<Int>, fps:Int, looped:Bool, offset:{x:Int, y:Int})
			{
				animationList.push({
					name: name,
					prefix: prefix,
					indices: indices,
					fps: fps,
					looped: looped,
					offset: offset
				});
			};

		quickAnimAdd('shoot1', 'Pico shoot 1', [], 24, false, {x: 0, y: 0});
		quickAnimAdd('shoot2', 'Pico shoot 2', [], 24, false, {x: -1, y: -128});
		quickAnimAdd('shoot3', 'Pico shoot 3', [], 24, false, {x: 412, y: -64});
		quickAnimAdd('shoot4', 'Pico shoot 4', [], 24, false, {x: 439, y: -19});

		quickAnimAdd('idle', 'Pico shoot 2', [4, 5, 6], 24, true, {x: -1, y: -128});

		data = {
			name: 'picoSpeaker',
			healthColor: -4728747,
			animationList: animationList,
			idleList: idleList,
			missList: missList,
			singList: singList,
			flip: {x: false, y: false},
			scale: {x: 1.0, y: 1.0}
		}

		trace(Json.stringify(data, "\t"));
	}
}

typedef CharacterSingTask =
{
	var anim:String;
	var direction:Int;
	var time:Float;
}
