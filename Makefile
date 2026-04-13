.PHONY: all build app sign run clean test

RUST_LIB     = driver/target/release/libargos_driver.a
SWIFT_FLAGS  = -Xlinker -L$(PWD)/driver/target/release \
               -Xlinker -largos_driver \
               -Xlinker -framework -Xlinker IOKit \
               -Xlinker -framework -Xlinker CoreFoundation

SIGN_ID      = "Apple Development: apple@grahamveitch.com (6TQVS3337G)"
ENTITLEMENTS = $(PWD)/Argos.entitlements
BINARY       = .build/debug/Argos
APP_BUNDLE   = Argos.app

all: build

## Build Rust driver + Swift binary + .app bundle + sign
build: $(RUST_LIB)
	swift build $(SWIFT_FLAGS)
	$(MAKE) app

## Assemble Argos.app bundle and sign it
app:
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	cp $(BINARY) $(APP_BUNDLE)/Contents/MacOS/Argos
	cp Sources/Argos/Info.plist $(APP_BUNDLE)/Contents/Info.plist
	codesign --force --sign $(SIGN_ID) \
	         --entitlements $(ENTITLEMENTS) \
	         $(APP_BUNDLE)
	@echo "[build] Argos.app ready"

## Sign the raw binary only (for quick iteration)
sign:
	codesign --force --sign $(SIGN_ID) \
	         --entitlements $(ENTITLEMENTS) \
	         $(BINARY)

## Build and open the .app
run: build
	open $(APP_BUNDLE)

## Build Rust driver only
$(RUST_LIB):
	cd driver && ~/.cargo/bin/cargo build --release

## Run Rust tests (glasses must be connected)
test:
	cd driver && ~/.cargo/bin/cargo test -- --nocapture --test-threads=1

clean:
	swift package clean
	rm -rf $(APP_BUNDLE)
	cd driver && ~/.cargo/bin/cargo clean
