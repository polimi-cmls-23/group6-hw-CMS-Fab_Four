#include <BMI160Gen.h>
#include <math.h>
#include <WiFiNINA.h>
#include <WiFiUdp.h>

char ssid[] = "Vodafone-C02000124";      // your network SSID (name)
char pass[] = "7PqrH2MaEkKMg476";   // your network password
int status = WL_IDLE_STATUS;      // the WiFi radio's status

char server[] = "192.168.1.7";  // indirizzo IP server python
unsigned int localPort = 8888;    // porta settata in server python

WiFiUDP Udp;

const int i2c_addr = 0x69; 

const int bufferSize = 100; //la dimensione dei buffer intanto l'ho settata a 100 ma vedremo a quanto settarla nel momento in cui calcoliamo la velocity col metodo che sto per sviluppare
float accelerationBuffer[bufferSize]; //qui vengono memorizzati i valori dell'accelerazione media sui 3 assi
float accelXBuffer[bufferSize];
float accelYBuffer[bufferSize];
float accelZBuffer[bufferSize];
float slopeBuffer[bufferSize]; //qui vengono memorizzati i valori della variazione di accelerazione in g/s 
unsigned long timeBuffer[bufferSize];

int commonIndex = 0;  //indice per accedere e scrivere sui buffer

//threshold di rilevamento picchi accelerazione
const float accelThreshold = 1.0; 
const float prevSlopeThreshold = 1500.0; 
const float nextSlopeThreshold = 0.0;

//valori che ho utilizzato per debuggare e calibrare la rilevazione 
float maxAccel = 0.0;
float maxSlope = 0.0;
float minSlope = 0.0;  


float previousValue = 0.0; //qui ci metto il valore precedente dell'accelerazione, superfluo da quando ho inserito il buffer

//misure di tempo che mi servono per calcolare la slope
unsigned long currentTime = 0;
unsigned long previousTime = 0;

//queste due variabili le uso per non rilevare troppi picchi in un breve intervallo di tempo
unsigned long previousStrokeTime = 0;
unsigned long minStrokeInterval = 50;

//nella prima esecuzione non calcolo la slope dato che non esiste un valore precedente
bool firstExecution = true;


void setup() {
  Serial.begin(9600);
  while (!Serial);
  Serial.println("Serial ok");
  pinMode(LED_BUILTIN, OUTPUT);

  while (!BMI160.begin(BMI160GenClass::I2C_MODE, i2c_addr));
  BMI160.setAccelerometerRange(16);
  BMI160.setAccelerometerRate(1000.0);
  Serial.println(BMI160.getAccelerometerRate());

      connessione WiFi
  if (WiFi.status() == WL_NO_MODULE) {
    Serial.println("Communication with WiFi module failed!");
    while (true);
  }

  while (status != WL_CONNECTED) {
    Serial.print("Attempting to connect to SSID: ");
    Serial.println(ssid);
    status = WiFi.begin(ssid, pass);
  }

  Serial.print("Connected");
  Udp.begin(localPort);
}


void loop() {
  if (firstExecution)
    //prima di calcolare la prima accelerazione aspetto dato che ho visto che l'accelerometro ci mette un po' a iniziare a funzionare
    delay(1000);

  float acceleration = calcAccelModule();
  // Serial.println(acceleration);
  storeAcceleration(acceleration);
  currentTime = millis();
  if (currentTime == previousTime) return;
  timeBuffer[commonIndex] = currentTime;

  if (!firstExecution) {

    float slope = 1000 * (acceleration - previousValue) / (currentTime - previousTime); //slope in g/s

    storeSlope(slope);
    updateMaxAccel(acceleration);
    updateMaxSlope(slope);
    updateMinSlope(slope);  // Aggiunta: aggiorna il valore minimo di slope
    detectStroke();
  }
  updatePreviousValues(acceleration, currentTime);
  firstExecution = false;
  commonIndex = (commonIndex + 1) % bufferSize;
  



}

float calcAccelModule() {
  //inizialmente calcolavo il modulo, ho visto che conviene calcolare la media tra i tre assi per poter identificare piú facilmente 
  //passaggi da valore positivo a negativo (cosa che in realtá non ho implementato ma si potrebbe fare, ma in ogni caso mi sembra piú preciso cosí)

  int gx, gy, gz;
  BMI160.readAccelerometer(gx, gy, gz);
  float accelerationX = gx / 2048.0;
  float accelerationY = gy / 2048.0;
  float accelerationZ = gz / 2048.0;
  accelXBuffer[commonIndex] = accelerationX;
  accelYBuffer[commonIndex] = accelerationY;
  accelZBuffer[commonIndex] = accelerationZ;
  // return sqrt(accelerationX * accelerationX + accelerationY * accelerationY + accelerationZ * accelerationZ);
  return (accelerationX + accelerationY + accelerationZ)/3.0;
}

void storeAcceleration(float acceleration) {
  accelerationBuffer[commonIndex] = acceleration;
}

void storeSlope(float slope) {
  slopeBuffer[commonIndex] = slope;
}

