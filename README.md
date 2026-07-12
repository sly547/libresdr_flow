## building the bitstream

```sh
cd hdl/projects/libre
export ADI something ingnore the vivado version=1
. /opt/tools/Xilinx/Vivado/2024.2/settings64.sh
make
```

I take the .xsa file from `hdl/projects/libre/libre.sdk/system_top.xsa` and put it into a folder in `br2_external`.
I take the .xsa file from `hdl/projects/libre/libre.sdk/system_top.xsa` and put it into `build/`

## FSBL

```sh
xsct scripts/create_fsbl_project.tcl
```

This creates a bunch of files that buildroot needs.

```sh
cp build/sdk/fsbl/Release/fsbl.elf br2-external/board/tezuka/libre/bitstream/
```

There it is found by `board/tezuka/common/prepost-image.sh`.

## device tree

### SDTGen - Vivado 2024.2

SDTGen is weird here - this version must be called with XSCT and then as part of a Tcl script. To be fair, this is documented in the [v2024.2 README](https://github.com/Xilinx/system-device-tree-xlnx/blob/xlnx_rel_v2024.2/README.md).

```sh
source /path/to/2024.2/Vivado/settings64.sh
xsct scripts/gensdt.tcl
```

### SDTGen - Vivado 2025.2

```sh
source /path/to/2025.2/Vivado/settings64.sh
sdtgen -xsa build/system_top.xsa -dir build/sdt_out_2025.2 -user_dts dts/libre-board.dtsi dts/libre-pl.dtsi dts/libre-config.dtsi -debug enable
```

### lopper

The output of `sdtgen` is reduced to a single system.dts file by `lopper`. Creating a Python venv for this tool is advised.

The libfdt situation might require a closer look.

```sh
source venv_lopper/bin/activate
pip install lopper[server,yaml,dt,pcpp]
pip install pylibfdt
```

To run it (the `-v` adds verbose output and can be omitted):

```sh
LOPPER_DTC_FLAGS="-b 0 -@" lopper -f -v --enhanced -O ./build/lopper_out_2025.2/ ./build/sdt_out_2025.2/system-top.dts zynq-libre.dts -- gen_domain_dts ps7_cortexa9_0 linux_dt
```

The internal dtc run needs the `-@` or `--syombols` flag to generate `__symbols__`, without which the `gen_domain_dts` assist fails.

The output must be copied to `br2-external/board/tezuka/libre/dts/zynq-libre.dts`.

## bitstream

current solution: buildroot package `board-fpga` from tezuka_fw extracts and copies `system_top.bit` to `buildroot/output/images/`.
