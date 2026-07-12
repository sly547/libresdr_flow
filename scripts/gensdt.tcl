# This is for Vivado 2024.2 where sdtgen cannot include multiple .dtsi files
# with "-user_dts foo.dtsi bar.dtsi".
#
# cd dts
# cat libre-board.dtsi libre-pl.dtsi libre-config.dtsi > libre.dtsi
#
# Run like this from a terminal with Vivado sourced:
#
# xsct scripts/gensdt.tcl

sdtgen set_dt_param -xsa build/system_top.xsa -dir build/sdt_out -include_dts dts/libre.dtsi -debug enable
sdtgen generate_sdt
