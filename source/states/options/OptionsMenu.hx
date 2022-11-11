package states.options;

import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import flixel.util.FlxSignal.FlxTypedSignal;
import flixel.input.keyboard.FlxKey;
import states.options.DescriptionHolder;
import objects.Alphabet;

using StringTools;
using utils.Tools;

// god this code is so horrible
class OptionsMenu extends MusicBeatState
{
	private var mainCategory:Array<CategoryInfo> = [
		{name: 'gameplay', description: 'Change the overall gameplay of your game.'},
		{name: 'graphics', description: 'Change the game\'s appearance.'},
		{name: 'controls', description: 'Change the controls to your liking.'},
		{name: 'notes', description: 'Change the note\'s appearance in-game.'}
	];

	// sprites and stuff, automatically handled
	public var background:FlxSprite;
	public var dimmer:FlxSprite;

	public var title:Alphabet;
	public var categoryTitle:FlxSprite;
	public var description:DescriptionHolder;
	public var groupCategory:FlxTypedGroup<OptionsSprite>;

	public var globalGroupManager:FlxTypedGroup<FlxObject>;

	public var categoryID:Int = -1;

	public var curSelected:Array<Null<Int>> = [];

	override function create()
	{
		background = new FlxSprite().loadGraphic(Paths.image('menus/settingsBG'));
		background.scrollFactor.set();
		add(background);

		dimmer = new FlxSprite().makeGraphic(FlxG.width, Std.int(FlxG.height * 0.9), FlxColor.BLACK);
		dimmer.scrollFactor.set();
		dimmer.screenCenter();
		dimmer.alpha = 0.3;
		add(dimmer);

		description = new DescriptionHolder();
		description.text = 'test test boogie boogie';

		globalGroupManager = new FlxTypedGroup<FlxObject>();

		categoryTitle = new FlxSprite(0, 100);
		categoryTitle.frames = Paths.getSparrowAtlas('menus/mainmenu/menu_options');

		categoryTitle.animation.addByPrefix('selected', 'options white', 12);
		categoryTitle.animation.play('selected');
		categoryTitle.scale.set(0.8, 0.8);
		categoryTitle.updateHitbox();
		categoryTitle.screenCenter(X);

		add(globalGroupManager);
		add(categoryTitle);
		add(description);

		createCategory();
		changeSelection(0, [], false);

		super.create();
	}

	public function createCategory(id:Int = -1)
	{
		categoryID = id;
		globalGroupManager.clear();

		if (id == -1)
		{
			for (i in 0...mainCategory.length)
			{
				var category = mainCategory[i];

				var categoryText:Alphabet = new Alphabet(0, 0, category.name, true);
				categoryText.y = 250 + ((categoryText.height + 20) * i);
				categoryText.screenCenter(X);
				categoryText.scrollFactor.set();
				categoryText.attributes.set('description', category.description);
				categoryText.ID = i;
				globalGroupManager.add(categoryText);
			}
		}
		else
		{
			switch (categoryID)
			{
				case 0 | 1:
					{
						var listedGroup:Array<
							{
								name:String,
								description:String,
								saveHolder:String,
								type:Int
							}> = [];

						if (id == 0)
						{
							listedGroup.push({
								name: 'Downscroll',
								description: 'If enabled, the notes will scroll downwards.',
								saveHolder: 'downscroll',
								type: 0
							});
							listedGroup.push({
								name: 'Ghost Tap',
								description: 'Allows you to make inputs that are not called for while playing a song.',
								saveHolder: 'ghost_tap',
								type: 0
							});
							listedGroup.push({
								name: 'Camera Zooming',
								description: 'If the camera should zoom in a little every four sections.',
								saveHolder: 'camZoom',
								type: 0
							});
						}
						else
						{
							listedGroup.push({
								name: 'Frame Rate',
								description: 'How many frames should the game run at.',
								saveHolder: 'frameRate',
								type: 1
							});
							listedGroup.push({
								name: 'Antialiasing',
								description: 'Removes jagged edges of the game for an improved quality.',
								saveHolder: 'antialiasing',
								type: 0
							});
							listedGroup.push({
								name: 'Flashing Lights',
								description: 'Whether flashing lights should be on or off for photosensitive players.',
								saveHolder: 'flashing_lights',
								type: 0
							});
						}

						for (member in listedGroup)
						{
							var i:Int = listedGroup.indexOf(member);

							var spriteMember:OptionsSprite = new OptionsSprite(member.name, member.saveHolder, member.description, member.type);
							spriteMember.ID = i;
							spriteMember.setPosition(40, dimmer.y + 80 + ((spriteMember.height + 10) * i));
							globalGroupManager.add(spriteMember);
						}
					}
			}
		}
	}

