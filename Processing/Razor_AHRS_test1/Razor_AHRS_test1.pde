/******************************************************************************************
* Test Sketch for Razor AHRS v1.4.2
* 9 Degree of Measurement Attitude and Heading Reference System
* for Sparkfun "9DOF Razor IMU" and "9DOF Sensor Stick"
*
* Released under GNU GPL (General Public License) v3.0
* Copyright (C) 2013 Peter Bartz [http://ptrbrtz.net]
* Copyright (C) 2011-2012 Quality & Usability Lab, Deutsche Telekom Laboratories, TU Berlin
* Written by Peter Bartz (peter-bartz@gmx.de)
*
* Infos, updates, bug reports, contributions and feedback:
*     https://github.com/ptrbrtz/razor-9dof-ahrs
******************************************************************************************/

/*
  NOTE: There seems to be a bug with the serial library in Processing versions 1.5
  and 1.5.1: "WARNING: RXTX Version mismatch ...".
  Processing 2.0.x seems to work just fine. Later versions may too.
  Alternatively, the older version 1.2.1 also works and is still available on the web.
*/

import processing.opengl.*;
import processing.serial.*;
import java.io.InputStreamReader;
import java.io.IOException;

// IF THE SKETCH CRASHES OR HANGS ON STARTUP, MAKE SURE YOU ARE USING THE RIGHT SERIAL PORT:
// 1. Have a look at the Processing console output of this sketch.
// 2. Look for the serial port list and find the port you need (it's the same as in Arduino).
// 3. Set your port number here:
final static int SERIAL_PORT_NUM = 5;
// 4. Try again.


final static int SERIAL_PORT_BAUD_RATE = 57600;

float yaw = 0.0f;
float pitch = 0.0f;
float roll = 0.0f;
float yawOffset = 0.0f;

int Sensitivity = 10;  //increaseing will inc the sensitivity 

Runtime r;
boolean continuous = false;  //continous sending of keystokes or not?

static final int WAVE_STYLE = 0;
static final int TILT_STYLE = 1;
int STYLE = TILT_STYLE;

static final int RIGHT_HANDED = 0;
static final int LEFT_HANDED = 1;
int HAND_PREF = RIGHT_HANDED;

String lastKeyCode = "";

boolean waveValueXStateR = true;
boolean waveValueXStateL = true;

int waveValueX;
int waveValueY;
int preWaveValueY = 0;
int preWaveValueX = 0;

PFont font;
Serial serial;

boolean synched = false;

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

  rotateY(-radians(yaw - yawOffset));
  rotateX(-radians(pitch));
  rotateZ(radians(roll)); 

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
  frameRate(20);    /**    FRAME RATE LOW  */
  r = Runtime.getRuntime(); // for system calls
  // Load font
  font = loadFont("Univers-66.vlw");
  textFont(font);
  
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
}

void setupRazor() {
  println("Trying to setup and synch Razor...");
  
  // On Mac OSX and Linux (Windows too?) the board will do a reset when we connect, which is really bad.
  // See "Automatic (Software) Reset" on http://www.arduino.cc/en/Main/ArduinoBoardProMini
  // So we have to wait until the bootloader is finished and the Razor firmware can receive commands.
  // To prevent this, disconnect/cut/unplug the DTR line going to the board. This also has the advantage,
  // that the angles you receive are stable right from the beginning. 
  delay(3000);  // 3 seconds should be enough
  
  // Set Razor output parameters
  //serial.write("#ob");  // Turn on binary output
  //serial.write("#o1");  // Turn on continuous streaming output
  //serial.write("#oe0"); // Disable error message output
  
  // Synch with Razor
  serial.clear();  // Clear input buffer up to here
  //serial.write("#s00");  // Request synch token
}

float readFloat(Serial s) {
  // Convert from little endian (Razor) to big endian (Java) and interpret as float
  return Float.intBitsToFloat(s.read() + (s.read() << 8) + (s.read() << 16) + (s.read() << 24));
}


