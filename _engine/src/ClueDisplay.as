/* See the file "LICENSE.txt" for the full license governing this code. */
package
{
import com.gskinner.motion.GTween;
import flash.accessibility.Accessibility;
import flash.accessibility.AccessibilityProperties;
import flash.display.InteractiveObject;
import flash.display.MovieClip;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.FocusEvent;
import flash.events.KeyboardEvent;
import flash.events.MouseEvent;
import flash.events.TimerEvent;
import flash.geom.Rectangle;
import flash.text.TextField;
import flash.ui.Keyboard;
import flash.utils.Timer;
import nm.events.StandardEvent;
import nm.ui.AlertWindow;

public class ClueDisplay extends MovieClip
{
	/**
	 * This class handles a clip that we will get from the crossword swc.
	 * It is used by the scrolling list that shows the crossword clues
	 * I did not just have that class in the swc. Maybe it should?
	 */
	// This will get initialized before any ClueDisplays are made
	// Clip is found in the Flash file that makes the swc.
	// SymbolNamed: ClueDisplay_MC
	// It has the following fields:
	//  clueText: TextField
	//  hintText: TextField
	//	questionNumber: TextField
	//	getHint: MovieClip
	//	freeWord: MovieClip
	//  clueHintDivider -> a graphic between the clue and hint
	//  dividerLine -> a graphic at the bottom to separate items
	//  selectionIndicator -> a graphic to show if this is selected
	//  acrossOrDownText
	// MORE WILL BE ADDED
	public static var movieClipAssets:Class;

	// this will be given this ClueDisplay when it is init
	// it can be used to retrieve if we have free words
	// is this a weird way to do it?
	public var doesUserHaveFreeWords:Function;
	// will be dispatched when this is clicked, or selected in some other way
	public static const EVENT_CLUE_SELECTED:String = "EVENT_CLUE_SELECTED";
	public static const EVENT_CLUE_CLICKED:String = "EVENT_CLUE_CLICKED";
	public static const EVENT_FREE_WORD_CLICKED:String = "EVENT_FREE_WORD_CLICKED";
	public static const EVENT_HINT_USED:String = "EVENT_HINT_USED";
	public static const EVENT_RESIZED:String = "EVENT_RESIZED";

	public var actualWord:String;
	public var indexInCrosswordWordReference:int;

	// functions for easy access to the assets
	protected function get _clueText():TextField{return _assets.clueText;}
	protected function get _hintText():TextField{return _assets.hintText;}
	protected function get _questionNumberText():TextField{return _assets.questionNumber;}
	protected function get _getHint():MovieClip{return (_assets.getHint);}
	protected function get _freeWord():MovieClip{return (_assets.freeWord);}
	protected function get _clueHintDivider():MovieClip{return _assets.clueHintDivider;}
	//protected function get _dividerLine():MovieClip{return _assets.dividerLine;}
	// NOTE: we are re-parenting the divider line off the _assets for easy making of _assets ( without masking divider)
	protected var _dividerLine:MovieClip;
	protected var _assets:MovieClip;
	protected var _isDown:Boolean;
	protected var _isSelected:Boolean = false;
	protected var _questionNumber:int;
	protected var _correctAnswer:String = '';
	protected var _hasShownHint:Boolean = false;
	protected var _background:Sprite;
	protected var _core:Engine;
	protected var _currentHeight:Number = 100;

	private var _clueString:String = "";


	public function get isDown():Boolean
	{
		return _isDown;
	}

	public function get isAcross():Boolean
	{
		return ! _isDown;
	}

	public function get questionNumber():int
	{
		return questionNumber;
	}

	protected function get _selectionIndicator():MovieClip
	{
		return _assets.selectionIndicator;
	}

	// this is used to get the height we will tell the clue bank that we are
	// it is based on the items visible, not the actual height of the movieclip
	public function getHeight():Number
	{
		return _currentHeight;
	}
	protected var _freeWordUsed:Boolean = false; // if a free word has been used on this clue
	function ClueDisplay(core:Engine)
	{
		this.accessibilityProperties = new AccessibilityProperties();
		this.focusRect = false;
		_core = core;
		_background = new Sprite();
		addChild(_background);
		_assets = new movieClipAssets();
		addChild(_assets);
		_assets.questionNumber.selectable = false;
		_assets.acrossOrDownText.selectable = false;
		_clueText.selectable = false;
		_clueText.mouseEnabled = false;
		_hintText.selectable = false;
		_hintText.mouseEnabled = false;
		_getHint.addEventListener(MouseEvent.CLICK, getHintClick, false, 0, true);
		_freeWord.addEventListener(MouseEvent.CLICK, freeWordClick, false, 0, true);
		_getHint.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown, false, 0, true);
		_freeWord.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown, false, 0, true);
		_getHint.accessibilityProperties = new AccessibilityProperties();
		_getHint.accessibilityProperties.name = "Get Hint";
		_getHint.accessibilityProperties.silent = false;
		_freeWord.accessibilityProperties = new AccessibilityProperties();
		_freeWord.accessibilityProperties.name = "Free Word";
		_freeWord.accessibilityProperties.silent = false;
		this.addEventListener(MouseEvent.CLICK, doSelectThis, false, 0, true);
		// the initial state of the clip
		hint = ''; // for if no hint is set, make sure the text field gets sized
		_selectionIndicator.visible = false;
		_clueHintDivider.visible = false;
		_hintText.visible = false;
		_getHint.visible = false;
		_freeWord.visible = false;
		_dividerLine = _assets.dividerLine;
		_assets.removeChild(_dividerLine);
		addChild(_dividerLine);
		positionElements();
		addEventListener(FocusEvent.FOCUS_IN, onFocusIn, false, 0, true);
	}

	public function refreshDisplay():void
	{
		positionElements();
		// TODO: check on what should and should not be visible?
	}
	protected var _theTween:GTween;
	// set the positions for all the elements, based on if they are visible or not
	protected function positionElements(doTween:Boolean = false):void
	{
		const PADDING:Number = 10.0;
		var originalHeight:Number = _currentHeight;
		var curY:Number = _clueText.y + _clueText.height + PADDING;
		// clue at top -> always visible, wont move
		// then clue hint divider
		if(_hintText.visible == true)
		{
			_clueHintDivider.y = curY ;
			curY += _clueHintDivider.height + PADDING;
			// then hint
			_hintText.y = curY;
			curY += _hintText.height + PADDING;
		}
		if( _isSelected == true && (_getHint.visible == true || _freeWord.visible == true))
		{
			// then buttons
			// HACKY CODE: hardcoding values to push it down away from the # and the down/across thing
			if(curY < 45.0)
			{
				curY = 45.0;
			}
			_getHint.y = curY;
			_freeWord.y = curY;
			curY += _getHint.height + PADDING;
		}
		// else if (_isSelected == true && _getHint.visible == false)
		// give it a minimum height
		if(curY < 50.0)
		{
			curY = 50.0;
		}
		const TWEEN_SPEED:Number = 0.4;
		removeEventListener(Event.ENTER_FRAME, fixScrollRect);
		if(_theTween)
		{
			_theTween.paused = true;
		}
		// this add's padding to the bottom
		curY += PADDING;
		// then divider line
		if(doTween)
		{
			_theTween = new GTween(_dividerLine, TWEEN_SPEED, {y:curY+5}, {ease: customTween});
			_theTween.onComplete = tweenComplete;
			addEventListener(Event.ENTER_FRAME, fixScrollRect, false, 0, true);
		}
		else
		{
			_dividerLine.y = curY+5;
			_assets.scrollRect = new Rectangle(0,-5,this.width, _dividerLine.y - 6.0 );
		}
		// now size the selection indicator
		if( _isSelected == true)
		{
			_selectionIndicator.height = curY - PADDING +2 //- 15;
		}
		_currentHeight = curY;
		// we need a backgroud clip that can be clicked
		_background.graphics.clear();
		_background.graphics.beginFill(0xFFFFFF,0.0);
		_background.graphics.drawRect(0,0, this.width, curY);
		_background.graphics.endFill();
		if(_currentHeight != originalHeight)
		{
			dispatchEvent(new Event(EVENT_RESIZED));
		}
	}
	protected function fixScrollRect(e:Event):void
	{
		e.target.removeEventListener(Event.COMPLETE, fixScrollRect);
		_assets.scrollRect = new Rectangle(0,-5,this.width, _dividerLine.y - 6.0 );
	}
