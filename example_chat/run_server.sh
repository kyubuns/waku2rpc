set -e

echo "==========generate source code=========="
cd ../
python generator.py example_chat/example_chat.yuu example_chat/src/waku_server.hpp
python generator.py example_chat/example_chat.yuu example_chat/src/WakuClient.hx

cd example_chat
echo "==========build server=========="
g++-4.7.2 src/chat_server.cpp -o bin/chat_server.exe -std=c++11 -Wall -I/usr/local/include -lmsgpack -lwebsocketpp -lboost_system-mt -lboost_date_time-mt -lboost_program_options-mt -lboost_thread-mt -lboost_regex-mt -lpthread
echo "==========build client=========="
haxe -js bin/public_html/chatclient.js -cp src -main ChatClient --dead-code-elimination -lib nodejs -debug

echo "==========run server=========="
./bin/chat_server.exe
