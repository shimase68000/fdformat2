#
# fdformat2 Makefile
#

SHELL := /bin/bash

# for debug
define dbg
  @echo "[Making: $@] [Deps: $^] [Changed: $?]"
endef

PROJ := fdformat2

.DEFAULT_GOAL := all

# --- define directory ---
XBINDIR := xbin
XOBJDIR := build_x68k
XLIBDIR := lib_h68k
XINCDIR := inc_h68k
XINCDIR_S := inc_h68k_s

OBJDIR  := build
LIBDIR  := lib
USRINC  := inc
USRINC_S := inc_s

SRCDIR  := src
SRCDIR_S := src_s

# --- Tools for Human68k ---
RUN68 := $(XBINDIR)/run68.exe
HAS   := $(XBINDIR)/has060x.x
HLK   := $(XBINDIR)/hlkx.r

# --- RAMDISK ---
RAMDISK := /mnt/ramdisk/$(PROJ)

# --- Build tools ---
CC    := m68k-xelf-gcc
NM    := m68k-xelf-nm
AS    := $(RUN68) $(HAS)
LK    := $(RUN68) $(HLK)

# SJIS環境ならこっち（必要に応じて utf8版に変更）
SPECS := -specs=xc.sjis.specs

# include dirs（ここにまとめる）
INCDIRS_S = . $(USRINC_S) $(XINCDIR_S)

# GCC COMPILE OPTION
CPPFLAGS  = $(addprefix -I,$(INCDIRS_S))
CPPFLAGS += -finput-charset=cp932 -fno-builtin

CPUFLAGS  = -mcpu=68000
CWARN     = -Wall -Wextra

CFLAGS   := $(CPUFLAGS) $(CWARN) -O2 $(CPPFLAGS) -MMD -MP
LDFLAGS  := $(SPECS) -Wl,-s

ASFLAGS  := -m 68000 -i ./$(XINCDIR_S) -i ./$(USRINC_S)
LKFLAGS  := -l -x -r

# XCライブラリ（install-xclib.sh 済み前提）
LDLIBS := \
    $(XLIBDIR)/clib.a \
    $(XLIBDIR)/iocslib.a \
    $(XLIBDIR)/doslib.a \
    $(XLIBDIR)/baslib.a \
    $(XLIBDIR)/gnulib.a \
    $(XLIBDIR)/libdos.a \
    $(XLIBDIR)/libiocs.a

# --- C sources (WSL build) ---
SRCS_C :=

# --- ASM sources (HAS060 on run68) ---
SRCS_S := \
        fdformat2.s \
        comline.s \
        divu32.s \
        physical_format.s \
        logical_format.s

OBJS := $(SRCS_C:%.c=$(XOBJDIR)/%.o)
DEPS := $(OBJS:.o=.d)

# --- FileEncoding conversion targets ---
USRINC_FILES := $(wildcard $(USRINC)/*)
SRCS_C_SJIS  := $(SRCS_C:%.c=$(SRCDIR_S)/%.c)
SRCS_S_SJIS  := $(SRCS_S:%.s=$(SRCDIR_S)/%.s)
USRINC_SJIS  := $(patsubst $(USRINC)/%,$(USRINC_S)/%,$(USRINC_FILES))
# ---
X68K_INCS    := $(USRINC_SJIS) $(wildcard $(XINCDIR_S)/*)

# UTF-8 -> SJIS conversion rules
$(SRCDIR_S)/%.c: $(SRCDIR)/%.c | $(SRCDIR_S)
	iconv -f UTF-8 -t CP932 $< > $@

$(SRCDIR_S)/%.s: $(SRCDIR)/%.s | $(SRCDIR_S)
	iconv -f UTF-8 -t CP932 $< > $@

$(USRINC_S)/%.h: $(USRINC)/%.h | $(USRINC_S)
	iconv -f UTF-8 -t CP932 $< > $@

$(USRINC_S)/%.mac: $(USRINC)/%.mac | $(USRINC_S)
	iconv -f UTF-8 -t CP932 $< > $@

# HASでHuman68k形式の .o を作る
X68K_ASM_OBJS := $(SRCS_S:%.s=$(XOBJDIR)/%.o)

# Convert to ELF .o for linking
ELF_ASM_OBJS  := $(SRCS_S:%.s=$(OBJDIR)/%_elf.o)

.SECONDARY:

# convert target (explicit)
.PHONY: convert
convert: $(SRCS_C_SJIS) $(SRCS_S_SJIS) $(USRINC_SJIS)

.PHONY: all
all:
	$(MAKE) convert
	$(MAKE) $(PROJ).r

.PHONY: clean show undef
$(OBJDIR):
	mkdir -p $(RAMDISK)/$@
	@if [ -L ./$@ ]; then \
		ln -sfn $(RAMDISK)/$@ ./$@; \
	elif [ ! -e ./$@ ]; then \
		ln -s $(RAMDISK)/$@ ./$@; \
	fi

$(XOBJDIR):
	mkdir -p $@

$(SRCDIR_S):
	mkdir -p $@

$(USRINC_S):
	mkdir -p $@

$(XINCDIR_S):
	mkdir -p $@

# Compile C (ELF relocatable)
#$(OBJDIR)/%.o: $(SRCDIR_S)/%.c | $(OBJDIR)
#	$(CC) $(SPECS) $(CFLAGS) -c $< -o $@

# Assemble (HAS via run68) -> Human68k .o
$(XOBJDIR)/%.o: $(SRCDIR_S)/%.s | $(XOBJDIR)
	$(AS) $(ASFLAGS) $< -o $@ | iconv -f CP932 -t UTF-8

# Convert Human68k .o -> ELF .o
# NOTE: do NOT use -k since your C symbols are without leading '_'
#$(OBJDIR)/%_elf.o: $(XOBJDIR)/%.o | $(OBJDIR)
#	x68k2elf.py -v $< $@

# Link
#$(PROJ).r: $(OBJS) $(ELF_ASM_OBJS)
#	$(LK) -o $@ $^ $(LDLIBS) $(LDFLAGS)
$(PROJ).r: $(OBJS) $(X68K_ASM_OBJS)
	$(LK) $(LKFLAGS) -o $@ $^ $(LDLIBS) | iconv -f CP932 -t UTF-8
	@echo -e "\033[32m"
	ls -la $@
	@echo -e "\033[0m"

#
$(X68K_ASM_OBJS): $(X68K_INCS)

# Quick check: show undefined symbols after link objects are ready
undef: $(OBJS) $(ELF_ASM_OBJS)
	@echo "---- Undefined symbols (per object) ----"
	@$(NM) -u $(OBJS) $(ELF_ASM_OBJS) || true

show:
	@echo "OBJS=$(OBJS)"
	@echo "X68K_ASM_OBJS=$(X68K_ASM_OBJS)"
	@echo "ELF_ASM_OBJS=$(ELF_ASM_OBJS)"

-include $(DEPS)

check:
	make clean
	make all -j8

clean:
	rm -r $(RAMDISK)/*
	rm -r $(SRCDIR_S) $(USRINC_S)
	rm -r $(OBJDIR) $(XOBJDIR)
	rm -r $(PROJ).x $(PROJ).x.elf
	rm -r $(PROJ).r

