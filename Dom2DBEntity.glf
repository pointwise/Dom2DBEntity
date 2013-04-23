#
# Copyright 2011 (c) Pointwise, Inc.
# All rights reserved.
# 
# This sample script is not supported by Pointwise, Inc.
# It is provided freely for demonstration purposes only.  
# SEE THE WARRANTY DISCLAIMER AT THE BOTTOM OF THIS FILE.
#

package require PWI_Glyph 2.4

if {[llength [pw::Grid getAll -type pw::Domain]] == 0} {
  tk_messageBox -icon error -title "No domains" -message \
      "There are no domains defined." -type ok
  exit
}

pw::Script loadTk

# globals
set PreserveGrid 1
set Domains [list]


# get a fully-qualified temporary file name
proc getTempFileName { basename } {
  global tcl_platform env

  # Build up a list of possible directories to write to
  set dirs [pwd] 
  if {[info exists env(TEMP)]} {
    lappend dirs $env(TEMP)
  }
  if {[info exists env(TMP)]} {
    lappend dirs $env(TMP)
  }
  if {[info exists env(TMPDIR)]} {
    lappend dirs $env(TMPDIR)
  }
  if {[string equal $tcl_platform(platform) "windows"]} {
    if {[info exists env(USERPROFILE)]} {
      lappend dirs $env(USERPROFILE)
    }
  } else {
    lappend dirs "/tmp"
    lappend dirs "/usr/tmp"
  }
  if {[info exists env(HOME)]} {
    lappend dirs $env(HOME)
  }

  foreach dir $dirs {
    if {[file writable $dir] > 0} {
      set fname [file join $dir ${basename}.[pid]]
      if {[file exists $fname] == 0 || [file writable $fname] > 0} {
        return $fname
      }
    }
  }
  
  return $basename
}


# export domains to a neutral file format
proc export {fname type ents} {
  set exporter [pw::Application begin GridExport $ents]
  if [catch {
    $exporter initialize -type $type $fname
    if {![$exporter verify]} {
      error "Could not export entities"
    }
    $exporter write
    $exporter end
  } msg] {
    catch { $exporter abort }
    return -code error $msg
  }
}


# import database surfaces from neutral file format
proc import {fname type} {
  set importer [pw::Application begin DatabaseImport]
  if [catch {
    $importer initialize -type $type $fname
    $importer read
    $importer convert
    $importer end
  } msg] {
    catch { $importer abort }
    return -code error $msg
  }
}


# convert the selected domains by exporting to a neutral file format and
# importing back as database entities
proc convertToDBEntity { } {
  global Domains PreserveGrid
  set uns [list]
  set str [list]
  foreach ent $Domains {
    if [$ent isOfType pw::DomainStructured] {
      lappend str $ent
    } elseif [$ent isOfType pw::DomainUnstructured]  {
      lappend uns $ent
    }
  }

  set result 1

  set fname [getTempFileName "domains.grd"]
  set fileExists [file exists $fname]

  if [llength $uns] {
    if [catch {export $fname Nastran $uns} msg] {
      tk_messageBox -icon error -title "Error exporting file" \
          -message "Error exporting file:\n$msg" -type ok

      set result 0
    } elseif {[catch {import $fname Nastran} msg]} {
      tk_messageBox -icon error -title "Error importing file" \
          -message "Error importing file:\n$msg" -type ok
      set result 0
    }
  }

  if {$result && [llength $str]} {
    if [catch {export $fname PLOT3D $str} msg] {
      tk_messageBox -icon error -title "Error exporting file" \
          -message "Error exporting file:\n$msg" -type ok

      set result 0
    } elseif {[catch {import $fname PLOT3D} msg]} {
      tk_messageBox -icon error -title "Error importing file" \
          -message "Error importing file:\n$msg" -type ok
      set result 0
    }
  }

  if {0 == $fileExists} {
    catch {file delete -- $fname}
  }

  if $result {
    if { $PreserveGrid == 0 } {
      #Note: Blocks which depend on selected domains will be deleted as well
      foreach dom $selected {
        catch { $dom delete -force -connectors }
      }
    }
  } else {
    exit
  }
}


# let the user pick domains to convert
proc select { } {
  global Domains

  # hide the GUI
  wm withdraw .

  # allow picking of any domain
  set mask [pw::Display createSelectionMask -requireDomain {}]

  # turn on picking
  if [pw::Display selectEntities -description "Select domains to convert" \
      -preselect $Domains -selectionmask $mask results] {
    foreach i $results(Domains) { 
      if { [lsearch $Domains $i] == -1 } {
        lappend Domains $i
      }
    }
  }

  # show the GUI
  if [winfo exists .] {
    wm deiconify .
  }

  # report the total number of picked domains
  .info configure -text [format "%d domains selected" [llength $Domains]]

  # enable the OK button if any domains are picked
  if {0 == [llength $Domains]} {
    .buttons.ok configure -state disabled
  } else {
    .buttons.ok configure -state normal
  }
}


