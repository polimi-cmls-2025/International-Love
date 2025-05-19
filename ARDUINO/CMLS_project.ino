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

void setup() {
  Serial.begin(9600); 
  pinMode(4,OUTPUT);
  digitalWrite(4,HIGH);

}

void loop() {
  measurePot();
  measureLeds();
  Serial.println();


}

void measurePot(){
  for (int i=0;i<digPot;i++){
    PotLine(potPins5V[i]);
    for(int j=0;j<anPot;j++){
      Serial.print(" Pot");
      Serial.print(i*anPot+j);
      Serial.print(": ");
      Serial.print(analogRead(potAnPins[j]));
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
      Serial.print(" Led");
      Serial.print(i*anLed+j);
      Serial.print(": ");
      colorLed(ledAnPins[j]);
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


void colorLed(int analogPin){
  double V=1023-analogRead(analogPin);
  V=(V-redV)/(1.0*(whiteV-redV));
  //Serial.print(V);
  if(V<0.05) Serial.print(" RED   ");
  else if (V<0.5) Serial.print(" GREEN ");
  else if (V<0.96) Serial.print(" BLUE  ");
  else if (V<1.5) Serial.print(" WHITE ");
  else Serial.print(" DISCO ");
}