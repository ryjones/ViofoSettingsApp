# Build chain for the VIOFO Settings app.
#
#   make            build and test
#   make app        wrap the binary in ViofoConfig.app
#   make dist       zip the app for distribution
#   make schema     re-check the schema against the firmware fixture
#   make catalog    rebuild the command catalogue from the firmware map
#   make clean

PKG     := ViofoConfig
CONFIG  ?= release
APP     := $(PKG)/$(PKG).app
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
API_MAP ?= $(HOME)/W/ViofoFirmwareThingy/api-map.json

.PHONY: all build test app dist schema catalog clean fmt

all: build test

build:
	swift build --package-path $(PKG) -c $(CONFIG)

test:
	swift test --package-path $(PKG)

app:
	$(PKG)/build-app.sh $(CONFIG)

dist: app
	cd $(PKG) && ditto -c -k --sequesterRsrc --keepParent $(PKG).app $(PKG)-$(VERSION).zip
	@echo "wrote $(PKG)/$(PKG)-$(VERSION).zip"

# The schema is checked against ground truth extracted from the camera firmware.
# See docs/camera-http-api.md and Tests/ViofoConfigTests/Fixtures/README.md.
schema:
	swift test --package-path $(PKG) --filter FirmwareSchemaTests

# The command set comes from cardv's HTTP dispatch table, by way of api-map.json
# in the firmware project. Option labels are merged in from the catalogue already
# in the tree -- they come from VIOFO's app database, which is not redistributed.
catalog:
	tools/gen-camera-commands.py $(API_MAP)

clean:
	rm -rf $(PKG)/.build $(APP) $(PKG)/*.zip
