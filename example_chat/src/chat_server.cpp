#include "waku_server.hpp"
using websocketpp::server;
#include <iostream>
#include <set>

class client : public wakuserver::connection, public std::enable_shared_from_this<client> {
  public:
    client(server::handler::connection_ptr con) : wakuserver::connection(con) {
      m_id = id++;
    }
    void onopen() {
      std::cout << "onopen" << std::endl;
      client::connections.insert(shared_from_this());

      for(auto& h : client::connections) h->info("誰かきた");
    }

    void onclose() {
      std::cout << "onclose" << std::endl;
      client::connections.erase(shared_from_this());

      for(auto& h : client::connections) h->info("誰かでていった");
    }

    void chat(wakuserver::Msg msg) {
      std::cout << "  " << msg.name << ": " << msg.msg << std::endl;
      for(auto& h : client::connections) h->chatNotify(m_id, msg.name, msg.msg);
    }

  private:
    int m_id;

  private:
    static int id;
    static std::set<std::shared_ptr<client>> connections;
};
int client::id = 0;
std::set<std::shared_ptr<client>> client::connections;

void settimer(boost::asio::deadline_timer &timer) {
  timer.expires_from_now(boost::posix_time::seconds(30));
  timer.async_wait([&timer](const boost::system::error_code &error){
    std::cout << "on_timer" << std::endl;
    settimer(timer);
  });
}

int main(int argc, char* argv[]) {
  short port = 9003;

  if (argc == 2) {
    port = atoi(argv[1]);
  }

  try {
    server::handler::ptr handler(new wakuserver::server_handler<client>());
    server endpoint(handler);

    endpoint.alog().set_level(websocketpp::log::alevel::CONNECT);
    endpoint.alog().set_level(websocketpp::log::alevel::DISCONNECT);
    endpoint.elog().set_level(websocketpp::log::elevel::RERROR);
    endpoint.elog().set_level(websocketpp::log::elevel::FATAL);

    std::cout << "Starting chat server on port " << port << std::endl;

    //timer
    boost::asio::io_service &io_service = endpoint.get_io_service();
    boost::asio::deadline_timer timer(io_service);
    settimer(timer);

    endpoint.listen(port);
  } catch (std::exception& e) {
    std::cerr << "Exception: " << e.what() << std::endl;
  }

  return 0;
}
