package ghost.debug;

import hxmath.math.MathUtil;
import echo.util.Disposable;
import ghost.ui.Button;
import h2d.Text;
import h2d.Object;
import h2d.Tile;
import h2d.Flow;

class Plugin implements IDisposable {
  public var name:String;
  public var active:Bool;
  // temp, display text until i figure out asset loading from external libraries ;p
  public var icon:Button; // BitmapButton;?
  public var debugger:Debugger;

  var canvas:Object;
  var panel:Flow;
  var header:Flow;
  var base:Flow;
  var dragging:Bool;

  public function new(name:String, ?icon:Tile) {
    this.name = name;
    // this.icon = new Bitmap(icon);
    this.icon = new Button(name, () -> active ? hide() : show());
    this.icon.scale(2);
    active = false;
    dragging = false;
    canvas = new Object();
    canvas.visible = false;
    panel = new Flow();
    panel.layout = Vertical;
    panel.visible = false;
    panel.scale(2);
    header = new Flow(panel);
    header.enableInteractive = true;
    header.interactive.onPush = function(_) dragging = true;
    header.interactive.onRelease = function(_) dragging = false;
    header.padding = 2;
    header.verticalAlign = Middle;
    header.backgroundTile = Tile.fromColor(0x000000, 1, 1, 0.7);
    var t = new Text(hxd.res.DefaultFont.get(), header);
    t.text = name;
    base = new Flow(panel);
    base.padding = 2;
    base.backgroundTile = Tile.fromColor(0x000000, 1, 1, 0.2);
  }

  public function attach(debugger:Debugger) {
    this.debugger = debugger;
    debugger.canvas.addChild(canvas);
    debugger.panels.addChild(panel);
  }

  public function remove() {
    if (debugger != null) debugger.remove(this);
    hide();
    canvas.remove();
    panel.remove();
    icon.remove();
  }

  public function refresh() {
    header.minWidth = base.outerWidth;
    if (dragging) {
      panel.setPosition(MathUtil.clamp(debugger.game.s2d.mouseX - 24, 0, debugger.game.s2d.width - panel.outerWidth),
        MathUtil.clamp(debugger.game.s2d.mouseY
          - (debugger.menu.visible ? debugger.menu.outerHeight : 0)
          - 24, 0,
          debugger.game.s2d.height
          - header.outerHeight));
    }
  }

  public function show() {
    active = true;
    canvas.visible = true;
    panel.visible = true;
    panel.needReflow = true;
  }

  public function hide() {
    active = false;
    canvas.visible = false;
    panel.visible = false;
  }

  public function dispose() {
    active = false;
    dragging = false;
    icon.remove();
    canvas.remove();
    panel.remove();
    header.remove();
    base.remove();
    icon = null;
    canvas = null;
    panel = null;
    header = null;
    base = null;
    debugger.remove(this);
    debugger = null;
  }
}
