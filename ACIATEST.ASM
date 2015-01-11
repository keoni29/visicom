;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; VISICOM ACIA comms test
; Processor: TMS7001 @ 3,579545MHz

ACIA_CR		.equ	128
ACIA_SR		.equ	128
ACIA_DR		.equ	129
_ACIA_SETUP .equ	(1<<7) | (1<<4) | (1 << 0)	; Serial clock/16
												; 8b 2s no parity
												; Receive irq enabled

_LEDPIN		.equ	3

		.include "TMS7000.INC"
		.org $C000
init	mov %72,B								; Initialize stack
		ldsp
		movp %0,BPORT							; 19200 baud serial clock
		movp %3,ACIA_CR							; Reset ACIA
		orp %(1<<_LEDPIN),ADDR					; Set LED pin to output
		orp %1,IOCNT0							; Enable INT1
		call @delay
		movp %_ACIA_SETUP,ACIA_CR				; Initialize ACIA
		eint									; Enable interrupts
restart	mov %0,B
loop	lda @str_hi(B)							; Load char from rom
		jz end								; Check if end of string
		call @aputc								; Print over serial
		inc R1									; Go to next character
		jmp loop
end		jmp end


aputc	btjzp %2,ACIA_SR,aputc					; Wait until char can be sent
		movp A,ACIA_DR							; Send char
		rets
bputc	btjzp %2,ACIA_SR,aputc					; Wait until char can be sent
		movp B,ACIA_DR							; Send char
		rets

delay	push B
		mov %50,A
delay1	mov %0,B
delay2	nop
		nop
		nop
		nop
		djnz B,delay2
		djnz A,delay1
		pop B
		rets

ISR_ACIA_rx
		push A
		push B
		btjzp %1,ACIA_SR,rx_empty				; Char received?
		movp ACIA_DR,B							; Read char & clear interrupt
		xorp %(1<<_LEDPIN),APORT				; Toggle LED
		call @bputc
rx_empty
wait	movp ACIA_DR,A
		btjop %2,P0,@wait						; Check if int1	
		pop B
		pop A
		reti

ISR_DUMMY
		; Do nothing
		reti

str_hi	.text "Goedhart/VisiCom                    []\n======================================\n Hardware (c)1978 Goedhart b.v.\n Software (c)2015 Koen van Vliet\n 18KB RAM, 4/16KB ROM System\n\nHello,\n\How are you doing today?\n\nREADY\n"
		.db 0

		;.org $FFF4
		.org $CFF4
vect_int5
		.dw ISR_DUMMY
vect_int4
		.dw ISR_DUMMY
vect_int3
		.dw ISR_DUMMY
vect_int2
		.dw ISR_DUMMY
vect_int1
		.dw ISR_ACIA_rx
vect_reset
		.dw init

		.end