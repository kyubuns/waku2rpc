import std.stdio;
import vibe.d;
import vibe.core.signal;
import msgpack;

{% for struct in structs %}
struct {{struct.name}} {
  {% for arg in struct.args %}
  {{arg.type}} {{arg.name}};{% endfor %}
}
{% endfor %}

template SendDataType(ArgT) {
  int commandNo;
  int functionNo;
  ArgT args;
}

class Connection {
  this(WebSocket socket) {
    m_socket = socket;
    m_functions[0] = &handshakeRequest;
  }
  void onopen() {}
  void onclose() {}

  final void run() {
    m_signal = createSignal();
    m_signal.acquire();
    while(m_socket.connected){
      if(m_socket.dataAvailableForRead()){
        ubyte[] receiveData = m_socket.receive();
        onmessage(receiveData);
      }
      foreach(message; m_messageQueue) { m_socket.send(message); }
      m_messageQueue = [];
      rawYield();
    }
    m_signal.release();
    onclose();
  }

  final void close() {
    //m_socket.close();
    writeln("connection close");
  }

  //===private
  private void onmessage(ubyte[] receiveData) {
    try {
      auto unpacker = StreamingUnpacker(receiveData);
      unpacker.execute();
      int commandNo  = unpacker.unpacked[0].as!(int);
      int functionNo = unpacker.unpacked[1].as!(int);
      Unpacked args = unpacker.unpacked[2];

      if(functionNo >= 1000) {
        if(m_handshaked == false) throw new Exception("not handshaked client");
        m_commandNo++;
        if(m_commandNo == 1000) m_commandNo = 0;
        if(commandNo != m_commandNo) {
          //string mes = "wrong command No. Actual-"+to!(string)(commandNo)+", m_commandNo-"+to!(string)(m_commandNo);
          throw new Exception("wrong command No.");
        }
      }
      auto func = (functionNo in m_functions);
      if(func is null) {
        //throw "non-existent function - " + itos(function_no);
        throw new Exception("non-existent function");
      }
      (*func)(args);
    }
    catch(Exception e) {
      writeln("ERROR: ", e);
    }
  }

  //==override
  //====================================================================================
  {% for function in CtoS %}
  struct {{function.name}}Args {
    {% for arg in function.args %}{{arg.type}} {{arg.name}};
    {% endfor %}}

  void {{function.name}}Call(Unpacked receiveArgs) {
    try {
      auto args = receiveArgs.as!({{function.name}}Args);
      {{function.name}}({% for arg in function.args %}args.{{arg.name}}{% if not loop.last %}, {% endif %}{% endfor %});
    }
    catch(Exception e) {
      writeln("ERROR: [call_chat]", e);
    }
  }
  {% endfor %}
  {% for function in CtoS %}
  void {{function.name}}({% for arg in function.args %}{{arg.type}} {{arg.name}}{% if not loop.last %}, {% endif %}{% endfor %}) {}{% endfor %}
  //====================================================================================

  //====================================================================================

  {% for function in StoC %}
  struct {{function.name}}Args {
    {% for arg in function.args %}{{arg.type}} {{arg.name}};
    {% endfor %}
  }

  struct {{function.name}}Type {
    mixin SendDataType!({{function.name}}Args);
  }

  bool {{function.name}}({% for arg in function.args %}{{arg.type}} {{arg.name}}{% if not loop.last %}, {% endif %}{% endfor %}) {
    if(!m_handshaked) return false;
    try {
      {{function.name}}Type senddata;
      senddata.commandNo = m_commandNo;
      senddata.functionNo = {{function.id}};
      {% for arg in function.args %}
      senddata.args.{{arg.name}} = {{arg.name}};{% endfor %}
      send(pack(senddata));
    }
    catch(Exception e) {
      writeln("SEND ERROR: [{{function.id}}]", e);
      return false;
    }
    return true;
  }
  {% endfor %}

  //====================================================================================
  private void send(ubyte[] buf) {
    m_messageQueue ~= buf;
    m_signal.emit();
  }

  struct handshakeArgs {
    string hash;
  }

  struct handshakeReturnArgs {
    bool result;
    int commandNo;
  }

  struct handshakeReturnType {
    mixin SendDataType!(handshakeReturnArgs);
  }

  private void handshakeRequest(Unpacked receiveArgs) {
    try {
      auto args = receiveArgs.as!(handshakeArgs);
      if(args.hash != "{{yuuversion}}") throw new Exception("wrong version");
      m_handshaked = true;
      m_commandNo = -1;//handshakeで0を返すと次にClientから返ってくる値は-1 + 1のため
    }
    catch(Exception e) {
      writeln("ERROR: [handshake]", e);
    }

    {
      handshakeReturnType senddata;
      senddata.commandNo = 0;
      senddata.functionNo = 0;
      senddata.args.result = m_handshaked;
      senddata.args.commandNo = 0;
      send(pack(senddata));
    }
    if(m_handshaked == false) {
      close();
      return;
    }
    {% for function in CtoS %}
    m_functions[{{function.id}}] = &{{function.name}}Call;{% endfor %}

    onopen();
  }

  //====================================================================================
  private WebSocket m_socket;
  private Signal m_signal;
  private ubyte[][] m_messageQueue;
  private void delegate(Unpacked)[int] m_functions;
  private bool m_handshaked;
  private int m_commandNo;
}

