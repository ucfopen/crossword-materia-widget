/* See the file "LICENSE.txt" for the full license governing this code. */
package
{
import flash.accessibility.Accessibility;
import flash.accessibility.AccessibilityProperties;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.FocusEvent;
import flash.events.MouseEvent;
import flash.text.TextField;
import flash.text.TextFieldAutoSize;
import flash.text.TextFormat;
/**
 * This class creates a space in the crossword puzzle. This space is aware of its location (based on its name) and
 * what letter it should contain to be considered correct.
 *
 * @author	Scott Rapp
 */
public class CrosswordSpace extends Sprite
{
	//--------------------------------------------------------------------------
	//
	//  Variables
	//
	//--------------------------------------------------------------------------
	/**
	 *  1 if the word is across, 2 if the word is down, 3 if the space is an intersection.
	 */
	public var isAcross:Boolean;
	public var cellNum:TextField
	public var csx:Number
	public var csy:Number
	public var wordNum:Array;
	public var wordsUsedIn:Array = []; // this will be filled with data based on CrosswordPuzzle's word reference
	// it is used to quickly see which words a space is used in
	private var _label:TextField
	/**
	 *  The correct answer.
	 */
	private var letter:String;
	/**
	 *  A default value for the space and crossword puzzle's size. Used during creation and testing.
	 */
	private var boxSize:Number;
	private var acrossId:String;
	private var downId:String;
	private var labelFormat:TextFormat
	private var numberFormat:TextFormat
	private var _spaceNameString:String;
	//--------------------------------------------------------------------------
	//
	//  Constructor
	//
	//-------------------------------------------------------------------------
	/**
	 * This function initializes the space and creates the movieclip and its functionality as a button.
	 *
	 * @usage   var CWspace = new CrosswordSpace(xLoc, yLoc, WordBank[a].across, WordBank[a].word.charAt(b), CWcolor, crossword_mc, this, showAnswers, isPlayable);
	 * @param   x           Number. The X coordinate for the space.
	 * @param   y           Number. The Y coordinate for the space.
	 * @param   across      Boolean. Whether the space is across only, down only, or both.
	 * @param   character   String. The correct value for the space.
	 * @param   CWcolor     Object. An object containing the color data for the space.
	 * @param   puzzle      MovieClip. The movieclip containing the spaces in the puzzle.
	 * @param   parentClass Object. The parent class of the space, usually CrosswordViewer.
	 * @param   showAnswers Boolean. Whether or not to display the correct answer upon creation. (used for answer key)
	 * @param   playable    Boolean. Whether or not to allow the crossword space to be a button. (used for print previewing)
	 */
	public function CrosswordSpace (x:Number, y:Number, size:Number, across:Boolean, character:String, spaceColor:Number, lineColor:Number, showAnswer:Boolean, playable:Boolean, cellFormat:TextFormat, numberFormat:TextFormat)
	{
		this.mouseChildren = false;
		this.accessibilityProperties = new AccessibilityProperties();
		//initialization
		letter = character;
		boxSize = size;
		labelFormat = cellFormat
		isAcross = across;
		this.numberFormat = numberFormat
		this.x =  x;
		this.y =  y;
		//Draw the crossword space graphics(box enclosing the letters)
		with(graphics)
		{
			beginFill(isSpace ? lineColor : spaceColor);
			drawRect(0, 0, boxSize, boxSize);
			endFill();
			lineStyle(1, lineColor);
			drawRect(0, 0, boxSize, boxSize);
		}
		//Create label for the letter to go in the box
		if (!isSpace)
		{
			_label = new TextField();
			_label.x = 3;
			_label.y = 2;
			_label.width = boxSize - 4;
			_label.height = boxSize - 2;
			_label.defaultTextFormat = labelFormat;
			_label.name = 'txt';
			_label.selectable = false;
			labelFormat.align = "center";
			_label.setTextFormat(labelFormat);
			this.addChild(_label);
		}
		//showLabel = showAnswer;
		this.playable = playable
		if(showAnswer || !isGuessable) label = character
		cellNum = new TextField();
		cellNum.selectable = false;
		cellNum.setTextFormat(numberFormat);
		cellNum.defaultTextFormat = numberFormat;
		cellNum.autoSize = TextFieldAutoSize.LEFT;
		this.addChild(cellNum);
		this.focusRect = false;
		this.tabEnabled = false;
		_spaceNameString = "Empty Cell";
		wordNum = new Array();
	}
	//--------------------------------------------------------------------------
	//
	//  Member Functions
	//
	//-------------------------------------------------------------------------
	/**
	 * This function creates a reference for the space to its across and/or down word's Question ID.
	 *
	 * @usage   CWspace.setId(415, true);
	 * @param   di     String. The ID of the word the space is in.
	 * @param   aToggle Boolean. Whether the word is across or down. Across is true.
	 */
	public function setId(id:String, aToggle:Boolean):void
	{
		if(aToggle) acrossId = id;
		else downId = id;
	}
	/**
	 * This function returns the stored reference of the Question ID related to this space.
	 *
	 * @usage   CWspace.getId(true);
	 * @param   aToggle Boolean. Whether you want the QID of the across or down word. Across is true.
	 * @return
	 */
	public function getId (aToggle:Boolean):String
	{
		// if theres an intersection require aToggle, default to verticle
		if(intersection) return aToggle ? acrossId : downId;
		// if there isnt an intersection, just return the qid for this word
		else return acrossId == null ?  downId : acrossId;
	}
	public function showAnswer():void
	{
		showLabel = true
		label = letter;
	}
	public function get intersection():Boolean
	{
		return downId != null && acrossId != null;
	}
	public function set playable(val:Boolean):void
	{
		if(val){
			showLabel = true
		}
		//else this.removeEventListener(MouseEvent.MOUSE_UP);
	}
	public function get playable():Boolean
	{
		return this.hasEventListener(MouseEvent.MOUSE_UP);
	}
	public function get isCorrect():Boolean
	{
		return (letter == _label.text);
	}
	public function set showLabel(val:Boolean):void
	{
		if (val)
		{
			// only create if it doesnt already exist and this isnt a space (spaces dont need textfields)
			if (_label == null && !isSpace)
			{
				_label = new TextField();
				_label.x = 3;
				_label.y = 2;
				_label.width = boxSize - 4;
				_label.height = boxSize - 2;
				_label.name = 'txt';
				_label.selectable = false;
				labelFormat.align = "center";
				_label.setTextFormat(labelFormat);
				_label.text = "";
				this.addChild(_label);
			}
		}
		else
		{
			if(_label) _label.visible = false;
			//_label.removeTextField();
		}
	}
	public function get label():String
	{
		if(_label == null)
		{
			return ' ';
		}
		return _label.text.length > 0 ?  _label.text : ' ';
	}
	public function lock():void
	{
		graphics.beginFill(0x000000, 0.0749);
		graphics.drawRect(0, 0, boxSize, boxSize);
		graphics.endFill();
		if(_label != null)
		{
			_label.setTextFormat(new TextFormat(null,null,0x666666));
		}
		_lock = true;
	}
	protected var _lock:Boolean = false;
	public function set label(val:String):void
	{
		if(_lock) return;
		if(_label)
		{
			showLabel = true
			_label.text = val;
			if(val == " ")
			{
				this.accessibilityProperties.name = _spaceNameString + "Empty Cell";
			}
			else
			{
				this.accessibilityProperties.name = _spaceNameString + val;
			}
			if(Accessibility.active) Accessibility.updateProperties();
		}
	}
	public function set cellNumber(val:Number):void
	{
		if (cellNum == null)
		{
			cellNum = new TextField();
			cellNum.setTextFormat(numberFormat);
			cellNum.selectable = false;
			cellNum.autoSize = TextFieldAutoSize.LEFT;
			this.addChild(cellNum);
		/*
			cellNum = createTextField("num", 1, 0, 0, 0, 0);
			cellNum.selectable = false;
			cellNum.autoSize = "left";
			cellNum.setNewTextFormat(numberFormat);
			*/
		}
		cellNum.text = String(val);
	}
	public function get isSpace():Boolean
	{
		return letter == ' ';
	}
	public function get isGuessable():Boolean
	{
		var n:Number = letter.charCodeAt(0)
		return  ((n>64 && n<91) /* [A-Z] */ || (n>96 && n<123) /* [a-z] */ || (n>47 && n<58) /* [0-9] */ ) && !isSpace;
	}
	public function get cellNumber():Number
	{
		return parseInt(cellNum.text);
	}
	public function initialName():void
	{
		_spaceNameString = "Cell: ";
		for each(var a:Array in wordNum)
		{
			_spaceNameString += a[0] + " ";
			if(a[1])
			{
				_spaceNameString += "Across, ";
			}
			else
			{
				_spaceNameString += "Down, ";
			}
		}
		_spaceNameString += " Value: ";
		this.accessibilityProperties.name = _spaceNameString + "Empty Cell";
		if(Accessibility.active) Accessibility.updateProperties();
	}
}
}