void draw() {
   // Reset scene
  background(0);
  lights();
  /*
  // Sync with Razor 
  if (!synched) {
    textAlign(CENTER);
    fill(255);
    text("Connecting to Razor...", width/2, height/2, -200);
    
    if (frameCount == 2)
      setupRazor();  // Set ouput params and request synch token
    else if (frameCount > 2)
      synched = readToken(serial, "#SYNCH00\r\n");  // Look for synch token
    return;
  }
  // Read angles from serial port
  if(serial.available() >= 13){
    if(serial.read() == '#'){
      yaw = readFloat(serial);
      pitch = readFloat(serial);
      roll = readFloat(serial);
    }
  }
  */
  
  while (serial.available() >= 13) {
    char ch = char(serial.read());
    //println(ch);
    if(ch == '#'){
      yaw = readFloat(serial);
      pitch = readFloat(serial);
      roll = readFloat(serial);
      //println(yaw + ", " + pitch);
     
      switch(HAND_PREF){
        
        case LEFT_HANDED:
        {
          switch(STYLE){
            case TILT_STYLE:
              if(pitch < -110 + Sensitivity){
                println("Left");
                sendKeyCode("123");
              }else if(pitch > 110 - Sensitivity){
                println("Right");
                sendKeyCode("124");
              }                                //taking all individually 
              else if(yaw < -50 + Sensitivity){
                println("Down");
                sendKeyCode("125");
              }else if(yaw > 60 - Sensitivity){
                println("Up");
                sendKeyCode("126");
              }
              else{
                lastKeyCode = "";
              }
              break;
            case WAVE_STYLE:
               waveValueX = (int)map(pitch, -255, 255, -10, 10);
               waveValueY = (int)map(yaw, -255, 255, -10, 10);
               println(waveValueX);
               if(waveValueX <= preWaveValueX && waveValueX > 2 && waveValueXStateL == true){
                 println("Right"); 
                 
                 waveValueXStateL = false;
                 waveValueXStateR = true;
                 
               }else if(waveValueX >= preWaveValueX && waveValueX < -2 && waveValueXStateR == true){
                 println("Left");
                 waveValueXStateR = false; 
                 waveValueXStateL = true; 
               }
               preWaveValueX = waveValueX;
               
          }
        }
        case RIGHT_HANDED:
        {
        switch(STYLE){
            case TILT_STYLE:
              if(pitch < -110 + Sensitivity){
                println("Right");
                sendKeyCode("124");
              }else if(pitch > 110 - Sensitivity){
                println("Left");
                sendKeyCode("123");
              }                                //taking all individually 
              else if(yaw < -50 + Sensitivity){
                println("Top");
                sendKeyCode("126");
              }else if(yaw > 60 - Sensitivity){
                println("Down");
                sendKeyCode("125");
              }
              else{
                lastKeyCode = "";
              }
              break;
            case WAVE_STYLE:
               waveValueX = (int)map(pitch, -255, 255, -10, 10);
               waveValueY = (int)map(yaw, -255, 255, -10, 10);
               println(waveValueX);
               if(waveValueX <= preWaveValueX && waveValueX > 2 && waveValueXStateL == true){
                 println("Right"); 
                 
                 waveValueXStateL = false;
                 waveValueXStateR = true;
                 
               }else if(waveValueX >= preWaveValueX && waveValueX < -2 && waveValueXStateR == true){
                 println("Left");
                 waveValueXStateR = false; 
                 waveValueXStateL = true; 
               }
               preWaveValueX = waveValueX;
               
          }
        }
      }
      
    }
    
  }
  
  /*
  if(serial.available() > 0){
    if(serial.readChar() == '#'){
    String line[] = splitTokens(serial.readString(), ",");
    print(line);
    if(line.length == 4){
      yaw = float(line[1]);
      pitch = float(line[2]);
      roll = float(line[3]);
      }
      else if(line.length == 3){
      yaw = float(line[0]);
      pitch = float(line[1]);
      roll = float(line[2]);
      }
    }
    
  }
 */
  
    
  // Draw board
  pushMatrix();
  translate(width/2, height/2, -350);
  drawBoard();
  popMatrix();
  
  textFont(font, 20);
  fill(255);
  textAlign(LEFT);

  // Output info text
  text("Point FTDI connector towards screen and press 'a' to align", 10, 25);

  // Output angles
  pushMatrix();
  translate(10, height - 10);
  textAlign(LEFT);
  text("Yaw: " + ((int) yaw), 0, 0);
  text("Pitch: " + ((int) pitch), 150, 0);
  text("Roll: " + ((int) roll), 300, 0);
  popMatrix();
}

void keyPressed() {
  switch (key) {
    case '0':  // Turn Razor's continuous output stream off
      serial.write("#o0");
      break;
    case '1':  // Turn Razor's continuous output stream on
      serial.write("#o1");
      break;
    case 'f':  // Request one single yaw/pitch/roll frame from Razor (use when continuous streaming is off)
      serial.write("#f");
      break;
    case 'a':  // Align screen with Razor
      yawOffset = yaw;
  }
}

void sendKeyCode(String code){
  String event = "tell application \"System Events\" to key code " + code;
  String[] keyPress = { "osascript", "-e", event};
  if(lastKeyCode.equals(code) == false){
    try{
      Process p = r.exec(keyPress);
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



