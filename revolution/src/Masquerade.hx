package;

import createjs.easeljs.Stage;
import createjs.easeljs.DisplayObject;

//ライブラリの中に入れたくなかったけどどうしようもなかった
enum EventType {
  Move;
}

//===========================================================================

typedef GameTime = Float;

interface Event {
  var type(default, null) : EventType;
}

class Process {
  public function new(stage_:Stage, processList:ProcessList) : Void {
    receiveEventType = [];
    isAlive = true;
    child = new List<DisplayObject>();
    stage = stage_;
  }

  public function addChild(c:DisplayObject) : Void {
    stage.addChild(c);
    child.add(c);
  }

  public function destructor() : Void {
    for(c in child) {
      stage.removeChild(c);
      c = null;
    }
    child = null;
    isAlive = false;
  }
  public function update(gameTime:GameTime, eventSender:EventSender) : Void {}
  public function receiveEvent(e:Event) : Void {}
  public var receiveEventType(default, null) : Array<EventType>;
  public var isAlive(default, null) : Bool;

  private var child:List<DisplayObject>;
  private var stage:Stage;
}



//EventSender
class EventSender {
  public function new():Void {
    listenerList = new IntHash<List<Process>>();
    eventQueue = new List<Event>();
  }

  public function addListener(process:Process) {
    for(type in process.receiveEventType) {
      var index = Type.enumIndex(type);
      if(listenerList.exists(index) == false) listenerList.set(index, new List<Process>());
      listenerList.get(index).add(process);
    }
  }

  public function deleteListener(process:Process) {
    for(type in process.receiveEventType) {
      var index = Type.enumIndex(type);
      if(listenerList.exists(index) == false) listenerList.set(index, new List<Process>());
      listenerList.get(index).remove(process);
    }
  }

  public function addEvent(event:Event):Void {
    eventQueue.add(event);
  }

  public function tick():Void {
    while(!eventQueue.isEmpty()) {
      var e:Event = eventQueue.pop();
      var index:Int = Type.enumIndex(e.type);
      for(listener in listenerList.get(index)) listener.receiveEvent(e);
    }
  }

  private var listenerList:IntHash<List<Process>>;
  private var eventQueue:List<Event>;
}



//ProcessList
class ProcessList {
  public function new():Void {
    eventSender = new EventSender();
    processList = new List<Process>();
    beforeTime = Date.now().getTime();
  }

  public function addProcess(process:Process) : Void {
    processList.add(process);
    eventSender.addListener(process);
  }

  public function deleteProcess(process:Process) : Void {
    processList.remove(process);
    eventSender.deleteListener(process);
    process = null;
  }

  public function tick() : Void {
    var time:Float = Date.now().getTime() - beforeTime;
    for(process in processList) {
      if(process.isAlive == false) {
        deleteProcess(process);
        continue;
      }
      process.update(time, eventSender);
    }
    eventSender.tick();

    beforeTime += time;
  }

  public function addEvent(e:Event) : Void { eventSender.addEvent(e); }

  private var eventSender:EventSender;
  private var processList:List<Process>;
  private var beforeTime:Float;
}
