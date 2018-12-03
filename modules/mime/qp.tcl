#! /usr/bin/env tclsh

# ::mime::qp::encode --
#
#    Tcl version of quote-printable encode
#
# Arguments:
#    string        The string to quote.
#       encoded_word  Boolean value to determine whether or not encoded words
#                     (RFC 2047) should be handled or not. (optional)
#
# Results:
#    The properly quoted string is returned.


namespace eval ::mime::qp {
    namespace ensemble create
    namespace export decode encode
}

proc ::mime::qp::encode {string {encoded_word 0} {no_softbreak 0}} {
    # 8.1+ improved string manipulation routines used.
    # Replace outlying characters, characters that would normally
    # be munged by EBCDIC gateways, and special Tcl characters "[\]{}
    # with =xx sequence

    if {$encoded_word} {
        # Special processing for encoded words (RFC 2047)
        set regexp {[\x00-\x08\x0B-\x1E\x21-\x24\x3D\x40\x5B-\x5E\x60\x7B-\xFF\x09\x5F\x3F]}
	lappend mapChars { } _
    } else {
        set regexp {[\x00-\x08\x0B-\x1E\x21-\x24\x3D\x40\x5B-\x5E\x60\x7B-\xFF]}
    }
    regsub -all -- $regexp $string {[format =%02X [scan "\\&" %c]]} string

    # Replace the format commands with their result

    set string [subst -novariables $string]

    # soft/hard newlines and other
    # Funky cases for SMTP compatibility
    lappend mapChars " \n" =20\n \t\n =09\n \n\.\n =2E\n "\nFrom " "\n=46rom "

    set string [string map $mapChars $string]

    # Break long lines - ugh

    # Implementation of FR #503336
    if {$no_softbreak} {
        set result $string
    } else {
        set result {}
        foreach line [split $string \n] {
            while {[string length $line] > 72} {
                set chunk [string range $line 0 72]
                if {[regexp -- (=|=.)$ $chunk dummy end]} {

                    # Don't break in the middle of a code

                    set len [expr {72 - [string length $end]}]
                    set chunk [string range $line 0 $len]
                    incr len
                    set line [string range $line $len end]
                } else {
                    set line [string range $line 73 end]
                }
                append result $chunk=\n
            }
            append result $line\n
        }

        # Trim off last \n, since the above code has the side-effect
        # of adding an extra \n to the encoded string and return the
        # result.
        set result [string range $result 0 end-1]
    }

    # If the string ends in space or tab, replace with =xx

    set lastChar [string index $result end]
    if {$lastChar eq { }} {
        set result [string replace $result end end =20]
    } elseif {$lastChar eq "\t"} {
        set result [string replace $result end end =09]
    }

    return $result
}


# ::mime::qp_decode --
#
#    Tcl version of quote-printable decode
#
# Arguments:
#    string        The quoted-printable string to decode.
#    encoded_word  Boolean value to determine whether or not encoded words
#                     (RFC 2047) should be handled or not. (optional)
#
# Results:
#    The decoded string is returned.

proc ::mime::qp::decode {string {encoded_word 0}} {
    # 8.1+ improved string manipulation routines used.
    # Special processing for encoded words (RFC 2047)

    if {$encoded_word} {
        # _ == \x20, even if SPACE occupies a different code position
        set string [string map [list _ \u0020] $string]
    }

    # smash the white-space at the ends of lines since that must've been
    # generated by an MUA.

    regsub -all -- {[ \t]+\n} $string \n string
    set string [string trimright $string " \t"]

    # Protect the backslash for later subst and
    # smash soft newlines, has to occur after white-space smash
    # and any encoded word modification.

    #TODO: codepath not tested
    set string [string map [list \\ {\\} =\n {}] $string]

    # Decode specials

    regsub -all -nocase {=([a-f0-9][a-f0-9])} $string {\\u00\1} string

    # process \u unicode mapped chars

    return [subst -novariables -nocommands $string]
}


package provide {mime qp} 1.7