;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; VISICOM Monitor program
; Processor: TMS7001 @ 3,579545MHz

rxcnt		.equ	60
rxp			.equ	(rxcnt + 1)
;		reserved	62
textp		.equ	63

bytep		.equ	64
;loadaddrh			66
loadaddr	.equ	67
nibi		.equ	68
bswap		.equ	69
loadsize	.equ	70


_LEDPIN		.equ	2
_ACIA_SETUP .equ	(1<<7) | (1<<4) | (1 << 0)
; Notes on ACIA setup
; * Serial clock/16
; * 8b 2s no parity
; * Receive irq enabled

		.include "TMS7000.INC"
		.include "VISICOM.INC"
		.org $C000
init	mov %72,B							; Initialize stack
		ldsp
		movp %0,BPORT						; 1200 baud serial clock
		movp %3,ACIA_CR						; Reset ACIA
		orp %(1<<_LEDPIN),ADDR				; Set LED pin to output
		orp %(1<<4)|(1<<0),IOCNT0			; Enable INT1 & INT3
		call @delay
		movp %_ACIA_SETUP,ACIA_CR			; Initialize ACIA
		call @delay
		mov %1,rxcnt
		mov %1,rxp
		mov %$30,A
		sta @RX_BUFF
		mov %0,textp
		mov %0,B
puts	lda @str_hi(B)						; Load char from rom
		jz puts_end							; Check if end of string
		call @aputc							; Print over serial
		inc R1								; Go to next character
		jmp puts
puts_end
		eint								; Enable interrupts
loop	call @getc							; Read character
		jz no_char
		cmp %8,A
		jeq backspace
		cmp %$0A,A
		jeq parse_line
		cmp %$0D,A
		jeq parse_line
		cmp %$20,A
		jl no_char
		btjo %64,textp,no_char				; Check if buffer is not full
		mov textp,B
		sta @TEXT_BUFF(B)
		inc textp							; Append character to input string
echo	call @aputc							; Echo character
no_char
		jmp loop
backspace
		btjo %255,textp,delchar				; Check if input string aint empty
		jmp no_char
delchar
		dec textp
		jmp echo

parse_line
 		btjo %255,textp,parse
		jmp echo
parse	call @aputc							; Print newline character
		call @blink							; Toggle LED
		or %1,nibi							; Select high nibble
		mov %0,B
parse_loop
		lda @TEXT_BUFF(B)					; Read char from input string
		cmp %$20,A							; Check for separator chars
		jeq separator
		cmp %$60,A
		jl isupper
		sub %$20,A							; Make uppercase
isupper	call @aputc							; Print char
		sub %$30,A							; Check if character is a number
		jl notvalid
		cmp %10,A
		jl valid
		sub %7,A							; Check if character is a letter
		jl notvalid
		cmp %10,A
		jl notvalid
		cmp %16,A
		jl valid
notvalid									; Invalid character detected
		mov %$3F,A							; Print '?'
		call @aputc
		jmp parse_done
valid	btjz %1,nibi,nlo
		rl A								; Move to high nibble
		rl A
		rl A
		rl A
		and %$F0,A
		clr bswap
nlo		or R0,bswap							; Write value
		xor %1,nibi							; Change nibble index
		btjo %1,nibi,nextbyte
continue
		inc B
		cmp textp,B
		jne parse_loop
		btjz %1,nibi,notvalid
parse_done
		mov %0,textp						; Clear input string
		mov %0A,A
		jmp echo
separator
		btjz %1,nibi,notvalid				; Not a valid byte!
		jmp continue
nextbyte
		push B
		mov bytep,B							; Store byte in buffer
		sta @BYTE_BUFF(B)
		inc bytep							; Move to next byte
		pop B
		jmp continue


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
getc	btjo %255,rxcnt,process_rx_buff		; Check if buffer is on first char
		clr A
		rets
process_rx_buff
		;call @blink
		movd rxp,R1							; Calculate read offset
		sub R0,B
		and %63,B
		dec rxcnt							; Decrease read offset
		lda @RX_BUFF(B)						; Read character from buffer
		rets
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
aputc	btjzp %2,ACIA_SR,aputc				; Wait until char can be sent
		movp A,ACIA_DR						; Send char
		rets
bputc	btjzp %2,ACIA_SR,aputc				; Wait until char can be sent
		movp B,ACIA_DR						; Send char
		rets
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
blink	xorp %(1<<_LEDPIN),APORT			; Toggle LED
		rets
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
delay	push B
		mov %30,A
