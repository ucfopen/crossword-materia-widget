/* See the file "LICENSE.txt" for the full license governing this code. */
package
{
import flash.accessibility.Accessibility;
import flash.accessibility.AccessibilityProperties;
import flash.display.DisplayObject;
import flash.display.GradientType;
import flash.display.InteractiveObject;
import flash.display.MovieClip;
import flash.display.SimpleButton;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.KeyboardEvent;
import flash.events.MouseEvent;
import flash.geom.Matrix;
import flash.text.TextField;
import flash.text.TextFieldAutoSize;
import flash.text.TextFormat;
import flash.ui.Keyboard;
import nm.events.StandardEvent;
import nm.gameServ.common.logging.Log;
import nm.gameServ.engines.EngineCore;
import nm.ui.AlertWindow;
import nm.ui.Window;
import nm.ui.layout.CenterScale;
import nm.util.Printer;
/**
* Stage Size: 635x503
*/
public class Engine extends EngineCore
{
	//--------------------------------------------------------------------------
	//
	//  Variables from Flash SWC files
	//
	//--------------------------------------------------------------------------
	protected var _crosswordArea:MovieClip;
	protected var _crosswordAreaBG:MovieClip;
	protected var _clueArea:MovieClip;
	protected var _Button:MovieClip;
	protected var _finishGameButton:MovieClip;
	protected var _printGameButton:MovieClip;
	protected var _keyboardHelpButton:MovieClip;
	protected var _hintsRemaining:TextField;
	protected var _freeWordsRemaining:TextField;
	protected var _gameTitle:TextField;
	protected var _mainClip:MovieClip;
	protected var _clueBankPageUp:SimpleButton;
	protected var _clueBankPageDown:SimpleButton;
	protected var _zoomOutButton:SimpleButton;
	protected var _zoomInButton:SimpleButton;
	protected var _clueDisplayClass:Class; // we will use this to pass in the type of the clue display boxes
	protected var grabZoom:CrosswordGrabZoomClip;
	protected var _numHintsTotal:int = 0;
	protected var _isFirstSelection:Boolean = true; // we are going to zoom in (if there are 3 zoom levels) on the first click
	protected var _clueBank:CrossWordClueBank;
	protected static const CLUE_BANK_TWEEN_DURATION:Number =  0.4;
	protected var _selectedClueDisplay:ClueDisplay = null;
	protected var _clueBankContainer:MovieClip;
	protected var _indexer:int = 1999; //arbitrary, but it's unlikely anybody will have 200+ words
	protected var _helpWindow:AlertWindow;
	// this has the text, numbering, some option buttons, and more
	protected var viewWidth:int = 423;
	protected var viewHeight:int = 419;
	//--------------------------------------------------------------------------
	//
	//  Variables
	//
	//--------------------------------------------------------------------------
	/**
	 *  Used to alert the engine that the clues have been changed since the last time they were updated.
	 */
	public var updateClues:Boolean;
	public var hintCost:Number;
	private var availFreeWords:Number;
	private var CWView:CrosswordPuzzle;
	private var layout:Layout;
	private var printClues:Boolean;
	private var printer:Printer
	private var printPuzzle:Boolean;
	private var showingClues:Boolean;
	private var showingHint:Boolean;
	private var showLetters:Boolean;
	private var usedFreeWords:Number
	private var usedHints:Number;
	private var windows:MovieClip;
	private var zoomButtonDown:Boolean = false;
	private var cluesButtonDown:Boolean = false;
	private var freeWordButtonDown:Boolean = false;
	private var hintButtonDown:Boolean = false;
	private var printButtonDown:Boolean = false;
	private var submitButtonDown:Boolean = false;
	private var windowedPrintButtonDown:Boolean = false;
	private var windowedCloseButtonDown:Boolean = false;

	public function Engine():void
	{
		var mainClip:MainClip = new MainClip();
		addChild(mainClip);
		setChildIndex(mainClip,0);
		_crosswordAreaBG       = mainClip.puzzleArea;
		_crosswordAreaBG.alpha = 0;
		_clueArea              = mainClip.clueArea;
		_finishGameButton      = mainClip.finishGameButton;
		_printGameButton       = mainClip.printGameButton;
		_keyboardHelpButton    = mainClip.keyboardButton;
		_hintsRemaining        = mainClip.hintsRemaining;
		_freeWordsRemaining    = mainClip.freeWordsRemaining;
		_gameTitle             = mainClip.gameTitle;
		_mainClip              = mainClip;
		_keyboardHelpButton.tabIndex = 0;
		if(!Accessibility.active) _printGameButton.tabIndex = 1; //only tab-to-able when not blind
		_clueBankPageUp = mainClip.clueBankPageUp;
		_clueBankPageUp.accessibilityProperties = new AccessibilityProperties();
		_clueBankPageUp.accessibilityProperties.name = "Page Up";
		_clueBankPageDown = mainClip.clueBankPageDown;
		_clueBankPageDown.accessibilityProperties = new AccessibilityProperties();
		_clueBankPageDown.accessibilityProperties.name = "Page Down";
		_clueBankPageUp.tabIndex = 2; // always 2, print button is always 1, help button is always 0
		//+3 and +4 because the lowest clue might have two buttons in it
		_clueBankPageDown.tabIndex = _indexer+3; //arbitrary, just has to be the second highest
		_finishGameButton.tabIndex = _indexer+4; //arbitrary, just has to be the highest number
		_finishGameButton.accessibilityProperties = new AccessibilityProperties();
		_finishGameButton.accessibilityProperties.name = "Finish";
		_keyboardHelpButton.accessibilityProperties = new AccessibilityProperties();
		_keyboardHelpButton.accessibilityProperties.name = "Keyboard Help";
		_zoomInButton = mainClip.zoomInButton;
		_zoomOutButton = mainClip.zoomOutButton;
		_zoomInButton.tabEnabled = false;
		_zoomOutButton.tabEnabled = false;
		_clueDisplayClass = ClueDisplay_MC;
		CrossWordClueBank.scrollBarBackgroundGraphic = scrollBarBackground;
		CrossWordClueBank.scrollBarHandleGraphic = scrollBarHandle;
		CrossWordClueBank.scrollBarControlGraphic = scrollBarControl;
		CrosswordPuzzle.crossWordBackground = CrossWordBackground;
		super();
	}

	//--------------------------------------------------------------------------
	//
	//  Override Functions
	//
	//--------------------------------------------------------------------------
	protected override function startEngine():void
	{
		super.startEngine();
		//Check if data is meant for crossword
		if(!qSetData.items.length || !qSetData.items[0].items.length || qSetData.items[0].items[0].options == null)
		{
			alert("Incorrect Data Format", "The given data was not meant for this program and may not function properly.",1);
		}
		/***** Initiate Variables *****/
		//Set defaults
		showingClues   = false;
		showLetters    = true;
		printPuzzle    = true;
		printClues     = true;
		updateClues    = true;
		showingHint    = false
		usedHints      = 0;
		usedFreeWords  = 0;
		availFreeWords = Number(qSetData.options.freeWords);
		hintCost       = Number(qSetData.options.hintPenalty);
		//Compensate for faulty variables
		if(isNaN(availFreeWords))
		{
			availFreeWords = 2
		}
		if(isNaN(hintCost))
		{
			hintCost = 100;
		}
		//Remove questions that aren't in the puzzle
		removeUnplacedWords(qSetData);
		/***** Load the Puzzle *****/
		_crosswordArea = new MovieClip();
		_mainClip.addChild(_crosswordArea);
		_crosswordArea.x = _crosswordAreaBG.x
		_crosswordArea.y = _crosswordAreaBG.y
		_crosswordArea = new MovieClip();
		_mainClip.addChild(_crosswordArea);
		_crosswordArea.x = _crosswordAreaBG.x
		_crosswordArea.y = _crosswordAreaBG.y
		_crosswordArea.graphics.beginFill(0, 0);
		_crosswordArea.graphics.drawRect(0, 0, 400, 400); // draw the background transparent, used to regulate the size of the cw puzzle
		_crosswordArea.graphics.endFill();
		// TODO: does this draw twice?
		_crosswordArea.graphics.beginFill(0, 0);
		_crosswordArea.graphics.drawRect(0, 0, 400, 400); // draw the background transparent, used to regulate the size of the cw puzzle
		_crosswordArea.graphics.endFill();
		//Draw/Create background, boxes, and buttons
		layout = new Layout(_crosswordArea);//this);
		_gameTitle.text = inst.name
		viewWidth = _crosswordAreaBG.width;
		viewHeight = _crosswordAreaBG.height;
		grabZoom = new CrosswordGrabZoomClip(_crosswordAreaBG.x, _crosswordAreaBG.y, _crosswordAreaBG.width, _crosswordAreaBG.height);
		addChild(grabZoom);
		// move the zoom buttons in front of grab zoom
		addChild(_zoomInButton);
		addChild(_zoomOutButton);
		//Create the actual puzzle
		CWView = new CrosswordPuzzle(qSetData, true, false);
		CWView.addEventListener(CrosswordPuzzle.EVENT_WORD_SELECTED, crosswordWordSelected, false, 0, true);
		CWView.addEventListener(CrosswordPuzzle.EVENT_WORD_FOCUS, crosswordWordClueFocus, false, 0, true);
		CWView.addEventListener(MouseEvent.MOUSE_WHEEL, relayMouseWheel, false, 0, true);
		grabZoom.content.addChild(CWView);
		//Zoom to fit puzzle into window
		grabZoom.centerAndShowAllContent();
		//Add event for clicking on word boxes
		CWView.addEventListener('selectWord', handle_SelectWord, false, 0, true);
		//Set help text
		_freeWordsRemaining.text = ""+(availFreeWords - usedFreeWords)
		// NOTE: some of these are not being used anymore
		//Set up button listeners
		initButtons();
		grabZoom.addEventListener(CrosswordGrabZoomClip.EVENT_ZOOM_CHANGED, showZoomButtons, false, 0, true);
		showZoomButtons();
		stage.addEventListener(MouseEvent.MOUSE_UP, handle_StageMouseUp, false, 0, true);
		// this gives the SWC assseets to the ClueDisplay class
		ClueDisplay.movieClipAssets = _clueDisplayClass;
		initClueDisplaysList();
		// initClueDisplaysList will count up _numHintsTotal
		_hintsRemaining.text = _numHintsTotal + "";
		windows = new MovieClip();
		addChild(windows);
		addEventListener(KeyboardEvent.KEY_DOWN, checkZoom);
		if(Accessibility.active)
		{
			Accessibility.updateProperties();
			addEventListener(MouseEvent.CLICK, focusHelpInitially);
			addEventListener(KeyboardEvent.KEY_DOWN, focusHelpInitially);
			onKeyboardHelpClick();
		}
	}
	protected function focusHelpInitially(event:Event = null):void
	{
		removeEventListener(MouseEvent.CLICK, focusHelpInitially);
		removeEventListener(KeyboardEvent.KEY_DOWN, focusHelpInitially);
		stage.focus = _helpWindow;
		addEventListener(MouseEvent.CLICK, removeHelpInitially);
		addEventListener(KeyboardEvent.KEY_DOWN, removeHelpInitially);
	}
	protected function removeHelpInitially(event:Event = null):void
	{
		removeEventListener(MouseEvent.CLICK, removeHelpInitially);
		removeEventListener(KeyboardEvent.KEY_DOWN, removeHelpInitially);
		stage.focus = _keyboardHelpButton;
	}
	private function checkZoom(event:KeyboardEvent):void
	{
		switch(event.keyCode)
		{
			case Keyboard.NUMPAD_ADD: case 187: //plus
			{
				zoomIn();
				break;
			}
			case Keyboard.NUMPAD_SUBTRACT: case 189: //minus
			{
				zoomOut();
				break;
			}
		}
	}
	protected function removeUnplacedWords(qSet:Object):void
	{
		if(qSet.items)
		{
			var len:int = qSet.items.length;
			for(var i:int = 0; i < len; i++)
			{
				if(qSet.items[i].options && qSet.items[i].options.hasOwnProperty('posSet') && isFalse(qSet.items[i].options.posSet))
				{
					qSet.items.splice(i, 1);
					i--;
					len--;
				}
				else if(qSet.items[i].items && qSet.items[i].items.length && qSet.items[i].items.length > 0)
				{
					removeUnplacedWords(qSet.items[i]);
				}
			}
		}
	}
	protected function isFalse(val:*):Boolean
	{
		return (val is String && val.toLowerCase() == 'false') || !Boolean(val);
	}
	protected function initButtons():void
	{
		layout.cluesButton.addEventListener(MouseEvent.MOUSE_UP, handle_CluesButtonMouseUp, false, 0, true);
		layout.cluesButton.addEventListener(MouseEvent.MOUSE_DOWN, handle_CluesButtonMouseDown, false, 0, true);
		makeButtonInteractive(layout.cluesButton);
		layout.freeWordButton.addEventListener(MouseEvent.MOUSE_UP, handle_FreeWordButtonMouseUp, false, 0, true);
		layout.freeWordButton.addEventListener(MouseEvent.MOUSE_DOWN, handle_FreeWordButtonMouseDown, false, 0, true);
		makeButtonInteractive(layout.freeWordButton);
		layout.submitButton.addEventListener(MouseEvent.MOUSE_UP, handle_SubmitButtonMouseUp, false, 0, true);
		layout.submitButton.addEventListener(MouseEvent.MOUSE_DOWN, handle_SubmitButtonMouseDown, false, 0, true);
		makeButtonInteractive(layout.submitButton);
		layout.zoomButton.addEventListener(MouseEvent.MOUSE_DOWN, handle_ZoomButtonMouseDown, false, 0, true);
		makeButtonInteractive(layout.zoomButton);
		_zoomInButton.addEventListener(MouseEvent.CLICK, zoomIn, false, 0, true);
		_zoomOutButton.addEventListener(MouseEvent.CLICK, zoomOut, false, 0, true);
		layout.hintButton.addEventListener(MouseEvent.MOUSE_DOWN, handle_HintButtonMouseDown, false, 0, true);
		makeButtonInteractive(layout.hintButton)
		_printGameButton.addEventListener(MouseEvent.MOUSE_UP, handle_PrintPreviewButtonMouseUp, false, 0, true);
		_printGameButton.addEventListener(MouseEvent.MOUSE_DOWN, handle_PrintPreviewButtonMouseDown, false, 0, true);
		_printGameButton.addEventListener(KeyboardEvent.KEY_DOWN, onMainButtonsKeyPress, false, 0, true);
		makeButtonInteractive(_printGameButton);
		//listeners for keyboard button here
		_keyboardHelpButton.addEventListener(MouseEvent.CLICK, onKeyboardHelpClick, false, 0, true);
		_keyboardHelpButton.addEventListener(KeyboardEvent.KEY_DOWN, onMainButtonsKeyPress, false, 0, true);
		makeButtonInteractive(_keyboardHelpButton);
		_finishGameButton.addEventListener(MouseEvent.CLICK, onFinishClick, false, 0, true);
		_finishGameButton.addEventListener(KeyboardEvent.KEY_DOWN, onMainButtonsKeyPress, false, 0, true);
		makeButtonInteractive(_finishGameButton);
	}
	protected function makeButtonInteractive(button:Sprite):void
	{
		button.addEventListener(MouseEvent.ROLL_OVER, Layout.makeHighlight, false, 0, true);
		button.addEventListener(MouseEvent.ROLL_OUT, Layout.removeHighlight, false, 0, true);
		button.buttonMode = true;
	}
	protected function onFinishClick(e:MouseEvent):void
	{
		verifySubmit();
	}
	protected function onMainButtonsKeyPress(e:KeyboardEvent):void
	{
		if(e.keyCode == Keyboard.SPACE || e.keyCode == Keyboard.ENTER || e.keyCode == Keyboard.NUMPAD_5)
		{
			switch(e.target)
			{
				case _keyboardHelpButton: { onKeyboardHelpClick(); break; }
				case _printGameButton: { showPrintPreview(); break; }
				case _finishGameButton: { verifySubmit(); break; }
				default: return;
			}
		}
	}
	// check if the user has free words
	protected function doesUserHaveFreeWords():Boolean
	{
		return ( (availFreeWords - usedFreeWords) > 0);
	}
	//--------------------------------------------------------------------------
	//
	//  Member Functions
	//
	//--------------------------------------------------------------------------
	protected function onClueBankClueSelected(e:Event):void
	{
		var c:ClueDisplay = e.target as ClueDisplay;
		// de-select the previous selected clue in the bank
		if(_selectedClueDisplay)
		{
			_selectedClueDisplay.removeEventListener(ClueDisplay.EVENT_RESIZED, onClueDisplayResize);
			_selectedClueDisplay.deselect();
		}
		_selectedClueDisplay = c;
		_selectedClueDisplay.addEventListener(ClueDisplay.EVENT_RESIZED, onClueDisplayResize, false, 0, true);
		// NOTE: do not call for the CWView to select to word in this function
		// if they clicked in the puzzle, that will have been handeled by the Crossword puzzle
		// if they cliked on a clue display, there is a separate event for that
		// it probably just resized, but, the event would have dispatched before this function
		onClueDisplayResize();
	}
	protected function onClueDisplayResize(e:Event = null):void
	{
		// the re-size should pretty much always happen from _selectedClueDisplay
		_clueBank.scrollToItem(_selectedClueDisplay, true, true); // incase our selected item got kicked off the page
		_clueBank.setScrollBarSizes();
		_clueBank.updateScrollBarPosition();
		showClueBankNavButtons();
	}
	// made using the easing explorer found at http://www.madeinflex.com/img/entries/2007/05/customeasingexplorer.html
	protected static function customTween(t:Number, b:Number, c:Number, d:Number):Number
	{
		var ts:Number=(t/=d)*t;
		var tc:Number=ts*t;
		return b+c*(0*tc*ts + -1*ts*ts + 4*tc + -6*ts + 4*t);
	}
	// called by startengine to init the clues list
	protected function initClueDisplaysList():void
	{
		// putting our clue bank clips on this so we can mask em easy
		_clueBankContainer = new MovieClip();
		addChild(_clueBankContainer);
		_clueBankContainer.x = 0; _clueBankContainer.y = 0;
		// add a transparent fill just to hear mouse wheels over it
		_clueBankContainer.graphics.beginFill(0,0);
		_clueBankContainer.graphics.drawRect(_clueArea.x, _clueArea.y, _clueArea.width, _clueArea.height);
		_clueBankContainer.graphics.endFill();
		_clueBankContainer.mask = _clueArea; // re-purpose the clue area as a mask
		// listen to mouse wheel
		_clueBankContainer.addEventListener(MouseEvent.MOUSE_WHEEL, onClueBankMouseWheel, false, 0, true);
		_clueBank = new CrossWordClueBank(_clueBankContainer);
		_clueBank.setTweenStyle(CLUE_BANK_TWEEN_DURATION, customTween);
		_clueBank.setArea( _clueArea.x, _clueArea.y, _clueArea.width, _clueArea.height);
		_clueBank.addEventListener(CrossWordClueBank.EVENT_PAGE_CHANGED, clueBankPageChange, false, 0, true);
		// our clue displays will tell their heights with getHeight functions instead of just .height
		// they have hidden stuff that messes up the .height
		_clueBank.setItemHeightFunctionField('getHeight');
		// add the items to the list
		var c:ClueDisplay;
		var len:Number = CWView.wordReference.length
		for(var i:Number = len - 1; i >= 0; i--)
		{
			var ref:Object = CWView.wordReference[i];
			if(ref == null) continue;
			c = new ClueDisplay(this);
			if(ref.question.options.dir == '0' || ref.question.options.dir == 'false' )
			{
				c.isAcross = true;
			}
			else
			{
				c.isDown = true;
			}
			c.indexInCrosswordWordReference = i;
			c.questionNumber = ref.index;
			autoIndex(c);
			c.setButtonTabIndices();
			c.clueText = ref.question.questions[0].text;
			c.actualWord = ref.question.answers[0].text;
			c.hint = ref.question.options.hint;
			if(ref.question.options.hint != null && ref.question.options.hint != "")
			{
				_numHintsTotal++;
			}
			_clueBankContainer.addChild(c);
			c.refreshDisplay();
			// NOTE: doing this after c.refreshDisplay() to not get some bad resize events
			initClueDisplayCommunication(c);
			// adding it also after calling c.refreshDisplay()
			_clueBank.addItem(c, false);
			c.tabEnabled = true;
		}
		if(Accessibility.active) Accessibility.updateProperties();
		// prepare clue bank navigation buttons
		_clueBankPageUp.addEventListener(MouseEvent.CLICK, clueBankPageUpFunc, false, 0, true);
		_clueBankPageDown.addEventListener(MouseEvent.CLICK, clueBankPageDownFunc, false, 0, true);
		_clueBankPageUp.addEventListener(KeyboardEvent.KEY_DOWN, clueBankKeyboardNav, false, 0, true);
		_clueBankPageDown.addEventListener(KeyboardEvent.KEY_DOWN, clueBankKeyboardNav, false, 0, true);
		showClueBankNavButtons();
		_clueBank.initScrollBar();
	}
	// this will set up some stuff to track and listen to a clue display
	protected function initClueDisplayCommunication(c:ClueDisplay):void
	{
		// we need to know when it gets selected and clicked
		// select event gets dispatched whenever it goes into the selected state
		// when one is clicked, it calls a clicked event and a selected event
		c.addEventListener(ClueDisplay.EVENT_CLUE_SELECTED, onClueBankClueSelected, false, 0, true);
		c.addEventListener(ClueDisplay.EVENT_CLUE_CLICKED, onClueBankClueClicked, false, 0, true);
		c.addEventListener(ClueDisplay.EVENT_FREE_WORD_CLICKED, freeWordClicked, false, 0, true);
		c.addEventListener(ClueDisplay.EVENT_HINT_USED, hintUsed, false, 0, true);
		// set up the free words function
		c.doesUserHaveFreeWords = doesUserHaveFreeWords;
	}
	protected function onClueBankMouseWheel(e:MouseEvent):void
	{
		if(e.delta > 0)
		{
			_clueBank.tryGotoPreviousPage(true);
		}
		else if( e.delta < 0)
		{
			_clueBank.tryGotoNextPage(true);
		}
	}
	protected function freeWordClicked(e:Event):void
	{
		useFreeWord();
	}
	private function clueBankKeyboardNav(event:KeyboardEvent):void
	{
		if(event.keyCode == Keyboard.SPACE || event.keyCode == Keyboard.NUMPAD_5)
		{
			switch(event.target)
			{
				case _clueBankPageUp: { clueBankPageUpFunc(); break; }
				case _clueBankPageDown: { clueBankPageDownFunc(); break; }
				default: return;
			}
		}
	}
	protected function clueBankPageUpFunc(e:Event = null):void
	{
		_clueBank.tryGotoPreviousPage(true);
		showClueBankNavButtons(); // update which nav buttons should show
		if(!e) stage.focus = _clueBankPageDown;
	}
	protected function clueBankPageDownFunc(e:Event = null):void
	{
		_clueBank.tryGotoNextPage(true);
		showClueBankNavButtons(); // update which nav buttons should show
		if(!e) stage.focus = _clueBankPageUp;
	}
	protected function clueBankPageChange(e:Event):void
	{
		showClueBankNavButtons();
	}
	protected function showClueBankNavButtons():void
	{
		if(_clueBank.canGoToNextPage())
		{
			_clueBankPageDown.alpha = 1;
			_clueBankPageDown.mouseEnabled = true;
			_clueBankPageDown.useHandCursor = true;
		}
		else
		{
			_clueBankPageDown.alpha = .5;
			_clueBankPageDown.mouseEnabled = false;
			_clueBankPageDown.useHandCursor = false;
		}
		if(_clueBank.canGoToPreviousPage())
		{
			_clueBankPageUp.alpha = 1;
			_clueBankPageUp.mouseEnabled = true;
			_clueBankPageUp.useHandCursor = true;
		}
		else
		{
			_clueBankPageUp.alpha = .5;
			_clueBankPageUp.mouseEnabled = false;
			_clueBankPageUp.useHandCursor = false;
		}
	}
	protected function onClueBankClueClicked(e:Event):void
	{
		var c:ClueDisplay = e.target as ClueDisplay;
		// NOTE: we dont need to do the un-selecting of previous ones here
		//  when click event is heard, a selected event will follow
		// select this one on the crossword puzzle
		CWView.selectWordByWordReferenceIndex(c.indexInCrosswordWordReference, c.isAcross);
	}
	public function zoomIn(e:Event = null):void
	{
		grabZoom.zoomIn();
	}
	public function zoomOut(e:Event = null):void
	{
		grabZoom.zoomOut();
	}
	protected function showZoomButtons(e:Event = null):void
	{
		if(grabZoom.curScaleLevel == grabZoom.minScaleLevel)
		{
			// TODO: show it as disabled
			_zoomOutButton.alpha = .5;
			_zoomOutButton.mouseEnabled = false;
			_zoomOutButton.useHandCursor = false;
		}
		else
		{
			_zoomOutButton.alpha = 1;
			_zoomOutButton.mouseEnabled = true;
			_zoomOutButton.useHandCursor = true ;
		}
		if(grabZoom.curScaleLevel == grabZoom.maxScaleLevel)
		{
			_zoomInButton.alpha = .5;
			_zoomInButton.mouseEnabled = false;
			_zoomInButton.useHandCursor = false;
		}
		else
		{
			_zoomInButton.alpha = 1;
			_zoomInButton.mouseEnabled = true;
			_zoomInButton.useHandCursor = true;
		}
	}
	protected function relayMouseWheel(e:MouseEvent):void
	{
		// TODO: fixit
		// e.stageX and e.stageY dont seem right here
		// test by mouse zooming when you have no word selected (only at start of game)
		var e2:MouseEvent = e.clone() as MouseEvent;
		grabZoom.onMouseWheel(e2);
	}
	// this happens when they click a word in the crossword puzzle
	protected function crosswordWordSelected(e:Event):void
	{
		// make sure the clue bank is looking at the selected word
		var wordIndex:int = CWView.selectedWordIndex;
		for(var i:int =0; i< _clueBank.items.length; i++)
		{
			var item:ClueDisplay = (_clueBank.items[i] as ClueDisplay);
			if( item.indexInCrosswordWordReference == wordIndex)
			{
				item.select(); // this will dispatch the event that makes it scroll to it
				showClueBankNavButtons();
				return;
			}
		}
	}
	protected function crosswordWordClueFocus(e:Event):void
	{
		// make sure the clue bank is looking at the selected word
		var wordIndex:int = CWView.selectedWordIndex;
		for(var i:int =0; i< _clueBank.items.length; i++)
		{
			var item:ClueDisplay = (_clueBank.items[i] as ClueDisplay);
			if( item.indexInCrosswordWordReference == wordIndex)
			{
				stage.focus = item;
				showClueBankNavButtons();
				return;
			}
		}
	}
	//----------------------------------
	//  hints and clues
	//----------------------------------
	/**
	 * Toggles between the full clue list and the crossword puzzle (both are in the same area)
	 *
	 * @usage   CW.showClues();
	 */
	private function toggleCrosswordAndClues():void
	{
		if(showingClues)
		{
			layout.clueList.visible = false;
			(layout.cluesButton.getChildByName('label') as TextField).text = "Show All Clues";
			CWView.visible = true;
		}
		else
		{
			layout.clueList.visible = true;
			(layout.cluesButton.getChildByName('label') as TextField).text = "Show Crossword";
			CWView.visible = false;
			updateClueList();
		}
		showingClues = !showingClues;
	}
	/**
	 *  Checks if cluelist needs to be updated (with used hints) and updates it accordingly
	 */
	private function updateClueList():void
	{
		if(updateClues)
		{
			layout.clueList.htmlText = createClueList();
			updateClues = false;
		}
	}
	/**
	 * Creates the full clues list as Flash HTML and returns it as a string.
	 *
	 * @usage   CW.createClueList();
	 * @return  String. The full Flash HTML text of every clue in the puzzle is returned.
	 */
	private function createClueList():String
	{
		var AcrossArray:Array = new Array();
		var DownArray:Array = new Array();
		var cluesText:String;
		var acrossText:String = '';
		var downText:String = '';
		//The words are put in order based on their orientation and their associated number.
		var len:Number = CWView.wordReference.length
		for(var i:Number = 0; i < len; i++)
		{
			var ref:Object = CWView.wordReference[i]
			if(ref.question.options.dir == '0' || ref.question.options.dir == 'false' )
			{
				acrossText += '<A HREF="">     '+ref.index + ': ' + ref.question.questions[0].text+'</A><BR/>';
			}
			else downText += '<A HREF="">     '+ref.index + ': ' + ref.question.questions[0].text+'</A><BR/>';
		}
		//HTML is used for formatting.
		cluesText = '<P ALIGN="center"><FONT SIZE="16"><B>Crossword Puzzle Clues</B></FONT></P><BR/>';
		cluesText += '<P ALIGN="left"><FONT SIZE="14"><B><U>Across</U></B></FONT><BR/><FONT SIZE="12">';
		cluesText += acrossText
		cluesText += '</FONT><FONT SIZE="14"><B><BR/><U>Down</U></B></FONT><BR/><FONT SIZE="12">';
		cluesText += downText
		cluesText += "</FONT></P>";
		return cluesText;
	}
	/**
	 *  Fills out the currently selected row/column in the crossword
	 */
	private function useFreeWord():void
	{
		if(availFreeWords > usedFreeWords)
		{
			var id:String = CWView.currentSpace.getId(CWView.aToggle);
			var index:int = CWView.findWordReferenceById(id)
			if(CWView.wordReference[index].freeWordUsed != true)
			{
				CWView.showWord(index)
				CWView.wordReference[index].freeWordUsed = true;
				usedFreeWords++;
				//log it on the server
				addLog(Log.KEY_PRESSED, String(id), "FreeWord"); //Logs that a free word has been used.
				//This updates the free word text field.
				_freeWordsRemaining.text = ""+(availFreeWords - usedFreeWords)
				// lock down the word so they cannot type no mo
				CWView.lockDownWord(CWView.wordReference[index]);
			}
		}
	}
	protected function hintUsed(e:Event):void
	{
		usedHints++;
		_hintsRemaining.text = (_numHintsTotal - usedHints) + "";
		// scoring.adjustQuestionScore(String(CWView.currentSpace.getId(CWView.aToggle)), -(hintCost), "%n Hint%s Received");
		scoring.submitInteractionForScoring(String(CWView.currentSpace.getId(CWView.aToggle)), 'question_hint', ('-' + hintCost.toString()));
	}
	//----------------------------------
	//  finishing and submitting
	//----------------------------------
	/**
	 *  Displays a popup to confirm that puzzle should be submitted
	 *
	 *  @see handle_SubmitAlert
	 *  @see submitAndFinish
	 */
	private function verifySubmit():void
	{
		alertWindow('Last Chance', 'Only submit your scores when you are finished with the puzzle.\n  If you wish to continue playing or print the puzzle click "Cancel".');
	}
	private function  alertWindow(title:String, message:String):void
	{
		var alert:AlertWindow = AlertWindow(this.alert(title, message, 2));
		alert.addEventListener("dialogClick", handle_SubmitAlert, false, 0, true);
		alert.focusRect = false;
		stage.focus = alert;
		//the window is originally centered based somehow on the zoom/drag position of the puzzle window
		//this will center it on the stage
		alert._x = (stage.stageWidth - alert.width)/2;
		alert._y = (stage.stageHeight - alert.height)/2;
	}
	/**
	 *  Submits the score for this crossword and ends the game
	 */
	private function submitAndFinish():void
	{
		// loop through words in the puzzle to check the answers and send the values to the server
		for(var i:* in CWView.wordReference)
		{
			//Logs what word was typed for confirmation.
			scoring.submitQuestionForScoring(String(CWView.wordReference[i].question.id), CWView.getUserAnswer(i));
		}
		end();
	}
	//----------------------------------
	//  printing
	//----------------------------------
	private function showPrintPreview():void
	{
		/***** Create Window *****/
		//Create the window in which to put everything
		layout.createPrintWindow(windows, widget.width, widget.height);
		//Create reference to the window
		var printWindow:Window = layout.printWindow;
		//Create references to buttons
		var printButton:DisplayObject = printWindow.content.getChildByName("PrintButton");
		var closeButton:DisplayObject = printWindow.content.getChildByName("CloseButton");
		//Score the game (Print gets treated as submit)
		//Add button listeners
		printButton.addEventListener(MouseEvent.MOUSE_UP, handle_PrintConfirmButtonMouseDown, false, 0, true);
		closeButton.addEventListener(MouseEvent.MOUSE_UP, handle_ClosePrintPreviewButtonMouseDown, false, 0, true);
		printButton.addEventListener(MouseEvent.MOUSE_UP, handle_PrintConfirmButtonMouseUp, false, 0, true);
		closeButton.addEventListener(MouseEvent.MOUSE_UP, handle_ClosePrintPreviewButtonMouseUp, false, 0, true);
		/***** Prepare The Printer *****/
		//Create Printer object
		printer = new Printer();
		//Sets the margins and footer for the pages sent to the printer.
		printer.setMargins(10, 10, 10, 10);
		printer.setHeader(65, 10, inst.name, new TextFormat("Trebuchet MS", 28, 0, true, false, false, "", "", "center"))
		/***** Prepare Sprites For Printer *****/
		//Make sure the clue list is updated (has clues)
		updateClueList();
		//Create new puzzle, formatted for printing
		var puzzlePage:MovieClip = new MovieClip();
		var newPuzzle:CrosswordPuzzle = new CrosswordPuzzle(qSetData, false, false);
		puzzlePage.addChild(newPuzzle);
		//Create new clue list, formatted for printing
		var cluesPage:MovieClip = new MovieClip();
		var newClues:TextField = new TextField();
		newClues.width = printer.pageWidth;
		newClues.selectable = false;
		newClues.multiline = true;
		newClues.wordWrap = true;
		newClues.autoSize = TextFieldAutoSize.LEFT;
		newClues.htmlText = createClueList();
		cluesPage.addChild(newClues);
		//Scale and (horizontally) center the new puzzle to fit the page
		CenterScale.scale(newPuzzle, printer.contentHeight, printer.contentWidth, true);
		//Adds sprites to the printer buffer
		printer.addPage(puzzlePage);
		printer.addPage(cluesPage);
		/***** Create Preview Sprites *****/
		//Create [puzzle] preview container
		var puzzlePreview:MovieClip = new MovieClip();
		printWindow.content.addChild(puzzlePreview);
		//Create [clues] preview container
		var cluesPreview:MovieClip = new MovieClip();
		printWindow.content.addChild(cluesPreview);
		//Set up window preview variables
		var spacing:int = 3;
		var previewWidth:int = printWindow.contentWidth/2-spacing;
		var previewHeight:int = (printer.pageHeight*previewWidth)/printer.pageWidth;
		//Render the previews from preparation pages
		puzzlePreview.addChild(printer.renderPreviewPage(0, previewHeight, previewWidth));
		cluesPreview.addChild(printer.renderPreviewPage(1, previewHeight, previewWidth));
		//Center preview pages
		cluesPreview.x = (printWindow.contentWidth - (previewWidth*2 + spacing))/2;
		puzzlePreview.x = cluesPreview.x + previewWidth + spacing;
	}
	public function printToPaper():void
	{
		printer.print();
	}
	private function closePrintPreview():void
	{
		printer.cleanUp();
		layout.printWindow.content.getChildByName("PrintButton").removeEventListener(MouseEvent.MOUSE_UP, handle_PrintConfirmButtonMouseUp);
		layout.printWindow.content.getChildByName("CloseButton").addEventListener(MouseEvent.MOUSE_UP, handle_ClosePrintPreviewButtonMouseUp);
		layout.printWindow.content.getChildByName("PrintButton").removeEventListener(MouseEvent.MOUSE_DOWN, handle_PrintConfirmButtonMouseDown);
		layout.printWindow.content.getChildByName("CloseButton").addEventListener(MouseEvent.MOUSE_DOWN, handle_ClosePrintPreviewButtonMouseDown);
		layout.removePrintWindow()
	}
	//--------------------------------------------------------------------------
	//
	//  Event handlers
	//
	//--------------------------------------------------------------------------
	/**
	 *  Called when alert window is responded to (the one that appears after submit is pressed)
	 *  If "yes" or "ok" (true) was pressed, scores are submitted
	 */
	private function handle_SubmitAlert(e:StandardEvent):void
	{
		e.target.removeEventListener('dialogClick', handle_SubmitAlert);
		if (e.result == true)
		{
			submitAndFinish();
		}
	}
	/**
	 *  Called when a box or word is selected on the actual crossword
	 */
	private function handle_SelectWord(eObj:Object):void
	{
		//find reference to the word
		var selectedWord:Object = CWView.wordReference[CWView.findWordReferenceById(eObj.result)];
		if(_isFirstSelection)
		{
			grabZoom.setFirstSelectionZoomLevel();
		}
		grabZoom.showWord( CWView.getSelecetedWordBounds(), CWView.getSelectedLetterSpaceBounds(),_isFirstSelection);
		_isFirstSelection = false;
		//Place the clue
		layout.wordClue.htmlText = selectedWord.question.questions[0].text // place clue text in the textfield
		/***** Deal with the hint *****/
		//Reset this flag
		showingHint = false;
	}
	private function handle_StageMouseUp(e:MouseEvent):void
	{
		zoomButtonDown = false;
		cluesButtonDown = false;
		freeWordButtonDown = false;
		hintButtonDown = false;
		printButtonDown = false;
		submitButtonDown = false;
		windowedPrintButtonDown = false;
		windowedCloseButtonDown = false;
	}
	//----------------------------------
	//  button handlers
	//----------------------------------
	/**
	 *  Called when the "Zoom" button is pressed.
	 *  Only functions if the button is enabled.
	 */
	private function handle_ZoomButtonMouseDown(e:Event):void
	{
		zoomButtonDown = true;
	}
	/**
	 *  Called when the "Clues" button is pressed.
	 *  Only functions if the button is enabled.
	 */
	private function handle_CluesButtonMouseDown(e:Event):void
	{
		cluesButtonDown = true;
	}
	/**
	 *  Called when the "Clues" button is released.
	 *  Only functions if the button is enabled.
	 */
	private function handle_CluesButtonMouseUp(e:Event):void
	{
		if(layout.cluesButton.enabled && cluesButtonDown) toggleCrosswordAndClues();
	}
	/**
	 *  Called when the "Free Word" button is pressed.
	 *  Only functions if the button is enabled.
	 */
	private function handle_FreeWordButtonMouseDown(e:Event):void
	{
		freeWordButtonDown = true;
	}
	/**
	 *  Called when the "Free Word" button is released.
	 *  Only functions if the button is enabled.
	 */
	private function handle_FreeWordButtonMouseUp(e:Event):void
	{
		if(layout.freeWordButton.enabled && freeWordButtonDown) useFreeWord();
	}
	/**
	 *  Called when the "Hint" button is pressed.
	 *  Only functions if the button is enabled.
	 */
	private function handle_HintButtonMouseDown(e:Event):void
	{
		hintButtonDown = true;
	}
	/**
	 *  Called when the "Print" button is released on the [main] screen.
	 *  Only functions if the button is enabled.
	 */
	private function handle_PrintPreviewButtonMouseDown(e:Event):void
	{
		printButtonDown = true;
	}
	/**
	 *  Called when the "Print" button is released on the [main] screen.
	 *  Only functions if the button is enabled.
	 */
	private function handle_PrintPreviewButtonMouseUp(e:Event):void
	{
		if(_printGameButton.enabled && printButtonDown) showPrintPreview();
	}
	/**
	 *  Called when the "Print" button is released on the [print] screen.
	 *  Only functions if the button is enabled.
	 */
	private function handle_PrintConfirmButtonMouseDown(e:Event):void
	{
		windowedPrintButtonDown = true;
	}
	/**
	 *  Called when the "Print" button is released on the [print] screen.
	 *  Only functions if the button is enabled.
	 */
	private function handle_PrintConfirmButtonMouseUp(e:Event):void
	{
		if(windowedPrintButtonDown)
		{
			closePrintPreview();
			printToPaper();
		}
	}
	/**
	 *  Called when the "Close" button is pressed on the [print] screen.
	 *  Only functions if the button is enabled.
	 */
	private function handle_ClosePrintPreviewButtonMouseDown(e:Event):void
	{
		windowedCloseButtonDown = true;
	}
	/**
	 *
	 *  Called when the "Close" button is released on the [print] screen.
	 *  Only functions if the button is enabled.
	 */
	private function handle_ClosePrintPreviewButtonMouseUp(e:Event):void
	{
		if(windowedCloseButtonDown) closePrintPreview();
	}
	/**
	 *  Called when the "Submit" button is pressed.
	 *  Only functions if the button is enabled.
	 */
	private function handle_SubmitButtonMouseDown(e:Event):void
	{
		submitButtonDown = true;
	}
	/**
	 *  Called when the "Submit" button is released.
	 *  Only functions if the button is enabled.
	 */
	private function handle_SubmitButtonMouseUp(e:Event):void
	{
		if(layout.submitButton.enabled && submitButtonDown) verifySubmit();
	}
	private function onKeyboardHelpClick(e:Event = null):void
	{
		var alertMsg:String = "Keyboard Navigation: Use the numpad and tab key to interact with the cell grid and clue list."
		+ "\n\nNumpad 8: Navigate up."
		+ "\nNumpad 4: Navigate left."
		+ "\nNumpad 6: Navigate right."
		+ "\nNumpad 2: Navigate down."
		+ "\nNumpad 5: Choose and confirm."
		+ "\nNumpad 7: Cancel."
		+ "\n\nClick the OK button or press any key to continue.";
		_helpWindow = AlertWindow(this.alert("Keyboard Help", alertMsg, AlertWindow.OK));
		_helpWindow.addEventListener("dialogClick", closeAlertWindow, false, 0, true);
		_helpWindow.addEventListener(KeyboardEvent.KEY_DOWN, closeAlertWindow);
		_helpWindow.accessibilityProperties = new AccessibilityProperties();
		_helpWindow.accessibilityProperties.name = alertMsg;
		if(Accessibility.active) Accessibility.updateProperties();
		_helpWindow.focusRect = false;
		stage.focus = _helpWindow;
		//the window is originally centered based somehow on the zoom/drag position of the puzzle window
		//this will center it on the stage
		_helpWindow._x = (stage.stageWidth - _helpWindow.width)/2;
		_helpWindow._y = (stage.stageHeight - _helpWindow.height)/2;
		function closeAlertWindow(event:Event):void
		{
			_helpWindow.removeEventListener("dialogClick", closeAlertWindow);
			_helpWindow.removeEventListener(KeyboardEvent.KEY_DOWN, closeAlertWindow);
			if(event.type == KeyboardEvent.KEY_DOWN) _helpWindow.spoofButtonClick(true);
		}
	}
	private function autoIndex(obj:Object):void
	{
		obj.tabIndex = _indexer;
		_indexer-=10;
	}
	public function hintsRemaining():uint
	{
		return _numHintsTotal - usedHints;
	}
}
}