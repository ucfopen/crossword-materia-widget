package events
{
	import flash.events.Event;
	public class ConfirmDeleteEvent extends Event
	{
		public var moveToCategory:int;
		public var moveToCategoryId:int;
		public var option:String;
		public static const CONTINUE_CLICK:String = "continueClick";
		public static const CANCEL_CLICK:String = "cancelClick";
		public function ConfirmDeleteEvent(type:String, option:String, moveToCategory:int, moveToCategoryId:int, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, bubbles, cancelable);
			this.option = option;
			this.moveToCategory = moveToCategory;
			this.moveToCategoryId = moveToCategoryId;
		}
		override public function clone():Event
		{
			return new ConfirmDeleteEvent(type, option, moveToCategory, moveToCategoryId);
		}
	}
}