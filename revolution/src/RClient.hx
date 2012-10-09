package;

import Masquerade;
import WakuClient;
import createjs.easeljs.Stage;
import createjs.easeljs.Shape;
import createjs.easeljs.Text;
import createjs.easeljs.Ticker;
import createjs.easeljs.Shadow;
import createjs.easeljs.MouseEvent;
import js.Lib;
import js.JQuery;

typedef Point2D = {
  var x : Float;
  var y : Float;
}

class MoveEvent implements Event {
  public function new(id_:Int, to_:Point2D):Void {
    id = id_;
    to = to_;
    type = EventType.Move;
  }

  public var id(default, null)   : Int;
  public var to(default, null) : Point2D;
  public var type(default, null) : EventType;
}




//Process
class BGProcess extends Process {
  public function new(stage:Stage, processList:ProcessList, con:Connection):Void {
    super(stage, processList);
    bg = new Shape();
    bg.graphics.beginFill("#eeffee").drawRect(0, 0, 800, 600);
    stage.addChild(bg);
    bg.onClick = function(evt:MouseEvent) {
      con.move(new Point(Std.int(evt.stageX), Std.int(evt.stageY)));
      processList.addEvent(new MoveEvent(-1, {x:evt.stageX, y:evt.stageY}));  //-1は自分
    }
  }

  private var bg:Shape;
}

class CharProcess extends Process {
  public function new(id_:Int, name_:String, stage:Stage, processList:ProcessList, p_:Point2D, isMine_:Bool):Void {
    super(stage, processList);

    id = id_;
    p = to = p_;
    name = name_;
    receiveEventType = [EventType.Move];
    isMine = isMine_;

    circle = new Shape();
    circle.graphics.beginFill("#FF0000").drawCircle(0,0,8);
    namePlate = new Text(name, "10px Arial");
    namePlate.shadow = new Shadow("#000", 0, 0, 10);

    draw();
    addChild(namePlate);
    addChild(circle);

    charList.set(id, this);
  }

  public function erase() : Void{
    charList.remove(id);
    destructor();
  }

  public override function update(gameTime:GameTime, eventSender:EventSender) : Void {
    if(to.x == p.x && to.y == p.y) return;
    var s:Point2D = {x:to.x-p.x, y:to.y-p.y};
    var m = (gameTime/4)/Math.sqrt(s.x*s.x + s.y*s.y);
    var s2:Point2D = {x:s.x*m, y:s.y*m};
    if(Math.abs(s2.x) > Math.abs(s.x)) s2.x = s.x;
    if(Math.abs(s2.y) > Math.abs(s.y)) s2.y = s.y;

    p.x += s2.x;
    p.y += s2.y;
    draw();
  }

  public override function receiveEvent(e:Event) : Void {
    if(e.type == EventType.Move) {
      var event:MoveEvent = cast(e, MoveEvent);
      if((!isMine && event.id == id) || (isMine && event.id == -1)) {
        to = event.to;
        draw();
      }
    }
  }

  private function draw() : Void {
    circle.x = p.x;
    circle.y = p.y;
    namePlate.x = p.x;
    namePlate.y = p.y+10;
  }

  private var circle:Shape;
  private var namePlate:Text;
  private var id:Int;
  private var p:Point2D;
  private var to:Point2D;
  private var isMine:Bool;
  public var name(default, null):String;
  static public var charList:IntHash<CharProcess> = new IntHash<CharProcess>();
}













class Client extends Connection {
  public function new(host:String, stage_:Stage, processList_:ProcessList):Void {
    stage = stage_;
    processList = processList_;
    super(host);
  }

  override public function onopen():Void {
    trace("onopen");
  }

  override public function onclose():Void {
    trace("onclose");
    var mes = new Text("サーバーとの接続が切れました", "30px Arial");
    mes.x = mes.y = 50;
    stage.addChild(mes);
  }

  static public function addtext(text:String):Void {
    new JQuery("div#chat").prepend("<div>" + text + "</div>");
  }

  override public function chatNotify(id:Int, msg:String):Void {
    trace("chatNotify");
    trace(id);
    trace(msg);
    var c:CharProcess = CharProcess.charList.get(id);
    addtext(c.name+":"+msg);
  }

  override public function loginNotify(status:Char):Void {
    trace("loginNotify");
    processList.addProcess(new CharProcess(status.id, status.name, stage, processList, {x:status.point.x, y:status.point.y}, false));
  }

  override public function moveNotify(id:Int, to:Point):Void {
    trace("moveNotify");
    processList.addEvent(new MoveEvent(id, {x:to.x, y:to.y}));
  }

  override public function loginReply(id:Int, charList:Array<Char>):Void {
    trace("loginReply");
    for(c in charList) {
      processList.addProcess(new CharProcess(c.id, c.name, stage, processList, {x:c.point.x, y:c.point.y}, (c.id == id)));
    }
  }

  override public function logoutNotify(id:Int):Void {
    trace("logoutNotify");
    var c:CharProcess = CharProcess.charList.get(id);
    c.erase();
  }

  private var stage:Stage;
  private var processList:ProcessList;
}


class RClient {
  private var stage:Stage;
  private var processList:ProcessList;
  private var connection:Client;
  public static function main():Void {
    new RClient();
  }

  public function new():Void {
    new JQuery(Lib.document).ready(function(e) {
      Lib.window.onload = initHandler;
    });
  }

  public function addtext(text:String):Void {
    new JQuery("div#chat").prepend("<div>" + text + "</div>");
  }

  private function initHandler(_):Void {
    new JQuery("#message").attr('disabled', 'true');
    new JQuery("#send").attr('disabled', 'true');
    new JQuery("#login").click(function(){
      //login button
      var name:String = new JQuery("#name").val();
      new JQuery("#name").attr('disabled', 'true');
      new JQuery("#login").attr('disabled', 'true');
      new JQuery("#message").removeAttr('disabled');
      new JQuery("#send").removeAttr('disabled');
      connection.login(name, "#FF0000");
    });

    new JQuery("#send").click(function(){
      //send button
      var message:String = new JQuery("#message").val();
      new JQuery("#message").val("");
      connection.chat(message);
    });

    stage = new Stage(cast js.Lib.document.getElementById("canvas"));
    processList = new ProcessList();
    connection = new Client('ws://localhost:9003/', stage, processList);

    processList.addProcess(new BGProcess(stage, processList, connection));

    Ticker.setFPS(30);
    Ticker.addListener(tick);
  }

  private function tick():Void {
    processList.tick();
    stage.update();
  }
}
