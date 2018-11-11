package boost.h2.d.geom;

import hxmath.math.Vector2;

using hxd.Math;
using hxmath.math.MathUtil;

typedef PolygonType = {
  x:Float,
  y:Float,
  vertices:Array<Vector2>,
  rotation:Float
}

class Polygon extends Shape {
  public var vertices:Array<Vector2>;
  @:isVar public var rotation(get, set):Float;

  public function new(x:Float = 0, y:Float = 0, ?vertices:Array<Vector2>, rotation:Float = 0) {
    super(x, y);
    this.vertices = vertices == null ? [] : vertices;
    this.rotation = rotation;
  }

  public function from_rect() {}

  public function from_circle(sub_divisions:Int = 3) {}

  // getters
  function get_rotation():Float return rotation;

  // setters
  function set_rotation(value:Float):Float return rotation = value;
}
