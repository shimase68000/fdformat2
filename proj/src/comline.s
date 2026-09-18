;
; comline.s (parse command line)
;
;----------------------------------

    .include iocscall.mac
	.include doscall.mac
	.include fdformat2.mac

;----------------------------------

	.xdef	parse_comline

;----------------------------------

	.text

;----------------------------------
; init sw
;----------------------------------
init_sw:
	movem.l	d0/a0,-(sp)

	sf		sw_physical(a5)
	sf		sw_logical(a5)
	sf		sw_force(a5)
	sf		sw_usage(a5)

	lea		sw_slide(a5),a0
	moveq.l	#NUM_OF_DRIVE-1,d0
@@:
	move.b	#DEFAULT_SLIDE_VALUE,(a0)+
	dbra	d0,@b

	movem.l	(sp)+,d0/a0
	rts

;----------------------------------
; parse comline
;----------------------------------
parse_comline:
	move.l	a2,-(sp)

	bsr		init_sw

	tst.b	(a2)+		; skip the length byte, and check for empty
	beq		parse_exit

	bsr		parse_sub

parse_exit:
	move.l	(sp)+,a2
	rts

;----------------------------------
parse_sub:
	movem.l	d0-d3/a1-a3,-(sp)

	lea		str_force(pc),a3
	moveq.l	#0,d1			; clear state: d1.b
	moveq.l	#0,d2			; clear counter
	moveq.l	#0,d3			; clear switch 's' flag

parse_sub_loop:
	move.b	(a2)+,d0
	cmpi.b	#' ',d0			; check delimiter
	bhi		8f
	
	cmpi.b	#2,d1
	beq		switch_s_confirmed

	cmpi.b	#3,d1
	beq		switch_force_confirmed
9:
	moveq.l	#0,d1			; clear state

	tst.b	d0				; check terminater
	bne		parse_sub_loop

parse_sub_exit:
	movem.l	(sp)+,d0-d3/a1-a3
	rts

;--- check state
8:
	tst.b	d1
	beq		0f
	cmpi.b	#1,d1
	beq		1f					; d1.b==1: after '/','-'
	cmpi.b	#2,d1
	beq		switch_s_main		; d1.b==2: after 's'
	bra		switch_force_main	; d1.b==3: after 'f'orce

;---
0:
	cmp.b	#'/',d0
	beq		@f
	cmp.b	#'-',d0
	beq		@f
	bra		switch_usage
@@:
	moveq.l	#1,d1			; d1.b <= 1 (check next char)
	bra		parse_sub_loop

;---
1:
	ori.b	#$20,d0

	cmpi.b	#'p',d0			; 'p': physical format
	beq		switch_p
	cmpi.b	#'l',d0			; 'l': logical format
	beq		switch_l
	cmpi.b	#'s',d0			; 's': slide value
	beq		switch_s
	cmp.b	(a3),d0			; 'f'orce
	beq		switch_force

; anything other than 'p' / 'l' / 's' / 'force' after '/' or '-' lands here
switch_usage:
	moveq.l	#0,d1			; clear state
	moveq.l	#0,d2			; clear counter
	st.b	sw_usage(a5)
	bra		parse_sub_exit

;----------------------------------
switch_p:
	moveq.l	#1,d1			; d1.b <= 1 (check next char)
	st.b	sw_physical(a5)
	bra		parse_sub_loop

;----------------------------------
switch_l:
	moveq.l	#1,d1			; d1.b <= 1 (check next char)
	st.b	sw_logical(a5)
	bra		parse_sub_loop

;----------------------------------
switch_s:
	tst.b	d3				; check switch 's' flag
	beq		@f
	bra		switch_usage
	
@@:
	moveq.l	#2,d1			; d1.b <= 2 (switch s)
	moveq.l	#0,d2			; d2.w counter
	st.b	d3				; set switch 's' flag
	bra		parse_sub_loop

;--- main
switch_s_main:
	cmpi.b	#'7',d0
	bhi		switch_usage
	subi.b	#'0',d0
	bmi		switch_usage	

	cmpi.w	#NUM_OF_DRIVE,d2
	bcc		switch_usage

	move.b	d0,sw_slide(a5,d2.w)
	addq.w	#1,d2
	bra		parse_sub_loop

;--- confirmed
switch_s_confirmed:
	cmpi.b	#1,d2
	bmi		10f
	bne		9b

	moveq.l	#NUM_OF_DRIVE-1,d2
@@:
	move.b	sw_slide(a5),sw_slide(a5,d2.w)
	dbra	d2,@b
	bra		9b

;--- illegal
10:
	st.b	sw_usage(a5)
	bra		9b

;----------------------------------
switch_force:
	moveq.l	#3,d1			; d1.b <= 3 (switch 'f'orce)
	moveq.l	#0,d2			; d2.w counter
	bra		parse_sub_loop

;--- main
switch_force_main:
	addq.w	#1,d2
	ori.b	#$20,d0
	cmp.b	(a3,d2.w),d0
	bne		switch_usage
	bra		parse_sub_loop

;--- confirmed
switch_force_confirmed:
	addq.w	#1,d2
	tst.b	(a3,d2.w)
	bne		@f	

	st.b	sw_force(a5)
	bra		9b

;--- illegal
@@:
	st.b	sw_usage(a5)
	bra		9b

;----------------------------------
	.data

str_force:
	.dc.b	'force',0