# build the GUI
proc makeWindow {} {
  label .title -text "Domain To DB Entity"
  wm title . "Domain to DB Entity"
  set font [.title cget -font]
  .title configure -font [font create -family [font actual $font -family] \
      -weight bold]

  pack .title -expand 1 -side top
  pack [frame .hr1 -relief sunken -height 2 -bd 1] -side top -padx 2 \
      -fill x -pady 4
  pack [button .enterSelect -text "Pick Domains" -command { select }] -padx 4
  pack [checkbutton .preserve -text "Keep Domains" -variable PreserveGrid]
  pack [frame .hr2 -relief sunken -height 2 -bd 1] -side top -padx 2 \
      -fill x -pady 1
  pack [label .info -text "0 domains selected"] -side top -fill x -pady 2
  pack [frame .buttons] -fill x -padx 2 -pady 1
  pack [button .buttons.cancel -text "Cancel" -command { exit }] \
      -side right -padx 2
  pack [button .buttons.ok -text "OK" -command { convertToDBEntity; exit;} \
      -state disabled] -side right -padx 2

  pack [label .buttons.logo -image [pwLogo] -bd 0 -relief flat] \
    -side left -padx 5

  bind . <KeyPress-Escape> { .buttons.cancel invoke }
  bind . <Control-KeyPress-Return> { .buttons.ok invoke }
}


