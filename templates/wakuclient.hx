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

{% for struct in structs %}
class {{struct.name}} {
  public function new({% for arg in struct.args %}{% if not loop.first %}, {% endif %}{{arg.name}}_:{{arg.type}}{% endfor %}) {
    {% for arg in struct.args %}
    {{arg.name}} = {{arg.name}}_;
    {% endfor %}
  }

  public static function create(args:Dynamic):{{struct.name}} {
    if(args.length != {{struct.args|length}}) throw "new {{struct.name}} : wrong args";

    var tmp = new {{struct.name}}(
      {% for arg in struct.args %}
      {{loop.index0|to_arg|cast_hx(arg.type)}}{% if not loop.last %},{% endif %}
      {% endfor %}
    );
    return tmp;
  }

  public function to_array():Array<Dynamic> {
    var tmp = new Array<Dynamic>();
    {% for arg in struct.args %}
    {% if arg.type == 'String' %}
    tmp.push(Sanitizer.run({{arg.name}}));
    {% elif arg.type == 'Array<String>' %}
    tmp.push(Lambda.array(Lambda.map({{arg.name}}, Sanitizer.run)));
    {% elif arg.originaltype is classname %}
    tmp.push({{arg.name}}.to_array());
    {% else %}
    tmp.push({{arg.name}});
    {% endif %}
    {% endfor %}
    return tmp;
  }

  {% for arg in struct.args %}
  public var {{arg.name}}:{{arg.type}};
  {% endfor %}
}
{% endfor %}

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
          trace(receive_data);
          if(receive_data.length != 3) return;

          var commandNo = {{'receive_data[0]'|cast_hx('Int')}};
          var functionNo = {{'receive_data[1]'|cast_hx('Int')}};
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
    m_socket.send(packData(0, 0, ['{{yuuversion}}']));
  }

  private function handshakeReply(data:Dynamic):Void {
    if(data.length != 2) return;
    try {
      m_handshaked = {{'data[0]'|cast_hx('Bool')}};
      m_commandNo  = {{'data[1]'|cast_hx('Int')}};
      if(m_handshaked == false) throw "reject";

      {% for function in StoC %}
      m_functions.set({{function.id}}, call_{{function.name}});
      {% endfor %}

      onopen();
    }
    catch(errorMsg:String) trace("handshake error[" + errorMsg + "]");
  }

//====================================================================================
  {% for function in StoC %}
  private function call_{{function.name}}(args:Dynamic) {
    if(args.length != {{function.args|length}}) return;
    var tmp:Dynamic;
    {% for arg in function.args %}
    {% if arg.is_array %}
    tmp = {{loop.index0|to_arg}};
    var {{arg.name}} = new {{arg.type}}();
    for(i in 0...tmp.length) {{arg.name}}.push({{"tmp[i]"|cast_hx(arg.elementtype)}});
    {% else %}
    var {{arg.name}}:{{arg.type}} = {{loop.index0|to_arg|cast_hx(arg.type)}};
    {% endif %}
    {% endfor %}
    {{function.name}}({% for arg in function.args %}{{arg.name}}{% if not loop.last %}, {% endif %}{% endfor %});
  }
  public function {{function.name}}({% for arg in function.args %}{{arg.name}}:{{arg.type}}{% if not loop.last %}, {% endif %}{% endfor %}):Void {}
  {% endfor %}
//====================================================================================

//====================================================================================
  {% for function in CtoS %}
  public function {{function.name}}({% for arg in function.args %}{{arg.name}}:{{arg.type}}{% if not loop.last %}, {% endif %}{% endfor %}):Bool {
    if(!m_handshaked) return false;
    if(m_commandNo == 1000) m_commandNo = 0;
    m_socket.send(packData(m_commandNo++, {{function.id}}, [
    {% for arg in function.args %}
    {% if arg.type == 'String' %}
    Sanitizer.run({{arg.name}})
    {% elif arg.type == 'Array<String>' %}
    Lambda.array(Lambda.map({{arg.name}}, Sanitizer.run))
    {% elif arg.originaltype is classname %}
    {{arg.name}}.to_array()
    {% else %}
    {{arg.name}}
    {% endif %}
    {% if not loop.last %},{% endif %}
    {% endfor %}
    ]));
    return true;
  }
  {% endfor %}
//====================================================================================

  public function onopen():Void {}
  public function error(msg:String):Void {}
  public function onclose():Void {}
}
