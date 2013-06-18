/* See the file "LICENSE.txt" for the full license governing this code. */
package
{
import flash.display.MovieClip;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.geom.Rectangle;
import nm.ui.TweeningDragDropBankList;
public class CrossWordClueBank extends TweeningDragDropBankList
{
	protected static const TRACE_STRING:String = "CrossWordClueBank";
	public static const EVENT_PAGE_CHANGED:String = "EVENT_PAGE_CHANGED";
	private static const SCROLL_BAR_WIDTH:Number = 8;
	private static const SCROLL_BAR_PADDING:Number = 12;
	private var _scrollBarIsDragging:Boolean ;
	private var _scrollBarWidth:Number;
	private var _scrollBarHeight:Number;
	private var _scrollBarX:Number;
	private var _scrollBarY:Number;
	private var _scrollBarPhantomWidth:Number ;
	private var _scrollBarPhantomHeight:Number;
	private var _scrollBarPhantomX:Number;
	private var _scrollBarPhantomY:Number;
	private var _scrollBarControlWidth:Number;
	private var _scrollBarControlHeight:Number;
	private var _scrollBarControlX:Number;
	private var _scrollBarControlY:Number;
	//private var textFieldOutput:TextField;
	private var _scrollStepsY:Array;
	private var _scrollHoverPage:Number;
	public static var scrollBarBackgroundGraphic:Class;
	public static var scrollBarHandleGraphic:Class;
	public static var scrollBarControlGraphic:Class;
	private var _scrollBarAreaClip:Sprite;
	private var _scrollBarPhantomClip:Sprite;
	private var _scrollBarControlClip:Sprite;
	public function CrossWordClueBank(parent:MovieClip):void
	{
		super(parent)
	}
	public override function setArea(theX:Number, theY:Number, width:Number, height:Number):void
	{
		super.setArea(theX, theY, width, height)
	}
	public function initScrollBar():void {
		_scrollBarIsDragging = false
		_scrollBarWidth = SCROLL_BAR_WIDTH
		_scrollBarHeight = _height
		_scrollBarX = _x+_width-_scrollBarWidth-SCROLL_BAR_PADDING
		_scrollBarY = _y
		setScrollBarSizes();
		_parent.stage.addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove)
		_scrollBarPhantomClip.addEventListener(MouseEvent.MOUSE_DOWN, startScrollPhantomDrag, false, 0, true);
		_parent.stage.addEventListener(MouseEvent.MOUSE_UP, stopScrollPhantomDrag, false, 0, true);
	}
	public function setScrollBarSizes():void
	{
		_scrollBarPhantomWidth = _scrollBarControlWidth = SCROLL_BAR_WIDTH
		_scrollBarPhantomHeight = _scrollBarControlHeight = _height/(getCurrentLastPage()+1)
		_scrollBarPhantomX = _scrollBarControlX = _x+_width-_scrollBarControlWidth-SCROLL_BAR_PADDING
		_scrollBarPhantomY = _scrollBarControlY = _y
		_scrollStepsY = new Array();
		var steps:int = (_scrollBarHeight / _scrollBarControlHeight)
		for (var i:int = 0; i < steps; i++) {
			_scrollStepsY.push(_scrollBarY + i*_scrollBarControlHeight);
		}
		if(_scrollBarAreaClip == null)
		{
			_scrollBarAreaClip = new scrollBarBackgroundGraphic()
			_parent.addChild(_scrollBarAreaClip);
		}
		_scrollBarAreaClip.x = _scrollBarX
		_scrollBarAreaClip.y = _scrollBarY
		_scrollBarAreaClip.width = _scrollBarWidth
		_scrollBarAreaClip.height = _scrollBarHeight
		_scrollBarAreaClip.alpha = .35
		if( _scrollBarControlClip == null)
		{
			_scrollBarControlClip = new scrollBarControlGraphic()
			_parent.addChild(_scrollBarControlClip);
		}
		_scrollBarControlClip.x = _scrollBarControlX
		_scrollBarControlClip.y = _scrollBarControlY
		_scrollBarControlClip.width = _scrollBarControlWidth
		_scrollBarControlClip.height = _scrollBarControlHeight
		_scrollBarControlClip.alpha = .35
		if( _scrollBarPhantomClip == null)
		{
			_scrollBarPhantomClip = new scrollBarHandleGraphic();
			_parent.addChild(_scrollBarPhantomClip);
		}
		_scrollBarPhantomClip.x =_scrollBarPhantomX
		_scrollBarPhantomClip.y =_scrollBarPhantomY
		_scrollBarPhantomClip.width =_scrollBarPhantomWidth
		_scrollBarPhantomClip.height =_scrollBarPhantomHeight
		_scrollBarPhantomClip.buttonMode = true;
		_scrollBarPhantomClip.tabEnabled = false;
		showScrollBar(steps > 1);
	}
	public function showScrollBar(val:Boolean):void
	{
//		trace("calculating...");
		if(_scrollBarPhantomClip.visible == val)
		{
			return;
		}
		_scrollBarPhantomClip.visible = val;
		_scrollBarControlClip.visible = val;
		_scrollBarAreaClip.visible = val;
	}
	public override function tryGotoNextPage(animate:Boolean = true):void
	{
		super.tryGotoNextPage(animate);
		updateScrollBarPosition();
		this.dispatchEvent(new Event(EVENT_PAGE_CHANGED, true));
	}
	public override function tryGotoPreviousPage(animate:Boolean = true):void
	{
		super.tryGotoPreviousPage(animate);
		updateScrollBarPosition();
		this.dispatchEvent(new Event(EVENT_PAGE_CHANGED, true));
	}
	public override function scrollToItem(item:Object, animate:Boolean=true, force:Boolean = false):void
	{
		super.scrollToItem(item, animate, force);
		updateScrollBarPosition();
		var steps:int = (_scrollBarHeight / _scrollBarControlHeight)
		showScrollBar(steps > 1);
	}
	public function tryGotoPage(pageNum:Number, animate:Boolean = true):void
	{
		_currentPage = pageNum
		moveItemsIntoPosition(animate)
		this.dispatchEvent(new Event(EVENT_PAGE_CHANGED, true));
	}
	public function updateScrollBarPosition(currentPage:int = -1):void
	{
		if (_currentPage != currentPage && currentPage != -1)
		{
			tryGotoPage(currentPage)
		}
		if (currentPage != -1)
		{
			_currentPage = currentPage
		}
		if (!_scrollBarIsDragging)
		{
			_scrollBarPhantomY = _scrollBarPhantomClip.y = _scrollStepsY[_currentPage];
		}
		_scrollBarControlY = _scrollBarControlClip.y = _scrollStepsY[_currentPage];
	}
	private function startScrollPhantomDrag(e:MouseEvent):void
	{
		//_scrollBarControlClip.removeEventListener(MouseEvent.MOUSE_DOWN, startScrollControlDrag)
		var dragBounds:Rectangle = new Rectangle(_scrollBarX, _scrollBarY, 0,
												_scrollBarHeight - _scrollBarPhantomClip.height);
		_scrollBarPhantomClip.startDrag(false, dragBounds);
		_scrollBarIsDragging = true;
	}
	private function stopScrollPhantomDrag(e:MouseEvent):void
	{
		//_scrollBarControlClip.removeEventListener(MouseEvent.MOUSE_DOWN, stopScrollControlDrag)
		_scrollBarPhantomClip.stopDrag();
		_scrollBarIsDragging = false;
		_scrollBarPhantomY = _scrollBarPhantomClip.y = _scrollStepsY[_currentPage]
	}
	private function onMouseMove(e:Event):void {
		if (_scrollBarIsDragging)
		{
			for (var i:int = 0; i < _scrollStepsY.length; i++) {
				var scrollPhantomCenter:Number = (_scrollBarPhantomClip.y + (_scrollBarPhantomClip.height/2));
				if (scrollPhantomCenter > _scrollStepsY[i] && scrollPhantomCenter < _scrollStepsY[i]+_scrollBarPhantomClip.height) {
					//(_parent.parent as MovieClip).alert("--"+_scrollStepsY[i], "--"+_scrollStepsY[i])
					updateScrollBarPosition(i)
					//_scrollHoverPage = i
				}
			}
		}
	}
}
}