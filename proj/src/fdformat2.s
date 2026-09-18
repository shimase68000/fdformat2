;
; fdformat2.s
;
;-------------------------------------

	.include iocscall.mac
	.include doscall.mac

	.include title.mac
	.include fdformat2.mac

;-------------------------------------

	.xref	uint32_to_dec
	.xref	track_format
	.xref	logical_format
	.xref	parse_comline

;-------------------------------------

	.text

prog_start:
	bsr		disp_title

	lea		common_work(pc),a5
	bsr		init_drive_work
	bsr		parse_comline

	tst.b	sw_usage(a5)
	beq		@f

	lea		mes_usage(pc),a1
	IOCS	_B_PRINT
	bra		main_proc_exit

;---
@@:
	bsr		forward_setting_value

	tst.b	sw_force(a5)
	beq		@f

	lea		mes_title_force(pc),a1
	IOCS	_B_PRINT
@@:
	bsr		set_ejectall			; eject all drive
	bsr		disp_track_all			; init disp

	sf.b	okay_flag(a5)			; clear okay_flag (for confirm)
	sf.b	disp_sub_flag(a5)		; clear disp_sub_flag

	move.b	#SUB_STATE_NORMAL,sub_state(a5)

	sf.b	keyin_data(a5)			; clear keyin_data
	sf.b	extkey_data(a5)			; clear EXT data
	sf.b	keyin_conf_flag(a5)	; clear keyin clear flag

	bsr		main_loop

	moveq.l	#$0d,d1
	IOCS	_B_PUTC
	moveq.l	#$0a,d1
	IOCS	_B_PUTC

main_proc_exit:
	clr.l	-(sp)
	DOS		__KFLUSH
	DOS		__EXIT

;-------------------------------------
; set eject all (force eject)
;   out:
;        d6.b not empty drive count
;-------------------------------------
set_ejectall:
	moveq.l	#0,d6

	lea		drive_work(pc),a4
	moveq.l	#NUM_OF_DRIVE-1,d7
1:
	tst.b	drive_number(a4)
	bmi		2f

	cmpi.b	#STATE_EMPTY,state(a4)
	beq		@f
	cmpi.b	#STATE_ERROR_PHYSICAL,state(a4)
	beq		@f
	cmpi.b	#STATE_ERROR_LOGICAL,state(a4)
	beq		@f

	addq.b	#1,d6

@@:
	bsr		drive_eject
2:
	adda.l	#DRIVE_WORK_SIZE,a4
	dbra	d7,1b

	rts

;-------------------------------------
; set eject all2  (during exit pending)
;   out:
;        d6.b not empty drive count
;-------------------------------------
set_ejectall2:
	moveq.l	#0,d6

	lea		drive_work(pc),a4
	moveq.l	#NUM_OF_DRIVE-1,d7
1:
	tst.b	drive_number(a4)
	bmi		3f

	cmpi.b	#STATE_EMPTY,state(a4)
	beq		2f
	cmpi.b	#STATE_ERROR_PHYSICAL,state(a4)
	beq		2f
	cmpi.b	#STATE_ERROR_LOGICAL,state(a4)
	beq		2f
	cmpi.b	#STATE_CONFIRM,state(a4)
	beq		2f

	addq.b	#1,d6

	cmpi.b	#STATE_FORMATING,state(a4)
	beq		3f
	cmpi.b	#STATE_WRITING,state(a4)
	beq		3f
2:
	bsr		drive_eject
3:
	adda.l	#DRIVE_WORK_SIZE,a4
	dbra	d7,1b

	rts

;-------------------------------------
; drive_eject
;    in:
;       d1.b drive number (0..3)
;-------------------------------------
drive_eject:
	bsr		check_drive_empty
	beq		@f
	
	moveq.l	#STATE_EJECT,d0
	bsr		set_state
@@:
	rts

;-------------------------------------
; check drive empty
;-------------------------------------
check_drive_empty:
	moveq.l	#0,d5
	move.b	drive_number(a4),d5
	addi.b	#PDA_BASE,d5
	lsl.w	#8,d5
	move.w	d5,d1
	moveq.l	#0,d2
	IOCS	_B_DRVCHK

	andi.w	#%1100,d0
	cmpi.w	#%1100,d0

	rts

;-------------------------------------
; proc_empty
;-------------------------------------
proc_empty:
	tst.b	keyin_data(a5)	; check keyin data
	bne		1f

	moveq.l	#0,d6
	move.b	drive_number(a4),d6
	bmi		1f

	addi.b	#PDA_BASE,d6
	lsl.w	#8,d6
	move.w	d6,d1
	moveq.l	#0,d2
	IOCS	_B_DRVCHK

	btst.l	#1,d0		; check insert disk
	bne		2f
