.PHONY: all build run clean test

RUST_LIB     = driver/target/release/libargos_driver.a
SWIFT_FLAGS  = -Xlinker -L$(PWD)/driver/target/release \
               -Xlinker -largos_driver \
               -Xlinker -framework -Xlinker IOKit \
               -Xlinker -framework -Xlinker CoreFoundation

all: build

## Build Rust driver then Swift app
build: $(RUST_LIB)
	swift build $(SWIFT_FLAGS)

## Build release binary
release: $(RUST_LIB)
	swift build -c release $(SWIFT_FLAGS)

## Build and run
run: build
	.build/debug/Argos

## Build Rust driver only
$(RUST_LIB):
	cd driver && ~/.cargo/bin/cargo build --release

## Run Rust tests (glasses must be connected)
test:
	cd driver && ~/.cargo/bin/cargo test -- --nocapture --test-threads=1

clean:
	swift package clean
	cd driver && ~/.cargo/bin/cargo clean
