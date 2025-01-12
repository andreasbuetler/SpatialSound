import mqtt.*;
MQTTClient client;

String[] ip;
String personalToken;
float averageDistance;
ArrayList<Satellite> connected;
float x=0;
float y=0;

long frames=0;

//BeatTap
boolean beatFlag = false;
boolean beatFlagDel = false;
int BPM = 120;
long timer = 0;
long timerStart;
int singleBeatLength = 10;
int beatsInLoop = 16;
int totalLoopLength = beatsInLoop*singleBeatLength;
int users = 1;
int allowedBeatsperUser;
int allowedBeatsActiveUser=beatsInLoop;
int activeUser =1; //0 = THIS RECIEVER, 1= SENDER
int currentBeat = 0;
int sensitivity = 10;
int[] timeDistance = new int[beatsInLoop];
int[] sortedRhythm = new int[beatsInLoop];
ArrayList<IntList> BeatList = new ArrayList<IntList>();
boolean beatOn =false;
int inactiveTimer=0;
int inactiveTimeSlot=180;

//Delay
long initDelay=0;
long delayTime;
boolean delayOut= false;

String oldMessage=new String();
float windAverage;



void setup() {
  size (200, 200);
  frameRate (60);
  client  =new MQTTClient(this);
  connected = new ArrayList<Satellite>();
  ip = loadStrings("https://icanhazip.com/");
  personalToken=str(random(0, 32769));
  client.connect("mqtt://e2bcd174:ae5a67d2a2e7d9bc@broker.shiftr.io", ip[0]+ " - " + personalToken +" (Host)");
  client.subscribe("$events");
  //client.subscribe("/delayReturn");
  //client.subscribe("/delayReturn/Delay");
  client.subscribe(personalToken);
}



void draw() {
background(0);

  if (connected.size()>1){
      delaySend();
      getWindAverage();
    loopCalculator();
  calculateUserStates();
  saveRecievedBeats();

  playRhythm();
  sendJSON();
frames++;
//inactiveTimer++;
//println(inactiveTimer);
  }
  beatOn=false;
}

void messageReceived(String topic, byte[] payload) {



  if (topic.equals("$events")) {
    String in_=new String(payload);

    JSONObject in =new JSONObject();
    in=parseJSONObject(in_);
 //   println(in);
    if (in==null) {
      println("NO CONNECTION INPUT ERROR");
    } else {

       //CONNECT & DISCONNECT SATELLITES
      
      if (in.isNull("connection")==false) {    
        connected.add(new Satellite(in));
        println("CURRENT USERS:  "+connected.size());
        delayOut=false;
        averageDistance=calculateAverageDistance();
       // beatsInLoop=connected.size()*8;
      }

      if (in.isNull("disconnection")==false) {
        println(in);
        for (int i=0; i<connected.size(); i++) {
          println(connected.get(i).id);
          if (connected.get(i).id.equals(in.getJSONObject("disconnection").getString("name"))) {
            println("DISCONNECTED");
              if (activeUser==i){
              activeUser=1;
              inactiveTimer=0;
            }
            connected.remove(i);
            delayOut=false;
                    averageDistance=calculateAverageDistance();
            println("CURRENT USERS:  "+connected.size());
          }
        }
      }
      
      //MESSAGES
      
      if (in.isNull("message")==false) {
        String incomingTopic =in.getJSONObject("message").getString("topic");
      //  println("INCOMINGTOPIC:   " +incomingTopic);
       
       
       //BEAT IN
       if (incomingTopic.equals("singleBeat")){
 //        println("BEAT IN " + timer);
 println(in.getJSONObject("message").getString("payload"));
 if(in.getJSONObject("message").getString("payload").equals("MQ==")){
         beatFlag = true;
         inactiveTimer=0;
 }
  if(in.getJSONObject("message").getString("payload").equals("MA==")){
         beatFlagDel = true;
         inactiveTimer=0;
 }
       }
        
        //DELAY IN
        
        
        if (incomingTopic.equals("delayReturn/Delay")) {
          delayTime=millis()-initDelay;
        // println("current Delay time (ms) : "+delayTime);
          delayOut=false;
        }
      }
    }
  
  }
}

void keyPressed() {
  switch(key) {
  case ' ' : 

    return;
  }
}


