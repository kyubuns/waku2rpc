#include "waku_server.hpp"
using websocketpp::server;
#include <iostream>
#include <set>

class client : public wakuserver::connection, public std::enable_shared_from_this<client> {
  public:
    client(server::handler::connection_ptr con) : wakuserver::connection(con), m_isAlive(false) {}

    void onopen() {
      std::cout << "onopen" << std::endl;
      client::connections.insert(shared_from_this());
    }

    void onclose() {
      std::cout << "onclose" << std::endl;
      client::connections.erase(shared_from_this());

      if(m_isAlive==false) return;
      for(auto& client : client::connections) {
        if(client->isAlive() == false) continue;
        client->logoutNotify(m_status.id);
      }
      m_isAlive = false;
    }

    //C->S
    void login(std::string name, std::string color) {
      m_status.id = id++;
      std::cout << m_status.id << ":[login]";
      m_status.name = name;
      m_status.color = color;
      m_status.point.x = 100;
      m_status.point.y = 100;

      for(auto& client : client::connections) {
        if(client->isAlive() == false) continue;
        client->loginNotify(getStatus());
      }

      //charlistに自分自身を含めるためにここでAlive設定にする
      m_isAlive = true;
      std::vector<wakuserver::Char> charlist;
      for(auto& client : client::connections) {
        if(client->isAlive() == false) continue;
        charlist.push_back(client->getStatus());
      }
      loginReply(m_status.id, charlist);

      std::cout << "name:" << m_status.name << ",id:" << m_status.id << std::endl;
    }

    void chat(std::string msg) {
      if(m_isAlive==false) return;
      std::cout << m_status.id << ":[chat]";
      for(auto& client : client::connections) {
        if(client->isAlive() == false) continue;
        client->chatNotify(m_status.id, msg);
      }
      std::cout << "msg:" << msg << std::endl;
    }

    void move(wakuserver::Point to) {
      if(m_isAlive==false) return;
      std::cout << m_status.id << ":[move]";
      m_status.point = to;
      for(auto& client : client::connections) {
        if(client->isAlive() == false) continue;
        client->moveNotify(m_status.id, to);
      }
      std::cout << std::endl;
    }

    //getter
    bool isAlive() const { return m_isAlive; }
    const wakuserver::Char getStatus() const { return m_status; }

  private:
    bool m_isAlive;
    wakuserver::Char m_status;

  private:
    static int id;
    static std::set<std::shared_ptr<client>> connections;
};
int client::id = 0;
std::set<std::shared_ptr<client>> client::connections;


int main() {
  short port = 9003;

  try {
    server::handler::ptr handler(new wakuserver::server_handler<client>());
    server endpoint(handler);

    endpoint.alog().set_level(websocketpp::log::alevel::CONNECT);
    endpoint.alog().set_level(websocketpp::log::alevel::DISCONNECT);
    endpoint.elog().set_level(websocketpp::log::elevel::RERROR);
    endpoint.elog().set_level(websocketpp::log::elevel::FATAL);

    std::cout << "Starting game server on port " << port << std::endl;

    endpoint.listen(port);
  }
  catch (std::exception& e) {
    std::cerr << "Exception: " << e.what() << std::endl;
  }

  return 0;
}