1:
	rts

;--- insert disk
2:
	btst.l	#3,d0		; check write protect
	bne		4f

	tst.b	sw_force(a5)	; check force mode
	bne		5f

	tst.b	confirm_flag(a5)
	beq		3f

;--- state <= WAITING (already confirm)
	moveq.l	#STATE_WAITING,d0
	bsr		set_state
	rts

;--- state <= CONFIRM (before disk formatting)
3:
	moveq.l	#STATE_CONFIRM,d0
	bsr		set_state
	rts

;--- state <= EJECT (write protect)
4:
	moveq.l	#STATE_EJECT,d0
	bsr		set_state
	rts

;--- state <= FORMATTING (force mode)
5:
	moveq.l	#STATE_FORMATING,d0
	bsr		set_state
	rts

;-------------------------------------
; proc_waiting
;-------------------------------------
proc_waiting:
	bsr		check_drive_empty
	bne		1f

;--- no disk
	moveq.l	#STATE_EMPTY,d0
	bra		2f

;--- disk exist
1:
	tst.b	keyin_data(a5)		; check keyin data
	bne		9f

	tst.b	confirm_flag(a5)
	bne		9f

;--- state <= CONFIRM
	moveq.l	#STATE_CONFIRM,d0
2:
	bsr		set_state
9:
	rts

;-------------------------------------
; proc_formatting (physical format)
;-------------------------------------
proc_formatting:
	st.b	disp_flag(a4)

	bsr		check_drive_empty
	bne		@f

;--- no disk
	moveq.l	#STATE_EMPTY,d0
	bra		2f

;--- disk exist
@@:
	bsr		track_format

	andi.l	#$C000_0000,d0		; error check
	beq		1f					; error?

;--- error
	moveq.l	#STATE_ERROR_PHYSICAL,d0
	bra		2f

;--- no error
1:
	subq.b	#1,track_number(a4)
	bcc		@f					; format complete?
	
	moveq.l	#STATE_WRITING,d0			; state <- WRITING (logical format)
2:
	bsr		set_state
@@:
	rts

;-------------------------------------
; proc_writing (logical format)
;-------------------------------------
proc_writing:
	bsr		check_drive_empty
	bne		@f

;--- no disk
	moveq.l	#STATE_EMPTY,d0
	bra		2f

;--- disk exist
@@:
	bsr		logical_format
	tst.l	d0				; error check
	beq		1f

;--- error
	moveq.l	#STATE_ERROR_LOGICAL,d0
	bra		2f

;--- no error
1:
	addq.l	#1,comp_count(a4)			; comp_count++
	st.b	disp_total_flag(a5)			; set disp_total_flag

	moveq.l	#STATE_EJECT,d0
2:
	bsr		set_state
@@:
	rts

;-------------------------------------
; proc_eject
;-------------------------------------
proc_eject:
	bsr		check_drive_empty
	bne		1f

	moveq.l	#STATE_EMPTY,d0
	bsr		set_state
	bra		2f

1:
	move.w	d5,d1
	IOCS	_B_EJECT
2:
	rts

;-------------------------------------
; proc_confirm
;-------------------------------------
proc_confirm:
	bsr		check_drive_empty
	bne		1f

;--- no disk
	sf.b	confirm_flag(a5)	; clear confim_flag
	sf.b	okay_flag(a5)		; clear okay_flag

	moveq.l	#STATE_EMPTY,d0
	bsr		set_state
	rts

;--- disk exist
1:
	st.b	keyin_conf_flag(a5)	; set keyin confirm flag

	move.b	keyin_data(a5),d2	; d2.b <= keyin data
	bne		@f
	rts

@@:
	moveq.l	#0,d6
	bsr		check_confirm_key

	tst.b	d0
	beq		9f
	bpl		2f

;--- Yes
	sf.b	confirm_flag(a5)	; clear confirm_flag

	moveq.l	#STATE_FORMATING,d0
	bsr		set_state

	rts

;--- No
2:
	moveq.l	#STATE_EJECT,d0		; state <- EJECT
	bsr		set_state
9:
	rts

;-------------------------------------
; proc_error (physical/logical)
;-------------------------------------
proc_error_physical:
proc_error_logical:
	bra		proc_empty

;-------------------------------------
; proc state
;-------------------------------------
proc_state:
	movem.l	d0-d7/a0-a6,-(sp)

	lea		proc_table(pc),a1
	moveq.l	#0,d0
	move.b	state(a4),d0
	add.w	d0,d0
	adda.w	(a1,d0.w),a1
	jsr		(a1)

	movem.l	(sp)+,d0-d7/a0-a6
	rts

