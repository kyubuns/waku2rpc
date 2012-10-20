set -e

echo "==========generate source code=========="
cd ../
python generator.py revolution/revolution.yuu revolution/src/WakuClient.hx

cd revolution
echo "==========build client=========="
haxe -js public_html/client.js -cp src -main RClient --dead-code-elimination -lib createjs -debug

echo "==========run server=========="
./bin/gmsv.exe
