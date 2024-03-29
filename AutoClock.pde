#include <Time.h>
#include <TinyGPS.h>       //http://arduiniana.org/libraries/TinyGPS/
//#include <NewSoftSerial.h>  //http://arduiniana.org/libraries/newsoftserial/

#include <TimerOne.h>

#define TIME_MSG_LEN  11   // time sync to PC is HEADER followed by Unix time_t as ten ASCII digits
#define TIME_HEADER  'T'   // Header tag for serial time sync message
#define TIME_REQUEST  7    // ASCII bell character requests a time sync message

const byte START_PIN = 22;
const int OFFSET = -7;   // offset hours from gps time (UTC)

const byte RELAY_PIN = 2;

byte seven_seg_digits[10][7] = { 
	{ 1,1,1,1,1,1,0 },  // = 0
	{ 0,1,1,0,0,0,0 },  // = 1
	{ 1,1,0,1,1,0,1 },  // = 2
	{ 1,1,1,1,0,0,1 },  // = 3
	{ 0,1,1,0,0,1,1 },  // = 4
	{ 1,0,1,1,0,1,1 },  // = 5
	{ 1,0,1,1,1,1,1 },  // = 6
	{ 1,1,1,0,0,0,0 },  // = 7
	{ 1,1,1,1,1,1,1 },  // = 8
	{ 1,1,1,0,0,1,1 }   // = 9
};

byte tenHrPins[] = { 0, 30, 31, 0, 0, 0, 0 };
byte hrPins[] = { 34, 35, 38, 37, 36, 32, 33 };
byte tenMinPins[] = { 43, 44, 47, 45, 46, 41, 42 };
byte minPins[] = { 50, 51, 22, 23, 52, 48, 49 };
byte colonPin1 = 39;
byte colonPin2 = 40;
byte amPin = 24;
byte pmPin = 25;


boolean makeNoise = 0;
boolean debugGps = 0;


byte hundredMs = 0;
boolean tickTock = 0;
boolean halfTick = 0;

TinyGPS gps; 
//NewSoftSerial serial_gps =  NewSoftSerial(3, 2);  // receive on pin 3

void printFloat(double f, int digits = 2);


time_t prevDisplay = 0; // when the digital clock was displayed

char c;
char txt[80] = "";

void setup()
{
  pinMode(RELAY_PIN, OUTPUT);
  
  for (int i=START_PIN; i<=START_PIN+30; i++) pinMode(i, OUTPUT);
   
  Serial.begin(9600);
  Serial1.begin(4800);
  //serial_gps.begin(4800);
  Serial.println("Waiting for GPS time ... ");
  setSyncProvider(gpsTimeSync);
  
  //Timer1.initialize(1000000);
  //Timer1.initialize(500000);
  Timer1.initialize(1000000);
  Timer1.attachInterrupt(tock);
}

void loop() {
  if(Serial.available()) processSyncMessage();
  //while (Serial1.available()) gps.encode((char)Serial1.read());
  
  char c;
  
  while (Serial1.available()) {
    c = (char)Serial1.read();
    if (debugGps) Serial.print(c);
    gps.encode(c);
  }
  
}

void tock() {
  digitalWrite(colonPin1, second() % 2);
  digitalWrite(colonPin2, second() % 2);
  //digitalWrite(colonPin2, (second() + 1) % 2);

  //halfTick = halfTick ? 0 : 1;
  //if (halfTick) return;
  
  tickTock = tickTock ? 0 : 1;
  if (makeNoise) digitalWrite(RELAY_PIN, tickTock);
  digitalWrite(13, tickTock);
  /* digitalWrite(29, 1);
  delay(15);
  digitalWrite(29, 0); */
  tickTock ? Serial.println("tick") :  Serial.println("tock");
  digitalClockDisplay();
}

void digitalClockDisplay(){
  time_t newTime;
  int tenHr = ((hour() - 1) % 12 + 1) / 10;
  int oneHr = ((hour() - 1) % 12 + 1) % 10;
  
  /* // digital clock display of the time
  Serial.print("\n****** ");
  //Serial.print(hour());
  Serial.print(tenHr, DEC);
  Serial.print(oneHr, DEC);
  printDigits(minute());
  printDigits(second());
  Serial.print(" ");
  Serial.print(day());
  Serial.print(" ");
  Serial.print(month());
  Serial.print(" ");
  Serial.print(year()); 
  Serial.println("\n"); */
  
  sevenSegWrite(tenHrPins, tenHr ? tenHr : -1);
  sevenSegWrite(hrPins, oneHr);
  sevenSegWrite(tenMinPins, minute() / 10);
  sevenSegWrite(minPins, minute() % 10);
  
//  digitalWrite(colonPin1, second() % 2);
//  digitalWrite(colonPin2, (second() + 1) % 2);
  
  newTime = gpsTimeSync();
  if (newTime) setTime(newTime);
}

void printDigits(int digits){
  // utility function for digital clock display: prints preceding colon and leading 0
  Serial.print(":");
  if(digits < 10)
    Serial.print('0');
  Serial.print(digits);
}

time_t gpsTimeSync(){
  //Serial.println("gpsTimeSync");
  //  returns time if avail from gps, else returns 0
  unsigned long fix_age = 0 ;
  gps.get_new_datetime(NULL,NULL, &fix_age);
  unsigned long time_since_last_fix;
  //if(fix_age < 1000)
    return gpsTimeToArduinoTime(); // return time only if updated recently by gps  
  //return 0;
}