# the Pointwise logo image
proc pwLogo {} {
  set logoData "
R0lGODlheAAYAIcAAAAAAAICAgUFBQkJCQwMDBERERUVFRkZGRwcHCEhISYmJisrKy0tLTIyMjQ0
NDk5OT09PUFBQUVFRUpKSk1NTVFRUVRUVFpaWlxcXGBgYGVlZWlpaW1tbXFxcXR0dHp6en5+fgBi
qQNkqQVkqQdnrApmpgpnqgpprA5prBFrrRNtrhZvsBhwrxdxsBlxsSJ2syJ3tCR2siZ5tSh6tix8
ti5+uTF+ujCAuDODvjaDvDuGujiFvT6Fuj2HvTyIvkGKvkWJu0yUv2mQrEOKwEWNwkaPxEiNwUqR
xk6Sw06SxU6Uxk+RyVKTxlCUwFKVxVWUwlWWxlKXyFOVzFWWyFaYyFmYx16bwlmZyVicyF2ayFyb
zF2cyV2cz2GaxGSex2GdymGezGOgzGSgyGWgzmihzWmkz22iymyizGmj0Gqk0m2l0HWqz3asznqn
ynuszXKp0XKq1nWp0Xaq1Hes0Xat1Hmt1Xyt0Huw1Xux2IGBgYWFhYqKio6Ojo6Xn5CQkJWVlZiY
mJycnKCgoKCioqKioqSkpKampqmpqaurq62trbGxsbKysrW1tbi4uLq6ur29vYCu0YixzYOw14G0
1oaz14e114K124O03YWz2Ie12oW13Im10o621Ii22oi23Iy32oq52Y252Y+73ZS51Ze81JC625G7
3JG825K83Je72pW93Zq92Zi/35G+4aC90qG+15bA3ZnA3Z7A2pjA4Z/E4qLA2KDF3qTA2qTE3avF
36zG3rLM3aPF4qfJ5KzJ4LPL5LLM5LTO4rbN5bLR6LTR6LXQ6r3T5L3V6cLCwsTExMbGxsvLy8/P
z9HR0dXV1dbW1tjY2Nra2tzc3N7e3sDW5sHV6cTY6MnZ79De7dTg6dTh69Xi7dbj7tni793m7tXj
8Nbk9tjl9N3m9N/p9eHh4eTk5Obm5ujo6Orq6u3t7e7u7uDp8efs8uXs+Ozv8+3z9vDw8PLy8vL0
9/b29vb5+/f6+/j4+Pn6+/r6+vr6/Pn8/fr8/Pv9/vz8/P7+/gAAACH5BAMAAP8ALAAAAAB4ABgA
AAj/AP8JHEiwoMGDCBMqXMiwocOHECNKnEixosWLGDNqZCioo0dC0Q7Sy2btlitisrjpK4io4yF/
yjzKRIZPIDSZOAUVmubxGUF88Aj2K+TxnKKOhfoJdOSxXEF1OXHCi5fnTx5oBgFo3QogwAalAv1V
yyUqFCtVZ2DZceOOIAKtB/pp4Mo1waN/gOjSJXBugFYJBBflIYhsq4F5DLQSmCcwwVZlBZvppQtt
D6M8gUBknQxA879+kXixwtauXbhheFph6dSmnsC3AOLO5TygWV7OAAj8u6A1QEiBEg4PnA2gw7/E
uRn3M7C1WWTcWqHlScahkJ7NkwnE80dqFiVw/Pz5/xMn7MsZLzUsvXoNVy50C7c56y6s1YPNAAAC
CYxXoLdP5IsJtMBWjDwHHTSJ/AENIHsYJMCDD+K31SPymEFLKNeM880xxXxCxhxoUKFJDNv8A5ts
W0EowFYFBFLAizDGmMA//iAnXAdaLaCUIVtFIBCAjP2Do1YNBCnQMwgkqeSSCEjzzyJ/BFJTQfNU
WSU6/Wk1yChjlJKJLcfEgsoaY0ARigxjgKEFJPec6J5WzFQJDwS9xdPQH1sR4k8DWzXijwRbHfKj
YkFO45dWFoCVUTqMMgrNoQD08ckPsaixBRxPKFEDEbEMAYYTSGQRxzpuEueTQBlshc5A6pjj6pQD
wf9DgFYP+MPHVhKQs2Js9gya3EB7cMWBPwL1A8+xyCYLD7EKQSfEF1uMEcsXTiThQhmszBCGC7G0
QAUT1JS61an/pKrVqsBttYxBxDGjzqxd8abVBwMBOZA/xHUmUDQB9OvvvwGYsxBuCNRSxidOwFCH
J5dMgcYJUKjQCwlahDHEL+JqRa65AKD7D6BarVsQM1tpgK9eAjjpa4D3esBVgdFAB4DAzXImiDY5
vCFHESko4cMKSJwAxhgzFLFDHEUYkzEAG6s6EMgAiFzQA4rBIxldExBkr1AcJzBPzNDRnFCKBpTd
gCD/cKKKDFuYQoQVNhhBBSY9TBHCFVW4UMkuSzf/fe7T6h4kyFZ/+BMBXYpoTahB8yiwlSFgdzXA
5JQPIDZCW1FgkDVxgGKCFCywEUQaKNitRA5UXHGFHN30PRDHHkMtNUHzMAcAA/4gwhUCsB63uEF+
bMVB5BVMtFXWBfljBhhgbCFCEyI4EcIRL4ChRgh36LBJPq6j6nS6ISPkslY0wQbAYIr/ahCeWg2f
ufFaIV8QNpeMMAkVlSyRiRNb0DFCFlu4wSlWYaL2mOp13/tY4A7CL63cRQ9aEYBT0seyfsQjHedg
xAG24ofITaBRIGTW2OJ3EH7o4gtfCIETRBAFEYRgC06YAw3CkIqVdK9cCZRdQgCVAKWYwy/FK4i9
3TYQIboE4BmR6wrABBCUmgFAfgXZRxfs4ARPPCEOZJjCHVxABFAA4R3sic2bmIbAv4EvaglJBACu
IxAMAKARBrFXvrhiAX8kEWVNHOETE+IPbzyBCD8oQRZwwIVOyAAXrgkjijRWxo4BLnwIwUcCJvgP
ZShAUfVa3Bz/EpQ70oWJC2mAKDmwEHYAIxhikAQPeOCLdRTEAhGIQKL0IMoGTGMgIBClA9QxkA3U
0hkKgcy9HHEQDcRyAr0ChAWWucwNMIJZ5KilNGvpADtt5JrYzKY2t8nNbnrzm+B8SEAAADs="

  return [image create photo -format GIF -data $logoData]
}

makeWindow

#
# DISCLAIMER:
# TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, POINTWISE DISCLAIMS
# ALL WARRANTIES, EITHER EXPRESS OR IMPLIED, INCLUDING, BUT NOT LIMITED
# TO, IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE, WITH REGARD TO THIS SCRIPT.  TO THE MAXIMUM EXTENT PERMITTED 
# BY APPLICABLE LAW, IN NO EVENT SHALL POINTWISE BE LIABLE TO ANY PARTY 
# FOR ANY SPECIAL, INCIDENTAL, INDIRECT, OR CONSEQUENTIAL DAMAGES 
# WHATSOEVER (INCLUDING, WITHOUT LIMITATION, DAMAGES FOR LOSS OF 
# BUSINESS INFORMATION, OR ANY OTHER PECUNIARY LOSS) ARISING OUT OF THE 
# USE OF OR INABILITY TO USE THIS SCRIPT EVEN IF POINTWISE HAS BEEN 
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGES AND REGARDLESS OF THE 
# FAULT OR NEGLIGENCE OF POINTWISE.
#

