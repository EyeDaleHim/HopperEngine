package utils.logs;

import flixel.util.typeLimit.OneOfThree;
import openfl.events.IOErrorEvent;
import openfl.system.Capabilities;
import lime.system.System;
import sys.io.FileOutput;

class Logs
{
	public static var DEFAULT_SILENT:Bool = false;

	private static final LOG_STARTER:String = "
[START OF LOG]

_____ [[  SYSTEM INFO  ]] _____

> Operating System: %d
> Executable location: %e
> Device Vendor: %f
> CPU Architecture: %g
> Driver Info: %h
> Render info: %j

_______________________________
";

	private static var _INIT:Bool = false;

	private static var _STORED_MESSAGES:Array<Message> = [];

	private static var logFile:FileOutput;

	public static var BUFFER_SIZE:Int = 50; // How big should our logs be in memory before we write

	private static function _print(log:LogItem, printLevel:PrintLevel = CONSOLE, type:Type, silent:Bool = false, ?info:haxe.PosInfos):Void
	{
		var time:String = DateTools.format(Date.now(), "%H-%M-%S");

		var outputLog:Message = null;

		if (Std.isOfType(log, String))
			outputLog = {log: Custom(cast(log, String)), time: time, type: type};
		else
			outputLog = {log: log, time: time, type: type};

		_STORED_MESSAGES.push(outputLog);

		var line:String = formatMessage(outputLog.log);

		switch (printLevel)
		{
			case CONSOLE:
				#if !PRINT_REGARDLESS
				if (!silent)
				#else
				if (true) // wtf am i doing
				#end
				{
					#if js
					if (js.Syntax.typeof(untyped console) != "undefined" && (untyped console).log != null)
						(untyped console).log(formatPosInfo(line, info));
					#elseif sys
					Sys.println(formatPosInfo(line, info));
					#end
				}
			case FLIXEL:
				if (type == ERROR)
					FlxG.log.error(line);
				else if (type == WARNING)
					FlxG.log.warn(line);
			case _:
		}

		if (_STORED_MESSAGES.length > BUFFER_SIZE)
		{
			// buffer overfill...
			for (i in 0..._STORED_MESSAGES.length)
			{
				var logItem:CommonLogs = _STORED_MESSAGES[i].log;

				line = formatMessage(outputLog.log);

				if (line.length > 0)
					logFile.writeString('[${_STORED_MESSAGES[i].time}] [${_STORED_MESSAGES[i].type}]: $line\n');

				_STORED_MESSAGES[i] = null;
			}

			logFile.flush();
			_STORED_MESSAGES.resize(0);
		}
	}

	public static function init():Void
	{
		if (!_INIT)
		{
			_INIT = true;

			var date:String = DateTools.format(Date.now(), "%Y-%m-%d_%H-%M-%S");

			var directory = Path.join([System.applicationStorageDirectory, 'logs']);
			var file:String = '$date.log';

			var meta = openfl.Lib.current.stage.application.meta;

			if (!Assets.exists(directory))
			{
				FileSystem.createDirectory(directory);
			}

			logFile = File.write(Path.join([directory, file]));

			var starterOutput:String = LOG_STARTER;
			starterOutput = starterOutput.replace('%a', date);
			starterOutput = starterOutput.replace('%b', meta["name"]);
			starterOutput = starterOutput.replace('%c', meta["version"]);
			starterOutput = starterOutput.replace('%d', '${System.platformLabel} - ${System.platformVersion} (${System.platformName})');
			starterOutput = starterOutput.replace('%e', System.applicationDirectory);
			starterOutput = starterOutput.replace('%f', '${System.deviceVendor} (${System.deviceModel})');
			starterOutput = starterOutput.replace('%g', Capabilities.cpuArchitecture);
			starterOutput = starterOutput.replace('%h', FlxG?.stage?.context3D?.driverInfo ?? 'N/A');
			starterOutput = starterOutput.replace('%j', renderMethod());

			starterOutput = starterOutput.trim();

			logFile.writeString(starterOutput + "\n\n", UTF8);
			logFile.flush();

			FlxG.stage.application.onExit.add(function(exitCode:Int)
			{
				info('Application exited with code $exitCode', true);

				var line:String = "";

				for (i in 0..._STORED_MESSAGES.length)
				{
					var logItem:CommonLogs = _STORED_MESSAGES[i].log;

					line = formatMessage(logItem);

					if (line.length > 0)
						logFile.writeString('[${_STORED_MESSAGES[i].time}] [${_STORED_MESSAGES[i].type}]: $line\n');
				}

				logFile.flush();
				_STORED_MESSAGES.resize(0);
			}, 99);
		}
	}

	private static function formatMessage(logItem:CommonLogs):String
	{
		switch (logItem)
		{
			case Custom(message):
				return '$message';
			case NoChart(folder, file):
				return 'The game was not able to find a chart data for $file. ($folder)';
		}
	}

	public static function error(log:LogItem, ?printLevel:PrintLevel = FLIXEL, ?silent:Bool, ?info:haxe.PosInfos):Void
	{
		silent ??= DEFAULT_SILENT;
		_print(log, printLevel, ERROR, silent, info);
	}

	public static function warn(log:LogItem, ?printLevel:PrintLevel = FLIXEL, ?silent:Bool, ?info:haxe.PosInfos):Void
	{
		silent ??= DEFAULT_SILENT;
		_print(log, printLevel, WARNING, silent, info);
	}

	public static function info(log:LogItem, ?printLevel:PrintLevel = CONSOLE, ?silent:Bool, ?info:haxe.PosInfos):Void
	{
		silent ??= DEFAULT_SILENT;
		_print(log, printLevel, INFO, silent, info);
	}

	private static function renderMethod():String
	{
		try
		{
			return switch (FlxG.renderMethod)
			{
				case FlxRenderMethod.DRAW_TILES: 'DRAW_TILES';
				case FlxRenderMethod.BLITTING: 'BLITTING';
				default: 'UNKNOWN';
			}
		} catch (e)
		{
			return 'ERROR ON QUERY RENDER METHOD: ${e}';
		}
	}

	private static function formatPosInfo(v:String, infos:haxe.PosInfos):String
	{
		if (infos == null)
			return v;

		var infoStr:String = '${infos.fileName}:${infos.lineNumber}';

		if (infos.customParams != null)
		{
			for (value in infos.customParams)
			{
				infoStr += ", " + Std.string(value);
			}
		}

		return infoStr + ": " + v;
	}
}

typedef LogItem = OneOfThree<CommonLogs, String, Dynamic>;

typedef Message =
{
	var type:Type;
	var time:String;
	var log:CommonLogs;
};

enum abstract PrintLevel(String)
{
	var CONSOLE:PrintLevel;
	var LOG_ONLY:PrintLevel;
	var FLIXEL:PrintLevel;
}

enum abstract Type(String)
{
	var INFO:Type;
	var NOTICE:Type;
	var WARNING:Type;
	var ERROR:Type;
}

enum CommonLogs
{
	Custom(message:String);
	NoChart(folder:String, file:String);
}
