.EQU LED1 = PORTB0 ; pin 8
.EQU LED2 = PORTB1 ; pin 9
.EQU BUTTON1 = PORTB4 ; pin 12
.EQU BUTTON2 = PORTB5 ; pin 13
.EQU BUTTON3 = PORTB3 ; pin 11

.EQU TIMER0_MAX_COUNT = 18 ; 300 ms fördröjning.
.EQU TIMER1_MAX_COUNT = 6  ; 100 ms fördröjning.
.EQU TIMER2_MAX_COUNT = 12 ; 200 ms fördröjning.

.EQU RESET_vect        = 0x00 ; Reset-vektor, utgör programmets startpunkt.
.EQU PCINT0_vect       = 0x06
.EQU TIMER0_OVF_vect   = 0x20 ; Avbrottsvektor för Timer 0 
.EQU TIMER1_COMPA_vect = 0x16 ; Avbrottsvektor för Timer 1 
.EQU TIMER2_OVF_vect   = 0x12 ; Avbrottsvektor för Timer 2 

.DSEG	
.ORG SRAM_START

   counter0: .byte 1 ; static uint8_t counter0 = 0;
   counter1: .byte 1 ; static uint8_t counter1 = 0;
   counter2: .byte 1 ; static uint8_t counter2 = 0;

.CSEG

.ORG RESET_vect ; Programmets start punkt 
    RJMP main ; Hoppar till main

;********************************************************************************
; PCINT0_vect: ; avbrotts vektor för PCI PORTB (till BUTTON1)
;********************************************************************************
.ORG PCINT0_vect 
   RJMP ISR_PCINT0  

;/********************************************************************************
;* TIMER2_OVF_vect: Avbrottsvektor för Timer 2 i Normal Mode, som hoppas till
;*                  var 16.384:e ms. Programhopp sker till motsvarande
;*                  avbrottsrutin ISR_TIMER2_OVF för att hantera avbrottet.
;********************************************************************************/
.ORG TIMER2_OVF_vect ; Hopp sker till avbrottsrutin till ISR_PCINT0
   RJMP ISR_TIMER2_OVF


;/********************************************************************************
;* TIMER1_COMPA_vect: Avbrottsvektor för Timer 1 i CTC Mode, som hoppas till
;*                    var 16.384:e ms. Programhopp sker till motsvarande
;*                    avbrottsrutin ISR_TIMER1_COMPA för att hantera avbrottet.
;********************************************************************************/
.ORG TIMER1_COMPA_vect
   RJMP ISR_TIMER1_COMPA


;/********************************************************************************
;* TIMER0_OVF_vect: Avbrottsvektor för Timer 0 i Normal Mode, som hoppas till
;*                  var 16.384:e ms. Programhopp sker till motsvarande
;*                  avbrottsrutin ISR_TIMER0_OVF för att hantera avbrottet.
;********************************************************************************/
.ORG TIMER0_OVF_vect
   RJMP ISR_TIMER0_OVF

;********************************************************************************
; ISR_PCINT0: ;avbrotts vektor  som programmhop vid nedtryckning eller uppsläppning
;               av BUTTON1, annars görs inget 
;            
;********************************************************************************
ISR_PCINT0: 
   CLR R24
   STS PCICR, R24 ; PCICR = 0x00;
   LDI R24, (1 << TOIE0) ; TIMSK0 = (1 << TOIE0);
   STS TIMSK0, R24
check_button1:
   IN R24,PINB
   ANDI R24, (1 << BUTTON1)
   BREQ check_button2 ; Om BUTTON1 inte är nedtryckt, kolla BUTTON2
   CALL timer1_toggle ; Om BUTTON3 är nedtryckt, toggla Timer 1, annars avsluta.
   RETI
check_button2:
   IN R24,PINB
   ANDI R24, (1 << BUTTON2)
   BREQ check_button3
   CALL timer2_toggle
   RETI
check_button3:
	IN R24, PINB
	ANDI R24, (1 << BUTTON3)
	BREQ ISR_PCINT0_end 
	CALL system_reset ; Här görs en systemåterställning, kalla på system_reset
ISR_PCINT0_end:
    RETI


