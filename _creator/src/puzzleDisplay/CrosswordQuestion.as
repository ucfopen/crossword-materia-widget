package creators.crossword.puzzleDisplay
{
	import questionStorage.Question;
	public class CrosswordQuestion extends Object
	{
		protected static const TRACE_STRING:String = "CrosswordQuestion.as";
		public var questionData:Question;
		public var x:int, y:int, dir:Boolean;
		public var posSet:Boolean = false;
		function CrosswordQuestion(qsetQuestion:Question)
		{
			questionData = qsetQuestion;
			var word:String = qsetQuestion.getAnswer();
			posSet = qsetQuestion.options.posSet;
			x = qsetQuestion.options.x;
			y = qsetQuestion.options.y;
			dir = qsetQuestion.options.dir;
		}
		public function copy():CrosswordQuestion
		{
			var t:CrosswordQuestion = new CrosswordQuestion(questionData.clone());
			return t;
		}
		public function addOption(n:*, v:*):void
		{
			posSet = true;
			this[n] = v;
		}
		public function clearOptions():void{
			posSet = false;
		}
	}
}