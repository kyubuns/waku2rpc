#ifndef WAKUSERVER_HPP
#define WAKUSERVER_HPP

#include <websocketpp/websocketpp.hpp>
#include <functional>
#include <stdexcept>
#include <map>
#include <msgpack.hpp>
#include <memory>
#include <boost/lexical_cast.hpp>

using websocketpp::server;

namespace wakuserver {

{% for struct in structs %}
struct {{struct.name}} {
  {% for arg in struct.args %}
  {{arg.type}} {{arg.name}};
  {% endfor %}
  MSGPACK_DEFINE({% for arg in struct.args %}{{arg.name}}{% if not loop.last %}, {% endif %}{% endfor %});
};
{% endfor %}


std::string itos(int i) {
  return boost::lexical_cast<std::string>(i);
}

template<class T>
struct send_datatype{
  int command_no;
  int function_no;
  T args;

  MSGPACK_DEFINE(command_no, function_no, args);
};

struct handshakereply_type {
  bool result;
  int command_no;
  MSGPACK_DEFINE(result, command_no);
};

class connection {
public:
  connection(server::handler::connection_ptr con) : m_con(con), m_handshaked(false), m_command_no(0) {
    m_functions.insert(std::make_pair(0, std::bind(&connection::handshake_request, this, std::placeholders::_1)));
  }
  virtual ~connection() {}
  virtual void onopen() {}
  virtual void onclose() {}
  void onmessage(const msgpack::unpacked &receive_data) {
    msgpack::type::tuple<int, int, msgpack::object> datatypes;
    try{
      receive_data.get().convert(&datatypes);
      int command_no  = datatypes.get<0>();
      int function_no = datatypes.get<1>();
      msgpack::object &args = datatypes.get<2>();

      if(function_no >= 1000) {
        if(m_handshaked == false) throw std::runtime_error("not handshaked client");
        m_command_no++;
        if(m_command_no == 1000) m_command_no = 0;
        if(command_no != m_command_no) throw std::runtime_error("wrong command NO. Actual-"+itos(command_no)+", m_command_no-" + itos(m_command_no));
      }
      auto func = m_functions.find(function_no);
      if(func == m_functions.end()) throw "non-existent function - " + itos(function_no);
      func->second(args);
    }
    catch (std::runtime_error &e) {
      std::cout << "ERROR!: " << e.what() << std::endl;
      m_con->close(websocketpp::close::status::NORMAL);
    }
    catch (...) {
      std::cout << "parse error" << std::endl;
    }
  }

  void send(msgpack::sbuffer& sbuf) {
    std::string data(reinterpret_cast<char*>(sbuf.data()), sbuf.size());
    m_con->send(data, websocketpp::frame::opcode::BINARY);
  }

//====================================================================================
  {% for function in CtoS %}
  struct {{function.name}}_argtype {
    {% for arg in function.args %}
    {{arg.type}} {{arg.name}};
    {% endfor %}
    MSGPACK_DEFINE({% for arg in function.args %}{{arg.name}}{% if not loop.last %}, {% endif %}{% endfor %});
  };

  void call_{{function.name}}(msgpack::object &obj) {
    try {
      {{function.name}}_argtype args;
      obj.convert(&args);
      {{function.name}}({% for arg in function.args %}std::move(args.{{arg.name}}){% if not loop.last %}, {% endif %}{% endfor %});
    } catch(...) {
      std::cout << "parse error: {{function.name}}" << std::endl;
    }
  }
  virtual void {{function.name}}({% for arg in function.args %}{{arg.type}} {{arg.name}}{% if not loop.last %}, {% endif %}{% endfor %}) {}
  {% endfor %}
//====================================================================================

//====================================================================================
  {% for function in StoC %}
  struct {{function.name}}_argtype {
    {% for arg in function.args %}
    {{arg.type}} {{arg.name}};
    {% endfor %}
    MSGPACK_DEFINE({% for arg in function.args %}{{arg.name}}{% if not loop.last %}, {% endif %}{% endfor %});
  };

  bool {{function.name}}({% for arg in function.args %}{{arg.type}} {{arg.name}}_{% if not loop.last %}, {% endif %}{% endfor %}) {
    if(!m_handshaked) return false;
    try {
      send_datatype<{{function.name}}_argtype> senddata;
      senddata.command_no  = m_command_no;
      senddata.function_no = {{function.id}};
      {% for arg in function.args %}
      senddata.args.{{arg.name}} = {{arg.name}}_;
      {% endfor %}
      msgpack::sbuffer sbuf;
      msgpack::pack(sbuf, senddata);
      send(sbuf);
    } catch(std::runtime_error &e) {
      std::cout << "send error: " << e.what() << std::endl;
      return false;
    }
    return true;
  }
  {% endfor %}
//====================================================================================

private:
  void handshake_request(msgpack::object &args) {
    std::vector<std::string> argtypes;
    try {
      args.convert(&argtypes);
      if(argtypes.size() != 1) throw std::runtime_error("wrong arg size");
      if(argtypes[0] != "{{yuuversion}}") throw std::runtime_error("wrong version");
      m_handshaked = true;
      m_command_no = -1;//handshakeで0を返すと次にClientから返ってくる値は-1 + 1のため
    }
    catch (std::runtime_error &e) {
      std::cout << "handshake error[" << e.what() << "]" << std::endl;
    }

    {
      send_datatype<handshakereply_type> senddata;
      senddata.command_no = 0;
      senddata.function_no = 0;
      senddata.args.result = m_handshaked;
      senddata.args.command_no = 0;
      msgpack::sbuffer sbuf;
      msgpack::pack(sbuf, senddata);
      send(sbuf);
    }
    if(m_handshaked == false) {
      m_con->close(websocketpp::close::status::PROTOCOL_ERROR);
      return;
    }

    {% for function in CtoS %}
    m_functions.insert(std::make_pair({{function.id}}, std::bind(&connection::call_{{function.name}}, this, std::placeholders::_1)));
    {% endfor %}

    onopen();
  }

private:
  server::handler::connection_ptr m_con;
  bool m_handshaked;
  int m_command_no;
  std::map<int, std::function<void(msgpack::object&)>> m_functions;
};

template<class T>
class server_handler : public server::handler {
public:
  void on_open(connection_ptr con) {
    m_connections.insert(std::make_pair(con, std::make_shared<T>(con)));
  }

  void on_close(connection_ptr con) {
    auto it = m_connections.find(con);
    if (it == m_connections.end()) return;
    it->second->onclose();
    m_connections.erase(it);
  }

  void on_message(connection_ptr con, message_ptr msg) {
    if (msg->get_opcode() != websocketpp::frame::opcode::BINARY) return;

    msgpack::unpacked receive_data;
    msgpack::unpack(&receive_data, msg->get_payload().c_str(), msg->get_payload().size());
    try {
      m_connections[con]->onmessage(receive_data);
    }
    catch (std::runtime_error &e) {
      std::cout << "ERROR!: on_message - " << e.what() << std::endl;
    }
    catch(...) {
      std::cout << "ERROR!: on_message" << std::endl;
    }
  }

private:
  std::map<connection_ptr, std::shared_ptr<T>> m_connections;
};

}
#endif
