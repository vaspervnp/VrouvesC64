# LET'S GO FOR VROUVES - Commodore 64 build
#   make            -> build/vrouves.d64 (disk) and build/vrouves.tap (tape): the game,
#                      a file (a block) per stage, the ending
#   make run        -> x64sc with the disk autostarted
#   make test       -> headless tests (VICE binary monitor)
#   make data       -> src/data/ from tools/ (world, art, texts) and music/
#   make pictures   -> the loading picture and the ending again (slow)
#   make debug      -> a rich start at wave 9 with every defender (-D DEBUG=9)
#   make shots      -> docs/img/*.png (the manual) and docs/screenshots.png
#   make manuals    -> docs/MANUAL.pdf, docs/MANUAL_GR.pdf (markdown, weasyprint)

X64     ?= x64sc
C1541   ?= c1541
TASS    ?= 64tass
PYTHON  ?= python3

BUILD   := build
SRC     := $(wildcard src/*.asm src/*.inc)
DATA_IN := $(wildcard tools/*.py) $(wildcard music/*.txt)
STAMP   := src/data/.stamp
PRG     := $(BUILD)/vrouves.prg
BOOT    := $(BUILD)/boot.prg
D64     := $(BUILD)/vrouves.d64
TAP     := $(BUILD)/vrouves.tap
TPRG    := $(BUILD)/tape/vrouves.prg
TBOOT   := $(BUILD)/tape/boot.prg
TLABELS := $(BUILD)/tape/labels.txt
LABELS  := $(BUILD)/labels.txt
LIST    := $(BUILD)/vrouves.lst
TASSDEFS ?=

# -C case-sensitive labels, -B long branches where needed, -Wall all warnings
TASSFLAGS := -C -B -Wall -I src

.PHONY: all run run-tape test data pictures debug shots manuals clean

all: $(D64) $(TAP)

$(BUILD):
	mkdir -p $@

data: $(STAMP)

$(STAMP): $(DATA_IN) | $(BUILD)
	$(PYTHON) tools/mkmusic64.py
	$(PYTHON) tools/mkdata64.py
	touch $@

pictures: | $(BUILD)
	$(PYTHON) tools/mkdata64.py --pictures

$(PRG): $(SRC) $(STAMP) | $(BUILD)
	$(TASS) $(TASSFLAGS) $(TASSDEFS) src/main.asm -o $@ --vice-labels-numeric -l $(LABELS) -L $(LIST)

# the boot file: the loading picture while it loads the game
$(BOOT): src/boot.asm $(PRG) $(BUILD)/splash.bin | $(BUILD)
	$(TASS) $(TASSFLAGS) -D GAME_START=$$(printf %d 0x$$(awk '$$3 == ".start" {print $$2}' $(LABELS))) src/boot.asm -o $@

# the stages: a file each (VR-S01...), loaded when the game reaches them
STAGE_NUMS := 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20

$(D64): $(PRG) $(BOOT)
	rm -f $@
	$(C1541) -format "vrouves,vr" d64 $@ \
	    -write $(BOOT) vrouves \
	    -write $(PRG) vr-game \
	    $(foreach n,$(STAGE_NUMS),-write $(BUILD)/stages/s$(n).prg vr-s$(n)) \
	    -write $(BUILD)/endscr.prg vr-endscr \
	    -write $(BUILD)/endbmp.prg vr-endbmp >/dev/null

# the cassette: the boot file at the KERNAL's speed, then in turbo the loading
# picture, the game, the stages and the ending (the game reads each when it is
# reached; a stage's block has its number as the entry)
$(TPRG): $(SRC) $(STAMP) | $(BUILD)
	mkdir -p $(BUILD)/tape
	$(TASS) $(TASSFLAGS) $(TASSDEFS) -D TAPE=1 src/main.asm -o $@ --vice-labels-numeric -l $(TLABELS)

$(TBOOT): src/tapeboot.asm src/tape.asm | $(BUILD)
	mkdir -p $(BUILD)/tape
	$(TASS) $(TASSFLAGS) $< -o $@

$(TAP): $(TBOOT) $(TPRG) tools/mktap.py
	$(PYTHON) tools/mktap.py $@ $(TBOOT) VROUVES $(BUILD)/splash.bin@0x2000 \
	    $(TPRG)@0x$$(awk '$$3 == ".start" {print $$2}' $(TLABELS)) \
	    $(foreach n,$(STAGE_NUMS),$(BUILD)/stages/s$(n).bin@0x$$(awk '$$3 == ".st_file" {print $$2}' $(TLABELS)),$(patsubst 0%,%,$(n))) \
	    $(BUILD)/endscr.prg $(BUILD)/endbmp.prg

$(BUILD)/endscr.prg $(BUILD)/endbmp.prg $(BUILD)/splash.bin: $(STAMP)

run: $(D64)
	$(X64) -autostart $(D64)

run-tape: $(TAP)
	$(X64) -autostart $(TAP)

debug:
	$(MAKE) TASSDEFS="-D DEBUG=9" all

test: $(D64)
	$(PYTHON) tests/run_tests.py

shots: $(D64)
	$(PYTHON) tools/screenshots64.py

manuals:
	$(PYTHON) tools/make_manual.py

clean:
	rm -rf $(BUILD) src/data
