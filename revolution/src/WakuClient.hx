package;

extern class Blob {}
extern class ArrayBuffer {}

extern class Uint8Array implements ArrayAccess<Int> {
  var buffer : ArrayBuffer;
  var length : Int;

  @:overload(function(len:Int):Void{})
  public function new(array:ArrayBuffer) : Void;
}

extern class WebSocket {
  static var CONNECTING : Int;
  static var OPEN : Int;
  static var CLOSING : Int;
  static var CLOSED : Int;

  var readyState(default,null) : Int;
  var bufferedAmount(default,null) : Int;

  dynamic function onopen() : Void;
  dynamic function onmessage(e:{data:ArrayBuffer}) : Void;
  dynamic function onclose() : Void;
  dynamic function onerror() : Void;

  var url(default,null) : String;
  var extensions(default,null) : String;
  var protocol(default,null) : String;
  var binaryType : String;

  function new( url : String, ?protocol : Dynamic ) : Void;
  function send( data : ArrayBuffer ) : Bool;
  function close( ?code : Int, ?reason : String ) : Void;
}

@:native("msgpack")
extern class Msgpack {
  static function pack(data:Dynamic):Dynamic;       //pack  ::json->array[]
  static function unpack(data:Uint8Array):Dynamic;  //unpack::array[]->json
}


class Point {
  public function new(x_:Int, y_:Int) {
    
    x = x_;
    
    y = y_;
    
  }

  public static function create(args:Dynamic):Point {
    if(args.length != 2) throw "new Point : wrong args";

    var tmp = new Point(
      
      cast(args[0], Int),
      
      cast(args[1], Int)
      
    );
    return tmp;
  }

  public function to_array():Array<Dynamic> {
    var tmp = new Array<Dynamic>();
    
    
    tmp.push(x);
    
    
    
    tmp.push(y);
    
    
    return tmp;
  }

  
  public var x:Int;
  
  public var y:Int;
  
}

class Char {
  public function new(id_:Int, name_:String, color_:String, point_:Point) {
    
    id = id_;
    
    name = name_;
    
    color = color_;
    
    point = point_;
    
  }

  public static function create(args:Dynamic):Char {
    if(args.length != 4) throw "new Char : wrong args";

    var tmp = new Char(
      
      cast(args[0], Int),
      
      Sanitizer.run(cast(args[1], String)),
      
      Sanitizer.run(cast(args[2], String)),
      
      Point.create(args[3])
      
    );
    return tmp;
  }

  public function to_array():Array<Dynamic> {
    var tmp = new Array<Dynamic>();
    
    
    tmp.push(id);
    
    
    
    tmp.push(Sanitizer.run(name));
    
    
    
    tmp.push(Sanitizer.run(color));
    
    
    
    tmp.push(point.to_array());
    
    
    return tmp;
  }

  
  public var id:Int;
  
  public var name:String;
  
  public var color:String;
  
  public var point:Point;
  
}


class Sanitizer {
  static public function run(str:String):String {
    str = StringTools.replace(str, "<", '&lt;');
    str = StringTools.replace(str, ">", '&gt;');
    str = StringTools.replace(str, '"', '&quot;');
    str = StringTools.replace(str, "'", '&apos;');
    return str;
  }
}

class Connection {
  private var m_socket:WebSocket;
  private var m_handshaked:Bool = false;
  private var m_commandNo:Int = -1024;
  private var m_functions:IntHash<Dynamic->Void>;

  public function new(host:String):Void {
    m_socket = new WebSocket(host);
    m_socket.binaryType = "arraybuffer";
    //=========================================================================================
    m_socket.onopen = function():Void {
      m_socket.onclose = onclose;
      m_socket.onmessage = function(e:{data:ArrayBuffer}):Void {
        try {
          var receive_data:Dynamic = Msgpack.unpack(new Uint8Array(e.data));
          if(receive_data.length != 3) return;

          var commandNo = cast(receive_data[0], Int);
          var functionNo = cast(receive_data[1], Int);
          var args:Dynamic = receive_data[2];

          if(functionNo >= 1000 && m_handshaked == false) return;
          var func = m_functions.get(functionNo);
          if(func == null) throw "non-existent function";
          func(args);
        }
        catch(errorMsg:String) {
          //クライアント側は変なデータきてもそのデータ無視するだけ。
          trace("wrong data received ["+errorMsg+"]");
        }
      }
      handshake();
    }
  }