time_t gpsTimeToArduinoTime(){
  //Serial.println("gpsTimeToArduinoTime");
  // returns time_t from gps date and time with the given offset hours
  tmElements_t tm;
  int year;
  gps.crack_datetime(&year, &tm.Month, &tm.Day, &tm.Hour, &tm.Minute, &tm.Second, NULL, NULL);
  
  if (year < 2012) return 0;
  
  tm.Year = year - 1970; 
  time_t time = makeTime(tm);
  return time + (OFFSET * SECS_PER_HOUR);
}

void processSyncMessage() {
  // if time sync available from serial port, update time and return true
  while(Serial.available() >=  TIME_MSG_LEN ){  // time message consists of header & 10 ASCII digits
    char c = Serial.read() ;
    Serial.print(c);  
    if( c == TIME_HEADER ) {      
      time_t pctime = 0;
      for(int i=0; i < TIME_MSG_LEN -1; i++){  
        c = Serial.read();          
        if( c >= '0' && c <= '9'){  
          pctime = (10 * pctime) + (c - '0') ; // convert digits to a number    
        }
      }  
        setTime(pctime);   // Sync Arduino clock to the time received on the serial port
    }  
  }
}


void printFloat(double number, int digits)
{
  // Handle negative numbers
  if (number < 0.0)
  {
     Serial.print('-');
     number = -number;
  }

  // Round correctly so that print(1.999, 2) prints as "2.00"
  double rounding = 0.5;
  for (uint8_t i=0; i<digits; ++i)
    rounding /= 10.0;
  
  number += rounding;

  // Extract the integer part of the number and print it
  unsigned long int_part = (unsigned long)number;
  double remainder = number - (double)int_part;
  Serial.print(int_part);

  // Print the decimal point, but only if there are digits beyond
  if (digits > 0)
    Serial.print("."); 

  // Extract digits from the remainder one at a time
  while (digits-- > 0)
  {
    remainder *= 10.0;
    int toPrint = int(remainder);
    Serial.print(toPrint);
    remainder -= toPrint; 
  } 
}

void gpsdump(TinyGPS &gps)
{
  long lat, lon;
  float flat, flon;
  unsigned long age, date, time, chars;
  int year;
  byte month, day, hour, minute, second, hundredths;
  unsigned short sentences, failed;

  gps.get_position(&lat, &lon, &age);
  Serial.print("Lat/Long(10^-5 deg): "); Serial.print(lat); Serial.print(", "); Serial.print(lon); 
  Serial.print(" Fix age: "); Serial.print(age); Serial.println("ms.");
  
  feedgps(); // If we don't feed the gps during this long routine, we may drop characters and get checksum errors

  gps.f_get_position(&flat, &flon, &age);
  Serial.print("Lat/Long(float): "); printFloat(flat, 5); Serial.print(", "); printFloat(flon, 5);
  Serial.print(" Fix age: "); Serial.print(age); Serial.println("ms.");

  feedgps();

  gps.get_datetime(&date, &time, &age);
  Serial.print("Date(ddmmyy): "); Serial.print(date); Serial.print(" Time(hhmmsscc): "); Serial.print(time);
  Serial.print(" Fix age: "); Serial.print(age); Serial.println("ms.");

  feedgps();

  gps.crack_datetime(&year, &month, &day, &hour, &minute, &second, &hundredths, &age);
  Serial.print("Date: "); Serial.print(static_cast<int>(month)); Serial.print("/"); Serial.print(static_cast<int>(day)); Serial.print("/"); Serial.print(year);
  Serial.print("  Time: "); Serial.print(static_cast<int>(hour)); Serial.print(":"); Serial.print(static_cast<int>(minute)); Serial.print(":"); Serial.print(static_cast<int>(second)); Serial.print("."); Serial.print(static_cast<int>(hundredths));
  Serial.print("  Fix age: ");  Serial.print(age); Serial.println("ms.");
  
  feedgps();

  Serial.print("Alt(cm): "); Serial.print(gps.altitude()); Serial.print(" Course(10^-2 deg): "); Serial.print(gps.course()); Serial.print(" Speed(10^-2 knots): "); Serial.println(gps.speed());
  Serial.print("Alt(float): "); printFloat(gps.f_altitude()); Serial.print(" Course(float): "); printFloat(gps.f_course()); Serial.println();
  Serial.print("Speed(knots): "); printFloat(gps.f_speed_knots()); Serial.print(" (mph): ");  printFloat(gps.f_speed_mph());
  Serial.print(" (mps): "); printFloat(gps.f_speed_mps()); Serial.print(" (kmph): "); printFloat(gps.f_speed_kmph()); Serial.println();

  feedgps();

  gps.stats(&chars, &sentences, &failed);
  Serial.print("Stats: characters: "); Serial.print(chars); Serial.print(" sentences: "); Serial.print(sentences); Serial.print(" failed checksum: "); Serial.println(failed);
}
  
bool feedgps() {
  while (Serial.available()) {
    if (gps.encode(Serial.read()))
      return true;
  }
  return false;
}

void sevenSegWrite(byte pos[], byte digit) {
  for (byte seg = 0; seg < 7; ++seg) {
    digitalWrite(pos[seg], digit >= 0 && digit < 10 ? seven_seg_digits[digit][seg] : 0);
  }
}

