# Connect IQ watch app build. SDK path is read from the SDK manager config.
SDK     := $(shell cat "$(HOME)/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg")
KEY     ?= $(HOME)/.connectiq/developer_key.der
DEVICE  ?= fenix6
PRODUCTS := fenix6 fenix6pro fenix6s fenix6spro fenix6xpro
NAME    := GarminClicker
SRC     := $(shell find source test resources resources-rus -type f) manifest.xml monkey.jungle test.jungle
MONKEYC := "$(SDK)/bin/monkeyc"

.PHONY: build build-all test sim clean

build: bin/$(NAME).prg

bin/$(NAME).prg: $(SRC)
	@mkdir -p bin
	$(MONKEYC) -f monkey.jungle -d $(DEVICE) -o $@ -y "$(KEY)" -w

build-all:
	@for d in $(PRODUCTS); do \
		mkdir -p bin/$$d; \
		$(MONKEYC) -f monkey.jungle -d $$d -o bin/$$d/$(NAME).prg -y "$(KEY)" -w || exit 1; \
	done

# Unit-test build, run in the simulator; fails if any test fails.
test:
	@mkdir -p bin
	$(MONKEYC) -f "monkey.jungle;test.jungle" -d $(DEVICE) -o bin/test.prg -y "$(KEY)" -w -t
	@SDK="$(SDK)" DEVICE="$(DEVICE)" sh scripts/run-tests.sh

sim: bin/$(NAME).prg
	@SDK="$(SDK)" sh scripts/ensure-sim.sh
	"$(SDK)/bin/monkeydo" bin/$(NAME).prg $(DEVICE)

clean:
	rm -rf bin
