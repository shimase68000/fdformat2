;
; logical format
;
;-------------------------------------

	.include iocscall.mac
	.include doscall.mac
	.include title.mac
	.include fdformat2.mac

;-------------------------------------
	
	.xdef	logical_format

;-------------------------------------

WRITE_BUFFER_SIZE	.equ	1024
SECTOR0_IMAGE_SIZE	.equ	(sector0_image_bottom-sector0_image)
INIT_FAT_DATA_SIZE	.equ	3

DISP_XPOS	.equ	25
DISP_YPOS	.equ	12

;-------------------------------------
; logical format
;-------------------------------------

	.text

logical_format:
	bsr		clear_write_buffer
	bsr		clear_fat_area
	tst.l	d0
	bne		9f			; write error

	bsr		write_fat_data
	tst.l	d0
	bne		9f			; write error

	bsr		write_sector0_image
9:
	rts

;-------------------------------------
; write FAT data
;-------------------------------------
write_fat_data:

;--- copy to write_buffer 
	lea		write_buffer(pc),a1
	lea		init_fat_data(pc),a2
	move.w	#INIT_FAT_DATA_SIZE-1,d0
@@:
	move.b	(a2)+,(a1)+
	dbra	d0,@b

;--- write to disk
	moveq.l	#0,d1
	move.b	drive_number(a4),d1
	addi.b	#PDA_BASE,d1
	lsl.w	#8,d1
	move.b	#FDC_MODE,d1

	moveq.l	#0,d2
	move.b	#SECTOR_SIZE,d2
	lsl.w	#8,d2
	swap	d2
	move.b	#0,d2		; side 0
	lsl.w	#8,d2
	move.b	#2,d2		; sector 2 ($0400)

	move.l	#WRITE_BUFFER_SIZE,d3
	lea		write_buffer(pc),a1

	movem.l	d1-d3/a1,-(sp)
	IOCS	_B_WRITE		; write to 1st FAT
	movem.l	(sp)+,d1-d3/a1

	andi.l	#$C000_0000,d0		; error check
	bne		9f

	move.b	#0,d2		; side 0
	lsl.w	#8,d2
	move.b	#4,d2		; sector 4 ($0C00)

	IOCS	_B_WRITE	; write to 2nd FAT
	andi.l	#$C000_0000,d0
9:
	rts

;-------------------------------------
; write sector0 image
;-------------------------------------
write_sector0_image:

;--- copy to write_buffer 
	lea		write_buffer(pc),a1
	lea		sector0_image(pc),a2
	move.w	#SECTOR0_IMAGE_SIZE-1,d0
@@:
	move.b	(a2)+,(a1)+
	dbra	d0,@b

;--- volume serial number
	bsr		make_volume_serial_number	; d0.l <= VSN

	lea		write_buffer(pc),a1
	move.b	d0,$27(a1)
	lsr.l	#8,d0
	move.b	d0,$28(a1)
	lsr.l	#8,d0
	move.b	d0,$29(a1)
	lsr.l	#8,d0
	move.b	d0,$2a(a1)

;--- write to disk
	moveq.l	#0,d1
	move.b	drive_number(a4),d1
	addi.b	#PDA_BASE,d1
	lsl.w	#8,d1
	move.b	#FDC_MODE,d1

	moveq.l	#0,d2
	move.b	#SECTOR_SIZE,d2
	lsl.w	#8,d2
	swap	d2
	move.b	#0,d2		; side 0
	lsl.w	#8,d2
	move.b	#1,d2		; sector 0

	move.l	#WRITE_BUFFER_SIZE,d3
	lea		write_buffer(pc),a1
	IOCS	_B_WRITE

	andi.l	#$C000_0000,d0	; error check

	rts

;-------------------------------------
; make volume serial number
;    out:
;         d0.l volume serial number
;-------------------------------------
make_volume_serial_number:
	movem.l	d1/d6-d7,-(sp)

	IOCS	_DATEGET
	move.l	d0,d1
	IOCS	_DATEBIN
	andi.l	#$0FFF_FFFF,d0
	move.l	d0,d7

	IOCS	_TIMEGET
	move.l	d0,d1
	IOCS	_TIMEBIN
	andi.l	#$00FF_FFFF,d0
	move.l	d0,d6

	lsl.w	#8,d0
	or.w	d7,d0
	swap	d0
	swap	d7
	move.w	d7,d0
	lsr.l	#8,d6
	add.w	d6,d0		* d0; volume serial number

	movem.l	(sp)+,d1/d6-d7
	rts

