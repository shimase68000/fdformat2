;
; physical format
;
;-------------------------------------

	.include iocscall.mac
	.include doscall.mac
	.include fdformat2.mac

;-------------------------------------
	
	.xdef	track_format

;-------------------------------------
; track format
;-------------------------------------

	.text

track_format:
	movem.l	d1-d7/a0-a5,-(sp)

	moveq.l	#0,d6
	move.b	track_number(a4),d6

	move.l	d6,d4
	lsl.w	#7,d6		; cylinder (0..76)

	move.b	d4,d6
	andi.b	#1,d6		; side (0/1)

	move.b	sector_number(a4),d3
	addq.b	#1,d3		; start sector (1..8)

;--- set id_buf
	lea		id_buf(pc),a1
	moveq.l	#8-1,d5
1:
	move.w	d6,(a1)+	; track/side
	move.b	d3,(a1)+	; start sector
	move.b	#3,(a1)+	; sector size (3:1024 byte)

	andi.b	#%111,d3
	addq.b	#1,d3		; sector++

	dbra	d5,1b

;--- sector slide
	btst.l	#0,d6
	bne		2f			; outside -> sector slide (subtracting track)

	move.b	sector_number(a4),d1	; sector += slide_value
	add.b	slide_value(a4),d1
	andi.b	#%111,d1
	move.b	d1,sector_number(a4)

;--- track format
2:
	moveq.l	#0,d1
	move.b	drive_number(a4),d1
	addi.b	#PDA_BASE,d1
	lsl.w	#8,d1			; d1.hb = PDA
	move.b	#FDC_MODE,d1

	move.l	#FORMAT_MODE,d2
	move.w	d6,d2
	rol.l	#8,d2			; d2.l = format mode

	moveq.l	#4*8,d3			; d3.l = id_buf size
	lea		id_buf(pc),a1
	IOCS	_B_FORMAT

	movem.l	(sp)+,d1-d7/a0-a5
	rts

;-------------------------------------
	.bss

id_buf:
	.ds.b	4*8

