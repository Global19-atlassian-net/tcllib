if {![package vsatisfies [package provide Tcl] 8.2]} {
    # FRINK: nocheck
    return
}
package ifneeded uri      1.1.3 [list source [file join $dir uri.tcl]]
package ifneeded uri::urn 1.0.1 [list source [file join $dir urn-scheme.tcl]]