;---
proc_table:
	.dc.w	proc_empty-proc_table
	.dc.w	proc_waiting-proc_table
	.dc.w	proc_formatting-proc_table
	.dc.w	proc_writing-proc_table
	.dc.w	proc_eject-proc_table
	.dc.w	proc_confirm-proc_table
	.dc.w	proc_error_physical-proc_table
	.dc.w	proc_error_logical-proc_table

;-------------------------------------
; set state empty
;-------------------------------------
set_state_empty:
	move.b	#$ff,track_number(a4)	; init track_number
	move.b	#0,sector_number(a4)	; init sector_number
	rts

;-------------------------------------
; set state waiting
;-------------------------------------
set_state_waiting:
	rts

;-------------------------------------
; set state formatting 
;-------------------------------------
set_state_formatting:
	tst.b	sw_physical(a5)
	beq		@f

	move.b	#NUM_OF_TRACK-1,track_number(a4)	; init track_number
	move.b	#0,sector_number(a4)				; init sector_number
	rts

@@:
	moveq.l	#STATE_WRITING,d0
	bra		set_state

;-------------------------------------
; set state writing
;-------------------------------------
set_state_writing:
	tst.b	sw_logical(a5)
	beq		@f
	rts

@@:
	addq.l	#1,comp_count(a4)			; comp_count++
	st.b	disp_total_flag(a5)			; set disp_total_flag

	moveq.l	#STATE_EJECT,d0
	bra		set_state

;-------------------------------------
; set state eject
;-------------------------------------
set_state_eject:
	rts

;-------------------------------------
; set state confirm
;-------------------------------------
set_state_confirm:
	st.b	confirm_flag(a5)	; set confim_flag
	sf.b	okay_flag(a5)		; clear okay_flag

	rts

;-------------------------------------
; set state error (physical/logical)
;-------------------------------------
set_state_error_physical:
set_state_error_logical:
	bsr		check_drive_empty
	beq		@f

	move.w	d5,d1
	IOCS	_B_EJECT
@@:
	rts

;-------------------------------------
; set state
;   in:
;       d0.w state
;-------------------------------------
set_state:
	st.b	disp_flag(a4)		; set disp_flag
	move.b	d0,state(a4)		; d0.b => state

	lea		set_state_table(pc),a1
	add.w	d0,d0
	adda.w	(a1,d0.w),a1
	jsr		(a1)

	rts

;---
set_state_table:
	.dc.w	set_state_empty-set_state_table
	.dc.w	set_state_waiting-set_state_table
	.dc.w	set_state_formatting-set_state_table
	.dc.w	set_state_writing-set_state_table
	.dc.w	set_state_eject-set_state_table
	.dc.w	set_state_confirm-set_state_table
	.dc.w	set_state_error_physical-set_state_table
	.dc.w	set_state_error_logical-set_state_table
	
;-------------------------------------
; main loop
;-------------------------------------
main_loop:
	lea		mes_curmove_top(pc),a1
	IOCS	_B_PRINT

	lea		drive_work(pc),a4
	moveq.l	#NUM_OF_DRIVE-1,d7
1:
	tst.b	disp_flag(a4)
	beq		2f

	bsr		disp_track2
2:
	moveq.l	#$0d,d1		; CR
	IOCS	_B_PUTC

	clr.b	disp_flag(a4)

;--- keyin sense
	bsr		keyin_sense

;--- check EXT data
	tst.b	extkey_data(a5)
	bne		4f

	bsr		proc_state

4:
	moveq.l	#$0a,d1		; LF
	IOCS	_B_PUTC

	adda.l	#DRIVE_WORK_SIZE,a4
	dbra	d7,1b

;--- disp total
	tst.b	disp_total_flag(a5)
	beq		3f

	bsr		disp_total
	clr.b	disp_total_flag(a5)

;--- call sub_state
3:
	bsr		sub_proc_state

	sf.b	extkey_data(a5)		; clear extkey_data

	tst.b	keyin_conf_flag(a5)
	bne		@f

	sf.b	keyin_data(a5)		 ; clear keyin_data
@@:
	sf.b	keyin_conf_flag(a5) ; clear keyin confirm flag
	
	tst.l	d0
	bpl		main_loop

;--- exit main_loop
exit_main_loop:
	bsr		disp_track_all2

	tst.b	disp_sub_flag(a5)
	beq		@f

	lea		mes_proc_exit(pc),a1
	IOCS	_B_PRINT
@@:
	rts

;-------------------------------------
; sub_proc_normal
;-------------------------------------
sub_proc_normal:
	moveq.l	#0,d0

	cmpi.b	#$1b,extkey_data(a5)
	bne		@f

	bsr		set_sub_state_pending
@@:
	rts