  inline private function packData(commandNo:Int, functionNo:Int, args:Dynamic):ArrayBuffer {
    return (new Uint8Array(Msgpack.pack([commandNo, functionNo, args]))).buffer;
  }

  private function handshake():Void {
    m_handshaked = false;
    m_commandNo = -1024;
    m_functions = new IntHash<Dynamic->Void>();
    m_functions.set(0, handshakeReply);
    m_socket.send(packData(0, 0, ['7505bd6b4515be5096b47a62cebafcf948f01809']));
  }

  private function handshakeReply(data:Dynamic):Void {
    if(data.length != 2) return;
    try {
      m_handshaked = cast(data[0], Bool);
      m_commandNo  = cast(data[1], Int);
      if(m_handshaked == false) throw "reject";

      
      m_functions.set(8715, call_chatNotify);
      
      m_functions.set(6287, call_loginNotify);
      
      m_functions.set(5263, call_moveNotify);
      
      m_functions.set(6622, call_loginReply);
      
      m_functions.set(3858, call_logoutNotify);
      

      onopen();
    }
    catch(errorMsg:String) trace("handshake error[" + errorMsg + "]");
  }

//====================================================================================
  
  private function call_chatNotify(args:Dynamic) {
    if(args.length != 2) return;
    var tmp:Dynamic;
    
    
    var id:Int = cast(args[0], Int);
    
    
    
    var msg:String = Sanitizer.run(cast(args[1], String));
    
    
    chatNotify(id, msg);
  }
  
  private function call_loginNotify(args:Dynamic) {
    if(args.length != 1) return;
    var tmp:Dynamic;
    
    
    var status:Char = Char.create(args[0]);
    
    
    loginNotify(status);
  }
  
  private function call_moveNotify(args:Dynamic) {
    if(args.length != 2) return;
    var tmp:Dynamic;
    
    
    var id:Int = cast(args[0], Int);
    
    
    
    var to:Point = Point.create(args[1]);
    
    
    moveNotify(id, to);
  }
  
  private function call_loginReply(args:Dynamic) {
    if(args.length != 2) return;
    var tmp:Dynamic;
    
    
    var id:Int = cast(args[0], Int);
    
    
    
    tmp = args[1];
    var charList = new Array<Char>();
    for(i in 0...tmp.length) charList.push(Char.create(tmp[i]));
    
    
    loginReply(id, charList);
  }
  
  private function call_logoutNotify(args:Dynamic) {
    if(args.length != 1) return;
    var tmp:Dynamic;
    
    
    var id:Int = cast(args[0], Int);
    
    
    logoutNotify(id);
  }
  
  
  public function chatNotify(id:Int, msg:String):Void {}
  public function loginNotify(status:Char):Void {}
  public function moveNotify(id:Int, to:Point):Void {}
  public function loginReply(id:Int, charList:Array<Char>):Void {}
  public function logoutNotify(id:Int):Void {}
//====================================================================================

//====================================================================================
  
  public function chat(msg:String):Bool {
    if(!m_handshaked) return false;
    if(m_commandNo == 1000) m_commandNo = 0;
    m_socket.send(packData(m_commandNo++, 5106, [
    
    
    Sanitizer.run(msg)
    
    
    
    ]));
    return true;
  }
  
  public function move(to:Point):Bool {
    if(!m_handshaked) return false;
    if(m_commandNo == 1000) m_commandNo = 0;
    m_socket.send(packData(m_commandNo++, 1890, [
    
    
    to.to_array()
    
    
    
    ]));
    return true;
  }
  
  public function login(name:String, color:String):Bool {
    if(!m_handshaked) return false;
    if(m_commandNo == 1000) m_commandNo = 0;
    m_socket.send(packData(m_commandNo++, 5259, [
    
    
    Sanitizer.run(name)
    
    ,
    
    
    Sanitizer.run(color)
    
    
    
    ]));
    return true;
  }
  
//====================================================================================

  public function onopen():Void {}
  public function error(msg:String):Void {}
  public function onclose():Void {}
}