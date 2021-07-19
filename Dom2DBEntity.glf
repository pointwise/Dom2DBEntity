#############################################################################
#
# (C) 2021 Cadence Design Systems, Inc. All rights reserved worldwide.
#
# This sample script is not supported by Cadence Design Systems, Inc.
# It is provided freely for demonstration purposes only.
# SEE THE WARRANTY DISCLAIMER AT THE BOTTOM OF THIS FILE.
#
#############################################################################

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

  pack [label .buttons.logo -image [cadenceLogo] -bd 0 -relief flat] \
    -side left -padx 5

  bind . <KeyPress-Escape> { .buttons.cancel invoke }
  bind . <Control-KeyPress-Return> { .buttons.ok invoke }
}


# the Cadence Design Systems logo image
proc cadenceLogo {} {
  set logoData "
R0lGODlhgAAYAPQfAI6MjDEtLlFOT8jHx7e2tv39/RYSE/Pz8+Tj46qoqHl3d+vq62ZjY/n4+NT
T0+gXJ/BhbN3d3fzk5vrJzR4aG3Fubz88PVxZWp2cnIOBgiIeH769vtjX2MLBwSMfIP///yH5BA
EAAB8AIf8LeG1wIGRhdGF4bXD/P3hwYWNrZXQgYmVnaW49Iu+7vyIgaWQ9Ilc1TTBNcENlaGlIe
nJlU3pOVGN6a2M5ZCI/PiA8eDp4bXBtdGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1w
dGs9IkFkb2JlIFhNUCBDb3JlIDUuMC1jMDYxIDY0LjE0MDk0OSwgMjAxMC8xMi8wNy0xMDo1Nzo
wMSAgICAgICAgIj48cmRmOlJERiB4bWxuczpyZGY9Imh0dHA6Ly93d3cudy5vcmcvMTk5OS8wMi
8yMi1yZGYtc3ludGF4LW5zIyI+IDxyZGY6RGVzY3JpcHRpb24gcmY6YWJvdXQ9IiIg/3htbG5zO
nhtcE1NPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvbW0vIiB4bWxuczpzdFJlZj0iaHR0
cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL3NUcGUvUmVzb3VyY2VSZWYjIiB4bWxuczp4bXA9Imh
0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8iIHhtcE1NOk9yaWdpbmFsRG9jdW1lbnRJRD0idX
VpZDoxMEJEMkEwOThFODExMUREQTBBQzhBN0JCMEIxNUM4NyB4bXBNTTpEb2N1bWVudElEPSJ4b
XAuZGlkOkIxQjg3MzdFOEI4MTFFQjhEMv81ODVDQTZCRURDQzZBIiB4bXBNTTpJbnN0YW5jZUlE
PSJ4bXAuaWQ6QjFCODczNkZFOEI4MTFFQjhEMjU4NUNBNkJFRENDNkEiIHhtcDpDcmVhdG9yVG9
vbD0iQWRvYmUgSWxsdXN0cmF0b3IgQ0MgMjMuMSAoTWFjaW50b3NoKSI+IDx4bXBNTTpEZXJpZW
RGcm9tIHN0UmVmOmluc3RhbmNlSUQ9InhtcC5paWQ6MGE1NjBhMzgtOTJiMi00MjdmLWE4ZmQtM
jQ0NjMzNmNjMWI0IiBzdFJlZjpkb2N1bWVudElEPSJ4bXAuZGlkOjBhNTYwYTM4LTkyYjItNDL/
N2YtYThkLTI0NDYzMzZjYzFiNCIvPiA8L3JkZjpEZXNjcmlwdGlvbj4gPC9yZGY6UkRGPiA8L3g
6eG1wbWV0YT4gPD94cGFja2V0IGVuZD0iciI/PgH//v38+/r5+Pf29fTz8vHw7+7t7Ovp6Ofm5e
Tj4uHg397d3Nva2djX1tXU09LR0M/OzczLysnIx8bFxMPCwcC/vr28u7q5uLe2tbSzsrGwr66tr
KuqqainpqWko6KhoJ+enZybmpmYl5aVlJOSkZCPjo2Mi4qJiIeGhYSDgoGAf359fHt6eXh3dnV0
c3JxcG9ubWxramloZ2ZlZGNiYWBfXl1cW1pZWFdWVlVUU1JRUE9OTUxLSklIR0ZFRENCQUA/Pj0
8Ozo5ODc2NTQzMjEwLy4tLCsqKSgnJiUkIyIhIB8eHRwbGhkYFxYVFBMSERAPDg0MCwoJCAcGBQ
QDAgEAACwAAAAAgAAYAAAF/uAnjmQpTk+qqpLpvnAsz3RdFgOQHPa5/q1a4UAs9I7IZCmCISQwx
wlkSqUGaRsDxbBQer+zhKPSIYCVWQ33zG4PMINc+5j1rOf4ZCHRwSDyNXV3gIQ0BYcmBQ0NRjBD
CwuMhgcIPB0Gdl0xigcNMoegoT2KkpsNB40yDQkWGhoUES57Fga1FAyajhm1Bk2Ygy4RF1seCjw
vAwYBy8wBxjOzHq8OMA4CWwEAqS4LAVoUWwMul7wUah7HsheYrxQBHpkwWeAGagGeLg717eDE6S
4HaPUzYMYFBi211FzYRuJAAAp2AggwIM5ElgwJElyzowAGAUwQL7iCB4wEgnoU/hRgIJnhxUlpA
SxY8ADRQMsXDSxAdHetYIlkNDMAqJngxS47GESZ6DSiwDUNHvDd0KkhQJcIEOMlGkbhJlAK/0a8
NLDhUDdX914A+AWAkaJEOg0U/ZCgXgCGHxbAS4lXxketJcbO/aCgZi4SC34dK9CKoouxFT8cBNz
Q3K2+I/RVxXfAnIE/JTDUBC1k1S/SJATl+ltSxEcKAlJV2ALFBOTMp8f9ihVjLYUKTa8Z6GBCAF
rMN8Y8zPrZYL2oIy5RHrHr1qlOsw0AePwrsj47HFysrYpcBFcF1w8Mk2ti7wUaDRgg1EISNXVwF
lKpdsEAIj9zNAFnW3e4gecCV7Ft/qKTNP0A2Et7AUIj3ysARLDBaC7MRkF+I+x3wzA08SLiTYER
KMJ3BoR3wzUUvLdJAFBtIWIttZEQIwMzfEXNB2PZJ0J1HIrgIQkFILjBkUgSwFuJdnj3i4pEIlg
eY+Bc0AGSRxLg4zsblkcYODiK0KNzUEk1JAkaCkjDbSc+maE5d20i3HY0zDbdh1vQyWNuJkjXnJ
C/HDbCQeTVwOYHKEJJwmR/wlBYi16KMMBOHTnClZpjmpAYUh0GGoyJMxya6KcBlieIj7IsqB0ji
5iwyyu8ZboigKCd2RRVAUTQyBAugToqXDVhwKpUIxzgyoaacILMc5jQEtkIHLCjwQUMkxhnx5I/
seMBta3cKSk7BghQAQMeqMmkY20amA+zHtDiEwl10dRiBcPoacJr0qjx7Ai+yTjQvk31aws92JZ
Q1070mGsSQsS1uYWiJeDrCkGy+CZvnjFEUME7VaFaQAcXCCDyyBYA3NQGIY8ssgU7vqAxjB4EwA
DEIyxggQAsjxDBzRagKtbGaBXclAMMvNNuBaiGAAA7"

  return [image create photo -format GIF -data $logoData]
}

makeWindow

#############################################################################
#
# This file is licensed under the Cadence Public License Version 1.0 (the
# "License"), a copy of which is found in the included file named "LICENSE",
# and is distributed "AS IS." TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE
# LAW, CADENCE DISCLAIMS ALL WARRANTIES AND IN NO EVENT SHALL BE LIABLE TO
# ANY PARTY FOR ANY DAMAGES ARISING OUT OF OR RELATING TO USE OF THIS FILE.
# Please see the License for the full text of applicable terms.
#
#############################################################################