void saveRecievedBeats(){
  if(beatFlag){    
    timeDistance[currentBeat] = int(timer);
    currentBeat++;
    allowedBeatsActiveUser--;
    client.publish(connected.get(activeUser).token+"/allowedBeats",str(allowedBeatsActiveUser));
 // println("SENDING OUT ALLOWED BEATS (down)"+allowedBeatsActiveUser+" - to:"+connected.get(activeUser).token);
    beatFlag=false;
    //if (currentBeat%allowedBeatsperUser==0){
    if (allowedBeatsActiveUser==0){
      if(activeUser<connected.size()-1){
      activeUser++;
      inactiveTimer=0;
      allowedBeatsActiveUser = allowedBeatsperUser;
      client.publish(connected.get(activeUser).token+"/allowedBeats",str(allowedBeatsActiveUser));
//  println("SENDING OUT ALLOWED BEATS (new)"+allowedBeatsActiveUser+" - to:"+connected.get(activeUser).token);
      }else{
        activeUser=1;
        inactiveTimer=0;
        allowedBeatsActiveUser = allowedBeatsperUser;
           client.publish(connected.get(activeUser).token+"/allowedBeats",str(allowedBeatsActiveUser));
//  println("SENDING OUT ALLOWED BEATS (new)"+allowedBeatsActiveUser+" - to:"+connected.get(activeUser).token);
      }
    }
      if(currentBeat==beatsInLoop){
        currentBeat=0;
      }
   //  calculateUserStates(); 
       processBeats();
  }  
    if(beatFlagDel){    
    timeDistance[currentBeat] = 0;
    currentBeat++;
    allowedBeatsActiveUser--;
    client.publish(connected.get(activeUser).token+"/allowedBeats",str(allowedBeatsActiveUser));
 // println("SENDING OUT ALLOWED BEATS (down)"+allowedBeatsActiveUser+" - to:"+connected.get(activeUser).token);
    beatFlagDel=false;
    //if (currentBeat%allowedBeatsperUser==0){
    if (allowedBeatsActiveUser==0){
      if(activeUser<connected.size()-1){
      activeUser++;
      inactiveTimer=0;
      allowedBeatsActiveUser = allowedBeatsperUser;
      client.publish(connected.get(activeUser).token+"/allowedBeats",str(allowedBeatsActiveUser));
//  println("SENDING OUT ALLOWED BEATS (new)"+allowedBeatsActiveUser+" - to:"+connected.get(activeUser).token);
      }else{
        activeUser=1;
        inactiveTimer=0;
        allowedBeatsActiveUser = allowedBeatsperUser;
           client.publish(connected.get(activeUser).token+"/allowedBeats",str(allowedBeatsActiveUser));
//  println("SENDING OUT ALLOWED BEATS (new)"+allowedBeatsActiveUser+" - to:"+connected.get(activeUser).token);
      }
    }
      if(currentBeat==beatsInLoop){
        currentBeat=0;
      }
   //  calculateUserStates(); 
       processBeats();
  }
//  if(inactiveTimer>=inactiveTimeSlot){
    
//      if(activeUser<connected.size()-1){
//      activeUser++;
//      inactiveTimer=0;
//      allowedBeatsActiveUser = allowedBeatsperUser;
//      client.publish(connected.get(activeUser).token+"/allowedBeats",str(allowedBeatsActiveUser));
////  println("SENDING OUT ALLOWED BEATS (new)"+allowedBeatsActiveUser+" - to:"+connected.get(activeUser).token);
//      }else{
//        activeUser=1;
//        inactiveTimer=0;
//        allowedBeatsActiveUser = allowedBeatsperUser;
//           client.publish(connected.get(activeUser).token+"/allowedBeats",str(allowedBeatsActiveUser));
////  println("SENDING OUT ALLOWED BEATS (new)"+allowedBeatsActiveUser+" - to:"+connected.get(activeUser).token);
//      }
    
//  }

}

