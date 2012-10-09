set -e

echo "==========generate source code=========="
cd ../
python generator.py revolution/revolution.yuu templates/wakuserver.hpp revolution/src/waku_server.hpp
python generator.py revolution/revolution.yuu templates/wakuclient.hx revolution/src/WakuClient.hx

cd revolution
echo "==========build server=========="
g++ src/revolution.cpp -o bin/gmsv.exe -std=c++0x -Wall -I/usr/local/include -lmsgpack -lwebsocketpp -lboost_system-mt -lboost_date_time-mt -lboost_program_options-mt -lboost_thread-mt -lboost_regex-mt -lpthread
echo "==========build client=========="
haxe -js public_html/client.js -cp src -main RClient --dead-code-elimination -lib createjs -debug

echo "==========run server=========="
./bin/gmsv.exe
