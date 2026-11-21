# ch32v003-blink — 最小工程（CH32V003F4P6）

CH32V003F4P6（RISC-V RV32EC，16K Flash / 2K RAM）的 **裸机最小工程**：
PD0 以 500 ms 周期翻转。使用 **Makefile + 本地 RISC-V GCC** 构建，
不依赖 MounRiver Studio / IDE。库文件来自 WCH 官方
[openwch/ch32v003](https://github.com/openwch/ch32v003) EVT，已 vendored 进本工程。

## 当前状态

| 项目 | 状态 |
| --- | --- |
| 编译 / 链接（elf/hex/bin） | **通过**，text 932 B + data 8 B，bss 260 B（含 256 B 栈） |
| 上板实测 | **尚未进行** |
| 编译器 | xPack GNU RISC-V Embedded GCC 15.2.0-1（darwin-arm64，原生） |

## 关键配置

| 项 | 值 |
| --- | --- |
| 芯片 | CH32V003F4P6（16K Flash / 2K RAM） |
| 内核 | QingKe V2A，RV32EC（`-march=rv32ec_zicsr_zifencei -mabi=ilp32e`） |
| 时钟 | HSI 24 MHz × PLL2 = **48 MHz** |
| LED | **PD0** 推挽输出，30 MHz，500 ms 翻转 |
| 库 | WCH CH32V00x 外设库（StdPeriph 风格）+ core_riscv + debug |
| 启动文件 | `startup_ch32v00x.S`（官方原版） |
| 链接脚本 | `CH32V003_FLASH.ld`（Flash 0x00000000 / 16K，RAM 0x20000000 / 2K，栈 256 B） |
| 编译宏 | `-DCH32V003` |
| 烧录 | WCH-LinkE + minichlink（`make flash`，工具需另行安装） |

## 文档

| 文件 | 内容 |
| --- | --- |
| `PIN_GUIDE.md` | **引脚定义 + 芯片资源详细指南**（基于官方数据手册 V1.8，含 TSSOP20/QFN20/SOP16/SOP8、复用/重映射、时钟、存储、电气参数、FAQ） |
| `Datasheet/CH32V003DS0.PDF` | WCH 官方 CH32V003 数据手册 V1.8（37 页） |

## 工程结构

```
ch32v003-blink/
├── Makefile                    # 全部构建目标
├── CH32V003_FLASH.ld           # 链接脚本（16K Flash / 2K SRAM）
├── startup_ch32v00x.S          # 启动文件（官方）
├── Core/
│   ├── Inc/                    # ch32v00x_conf.h / it.h / system_*.h
│   └── Src/                    # main.c（直接寄存器）、system_*.c、it.c
├── Drivers/
│   ├── CH32V00x_Peripheral/    # WCH 外设库 Inc/Src（vendored）
│   ├── Core/                   # core_riscv.c/h（CSR / NVIC）
│   └── Debug/                  # debug.c/h（Delay_Ms、SDI/UART printf）
├── BSP/                        # 板级驱动（当前为空，留给 OLED/传感器等）
└── build/
```

## 编译器安装位置

与 STM32 工程保持一致，工具链放在工作区本地，不改 PATH：

```
/Users/theo-richard/workspace/toolchains/riscv-none-elf/bin/riscv-none-elf-gcc
```

版本：xPack GNU RISC-V Embedded GCC **15.2.0-1 darwin-arm64**，
自带 `rv32ec/ilp32e` multilib（CH32V003 无硬件乘除，必须有配套 libgcc）。

## 构建 / 自检

```bash
cd /Users/theo-richard/workspace/projects/ch32/ch32v003-blink

make            # 产出 build/ch32v003-blink.{elf,hex,bin}
make size       # Flash/RAM 占用 + 段布局
make dis        # build/ch32v003-blink.dis（反汇编）
make symbols    # build/ch32v003-blink.sym（按体积排序符号表）
make clean
```

### 逆向自检

```bash
TOOL=/Users/theo-richard/workspace/toolchains/riscv-none-elf/bin/riscv-none-elf

# ① .bin 头 8 字节：RISC-V 是“跳转表”，不是 ARM 的 SP + Reset 向量
xxd -l 8 build/ch32v003-blink.bin
# 当前期望：6f00402f 00000000
# 0x2f40006f = `j handle_reset`；第 2 个字是 NMI 入口（当前未用，为 0）

# ② 入口与架构
${TOOL}-readelf -h build/ch32v003-blink.elf | grep -E "Entry|Machine"
# 期望：Entry point 0x0，Machine RISC-V

# ③ 关键符号
${TOOL}-nm -S --size-sort build/ch32v003-blink.elf | tail -12
```

当前固件尺寸：**text 932 B + data 8 B**，**bss 260 B**（含 256 B 栈），
`.bin` = **940 B**（Flash 16 KB，占用约 5.7%）。

## 烧录（WCH-LinkE + minichlink）

> minichlink **本次未安装**。需要时再装（它只有几十 KB，不是 1 GB 的 MRS 包）。

接线（CH32V003 使用单线 SDI 调试，SWIO = **PD1**）：

```
WCH-LinkE 3V3  -> 目标板 3V3
WCH-LinkE GND  -> 目标板 GND
WCH-LinkE SWDIO -> 目标板 SWIO (PD1)
```

安装并烧录（macOS，原生 arm64）：

```bash
brew install libusb pkg-config
git clone https://github.com/cnlohr/ch32fun.git
cd ch32fun/minichlink && make ARCH=arm64

# 回到本工程后：
make flash MINICHLINK=/path/to/minichlink
```

也可以直接：

```bash
/path/to/minichlink -w build/ch32v003-blink.bin 0x08000000
```

或使用官方 WCH EVT 中的 `.hex`（WCH-LinkUtility，仅 Windows）：
`build/ch32v003-blink.hex`。

## 与 WCH 官方工程的差异

| 项 | 官方 EVT | 本工程 |
| --- | --- | --- |
| 编译 | MounRiver Studio + WCH GCC | 本地 xPack GCC + Makefile |
| main.c | StdPeriph `GPIO_Init()` | 直接寄存器（对照 STM32 LL 写法） |
| 中断属性 | `WCH-Interrupt-fast` | 标准 `__attribute__((interrupt))`（上游 GCC 不支持私有属性） |
| 时钟 | 默认 HSE 48 MHz | HSI 24 MHz × PLL2 = 48 MHz（无需外部晶振） |
| 链接 | MRS 自动生成 | `CH32V003_FLASH.ld` + 显式 rv32ec libgcc |

> 说明：启动文件仍保留官方 HPE（硬件中断栈）配置；当前工程未开中断，
> 后续若要使用中断，建议先确认上游 GCC 的 interrupt prologue 与 HPE 的配合，
> 或把 `startup_ch32v00x.S` 中 `csrw 0x804, t0` 的 HPE 位关闭。

## 工具链 / 库来源

- 编译器：<https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases/tag/v15.2.0-1>
- 外设库：<https://github.com/openwch/ch32v003>（`EVT/EXAM/SRC`）
- 烧录工具：<https://github.com/cnlohr/ch32fun>（minichlink）