;-------------------------------------
; sub_proc_pending
;-------------------------------------
sub_proc_pending:
	bsr		set_ejectall2
	tst.b	d6				; check all drive empty?
	bne		@f

	moveq.l	#-1,d0			; set exit flag
	rts

;---
@@:
	cmpi.b	#'q',extkey_data(a5)	; EXT 'Q' key?
	bne		@f

	tst.b	sw_force(a5)
	bne		1f

	bsr		set_sub_state_exit_confirm
@@:
	moveq.l	#0,d0

	rts


1:
	bsr		set_sub_state_immediate_exit

	moveq.l	#0,d0
	rts

;-------------------------------------
; sub_proc exit confirm
;-------------------------------------
sub_proc_exit_confirm:
	bsr		set_ejectall2
	tst.b	d6
	bne		@f

	moveq.l	#-1,d0			; set exit flag
	rts

;---
@@:
	st.b	keyin_conf_flag(a5)	; set keyin confirm flag

	moveq.l	#1,d6
	bsr		check_confirm_key
	tst.b	d0				; yes or no?
	beq		9f
	bpl		1f

;--- Yes => immediate exit
	moveq.l	#0,d0
	bsr		set_sub_state_immediate_exit
	bra		9f

;--- No => pending
1:
	bsr		set_sub_state_pending
9:
	rts

;-------------------------------------
; sub_proc immediate exit
;-------------------------------------
sub_proc_immediate_exit:
	bsr		set_ejectall

	moveq.l	#0,d0
	tst.b	d6
	bne		@f

	moveq.l	#-1,d0
@@:
	rts

;-------------------------------------
; sub proc state
;-------------------------------------
sub_proc_state:
	movem.l	d1-d7/a0-a6,-(sp)

	lea		sub_proc_table(pc),a1
	moveq.l	#0,d0
	move.b	sub_state(a5),d0
	add.w	d0,d0
	adda.w	(a1,d0.w),a1
	jsr		(a1)

	movem.l	(sp)+,d1-d7/a0-a6
	rts

;---
sub_proc_table:
	.dc.w	sub_proc_normal-sub_proc_table
	.dc.w	sub_proc_pending-sub_proc_table
	.dc.w	sub_proc_exit_confirm-sub_proc_table
	.dc.w	sub_proc_immediate_exit-sub_proc_table

;-------------------------------------
; set sub_state pending
;-------------------------------------
set_sub_state_pending:
	bsr		set_ejectall2
	tst.b	d6				; check all drive empty?
	bne		@f

	moveq.l	#-1,d0			; set exit flag
	rts

@@:
	move.b	#SUB_STATE_PENDING,sub_state(a5)	; state <= PENDING

	moveq.l	#$0a,d1		; LF
	IOCS	_B_PUTC
	IOCS	_B_PUTC

	lea		mes_exit_pending(pc),a1
	IOCS	_B_PRINT

	st.b	disp_sub_flag(a5)	; set disp_sub_flag
	moveq.l	#0,d0

	rts

;-------------------------------------
; set sub_state exit confirm
;-------------------------------------
set_sub_state_exit_confirm:
	move.b	#SUB_STATE_EXIT_CONFIRM,sub_state(a5)

	moveq.l	#$0a,d1		; LF
	IOCS	_B_PUTC
	IOCS	_B_PUTC

	lea		mes_exit_confirm(pc),a1
	IOCS	_B_PRINT

	st.b	disp_sub_flag(a5)	; set disp_sub_flag
	st.b	confirm_flag(a5)	; set confirm flag
	sf.b	okay_flag(a5)		; clear okay_flag

	rts

;-------------------------------------
; set sub_state immediate exit
;-------------------------------------
set_sub_state_immediate_exit:
	move.b	#SUB_STATE_IMMEDIATE_EXIT,sub_state(a5)

	rts

;-------------------------------------
; check confirm key
;   in:
;       d6.b 0: drive confirm
;            1: sub confirm
;  out:
;       d0.b 0: nothing
;            1: No
;           -1: Yes
;-------------------------------------
check_confirm_key:
	move.b	keyin_data(a5),d2
	sf.b	keyin_data(a5)			; clear keyin data

	cmpi.b	#$0d,d2		; ENTER
	beq		2f
	cmpi.b	#$08,d2		; BS
	beq		5f

	cmpi.b	#'y',d2		; 'Y'
	beq		1f
	cmpi.b	#'n',d2		; 'N'
	beq		4f

	moveq.l	#0,d0
	rts

;--- BS key
5:
	moveq.l	#0,d0
	tst.b	okay_flag(a5)	; check okay_flag
	beq		3f

	sf.b	okay_flag(a5)	; clear okay_flag

	lea		mes_sub_confirm(pc),a1
	tst.b	d6			; drive or sub?
	bne		@f

	move.b	digit_count(a5),d1
	IOCS	_B_RIGHT

	lea		mes_drive_confirm(pc),a1
