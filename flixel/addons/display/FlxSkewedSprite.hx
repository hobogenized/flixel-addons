package flixel.addons.display;

import flash.geom.Matrix;
import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxFrame.FlxFrameAngle;
import flixel.graphics.frames.FlxFrame.FlxFrameType;
import flixel.graphics.tile.FlxDrawTilesItem;
import flixel.system.FlxAssets;
import flixel.math.FlxAngle;
import flixel.util.FlxDestroyUtil;
import flixel.math.FlxPoint;

/**
 * ...
 * @author Zaphod
 */
class FlxSkewedSprite extends FlxSprite
{
	public var skew(default, null):FlxPoint;
	
	/**
	 * Tranformation matrix for this sprite.
	 * Used only when matrixExposed is set to true
	 */
	public var transformMatrix(default, null):Matrix;
	
	/**
	 * Bool flag showing whether transformMatrix is used for rendering or not.
	 * False by default, which means that transformMatrix isn't used for rendering
	 */
	public var matrixExposed:Bool = false;
	
	/**
	 * Internal helper matrix object. Used for rendering calculations when matrixExposed is set to false
	 */
	private var _skewMatrix:Matrix;
	
	public function new(X:Float = 0, Y:Float = 0, ?SimpleGraphic:FlxGraphicAsset)
	{
		super(X, Y, SimpleGraphic);
		
		skew = FlxPoint.get();
		_skewMatrix = new Matrix();
		transformMatrix = new Matrix();
	}
	
	/**
	 * WARNING: This will remove this sprite entirely. Use kill() if you 
	 * want to disable it temporarily only and reset() it later to revive it.
	 * Used to clean up memory.
	 */
	override public function destroy():Void 
	{
		skew = FlxDestroyUtil.put(skew);
		_skewMatrix = null;
		transformMatrix = null;
		
		super.destroy();
	}
	
	override public function draw():Void 
	{
		if (alpha == 0 || frame.type == FlxFrameType.EMPTY)
		{
			return;
		}
		
		if (dirty)	//rarely 
		{
			calcFrame();
		}
		
	#if FLX_RENDER_TILE
		var drawItem:FlxDrawTilesItem;
		
		var ox:Float = origin.x;
		if (_facingHorizontalMult != 1)
		{
			ox = frameWidth - ox;
		}
		var oy:Float = origin.y;
		if (_facingVerticalMult != 1)
		{
			oy = frameHeight - oy;
		}
	#end
		
		for (camera in cameras)
		{
			if (!isOnScreen(camera) || !camera.visible || !camera.exists)
			{
				continue;
			}

			getScreenPosition(_point, camera).subtractPoint(offset);
		
#if FLX_RENDER_BLIT
			if (isSimpleRender(camera))
			{
				_point.floor().copyToFlash(_flashPoint);
				camera.buffer.copyPixels(framePixels, _flashRect, _flashPoint, null, null, true);
			}
			else 
			{
				_matrix.identity();
				_matrix.translate( -origin.x, -origin.y);
				
				if (matrixExposed)
				{
					_matrix.concat(transformMatrix);
				}
				else
				{
					if ((angle != 0) && (bakedRotationAngle <= 0))
					{
						_matrix.rotate(angle * FlxAngle.TO_RAD);
					}
					_matrix.scale(scale.x, scale.y);
					
					updateSkewMatrix();
					_matrix.concat(_skewMatrix);
				}
				
				_point.addPoint(origin).floor();
				
				_matrix.translate(_point.x, _point.y);
				camera.buffer.draw(framePixels, _matrix, null, blend, null, antialiasing);
			}
#else
			drawItem = camera.getDrawTilesItem(frame.parent, isColored, _blendInt, antialiasing);
			
			_matrix.identity();
			
			if (frame.angle != FlxFrameAngle.ANGLE_0)
			{
				// handle rotated frames
				frame.prepareFrameMatrix(_matrix);
			}
			
			var x1:Float = (ox - frame.center.x);
			var y1:Float = (oy - frame.center.y);
			_matrix.translate(x1, y1);
			
			if (!matrixExposed)
			{
				var sx:Float = scale.x * _facingHorizontalMult;
				var sy:Float = scale.y * _facingVerticalMult;
				
				if (_angleChanged && (bakedRotationAngle <= 0))
				{
					var radians:Float = angle * FlxAngle.TO_RAD;
					_sinAngle = Math.sin(radians);
					_cosAngle = Math.cos(radians);
					_angleChanged = false;
				}
				_matrix.rotateWithTrig(_cosAngle, _sinAngle);
				
				_matrix.scale(sx * camera.totalScaleX, sy * camera.totalScaleY);
				
				if (!isSimpleRender(camera))
				{
					updateSkewMatrix();
					_matrix.concat(_skewMatrix);
				}
			}
			else
			{
				_matrix.scale(camera.totalScaleX, camera.totalScaleY);
				_matrix.concat(transformMatrix);
			}
			
			_point.addPoint(origin);
			
			_point.x *= camera.totalScaleX;
			_point.y *= camera.totalScaleY;
			
			if (isPixelPerfectRender(camera))
			{
				_point.floor();
			}
			
			_point.subtract(_matrix.tx, _matrix.ty);
			
			setDrawData(drawItem, camera, _matrix);
#end
			#if !FLX_NO_DEBUG
			FlxBasic.activeCount++;
			#end
		}
	}
	
	private function updateSkewMatrix():Void
	{
		_skewMatrix.identity();
		
		if ((skew.x != 0) || (skew.y != 0))
		{
			_skewMatrix.b = Math.tan(skew.y * FlxAngle.TO_RAD);
			_skewMatrix.c = Math.tan(skew.x * FlxAngle.TO_RAD);
		}
	}
	
	override public function isSimpleRender(?camera:FlxCamera):Bool
	{
		return super.isSimpleRender(camera) && (skew.x == 0) && (skew.y == 0) && (!matrixExposed);
	}
}