void calculateUserStates(){
  int oldAllowance =allowedBeatsperUser;
  users = (connected.size()-1);
  
  if(beatsInLoop/users>1){
  if(beatsInLoop%users==0){
    
     allowedBeatsperUser = beatsInLoop/users;
  }
  else{
  allowedBeatsperUser= (beatsInLoop-(beatsInLoop%users))/users;
  }
 
}
 else{allowedBeatsperUser=2;}
 if(oldAllowance!=allowedBeatsperUser){
  // println("ALlowed Beats per User: " +allowedBeatsperUser);
  String activeUserID = connected.get(activeUser).token;
  client.publish(activeUserID+"/allowedBeats",str(allowedBeatsActiveUser));
 // println("SENDING OUT ALLOWED BEATS "+allowedBeatsActiveUser+" - to:"+activeUserID);
  for(int k=0;k<(users+1);k++){
    if(k!=activeUser){
      client.publish(connected.get(k).token+"/allowedBeats",str(0));
  //    println("SENDING OUT ALLOWED BEATS : 0, not active - to:"+connected.get(k).token);
    }
  }
 }
}

void loopCalculator(){
  timer = frames-timerStart;  
  
  if (timer>=totalLoopLength){
    timerStart =frames;
 //         println("loop");
        //  println(timer);
  }
}
void processBeats(){
  sortedRhythm = timeDistance;
  sortedRhythm = sort(sortedRhythm);
//  printArray(sortedRhythm);
}
void playRhythm(){
  for(int k=0; k<beatsInLoop-1 ;k++){
   
    if(sortedRhythm[k]==timer){

      background(255,0,0);
      beatOn=true;
      //println("BEAT" + beatOn);
    }
  }
}

void delaySend() {
  if (delayOut==false) {
    String sendList=new String();
    for (int i =1; i<connected.size(); i++) {
      sendList=sendList+connected.get(i).token+",";
    }
    sendList=sendList+"/delayReturn";
  //   println(sendList + " - sent");
    initDelay=millis();
    client.publish(connected.get(1).token+"/Delay", sendList) ;
    delayOut=true;
  }
}

void getWindAverage(){
  float sum=0;
for (int i=0;i<connected.size();i++){
sum+=connected.get(i).windSpeed;
}
windAverage=sum/connected.size();

}

void sendJSON(){
 JSONArray coordinates= new JSONArray();
  for (int i=0;i<connected.size();i++){
//coordinates[i]=str(connected.get(i).latitude)+","+str(connected.get(i).longitude);
JSONObject location=new JSONObject();
location.setInt("id", i);
location.setFloat ("x",connected.get(i).longitude);
location.setFloat ("y",connected.get(i).latitude);
coordinates.setJSONObject(i,location);
  }
String message;
JSONObject sending =new JSONObject();
sending.setInt("NODES", connected.size());
sending.setFloat("windAverage",windAverage);
sending.setFloat("delay", delayTime);
sending.setBoolean("beat", beatOn);
sending.setJSONArray("coordinates", coordinates);
sending.setFloat("averageDistance",averageDistance);
message=(sending.toString());

if (message.equals(oldMessage)==false){
client.publish("/output", message);
//println("OUT: " +millis()+"   BEAT:   "+sending.getBoolean("beat"));
oldMessage=message;
}
}
float calculateAverageDistance(){
  float d=0;
float[] distance =new float[connected.size()];
  float sum_x=0;;
  float average_x=0;
    float sum_y=0;;
  float average_y=0;
float[] x= new float[connected.size()];
float[] y= new float[connected.size()];
float[] x_= new float[connected.size()];
float[] y_= new float[connected.size()];
float min_x=connected.get(0).longitude;
float max_x=connected.get(0).longitude;
float min_y=connected.get(0).latitude;
float max_y=connected.get(0).latitude;

for (int i=0;i<connected.size();i++){
x[i]=connected.get(i).longitude;
y[i]=connected.get(i).latitude;
if(x[i]<min_x){min_x=x[i];}
if(x[i]>max_x){max_x=x[i];}
if(y[i]<min_y){min_y=y[i];}
if(y[i]>max_y){max_y=y[i];}
}

for (int i=0;i<connected.size();i++){
x_[i]=map(x[i],min_x-0.00001,max_x+0.00001,0,1);
y_[i]=map(y[i],min_y-0.00001,max_y+0.00001,0,1);
sum_x+=x_[i];
sum_y+=y_[i];
}
average_x=sum_x/connected.size();
average_y=sum_y/connected.size();
for (int i=0;i<connected.size();i++){
distance[i]=dist(average_x,average_y,x_[i],y_[i]);
d+=distance[i];
}
d=d/connected.size();
return d;

}