//	protected function tweenComplete(e:Event):void
	protected function tweenComplete(g:GTween):void
	{
		removeEventListener(Event.ENTER_FRAME, fixScrollRect);
		dispatchEvent(new Event("TWEEN_DONE"));
	}
	protected static function customTween(t:Number, b:Number, c:Number, d:Number):Number
	{
		var ts:Number=(t/=d)*t;
		var tc:Number=ts*t;
		return b+c*(0*tc*ts + -1*ts*ts + 4*tc + -6*ts + 4*t);
	}

	public function set clueText(s:String):void
	{
		_assets.clueText.text = s;
		_assets.clueText.autoSize = "left";
		_clueString = "Clue for: " + _assets.questionNumber.text + " " + _assets.acrossOrDownText.text + ".";
		if(s != "") _clueString += " " + s;
		this.accessibilityProperties.name = _clueString;
	}

	public function set questionNumber(i:int):void
	{
		_questionNumber = i;
		_assets.questionNumber.text = i + ".";
	}
	// give this a hint
	public function set hint(s:String):void
	{
		if(s == null)
		{
			s = ""; // This might not necessary when QSets are fixed.
		}
		else
		{
			if(s != "")
			{
				this.accessibilityProperties.name += " Hint Available.";
			}
		}
		_assets.hintText.text = s;
		_assets.hintText.autoSize = "left";
	}

	public function set correctAnswer(s:String):void
	{
		_correctAnswer = s;
	}

	public function set isDown(b:Boolean):void
	{
		_isDown = b;
		if(b)
		{
			_assets.acrossOrDownText.text = "down";
		}
		else
		{
			_assets.acrossOrDownText.text = "across";
		}
	}

	public function set isAcross(b:Boolean):void
	{
		_isDown = ! b;
		if(b)
		{
			_assets.acrossOrDownText.text = "across";
		}
		else
		{
			_assets.acrossOrDownText.text = "down";
		}
	}

	protected function doSelectThis(e:Event = null):void
	{
		dispatchEvent(new Event(EVENT_CLUE_CLICKED, true));
		select(!e?false:true);
	}

	// NOTE: we need to do some checking to keep track selecting and unselecting?
	public function select(usedTab:Boolean = false):void
	{
		if(_isSelected == true)
		{
			return; // no need to select it if it already is
		}
		// display that it is selected
		// display the options for it
		// this will happen by playing the select animation defined in the swf
		// I was going to start/stop listening to item height changes
		// im going to test responding to heigh changes all the time
		_assets.freeWord.visible = (! _freeWordUsed && doesUserHaveFreeWords());
		if(_hintText.text != '')
		{
			if(_hasShownHint)
			{
				_getHint.visible = false;
				_hintText.visible = true;
				_clueHintDivider.visible = true;
			}
			else
			{
				_getHint.visible = true;
				_clueHintDivider.visible = false;
				_clueHintDivider.visible = false;
			}
		}
		else
		{
			_getHint.visible = false;
			_clueHintDivider.visible = false;
			_hintText.visible = false;
		}
		_assets.selectionIndicator.visible = true;
		_isSelected = true;
		positionElements(usedTab);
		if(!usedTab) addEventListener("TWEEN_DONE", resetFocusAfterTween, false, 0, true);
		dispatchEvent(new Event(EVENT_CLUE_SELECTED, true));
	}

	public function deselect():void
	{
		// NOTE: TODO: make an un select animation
		if(_isSelected == false)
		{
			return; // no need to re-unselect if it is not slected
		}
		_assets.selectionIndicator.visible = false;
		_isSelected = false;
		_getHint.visible = false;
		_getHint.y = 0; // so it gets out of the way of determining the height of this thing
		_freeWord.visible = false
		_freeWord.y = 0;
		positionElements();
	}
	protected function freeWordClick(e:MouseEvent = null):void
	{
		_freeWordUsed = true;
		_freeWord.visible = false;
		_getHint.visible = false;
		_clueString += " This word is " + actualWord;
		this.accessibilityProperties.name = _clueString;
		dispatchEvent(new Event(EVENT_FREE_WORD_CLICKED,true));

		if(Accessibility.active)
		{
			var hackHolder:ClueDisplay = this;
			Accessibility.updateProperties();
			var hack:Timer = new Timer(250,1);
			hack.start();
			hack.addEventListener(TimerEvent.TIMER_COMPLETE, refocus);
			function refocus(e:TimerEvent):void
			{
				hack.removeEventListener(TimerEvent.TIMER_COMPLETE, refocus);
				stage.focus = hackHolder;
			}
		}
	}
	protected function getHintClick(e:MouseEvent = null):void
	{
		if(_core.hintCost > 0)
		{
			var penaltyMsg:String = "Using a hint will result in a " + _core.hintCost + "% score penalty for this word.";
			if(!e)
			{
				penaltyMsg += "\n\nPress the confirm key to use a hint on this word, or any other key to cancel.";
				if(Accessibility.active) penaltyMsg += "\n\nThere are " + _core.hintsRemaining() + " hints remaining.";
			}
			var alert:AlertWindow = AlertWindow(_core.alert("Using Hint", penaltyMsg, AlertWindow.OKCANCEL));
			alert.addEventListener("dialogClick", getHintClickConfirmed, false, 0, true);

			alert._x = (stage.stageWidth - alert.width)/2;
			alert._y = (stage.stageHeight - alert.height)/2;

			var alertBox:MovieClip = alert.getChildAt(1) as MovieClip;
			if(Accessibility.active)
			{
				alertBox.accessibilityProperties = new AccessibilityProperties();
				alertBox.accessibilityProperties.name = penaltyMsg;
				Accessibility.updateProperties();
			}
			if(!e)
			{
				stage.focus = alertBox;
				alertBox.addEventListener(KeyboardEvent.KEY_DOWN, alertOnKeyDown, false, 0, true);
				function alertOnKeyDown(e:KeyboardEvent):void
				{
					alertBox.removeEventListener(KeyboardEvent.KEY_DOWN, alertOnKeyDown);
					switch(e.keyCode)
					{
						case Keyboard.NUMPAD_5:
						case Keyboard.ENTER:
							alert.spoofButtonClick(true);
							break;

						default:
							alert.spoofButtonClick(false);
							stage.focus = this;
							break;
					}
				}
			}
		}
		else
		{
			getHintClickConfirmed(new StandardEvent("dialogClick", true));
		}
	}
	protected function getHintClickConfirmed(e:StandardEvent):void
	{
		if(e.result) // If YES/OK was clicked
		{
			_hasShownHint = true;
			_hintText.visible = true;
			_clueHintDivider.visible = true;
			_getHint.visible = false;
			positionElements();
			dispatchEvent( new Event( EVENT_HINT_USED, true) );
			_clueString += " " + _hintText.text;
			this.accessibilityProperties.name = _clueString;
			if(Accessibility.active)
			{
				var hackHolder:ClueDisplay = this;
				Accessibility.updateProperties();
				var hack:Timer = new Timer(250,1);
				hack.start();
				hack.addEventListener(TimerEvent.TIMER_COMPLETE, refocus);
				function refocus(e:TimerEvent):void
				{
					hack.removeEventListener(TimerEvent.TIMER_COMPLETE, refocus);
					stage.focus = hackHolder;
				}
			}
			else
			{
				stage.focus = this;
			}
		}
	}
	private function onKeyDown(event:KeyboardEvent):void
	{
		if(event.keyCode == Keyboard.NUMPAD_5 || event.keyCode == Keyboard.SPACE || event.keyCode == Keyboard.ENTER)
		{
			switch(event.target)
			{
				case _getHint: { getHintClick(); break; }
				case _freeWord: { freeWordClick(); break; }
			}
		}
	}
	private function resetFocusAfterTween(e:Event):void
	{
		removeEventListener("TWEEN_DONE", resetFocusAfterTween);
		stage.focus = this;
	}
	private function onFocusIn(e:FocusEvent):void
	{
		doSelectThis();
	}

	public function setButtonTabIndices():void
	{
		_getHint.tabIndex = this.tabIndex+1;
		_freeWord.tabIndex = this.tabIndex+2;
	}
}
}