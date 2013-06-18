package events
{
	import flash.events.Event;
	public class QuestionMoveEvent extends Event
	{
		public var newcid:int;
		public static const QUESTION_MOVE:String = "questionMove";
		public static const QUESTION_DELETE:String = "questionDelete";
		public function QuestionMoveEvent(type:String, newcid:int, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, bubbles, cancelable);
			this.newcid = newcid;
		}
		override public function clone():Event
		{
			return new QuestionMoveEvent(type, newcid);
		}
	}
}