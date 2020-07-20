# NORMAL MODE: inserts diode cells
# OPTIMIZED MODE: inserts a fake diode, to be replaced later with a real diode if necessary

set input_def $::env(CURRENT_DEF)
set input_lef $::env(MERGED_LEF_UNPADDED)
set output_def $::env(SAVE_DEF)

read_lef $input_lef
read_def $input_def

set ::PREFIX ANTENNA
set ::VERBOSE 0
set ::block [[[::ord::get_db] getChip] getBlock]
set ::antenna_pin_name $::env(DIODE_CELL_PIN)
set ::nets [$::block getNets]

if { $::env(DIODE_INSERTION_STRATEGY) == 2 && [info exists ::env(FAKEDIODE_CELL)]} {
	set ::antenna_cell_name $::env(FAKEDIODE_CELL)
} else {
	set ::antenna_cell_name $::env(DIODE_CELL)
}

proc add_antenna_cell { iterm } {
	set antenna_master [[::ord::get_db] findMaster $::antenna_cell_name]
	set antenna_mterm [$antenna_master getMTerms]

	set iterm_net [$iterm getNet]
	set iterm_inst [$iterm getInst]
	set iterm_inst_name [$iterm_inst getName]
	set iterm_pin_name [[$iterm getMTerm] getConstName]


	set inst_loc [$iterm_inst getLocation]
	set inst_loc_x [lindex [$iterm_inst getLocation] 0]
	set inst_loc_y [lindex [$iterm_inst getLocation] 1]
	set inst_ori [$iterm_inst getOrient]

	set antenna_inst_name ${::PREFIX}_${iterm_inst_name}_${iterm_pin_name}
	# create a 2-node "subnet" for the antenna (for easy removal) -> doesn't work
	# set antenna_subnet [odb::dbNet_create $::block NET_${antenna_inst_name}]
	set antenna_inst [odb::dbInst_create $::block $antenna_master $antenna_inst_name]
	set antenna_iterm [$antenna_inst findITerm $::antenna_pin_name]

	$antenna_inst setLocation $inst_loc_x $inst_loc_y
	$antenna_inst setOrient $inst_ori
	$antenna_inst setPlacementStatus PLACED
	odb::dbITerm_connect $antenna_iterm $iterm_net
	# odb::dbITerm_connect $iterm $antenna_subnet
	# odb::dbITerm_connect $iterm $iterm_net
	#
	if { $::VERBOSE } {
		puts "\[INFO\]: Adding $antenna_inst_name on subnet $antenna_subnet for cell $iterm_inst_name pin $iterm_pin_name"
	}
}

set count 0
puts "\[INFO\]: Inserting $::antenna_cell_name..."
foreach net $::nets {
	set net_name [$net getName]
	if { [expr {$net_name eq $::env(VDD_PIN)} || {$net_name eq $::env(GND_PIN)}] } {
		puts "\[WARN\]: Skipping $net_name"
	} else {
		set iterms [$net getITerms]
		foreach iterm $iterms {
			if { [$iterm isInputSignal] } {
				add_antenna_cell $iterm
				set count [expr $count + 1]
			}
		}
	}
}
puts "\n\[INFO\]: $count of $::antenna_cell_name inserted!"
set_placement_padding -global -left $::env(DIODE_PADDING)
puts "\[INFO\]: Legalizing..."
detailed_placement
if { [check_placement -verbose] } {
	exit 1
}
write_def $::env(SAVE_DEF)
write_verilog $::env(yosys_result_file_tag)_diodes.v