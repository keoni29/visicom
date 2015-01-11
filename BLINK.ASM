;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; VISICOM BLINK LED ON PA3 at approx 1Hz
; Processor: TMS7001 @ 3,579545MHz

.include "TMS7000.INC"

_LEDPIN		.equ	2

        .org $c000
init
		mov %72,B								; Initialize stack
		ldsp
		orp %(1<<_LEDPIN),ADDR					; Set LED pin to output
loop	
		orp %(1<<_LEDPIN),APORT					; Turn on LED
		call @delay
		andp %~(1<<_LEDPIN),APORT				; Turn off LED
		call @delay
		jmp loop

delay	mov %0,A
delay1	mov %0,B
delay2	nop
		nop
		nop
		nop
		djnz B,delay2
		djnz A,delay1
		rets
		
		;.org $FFFE
		.org $CFFE
vect_reset
		.dw init
		.end