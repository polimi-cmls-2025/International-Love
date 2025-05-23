import oscP5.*;
import netP5.*;

OscP5 oscP5;
NetAddress myRemoteLocation;

// Configuration
float[] waveform = new float[256];         // Circular Buffer
float[] waveformHistory = new float[2048]; // Circular Buffer for the waveform mode
int waveformHistoryIndex = 0;              // Circular Buffer current position
float[] capturedWave = new float[256];     // Buffer for the oscilloscope mode
boolean hasSignal = false;
boolean newWaveReceived = false;  
int displayMode = 0; // 0=waveform, 1=oscilloscope
PFont font, smallFont;
color bgColor = color(255);  
color gridColor = color(200); 
int lastReset = 0;
boolean waitingForTrigger = false;
int triggerPosition = -1;
float triggerThreshold = 0.1f;  // Adjust as needed
float lastTriggerTime = 0;
int triggerTimeout = 100;       // Milliseconds to wait before forcing an update
boolean triggerFound = false;

void setup() {
  size(1000, 600);
  smooth(4);
  
  // OSC configuration
  try {
    oscP5 = new OscP5(this, 9001);
    myRemoteLocation = new NetAddress("127.0.0.1", 9001);
  } catch (Exception e) {
    println("OSC init error: " + e);
  }
  
  resetWaveforms();
  
  font = createFont("Arial Bold", 40, true);
  smallFont = createFont("Arial", 24, true);
}

void draw() {
  //background(bgColor);
  PImage background_img;
  background_img = loadImage("background.png");
  background_img.resize(width, height);
  background(background_img);

  fill(0, 0, 0, 200);
  rect(20, 80, 960, 510);
  drawUI();
  
  if (newWaveReceived) {
    addToWaveformHistory();
    newWaveReceived = false;
  }
  
  if (hasSignal) {
    if (displayMode == 0) {
      drawWaveform();
    } else {
      drawOscilloscope();
    }
    
    // Reset signal status after 3 seconds of no data
    if (millis() - lastReset > 3000) {
      hasSignal = false;
    }
  } else {
    drawNoSignal();
  }
}

void addToWaveformHistory() {
  for (int i = 0; i < waveform.length; i++) {
    waveformHistory[waveformHistoryIndex] = waveform[i];
    waveformHistoryIndex = (waveformHistoryIndex + 1) % waveformHistory.length;
  }
}

void oscEvent(OscMessage msg) {
  try {
    lastReset = millis();
    
    if (msg.checkAddrPattern("/waveform")) {
      hasSignal = true;
      int safeLength = min(waveform.length, msg.arguments().length);
      
      // Clean buffer
      for (int i = 0; i < waveform.length; i++) {
        waveform[i] = 0;
      }
      
      // Put new data in
      for (int i = 0; i < safeLength; i++) {
        waveform[i] = msg.get(i).floatValue();
      }
      
      newWaveReceived = true;
      
      // Handle oscilloscope mode - continuously update with trigger alignment
      if (displayMode == 1) {
        // Look for a trigger point (rising edge crossing threshold)
        triggerFound = false;
        for (int i = 1; i < waveform.length - 1; i++) {
          if (waveform[i-1] < triggerThreshold && waveform[i] >= triggerThreshold) {
            // Found a trigger point
            
            // Only update if we have enough samples after the trigger point
            if (i + 200 < waveform.length) {  // Make sure we have at least 200 samples after trigger
              triggerFound = true;
              
              // Copy the wave starting from the trigger point
              for (int j = 0; j < capturedWave.length; j++) {
                int idx = i + j;
                if (idx < waveform.length) {
                  capturedWave[j] = waveform[idx];
                } else {
                  capturedWave[j] = 0;  // Pad with zeros if we run out of samples
                }
              }
              
              lastTriggerTime = millis();
              break;
            }
          }
        }
        
        // If no trigger found, but it's been too long since the last update,
        // force an update to show changes in the signal
        if (!triggerFound && millis() - lastTriggerTime > triggerTimeout) {
          // Just capture the current waveform without trigger alignment
          arrayCopy(waveform, capturedWave);
          lastTriggerTime = millis();
        }
      }
    }
  } catch (Exception e) {
    println("OSC processing error: " + e);
  }
}

void drawUI() {
  // Header
    fill(0, 0, 0, 100);
    noStroke(); 
    rect(width/2 - 250, 10, 500, 60, 10);
  
    fill(230, 40, 40);
    textFont(font);
    textAlign(CENTER, TOP);
    textSize(42); 
    text("T.I.L.E.S Wave visualizer", width/2, 20);

  // Mode information
    textFont(smallFont);
    textSize(20); 
    fill(hasSignal ? color(0, 150, 0) : color(200, 0, 0));
    String modeText = displayMode == 0 ? "WAVEFORM" : "OSCILLOSCOPE";
    text("MODE: " + modeText, width/2, 100);

  // Instructions
    fill(230, 40, 40);
    textSize(18); 
    String instructions = "1: Waveform | 2: Oscilloscope | SPACE: Capture now | R: Reset";
    if (displayMode == 1) {
      instructions += " | U/D: Adjust trigger (" + nf(triggerThreshold, 1, 2) + ")";
    }
    text(instructions, width/2, height - 30);
      
  // Show trigger level if in oscilloscope mode
  if (displayMode == 1) {
    fill(255, 0, 0);
    text("Trigger: " + nf(triggerThreshold, 1, 2), 120, 100);
  }
}