@@:
	IOCS	_B_PRINT

	lea		mes_para4(pc),a1
	IOCS	_B_PRINT
	moveq.l	#$0d,d1
	IOCS	_B_PUTC

	tst.b	d6			; drive or sub?
	beq		@f
	
	moveq.l	#3,d1
	IOCS	_B_UP
@@:
	moveq.l	#0,d0
	rts

;--- 'N' => disk eject
4:
	sf.b	confirm_flag(a5)	; clear confirm_flag
	moveq.l	#1,d0

	rts

;--- 'Y'
1:
	st.b	okay_flag(a5)		; set okay_flag

	lea		mes_sub_confirm(pc),a1
	tst.b	d6			; drive or sub?
	bne		@f

	move.b	digit_count(a5),d1
	IOCS	_B_RIGHT

	lea		mes_drive_confirm(pc),a1
@@:
	IOCS	_B_PRINT

	moveq.l	#'y',d1
	IOCS	_B_PUTC
	moveq.l	#$0d,d1
	IOCS	_B_PUTC

	tst.b	d6
	beq		@f

	moveq.l	#3,d1
	IOCS	_B_UP
@@:
	moveq.l	#0,d0
	rts

;--- ENTER key
2:
	moveq.l	#0,d0
	
	tst.b	okay_flag(a5)		; check okay_flag
	beq		3f
	
	sf.b	okay_flag(a5)		; clear okay_flag
	moveq.l	#-1,d0				; set Yes
3:
	rts

;-------------------------------------
; keyin sense
;-------------------------------------
keyin_sense:
	IOCS	_B_KEYSNS
	tst.l	d0
	beq		9f

	IOCS	_B_KEYINP
	move.b	d0,d6

	bsr		clear_key_buffer

	sf.b	keyin_data(a5)			; clear keyin data

	cmpi.b	#$1b,d6		; ESC (EXT)
	beq		1f

	cmpi.b	#$0d,d6		; ENTER
	beq		3f

	cmpi.b	#$08,d6		; BS
	beq		3f

	ori.b	#$20,d6
	cmpi.b	#'q',d6		; 'Q' (EXT)
	beq		2f

	cmpi.b	#'y',d6		; 'Y'
	beq		3f
	
	cmpi.b	#'n',d6		; 'N'
	beq		3f

	rts

;--- Y / N / ENTER / BS
3:
	move.b	d6,keyin_data(a5)
	rts

;--- Q key
2:
	cmpi.b	#SUB_STATE_PENDING,sub_state(a5)
	bne		9f
	
	move.b	d6,extkey_data(a5)	; set EXT data
	rts

;--- ESC key
1:
	cmpi.b	#SUB_STATE_NORMAL,sub_state(a5)
	bne		9f

	move.b	d6,extkey_data(a5)	; set EXT data
9:
	rts

;-------------------------------------
; clear key buffer
;-------------------------------------
clear_key_buffer:
	IOCS	_B_KEYSNS
	tst.l	d0
	bne		@f
	rts

@@:
	IOCS	_B_KEYINP
	bra		clear_key_buffer

;-------------------------------------
; disp total
;-------------------------------------
disp_total:
	lea		mes_total(pc),a1
	IOCS	_B_PRINT

	lea		drive_work(pc),a4
	moveq.l	#0,d0
	moveq.l	#NUM_OF_DRIVE-1,d7
1:
	tst.b	c_drive_letter(a4)
	bmi		@f
	add.l	comp_count(a4),d0		; d0.l = sum
@@:
	adda.l	#DRIVE_WORK_SIZE,a4
	dbra	d7,1b

	moveq.l	#0,d1					; clear digit flag
	bsr		disp_comp_count

	rts

;-------------------------------------
; disp track all
;-------------------------------------
disp_track_all:
	lea		drive_work(pc),a4
	moveq.l	#NUM_OF_DRIVE-1,d7
1:
	lea		mes_default(pc),a1
	IOCS	_B_PRINT

	moveq.l	#$0d,d1
	IOCS	_B_PUTC
	moveq.l	#6,d1
	IOCS	_B_RIGHT

;--- disp drive number
	moveq.l	#0,d1
	move.b	c_drive_number(a4),d1
	IOCS	_B_PUTC

;--- disp drive letter
	lea		mes_para2(pc),a1
	move.b	c_drive_letter(a4),d1
	bmi		2f

	lea		mes_para1(pc),a1
	move.b	d1,1(a1)
2:
	IOCS	_B_PRINT

	moveq.l	#8,d1
	IOCS	_B_RIGHT

