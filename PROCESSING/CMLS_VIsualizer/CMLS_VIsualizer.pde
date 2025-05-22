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

void setup() {
  size(800, 600, P2D);
  
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
  background(bgColor);
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
      
      // Capture wave for oscilloscope mode when switching or on significant change
      if (displayMode == 1) {
        arrayCopy(waveform, capturedWave);
      }
    }
  } catch (Exception e) {
    println("OSC processing error: " + e);
  }
}

void drawUI() {
  // Header
  fill(240);
  noStroke();
  rect(width/2 - 200, 10, 400, 60, 10);
  fill(30);
  textFont(font);
  textAlign(CENTER, TOP);
  text("CMLS VISUALIZER", width/2, 20);
  
  // Mode information
  textFont(smallFont);
  fill(hasSignal ? color(0, 150, 0) : color(200, 0, 0));
  String modeText = displayMode == 0 ? "WAVEFORM" : "OSCILLOSCOPE";
  text("MODE: " + modeText, width/2, 100);
  
  // Instructions
  fill(100);
  text("1: Waveform | 2: Oscilloscope | SPACE: Freeze frame | R: Reset", width/2, height - 30);
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
  strokeWeight(2);
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
  
  // Show captured frame indicator
  fill(0, 120, 255);
  textAlign(RIGHT, TOP);
  text("Captured Frame", x + w - 10, y + 10);
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
  text("Check JUCE connection on port 9001", width/2, height/2 + 30);
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
    arrayCopy(waveform, capturedWave); // Capture current waveform
  } else if (key == ' ') {
    if (displayMode == 1) {
      arrayCopy(waveform, capturedWave); // Freeze current frame in oscilloscope mode
    }
  } else if (key == 'r') {
    resetWaveforms();
  }
}
