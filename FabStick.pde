import oscP5.*;
import netP5.*;
import controlP5.*;

OscP5 oscP5;
NetAddress superCollider;
float x, y;
ArrayList<PVector> trail;
int trailSize = 100;

ControlP5 cp5;

void setup() {
  size(800, 600);
  oscP5 = new OscP5(this, 45777);
  superCollider = new NetAddress("localhost", 57120); // Address of SuperCollider
  background(0);
  noStroke();
  trail = new ArrayList<PVector>();
  cp5 = new ControlP5(this);
  cp5.addSlider("roomsize")
     .setPosition(50,50)
     .setRange(0.01,25)
     .setValue(12.5);
  
  cp5.addSlider("revtime")
     .setPosition(50,100)
     .setRange(0.01,7)
     .setValue(3.5);
  
  cp5.addSlider("maxdelaytime")
     .setPosition(50,150)
     .setRange(0.01,10)
     .setValue(5);
  
  cp5.addSlider("delaytime")
     .setPosition(50,200)
     .setRange(0.01,1)
     .setValue(0.5);
     
   cp5.addSlider("decaytime")
     .setPosition(50,250)
     .setRange(0.01,20)
     .setValue(10);
     
   cp5.addSlider("rwet")
     .setPosition(50, 300)
     .setRange(0, 1)
     .setValue(0.1)
     .setLabel("Reverb Dry/Wet");
  
  cp5.addSlider("dwet")
     .setPosition(50, 350)
     .setRange(0, 1)
     .setValue(0.1)
     .setLabel("Delay Dry/Wet");
     
}

void draw() {
  background(0);

  // Draw all positions in the trail as colored circles
  for (int i = 0; i < trail.size(); i++) {
    PVector pos = trail.get(i);
    float normI = (float)i / trail.size(); // normalize index to range 0-1

    // Scale size between 0-150, add some randomness and make it larger as it approaches 1
    float size = (normI + (pos.x + pos.y) / 2 + random(0.1f)) * 100;

    // Decrease the alpha (z) value for fading effect
    pos.z -= 10;
    if (pos.z < 0) {
      trail.remove(i);
      i--; // Correct the index after removal
      continue;
    }

    // Use HSB color mode for more color variation
    colorMode(HSB, 255); 

    // Change fill color based on position in trail, y value, and z value
    fill(pos.x * 255, pos.y * 255, 255 - normI * 255, pos.z); 
    
    // Draw circle with no stroke for a softer look
    noStroke();
    ellipse(pos.x * width, pos.y * height, size, size); 

    // Reset color mode
    colorMode(RGB, 255);
  }

  // Add a subtle gradient to the background for a softer look
  setGradient(0, 0, width, height, color(0, 0, 0, 0), color(0, 0, 0, 100));
}

void setGradient(int x, int y, float w, float h, color c1, color c2) {
  for (int i = y; i <= y+h; i++) {
    float inter = map(i, y, y+h, 0, 1);
    color c = lerpColor(c1, c2, inter);
    stroke(c);
    line(x, i, x+w, i);
  }
}




void oscEvent(OscMessage msg) {
  if (msg.checkAddrPattern("/XY")) {
    if (msg.checkTypetag("ff")) {
      x = msg.get(0).floatValue();
      y = 1 - msg.get(1).floatValue(); // Invert the y axis
      trail.add(0, new PVector(x, y, 255)); // Add new position at the beginning of the trail with full alpha

      // Remove oldest position if the trail is too long
      if (trail.size() > trailSize) {
        trail.remove(trail.size() - 1);
      }

      println("X: " + x + ", Y: " + y);
    } else {
      println("Unexpected typetag in OSC message: " + msg.typetag());
    }
  }
  if (msg.addrPattern().equals("/roomsize")) {
    cp5.getController("roomsize").setValue(msg.get(0).floatValue());
  } 
  if (msg.addrPattern().equals("/revtime")) {
    cp5.getController("revtime").setValue(msg.get(0).floatValue());
  } 
  if (msg.addrPattern().equals("/rwet")) {
    cp5.getController("rwet").setValue(msg.get(0).floatValue());
  } 
  if (msg.addrPattern().equals("/maxdelaytime")) {
    cp5.getController("maxdelaytime").setValue(msg.get(0).floatValue());
  } 
  if (msg.addrPattern().equals("/delaytime")) {
    cp5.getController("delaytime").setValue(msg.get(0).floatValue());
  } 
  if (msg.addrPattern().equals("/decaytime")) {
    cp5.getController("decaytime").setValue(msg.get(0).floatValue());
  } 
  if (msg.addrPattern().equals("/dwet")) {
    cp5.getController("dwet").setValue(msg.get(0).floatValue());
  } 
   
}