;--- disp track
	tst.b	c_drive_letter(a4)
	bmi		3f		; drive not exist

	move.b	track_number(a4),d2
	bsr		disp_track_number		; disp '$xx'

	moveq.l	#4,d1
	IOCS	_B_RIGHT

;--- disp slide value
	moveq.l	#0,d1
	move.b	slide_value(a4),d1
	addi.b	#'0',d1
	IOCS	_B_PUTC

	moveq.l	#3,d1
	IOCS	_B_RIGHT

;--- disp comp_count
	move.l	comp_count(a4),d0
	moveq.l	#$ff,d1
	bsr		disp_comp_count

	moveq.l	#' ',d1
	IOCS	_B_PUTC

;--- disp state
	lea		mes_state_table(pc),a1
	moveq.l	#0,d0
	move.b	state(a4),d0
	add.w	d0,d0
	adda.w	(a1,d0.w),a1
	IOCS	_B_PRINT			; ${STATE},clr

	bra		4f

;---
3:
	lea		mes_para3(pc),a1	; '---',clr
	IOCS	_B_PRINT

;--- next drive
4:
	moveq.l	#$0d,d1
	IOCS	_B_PUTC

	moveq.l	#$0a,d1
	IOCS	_B_PUTC

	adda.l	#DRIVE_WORK_SIZE,a4
	dbra	d7,1b

	rts

;-------------------------------------
; disp track all2
;-------------------------------------
disp_track_all2:
	lea		mes_curmove_top(pc),a1
	IOCS	_B_PRINT

	lea		drive_work(pc),a4
	moveq.l	#NUM_OF_DRIVE-1,d7
1:
	cmpi.b	#STATE_ERROR_PHYSICAL,state(a4)
	beq		2f
	cmpi.b	#STATE_ERROR_LOGICAL,state(a4)
	beq		2f

	move.b	#STATE_EMPTY,state(a4)
2:
	bsr		disp_track2

	moveq.l	#$0d,d1
	IOCS	_B_PUTC
	moveq.l	#$0a,d1
	IOCS	_B_PUTC

	adda.l	#DRIVE_WORK_SIZE,a4
	dbra	d7,1b

	rts

;-------------------------------------
; disp track2
;-------------------------------------
disp_track2:
	moveq.l	#$0d,d1
	IOCS	_B_PUTC

	moveq.l	#18,d1
	IOCS	_B_RIGHT

	tst.b	c_drive_letter(a4)
	bmi		3f						; drive not exist

	move.b	track_number(a4),d2
	bsr		disp_track_number		; disp '$xx'

	moveq.l	#8,d1
	IOCS	_B_RIGHT

;--- disp comp_count
	move.l	comp_count(a4),d0
	moveq.l	#$ff,d1
	bsr		disp_comp_count

	moveq.l	#' ',d1
	IOCS	_B_PUTC

;--- disp state
	lea		mes_state_table(pc),a1
	moveq.l	#0,d0
	move.b	state(a4),d0
	add.w	d0,d0
	adda.w	(a1,d0.w),a1
	IOCS	_B_PRINT			; ${STATE},clr

	bra		4f

;---
3:
	lea		mes_para3(pc),a1	; '---',clr
	IOCS	_B_PRINT

;--- next drive
4:
	rts

;-------------------------------------
; forward setting value
;-------------------------------------
forward_setting_value:
	tst.b	sw_physical(a5)
	bne		@f
	tst.b	sw_logical(a5)
	bne		@f

	st.b	sw_physical(a5)		; set both flag
	st.b	sw_logical(a5)

@@:
	lea		drive_work+DRIVE_WORK_SIZE*(NUM_OF_DRIVE-1)(pc),a4
	moveq.l	#NUM_OF_DRIVE-1,d7
@@:
	move.b	sw_slide(a5,d7.w),slide_value(a4)
	suba.l	#DRIVE_WORK_SIZE,a4
	dbra	d7,@b

	rts

;-------------------------------------
; init drive work
;-------------------------------------
init_drive_work:
	move.b	#1,digit_count(a5)

	st.b	disp_total_flag(a5)

	sf.b	confirm_flag(a5)

	lea		drive_work(pc),a4
	moveq.l	#NUM_OF_DRIVE-1,d7
1:
	move.l	#INIT_COMP_COUNT,comp_count(a4)
	move.b	#STATE_EMPTY,state(a4)
	move.b	#$ff,track_number(a4)
	move.b	#INIT_SECTOR_NUMBER,sector_number(a4)
	move.b	#DEFAULT_SLIDE_VALUE,slide_value(a4)
	st.b	disp_flag(a4)

	adda.l	#DRIVE_WORK_SIZE,a4
	dbra	d7,1b

;--- get physical drive number
	bsr		get_phynumber

