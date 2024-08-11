TARGET := xtramtest
VERSION = $(shell git describe --tags --always --dirty=-local --broken=-XX 2>/dev/null || echo local_build)

ROMS = $(TARGET).8k $(TARGET).32k $(TARGET).64k

INC := -iinc

SRC := $(TARGET).asm

NASM := nasm
DOSBOXX := dosbox-x
MAME := mame
SHASUM := shasum

RAM = 256
CYCLES = 4000
VIDEO = cga
export RAM VIDEO BREAK FLAGS


%.bin: %.asm
	$(NASM) $(INC) -f bin -o $@ -l $(@:%.bin=%.lst) -Lm -dVERSION="$(VERSION)" $<
	$(info )
	@tools/size $(@:%.bin=%.map)

$(ROMS): $(TARGET).bin
	tools/makerom $(ROMS)
	$(info )
	@$(SHASUM) $^ $(ROMS)
	$(info )

clean:
	rm -f $(ROMS) $(TARGET).bin $(TARGET).lst $(TARGET).map $(TARGET).debug $(TARGET).dep

version:
	@echo Building $(TARGET) $(VERSION)
	@echo ""


$(TARGET).dep: $(SRC)
	$(NASM) $(INC) -M -MF $@ -MT $(TARGET).bin $< 

$(TARGET).map: $(TARGET).bin

$(TARGET).debug: $(TARGET).map
	tools/make_debugscript $< > $@

debug: all $(TARGET).debug
	tools/run -debug $(FLAGS)

run: all
	mame ibm5160 -inipath ./test -isa1 $(VIDEO) -ramsize $(RAM)K $(FLAGS)

runx: all
	dosbox-x -conf test/dosbox-x.conf --set "dosbox memsizekb=$(RAM)" --set "cpu cycles=$(CYCLES)" -machine $(VIDEO) $(FLAGS) 2>/dev/null

romburn: all
	minipro -p 'W27C512@DIP28' -w $(TARGET).64k

romemu: all
	eprom -mem 27256 -auto y $(TARGET).32k


.PHONY: binaries clean run $(TARGET).map romburn romemu version
.DEFAULT: all

all: version $(ROMS)

-include $(TARGET).dep