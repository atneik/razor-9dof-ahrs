import processing.opengl.*;
import processing.serial.*;
import java.io.InputStreamReader;
import java.io.IOException;
import controlP5.*;
import ddf.minim.*;
import ddf.minim.effects.*;

// IF THE SKETCH CRASHES OR HANGS ON STARTUP, MAKE SURE YOU ARE USING THE RIGHT SERIAL PORT:
// 1. Have a look at the Processing console output of this sketch.
// 2. Look for the serial port list and find the port you need (it's the same as in Arduino).
// 3. Set your port number here:
final static int SERIAL_PORT_NUM = 6;
// 4. Try again.


final static int SERIAL_PORT_BAUD_RATE = 57600;
float timeInterval = 800;
int Sensitivity = 10;  //increaseing will inc the sensitivity
boolean continuous = false;  //continous sending of keystokes or not?

//current Accels
float accelX = 0.0f;
float accelY = 0.0f;
float accelZ = 0.0f;

//Cali values AccelX/Y / break points
float caliXMin = -168;
float caliXMax = 148;
float caliYMin = -144;
float caliYMax = 134;

//Normal AccelX/Y
float NXMin = 0;
float NXMax = 0;
float NYMin = 0;
float NYMax = 0;

//float yawOffset = 0.0f;

String lastKeyCode = "";

long prevTime;
long currentTime;

boolean caliFlag = false;

PFont font;
Serial serial;
Runtime r;
ControlP5 cp5;
Minim minim;
AudioPlayer mario;

void drawArrow(float headWidthFactor, float headLengthFactor) {
  float headWidth = headWidthFactor * 200.0f;
  float headLength = headLengthFactor * 200.0f;
  
  pushMatrix();
  
  // Draw base
  translate(0, 0, -100);
  box(100, 100, 200);
  
  // Draw pointer
  translate(-headWidth/2, -50, -100);
  beginShape(QUAD_STRIP);
    vertex(0, 0 ,0);
    vertex(0, 100, 0);
    vertex(headWidth, 0 ,0);
    vertex(headWidth, 100, 0);
    vertex(headWidth/2, 0, -headLength);
    vertex(headWidth/2, 100, -headLength);
    vertex(0, 0 ,0);
    vertex(0, 100, 0);
  endShape();
  beginShape(TRIANGLES);
    vertex(0, 0, 0);
    vertex(headWidth, 0, 0);
    vertex(headWidth/2, 0, -headLength);
    vertex(0, 100, 0);
    vertex(headWidth, 100, 0);
    vertex(headWidth/2, 100, -headLength);
  endShape();
  
  popMatrix();
}

void drawBoard() {
  pushMatrix();

  rotateY(-radians(accelX));
  rotateX(-radians(accelY));
  rotateZ(radians(accelZ)); 

  // Board body
  fill(255, 0, 0);
  box(250, 20, 400);
  
  // Forward-arrow
  pushMatrix();
  translate(0, 0, -200);
  scale(0.5f, 0.2f, 0.25f);
  fill(0, 255, 0);
  drawArrow(1.0f, 2.0f);
  popMatrix();
    
  popMatrix();
}

// Skip incoming serial stream data until token is found
boolean readToken(Serial serial, String token) {
  // Wait until enough bytes are available
  if (serial.available() < token.length())
    return false;
  
  // Check if incoming bytes match token
  for (int i = 0; i < token.length(); i++) {
    if (serial.read() != token.charAt(i))
      return false;
  }
  return true;
}

// Global setup
void setup() {
  // Setup graphics
  size(640, 480, OPENGL);
  smooth();
  noStroke();
  frameRate(50);      /**    FRAME RATE LOW  */
  
  r = Runtime.getRuntime(); // for system calls
  
  // Load font
  font = loadFont("Univers-66.vlw");
  textFont(font);
  
  prevTime = System.currentTimeMillis();
  
  // Setup serial port I/O
  println("AVAILABLE SERIAL PORTS:");
  println(Serial.list());
  try{
    String portName = Serial.list()[SERIAL_PORT_NUM];
    println();
    println("HAVE A LOOK AT THE LIST ABOVE AND SET THE RIGHT SERIAL PORT NUMBER IN THE CODE!");
    println("  -> Using port " + SERIAL_PORT_NUM + ": " + portName);
    serial = new Serial(this, portName, SERIAL_PORT_BAUD_RATE);
  }catch(Exception e){
    println("Check if the port number is right, or Xbee is connected correctly.");
  }
  
  minim = new Minim(this);
  mario = minim.loadFile("mario.wav");
  
}

