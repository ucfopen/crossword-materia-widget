/* See the file "LICENSE.txt" for the full license governing this code. */
package
{
import flash.display.MovieClip;
import flash.display.Sprite;
import flash.events.MouseEvent;
import flash.filters.GlowFilter;
import flash.text.TextField;
import flash.text.TextFieldAutoSize;
import flash.text.TextFormat;
import nm.ui.AlertWindow;
import nm.ui.ScrollText;
import nm.ui.ScrollText_base;
import nm.ui.Window;
/**
* This class creates the viewing area for the student using the crossword engine.
*
* @author	Scott Rapp
*/
public class Layout
{
	public var clueList:ScrollText_base;
	public var wordClue:ScrollText_base;
	public var fg:MovieClip;
	public var puzzle:MovieClip;
	public var bg:MovieClip;
	public var zoomButton:MovieClip;
	public var cluesButton:MovieClip;
	public var freeWordButton:MovieClip;
	public var hintButton:MovieClip;
	public var submitButton:MovieClip;
	public var printButton:MovieClip;
	public var title:TextField;
	public var clueTitle:TextField;
	public var clueText:ScrollText_base;
	public var freeWordsText:TextField;
	public var hintsText:TextField;
	public var printWindow:Window
	private var scope:MovieClip
	public var alert:AlertWindow
	private var _crosswordAreaHeight:Number;
	private var _crosswordAreaWidth:Number;
	private var _crosswordArea:MovieClip;
	private var _clueArea:MovieClip;
	private var _clueAreaHeight:Number;
	private var _clueAreaWidth:Number;
	/**
	 * This function dynamically draws the crossword background for the student end using the Rect functions.
	 * The movieclip hierarchy is also created.
	 *
	 * @usage   var StudentBG:StudentBackground = new StudentBackground(Student_mc);
	 * @param   target_mc MovieClip. The empty movieclip that will hold the viewer.
	 */
	public function Layout(_crosswordArea:MovieClip){
		_crosswordAreaHeight = _crosswordArea.height;
		_crosswordAreaWidth = _crosswordArea.width;
		scope = _crosswordArea
		//Create Background MovieClips
		bg = new MovieClip();
		puzzle = new MovieClip();
		fg = new MovieClip();
		//puzzle.x = -10.0;
		//puzzle.y = -10.0;
		puzzle.x = 0;
		puzzle.y = 0;
		// default color
		var dC:Number = 0xAAAAAAA; // default color
		//Load Embedded Font
		//new CrosswordFont();
		// Buttons
		var titleFormat:TextFormat = new TextFormat("Trebuchet MS", 18, 0, true, false, false, "", "", "center");
		var normalFormat:TextFormat = new TextFormat("Trebuchet MS", 16, 0, true, false, false, "", "", "center");
		var clueFormat:TextFormat = new TextFormat("Arial_Font", 12, 0);
		var hintFormat:TextFormat = new TextFormat("Trebuchet MS", 14, 0, false, false, false, "", "", "center");
		var zoomFormat:TextFormat = new TextFormat("Trebuchet MS", 12, 0, true, false, false, "", "", "right");
		zoomFormat.rightMargin = 10
		zoomButton = new MovieClip()//makeButton(fg, 'zoom', 100, 9, 0, 79, 40, zoomFormat, "Zoom\nOut", dC)
		var zoomGlass:Sprite = new Sprite(); //new ZoomGlass();
		//zoomGlass.x = 8;
		//zoomGlass.y = 7;
		zoomButton.addChild(zoomGlass);
		//freeWordButton = makeButton(fg, 'freeword', 101, 470, 239, 136, 40, normalFormat, 'Free Word', dC)
		//hintButton = makeButton(fg, 'hint', 102, 470, 335, 136, 38, normalFormat, 'Get Hint', dC);
		//cluesButton = makeButton(fg, 'clues', 103, 470, 187, 136, 38, normalFormat, "Show All Clues", dC)
		//printButton = makeButton(fg, 'print', 104, 542, 421, 79, 41, normalFormat, 'Print', dC)
		//submitButton = makeButton(fg, 'submit', 105, 452, 421, 87, 41, normalFormat, 'Submit', dC)
		// TODO FIXME HACK
		freeWordButton = new MovieClip();
		hintButton = new MovieClip();
		cluesButton = new MovieClip();
		printButton = new MovieClip();
		submitButton = new MovieClip();
		//title = makeTextBox("TitleText", 8, 89, 8, 450, 40, bg, titleFormat, '');
		//makeTextBox("CurClueText", 13, 452, 51, 169, 30, bg, normalFormat ,"Current Clue");
		//freeWordsText = makeTextBox("FWRemainText", 6, 452, 285, 169, 52, fg, hintFormat, "");
		//hintsText = makeTextBox("HintsRemainText", 7, 452, 377, 169, 44, fg, hintFormat, "");
		wordClue = new ScrollText_base(170, 107, "Select a word", clueFormat);
		wordClue.editable = false
		wordClue.move(451,79);
//		fg.addChild(wordClue);
		//Create the scrolltext field for the clues list.
		clueList = new ScrollText(423, 419);
		clueList.editable = false
		clueList.move(9,43)
		//clueList.tf.html = true;
		clueList.tf.background = false;
		clueList.tf.border = false;
		clueList.tf.selectable = false;
		clueList.visible = false;
//		fg.addChild(clueList);
		scope.addChild(bg);
		scope.addChild(puzzle);
		scope.addChild(fg);
		disableButton(freeWordButton)
		disableButton(hintButton)
	}
	/**
	 * This is a reusable private function to create text fields.
	 *
	 * @usage   makeTextBox("CurClueText", 13, 452, 51, 169, 30, bg, normalFormat ,"Current Clue");
	 * @param   name      String. The name of the text field.
	 * @param   depth     Number. The depth at which the field will be created in the target movieclip.
	 * @param   X         Number. The X coordinate for the text field.
	 * @param   Y         Number. The Y coordinate for the text field.
	 * @param   width     Number. The width of the text field.
	 * @param   height    Number. The height of the text field.
	 * @param   target		MovieClip. The target movieclip where the text field will be created.
	 * @param   format    TextFormat. The format that is to be used in the text field.
	 * @param   text      String. The text to go in the text field initally.
	 */
	private function makeTextBox(name:String, depth:Number, x:Number, y:Number, width:Number, height:Number, target:MovieClip, format:TextFormat, text:String):TextField
	{
		var myText:TextField = new TextField();
		myText.name = name;
		myText.text = text;
		myText.x = x;
		myText.y = y;
		myText.width = width;
		myText.height = height;
		myText.selectable = false;
		myText.wordWrap = true;
		myText.embedFonts = true;
		myText.setTextFormat(format);
		myText.defaultTextFormat = format;
		target.addChild(myText);
		return myText;
	}
	public function createPrintWindow(parent:MovieClip=null, parentWidth:Number=0, parentHeight:Number=0):void
	{
		var xPos:Number = 50
		var yPos:Number = 10
		var winWidth:Number = 535
		var winHeight:Number = 450
		if (parent != null)
		{
			xPos = parentWidth/2 - winWidth/2
			yPos = parentHeight/2 - winHeight/2 - 15
		}
		//The window everything is held in
		printWindow = new Window(winWidth, winHeight, "Print Puzzle", true, true);
		printWindow._x = xPos;
		printWindow._y = yPos;
		if (parent)
		{
			parent.addChild(printWindow);
		}
		else
		{
			scope.addChild(printWindow);
		}
		//Prepare variables
		var buttonHeight:int = 41;
		var buttonWidth:int = 120;
		var buttonColor:Number = 0xDDDDDD;
		//Prepare fonts
		var normalFormat:TextFormat = new TextFormat("Trebuchet MS", 16, 0, true, false, false, "", "", "center");
		var smallFormat:TextFormat = new TextFormat("Trebuchet MS", 14, 0, true);
		//Create Buttons
		var content:MovieClip = printWindow.content;
		var p_closeButton:MovieClip = new CancelPrintButton();
		p_closeButton.name = 'CloseButton';
		p_closeButton.x = printWindow.contentWidth - buttonWidth;
		p_closeButton.y = printWindow.contentHeight - buttonHeight;
		p_closeButton.addEventListener(MouseEvent.ROLL_OVER, makeHighlight, false, 0, true);
		p_closeButton.addEventListener(MouseEvent.ROLL_OUT, removeHighlight, false, 0, true);
		p_closeButton.buttonMode = true;
		content.addChild(p_closeButton)
		var p_printButton:MovieClip = new ConfirmPrintButton();
		p_printButton.name = 'PrintButton';
		p_printButton.x = 0;
		p_printButton.y = printWindow.contentHeight - buttonHeight;
		p_printButton.addEventListener(MouseEvent.ROLL_OVER, makeHighlight, false, 0, true);
		p_printButton.addEventListener(MouseEvent.ROLL_OUT, removeHighlight, false, 0, true);
		p_printButton.buttonMode = true;
		content.addChild(p_printButton)
		//var p_cwButton = makeButton(content, 'CWButton', 2, 85, PreviewH + 10, BtnWidth, BtnHeight, normalFormat, 'Crossword', dC);
		//var p_cluesButton = makeButton(content, 'CWText', 3, 180, PreviewH + 10, BtnWidth, BtnHeight, normalFormat, 'Clues', dC);
		//var p_bothButton = makeButton(content, 'BothButton', 4, 245, PreviewH + 10, BtnWidth, BtnHeight, normalFormat, 'Both', dC);
		//var p_showButton = makeButton(content, 'LettersButton', 5, 315, PreviewH + 10, BtnWidth, BtnHeight, normalFormat, 'Show Letters', dC);
	}
	public function removePrintWindow():void
	{
		if(printWindow.parent) printWindow.parent.removeChild(printWindow);
		printWindow = null;
	}
	public function showAlert(title:String, message:String):void
	{
		alert = new AlertWindow(title, message, 2, scope.width / 2);
	}
	private function makeButton(target:MovieClip, name:String, depth:Number, x:Number, y:Number, width:Number, height:Number, format:TextFormat, text:String, color:Number):MovieClip
	{
		var button:MovieClip = new MovieClip();
		button.name = name;
		button.x = x
		button.y = y
		var labela:TextField = makeTextBox('label', 0, 0, 0, width, height, button, format, text)
		labela.autoSize = TextFieldAutoSize.LEFT;
		labela.y = (height - labela.height) /2 // center height
		button.graphics.beginFill(0);
		button.graphics.drawRect(0, 0, width, height);// outer line
		button.graphics.beginFill(0xFFFFFF);
		button.graphics.drawRect(1, 1, width - 2, height - 2);// white buffer
		button.graphics.beginFill(0);
		button.graphics.drawRect(3, 3, width - 6, height - 6);// inner line
		button.graphics.beginFill(color);
		button.graphics.drawRect(4, 4, width - 8, height - 8);// fill
		button.graphics.endFill();
		/*
		Rect.draw(button, 0, 0, width, height, 0);// outer line
		Rect.draw(button, 1, 1, width-2, height-2, 0xFFFFFF);// white buffer
		Rect.draw(button, 3, 3, width-6, height-6, 0);// inner line
		Rect.draw(button, 4, 4, width-8, height-8, color);// fill
		*/
		// listeners
		button.addEventListener(MouseEvent.ROLL_OVER, makeHighlight, false, 0, true);
		button.addEventListener(MouseEvent.ROLL_OUT, removeHighlight, false, 0, true);
		//release outside
		button.addEventListener(MouseEvent.MOUSE_DOWN, removeHighlight, false, 0, true);
		target.addChild(button);
		button.mouseChildren = false;
		//button.useHandCursor = true;
		button.buttonMode = true;
		return button;
	}
	/**
	 * This internal function creates a highlight over a button. Used for mouse over.
	 * THIS WILL BE REPLACED WITH A CROSSWORD_BUTTON CLASS.
	 *
	 * @usage   CW.button2.makeHighlight(eObj);
	 * @param   eObj Object. The event object, used to determine which button is going into the over state.
	 */
	public static function makeHighlight(e:MouseEvent):void
	{
		var target:MovieClip = e.target as MovieClip;
		target.filters = [new GlowFilter(0x264960, .5)];
	}
	/**
	 * This internal function destroys the highlight created over a button in the previous function. Used for mouse out.
	 * THIS WILL BE REPLACED WITH A CROSSWORD_BUTTON CLASS.
	 *
	 * @usage   CW.button2.removeHightlight();
	 */
	public static function removeHighlight(e:MouseEvent):void
	{
		var target:MovieClip = e.target as MovieClip;
		target.filters = [];
		return;
		switch(e.type)
		{
			case MouseEvent.MOUSE_DOWN:
				target.filters = [new GlowFilter(0xffffff, .8)];
				target.addEventListener(MouseEvent.MOUSE_UP, removeHighlightReleaseOutside, false, 0, true);
				break;
			case MouseEvent.ROLL_OUT:
				target.filters = [];
				break;
		}
	}
	public static function removeHighlightReleaseOutside(e:MouseEvent):void
	{
		/*
		var target:MovieClip = e.target as MovieClip;
		target.parent.getremoveChild(target);
		*/
		//scope.removeEventListener(MouseEvent.MOUSE_UP, removeHighlightReleaseOutside);
		////trace("TARGET: "+e.target);
	}
	public function disableButton(button:MovieClip):void
	{
		/***** Change Attributes *****/
		button.alpha = .35;
		button.buttonMode = false;
		button.enabled = false;
		//Remove highlight if it exists
		var child:MovieClip = button.getChildByName("hl") as MovieClip;
		if(child)
			button.removeChild(child);
		/***** Remove Listeners *****/
		button.removeEventListener(MouseEvent.ROLL_OVER, makeHighlight);
		button.removeEventListener(MouseEvent.ROLL_OUT, removeHighlight);
		button.removeEventListener(MouseEvent.MOUSE_DOWN, removeHighlight);
	}
	public function enableButton(button:MovieClip):void
	{
		/***** Change Attributes *****/
		button.alpha = 1;
		button.buttonMode = true;
		button.enabled = true;
		/***** Enable Listeners *****/
		button.addEventListener(MouseEvent.ROLL_OVER, makeHighlight, false, 0, true);
		button.addEventListener(MouseEvent.ROLL_OUT, removeHighlight, false, 0, true);
		//release outside
		button.addEventListener(MouseEvent.MOUSE_DOWN, removeHighlight, false, 0, true);
	}
}
}