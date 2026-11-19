AS := vasm
ASFLAGS := -Fvobj -quiet

LD := vlink
LDFLAGS := -T scripts/bhmth.ld -b rawbin2

PNG2BIN := png2bin
BPP := 4

SRC_DIR := src
ASSET_DIR := assets
BUILD_DIR := build
BIN_DIR := bin

TARGET := $(BIN_DIR)/minesweeper.bhm

ASM_SRCS := $(wildcard $(SRC_DIR)/*.asm)
PNG_SRCS := $(wildcard $(ASSET_DIR)/*.png)

ASSET_BINS := $(patsubst $(ASSET_DIR)/%.png, $(BUILD_DIR)/assets/%.bin, $(PNG_SRCS))
ASSET_PALS := $(patsubst $(ASSET_DIR)/%.png, $(BUILD_DIR)/assets/%.pal, $(PNG_SRCS))
OBJS := $(patsubst $(SRC_DIR)/%.asm, $(BUILD_DIR)/obj/%.o, $(ASM_SRCS))

.PHONY: all clean run

all: $(TARGET)

$(TARGET): $(OBJS) | $(BIN_DIR)
	@echo "Linking binary: $@"
	$(LD) $(LDFLAGS) -o $@ $(OBJS)
	@stat $(TARGET) --printf="Final ROM size: %s bytes\n"

$(BUILD_DIR)/obj/%.o: $(SRC_DIR)/%.asm $(ASSET_BINS) $(ASSET_PALS) | $(BUILD_DIR)/obj
	@echo "Assembling: $< -> $@"
	$(AS) $(ASFLAGS) -o $@ $<

$(BUILD_DIR)/assets/%.bin $(BUILD_DIR)/assets/%.pal &: $(ASSET_DIR)/%.png | $(BUILD_DIR)/assets
	@echo "Converting asset and generating palette: $<"
	$(PNG2BIN) $< --bpp $(BPP) -o $(BUILD_DIR)/assets/$*.bin --out-pal $(BUILD_DIR)/assets/$*.pal

$(BUILD_DIR)/obj $(BUILD_DIR)/assets $(BIN_DIR):
	mkdir -p $@

clean:
	rm -rf $(BUILD_DIR) $(BIN_DIR)

run:
	@behemoth $(TARGET)