;--- data to drive work
	lea		phynumber+NUM_OF_DRIVE(a5),a3
	lea		drive_work+DRIVE_WORK_SIZE*(NUM_OF_DRIVE-1)(pc),a4
	moveq.l	#NUM_OF_DRIVE-1,d7
2:
	move.b	d7,d2
	move.b	d2,drive_number(a4)
	addi.b	#'0',d2
	move.b	d2,c_drive_number(a4)

	move.b	-(a3),d1
	bpl		3f

	move.b	d1,drive_number(a4)		; d1.b=$ff: drive not exist
	bra		4f
3:
	addi.b	#'A',d1
4:
	move.b	d1,c_drive_letter(a4)

	suba.l	#DRIVE_WORK_SIZE,a4
	dbra	d7,2b

	rts

;-------------------------------------
; get physical drive number
;-------------------------------------
get_phynumber:
;--- init phynumber
	lea		phynumber(a5),a3
	moveq.l	#NUM_OF_DRIVE-1,d0
@@:
	move.b	#$ff,(a3)+		; $ff=not exist
	dbra	d0,@b

;--- get physical number
	lea		phynumber(a5),a3
	lea		dpbbuf(pc),a4

	moveq.l	#DRIVE_COUNT-1,d7
1:
	move.l	a4,-(sp)
	move.w	d7,-(sp)
	addq.w	#1,(sp)
	DOS		__GETDPB
	addq.w	#6,sp

	tst.l	d0		; _GETDPB error?
	bmi		2f

	cmpi.b	#MEDIA_2HD,DPB_MEDIABYTE(a4)	; Media Byte == 2HD?
	bne		2f

	moveq.l	#0,d1
	move.b	DPB_UNITNUM(a4),d1
	move.b	DPB_DRIVENUM(a4),d2		; d2.b <- phy number (A:0..Z:25)
	move.b	d2,(a3,d1.w)
2:
	dbra	d7,1b
	rts

;-------------------------------------
; disp track number (to hex)
;    in: d2.b track number
;-------------------------------------
disp_track_number:
	movem.l	d0-d2,-(sp)

	lea		mes_track_number_def(pc),a1
	cmpi.b	#$ff,d2
	beq		@f
	lea		mes_track_number_run(pc),a1
@@:
	IOCS	_B_PRINT

	moveq.l	#0,d1
	move.b	d2,d1
	lsr.b	#4,d1
	addi.b	#'0',d1
	cmpi.b	#'9',d1
	bls		@f

	addq.b	#7,d1
@@:
	IOCS	_B_PUTC		; disp high 4bit

	move.b	d2,d1
	andi.w	#$f,d1
	addi.b	#'0',d1
	cmpi.b	#'9',d1
	bls		@f

	addq.b	#7,d1
@@:
	IOCS	_B_PUTC		; disp low 4bit

	lea		mes_escseq33m(pc),a1
	IOCS	_B_PRINT

	movem.l	(sp)+,d0-d2
	rts

;-------------------------------------
; disp comp_count
;   in: d0.l comp_count
;       d1.b digit flag
;-------------------------------------
disp_comp_count:
	movem.l	d0-d7/a0-a6,-(sp)

	lea		str_comp_count(pc),a0
	bsr		uint32_to_dec

	move.l	a0,-(sp)

	tst.b	d1		; check digit flag
	beq		3f

	move.b	digit_count(a5),d3
	cmp.b	d3,d0
	bhi		2f

	sub.b	d0,d3
	beq		3f

	subq.b	#1,d3
	moveq.l	#' ',d1
1:
	IOCS	_B_PUTC
	dbra	d3,1b
	bra		3f

2:
	move.b	d0,digit_count(a5)				; update digit_count
	bsr		set_disp_flag_all
3:
	move.l	(sp)+,a1
	IOCS	_B_PRINT

	movem.l	(sp)+,d0-d7/a0-a6
	rts

str_comp_count:
	.ds.b	11
	.even

;-------------------------------------
; set disp_flag all
;-------------------------------------
set_disp_flag_all:
	lea		drive_work(pc),a3
	moveq.l	#NUM_OF_DRIVE-1,d6
@@:
	st.b	disp_flag(a3)
	adda.l	#DRIVE_WORK_SIZE,a3
	dbra	d6,@b

	rts

;-------------------------------------
; disp title
;-------------------------------------
disp_title:
	lea		mes_title(pc),a1
	IOCS	_B_PRINT
	rts

;=====================================

	.data

mes_title:
	.dc.b	$1b,'[33m',TITLE_PROGNAME,' version ',TITLE_VERSION,TITLE_SUBVERSION,' ',TITLE_COPYRIGHT
	.dc.b	$1b,'[K',$0d,$0a
	.dc.b	0

