;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; VISICOM Video output test
; Processor: TMS7001 @ 3,579545MHz

		.include "TMS7000.INC"
_LEDPIN	.equ	3
; PIA1 Registers
P1DA	.equ	160
P1DDRA	.equ	160
P1CRA	.equ	161
CRA2	.equ	2
CRB2	.equ	2
P1DB	.equ	162
P1DDRB	.equ	162
P1CRB	.equ	163
VDP		.equ	162

init	mov %72,B
		ldsp
		orp %(1<<_LEDPIN)
		call @init_pia1
		call @init_vdp
		orp %(1<<2),P1CRA					; Select Output register
loop	xorp %(1<<5)|(1<<6),P1DA
		jmp loop							; Done


init_pia1
		; Initialize PIA1
		; - Write strobe CB2 with E restore
		; - PA5,PA6 output & HIGH
		movp %00000100,P1CRA
		movp %00101000,P1CRB
		orp %(1<<5)|(1<<6),P1DA				; Set PA5,PA6 to OUTPUT
		rets
init_vdp
		; Initialize VDP
		rets

; TRAP vectors
		.org $FFFE
vect_reset
		.dw init
		.end