delay1	mov %0,B
delay2	nop
		nop
		nop
		nop
		djnz B,delay2
		djnz A,delay1
		pop B
		rets
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
put_rxbuff
		btjo %>64,rxcnt,@rx_full 			; Check if buffer is full
		mov rxp,B            				; 
		and %63,B            				; Limit buffer size to 64 bytes
		sta @RX_BUFF(B)      				; Store character in buffer
		inc rxp              				; Advance buffer pointer
		inc rxcnt              				; Increase read offset
rx_full	rets
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ISR_ACIA_rx
		push A
		push B
		btjzp %1,ACIA_SR,rx_empty			; Char received?
		movp ACIA_DR,A						; Read char & clear interrupt
		call @put_rxbuff					; char >> rx buffer and echo
rx_empty
s_wait	movp ACIA_DR,A
		btjop %2,P0,@s_wait					; Check if int1	
		pop B
		pop A
		reti
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ISR_KBENC
		push A
		push B
k_wait	movp KBENC,B						; Read key
		tsta                 				; Dummy instruction
		nop                 				; Dummy instruction
		btjop %32,P0,@k_wait				; Check if int3
		lda @kb_lut(B)						; Get char from table
		call @put_rxbuff					; char >> rx buffer and echo
		pop B
		pop A
		reti
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ISR_DUMMY
		; Do nothing
		reti
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
str_hi	.db $1B
		.text "[2J"	; Clear screen
		.db $1B
		.text "[H"	; Return cursor to home
		.text "Goedhart/VisiCom                    []\n"
		.text "======================================\n"
		.text " Hardware (c)1978 Goedhart b.v.\n"
		.text " Software (c)2015 Koen van Vliet\n"
		.text " 18KB RAM, 4/16KB ROM System\n\n"
		.text "Hello,\n"
		.text "How are you doing today?\n\n"
		.text "READY\n"
		.db 0
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
kb_lut	.db	$13, $01, $17, $1A, $05, $18, $0C, $5B, $06, $04, $12, $03, $14, $16, $11, $10
		.db	$08, $07, $19, $02, $15, $0E, $1C, $5D, $0B, $0A, $09, $0D, $0F, $1F, $1E, $1D
		.db	$5C, $00, $7D, $00, $51, $00, $21, $3D, $2B, $4C, $50, $3E, $40, $2F, $3A, $30
		.db	$08, $00, $1B, $00, $71, $00, $31, $2D, $3B, $6C, $70, $2E, $5E, $3F, $2A, $54
		.db	$73, $41, $57, $5A, $45, $58, $5F, $22, $46, $44, $52, $43, $54, $56, $25, $24
		.db	$48, $47, $59, $42, $55, $4E, $27, $26, $4B, $4A, $49, $6D, $6F, $2C, $39, $38
		.db	$53, $61, $77, $7A, $65, $78, $33, $32, $66, $64, $72, $63, $74, $76, $35, $34
		.db	$68, $67, $79, $62, $75, $6E, $37, $36, $6B, $6A, $69, $4D, $4F, $3C, $29, $28
		.db	$00, $00, $00, $20, $09, $00, $00, $00, $0A, $0D, $0B, $B8, $C8, $A7, $02, $11
		.db	$3A, $A6, $20, $11, $33, $A6, $08, $11, $28, $80, $16, $76, $01, $27, $11, $76
		.db	$80, $3A, $28, $32, $3B, $53, $7F, $AB, $46, $32, $D3, $3B, $D3, $3A, $E0, $1B
		.db	$76, $40, $3C, $FC, $32, $3D, $53, $3F, $AB, $46, $B2, $D3, $3D, $D3, $3C, $E0
		.db	$0A, $80, $16, $A2, $1F, $11, $E0, $D7, $A2, $1F, $11, $C9, $B9, $D5, $46, $0B
		.db	$D2, $30, $E5, $02, $D3, $30, $D2, $31, $E5, $02, $D3, $31, $D2, $32, $E5, $02
		.db	$D3, $32, $76, $80, $05, $02, $D2, $05, $76, $80, $33, $12, $DA, $33, $0F, $B8
		.db	$80, $02, $D0, $39, $B9, $A2, $C0, $03, $74, $40, $26, $72, $05, $33, $76, $80
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		;.org $FFF4
		.org $CFF4
vect_int5
		.dw ISR_DUMMY
vect_int4
		.dw ISR_DUMMY
vect_int3
		.dw ISR_KBENC
vect_int2
		.dw ISR_DUMMY
vect_int1
		.dw ISR_ACIA_rx
vect_reset
		.dw init

		.end