	private var manualLerpPoint:FlxPoint = FlxPoint.get();
	private var _lerpTarget:Int = 0;

	override function update(elapsed:Float)
	{
		var lerpValue:Float = elapsed * 7.725;
		var lerpTowards:FlxPoint = new FlxPoint();

		switch (_lerpTarget)
		{
			case 0:
				lerpTowards = new FlxPoint(Math.min(FlxG.mouse.screenX + 24, FlxG.width - description.width - 8),
					Math.min(FlxG.mouse.screenY + 32, FlxG.height - description.height - 8));

				lerpTowards.set(Math.max(8, lerpTowards.x), Math.max(8, lerpTowards.y));

				lerpValue = elapsed * Math.max(FlxMath.remapToRange(new FlxPoint(description.x, description.y).distanceTo(lerpTowards), 150, 450, 7.725,
					15.775), 7.725);
			case 1:
				manualLerpPoint.copyTo(lerpTowards);
		}

		description.setPosition(Tools.lerpBound(description.x, lerpTowards.x, lerpValue), Tools.lerpBound(description.y, lerpTowards.y, lerpValue));

		if (FlxG.mouse.justMoved)
		{
			_lerpTarget = 0;

			switch (categoryID)
			{
				case -1 | 0 | 1:
					{
						for (category in globalGroupManager.members)
						{
							if (category.ID != curSelected[categoryID + 1])
							{
								if (FlxG.mouse.overlaps(category))
								{
									changeSelection(category.ID, [], true);
									break;
								}
							}
						}

						if (categoryID == 0 || categoryID == 1)
						{
							if (!FlxG.mouse.overlaps(globalGroupManager.members[curSelected[categoryID + 1]]))
								cast(globalGroupManager.members[curSelected[categoryID + 1]], OptionsSprite).isSelected = false;
						}
					}
			}
		}

		var currentObj:FlxObject = globalGroupManager.members[curSelected[categoryID + 1]];

		if (controls.getKey('BACK', JUST_PRESSED))
		{
			if (categoryID == -1)
				MusicBeatState.switchState(new states.menus.MainMenuState());
			else
			{
				createCategory(-1);
				changeSelection(0, [], false);

				categoryTitle.visible = true;
			}
		}
		else if (controls.getKey('ACCEPT', JUST_PRESSED) || (FlxG.mouse.justPressed && FlxG.mouse.overlaps(currentObj)))
		{
			@:privateAccess
			{
				switch (categoryID)
				{
					case -1:
						{
							categoryTitle.visible = false;
							createCategory(curSelected[0]);

							description._controlledAlpha = 0.0;
							description.targetAlpha = 0.0;
						}
					case 0 | 1:
						{
							var optionsSprite:OptionsSprite = cast(currentObj, OptionsSprite);

							switch (optionsSprite.__type)
							{
								case 0:
									{
										optionsSprite.onChange(!optionsSprite._isAccepted);
									}
							}
						}
				}
			}
		}
		else
		{
			@:privateAccess
			{
				if (controls.getKey('UI_UP', JUST_PRESSED))
				{
					changeSelection(-1, controls.LIST_CONTROLS['UI_DOWN'].__keys);
				}
				else if (controls.getKey('UI_DOWN', JUST_PRESSED))
				{
					changeSelection(1, controls.LIST_CONTROLS['UI_DOWN'].__keys);
				}

				switch (categoryID)
				{
					case 2:
						{}
				}
			}
		}

		super.update(elapsed);
	}

	public function changeSelection(change:Int = 0, keys:Array<Int>, mouse:Bool = false)
	{
		if (curSelected[categoryID + 1] == null)
			curSelected[categoryID + 1] = 0;

		var curSelection:Int = curSelected[categoryID + 1];

		if (!mouse)
			curSelection = FlxMath.wrap(curSelection + change, 0, globalGroupManager.members.length - 1);
		else
			curSelection = FlxMath.wrap(change, 0, globalGroupManager.members.length - 1);

		curSelected[categoryID + 1] = curSelection;

		if (change != 0)
			FlxG.sound.play(Paths.sound('menu/scrollMenu'), 0.75);

		var keyDirection:Int = FlxKey.NONE;

		for (key in keys)
		{
			if (keyDirection == -1)
				keyDirection = getKeyDirection(key);
			else
				break;
		}

		@:privateAccess
		description._controlledAlpha = 0.7;
		description.targetAlpha = 1.0;

		switch (categoryID)
		{
			case -1:
				{
					for (text in globalGroupManager.members)
					{
						var textObj:Alphabet = cast(text, Alphabet);

						if ((mouse && FlxG.mouse.overlaps(textObj)) || (!mouse && textObj.ID == curSelection))
						{
							description.text = textObj.attributes['description'];
							textObj.alpha = 1.0;

							if (!mouse)
							{
								manualLerpPoint.set(textObj.x + 100, textObj.y + textObj.height + 10);
								_lerpTarget = 1;
							}
						}
						else
							textObj.alpha = 0.6;
					}
				}
			case 0 | 1:
				{
					for (text in globalGroupManager.members)
					{
						var textObj:OptionsSprite = cast(text, OptionsSprite);

						if (textObj.isSelected = ((mouse && FlxG.mouse.overlaps(textObj)) || (!mouse && textObj.ID == curSelection)))
						{
							description.text = textObj.description;

							if (!mouse)
							{
								manualLerpPoint.set(textObj.x + 100, textObj.y + textObj.height + 10);
								_lerpTarget = 1;
							}
						}
					}
				}
			case 2:
				{}
			case 3:
				{}
		}
	}

