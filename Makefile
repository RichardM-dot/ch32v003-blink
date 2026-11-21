# Makefile — ch32v003-blink（CH32V003F4P6 / RV32EC，中文注释）
TOOLCHAIN := /Users/theo-richard/workspace/toolchains/riscv-none-elf/bin/riscv-none-elf-
CC      := $(TOOLCHAIN)gcc
AS      := $(TOOLCHAIN)gcc -x assembler-with-cpp
OBJCOPY := $(TOOLCHAIN)objcopy
OBJDUMP := $(TOOLCHAIN)objdump
NM      := $(TOOLCHAIN)nm
SIZE    := $(TOOLCHAIN)size
READELF := $(TOOLCHAIN)readelf

TARGET  := ch32v003-blink
BUILD   := build

# CH32V003 是 RV32EC，无硬件乘除；zicsr/zifencei 供 core_riscv.h 的 CSR 指令使用。
# 注意：库文件按 rv32ec/ilp32e 编译，链接时显式指定该 multilib 的 libgcc。
CPU     := -march=rv32ec_zicsr_zifencei -mabi=ilp32e
DEFS    := -DCH32V003 $(EXTRA_DEFS)
INC     := -ICore/Inc \
           -IDrivers/CH32V00x_Peripheral/Inc \
           -IDrivers/Core \
           -IDrivers/Debug \
           -IBSP

CFLAGS  := $(CPU) $(DEFS) $(INC) -Os -g -Wall -ffunction-sections -fdata-sections -fno-common
ASFLAGS := $(CPU) $(DEFS) $(INC) -g
LIBGCC_DIR := $(shell $(CC) -march=rv32ec -mabi=ilp32e -print-libgcc-file-name | xargs dirname)
LDFLAGS := $(CPU) -TCH32V003_FLASH.ld -nostdlib -Wl,--gc-sections \
           -Wl,-Map=$(BUILD)/$(TARGET).map -L$(LIBGCC_DIR) -lgcc

C_SOURCES := $(wildcard Core/Src/*.c) \
             $(wildcard Drivers/CH32V00x_Peripheral/Src/*.c) \
             $(wildcard Drivers/Core/*.c) \
             $(wildcard Drivers/Debug/*.c) \
             $(wildcard BSP/*.c)
ASM_SOURCES := startup_ch32v00x.S

OBJECTS := $(addprefix $(BUILD)/,$(notdir $(C_SOURCES:.c=.o)))
OBJECTS += $(addprefix $(BUILD)/,$(notdir $(ASM_SOURCES:.S=.o)))
vpath %.c $(sort $(dir $(C_SOURCES)))
vpath %.S $(sort $(dir $(ASM_SOURCES)))

all: $(BUILD)/$(TARGET).elf $(BUILD)/$(TARGET).hex $(BUILD)/$(TARGET).bin
$(BUILD)/%.o: %.c | $(BUILD)
	$(CC) -c $(CFLAGS) $< -o $@
$(BUILD)/%.o: %.S | $(BUILD)
	$(AS) -c $(ASFLAGS) $< -o $@
$(BUILD)/$(TARGET).elf: $(OBJECTS) | $(BUILD)
	$(CC) $(OBJECTS) $(LDFLAGS) -o $@
$(BUILD)/%.hex: $(BUILD)/%.elf
	$(OBJCOPY) -O ihex $< $@
$(BUILD)/%.bin: $(BUILD)/%.elf
	$(OBJCOPY) -O binary -S $< $@
$(BUILD):
	mkdir -p $@

dis: $(BUILD)/$(TARGET).elf
	$(OBJDUMP) -d $< > $(BUILD)/$(TARGET).dis
symbols: $(BUILD)/$(TARGET).elf
	$(NM) -S --size-sort $< > $(BUILD)/$(TARGET).sym
size: $(BUILD)/$(TARGET).elf
	$(SIZE) $<
	$(READELF) -l $< | grep -E "LOAD|Entry"

# 需要 WCH-LinkE + minichlink；minichlink 未安装时不要执行
MINICHLINK ?= minichlink
flash: $(BUILD)/$(TARGET).bin
	$(MINICHLINK) -w $< 0x08000000

clean:
	rm -rf $(BUILD)
.PHONY: all dis symbols size flash clean
