## tezuka features removed

- no ifplugd script [/etc/ifplugd/ifplugd.action](https://github.com/F5OEO/tezuka_fw/blob/main/board/tezuka/common/overlay_tezuka/etc/ifplugd/ifplugd.action`)
    - udhcpc is only started (by busybox?) when `eth0` is plugged in during boot
- MAC address from hardcoded '00:60:88' + processed SHA-1 of `$SERIAL` in `/etc/init.d/S40network`
    - configured in `/etc/network/interfaces`
    - introduced [here](https://github.com/F5OEO/tezuka_fw/pull/21)
    - otherwise it uses the default MAC address for the Zynq's Ethernet MAC (00 0a 35 00 01 22)
    - maybe replace with `set ethaddr AA BB CC DD EE FF` in U-boot (try `saveenv`)

## adding custom IP to the HDL project

Don't fight adi-hdl's build scripts too much. Setting the `ip_repo_paths` variable and creating the block design happens in one single Tcl process `adi_project_create`, but it then calls the project's `system_bd.tcl`, which allows customization. The only annoyance is that the BD has to be closed before `update_ip_catalog` can be called.

## building the bitstream

```sh
cd hdl/projects/libre
export ADI_IGNORE_VERSION_CHECK=1
. /opt/tools/Xilinx/2025.2/Vivado/settings64.sh
make
```

I take the .xsa file from `hdl/projects/libre/libre.sdk/system_top.xsa` and put it into `build/` and `br2-external/board/tezuka/libre/bitstream/`.

## FSBL

```sh
xsct scripts/create_fsbl_project.tcl
```

This also extracts the .xsa archive into `build/`, cluttering the folder with files.

```sh
cp build/sdk/fsbl/Release/fsbl.elf br2-external/board/tezuka/libre/bitstream/
```

There it is found by `board/tezuka/common/prepost-image.sh`.

## device tree

### SDTGen - Vivado 2024.2

SDTGen is weird here - this version must be called with XSCT and then as part of a Tcl script. To be fair, this is documented in the [v2024.2 README](https://github.com/Xilinx/system-device-tree-xlnx/blob/xlnx_rel_v2024.2/README.md).

```sh
source /path/to/Vivado/2024.2/settings64.sh
xsct scripts/gensdt.tcl
```

### SDTGen - Vivado 2025.2

In this version, the tool can be called directly.

```sh
source /path/to/2025.2/Vivado/settings64.sh
sdtgen -xsa build/system_top.xsa -dir build/sdt_out -user_dts dts/libre-board.dtsi dts/libre-pl.dtsi dts/libre-config.dtsi -debug enable
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
LOPPER_DTC_FLAGS="-b 0 -@" lopper -f -v --enhanced -O ./build/lopper_out/ ./build/sdt_out/system-top.dts zynq-libre.dts -- gen_domain_dts ps7_cortexa9_0 linux_dt
```

The internal dtc run needs the `-@` or `--syombols` flag to generate `__symbols__`, without which the `gen_domain_dts` assist fails.

The output must be copied to `br2-external/board/tezuka/libre/dts/zynq-libre.dts`.

## bitstream

current solution: buildroot package `board-fpga` from tezuka_fw extracts and copies `system_top.bit` to `buildroot/output/images/`.

To rebuild with a new XSA file:

```sh
just stage-manual-xsa
just build-dts
just stage-artifacts

# update buildroot
make -C br2-external/buildroot board-fpga-rebuild uboot-rebuild linux-rebuild && make -C br2-external/buildroot

# copy to target
rsync -rv -e 'ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null' ./br2-external/buildroot/output/images/sdimg/ root@libresdr.local:/boot/
```