void drawWaveform() {
  float x = 70, y = 150, w = width-140, h = 350;
  
  // Draw grid before the waveform
  drawSimpleGrid(x, y, w, h);

  // Draw historical waveform (real-time streaming)
  stroke(255, 51, 0);
  strokeWeight(2);
  noFill();
  
  // Calculate how many points to display (entire visible buffer)
  int numPoints = waveformHistory.length;
  float pointSpacing = w / numPoints;
  
  beginShape();
  for (int i = 0; i < numPoints; i++) {
    // Order samples so that the most recent are on the right
    int idx = (waveformHistoryIndex - numPoints + i + waveformHistory.length) % waveformHistory.length;
    float value = waveformHistory[idx];
    
    float xPos = x + i * pointSpacing;
    float yPos = y + h/2 - value * h/2 * 0.8; // Invert direction
    
    // Check that points are in valid range
    if (xPos >= x && xPos <= x + w) {
      vertex(xPos, yPos);
    }
  }
  endShape();
  
  // Vertical line indicating current position
  stroke(0, 255, 0, 100);
  strokeWeight(1);
  line(x + w, y, x + w, y + h);
}

void drawOscilloscope() {
  float x = 70, y = 150, w = width-140, h = 350;
  
  // Detailed grid with values
  drawDetailedGrid(x, y, w, h);
  
  // Captured waveform
  stroke(0, 120, 255);
  strokeWeight(3);
  noFill();
  beginShape();
  
  // Display the captured waveform
  for (int i = 0; i < capturedWave.length; i++) {
    float xPos = map(i, 0, capturedWave.length-1, x, x+w);
    float yPos = y + h/2 - capturedWave[i] * h/2 * 0.8; // Invert direction
    vertex(xPos, yPos);
  }
  endShape();
  
  // Zero line and indicators
  stroke(0, 150);
  line(x, y + h/2, x+w, y + h/2);
  
  // Show trigger line
  stroke(255, 0, 0, 100);
  float triggerY = y + h/2 - triggerThreshold * h/2 * 0.8;
  line(x, triggerY, x+w, triggerY);
  
  // Show status indicator
  fill(triggerFound ? color(0, 150, 0) : color(200, 0, 0));
  textAlign(RIGHT, TOP);
  text(triggerFound ? "Triggered" : "Auto", x + w - 10, y + 10);
}

void drawSimpleGrid(float x, float y, float w, float h) {
  stroke(gridColor);
  strokeWeight(1);
  
  // Main horizontal lines
  line(x, y + h/2, x+w, y + h/2);  // Center line (zero)
  
  // Vertical lines
  for (int i = 0; i <= 4; i++) {
    float xPos = x + i*(w/4);
    line(xPos, y, xPos, y+h);
  }
}

void drawDetailedGrid(float x, float y, float w, float h) {
  stroke(gridColor);
  strokeWeight(1);
  
  // Horizontal lines
  for (int i = 0; i <= 8; i++) {
    float yPos = y + i*(h/8);
    line(x, yPos, x+w, yPos);
    
    // Amplitude values
    fill(100);
    textAlign(RIGHT, CENTER);
    text(nf(1.0 - i/4.0, 1, 1), x-10, yPos);
  }
  
  // Vertical lines
  for (int i = 0; i <= 8; i++) {
    float xPos = x + i*(w/8);
    strokeWeight(i == 0 ? 2 : 1);  // Thicker line at start
    stroke(i == 0 ? color(100) : gridColor);
    line(xPos, y, xPos, y+h);
  }
  
  // Amplitude labels
  strokeWeight(1);
  fill(100);
  textAlign(RIGHT, CENTER);
  text("1.0", x-10, y);
  text("0", x-10, y + h/2);
  text("-1.0", x-10, y + h);
  
  // Sample index labels
  textAlign(CENTER, TOP);
  text("0", x, y + h + 5);
  text("64", x + w/4, y + h + 5);
  text("128", x + w/2, y + h + 5);
  text("192", x + 3*w/4, y + h + 5);
  text("256", x + w, y + h + 5);
}

void drawNoSignal() {
  textFont(smallFont);
  fill(200, 0, 0);
  textAlign(CENTER);
  text("NO SIGNAL DETECTED", width/2, height/2);
  text("Check JUCE connection on port 9004", width/2, height/2 + 30); // Update port number
}

void resetWaveforms() {
  for (int i = 0; i < waveform.length; i++) {
    waveform[i] = 0;
    capturedWave[i] = 0;
  }
  
  // Reset waveform history
  for (int i = 0; i < waveformHistory.length; i++) {
    waveformHistory[i] = 0;
  }
  waveformHistoryIndex = 0;
  
  newWaveReceived = false;
}

void keyPressed() {
  if (key == '1') {
    displayMode = 0; 
  } else if (key == '2') {
    displayMode = 1;
  } else if (key == ' ') {
    if (displayMode == 1) {
      // In oscilloscope mode, space captures current waveform without waiting for trigger
      arrayCopy(waveform, capturedWave);
    }
  } else if (key == 'r') {
    resetWaveforms();
  } else if (key == 'u' && displayMode == 1) {
    // Increase trigger threshold
    triggerThreshold = min(triggerThreshold + 0.05f, 0.95f);
  } else if (key == 'd' && displayMode == 1) {
    // Decrease trigger threshold
    triggerThreshold = max(triggerThreshold - 0.05f, -0.95f);
  }
}
