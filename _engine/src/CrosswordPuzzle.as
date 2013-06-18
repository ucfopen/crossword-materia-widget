/* See the file "LICENSE.txt" for the full license governing this code. */
package
{
	import com.adobe.utils.StringUtil;
	
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.events.TimerEvent;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.text.TextFormat;
	import flash.ui.Keyboard;
	import flash.utils.Timer;
	
	import org.rubyamf.remoting.ssr.ResultEvent;
	/**
	 * This class creates the crossword puzzle itself, holds all references to the puzzle, and assigns the functionality
	 * for the spaces and zooming features.
	 *
	 * @author	Scott Rapp, Luis Estrada, Anthony Reyes
	 */
	public class CrosswordPuzzle extends Sprite
	{
		public static const ZOOM_OUT:String = "zoom out";
		public static const EVENT_WORD_SELECTED:String = "EVENT_WORD_SELECTED";
		public static const EVENT_WORD_FOCUS:String = "EVENT_WORD_FOCUS";
		public static var crossWordBackground:Class;
		public var qset:Object;
		public var aToggle:Boolean; // Used for intersections (keeps track of vert/horizontal word usage )
		public var currentSpace:CrosswordSpace;
		public var wordReference:Array; // Referenced words linking qset with spaces/numbers on the puzzle
		private var spaceArray:Object; // A collection of references to every space in the crossword puzzle
		private var _style:Object
		private var resizeAcross:Boolean;
		private var cw_mc:MovieClip;
		private var hl_mc:MovieClip;
		private var cellHl_mc:MovieClip;
		private var currentWordId:String;
		private var _playable:Boolean;
		protected var _curMouseOverWord:Object = null;
		protected var _mouseoverHilightMC:MovieClip; // this clip's .graphics will be used for mouseover drawings
		protected var _tempHackWordCount:int = 0; // check the comment in placeWord for more info
		//--------------------------------------------------------------------------
		//
		//  Constructor
		//
		//--------------------------------------------------------------------------
		/**
		 *  This function initializes the crossword viewer by assigning variables and calling the displayCrossword function.
		 *
		 *  @usage   var CWView:CrosswordViewer = new CrosswordViewer(qSet, true, true);
		 *
		 *  @param qset		Object.		Contains data (question/answer) to construct the crossword
		 *  @param playable		Boolean.	default to true
		 *  @param showAnswers	Boolean.	default to false, If true, the answers are shown by default, used for an answer key.
		 */
		public function CrosswordPuzzle (qset:Object, playable:Boolean = true, showAnswers:Boolean = false)
		{
			// GDispatcher.initialize(this);
			_style = new Object()
			styleDefaults()
			// The animation class and Key listener are initialized.
			wordReference = new Array()
			// Assigns variables before calling displayCrossword to begin construction.
			spaceArray = new Object();
			aToggle = true;
			this.qset = qset;
			_playable = playable;
			// Begins construction of the crossword
			renderCrossword(showAnswers, playable);
			// Wait until added to set playable on/off (to add key listener to stage)
			addEventListener(Event.ADDED_TO_STAGE, onAddedToStage, false, 0, true);
			// our word reference should be made by now, so this function is safe to call
			initWordsUsedIn();
		}
		// this will fill up the CorsswordsPuzzle spaces wordsUsedIn reference arrays
		protected function initWordsUsedIn():void
		{
			// tell every space about what words they are used in
			for(var i:int =0; i< wordReference.length; i++)
			{
				for(var j:int = 0; j < wordReference[i].cells.length; j++)
				{
					(wordReference[i].cells[j] as CrosswordSpace).wordsUsedIn.push( wordReference[i] );
				}
			}
		}
		//--------------------------------------------------------------------------
		//
		//  Member Functions
		//
		//--------------------------------------------------------------------------
		/**
		 *  Called when added to the stage.
		 *  Sets playable on/off, which requires access to stage
		 */
		protected function onAddedToStage(event:Event):void
		{
			removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
			playable = _playable;
		}
		/**
		 * This function uses the qset object to create a crossword puzzle and display it in the target movieclip.
		 *
		 * @usage   CWView.displayCrossword(false, true);
		 * @param   showAnswers Boolean. If true, the answers are shown by default, used for an answer key.
		 * @param   playable    Boolean. If false, this is assumed to be a preview, and therefore the crossword is not playable.
		 */
		private function renderCrossword(showAnswers:Boolean, playable:Boolean):void
		{
			//initialize variables
			var numArray:Array = new Array();
			cw_mc = new MovieClip();
			cw_mc.name = 'crossword';
			hl_mc = new MovieClip();
			hl_mc.name = 'highlight'; // word highlight
			cellHl_mc = new MovieClip();
			cellHl_mc.mouseEnabled = false;
			cellHl_mc.name = 'cellHighlight'; // cell highlight
			this.addChild(cw_mc);
			this.addChild(cellHl_mc);
			this.addChild(hl_mc);
			_mouseoverHilightMC = new MovieClip();
			_mouseoverHilightMC.mouseEnabled = false;
			addChild(_mouseoverHilightMC);
			var words:Array = qset.items[0].items as Array;
			var len:int = words.length
			for(var i:int = len - 1; i >= 0; i--)
			{
				placeWord(words[i], showAnswers, playable)
			}
			//move and resize everything
			var boxSize:Number =  getStyle('boxSize')
			hl_mc.x = hl_mc.y = cw_mc.x = cw_mc.y = boxSize; // leave a boxSize space on the top and left
			cellHl_mc.graphics.beginFill(getStyle('hlColor'), 0.4);
			cellHl_mc.graphics.drawRect(boxSize, boxSize, boxSize, boxSize);
			cellHl_mc.graphics.endFill();
			cellHl_mc.visible = false
		}
		private function placeWord(q:Object, showAnswers:Boolean, playable:Boolean):void
		{
			_tempHackWordCount++;
			var word:Array = q.answers[0].text.toUpperCase().split('')
			var len:Number = word.length
			var x:Number = q.options? Number(q.options.x): 0;
			var y:Number = q.options? Number(q.options.y): 0;
			var boxSize:Number = getStyle('boxSize');
			var cellx:Number = x * boxSize
			var celly:Number = y * boxSize
			var cellList:Array = new Array() // array of all the cells in this word
			for (var i:int = 0; i < len; i++)
			{
				// NOTE: having some confusion on how these values will come in
				var dir:Boolean = !(q.options.dir == 'false' || q.options.dir == '0' || q.options.dir == false);
				var space:CrosswordSpace = setSpace(cellx, celly, !dir, word[i], showAnswers, playable);
				space.wordNum.push([wordReference.length+1, !dir]); // to keep track of which words this cell is in
				space.initialName();
				cellList.push(space); // store all the cells in this word
				space.setId( q.id, !dir ); //The space is given a reference to which word it is a part of.
				// incriment x, y to keep track of height/width of finished puzzle
				if(!dir) cellx += boxSize
				else celly += boxSize
			}
			if (isNaN(cellList[0].cellNumber))
				cellList[0].cellNumber = wordReference.length+1; // set the number if it isnt already set
			// question is a reference to the question in the qset, cells is an array of cells in order, index is the word index of this object in the wordReference array
			wordReference.push({question:q, cells:cellList, index:cellList[0].cellNumber});
		}
		private function getSpace(x:Number, y:Number):CrosswordSpace
		{
			return spaceArray[x + '_' + y];
		}
		private function setSpace(x:Number, y:Number, dir:Boolean, letter:String, showAnswers:Boolean, playable:Boolean):CrosswordSpace
		{
			var space:CrosswordSpace = getSpace(x, y);
			if (space == null)
			{
				space = new CrosswordSpace(x, y, getStyle('boxSize'), dir, letter, getStyle('spaceColor'), getStyle('lineColor'), showAnswers, playable, getStyle('cellFormat'), getStyle('numberFormat'));
				cw_mc.addChild(space);
				spaceArray[space.x + '_' + space.y] = space;
				if (playable)
				{
					space.addEventListener(MouseEvent.CLICK, onSpaceEvent, false, 0, true);
					space.addEventListener(MouseEvent.MOUSE_DOWN, onSpaceEvent, false, 0, true);
					space.addEventListener(MouseEvent.MOUSE_OVER, onSpaceMouseOver, false, 0, true);
					space.addEventListener(MouseEvent.MOUSE_OUT, onSpaceMouseOut, false, 0, true);
				}
			}
			return space;
		}
		private function onSpaceEvent(event:MouseEvent):void
		{
			switch(event.type)
			{
				case MouseEvent.CLICK:
					selectWordByClick(event.target as CrosswordSpace,event.stageX, event.stageY);
					break;
			}
		}
		protected function onSpaceMouseOver(event:MouseEvent):void
		{
			var theSpace:CrosswordSpace = event.target as CrosswordSpace;
			// the rest of the work is done by mouseOverSpace, so we can re-use that function
			mouseOverSpace(theSpace, event.stageX, event.stageY);
		}
		protected function mouseOverSpace(theSpace:CrosswordSpace, clickX:Number = 0.0, clickY:Number = 0.0):void
		{
			// this function will display some mouseover interaction for the word
			killMouseOutTimer(); // cancel any previously running mouse out
			var wordsForSpace:Array = theSpace.wordsUsedIn;
			if( wordsForSpace.length == 1)
			{
				if( ! isWordSelected(wordsForSpace[0]) )
				{
					mouseOverWord(wordsForSpace[0]);
				}
				else
				{
					// it can get here
					// its complicated...
					// if a word is selected and a space is selected that has an intersection
					//  and you mouseover that space then move the mouse along the selected word
					//  this fixes things
					cancelMouseOver();
				}
			}
			else if(wordsForSpace.length == 2)
			{
				// if one of the words is selected, select the other one
				if(isWordSelected(wordsForSpace[0]))
				{
					if(currentSpace == theSpace)
					{
						mouseOverWord(wordsForSpace[1]);
					}
					else
					{
						cancelMouseOver();
					}
				}
				else if( isWordSelected(wordsForSpace[1]))
				{
					// TODO similar to up there!
					if(currentSpace == theSpace)
					{
						mouseOverWord(wordsForSpace[0]);
					}
					else
					{
						cancelMouseOver();
					}
				}
				else // select the word the click is more aligned with
				{
					var selectedWord:Object = getWordFromIntersectionClick( wordsForSpace[0], wordsForSpace[1],	theSpace, clickX, clickY);
					mouseOverWord(selectedWord);
					listenToMouseMoveOnSpaceForWordSelection(theSpace, wordsForSpace[0], wordsForSpace[1]);
				}
			}
			// else... should be no else. It should only be 1 or 2 words that a space belongs to
		}
		protected static const MOUSE_OUT_TIMER_DELAY:Number = 30;
		protected var _mouseOutTimer:Timer = null;
		protected function onSpaceMouseOut(e:MouseEvent):void
		{
			killMouseOutTimer();
			startMouseOutTimer();
		}
		protected function killMouseOutTimer():void
		{
			if(_mouseOutTimer != null)
			{
				_mouseOutTimer.removeEventListener(TimerEvent.TIMER_COMPLETE, cancelMouseOver);
				_mouseOutTimer.stop()
				_mouseOutTimer = null;
			}
		}
		protected function startMouseOutTimer():void
		{
			if(_mouseOutTimer != null)
			{
				killMouseOutTimer();
			}
			_mouseOutTimer = new Timer(MOUSE_OUT_TIMER_DELAY, 1);
			_mouseOutTimer.addEventListener(TimerEvent.TIMER_COMPLETE, cancelMouseOver, false, 0, true);
			_mouseOutTimer.start();
		}
		protected function cancelMouseOver(e:Event = null):void
		{
			// hide the mouseover graphics
			// any new mouseovers would have canceled the timer, so go ahead an hide
			killMouseOutTimer();
			_mouseoverHilightMC.graphics.clear();
			_curMouseOverWord = null;
		}
		protected function isWordSelected(word:Object):Boolean
		{
			var result:Boolean = (word.question.id == currentWordId);
			return result;
		}
		// these vars are used for:
		// listenToMouseMoveOnSpaceForWordSelection, intersectionSpaceMouseOut, intersectionSpaceMouseOut
		protected var _curIntersectionSpace:CrosswordSpace;
		protected var _curIntersectionWord1:Object;
		protected var _curIntersectionWord2:Object;
		// when we mouseover a space that is used in 2 words, this sets up listeners to tell which word should be selected at any time
		protected function listenToMouseMoveOnSpaceForWordSelection(theSpace:CrosswordSpace, w1:Object, w2:Object):void
		{
			_curIntersectionSpace = theSpace;
			_curIntersectionWord1 = w1;
			_curIntersectionWord2 = w2;
			theSpace.addEventListener(MouseEvent.MOUSE_MOVE, intersectionSpaceMouseMove, false, 0, true);
			theSpace.addEventListener(MouseEvent.MOUSE_OUT, intersectionSpaceMouseOut, false, 0, true);
		}
		protected function intersectionSpaceMouseMove(e:MouseEvent):void
		{
			mouseOverWord(
				getWordFromIntersectionClick(
					_curIntersectionWord1, _curIntersectionWord2, _curIntersectionSpace,e.stageX, e.stageY));
		}
		protected function intersectionSpaceMouseOut(e:MouseEvent):void
		{
			_curIntersectionSpace.removeEventListener(MouseEvent.MOUSE_MOVE, intersectionSpaceMouseMove);
			_curIntersectionSpace.removeEventListener(MouseEvent.MOUSE_OUT, intersectionSpaceMouseOut);
			_curIntersectionSpace = null;
			_curIntersectionWord1 = null;
			_curIntersectionWord2 = null;
		}
		protected function getSpaceAfterSpaceInWord(theSpace:CrosswordSpace, theWord:Object):CrosswordSpace
		{
			for(var i:int = 0; i < theWord.cells.length - 1; i++)
			{
				if(theWord.cells[i] == theSpace)
				{
					return theWord.cells[i + 1];
				}
			}
			return null;
		}
		protected function getSpaceBeforeSpaceInWord(theSpace:CrosswordSpace, theWord:Object):CrosswordSpace
		{
			for(var i:int = 1; i < theWord.cells.length; i++)
			{
				if(theWord.cells[i] == theSpace)
				{
					return theWord.cells[i - 1];
				}
			}
			return null;
		}
		protected function getWordFromIntersectionClick( word1:Object, word2:Object, theSpace:CrosswordSpace, cx:Number, cy:Number):Object
		{
			// depending on where they click, we choose between vertical or horizontal
			//  then find the word that is eaither vertical or horizontal
			// it is different for corner intersections vs edge intersections
			// the test lines can be rising, falling, or both
			// the neighbor spaces for the intersection
			var verticalWord:Object = getVerticalWord(word1, word2);
			var horizontalWord:Object = (word1 == verticalWord) ? word2 : word1;
			var top:CrosswordSpace = getSpaceBeforeSpaceInWord(theSpace, verticalWord);
			var bottom:CrosswordSpace = getSpaceAfterSpaceInWord(theSpace, verticalWord);
			var left:CrosswordSpace = getSpaceBeforeSpaceInWord(theSpace, horizontalWord);
			var right:CrosswordSpace = getSpaceAfterSpaceInWord(theSpace, horizontalWord);
			const VERTICAL:int = 0;
			const HORIZONTAL:int = 1;
			// vertical or horizontal will 'own' slices based on the situation
			var topOwner:int = VERTICAL;
			var bottomOwner:int = VERTICAL;
			var leftOwner:int = HORIZONTAL;
			var rightOwner:int = HORIZONTAL;
			if( top == null) topOwner = HORIZONTAL;
			if( bottom == null) bottomOwner = HORIZONTAL;
			if( left == null) leftOwner = VERTICAL;
			if( right == null) rightOwner = VERTICAL;
			var localClickPoint:Point = theSpace.globalToLocal( new Point(cx, cy));
			// if we are scaled, globalToLocal will 'un do' that scaling for its point
			// so use getStyle('boxSize')
			var theSpaceCenterPoint:Point = new Point(getStyle('boxSize') /2.0, getStyle('boxSize') /2.0);
			var opposite:Number = (localClickPoint.y - theSpaceCenterPoint.y);
			var adjacent:Number = (localClickPoint.x - theSpaceCenterPoint.x);
			if(adjacent == 0) // dont want to divide by zero!
			{
				// eh... just return vertical?
				return getVerticalWord(word1, word2);
			}
			var angle:Number = Math.atan( opposite / adjacent );
			while( angle < 0)
			{
				angle += Math.PI * 2;
			}
			angle = angle * 180.0 / Math.PI;
			// HACKY FIXEMUPS
			// this is hacky, but it works
			if(adjacent > 0)
			{
				angle = angle - 180;
				while( angle < 0)
				{
					angle += 360;
				}
			}
			// END HACKY FIXEMUPS
			if( angle < 45.0) // left
			{
				return (leftOwner == VERTICAL) ? verticalWord : horizontalWord;
			}
			else if( angle < 135) // top
			{
				return (topOwner == VERTICAL) ? verticalWord : horizontalWord;
			}
			else if( angle < 225) // right
			{
				return (rightOwner == VERTICAL) ? verticalWord : horizontalWord;
			}
			else if( angle < 315) // bottom
			{
				return (bottomOwner == VERTICAL) ? verticalWord : horizontalWord;
			}
			else // left
			{
				return (leftOwner == VERTICAL) ? verticalWord : horizontalWord;
			}
		}
		// given 2 word objects, return the vertical one
		// one of them is going to be vertical
		protected function getVerticalWord(w1:Object, w2:Object):Object
		{
			if( w1.question.options.dir == '1')
			{
				return w1;
			}
			return w2;
		}
		protected function getHorizontalWord(w1:Object, w2:Object):Object
		{
			if( w1 == getVerticalWord(w1, w2))
			{
				return w2;
			}
			return w1;
		}
		protected function mouseOverWord(word:Object):void
		{
			if(word == _curMouseOverWord)
			{
				return;
			}
			// stop mouseing over the current mouseoverd word
			// display mouseover graphics
			const MOUSE_OVER_COLOR:int = 0x67A0C7;
			drawWordHilightForWord(word, _mouseoverHilightMC, MOUSE_OVER_COLOR, true);
			_curMouseOverWord = word;
		}
		public function showWord(wordReferenceIndex:Number):void
		{
			for(var i:String in wordReference[wordReferenceIndex].cells)
			{
				wordReference[wordReferenceIndex].cells[i].showAnswer();
			}
		}
		public function selectWordByWordReferenceIndex(i:int, isAcross:Boolean):void
		{
			// NOTE: this function is currently called when they
			//  click a word in the word list
			// Because of this, the last param of select word is false
			// see its comments for details
			selectWord(wordReference[i].cells[0], isAcross, true, false);
		}
		// this handles selecting a word when a space is clicked
		public function selectWordByClick(space:CrosswordSpace, clickX:Number, clickY:Number):void
		{
			// if we have a mouseover space, we can select that one
			// the mousovering should be telling the user which one to select next
			// NOTE: i dont think clickX and clickY will be needed for this anymore
			if(_curMouseOverWord != null)
			{
				var isAccross:Boolean = (_curMouseOverWord.question.options.dir == '0');
				selectWord(space, isAccross, true);
			}
			else
			{
				selectWord(space);
			}
			if(space.intersection && currentSpace == space)
			{
				// fix mouseover interaction:
				// this was an intersection piece
				//  so show the mouseover graphics for the other member of the intersection
				//  this is because we put mouseover graphics on the one that will be selected
				//  on click
				mouseOverSpace(currentSpace);
			}
		}
		/**
		 * This function is called whenever a space is clicked or arrow keyed to by the user. This updates all of the on-screen
		 * highlights and zooming by calling the appropriate functions and setting the variables.
		 *
		 * @usage   CWView.selectWord("s_0_4");
		 * @param   whoIsIt     String. The name of the space calling this function, used to identify the focus of the selection.
		 * @param   acrossForce Boolean. If this is not undefined, aToggle is forced to be its value.
		 * @param   dispatchSelectionEvent Boolean this can be used to enable or disable dispatching a selection event
		 */
		protected function selectWord(space:CrosswordSpace, acrossForce:Boolean = false,
									  useAcrossForce:Boolean = false, dispatchSelectionEvent:Boolean = true):void
		{
			// NOTE ABOUT dispatchSelectionEvent:Boolean
			//  This event is currently being used to tell the engine if it should
			//  try and select this word in the words list or not.
			//  We don't need to select it in the words list when this
			//   selection has happened because of a selection in the words list.
			//   ( that word will already be selected )
			if(space == null) return;
			cellHl_mc.visible = true;
			if (currentSpace == space)
			{
				// toggle the direction if its at an intersection and already selected
				if(space.intersection)
				{
					aToggle = !aToggle; // toggle selected words
				}
			}
			else
			{
				if(!space.intersection) aToggle = space.isAcross // only set the aToggle if this block doesnt have an intersection point
				// if the chosen space is literally a " " character
				if(space.isGuessable == false)
				{
					var nSpace:CrosswordSpace = getNextSpace(space) // move to the next letter
					if(nSpace === currentSpace)
					{
						nSpace = getPreviousSpace(space)
					}
					currentSpace = nSpace
				}
				else currentSpace = space;
				cellHl_mc.x = currentSpace.x;
				cellHl_mc.y = currentSpace.y;
			}
			//Used from the engine class, when a clue from the clues page is clicked, and the first letter is an intersection,
			//the incorrect word may be selected. This overrides that.
			if(useAcrossForce) aToggle = acrossForce;
			_mouseoverHilightMC.graphics.clear();
			if( currentWordId != space.getId(aToggle) ) // the word has changed
			{
				drawWordHighLight( currentSpace, hl_mc, getStyle('hlColor') );
			}
			currentWordId = space.getId(aToggle); //Remembers what the previous word was for the next selection call.
			this.dispatchEvent(new ResultEvent("selectWord", false, false, currentWordId));
			if(dispatchSelectionEvent)
			{
				dispatchEvent(new Event(EVENT_WORD_SELECTED, true));
			}
		}
		// NOTE: this could be a lot faster if we just store the index when we store the currentSpace
		public function get selectedWordIndex():int
		{
			var result:int = -1;
			for(var i:int =0; i< wordReference.length; i++)
			{
				if(isWordSelected(wordReference[i]))
				{
					result = i;
					break;
				}
			}
			return result;
		}
		//if the user presses a key before selecting a cell with the mouse
		private function forceFirstSpace():void
		{
			//default the selected cell to the first cell of the first word
			currentSpace = wordReference[0].cells[0];
			var isAcross:Boolean = (wordReference[0].question.options.dir == 0 || wordReference[0].question.options.dir == false);
			selectWordByWordReferenceIndex(0,isAcross);
			cellHl_mc.x = currentSpace.x;
			cellHl_mc.y = currentSpace.y;
		}
		public function getUpSpace(space:CrosswordSpace = null):CrosswordSpace
		{
			if(!currentSpace)
			{
				forceFirstSpace();
				return currentSpace;
			}
			if(!(space is CrosswordSpace)) space = currentSpace;
			return getSpace(space.x, space.y-getStyle('boxSize'))
		}
		public function getDownSpace(space:CrosswordSpace = null):CrosswordSpace
		{
			if(!currentSpace)
			{
				forceFirstSpace();
				return currentSpace;
			}
			if (!(space is CrosswordSpace)) space = currentSpace;
			return getSpace(space.x, space.y+getStyle('boxSize'))
		}
		public function getLeftSpace(space:CrosswordSpace = null):CrosswordSpace
		{
			if(!currentSpace)
			{
				forceFirstSpace();
				return currentSpace;
			}
			if(!(space is CrosswordSpace)) space = currentSpace;
			return getSpace(space.x-getStyle('boxSize'), space.y)
		}
		public function getRightSpace(space:CrosswordSpace = null):CrosswordSpace
		{
			if(!currentSpace)
			{
				forceFirstSpace();
				return currentSpace;
			}
			if(!(space is CrosswordSpace)) space = currentSpace;
			return getSpace(space.x+getStyle('boxSize'), space.y)
		}
		public function getNextSpace(space:CrosswordSpace = null, i:Number = NaN):CrosswordSpace
		{
			if (!(space is CrosswordSpace))
			{
				space = currentSpace; // no space sent, default to the current
			}
			// HACK BUGFIX
			// if you rapidly click on a space and type, it can mess up
			// this is a hacky fix for that, double check aToggle is cool
			if(! space.intersection)
			{
				if((aToggle && ! space.isAcross) || (!aToggle && space.isAcross))
				{
					aToggle = !aToggle;
				}
			}
			var nSpace:CrosswordSpace = aToggle ? getRightSpace(space) : getDownSpace(space)
			if(nSpace == null)
			{
				nSpace =  currentSpace;
			}
			if(!nSpace.isGuessable) // will pass if its not guessable and if nSpace doesnt exist
			{
				if( i > 50 )
				{
					return currentSpace; // recursion limiter
				}
				nSpace =  getNextSpace(nSpace, isNaN(i) ? 1 : ++i); //recursively keep skipping forward untill nSpace.isGuessable is false
			}
			return nSpace
		}
		public function getPreviousSpace(space:CrosswordSpace = null, i:Number = -1):CrosswordSpace
		{
			if(!(space is CrosswordSpace)) space = currentSpace;
			var prevSpace:CrosswordSpace = aToggle ? getLeftSpace(space) : getUpSpace(space)
			// this part is a bugfix for if the first chars are un-guessables
			if(prevSpace == null && space.isGuessable == false)
			{
				return getNextSpace(space, (i==-1)? 1 : ++i);
			}
			else if (prevSpace == null)
			{
				return space;
			}
			if(!prevSpace.isGuessable){
				if(i>50) return currentSpace; // recursion limiter
				return getPreviousSpace(prevSpace, (i==-1) ? 1 : ++i); //recursively keep skipping back untill prevSpace.isGuessable is false
			}
			return prevSpace
		}
		/**
		 * This function is called only when the space that has become the focus is in a new word. This was seperated from
		 * the previous function, selectWord, to make the crossword run faster.
		 *
		 * @usage   CWView.changeWord("s_0_4");
		 * @param   whoIsIt String. The string identifying the space to become the focus.
		 */
		private function drawWordHighLight(space:CrosswordSpace, targetMC:MovieClip, theColor:int):void
		{
			targetMC.graphics.clear();
			var boxSize:Number = getStyle('boxSize')
			var thisWord:Object = wordReference[findWordReferenceById(space.getId(aToggle))].question;
			const LINE_THICKNESS:Number = 1.8;
			if (aToggle)
			{
				targetMC.graphics.lineStyle(LINE_THICKNESS, theColor);
				targetMC.graphics.drawRect(Number(thisWord.options.x) * boxSize, thisWord.options.y * boxSize, thisWord.answers[0].text.length * boxSize, boxSize);
			}
			else
			{
				targetMC.graphics.lineStyle(LINE_THICKNESS, theColor);
				targetMC.graphics.drawRect(Number(thisWord.options.x)*boxSize, thisWord.options.y*boxSize, boxSize, thisWord.answers[0].text.length * boxSize);
			}
		}
		protected function drawWordHilightForWord( thisWord:Object, targetMC:MovieClip, theColor:int, fill:Boolean):void
		{
			targetMC.graphics.clear();
			var boxSize:Number = getStyle('boxSize');
			const LINE_THICKNESS:Number = 1.4;
			var r:Object = wordReference;
			var question:Object = thisWord.question;
			if (question.options.dir == '0')
			{
				targetMC.graphics.lineStyle(LINE_THICKNESS, theColor);
				if(fill)
				{
					targetMC.graphics.beginFill(theColor, 0.2);
				}
				targetMC.graphics.drawRect( (Number(question.options.x) + 1) * boxSize,
					(Number(question.options.y) + 1) * boxSize,
					question.answers[0].text.length * boxSize,
					boxSize);
				if(fill)
				{
					targetMC.graphics.endFill();
				}
			}
			else
			{
				targetMC.graphics.lineStyle(LINE_THICKNESS, theColor);
				if(fill)
				{
					targetMC.graphics.beginFill(theColor, 0.2);
				}
				targetMC.graphics.drawRect( (Number(question.options.x) + 1) * boxSize,
					(Number(question.options.y) + 1) * boxSize,
					boxSize,
					question.answers[0].text.length * boxSize);
				if(fill)
				{
					targetMC.graphics.endFill();
				}
			}
		}
		public function findWordReferenceById(id:String):Number
		{
			for(var i:* in wordReference){
				if(wordReference[i].question.id == id) return i
			}
			return 0;
		}
		/**
		 *  Called when a key is pressed.
		 *  Determines what to do, based on the key pressed
		 *  Restricted to [Arrows] [Numpad Arrows] [Backspace] [Letters] [Numbers]
		 */
		private function onKeyDown(event:KeyboardEvent):void
		{
			switch( event.keyCode)
			{
				//Bakspace is Pressed
				case Keyboard.BACKSPACE:
				{
					if(currentSpace.label == " ")
					{
						selectWord( getPreviousSpace() );
					}
					// no break, delete and backspace both reset the value of this cell
				}
				//Delete key is Pressed
				case Keyboard.DELETE:
				{
					currentSpace.label = " ";
					break;
				}
				//Up Arrow is Pressed
				case Keyboard.UP: case Keyboard.NUMPAD_8:
				{
					selectWord( getUpSpace() ); // select space up
					break;
				}
				//Down Arrow is Pressed
				case Keyboard.DOWN: case Keyboard.NUMPAD_2:
				{
					selectWord( getDownSpace() ); // select space down
					break;
				}
				//Right Arrow is Pressed
				case Keyboard.RIGHT: case Keyboard.NUMPAD_6:
				{
					selectWord( getRightSpace() ); // select space right
					break;
				}
				//Left Arrow is Pressed
				case Keyboard.LEFT: case Keyboard.NUMPAD_4:
				{
					selectWord( getLeftSpace() ); // select space left
					break;
				}
				//Return Key is Pressed
				case Keyboard.ENTER: //case Keyboard.NUMPAD_5:
				case Keyboard.ESCAPE:
				{
					dispatchEvent(new Event(ZOOM_OUT));
					break;
				}
				//hackey, but numpad keys must be ignored
				case Keyboard.NUMPAD_5:
				{
					dispatchEvent(new Event(EVENT_WORD_FOCUS, true));
					return;
				}
				//Letter or Number is Pressed
				default:
				{
					// if they type before selecting a word
					if(currentSpace == null) return;
					var keyAscii:Number = event.charCode;
					if((keyAscii > 47 && keyAscii < 58 ) || (keyAscii > 64 && keyAscii < 91 ) || (keyAscii > 96 && keyAscii < 123))
					{
						//transorm capitals to upper case
						if (keyAscii > 90) keyAscii -= 32;
						currentSpace.label = String.fromCharCode(keyAscii);
						//space right or space down
						selectWord(getNextSpace());
					}
					return;
				}
			}
			stage.focus = currentSpace;
		}
		public function getUserAnswer(wordIndex:Number):String
		{
			var answer:String = ''
			var cellArr:Array = wordReference[wordIndex].cells;
			var len:int = cellArr.length
			for(var i:int = 0; i < len; i++)
			{
				answer += cellArr[i].label;
			}
			return answer;
		}
		public function lockDownWord(wordRef:Object):void
		{
			for(var i:int =0; i< wordRef.cells.length; i++)
			{
				(wordRef.cells[i] as CrosswordSpace).lock();
			}
		}
		private function styleDefaults():void
		{
			setStyle('boxSize', 30)
			setStyle('lineColor', 0x000000);
			setStyle('spaceColor', 0xFFFFFF);
			setStyle('hlColor', 0x67A0C7);
			setStyle('numberFormat', new TextFormat('Arial', getStyle('boxSize')/3.5, 0x000000))
			setStyle('cellFormat', new TextFormat('Arial', getStyle('boxSize')/2, 0x000000))
		}
		/**
		 * Define or redefine a style property
		 * @param	propName	String name of the property
		 * @param	val	Value of the property
		 */
		public function setStyle(propName:String, val:*):*
		{
			_style[propName] = val;
			return val;
		}
		/**
		 * Retrieves a style property value
		 * @param	propName	String name of the proptery
		 * @return	Value of the property
		 */
		public function getStyle(propName:String):*
		{
			return _style[propName];
		}
		public function set playable(val:Boolean):void
		{
			_playable = val
			if (val == true) stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown, false, 0, true);
			else stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
		}
		public function get playable():Boolean
		{
			return _playable
		}
		public function getSelectedLetterSpaceBounds():Rectangle
		{
			if(currentSpace == null)
			{
				return new Rectangle();
			}
			var boxSize:Number = getStyle('boxSize');
			var r:Rectangle = new Rectangle(currentSpace.x + boxSize, currentSpace.y + boxSize , boxSize, boxSize);
			return r;
		}
		public function getSelecetedWordBounds():Rectangle
		{
			if(selectedWordIndex == -1)
			{
				return new Rectangle();
			}
			var word:Object = wordReference[ selectedWordIndex];
			var question:Object = word.question;
			var boxSize:Number = getStyle('boxSize');
			if(question.options.dir == '0')
			{
				return new Rectangle( (Number(question.options.x) + 1) * boxSize,
					(Number(question.options.y) + 1) * boxSize,
					question.answers[0].text.length * boxSize,
					boxSize);
			}
			else
			{
				return new Rectangle( 	(Number(question.options.x) + 1) * boxSize,
					(Number(question.options.y) + 1) * boxSize,
					boxSize,
					question.answers[0].text.length * boxSize);
			}
		}
	}
}