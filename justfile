# Copyright (c) 2026 Michael Büchler
# SPDX-License-Identifier: MIT

set shell := ["bash", "-c"]

vivado_path := "/mnt/ssd/tools/Xilinx/2025.2/Vivado/settings64.sh"

build-hdl:
    #!/usr/bin/env bash
    echo "building HDL"
    source {{vivado_path}}
    export ADI_IGNORE_VERSION_CHECK=1
    make -C hdl/projects/libre
    mkdir -p build
    cp hdl/projects/libre/libre.sdk/system_top.xsa build/

stage-manual-xsa:
    cp hdl/projects/libre/system_top.xsa build/

build-fsbl:
    #!/usr/bin/env bash
    echo "building FSBL"
    rm -rf build/sdk
    source {{vivado_path}}
    xsct scripts/create_fsbl_project.tcl

build-sdt:
    #!/usr/bin/env bash
    echo "building system device tree (SDT)"
    source {{vivado_path}}
    mkdir -p build/sdt_out
    sdtgen -xsa build/system_top.xsa \
        -dir build/sdt_out \
        -user_dts dts/libre-board.dtsi dts/libre-pl.dtsi dts/libre-config.dtsi \
        -debug enable

build-dts: build-sdt
    #!/usr/bin/env bash
    echo "building device tree for Linux and U-Boot"
    mkdir -p build/lopper_out
    source venv_lopper/bin/activate
    LOPPER_DTC_FLAGS="-b 0 -@" lopper -f -v --enhanced \
        -O ./build/lopper_out/ \
        ./build/sdt_out/system-top.dts \
        zynq-libre.dts -- \
        gen_domain_dts ps7_cortexa9_0 linux_dt
    cp build/lopper_out/zynq-libre.dts br2-external/board/tezuka/libre/dts/zynq-libre.dts

stage-artifacts:
    @echo "copying hardware artifacts into br2-external"
    cp build/system_top.xsa br2-external/board/tezuka/libre/bitstream/
    cp build/sdk/fsbl/Release/fsbl.elf br2-external/board/tezuka/libre/bitstream/
    cp build/lopper_out/zynq-libre.dts br2-external/board/tezuka/libre/dts/
    cp build/sdt_out/ps7_init_gpl.c br2-external/board/tezuka/libre/
    cp build/sdt_out/ps7_init_gpl.h br2-external/board/tezuka/libre/

build-buildroot:
    @echo "building the system with buildroot"
    make -C br2-external/buildroot board-fpga-rebuild uboot-rebuild linux-rebuild
    make -C br2-external/buildroot

deploy-lan:
    rsync -rv -e 'ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null' ./br2-external/buildroot/output/images/sdimg/ root@libresdr.local:/boot/

gui:
    #!/usr/bin/env bash
    echo "opening Vivado"
    source {{vivado_path}}
    vivado hdl/projects/libre/libre.xpr

clean:
    make -C hdl/projects/libre clean-all
    rm build/ -rf
    make -C br2-external/buildroot distclean
