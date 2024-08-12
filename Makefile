TARGET := xtramtest

ifndef VERSION
VERSION := $(shell git describe --tags --always --dirty=-local --broken=-XX 2>/dev/null || echo local_build)
endif
ifeq ($(VERSION),)
VERSION := local_build
endif

$(if $(MAKE_RESTARTS),,$(info -- $(TARGET) $(VERSION) --)$(info ))

ROMS = $(TARGET).8k $(TARGET).32k $(TARGET).64k

defined = $(findstring undefined,$(origin $(1)))

DEFLIST = VERSION SHOWSTACK
# export $(DEFLIST)

VARDEF = $(if $(call defined,$(1)),,-d$(1)$(if $(value $(1)),="$(value $(1))"))

DEFS := $(foreach var,$(DEFLIST),$(call VARDEF,$(var)))

INC := -iinc

vpath % inc

SRC := $(TARGET).asm

NASM := nasm
DOSBOXX := dosbox-x
MAME := mame
SHASUM := shasum

RAM = 256
CYCLES = 4000
VIDEO = cga
export RAM VIDEO BREAK FLAGS


%.bin: %.asm Makefile
	$(NASM) $(INC) -f bin -o $@ -l $(@:%.bin=%.lst) -Lm $(DEFS) $<
	$(info )
	@tools/size $(@:%.bin=%.map)

$(ROMS): $(TARGET).bin
	tools/makerom $(ROMS)
	$(info )
	@$(SHASUM) $^ $(ROMS)
	$(info )

clean:
	rm -f $(ROMS) $(TARGET).bin $(TARGET).lst $(TARGET).map $(TARGET).debug $(TARGET).dep


$(TARGET).dep: $(SRC)
	$(NASM) $(INC) -M -MF $@ -MT $(TARGET).bin $< 

$(TARGET).map: $(TARGET).bin

$(TARGET).debug: $(TARGET).map
	tools/make_debugscript $< > $@

debug: DEBUG = -debug
debug: all $(TARGET).debug run

run: all
	$(MAME) ibm5160 -inipath ./test -isa1 $(VIDEO) -ramsize $(RAM)K $(DEBUG) $(FLAGS)

runx: all
	$(DOSBOXX) -conf test/dosbox-x.conf --set "dosbox memsizekb=$(RAM)" --set "cpu cycles=$(CYCLES)" -machine $(VIDEO) $(FLAGS) 2>/dev/null

romburn: all
	minipro -p 'W27C512@DIP28' -w $(TARGET).64k

romemu: all
	eprom -mem 27256 -auto y $(TARGET).32k


.PHONY: binaries clean run $(TARGET).map romburn romemu version debug deps
.DEFAULT: all

# all: version $(ROMS)
all: $(ROMS)

deps: $(TARGET).dep
-include $(TARGET).dep