void setupRazor() {
  println("Trying to setup and synch Razor...");
  delay(3000);  // 3 seconds should be enough
  serial.clear();
}

float readFloat(Serial s) {
  // Convert from little endian (Razor) to big endian (Java) and interpret as float
  return Float.intBitsToFloat(s.read() + (s.read() << 8) + (s.read() << 16) + (s.read() << 24));
}


void draw() {
   // Reset scene
  background(0);
  lights();
  
  while (serial.available() >= 13) {
    char ch = char(serial.read());
    //println(ch);
    if(ch == '#'){
      accelX = readFloat(serial);
      accelY = readFloat(serial);
      accelZ = readFloat(serial);
      //println(accelX + ", " + accelY);
      if(accelY < caliYMin + Sensitivity){
        //println("Left");
        sendKeyCode("123");
      }else if(accelY > caliYMax - Sensitivity){
        //println("Right");
        sendKeyCode("124");
      }                                //taking all individually 
      else if(accelX < caliXMin + Sensitivity){
        //println("Down");
        sendKeyCode("125");
      }else if(accelX > caliXMax - Sensitivity){
        //println("Up");
        sendKeyCode("126");
      }
      else{
        lastKeyCode = "";
      }
    }
  } 
  // Draw board
  pushMatrix();
  translate(width/2, height/2, -350);
  drawBoard();
  popMatrix();
  
  textFont(font, 20);
  fill(255);
  textAlign(LEFT);

  // Output info text
  text("The Headgear is working. Start Playing!", 10, 25);
  if(caliFlag){
    text("Caliberating... ", 10, 45);
  }
  
  // Output angles
  pushMatrix();
  translate(10, height - 10);
  textAlign(LEFT);
  text("AccelX: " + ((int) accelX), 0, 0);
  text("AccelY: " + ((int) accelY), 150, 0);
  text("AccelZ: " + ((int) accelZ), 300, 0);
  popMatrix();
  
}


void keyPressed() {
    if (key == 'w') {
      println("up-" + accelX);
      caliXMax = accelX;
    } else if (key == 's') {
      println("down-" + accelX);
      caliXMin = accelX;
    } else if (key == 'a') {
      println("left-"  + accelY);
      caliYMin = accelY;
    } else if (key == 'd') {
      println("right-" + accelY);
      caliYMax = accelY;
    }
}

float getCaliValue(char axis) {
  if(axis == 'X') {
    for(int i = 5; i > 0; i--){
      text(i + "secs", 10, 50 + i*10);
      delay(1000);
    }
    return accelX;
  } else if(axis == 'Y') {
  for(int i = 5; i > 0; i--){
      text(i + "secs", 60, 10);
      delay(1000);
    }
    return accelY;
  }
  
  return 0;
}

float getMinCaliValue(char axis) {
  caliFlag = true;
  float value = 512;
  if(axis == 'X') {
    while(caliFlag) {
      if( accelX > value && value < NXMin){
        caliFlag = false;
      }
      if( value > accelX ){
        value = accelX;
        println(value);
      }
    } 
  } else {
    while(caliFlag) {
      if( value > accelY){
        value = accelY;
        println(value);
      }
    } 
  }
  return value;
}

float getMaxCaliValue(char axis) {
  caliFlag = true;
  float value = -512;
  if(axis == 'X') {
    while(caliFlag) {
      if( value < accelX ){
        value = accelX;
        println(value);
      }
    } 
  } else {
    while(caliFlag) {
      if( value < accelY){
        value = accelY;
        println(value);
      }
    } 
  }
  return value;
}

void sendKeyCode(String code) {
  String event = "tell application \"System Events\" to key code " + code;
  String[] keyPress = { "osascript", "-e", event};
  currentTime = System.currentTimeMillis();
  if(lastKeyCode.equals(code) == false && (currentTime - prevTime) > timeInterval ){
    prevTime = currentTime;
    try{
      thread("playMario");
      Process p = r.exec(keyPress);
      println(code);
      if(continuous == false)
        lastKeyCode = code;
      try{
          p.waitFor();
          /*
          BufferedReader b = new BufferedReader(new InputStreamReader(p.getInputStream()));
          String line = "";
          while ((line = b.readLine()) != null) {
          println(line);
          } 
          */  
          p.destroy();       
      }catch (InterruptedException e) {
        throw new RuntimeException(e);
      }
    }catch (IOException e) {
      e.printStackTrace();
    }
  }
}

void playMario(){
  mario.play();
  mario = minim.loadFile("mario.wav");
}



