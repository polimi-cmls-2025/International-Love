int Ts=10;
 
int potPins5V[] = {6,8,10,12};
int potPins0V[] = {7,9,11,13};
int potAnPins[]={A0,A1,A2};
int digPot=4;
int anPot=3;

int ledPins[] = {3,4,5};
int ledAnPins[]={A4,A5};
int digLed=3;
int anLed=2;

int calLed=2; //Dig Pin to calibrate red and white
int redV=0;
int whiteV=0;

int pots[12]={};
int leds[6]={};

void setup() {
  Serial.begin(9600); 
  pinMode(4,OUTPUT);
  digitalWrite(4,HIGH);

}

void loop() {
  measurePot();
  measureLeds();
  Serial.print("<");
  int waves[4]={0,0,0,0};
  if(leds[3]!=0){
    waves[leds[3]-1]=pots[5];
  }
  if(leds[5]!=0){
    waves[leds[5]-1]=pots[4];
  }
  Serial.print(waves[0]);
  Serial.print(",");
  Serial.print(waves[1]);
  Serial.print(",");
  Serial.print(waves[2]);
  Serial.print(",");
  Serial.print(waves[3]);
  Serial.print(",");
  Serial.print(pots[2]);
  Serial.print(",");
  Serial.print(pots[1]);
  Serial.print(",");
  Serial.print(pots[0]);
  Serial.print(",");
  Serial.print(pots[3]);

  int fx[4]={0,0,0,0};
  if(leds[1]!=0){
    fx[leds[1]-1]=pots[8];
  }
  if(leds[2]!=0){
    fx[leds[2]-1]=pots[11];
  }
  Serial.print(",");
  Serial.print(fx[0]);
  Serial.print(",");
  Serial.print(fx[1]);
  Serial.print(",");
  Serial.print(fx[2]);
  Serial.print(",");
  Serial.print(fx[3]);
  Serial.print(",");

  int filt[4]={0,0,0,0};
  if(leds[4]!=0){
    filt[leds[4]-1]=pots[7];
  }
  if(leds[0]!=0){
    filt[leds[0]-1]=pots[10];
  }
  Serial.print(filt[0]);
  Serial.print(",");
  Serial.print(filt[1]);
  Serial.print(",");
  Serial.print(filt[2]);
  Serial.print(",");
  Serial.print(filt[3]);
  Serial.print(",");
  Serial.print(pots[9]);
  Serial.print(",");
  Serial.print(pots[6]);
  Serial.println(">");
}

void measurePot(){
  for (int i=0;i<digPot;i++){
    PotLine(potPins5V[i]);
    for(int j=0;j<anPot;j++){
      /*Serial.print(" Pot");
      Serial.print(i*anPot+j);
      Serial.print(": ");
      Serial.print(analogRead(potAnPins[j]));*/
      pots[i*anPot+j]=1000-analogRead(potAnPins[j]);
    }
    delay(Ts);
    //Serial.println();
  }
  //Serial.println();
  PotLine(0); 

}

void PotLine(int digitalLine){
  for(int i=0;i<digPot;i++){
    if(potPins5V[i]==digitalLine){
      pinMode(potPins5V[i],OUTPUT);
      digitalWrite(potPins5V[i],HIGH);
      pinMode(potPins0V[i],OUTPUT);
      digitalWrite(potPins0V[i],LOW);
    }
    else{
      pinMode(potPins5V[i],INPUT);
      pinMode(potPins0V[i],INPUT);
    }
  } 
}

void measureLeds(){
  calibrateLed();
  for (int i=0;i<digLed;i++){
    LedLine(ledPins[i]);
    for(int j=0;j<anLed;j++){
      /*Serial.print(" Led");
      Serial.print(i*anLed+j);
      Serial.print(": ");*/
      
      leds[i*anLed+j]=colorLed(ledAnPins[j]);
    }
    delay(Ts);
    
  }
  Serial.println();
  LedLine(0); //0 acts as null value so everyting goes to input

}

void LedLine(int digitalLine){
  for(int i=0;i<digLed;i++){
    if(ledPins[i]==digitalLine){
      pinMode(ledPins[i],OUTPUT);
      digitalWrite(ledPins[i],HIGH);
    }
    else{
      pinMode(ledPins[i],INPUT);
    }
  } 
}

void calibrateLed(){
    pinMode(2,OUTPUT);
    digitalWrite(2,HIGH);

    redV=1023-analogRead(ledAnPins[0]);
    whiteV=1023-analogRead(ledAnPins[1]);

    delay(Ts);

    pinMode(2,INPUT);
}


int colorLed(int analogPin){
  double V=1023-analogRead(analogPin);
  V=(V-redV)/(1.0*(whiteV-redV));
  //Serial.print(V);
  if(V<0.05) return 1;
  else if (V<0.5) return 2;
  else if (V<0.96) return 3;
  else if (V<1.5) return 4;
  else return 0;
}