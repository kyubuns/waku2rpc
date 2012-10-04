#include "waku_server.hpp"
using websocketpp::server;
#include <iostream>
#include <set>

class hoge : public wakuserver::connection, public std::enable_shared_from_this<hoge> {
public:
  hoge(server::handler::connection_ptr con) : wakuserver::connection(con) {
    m_id = id++;
  }
  void onopen() {
    std::cout << "onopen" << std::endl;
    hoge::connections.insert(shared_from_this());

    for(auto& h : hoge::connections) h->info("誰かきた");
  }

  void onclose() {
    std::cout << "onclose" << std::endl;
    hoge::connections.erase(shared_from_this());

    for(auto& h : hoge::connections) h->info("誰かでていった");
  }

  void chat(wakuserver::Msg msg) {
    std::cout << "  " << msg.name << ": " << msg.msg << std::endl;
    for(auto& h : hoge::connections) h->chatNotify(m_id, msg.name, msg.msg);
  }

private:
  int m_id;

private:
  static int id;
  static std::set<std::shared_ptr<hoge>> connections;
};
int hoge::id = 0;
std::set<std::shared_ptr<hoge>> hoge::connections;

int main(int argc, char* argv[]) {
    short port = 9003;
    
    if (argc == 2) {
        // TODO: input validation?
        port = atoi(argv[1]);
    }
    
    try {
        // create an instance of our handler
        server::handler::ptr handler(new wakuserver::server_handler<hoge>());
        
        // create a server that listens on port `port` and uses our handler
        server endpoint(handler);
        
        endpoint.alog().set_level(websocketpp::log::alevel::CONNECT);
        endpoint.alog().set_level(websocketpp::log::alevel::DISCONNECT);
        
        endpoint.elog().set_level(websocketpp::log::elevel::RERROR);
        endpoint.elog().set_level(websocketpp::log::elevel::FATAL);
        
        // setup server settings
        // Chat server should only be receiving small text messages, reduce max
        // message size limit slightly to save memory, improve performance, and 
        // guard against DoS attacks.
        //server->set_max_message_size(0xFFFF); // 64KiB
        
        std::cout << "Starting chat server on port " << port << std::endl;
        
//        boost::asio::io_service &a = endpoint.get_io_service();
        endpoint.listen(port);
    } catch (std::exception& e) {
        std::cerr << "Exception: " << e.what() << std::endl;
    }
    
    return 0;
}