;-------------------------------------
; clear write buffer
;-------------------------------------
clear_write_buffer:
	lea		write_buffer(pc),a1
	moveq.l	#0,d0
	moveq.l	#WRITE_BUFFER_SIZE/(4*8)-1,d1
1:
	move.l	d0,(a1)+
	move.l	d0,(a1)+
	move.l	d0,(a1)+
	move.l	d0,(a1)+
	move.l	d0,(a1)+
	move.l	d0,(a1)+
	move.l	d0,(a1)+
	move.l	d0,(a1)+
	dbra	d1,1b

	rts

;-------------------------------------
; clear FAT area
;-------------------------------------
clear_fat_area:
	moveq.l	#0,d1
	move.b	drive_number(a4),d1
	addi.b	#PDA_BASE,d1
	lsl.w	#8,d1
	move.b	#FDC_MODE,d1

	moveq.l	#0,d2
	move.b	#SECTOR_SIZE,d2
	lsl.w	#8,d2
	swap	d2

	move.l	#WRITE_BUFFER_SIZE,d3
	moveq.l	#0,d4

	lea		write_buffer(pc),a1
	moveq.l	#11-1,d5
2:
	move.w	d4,d2
	andi.w	#.not.(%111),d2
	lsl.w	#5,d2			; d2[15:8] <= side(0/1)

	move.b	d4,d2
	andi.b	#%111,d2
	addq.b	#1,d2			; d2[7:0] <= sector(1..8)

	movem.l	d1-d5/a1,-(sp)
	IOCS	_B_WRITE
	movem.l	(sp)+,d1-d5/a1

	andi.l	#$C000_0000,d0	; error check
	bne		3f

	addq.w	#1,d4
	dbra	d5,2b
3:
	rts

;-------------------------------------
	.data

sector0_image:
	bra.s	ipl_entry

	.dc.b	$90
	.dc.b	'FDF2v',FDFORMAT2_MARK	; OEM mark (8bytes)

;--- BPB (+$0B)
	.dc.b	$00,$04			; bytes/sector = 1024
	.dc.b	$01				; sectors/cluster
	.dc.b	$01,$00			; reserved sectors
	.dc.b	$02				; number of FATs
	.dc.b	$C0,$00			; RootEntCnt
	.dc.b	$D0,$04			; TotSec16
	.dc.b	$FE				; Media ID ($FE = 2HD)
	.dc.b	$02,$00			; FAT size (number of sectors per FAT)
	.dc.b	$08,$00			; number of sectors per track
	.dc.b	$02,$00			; number of heads
	.dc.b	$00,$00,$00,$00	; number of hidden sectors
	.dc.b	$00,$00,$00,$00	; TotSec32 (= 0)

;--- BPB (+$24)
	.dc.b	$00				; drive number
	.dc.b	$00				; reserved

;--- Extended BPB (+$26)
	.dc.b	$29				; Extended Boot signature
	.dc.b	$00,$00,$00,$00	; Volume serial number
	.dcb.b	11,$20			; Volume Label
	.dc.b	'FAT12   '		; file system type (8bytes)

;---
ipl_entry:
	moveq.l	#DISP_XPOS,d1
	moveq.l	#DISP_YPOS,d2
	IOCS	_B_LOCATE
	lea		mes_ipl1(pc),a1
	IOCS	_B_PRINT

	moveq.l	#DISP_XPOS,d1
	moveq.l	#DISP_YPOS+1,d2
	IOCS	_B_LOCATE
	lea		mes_ipl2(pc),a1
	IOCS	_B_PRINT

	IOCS	_BOOTINF

	move.l	#FDC_MODE,d7
	lsl.w	#8,d0
	or.w	d0,d7
	move.w	d7,d1
	IOCS	_B_EJECT

	IOCS	_IPLERR

mes_ipl1:
	.dc.b	$1b,'[1m',$1b,'[7m','                                             ',0

mes_ipl2:
	.dc.b	'     システムが入っていないディスクです      ',0

sector0_image_bottom	.equ	*

;-------------------------------------

init_fat_data:
	.dc.b	$FE,$FF,$FF

;-------------------------------------

	.bss

write_buffer:
	.ds.b	WRITE_BUFFER_SIZE