void updateMaxAccel(float acceleration) {
  if (acceleration > maxAccel) {
    maxAccel = acceleration;
    // Serial.print("max acceleration: ");
    // Serial.println(maxAccel);
  }
}

void updateMaxSlope(float slope) {
  if (slope > maxSlope) {
    maxSlope = slope;
    // Serial.print("max slope: ");
    // Serial.println(maxSlope);
  }
}

void updateMinSlope(float slope) {
  if (slope < minSlope) {  // Aggiunta: confronto con il valore minimo
    minSlope = slope;
    // Serial.print("min slope: ");  // Aggiunta: stampa del valore minimo
    // Serial.println(minSlope);
  }
}

void updatePreviousValues(float acceleration, unsigned long currentTime) {
  previousValue = acceleration;
  previousTime = currentTime;
}

bool detectStroke() {

  // Verifica se è trascorso abbastanza tempo dall'ultimo stroke rilevato
  if (currentTime - previousStrokeTime < minStrokeInterval) {
    return false;  
  }

  

    float acceleration = accelerationBuffer[(commonIndex - 1 + bufferSize) % bufferSize];
    //verifico la condizione 1, ovvero se il valore assoluto dell'accelerazione supera la soglia
    if (abs(acceleration) > accelThreshold) {
      
      // Serial.print("condition 1 (accel) verified: ");
      // Serial.println(acceleration);


      // Verifica la condizione 2, ovvero, se acceleration é positiva ci deve corrispondere una slope positiva maggiore della soglia,
      //altrimenti una slope negativa minore di -soglia
      int prevSlopeIndex = (commonIndex - 1 + bufferSize) % bufferSize;
      for (int i = prevSlopeIndex; i != (prevSlopeIndex + bufferSize - 4) % bufferSize; i = (i - 1 + bufferSize) % bufferSize ) {

      
      if ((acceleration >= 0.0 && slopeBuffer[i] > prevSlopeThreshold) || (acceleration < 0.0 && -slopeBuffer[i] > prevSlopeThreshold)) {
        // Serial.print("condition 2 (prevslope) verified: ");
        // Serial.println(slopeBuffer[i]);

        // Verifica la condizione 3, ovvero dopo il picco ci dev'essere una slope opposta a quella corrispondente al picco
        int nextSlopeIndex = commonIndex;
        if ((acceleration >= 0.0 && slopeBuffer[nextSlopeIndex] <= nextSlopeThreshold) || (acceleration < 0.0 && -slopeBuffer[nextSlopeIndex] <= nextSlopeThreshold)) {
            // Serial.print("condition 3 (nextslope) verified: ");
            // Serial.println(slopeBuffer[nextSlopeIndex]);
            previousStrokeTime = currentTime;  // Aggiorna il tempo dell'ultimo stroke rilevato



            float speed = calcSpeed();
            float accelModule = calcAccelerationModule((commonIndex - 1 + bufferSize) % bufferSize);
            float accelModule2 = calcAccelerationModule((commonIndex - 2 + bufferSize) % bufferSize);
            float accelModule4 = calcAccelerationModule((commonIndex - 3 + bufferSize) % bufferSize);
            float velocity = (abs(acceleration * 200) 
              + abs(slopeBuffer[i]/3 + slopeBuffer[(i + bufferSize - 1) % bufferSize]/3 + slopeBuffer[(i + bufferSize - 2) % bufferSize]/3) 
              + (speed * 100) 
              + ((accelModule/3 + accelModule2/3 + accelModule4/3) * 100))
              /4;
            float finalVelocity = constrain(map(velocity, 700, 3000, 0, 127), 0, 127)/127.0;

            
            
            Serial.print("Stroke detected!: velocity = ");
            Serial.println(finalVelocity);
            sendValue(finalVelocity);
            // Serial.println(commonIndex);
            // printPreviousValues();
            return true;  
          
        }
      }
    }
  }

  return false;  
}

float calcSpeed() {
  float speedX = 0.0;
  float speedY = 0.0;
  float speedZ = 0.0;
  for (int i = (commonIndex - 10 + bufferSize) % bufferSize; i != (commonIndex - 2 + bufferSize) % bufferSize; i = (i + 1) % bufferSize) {
    unsigned long timeDelta = timeBuffer[(i+1)%bufferSize] - timeBuffer[i];
    speedX +=  accelXBuffer[i] * timeDelta;
    speedY +=  accelYBuffer[i] * timeDelta;
    speedZ +=  accelZBuffer[i] * timeDelta;
  }
  return sqrt(speedX*speedX + speedY*speedY + speedZ*speedZ);
}

float calcAccelerationModule(int index) {
  return sqrt(accelXBuffer[index]*accelXBuffer[index] + accelYBuffer[index]*accelYBuffer[index] + accelZBuffer[index]*accelZBuffer[index]);
}

void sendValue(float value) {
  Udp.beginPacket(server, localPort);
  Udp.print(value, 4);
  Udp.endPacket();
}
