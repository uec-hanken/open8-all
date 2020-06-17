# This line accommodates script automation
# foreach { flow project revision } $quartus(args) { break }
set project open8_II
set file_name ${project}.qpf
set done 0
set revision_number ""

    if { $tcl_platform(os) == "Linux" } {
      post_message -type critical_warning "Unable to compile app.s under Linux - make sure app.hex has been updated!"
    } else {
      set cmd "software/make.bat"

      if { [catch {open "|$cmd"} input] } {
        return -code error $input
      } else {
        post_message "Compiled app.s"
      }
    }