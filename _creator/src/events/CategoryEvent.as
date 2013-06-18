package events
{
	import flash.events.Event;
	public class CategoryEvent extends Event
	{
		public var info:String;
		public static const CATEGORY_RENAME:String = "renameEvent";
		public static const CATEGORY_DELETE:String = "deleteEvent";
		public static const CATEGORY_CLICK:String  = "categoryClick";
		public function CategoryEvent(type:String, info:String, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, bubbles, cancelable);
			this.info = info;
		}
		override public function clone():Event
		{
			return new CategoryEvent(type, info);
		}
	}
}