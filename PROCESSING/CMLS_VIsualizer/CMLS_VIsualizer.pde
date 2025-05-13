import oscP5.*;
import netP5.*;

OscP5 oscP5;
NetAddress myRemoteLocation;

// Configurazione
float[] waveform = new float[256];         // Buffer per i dati in arrivo
float[] waveformHistory = new float[2048]; // Buffer circolare per la modalità waveform
int waveformHistoryIndex = 0;              // Posizione corrente nel buffer circolare
float[] capturedWave = new float[256];     // Per la modalità oscilloscopio  
float currentFreq = 0;
float previousFreq = 0;
boolean hasSignal = false;
boolean newWaveReceived = false;  // Flag per indicare quando arrivano nuovi dati
int displayMode = 0; // 0=waveform, 1=oscilloscope
PFont font, smallFont;
color bgColor = color(255);  // Sfondo bianco
color gridColor = color(200);  // Griglia più scura per sfondo bianco
int lastReset = 0;  // Timestamp dell'ultimo reset

void setup() {
  size(800, 600, P2D);
  
  // Configura OSC
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
  
  // Se abbiamo ricevuto nuovi dati, aggiungiamoli allo storico per la modalità waveform
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
    
    // Se sono passati più di 3 secondi senza segnale, considera la connessione persa
    if (millis() - lastReset > 3000) {
      hasSignal = false;
    }
  } else {
    drawNoSignal();
  }
}

// Aggiunge i dati recenti allo storico della forma d'onda
void addToWaveformHistory() {
  for (int i = 0; i < waveform.length; i++) {
    waveformHistory[waveformHistoryIndex] = waveform[i];
    waveformHistoryIndex = (waveformHistoryIndex + 1) % waveformHistory.length;
  }
}

