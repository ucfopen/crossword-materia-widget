package puzzleDisplay
{
	import flash.display.MovieClip;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFormat;
	import flash.text.TextFormatAlign;
	public class LetterBox2 extends MovieClip
	{
		public var text:TextField;
		public function LetterBox2()
		{
			this.graphics.lineStyle(1);
			this.graphics.beginFill(0xffffff);
			this.graphics.drawRect(0,0,39,39);
			text = new TextField();
			text.width = this.width;
			text.height = this.height;
			var tf:TextFormat = new TextFormat("Helvetica", 24, 0, true, false, false, null, null, TextFormatAlign.CENTER);
			text.defaultTextFormat = tf;
			text.text = "X";
			text.autoSize = TextFieldAutoSize.CENTER;
			text.y = (this.height - text.height) / 2;
			text.text = "";
			addChild(text);
		}
	}
}