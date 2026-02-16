#include<LiquidCrystal_I2C.h>
#include<Wire.h>
float output;
LiquidCrystal_I2C lcd(0x27,16,2);

const int loplus = D5;
const int lominus = D6;

void setup(){
  Serial.begin(9600);
  lcd.init();
  lcd.backlight();
  lcd.setCursor(0,0);
  lcd.println("ECG MONITORING  ");
  delay(500);
  lcd.clear();
  pinMode(loplus,INPUT);
  pinMode(lominus,INPUT);
}
void loop(){

  lcd.setCursor(0,0);
  lcd.println("ECG MONITORING");
  delay(3000);
  lcd.clear();

  lcd.setCursor(0,0);
  Serial.println("Scanning...");
  lcd.println("Scanning...");
  delay(500);
  lcd.clear();

  int plusstate = digitalRead(loplus);
  int minusstate = digitalRead(lominus);

  if(plusstate==1||minusstate==1){
    lcd.setCursor(0,0);
    lcd.println(output);
    delay(1000);
    lcd.clear();
  }
 else{
  float output= analogRead(A0);
  lcd.println(output);
 }
  delay(1);

}



 