void oscEvent(OscMessage msg) {
  try {
    // Aggiorna il timestamp dell'ultimo messaggio ricevuto
    lastReset = millis();
    
    if (msg.checkAddrPattern("/waveform")) {
      hasSignal = true;
      int safeLength = min(waveform.length, msg.arguments().length);
      
      // Pulisci prima il buffer
      for (int i = 0; i < waveform.length; i++) {
        waveform[i] = 0;
      }
      
      // Riempi con i nuovi dati
      for (int i = 0; i < safeLength; i++) {
        waveform[i] = msg.get(i).floatValue();
      }
      
      newWaveReceived = true;
      
      // Auto-cattura se la frequenza cambia significativamente (modalità oscilloscopio)
      if (displayMode == 1 && abs(currentFreq - previousFreq) > 5) {
        arrayCopy(waveform, capturedWave);
        previousFreq = currentFreq;
      }
    } 
    else if (msg.checkAddrPattern("/freq")) {
      currentFreq = msg.get(0).floatValue();
      hasSignal = true;
    }
    else if (msg.checkAddrPattern("/reset")) {
      resetWaveforms();
      previousFreq = 0;
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
  
  // Informazioni frequenza e modalità
  textFont(smallFont);
  fill(hasSignal ? color(0, 150, 0) : color(200, 0, 0));
  String modeText = displayMode == 0 ? "WAVEFORM" : "OSCILLOSCOPE";
  text(nf(currentFreq, 0, 2) + " Hz | MODE: " + modeText, width/2, 100);
  
  // Istruzioni
  fill(100);
  text("1: Waveform | 2: Oscilloscope | SPACE: Freeze frame | R: Reset", width/2, height - 30);
}

void drawWaveform() {
  float x = 70, y = 150, w = width-140, h = 350;
  
  // Disegna la griglia prima dell'onda
  drawSimpleGrid(x, y, w, h);

  // Disegna la forma d'onda storica (streaming in tempo reale)
  stroke(255, 51, 0);
  strokeWeight(2);
  noFill();
  
  // Calcola quanti punti visualizzare (tutto il buffer visibile)
  int numPoints = waveformHistory.length;
  float pointSpacing = w / numPoints;
  
  beginShape();
  for (int i = 0; i < numPoints; i++) {
    // Ordina i campioni in modo che i più recenti siano a destra
    int idx = (waveformHistoryIndex - numPoints + i + waveformHistory.length) % waveformHistory.length;
    float value = waveformHistory[idx];
    
    float xPos = x + i * pointSpacing;
    float yPos = y + h/2 - value * h/2 * 0.8; // Inverti la direzione
    
    // Controlla che i punti siano nel range valido
    if (xPos >= x && xPos <= x + w) {
      vertex(xPos, yPos);
    }
  }
  endShape();
  
  // Linea verticale che indica la posizione corrente
  stroke(0, 255, 0, 100);
  strokeWeight(1);
  line(x + w, y, x + w, y + h);
}

void drawOscilloscope() {
  float x = 70, y = 150, w = width-140, h = 350;
  
  // Griglia dettagliata con valori
  drawDetailedGrid(x, y, w, h);
  
  // Trova il numero di campioni necessari per un periodo completo
  int samplesPerPeriod = calculateSamplesPerPeriod();
  
  // Onda catturata
  stroke(0, 120, 255);
  strokeWeight(2);
  noFill();
  beginShape();
  
  // Mostra un periodo completo o più periodi che si adattano alla larghezza disponibile
  int pointsToShow = min(samplesPerPeriod, capturedWave.length);
  
  // Se pointsToShow è troppo piccolo, mostra più periodi
  int numPeriods = max(1, min(8, (int)(256 / pointsToShow)));
  pointsToShow = min(256, pointsToShow * numPeriods);
  
  for (int i = 0; i < pointsToShow; i++) {
    float xPos = map(i, 0, pointsToShow-1, x, x+w);
    float yPos = y + h/2 - capturedWave[i % samplesPerPeriod] * h/2 * 0.8; // Inverti la direzione e ripeti il periodo se necessario
    vertex(xPos, yPos);
  }
  endShape();
  
  // Linea zero e indicatori
  stroke(0, 150);
  line(x, y + h/2, x+w, y + h/2);
  
  // Mostra il numero di periodi visualizzati
  fill(0, 120, 255);
  textAlign(RIGHT, TOP);
  text(numPeriods + " period" + (numPeriods > 1 ? "s" : ""), x + w - 10, y + 10);
}

// Calcola quanti campioni sono necessari per rappresentare un periodo completo
int calculateSamplesPerPeriod() {
  if (currentFreq <= 0) return 256; // Fallback se la frequenza non è valida
  
  // A 44100 Hz, quanti campioni servono per un periodo di questa frequenza?
  int samplesPerPeriod = (int)(44100.0 / currentFreq);
  
  // Per frequenze molto alte, assicuriamoci di avere almeno 16 campioni per periodo
  return constrain(samplesPerPeriod, 16, 256);
}

void drawSimpleGrid(float x, float y, float w, float h) {
  stroke(gridColor);
  strokeWeight(1);
  
  // Linee orizzontali principali
  line(x, y + h/2, x+w, y + h/2);  // Linea centrale (zero)
  
  // Linee verticali
  for (int i = 0; i <= 4; i++) {
    float xPos = x + i*(w/4);
    line(xPos, y, xPos, y+h);
  }
}

void drawDetailedGrid(float x, float y, float w, float h) {
  stroke(gridColor);
  strokeWeight(1);
  
  // Linee orizzontali con valori
  for (int i = 0; i <= 8; i++) {
    float yPos = y + i*(h/8);
    line(x, yPos, x+w, yPos);
    
    // Valori di ampiezza
    fill(100);
    textAlign(RIGHT, CENTER);
    text(nf(1.0 - i/4.0, 1, 1), x-10, yPos);
  }
  
  // Calcola il numero di periodi visualizzati per adattare le linee verticali
  int samplesPerPeriod = calculateSamplesPerPeriod();
  int numPeriods = max(1, min(8, (int)(256 / samplesPerPeriod)));
  
  // Disegna le linee verticali principali per ogni periodo
  for (int p = 0; p <= numPeriods; p++) {
    float xPos = x + (w * p / numPeriods);
    strokeWeight(p == 0 ? 2 : 1);  // Linea più spessa all'inizio
    stroke(p == 0 ? color(100) : gridColor);
    line(xPos, y, xPos, y+h);
    
    // Disegna le suddivisioni all'interno di ciascun periodo
    if (p < numPeriods) {
      strokeWeight(0.5);
      stroke(gridColor, 150);
      for (int d = 1; d < 4; d++) {
        float subXPos = x + (w * (p + d/4.0) / numPeriods);
        line(subXPos, y, subXPos, y+h);
      }
    }
  }
  
  // Etichette assi
  strokeWeight(1);
  fill(100);
  textAlign(RIGHT, CENTER);
  text("1.0", x-10, y);
  text("0", x-10, y + h/2);
  text("-1.0", x-10, y + h);
  
  // Calcola durata temporale di un periodo in base alla frequenza
  float periodMs = currentFreq > 0 ? (1000.0 / currentFreq) : (256/44100.0)*1000;
  float fullDurationMs = periodMs * numPeriods;
  
  // Etichette temporali
  textAlign(CENTER, TOP);
  text("0ms", x, y + h + 5);
  
  // Etichette intermedie per ogni periodo
  for (int p = 1; p < numPeriods; p++) {
    float xPos = x + (w * p / numPeriods);
    text(nf(periodMs * p, 0, 1) + "ms", xPos, y + h + 5);
  }
  
  text(nf(fullDurationMs, 0, 1) + "ms", x + w, y + h + 5);
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
  
  // Reset dello storico della forma d'onda
  for (int i = 0; i < waveformHistory.length; i++) {
    waveformHistory[i] = 0;
  }
  waveformHistoryIndex = 0;
  
  newWaveReceived = false;
}

void keyPressed() {
  if (key == '1') {
    displayMode = 0; // Modalità waveform
  } else if (key == '2') {
    displayMode = 1; // Modalità oscilloscopio
    arrayCopy(waveform, capturedWave); // Cattura immediata al cambio modalità
    previousFreq = currentFreq;
  } else if (key == ' ') {
    if (displayMode == 1) {
      arrayCopy(waveform, capturedWave); // Cattura manuale
    }
  } else if (key == 'r') {
    resetWaveforms();
    previousFreq = 0;
  }
}
