## Introduction

Why this repo? I wanted to have the complete build flow understood and under control. tezuka_fw is nice for the enhancements and features it provides over the PlutoSDR code from Analog Devices Inc. (ADI), but I don't actually need those features and they are in my way (example: some background script in Linux for push-to-talk functionality kept disabling my Tx LO and I was pulling my hair out before I found the culprit).
What I need is a developer-friendly platform for experimentation and exploration, so I tried to combine the best of both worlds.Maybe others find it useful, too.

Side note: as of writing this I forgot some details, but I think ADI's buildroot build flow is also undergoing some changes at the moment (analogdevicesinc/plutosdr-fw vs. analogdevicesinc/br2-external). This one is based on the latter.

One major motivation was to use the relatively new "SHEL flow" that AMD/Xilinx introduced for generating a device tree, rather than dealing with hand-written DTS files, and getting rid of generated code (like ps7_init_gpl.c).

## features added

- an AXI SPI core talks to the TI DAC7311 that can be used to tune the VCTCXO
- an AXI IIC core could talk to the AD7291 8 channel ADC (but it's unpopulated on my board) and the AT24C02D (untested)

## tezuka features removed

Incomplete list:

- only the "libre" board (LibreSDR/ZynqSDR) is supported
- no ifplugd script [/etc/ifplugd/ifplugd.action](https://github.com/F5OEO/tezuka_fw/blob/main/board/tezuka/common/overlay_tezuka/etc/ifplugd/ifplugd.action`)
    - udhcpc is only started (by busybox?) when `eth0` is plugged in during boot
- MAC address from hardcoded '00:60:88' + processed SHA-1 of `$SERIAL` in `/etc/init.d/S40network`
    - configured in `/etc/network/interfaces`
    - introduced [here](https://github.com/F5OEO/tezuka_fw/pull/21)
    - now it uses the default MAC address for the Zynq's Ethernet MAC (00 0a 35 00 01 22)
    - maybe replace with `set ethaddr AA BB CC DD EE FF` in U-boot (try `saveenv`)

## adding custom IP to the HDL project

Setting the `ip_repo_paths` variable and creating the block design happens in one single Tcl process `adi_project_create` (so no customization here), but it then calls the project's `system_bd.tcl`, which allows customization. Add a custom repo here.

## Build

Please have a look at the `justfile` as this section might be outdated.

To deploy, copy the files from `./br2-external/buildroot/output/images/sdimg/` to the SD card. With Ethernet see `just deploy-lan`.

### building the bitstream

```sh
cd hdl/projects/libre
export ADI_IGNORE_VERSION_CHECK=1
. /opt/tools/Xilinx/2025.2/Vivado/settings64.sh
make
```

The justfile command `build-hdl` automates this and copies the .xsa file from `hdl/projects/libre/libre.sdk/system_top.xsa` into `build/`. When a manual implementation and bitstream generation was done in Vivado, the `stage-manual-xsa` step is available to copy it from `hdl/projects/libre/system_top.xsa` instead (the default location for "Export hardware").

Then later, the `stage-artifacts` step in the just file copies it to `br2-external/board/tezuka/libre/bitstream/`.

### FSBL

```sh
xsct scripts/create_fsbl_project.tcl
```

This also extracts the .xsa archive into `build/`, cluttering the folder with files.

```sh
cp build/sdk/fsbl/Release/fsbl.elf br2-external/board/tezuka/libre/bitstream/
```

There it is found by `board/tezuka/common/prepost-image.sh`.

This is automated in the justfile by `build-fsbl` and `stage-artifacts`.

### device tree

#### SDTGen - Vivado 2024.2

SDTGen is weird here - this version must be called with XSCT and then as part of a Tcl script. To be fair, this is documented in the [v2024.2 README](https://github.com/Xilinx/system-device-tree-xlnx/blob/xlnx_rel_v2024.2/README.md).

```sh
source /path/to/Vivado/2024.2/settings64.sh
xsct scripts/gensdt.tcl
```

#### SDTGen - Vivado 2025.2

In this version, the tool can be called directly.

```sh
source /path/to/2025.2/Vivado/settings64.sh
sdtgen -xsa build/system_top.xsa -dir build/sdt_out -user_dts dts/libre-board.dtsi dts/libre-pl.dtsi dts/libre-config.dtsi -debug enable
```

#### lopper

The output of `sdtgen` is reduced to a single system.dts file by `lopper`. Creating a Python venv for this tool is advised.

The libfdt situation might require a closer look.

```sh
source venv_lopper/bin/activate
pip install lopper[server,yaml,dt,pcpp]
pip install pylibfdt
```

To run it (the `-v` adds verbose output and can be omitted):

```sh
LOPPER_DTC_FLAGS="-b 0 -@" lopper -f -v --enhanced -O ./build/lopper_out/ ./build/sdt_out/system-top.dts zynq-libre.dts -- gen_domain_dts ps7_cortexa9_0 linux_dt
```

The internal dtc run needs the `-@` or `--syombols` flag to generate `__symbols__`, without which the `gen_domain_dts` assist fails.

The output must be copied to `br2-external/board/tezuka/libre/dts/zynq-libre.dts`.

### bitstream

current solution: buildroot package `board-fpga` from tezuka_fw extracts and copies `system_top.bit` to `buildroot/output/images/`.

To rebuild with a new XSA file:

```sh
just stage-manual-xsa
just build-dts
just stage-artifacts

# update buildroot
just build-buildroot

# copy to target
just deploy-lan
```

## Issues

Vivado 2025.2 has some trouble with bootgen, and buildroot might fail. I solve it locally by changing the script to use `BOOTGEN="/tools/Xilinx/Vitis/2024.2/bin/bootgen"`.

## TODO

- [ ] introduce the components of the build flow, make a nice diagram
- [ ] understand and improve U-Boot env
