TARGET := xtramtest
ROMS = $(TARGET).8k $(TARGET).32k $(TARGET).64k

.DEFAULT: all
all: $(TARGET).bin $(ROMS)

# create a user name to indicate who compiled this
USER_ID := $(shell gh api user -q ".login" 2>/dev/null || git config --get user.email 2>/dev/null || echo local_user)
$(info -- $(USER_ID) --)

# get a branch name if it is not main or master
BRANCH := $(shell git rev-parse --abbrev-ref HEAD 2>/dev/null || echo local)
ifeq ($(BRANCH),main)
BRANCH :=
endif
ifeq ($(BRANCH),master)
BRANCH :=
endif
ifneq ($(BRANCH),)
BRANCH := $(BRANCH)/
endif

# create a version string, including branch if it is not main or master
ifndef VERSION
VERSION := $(BRANCH)$(shell git describe --tags --always --dirty=+ --broken=-XX 2>/dev/null || echo local)
endif
ifeq ($(VERSION),)
VERSION := local
endif

# print the version string if this is not a make restart
$(if $(MAKE_RESTARTS),,$(info -- $(TARGET) $(VERSION) --)$(info ))


# functions to create define options for nasm
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


%.bin: %.asm %.dep Makefile
	$(NASM) $(INC) -f bin -o $@ -l $(@:%.bin=%.lst) -Lm $(DEFS) $<
	$(info )
	@tools/size $(@:%.bin=%.map)
	@$(SHASUM) $@



%.8k: %.bin
	@tools/makerom $@
	@$(SHASUM) $@

%.32k: %.bin
	@tools/makerom $@
	@$(SHASUM) $@

%.64k: %.bin
	@tools/makerom $@
	@$(SHASUM) $@


# $(ROMS): $(TARGET).bin
# 	tools/makerom $(ROMS)
# 	@echo
# 	@$(SHASUM) $^ $(ROMS)
# 	@echo

tidy:
	rm -f $(ROMS) $(TARGET).bin $(TARGET).lst $(TARGET).map $(TARGET).debug

clean: tidy
	rm -f $(TARGET).dep

%.dep: %.asm
	$(NASM) $(INC) -M -MF $@ -MT $@ $< 


# $(TARGET).dep: $(SRC)
# 	$(NASM) $(INC) -M -MF $@ -MT $(TARGET).dep $< 

%.map: %.bin
	@true

# $(TARGET).map: $(TARGET).bin

# $(TARGET).debug: $(TARGET).map
%.debug: %.map
	tools/make_debugscript $< > $@

debug: DEBUG = -debug
debug: $(TARGET).debug run

run: all
	$(MAME) ibm5160 -inipath ./test -isa1 $(VIDEO) -ramsize $(RAM)K $(DEBUG) $(FLAGS)

runx: all
	$(DOSBOXX) -conf test/dosbox-x.conf --set "dosbox memsizekb=$(RAM)" --set "cpu cycles=$(CYCLES)" -machine $(VIDEO) $(FLAGS) 2>/dev/null

romburn: all
	minipro -p 'W27C512@DIP28' -w $(TARGET).64k

romemu: all
	eprom -mem 27256 -auto y $(TARGET).32k


.PHONY: all binaries clean run romburn romemu version debug deps
.NOTINTERMEDIATE:

# all: version $(ROMS)

deps: $(TARGET).dep
-include $(TARGET).dep