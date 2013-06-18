package puzzleDisplay
{
// this class is a clip that draws a crossword puzzle on it
// crossword creation logic taken from original gs crossword code
import com.gskinner.motion.GTween;
import flash.display.MovieClip;
import flash.events.Event;
import flash.geom.ColorTransform;
import materia.questionStorage.Question;
import puzzleDisplay.LetterBox2;
public class CrosswordPuzzleDisplay extends MovieClip
{
	protected static const TRACE_STRING:String = "CrosswordPuzzle.as";
	private var puzzleGrid:Object;
	private var letterIndex:Object;
	//Original deminsion variables
	private var oWidth:int;
	private var oHeight:int;
	private var wordsAdded:MovieClip;
	//An array of LetterBoxes
	private var letterClips:Array = null;
	function CrosswordPuzzleDisplay(width:int, height:int)
	{
		letterClips = new Array();
		oWidth = width;
		oHeight = height;
		wordsAdded = new MovieClip();
		addChild(wordsAdded);
	}
	public function loadPreBuiltPuzzle(name:String, words:Array):void
	{
		puzzleGrid = new Object();
		letterIndex = new Array();
		for each ( var word:Object in words)
		{
			var wordArray:Array = (word.answers[0].text as String).toUpperCase().split("");
			placeOnGrid(wordArray, word.options.x, word.options.y, word.options.dir);
		}
		reDraw(words);
	}
	public function buildPuzzle(name:String, aQSET:Array):Array // using arrays instead of qsets for simplicity
	{
		for(var i:int = 0; i<aQSET.length; i++)
		{
			aQSET[i].options.posSet = false;
		}
		var myWords:Array = new Array();
		//Copy the array
		for(var j:int = 0; j < aQSET.length; j++)
		{
			myWords.push(aQSET[j]);
		}
		var outQSET:Array = new Array()
		puzzleGrid = new Object();
		letterIndex = new Array();
		//minX = minY = maxX = maxY = 0;
		var loopCount:Number = 0;
		var loopLimit:Number = myWords.length *10// maximum number of attempts to place words on the grid
		myWords = randArray(myWords)
		// find the first valid word
		var firstword:Question
		while(firstword == null && myWords.length > 0)
		{
			firstword = (myWords.pop() as Question); // pop off the first word
			if(firstword == null || firstword.answers[0].text.length < 2) firstword = null // if its less then 2 characters, skip it
		}
		if(firstword == null)
		{
			return [];
		}
		// place the first word
		placeOnGrid(firstword.answers[0].text.toUpperCase().split(''), 0, 0, false);
		registerWord(outQSET, firstword, 0, 0, false);
		// try to place the remaining words with a loop limit to prevent this from taking too long
		while(myWords.length > 0 && loopLimit > loopCount++)
		{
			var word:Question = myWords.pop();
			var result:Object = testFitWord(word.answers[0].text.toUpperCase().split(''));
			if(result) // word fit found
			{
				placeOnGrid(result.word, result.x, result.y, result.dir);
				registerWord(outQSET, word, result.x, result.y, result.dir);
				loopCount = 0; // reset loop now that a word was added
			}
			else // word didnt fit
			{
				myWords.splice(0,0,word);// place it back onto the beginning of the array
			}
		}
		puzzleGrid = null // clear up memory
		letterIndex = null // clear up memory
		return normalizeQSET(outQSET);
	}
	private function testFitWord(word:Array):Object
	{
		var match:Array;
		if(word.length > 1) // words must be longer then 1 char
		{
			// find possible locations based on common letters
			var myLetters:Array = randArray(word);
			for(var i:int = 0; i< myLetters.length; i++) // loop through the letters in this word
			{
				if(myLetters[i] != " ")
				{
					var matchArray:Array = randArray(letterIndex[myLetters[i].charCodeAt(0)])
					if(matchArray != null) // if there is a matching letter on the board
					{
						for(var n:int = 0; n< matchArray.length; n++) // loop through the indexed letters that match the current one from the word
						{
							if(testFitWordAt(word, matchArray[n].x-i, matchArray[n].y, true))
							{
								match = matchArray.splice(n,1) // we matched this letter, so it cant be used again, it already has two perpendicular words going through it
								return {word:word, x:match[0].x-i, y:match[0].y, dir:true}
							}
							if(testFitWordAt(word, matchArray[n].x, matchArray[n].y-i, false))
							{
								match = matchArray.splice(n,1) // we matched this letter, so it cant be used again, it already has two perpendicular words going through it
								return {word:word, x:match[0].x, y:match[0].y-i, dir:false}
							}
						}
					}
				}
			}
		}
		return false;
	}
	// test fit a word at a specific location and direction on the grid
	private function testFitWordAt(word:Array, tx:Number, ty:Number, across:Boolean):Boolean
	{
		// check the boxes before and after the word to make sure they are clear
		if(across)
		{
			if(puzzleGrid[tx-1] == undefined) puzzleGrid[tx-1] = new Object();
			if(puzzleGrid[tx+word.length] == undefined) puzzleGrid[tx+word.length] = new Object();
			if(puzzleGrid[tx-1][ty] != undefined || puzzleGrid[tx+word.length][ty] != undefined) return false;
		}
		else
		{
			if(puzzleGrid[tx-1] == undefined) puzzleGrid[tx-1] = new Object();
			if(puzzleGrid[tx][ty-1] != undefined || puzzleGrid[tx][ty+word.length] != undefined) return false;
		}
		// check spaces for existing words
		for(var i:Number = 0; i < word.length; i++)
		{
			if(puzzleGrid[tx] == undefined) puzzleGrid[tx] = new Object();
			if(puzzleGrid[tx][ty] == undefined)// current box is empty
			{
				// verify that there are no adjacent letters
				if(across)
				{
					if(puzzleGrid[tx] == undefined) puzzleGrid[tx-1] = new Object();
					if( puzzleGrid[tx][ty-1] != undefined || puzzleGrid[tx][ty+1] != undefined) return false;
				}
				else
				{
					if(puzzleGrid[tx-1] == undefined) puzzleGrid[tx-1] = new Object();
					if(puzzleGrid[tx+1] == undefined) puzzleGrid[tx+1] = new Object();
					if( puzzleGrid[tx-1][ty] != undefined || puzzleGrid[tx+1][ty] != undefined) return false;
				}
			}
			else // current box isnt empty
			{
				if(puzzleGrid[tx] == undefined) puzzleGrid[tx] = new Object();
				if(puzzleGrid[tx][ty] != word[i]) return false;
				// verify that there is a word perpendicular to this one by making sure there is at least 1 adjacent block with a letter in it
				if(across)
				{
					if(puzzleGrid[tx] == undefined) puzzleGrid[tx-1] = new Object();
					if( puzzleGrid[tx][ty-1] == undefined && puzzleGrid[tx][ty+1] == undefined) return false;
				}
				else{
					if(puzzleGrid[tx-1] == undefined) puzzleGrid[tx-1] = new Object();
					if(puzzleGrid[tx+1] == undefined) puzzleGrid[tx+1] = new Object();
					if( puzzleGrid[tx-1][ty] == undefined && puzzleGrid[tx+1][ty] == undefined) return false;
				}
			}
			if(across) tx++;
			else ty++;
		}
		return true; // we made it all the way through the word without failing, return true that it does indeed fit
	}
	private function registerWord(myQSET:Array, myQ:Question, x:Number, y:Number, dir:Boolean):void
	{
		myQ.addOption('x', x);
		myQ.addOption('y', y);
		myQ.addOption('dir', dir == true ? 0 : 1);
		myQ.addOption('posSet', true);
		myQSET.push(myQ);
	}
	private function placeOnGrid(letters:Array, x:Number, y:Number, dir:Boolean):void
	{
		var xi:Number = 0
		var yi:Number = 0
		var len:Number = letters.length
		for(var i:int = 0; i < len; i++)
		{
			if(puzzleGrid[x+xi] == undefined) puzzleGrid[x+xi] = new Object();
			if(puzzleGrid[x+xi][y+yi] == undefined) // dont set grid cells or store a letter index if theres already a letter here.
			{
				indexLetter( letters[i], x+xi, y+yi);
				if(puzzleGrid[x+i] == undefined) puzzleGrid[x+i] = new Object() // if the column doesnt exist, make it
				puzzleGrid[x+xi][y+yi] = letters[i]
			}
			if(dir) xi++;
			else yi++;
		}
	}
	private function indexLetter(letter:String, x:Number, y:Number):void
	{
		var charCode:Number = letter.charCodeAt(0)
		if(letterIndex[charCode] == undefined) letterIndex[charCode] = new Array();
		letterIndex[charCode].push({x:x,y:y});
	}
	// Drawing puzzle
	private function normalizeQSET(myQSET:Array):Array
	{
		var minX:Number = 0
		var minY:Number = 0
		for(var i:int =0; i<myQSET.length; i++){
			if(myQSET[i].options.x < minX) minX = myQSET[i].options.x
			if(myQSET[i].options.y < minY) minY = myQSET[i].options.y
		}
		minX = -(minX) // mins will never be positive, and negative 0 is 0 so we only need to invert the values
		minY = -(minY);
		for(i=0;i<myQSET.length; i++){
			myQSET[i].options.x += minX;
			myQSET[i].options.y += minY;
		}
		return myQSET
	}
	public function drawPuzzle(words:Array):void
	{
		var i:int, j:int;
		//Clears all the letterboxes from the screen
		if(letterClips != null)
		{
			for(i=0; i< letterClips.length; i++)
			{
				if(letterClips[i].parent != null)
				{
					wordsAdded.removeChild(letterClips[i]);
				}
			}
		}
		//Clears the array
		letterClips = new Array();
		//Stores a letterbox temporarily
		var newClip:MovieClip;
		//The width and height of the letterbox
		var squareSize:int = 30;
		var curX:Number, curY:Number;
		for(i = 0; i < words.length; i++)
		{
			curX = words[i].options.x * squareSize;
			curY = words[i].options.y * squareSize;
			for(j = 0; j < words[i].answers[0].text.length;j++)
			{
				newClip = new LetterBox2();
				newClip.width = squareSize;
				newClip.height = squareSize;
				newClip.x = curX;
				newClip.y = curY;
				newClip.text.text = words[i].answers[0].text.charAt(j).toUpperCase();
				newClip.text.selectable = false;
				letterClips.push(newClip);
				if(words[i].answers[0].text.charAt(j) == ' ')
				{
					newClip.transform.colorTransform = new ColorTransform(0,0,0);
				}
				wordsAdded.addChild(newClip);
				if(words[i].options.dir)
				{
					curY += squareSize;
				}
				else
				{
					curX += squareSize;
				}
			}
		}
		reDraw(words);
	}
	public function reDraw(words:Array):void
	{
		var squareSize:Number = 30;
		var i:int, j:int;
		var curX:Number, curY:Number;
		var minX:Number = int.MAX_VALUE, maxX:Number = int.MIN_VALUE
		var minY:Number = int.MAX_VALUE, maxY:Number = int.MIN_VALUE;
		// 1 pass to get the size of everyhing
		for(i=0; i< words.length; i++)
		{
			if(!words[i].options.posSet)
			{
				continue;
			}
			curX = words[i].options.x * squareSize;
			curY = words[i].options.y * squareSize;
			for(j=0; j< words[i].answers[0].text.length;j++)
			{
				if(curX > maxX) maxX = curX;
				if(curX < minX) minX = curX;
				if(curY > maxY) maxY = curY;
				if(curY < minY) minY = curY;
				if(words[i].options.dir)
				{
					curY += squareSize;
				}
				else
				{
					curX += squareSize;
				}
			}
		}
		var xOffset:Number;
		var yOffset:Number;
		var n:Number;
		//If the puzzle is wider than it is tall
		if(maxX - minX > maxY - minY)
		{
			n = (maxX-minX + squareSize)/squareSize;
			squareSize = oWidth/n;
			xOffset = -minX * squareSize/30;
			yOffset = -minY * squareSize/30;
		}
		//If the puzzle is taller than it is wide
		else
		{
			n = (maxY-minY + squareSize)/squareSize;
			squareSize = oHeight/n;
			xOffset = -minX * squareSize/30;
			yOffset = -minY * squareSize/30;
		}
		// square size is now as big as it can be but still fitting everything
		var t:int = 0;
		var firstTween:Boolean = true; // we only need to call the end function after 1 tween
		// 2nd pass to tween everything
		for(i=0; i< words.length; i++)
		{
			if(!words[i].options.posSet)
			{
				//Hide letter boxes that arent part of the puzzle anymore
				for(j=0; j< words[i].answers[0].text.length; j++)
				{
					new GTween(letterClips[t], 0.5, {alpha:0});
					t++;
				}
				continue;
			}
			curX = words[i].options.x * squareSize;
			curY = words[i].options.y * squareSize;
			for(j=0; j< words[i].answers[0].text.length;j++)
			{
				if(firstTween == true)
				{
					firstTween = false;
					var g:GTween = new GTween(letterClips[t], .5, {alpha:1, x:curX+xOffset, y:curY+yOffset, width:squareSize, height:squareSize});
					g.addEventListener(Event.COMPLETE, allTweensComplete);
				}
				else
				{
					new GTween(letterClips[t], .5, {alpha:1, x:curX+xOffset, y:curY+yOffset, width:squareSize, height:squareSize});
				}
				t++;
				if(words[i].options.dir)
				{
					curY += squareSize;
				}
				else
				{
					curX += squareSize;
				}
			}
		}
	}
	private function allTweensComplete(e:Event):void
	{
		e.currentTarget.removeEventListener(Event.COMPLETE, allTweensComplete);
		this.dispatchEvent(new Event("CROSSWORD_BUILT", true));
	}
	public function buildColorObject():Object
	{
		var CWcolor:Object = new Object();
		CWcolor._textColor = 0;
		CWcolor._lineColor = 0;
		CWcolor._bgColor = 0xCCCCCC
		CWcolor._spaceColor = 0xFFFFFF;
		CWcolor._highlightColor = 0xCC0000
		CWcolor._cursorColor = 0xEE0000
		CWcolor._numColor = 0;
		return CWcolor;
	}
	private function randArray(t:Array):Array
	{
		if(t == null) return null;
		var w:Array = new Array();
		var i:int;
		for(i=0; i< t.length; i++){
			w.push(t[i]);
		}
		var w2:Array = new Array();
		while(w.length > 0){
			i = Math.floor(Math.random()*w.length);
			w2.push(w[i]);
			w.splice(i,1);
		}
		return w2;
	}
	public function isEmpty():Boolean
	{
		return letterClips.length>0;
	}
}
}