	private function getKeyDirection(key:Int)
	{
		var controlList:Array<Array<FlxKey>> = [];
		@:privateAccess
		{
			controlList = [
				controls.LIST_CONTROLS['UI_LEFT'].__keys,
				controls.LIST_CONTROLS['UI_DOWN'].__keys,
				controls.LIST_CONTROLS['UI_UP'].__keys,
				controls.LIST_CONTROLS['UI_RIGHT'].__keys,
			];
		}

		if (key != FlxKey.NONE)
		{
			for (i in 0...controlList.length)
			{
				for (j in 0...controlList[i].length)
				{
					if (controlList[i][j] == key)
						return i;
				}
			}
		}

		return -1;
	}
}

@:allow(states.options.OptionsMenu)
class OptionsSprite extends FlxTypedSpriteGroup<FlxSprite>
{
	public var name:String = '';
	public var saveHolder:String = '';
	public var description:String = '';

	public var isSelected:Bool = false;

	private var _background:FlxSprite;
	private var _selectionBG:FlxSprite;
	private var _nameSprite:FlxText;

	// bool
	private var _isAccepted:Bool;
	private var _statsText:FlxText; // on, off

	// float, int
	private var _arrowLeft:FlxText;
	private var _arrowRight:FlxText;
	private var _numText:FlxText;

	private var __type:Int = -1;

	override function new(name:String, saveHolder:String, description:String, type:Int = -1)
	{
		super();

		this.name = name;
		this.saveHolder = saveHolder;
		this.description = description;
		__type = type;

		_background = new FlxSprite().makeGraphic(Std.int(FlxG.width * 0.6), 90, FlxColor.BLACK);
		_background.scrollFactor.set();
		_background.alpha = 0.3;

		_selectionBG = new FlxSprite().makeGraphic(Std.int(FlxG.width * 0.6), 90, FlxColor.WHITE);
		_selectionBG.scrollFactor.set();
		_selectionBG.alpha = 0.0;

		_nameSprite = new FlxText(20, 0, 0, name, 26);
		_nameSprite.setFormat(Paths.font("vcr.ttf"), 26, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		_nameSprite.borderSize = 1.75;
		_nameSprite.centerOverlay(_background, Y);

		add(_background);
		add(_selectionBG);
		add(_nameSprite);

		switch (__type)
		{
			case 0:
				{
					_isAccepted = Settings.getPref(saveHolder, false);

					_statsText = new FlxText(0, 0, 0, (_isAccepted ? 'ON' : 'OFF'), 20);
					_statsText.setFormat(Paths.font("vcr.ttf"), 26, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
					_statsText.centerOverlay(_background, Y);
					_statsText.x = _background.x + _background.width - _statsText.width - 20;
					add(_statsText);
				}
		}
	}

	private var _offsetReset:Float = 0.0;

	override function update(elapsed:Float)
	{
		if ((_offsetReset += elapsed) > 1 / 6)
			offset.set(0, 0);

		if (isSelected)
			_selectionBG.alpha = 0.2;
		else
			_selectionBG.alpha = 0.0;
	}

	public function onChange(Value:Dynamic)
	{
		var acceptedOffset:Bool = false;

		switch (__type)
		{
			case 0:
				{
					_isAccepted = Value;

					_statsText.text = _isAccepted ? 'ON' : 'OFF';
					_statsText.x = _background.x + _background.width - _statsText.width - 20;

					Settings.setPref(saveHolder, _isAccepted);

					acceptedOffset = true;
				}
			case 1:
				{}
		}

		if (acceptedOffset)
		{
			_offsetReset = 0.0;
			offset.set(0, -8);
		}
	}
}

typedef CategoryInfo =
{
	var name:String;
	var description:String;
}
