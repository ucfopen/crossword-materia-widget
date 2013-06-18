package
{
	import materia.questionStorage.Question;
	import mx.messaging.AbstractConsumer;
	public class CrosswordQuestion extends Question
	{
		public function CrosswordQuestion(type:String="MC", options:Object=null, id:Number=0, question:String=null, answer:String=null)
		{
			super(type, options, id, question, answer);
		}
		public override function validAnswer():Boolean
		{
			// Valid answer cannot be empty or have only special characters
			return !empty(answer) && !specialChars(answer);
		}
		/**
		 *	Checks if string contains only special characters
		 * 	Side effect: Sets error message specific to crossword answer 
		 **/
		public function specialChars(str:String):Boolean
		{
			// Valid answer must have at least one number or letter
			if(!(/[A-Za-z0-9]/.test(str)))
			{
				options.errorMessage = "Crossword answers must contain at least one letter or number.";
				options.errorTitle = "Invalid Crossword Answer";
				return true;	
			}
			return false;
		}
	}
}