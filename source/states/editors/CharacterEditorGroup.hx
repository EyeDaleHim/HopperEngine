package states.editors;

class CharacterEditorGroup extends FlxContainer
{
    override public function new()
    {
        super();

        add(new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFFBB0E0E));
    }
}