mes_title_force:
	.dc.b	$1b,'[36m','[ FORCE MODE ]',$1b,'[33m'
	.dc.b	$1b,'[K',$0d,$0a
	.dc.b	0

mes_usage:
	.dc.b	'usage: fdformat2 [switch]',$1b,'[K',$0d,$0a
	.dc.b	'switch:  -p          physical format only',$1b,'[K',$0d,$0a
	.dc.b	'         -l          logical format only',$1b,'[K',$0d,$0a
	.dc.b	'         -s<0-7>...  sector slide value (default:2)',$1b,'[K',$0d,$0a
	.dc.b	'         -force      force mode (skip confirmation)',$1b,'[K',$0d,$0a
	.dc.b	0

mes_default:
	.dc.b	'Drive 0   : Track $FF SL[0] #',0

mes_total:
	.dc.b	'Total #',0

mes_exit_pending:
	.dc.b	$0d
	.dc.b	'[ EXIT PENDING ] [Q] 即時終了',$1b,'[K',$0d,$0a
	.dc.b	'新規ディスクの受付を停止しました。',$1b,'[K',$0d,$0a
	.dc.b	'フォーマット完了後に終了します。',$1b,'[K'
	.dc.b	$1b,'[4A',0

mes_exit_confirm:
	.dc.b	$0d
	.dc.b	'[ CONFIRM IMMEDIATE EXIT ]',$1b,'[K',$0d,$0a
	.dc.b	'実行中のフォーマットを中断して終了しますか？ [Y/N]',$1b,'[K',$0d,$0a
	.dc.b	$1b,'[K',$0d,$0a
	.dc.b	$1b,'[5A',0

mes_proc_exit:
	.dc.b	$0d,$0a
	.dc.b	$1b,'[2K',$0a
	.dc.b	$1b,'[2K',$0a
	.dc.b	$1b,'[2K',$0a
	.dc.b	$1b,'[2K',$0a
	.dc.b	$1b,'[5A',0

mes_para1:
	.dc.b	'(-)',0

mes_para2:
	.dc.b	'   ',0

mes_para3:
	.dc.b	'---'		; fall through to mes_para4 (no terminator)
mes_para4:
	.dc.b	$1b,'[K',0

mes_para9:
	.dc.b	'$FE',0

mes_track_number_def:
	.dc.b	'$',0

mes_track_number_run:
	.dc.b	'$',$1b,'[31m',0

mes_curmove_top:
	.dc.b	$0d,$1b,'[',$30+NUM_OF_DRIVE,'A',0

mes_drive_confirm:
	.dc.b	$1b,'[',DRIVE_CONFIRM_COL10,DRIVE_CONFIRM_COL1,'C',0

mes_sub_confirm:
	.dc.b	$0a,$0a,$0a,$1b,'[',SUB_CONFIRM_COL10,SUB_CONFIRM_COL1,'C',0

mes_escseq33m:
	.dc.b	$1b,'[33m',0

	.even

mes_state_table:
	.dc.w	mes_state_empty-mes_state_table
	.dc.w	mes_state_waiting-mes_state_table
	.dc.w	mes_state_formatting-mes_state_table
	.dc.w	mes_state_writing-mes_state_table
	.dc.w	mes_state_eject-mes_state_table
	.dc.w	mes_state_confirm-mes_state_table
	.dc.w	mes_state_error_physical-mes_state_table
	.dc.w	mes_state_error_logical-mes_state_table

	.even

mes_state_empty:
	.dc.b	'---',$1b,'[K',0
mes_state_waiting:
	.dc.b	'WAITING',$1b,'[K',0
mes_state_formatting:
	.dc.b	$1b,'[31m','FORMATTING (Physical)',$1b,'[33m',$1b,'[K',0
mes_state_writing:
	.dc.b	$1b,'[31m','FORMATTING (Logical)',$1b,'[33m',$1b,'[K',0
mes_state_eject:
	.dc.b	'EJECT',$1b,'[K',0
mes_state_confirm:
	.dc.b	$1b,'[43m','フォーマットを開始しますか？',$1b,'[33m',' [Y/N]',$1b,'[K',0
mes_state_error_physical:
	.dc.b	$1b,'[42m','Physical Format ERROR',$1b,'[33m',$1b,'[K',0
mes_state_error_logical:
	.dc.b	$1b,'[42m','Logical Format ERROR',$1b,'[33m',$1b,'[K',0

;-------------------------------------
	.bss

	.even

common_work:
	.ds.b	COMMON_WORK_SIZE

	.even

drive_work:
	.ds.b	(DRIVE_WORK_SIZE*NUM_OF_DRIVE)

	.even

dpbbuf:
	.ds.b	94

