;
; divu32.s
;
;-------------------------------------

	.xdef	uint32_to_dec

;-------------------------------------
; uint32_to_dec
;
; in:
;   D0.L = unsigned 32bit value
;   A0   = destination buffer
;
; out:
;   (A0) = decimal ASCII string + NUL
;   d0.w = digit
;
; destroy:
;   none (all registers restored)
;
; max:
;   "4294967295" + NUL = 11 bytes
;-------------------------------------
uint32_to_dec:
		movem.l	d1-d3/a0-a1,-(sp)

        lea		decbuf+10(pc),a1
        clr.b	(a1)                ; NUL

        tst.l	d0
        bne		1f

        move.b	#'0',-(a1)
        bra		2f

1:
        bsr		divu32_10           ; D0=quotient, D1=remainder
        add.b	#'0',d1
        move.b	d1,-(a1)

        tst.l	d0
        bne		1b

2:
		addq.w	#1,d0
        move.b	(a1)+,(a0)+
        bne		2b

		movem.l	(sp)+,d1-d3/a0-a1
        rts

;-------------------------------------
; divu32_10
;
; in:
;   D0.L = unsigned 32bit value
;
; out:
;   D0.L = quotient
;   D1.L = remainder (0..9)
;
; destroy:
;   D2-D3
;
; note:
;   DIVU is 32bit / 16bit -> 16bit.
;   So the dividend is split into two 16bit steps:
;     upper: (0000:HI) / 10        -> quotient(HI), remainder R1
;     lower: (R1  :LO) / 10        -> quotient(LO), remainder R
;   Neither step can overflow:
;     0000:HI <= $0000FFFF -> quotient <= 6553
;     R1:LO   <= $0009FFFF -> quotient <= 65535
;-------------------------------------
divu32_10:
        move.l  d0,d2          ; d2 = N (keep low word)
        moveq   #10,d3         ; divisor = 10

        ;--- 1) upper word / 10
        clr.w   d0
        swap    d0             ; d0 = $0000:HI
        divu.w  d3,d0          ; d0 = R1:quotient(HI)

        move.w  d0,d1
        swap    d1             ; d1 upper word = quotient(HI)

        ;--- 2) (R1:LO) / 10
        move.w  d2,d0          ; d0 = R1:LO   (R1 is already in the upper word)
        divu.w  d3,d0          ; d0 = R:quotient(LO)

        move.w  d0,d1          ; d1 = 32bit quotient

        ;--- 3) remainder
        clr.w   d0
        swap    d0             ; d0 = remainder (0..9)

        exg     d0,d1          ; d0 = quotient, d1 = remainder
        rts

;-------------------------------------
        .even
decbuf:
        .ds.b    11
		.even
