cd   "D:/Program Files (x86)/eHiWay/eLinx3.0/bin/shell/bin"
set tclFile  "D:/Program Files (x86)/eHiWay/eLinx3.0/bin/shell/bin/run_bitgen.tcl"
set dir "D:/github_example/ov5640_hdmi_640x480"
set prj ov5640_hdmi_640x480
set topEntity ov5640_hdmi_top
set seriesName "eHiChip6"
set deviceName EQ6HL130
set packageName CSG484_H
set SynthName synth_1
set ImpleName imple_1
source $tclFile
run_bitgen $dir $prj $topEntity $seriesName $deviceName $packageName $SynthName $ImpleName
exit 0