;/********************************************************************************
;* ISR_TIMER2_OVF: Avbrottsrutin för Timer 2 i Normal Mode, som äger rum var 
;*                 16.384:e ms vid overflow (uppräkning till 256, då räknaren 
;*                 blir överfull). Ungefär var 200:e ms togglas lysdiod LED2.
;********************************************************************************/
ISR_TIMER2_OVF:
   LDS R24, counter2
   INC R24
   CPI R24, TIMER2_MAX_COUNT
   BRLO ISR_TIMER2_OVF_end
   OUT PINB, R18
   CLR R24
ISR_TIMER2_OVF_end:
   STS counter2, R24
   RETI


;/********************************************************************************
;* ISR_TIMER1_COMPA: Avbrottsrutin för Timer 1 i CTC Mode, som äger rum var 
;*                   16.384:e ms vid vid uppräkning till 256. Ungefär var 
;*                   100:e ms togglas lysdiod LED1.
;********************************************************************************/
ISR_TIMER1_COMPA:
   LDS R24, counter1
   INC R24
   CPI R24, TIMER1_MAX_COUNT
   BRLO ISR_TIMER1_COMPA_end
   OUT PINB, R17
   CLR R24
ISR_TIMER1_COMPA_end:
   STS counter1, R24
   RETI

;/********************************************************************************
;* ISR_TIMER0_OVF: Avbrottsrutin för Timer 0 i Normal Mode, som äger rum var 
;*                 16.384:e ms vid overflow (uppräkning till 256, då räknaren 
;*                 blir överfull). Ungefär var 300:e ms togglas lysdiod LED1.
;********************************************************************************/
ISR_TIMER0_OVF:
   LDS R24, counter0
   INC R24
   CPI R24, TIMER0_MAX_COUNT
   BRLO ISR_TIMER0_OVF_end
   STS PCICR, R16
   CLR R24
   STS TIMSK0, R24 
ISR_TIMER0_OVF_end:
   STS counter0, R24
   RETI

 main: 

setup:
 LDI R16, (1 << LED1) | (1 << LED2)
 OUT DDRB, R16
 LDI R16, (1 << LED1)
 LDI R17, (1 << LED2)
 LDI R24, (1 << BUTTON1) | (1 << BUTTON2) | (1 << BUTTON3)
 OUT PORTB, R24
 STS PCICR, R16 ; som (1 << PCIE0)
 STS PCMSK0, R24 ; som (1 << BUTTON1)
 LDI R18, (1 << CS00) | (1 << CS02) ; timer 0
 OUT TCCR0B, R18
 LDI R19, (1 << WGM12) | (1 << CS10) | (1 << CS12) ; timer 1
 STS TCCR1B, R19
 ; OCR1A = 256 => Timer 1 räknar till 256 som de andra timerkretsarna.
 LDI R19, high(256) ; 256 = 0000 0001 0000 0000 => övre till OCR1AH, lägre till OCR1AL.
 STS OCR1AH, R19 ; OCR1AH = 0000 0001.
 LDI R19, low(256) 
 STS OCR1AL, R19 ; OCRAL = 0000 0000
 LDI R19, (1 << CS20) | (1 << CS21) | (1 << CS22)
 STS TCCR2B, R19
 SEI

main_loop: 
    RJMP main_loop ; Återstartar kontinuerligt loopen.

;********************************************************************************
; system_reset: Återställer systemet genom att nollställa alla räknare samt
;               släcka lysdioderna.
;********************************************************************************
system_reset:
   CLR R24
   STS counter0, R24
   STS counter1, R24
   STS counter2,R24
   IN R24, PORTB
   ANDI R24, ~((1 << LED1) | (1 << LED2))
   OUT PORTB, R24
   RET	

timer1_toggle:
   LDS R24, TIMSK1
   CPI R24, 0 
   BREQ timer1_on
timer1_off:
   CLR R24
   STS TIMSK1, R24 ; Timer 1 av.
   IN R24, PORTB
   ANDI R24, ~(1 << LED1)
   OUT PORTB, R24
   RET 
timer1_on:
   STS TIMSK1, R17 ; Sätter på Timer 1 genom att tilldela (1 << OCIE1A) = (1 << LED1);
   RET

timer2_toggle:
   LDS R24, TIMSK2
   CPI R24, 0 
   BREQ timer2_on
timer2_off:
   CLR R24
   STS TIMSK2, R24 ; Timer 2 av.
   IN R24, PORTB
   ANDI R24, ~(1 << LED2)
   OUT PORTB, R24
   RET 
timer2_on:
   STS TIMSK2, R17 ; Sätter på Timer 2 genom att tilldela (1 << OCIE1A) = (1 << LED2);
   RET
   
