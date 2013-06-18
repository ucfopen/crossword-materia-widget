/* See the file "LICENSE.txt" for the full license governing this code. */
package
{
	import com.gskinner.motion.GTween;
	import flash.display.MovieClip;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	public class CrosswordGrabZoomClip extends MovieClip
	{
		/**
		 * Making this because GrabZoomClip, which crossword was using before, was annoying me.
		 */
		public static const EVENT_ZOOM_CHANGED:String = "EVENT_ZOOM_CHANGED";
		public var content:MovieClip;
		protected var _draggableBackground:MovieClip;
		protected var _width:Number;
		protected var _height:Number;
		// we will have functions that collect how much we need to move
		// and them move them all at once
		protected var _contentXMoveAmount:Number;
		protected var _contentYMoveAmount:Number;
		protected var _dragging:Boolean = false;
		// this is the rectangle we try to keep the word they are viewing inside of
		// it is a little smaller than the whole area to make things look nice
		protected var _wordViewRectangle:Rectangle;
		// the padding that makes thw _wordViewRectangle smaller than the view rectangle
		protected static const WORD_VIEW_PADDING:Number = 30;
		protected static const CONTENT_TWEEN_DURATION:Number = 0.6;
		protected static const CONTENT_ZOOM_TWEEN_DURATION:Number = 0.1;
		protected var _contentMinScale:Number = -1; // this will be set to the zoom level that shows the whole puzzle
		//protected static const MAX_CONTENT_SCALE:Number = 3.8; // this zoom in amount is hard-coded
		// auto scale mode is when the user is not managing zoom on their own
		protected var _isAutoScaleMode:Boolean = true;
		// when in auto-scale mode, this is the scale it will go to / stay at when selecting words
		//protected static const AUTO_SCALE_PLAY_SCALE:Number = 1.0;
		protected var _theTween:GTween;
		// hardcoded zoom values
		protected static const NORMAL_MODE_SCALE:Number = 1.0; // square is 10,10
		protected static const SUPER_ZOOM_SCALE:Number = 1.9; // square is 20,20
		// organized from [most zoomed out ... most zoomed in]
		protected var _scaleLevels:Array;
		protected var _curScaleLevelIndex:int = 0; // start zoomed out
		public function get curScaleLevel():int
		{
			return _curScaleLevelIndex;
		}
		public function get maxScaleLevel():int
		{
			return _scaleLevels.length - 1;
		}
		public function get minScaleLevel():int
		{
			return 0;
		}
		// stores the rects that were last displayed
		// used for when we zoom -> we zoom based on the showing word
		protected var _shownWordRectangle:Rectangle = null;
		protected var _shownSpaceRectangle:Rectangle = null;
		public function CrosswordGrabZoomClip(tx:Number, ty:Number, w:Number, h:Number):void
		{
			x = tx;
			y = ty
			_width = w;
			_height = h;
			var theMask:MovieClip = new MovieClip();
			theMask.graphics.beginFill(0xffffff,1);
			theMask.graphics.drawRect(0, 0, _width, _height);
			theMask.graphics.endFill();
			addChild(theMask)
			this.mask = theMask;
			// TODO: i want mask to be this!
			//this.scrollRect = new Rectangle(x, y, _width, _height)
			_wordViewRectangle =  new Rectangle(WORD_VIEW_PADDING, WORD_VIEW_PADDING, _width - WORD_VIEW_PADDING*2, _height - WORD_VIEW_PADDING*2);
			// set up the clip for hearing mouse events
			_draggableBackground = new MovieClip();
			_draggableBackground.x = 0;
			_draggableBackground.y = 0;
			_draggableBackground.graphics.beginFill(0xffffff, 0.0);
			_draggableBackground.graphics.drawRect(0, 0, _width, _height);
			addChild(_draggableBackground);
			addEventListener(Event.ADDED_TO_STAGE, onAddedToStage, false, 0, true);
			content = new MovieClip();
			addChild(content);
			//this.addEventListener(Event.ENTER_FRAME, doit);
		}
		/*
		function doit(e)
		{
			graphics.clear();
			graphics.beginFill(0x00ff00, 0.3);
			graphics.drawRect(contentX, contentY, content.width, content.height);
			graphics.endFill();
		}
		*/
		protected function onAddedToStage(e:Event):void
		{
			removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
			_draggableBackground.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown, false, 0, true);
			stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp, false, 0, true);
			stage.addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove, false, 0, true);
			_draggableBackground.addEventListener(MouseEvent.MOUSE_WHEEL, onMouseWheel, false, 0, true);
		}
		protected function onMouseUp(e:MouseEvent):void
		{
			if(_dragging == true)
			{
				content.stopDrag();
				keepContentInBounds();
			}
			_dragging = false;
		}
		protected function onMouseDown(e:MouseEvent):void
		{
			cancelTheTween();
			_dragging = true;
		}
		protected function onMouseMove(e:MouseEvent):void
		{
			if(_dragging == true)
			{
				content.startDrag(false);
			}
		}
		// HACK FUNCTIONS FOR FIXING THE x/y
		// there is a thing with the puzzle where the puzzle gets drawn
		// 1 square down and 1 squar right of where the x,y, width and height
		// think it is
		// not sure why, and this is easier than going into that
		// NOTE: some(most?) functions wont use this
		//   arg.. this is ruff
		// also if you say: content.x = contentX,
		// the content will actually move...
		protected function get contentX():Number
		{
			// NOTE: 30 is the current boxsize of the crossword puzzle
			return content.x + 30 * content.scaleX
		}
		protected function get contentY():Number
		{
			// NOTE: 30 is the current boxsize of the crossword puzzle
			return content.y + 30 * content.scaleY;
		}
		// END HACK FUNCTIONS
		protected function keepContentInBounds(animate:Boolean = true):void
		{
			var contentRect:Rectangle =
				new Rectangle(contentX,
								contentY,
								content.width,
								content.height);
			//_wordViewRectangle.width can be thought of as the content width at the minimum scale
			// we increase the bounds of our dragging container using that amount
			var containerSizeIncrease:Number = content.scaleX / getMinContentScale();
			var containerRect:Rectangle =
				new Rectangle(_wordViewRectangle.x,
								_wordViewRectangle.y,
								 _wordViewRectangle.width,
								 _wordViewRectangle.height);
			var xMove:Number = 0;
			var yMove:Number = 0;
			var leftOffset:Number = containerRect.left - contentRect.left;
			var rightOffset:Number = containerRect.right - contentRect.right;
			if(leftOffset > 0 && rightOffset > 0)
			{
				// move right the minimum amount
				xMove += Math.min(leftOffset, rightOffset);
			}
			if( leftOffset < 0 && rightOffset < 0)
			{
				// move the maximum amount
				xMove += Math.max(leftOffset, rightOffset);
			}
			// if one neg an one pos, nothing needed to do
			var topOffset:Number = containerRect.top - contentRect.top;
			var bottomOffset:Number = containerRect.bottom - contentRect.bottom;
			if(topOffset > 0 && bottomOffset > 0)
			{
				// move right the minimum amount
				yMove += Math.min(topOffset, bottomOffset);
			}
			if( topOffset < 0 && bottomOffset < 0)
			{
				// move the maximum amount
				yMove += Math.max(topOffset, bottomOffset);
			}
			// if one neg an one pos, nothing needed to do
			// now move em
			if( animate)
			{
				cancelTheTween();
				_theTween = new GTween(content, 0.4, {x:content.x + xMove, y:content.y + yMove}, {ease:customTweenFunc});
			}
			else
			{
				content.x += xMove;
				content.y += yMove;
			}
			//content left can become more than container left
		}
		protected function cancelTheTween():void
		{
			if(_theTween)
			{
				_theTween.paused = true;
			}
		}
		public function setFirstSelectionZoomLevel():void
		{
			if( _curScaleLevelIndex == 0 && _scaleLevels.length > 2)
			{
				_curScaleLevelIndex = 1;
			}
		}
		public function zoomIn():void
		{
			doZooming(false, contentX + content.width/2, contentY + content.width/2);
		}
		public function zoomOut():void
		{
			doZooming(true, contentX + content.width/2, contentY + content.width/2);
		}
		// the mouse wheel will zoom in and out
		public function onMouseWheel(e:MouseEvent):void
		{
			doZooming( e.delta < 0, e.stageX, e.stageY);
		}
		protected function doZooming(zoomOut:Boolean, locX:Number, locY:Number):void
		{
			// NOTE: locX and Y will not be used if a word is selected
			var oldScale:Number = content.scaleX;
			var newScale:Number = oldScale; //content.scaleX + ( SCALE_MULTIPLIER * e.delta);
			if(zoomOut)
			{
				if(_curScaleLevelIndex == 0)
				{
					return;
				}
				_curScaleLevelIndex--;
			}
			else
			{
				if(_curScaleLevelIndex == _scaleLevels.length-1)
				{
					return;
				}
				_curScaleLevelIndex++;
			}
			newScale = _scaleLevels[_curScaleLevelIndex];
			cancelTheTween(); // so this doesnt interfere with a 'keep it on screen' tween
			if(_shownWordRectangle != null)
			{
				// zoom based on still showing that rectangle
				showWord(_shownWordRectangle, _shownSpaceRectangle, true);
			}
			else // use the previous zoom method: zoom based on the mouse pointer
			{
				var localPoint:Point = new Point((locX - this.x) - content.x,
													(locY - this.y) - content.y);
				var scaleChange:Number = (newScale / oldScale);
				var newLocalPointX:Number = localPoint.x * scaleChange;
				var newLocalPointY:Number = localPoint.y * scaleChange;
				var newX:Number = content.x - (newLocalPointX - localPoint.x);
				var newY:Number = content.y - (newLocalPointY - localPoint.y);
				// this code keeps things on screen when we zoom
				// remeber the x and the y
				var origX:Number = content.x;
				var origY:Number = content.y;
				var origScale:Number = content.scaleX;
				// instantly set the new x, y and scale
				content.x = newX;
				content.y = newY;
				content.scaleX = content.scaleY = newScale;
				// move the move that would need to happen to keep it all on screen
				keepContentInBounds(false); // dont animate here, we will make a tween in this func
				// restore the x,y and scale, but remember the 'keep it on screen' moves
				newX = content.x;
				newY = content.y;
				content.x = origX;
				content.y = origY
				content.scaleX = content.scaleY = origScale;
				_theTween = new GTween(content, CONTENT_ZOOM_TWEEN_DURATION,
					{x: newX, y: newY, scaleX: newScale, scaleY: newScale},
					{ease:customTweenFunc});
				_theTween.paused = false;
				dispatchEvent(new Event(EVENT_ZOOM_CHANGED, true));
			}
		}
		// this will be like the init function
		// it should be called after the content is set
		public function centerAndShowAllContent():void
		{
			_scaleLevels = [];
			_scaleLevels.push(getMinContentScale());
			if( getMinContentScale() < NORMAL_MODE_SCALE)
			{
				_scaleLevels.push(NORMAL_MODE_SCALE);
			}
			if(SUPER_ZOOM_SCALE > getMinContentScale())
			{
				_scaleLevels.push(SUPER_ZOOM_SCALE);
			}
			_curScaleLevelIndex = 0;
			content.scaleX = content.scaleY = _scaleLevels[_curScaleLevelIndex];
			content.x = ( _width - (content.width + contentX )) / 2.0;
			content.y = ( _height - (content.height + contentY )) / 2.0;
		}
		protected function getMinContentScale(forceReCompute:Boolean = false):Number
		{
			if(_contentMinScale != -1 && forceReCompute != true)
			{
				return _contentMinScale;
			}
			// NOTE: assuming content starts at 0,0, and width, height are good
			_contentMinScale = Math.min( _wordViewRectangle.width / content.width,
										_wordViewRectangle.height / content.height);
			return _contentMinScale;
		}
		protected function startContentMoving():void
		{
			_contentXMoveAmount = 0.0;
			_contentYMoveAmount = 0.0;
		}
		protected function endContentMoving():void
		{
			// this actually moves the content
			if(_contentXMoveAmount != 0 || _contentYMoveAmount != 0)
			{
				_theTween = new GTween(content, CONTENT_TWEEN_DURATION,
					{x: content.x + _contentXMoveAmount , y: content.y + + _contentYMoveAmount},
					{ease:customTweenFunc});
				_theTween.paused = false;
				_contentXMoveAmount = 0;
				_contentYMoveAmount = 0;
			}
		}
		protected static function customTweenFunc(t:Number, b:Number, c:Number, d:Number):Number
		{
			var ts:Number=(t/=d)*t;
			var tc:Number=ts*t;
			return b+c*(0*tc*ts + -1*ts*ts + 4*tc + -6*ts + 4*t);
		}
		//
		public function showWord(rect:Rectangle, mandatoryRect:Rectangle, doScaleChange:Boolean = false):void
		{
			// NOTE: about doScaleChange:
			// this is for when we have changed _curScaleLevelIndex, but we are counting on this function
			// to actually do the zooming to that scale
			_shownWordRectangle = rect;
			_shownSpaceRectangle = mandatoryRect;
			// fix up our zooming if we are in autoScale mode
			var prevScale:Number;
			if(doScaleChange)
			{
				// set our new scale, so the movement math will be done relative to it
				prevScale = content.scaleX;
				content.scaleX = _scaleLevels[_curScaleLevelIndex];
				content.scaleY = _scaleLevels[_curScaleLevelIndex];
			}
			// try to show the rectangle
			// mandatoryRect must be shown on screen
			startContentMoving();
			if(! (_curScaleLevelIndex == 0))  // at maximum zoom, we dont need any moving around
												// everything should already be showing
			{
				centerRect(rect);
				//showRectangle(rect); // first try and have the whole rect showing
				showRectangle(mandatoryRect); // now make sure that this part is showing
			}
			// make sure we are not going out of bounds with our word showins
			// do all of the moving
			var prevContentX:Number = content.x;
			var prevContentY:Number = content.y;
			content.x = content.x + _contentXMoveAmount;
			content.y = content.y + _contentYMoveAmount;
			// see how the content will need to be moved after moving
			keepContentInBounds(false);
			content.x -= _contentXMoveAmount;
			content.y -= _contentYMoveAmount;
			_contentXMoveAmount += content.x - prevContentX;
			_contentYMoveAmount += content.y - prevContentY;
			// move items back to where they were
			content.x = prevContentX;
			content.y = prevContentY;
			// now do the tweening
			endContentMoving();
			if(doScaleChange)
			{
				// re- set the scale, and tween to the new one
				content.scaleX = prevScale;
				content.scaleY = prevScale;
				_theTween = new GTween(content, CONTENT_TWEEN_DURATION, // not using CONTENT_ZOOM_TWEEN_DURATION
																		// to be consistent with the move tween
					{scaleX:  _scaleLevels[_curScaleLevelIndex], scaleY:  _scaleLevels[_curScaleLevelIndex]},
					{ease:customTweenFunc});
				_theTween.paused = false;
				dispatchEvent(new Event(EVENT_ZOOM_CHANGED, true));
			}
		}
		protected function centerRect(r:Rectangle):void
		{
			var newR:Rectangle = contentToLocalRectangle(r);
			// incase we are calling this function on multiple rects before
			//    endContentMoving is called
			newR.x += _contentXMoveAmount;
			newR.y += _contentYMoveAmount;
			var moveLeft:Boolean = newR.left < _wordViewRectangle.left
			var moveRight:Boolean = newR.right > _wordViewRectangle.right;
			var moveTop:Boolean = newR.top < _wordViewRectangle.top;
			var moveBottom:Boolean = newR.bottom > _wordViewRectangle.bottom;
			//need to do some keepContentInBounds
			_contentXMoveAmount += ((_wordViewRectangle.left - newR.left) + (-(newR.right - _wordViewRectangle.right))) / 2.0
			_contentYMoveAmount += ((_wordViewRectangle.top - newR.top) + (-(newR.bottom - _wordViewRectangle.bottom))) /2.0
		}
		// NOTE: call 'startContentMoving' before using this function
		protected function showRectangle(r:Rectangle):void
		{
			// r is a rect in content coordinates
			var newR:Rectangle = contentToLocalRectangle(r);
			// incase we are calling this function on multiple rects before
			//    endContentMoving is called
			newR.x += _contentXMoveAmount;
			newR.y += _contentYMoveAmount;
			var xMove:Number = 0.0;
			var yMove:Number = 0.0;
			var moveLeft:Boolean = newR.left < _wordViewRectangle.left
			var moveRight:Boolean = newR.right > _wordViewRectangle.right;
			if(moveLeft && moveRight)
			{
				// center it
				// average between the other 2 move options?
				// will that work?
				xMove = ((_wordViewRectangle.left - newR.left) + (-(newR.right - _wordViewRectangle.right))) / 2.0
			}
			else if( moveLeft )
			{
				xMove = _wordViewRectangle.left - newR.left;
			}
			else if( moveRight )
			{
				xMove = -(newR.right - _wordViewRectangle.right);
			}
			var moveTop:Boolean = newR.top < _wordViewRectangle.top;
			var moveBottom:Boolean = newR.bottom > _wordViewRectangle.bottom;
			if(moveTop && moveBottom)
			{
				// center it
				yMove = ((_wordViewRectangle.top - newR.top) + (-(newR.bottom - _wordViewRectangle.bottom))) /2.0
			}
			else if(moveTop)
			{
				yMove = _wordViewRectangle.top - newR.top;
			}
			else if(moveBottom)
			{
				yMove = -(newR.bottom - _wordViewRectangle.bottom);
			}
			_contentXMoveAmount += xMove;
			_contentYMoveAmount += yMove;
		}
		protected function contentToLocalRectangle(r:Rectangle):Rectangle
		{
			var topLeft:Point =
				this.globalToLocal( content.localToGlobal( new Point( r.x, r.y) ) );
			var bottomRight:Point =
				this. globalToLocal(content.localToGlobal( new Point( r.x + r.width, r.y + r.height) ) );
			var newWidth:Number = bottomRight.x - topLeft.x;
			var newHeight:Number = bottomRight.y - topLeft.y;
			return new Rectangle( topLeft.x, topLeft.y, newWidth, newHeight);
		}
	}
}