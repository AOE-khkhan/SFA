# read entity and write to spreadsheet
proc getEntity {objEntity checkInverse} {
  global attrType badAttributes cells col coordinatesList count developer entComment entCount entName heading invMsg invVals lineStrips localName
  global matrixList normals opt roseLogical row rowmax sheetLast skipEntities skipPerm syntaxErr thisEntType triangles worksheet worksheets
  global wsCount wsNames
  
# get entity type
  set thisEntType [$objEntity Type]
  #if {$developer} {if {$thisEntType != $expectedEnt} {errorMsg "Mismatch: $thisEntType  $expectedEnt"}}

  if {[info exists invVals]} {unset invVals}
  set cellLimit1 200
  set cellLimit2 500

# -------------------------------------------------------------------------------------------------
# open worksheet for each entity if it does not already exist
  if {![info exists worksheet($thisEntType)]} {
    set msg "[formatComplexEnt $thisEntType] ("
    set rm [expr {$rowmax-3}]
    if {$entCount($thisEntType) > $rm} {append msg "$rm of "}
    append msg "$entCount($thisEntType))"
    outputMsg $msg
    
    if {$entCount($thisEntType) > $rm} {errorMsg " Maximum Rows ($rm) exceeded (see Spreadsheet tab)" red}
    if {$entCount($thisEntType) > 10000 && $rm > 10000} {errorMsg " Number of entities > 10000.  Consider using the Maximum Rows option." red}

    set wsCount [$worksheets Count]
    if {$wsCount < 1} {
      set worksheet($thisEntType) [$worksheets Item [expr [incr wsCount]]]
    } else {
      set worksheet($thisEntType) [$worksheets Add [::tcom::na] $sheetLast]
    }
    $worksheet($thisEntType) Activate
    
    set sheetLast $worksheet($thisEntType)

    set name $thisEntType
    if {[string length $name] > 31} {
      set name [string range $name 0 30]
      for {set i 1} {$i < 10} {incr i} {
        if {[info exists entName($name)]} {set name "[string range $name 0 29]$i"}
      }
      errorMsg " Worksheet names are truncated to the first 31 characters" red
    }
    set wsNames($name) $thisEntType
    set ws_name($thisEntType) [$worksheet($thisEntType) Name $name]
    set cells($thisEntType)   [$worksheet($thisEntType) Cells]
    set heading($thisEntType) 1

    set row($thisEntType) 4
    $cells($thisEntType) Item 3 1 "ID"

# set vertical alignment
    $cells($thisEntType) VerticalAlignment [expr -4160]

    set entName($name) $thisEntType
    set count($thisEntType) 0
    set invMsg ""

# color tab, not available in very old versions of Excel
    catch {
      set cidx [setColorIndex $thisEntType]
      if {$cidx > 0} {[$worksheet($thisEntType) Tab] ColorIndex [expr $cidx]}      
    }

    set wsCount [$worksheets Count]
    set sheetLast $worksheet($thisEntType)

# file of entities not to process
    set cfile [file rootname $localName]
    append cfile "-skip.dat"
    if {[catch {
      set skipFile [open $cfile w]
      foreach item $skipEntities {if {[lsearch $skipPerm $item] == -1} {puts $skipFile $item}}
      if {[lsearch $skipEntities $thisEntType] == -1 && [lsearch $skipPerm $thisEntType] == -1} {puts $skipFile $thisEntType}
      close $skipFile
    } emsg]} {
      errorMsg "ERROR processing 'skip' file: $emsg"
    }
    update idletasks

# -------------------------------------------------------------------------------------------------
# entity worksheet already open
  } else {
    incr row($thisEntType)
    set heading($thisEntType) 0
  }

# -------------------------------------------------------------------------------------------------
# if less than max allowed rows, append attribute values to rowList, append rowList to matrixList 
# originally, values where written directly one-by-one to a worksheet, now writing a matrix of values
# to a worksheet is much faster than writing values to cells one at a time
  if {$row($thisEntType) <= $rowmax} {
    set col($thisEntType) 1
    incr count($thisEntType)
    
# show progress with > 50000 entities
    if {$entCount($thisEntType) >= 50000} {
      set c1 [expr {$count($thisEntType)%20000}]
      if {$c1 == 0} {
        outputMsg " $count($thisEntType) of $entCount($thisEntType) processed"
        update idletasks
      }
    }

# entity ID
    set p21id [$objEntity P21ID]
    lappend rowList $p21id
    [$worksheet($thisEntType) Range A$row($thisEntType)] NumberFormat "0"
      
# keep track of the entity ID for a row
    setIDRow $thisEntType $p21id

# -------------------------------------------------------------------------------------------------
# find inverse relationships for specific entities
    if {$checkInverse} {invFind $objEntity}
    set invLen 0
    if {[info exists invVals]} {set invLen [array size invVals]}

# -------------------------------------------------------------------------------------------------
# for all attributes of the entity
    set nattr 0
    set objAttributes [$objEntity Attributes]

    ::tcom::foreach objAttribute $objAttributes {
      set attrName [$objAttribute Name]

      if {[catch {
        if {![info exists badAttributes($thisEntType)]} {
          set objValue [$objAttribute Value]

# look for bad attributes that cause a crash
        } else {
          set ok 1
          foreach ba $badAttributes($thisEntType) {if {$ba == $attrName} {set ok 0}}
          if {$ok} {
            set objValue [$objAttribute Value]
          } else {
            set objValue "???"
            if {[llength $badAttributes($thisEntType)] == 1} {
              set ok1 0
              switch -- $attrName {
                position_coords {if {[info exists coordinatesList($p21id)]} {set objValue $coordinatesList($p21id); set ok1 1}}
                line_strips     {if {[info exists lineStrips($p21id)]}      {set objValue $lineStrips($p21id); set ok1 1}}
              }
              if {!$ok1} {errorMsg " Reporting [formatComplexEnt $thisEntType] '$attrName' attribute is not supported.  '???' will appear in spreadsheet for this attribute.  See User Guide section 3.3.1" red}
            } else {
              set str $badAttributes($thisEntType)
              regsub -all " " $str "' '" str
              errorMsg " Reporting [formatComplexEnt $thisEntType] '$str' attribute is not supported.  '???' will appear in spreadsheet for these attributes.  See User Guide section 3.3.1" red
            }
          }
        }

# error getting attribute value
      } emsgv]} {
        set msg "ERROR processing '$attrName' attribute on '[$objEntity Type]': $emsgv"
        errorMsg $msg
        lappend syntaxErr([$objEntity Type]) [list -$row($thisEntType) $attrName $msg]
        if {[string first "datum_reference_compartment 'modifiers' attribute" $msg] != -1 || \
            [string first "datum_reference_element 'modifiers' attribute" $msg] != -1 || \
            [string first "annotation_plane 'elements' attribute" $msg] != -1} {
          set msg "Syntax Error: On '[$objEntity Type]' entities change the '$attrName' attribute with\n '()' to '$' where applicable.  The attribute is an OPTIONAL SET\[1:?\] and '()' is not valid."
          errorMsg $msg
          lappend syntaxErr([$objEntity Type]) [list -$row($thisEntType) $attrName $msg]
        }
        set objValue ""
        catch {raise .}
      }

      incr nattr

# -------------------------------------------------------------------------------------------------
# headings in first row only for first instance of an entity
      if {$heading($thisEntType) != 0} {
        $cells($thisEntType) Item 3 [incr heading($thisEntType)] $attrName
        set attrType($heading($thisEntType)) [$objAttribute Type]
        set entComment($attrName) 1
      }

# -------------------------------------------------------------------------------------------------
# values in rows
      incr col($thisEntType)

# not a handle, just a single value
      if {[string first "handle" $objValue] == -1} {
        set ov $objValue
    
# if value is a boolean, substitute string roseLogical
        if {([$objAttribute Type] == "RoseBoolean" || [$objAttribute Type] == "RoseLogical") && [info exists roseLogical($ov)]} {set ov $roseLogical($ov)}

# check if showing numbers without rounding
        catch {
          if {!$opt(xlNoRound)} {
            lappend rowList $ov
          } elseif {$attrType($col($thisEntType)) != "double" && $attrType($col($thisEntType)) != "measure_value"} {
            lappend rowList $ov
          } elseif {[string length $ov] < 12} {
            lappend rowList $ov

# no rounding, show as text '
          } else {
            lappend rowList "'$ov"
          }
        }
        
# -------------------------------------------------------------------------------------------------
# node type 18=ENTITY, 19=SELECT TYPE  (node type is 20 for SET or LIST is processed below)
      } elseif {[$objAttribute NodeType] == 18 || [$objAttribute NodeType] == 19} {
        set refEntity [$objAttribute Value]

# get refType, however, sometimes this is not a single reference, but rather a list
        if {[catch {
          set refType [$refEntity Type]
          set valnotlist 1
        } emsg2]} {

# process like a list
          catch {foreach idx [array names cellval] {unset cellval($idx)}}
          ::tcom::foreach val $refEntity {append cellval([$val Type]) "[$val P21ID] "}
          set str ""
          set size 0
          catch {set size [array size cellval]}

          if {$size > 0} {
            foreach idx [lsort [array names cellval]] {
              set ncell [expr {[llength [split $cellval($idx) " "]] - 1}]
              if {$ncell > 1 || $size > 1} {
                set ok 1
                if {$ncell > $cellLimit1 && ([string first "styled_item" $idx] != -1 || [string first "triangulated" $idx] != -1 || \
                    [string first "connecting_edge" $idx] != -1 || [string first "3d_element_representation" $idx] != -1 || \
                    $idx == "node" || $idx == "cartesian_point" || $idx == "advanced_face")} {
                  set ok 0
                } elseif {$ncell > $cellLimit2} {
                  set ok 0
                }
                if {$ok} {
                  append str "($ncell) [formatComplexEnt $idx 1] $cellval($idx)  "
                } else {
                  append str "($ncell) [formatComplexEnt $idx 1]  "
                }
              } else {
                append str "(1) [formatComplexEnt $idx 1] $cellval($idx)  "
              }
            }
          }
          
          lappend rowList [string trim $str]
          set valnotlist 0
        }

# value is not a list which is the most common
        if {$valnotlist} {
          set str "[formatComplexEnt $refType 1] [$refEntity P21ID]"

# for length measure (and other measures), add the actual measure value
          set cellComment 0
          if {[string first "measure_with_unit" $refType] != -1} {
            ::tcom::foreach refAttribute [$refEntity Attributes] {
              if {[$refAttribute Name] == "value_component"} {
                set str "[$refAttribute Value] ($str)"
                set cellComment 1
              }
            }
          }
          lappend rowList $str
          if {$cellComment && $entComment($attrName)} {
            addCellComment $thisEntType 3 $col($thisEntType) "The values of *_measure_with_unit are also shown."
            set entComment($attrName) 0
          }
        }

# -------------------------------------------------------------------------------------------------
# node type 20=AGGREGATE (ENTITIES), usually SET or LIST, try as a tcom list or regular list (SELECT type)
      } elseif {[$objAttribute NodeType] == 20} {
        catch {foreach idx [array names cellval] {unset cellval($idx)}}
        catch {unset cellparam}
        set valMeasure {}

# collect the reference id's (P21ID) for the Type of entity in the SET or LIST
        if {[catch {
          ::tcom::foreach val [$objAttribute Value] {
            set valType [$val Type]
            append cellval($valType) "[$val P21ID] "

# check for length or plane measures
            if {[string first "measure_with_unit" $valType] != -1} {
              if {[string first "length" $valType] != -1 || [string first "plane" $valType] != -1} {
                ::tcom::foreach refAttribute [$val Attributes] {
                  if {[$refAttribute Name] == "value_component"} {lappend valMeasure [$refAttribute Value]}
                }
              }
            }
          }
        } emsg]} {
          foreach val [$objAttribute Value] {
            if {[string first "handle" $val] != -1} {
              set valType [$val Type]
              append cellval($valType) "[$val P21ID] "
            } else {
              append cellparam "$val "
            }
          }
        }

# -------------------------------------------------------------------------------------------------
# format cell values for the SET or LIST
        set str ""
        set size 0
        catch {set size [array size cellval]}

        set strMeasure ""
        if {[llength $valMeasure] > 0 && [llength $valMeasure] < 5} {set strMeasure "[join $valMeasure] "}

        if {[info exists cellparam]} {append str "$cellparam "}
        if {$size > 0} {
          foreach idx [lsort [array names cellval]] {
            set ncell [expr {[llength [split $cellval($idx) " "]] - 1}]
            if {$ncell > 1 || $size > 1} {
              set ok 1
              if {$ncell > $cellLimit1 && ([string first "styled_item" $idx] != -1 || [string first "triangulated" $idx] != -1 || \
                  [string first "connecting_edge" $idx] != -1 || [string first "3d_element_representation" $idx] != -1 || \
                  $idx == "node" || $idx == "cartesian_point" || $idx == "advanced_face")} {
                set ok 0
              } elseif {$ncell > $cellLimit2} {
                set ok 0
              }
              if {$ok} {
                if {[string first "measure_with_unit" $idx] != -1} {
                  append str "$strMeasure\($ncell) [formatComplexEnt $idx 1] $cellval($idx)  "
                } else {
                  append str "($ncell) [formatComplexEnt $idx 1] $cellval($idx)  "
                }
              } else {
                append str "($ncell) [formatComplexEnt $idx 1]  "
              }
            } elseif {[string first "measure_with_unit" $idx] != -1} {
              append str "$strMeasure\(1) [formatComplexEnt $idx 1] $cellval($idx)  "
            } else {
              append str "(1) [formatComplexEnt $idx 1] $cellval($idx)  "
            }
          }
        }
        
        lappend rowList [string trim $str]
        if {$strMeasure != "" && $entComment($attrName)} {
          addCellComment $thisEntType 3 $col($thisEntType) "The values of *_measure_with_unit are also shown."
          set entComment($attrName) 0
        }
      }
    }

# append rowList to matrixList which will be written to spreadsheet after all entities have been processed in genExcel
    lappend matrixList $rowList

# -------------------------------------------------------------------------------------------------
# report inverses    
    if {$invLen > 0} {invReport}

# rows exceeded, return of 0 will break the loop to process an entity type
  } else {
    return 0
  }  

# clean up variables to hopefully release some memory
  foreach var {objAttributes attrName refEntity refType} {if {[info exists $var]} {unset $var}}
  update idletasks
  return 1
}

# -------------------------------------------------------------------------------
# keep track of the entity ID for a row
proc setIDRow {entType p21id} {
  global gpmiEnts gpmiIDRow idRow propDefIDRow row spmiEnts spmiIDRow
  
# row id for an entity id
  set idRow($entType,$p21id) $row($entType)
  
# specific arrays for properties and PMI
  if {$entType == "property_definition"} {
    set propDefIDRow($p21id) $row($entType)
  } elseif {$gpmiEnts($entType)} {
    set gpmiIDRow($entType,$p21id) $row($entType)
  } elseif {$spmiEnts($entType)} {
    set spmiIDRow($entType,$p21id) $row($entType)
  }
}

# -------------------------------------------------------------------------------------------------
# read entity and write to CSV file
proc getEntityCSV {objEntity} {
  global badAttributes count csvdirnam csvfile csvintemp csvstr entCount fcsv localName mydocs roseLogical row rowmax skipEntities skipPerm thisEntType
  
# get entity type
  set thisEntType [$objEntity Type]
  set cellLimit1 500
  set cellLimit2 1000

# -------------------------------------------------------------------------------------------------
# csv file for each entity if it does not already exist
  if {![info exists csvfile($thisEntType)]} {
    set msg "[formatComplexEnt $thisEntType] ("
    set rm [expr {$rowmax-3}]
    if {$entCount($thisEntType) > $rm} {append msg "$rm of "}
    append msg "$entCount($thisEntType))"
    outputMsg $msg
    
    if {$entCount($thisEntType) > $rm} {errorMsg " Maximum Rows ($rm) exceeded (see Spreadsheet tab)" red}
    if {$entCount($thisEntType) > 10000 && $rm > 10000} {errorMsg " Number of entities > 10000.  Consider using the Maximum Rows option." red}

# open csv file
    set csvfile($thisEntType) 1
    set csvfname [file join $csvdirnam $thisEntType.csv]
    if {[string length $csvfname] > 218} {
      set csvfname [file nativename [file join $mydocs $thisEntType.csv]]
      errorMsg " Some CSV files are saved in the home directory." red
      set csvintemp 1
    }
    set fcsv [open $csvfname w]
    puts $fcsv "[formatComplexEnt $thisEntType] ($entCount($thisEntType))"

# headings in first row
    set csvstr "ID"
    ::tcom::foreach objAttribute [$objEntity Attributes] {append csvstr ",[$objAttribute Name]"}
    puts $fcsv $csvstr
    unset csvstr

    set count($thisEntType) 0
    set row($thisEntType) 4

# file of entities not to process
    set cfile [file rootname $localName]
    append cfile "-skip.dat"
    if {[catch {
      set skipFile [open $cfile w]
      foreach item $skipEntities {if {[lsearch $skipPerm $item] == -1} {puts $skipFile $item}}
      if {[lsearch $skipEntities $thisEntType] == -1 && [lsearch $skipPerm $thisEntType] == -1} {puts $skipFile $thisEntType}
      close $skipFile
    } emsg]} {
      errorMsg "ERROR processing 'skip' file: $emsg"
    }
    update idletasks

# CSV file already open
  } else {
    incr row($thisEntType)
  }

# -------------------------------------------------------------------------------------------------
# start appending to csvstr, if less than max allowed rows
  update idletasks
  if {$row($thisEntType) <= $rowmax} {
    incr count($thisEntType)
  
# show progress with > 50000 entities
    if {$entCount($thisEntType) >= 50000} {
      set c1 [expr {$count($thisEntType)%20000}]
      if {$c1 == 0} {
        outputMsg " $count($thisEntType) of $entCount($thisEntType) processed"
        update idletasks
      }
    }

# entity ID
    set p21id [$objEntity P21ID]

# -------------------------------------------------------------------------------------------------
# for all attributes of the entity
    set nattr 0
    set csvstr $p21id
    set objAttributes [$objEntity Attributes]
    ::tcom::foreach objAttribute $objAttributes {
      set attrName [$objAttribute Name]
  
      if {[catch {
        if {![info exists badAttributes($thisEntType)]} {
          set objValue [$objAttribute Value]

# look for bad attributes that cause a crash
        } else {
          set ok 1
          foreach ba $badAttributes($thisEntType) {if {$ba == $attrName} {set ok 0}}
          if {$ok} {
            set objValue [$objAttribute Value]
          } else {
            set objValue "???"
            errorMsg " Reporting [formatComplexEnt $thisEntType] '$attrName' attribute is not supported.  '???' will appear in CSV file for this attribute.  See User Guide section 3.3.1" red
          }
        }

# error getting attribute value
      } emsgv]} {
        set msg "ERROR processing #[$objEntity P21ID]=[$objEntity Type] '$attrName' attribute: $emsgv"
        if {[string first "datum_reference_compartment 'modifiers' attribute" $msg] != -1 || \
            [string first "datum_reference_element 'modifiers' attribute" $msg] != -1 || \
            [string first "annotation_plane 'elements' attribute" $msg] != -1} {
          errorMsg "Syntax Error: On '[$objEntity Type]' entities change the '$attrName' attribute with\n '()' to '$' where applicable.  The attribute is an OPTIONAL SET\[1:?\] and '()' is not valid."
        }
        errorMsg $msg
        set objValue ""
        catch {raise .}
      }
      incr nattr

# -------------------------------------------------------------------------------------------------
# not a handle, just a single value
      if {[string first "handle" $objValue] == -1} {
        set ov $objValue
  
# if value is a boolean, substitute string roseLogical
        if {([$objAttribute Type] == "RoseBoolean" || [$objAttribute Type] == "RoseLogical") && [info exists roseLogical($ov)]} {set ov $roseLogical($ov)}
        append csvstr ",$ov"

# -------------------------------------------------------------------------------------------------
# node type 18=ENTITY, 19=SELECT TYPE  (node type is 20 for SET or LIST is processed below)
      } elseif {[$objAttribute NodeType] == 18 || [$objAttribute NodeType] == 19} {
        set refEntity [$objAttribute Value]

# get refType, however, sometimes this is not a single reference, but rather a list
#  which causes an error and it has to be processed like a list below
        if {[catch {
          set refType [$refEntity Type]
          set valnotlist 1
        } emsg2]} {

# process like a list which is very unusual
          catch {foreach idx [array names cellval] {unset cellval($idx)}}
          ::tcom::foreach val $refEntity {append cellval([$val Type]) "[$val P21ID] "}
          set str ""
          set size 0
          catch {set size [array size cellval]}

          if {$size > 0} {
            foreach idx [lsort [array names cellval]] {
              set ncell [expr {[llength [split $cellval($idx) " "]] - 1}]
              if {$ncell > 1 || $size > 1} {
                set ok 1
                if {$ncell > $cellLimit1 && ([string first "styled_item" $idx] != -1 || [string first "triangulated" $idx] != -1 || \
                    [string first "connecting_edge" $idx] != -1 || [string first "3d_element_representation" $idx] != -1 || \
                    $idx == "node" || $idx == "cartesian_point" || $idx == "advanced_face")} {
                  set ok 0
                } elseif {$ncell > $cellLimit2} {
                  set ok 0
                }
                if {$ok} {
                  append str "($ncell) [formatComplexEnt $idx 1] $cellval($idx)  "
                } else {
                  append str "($ncell) [formatComplexEnt $idx 1]  "
                }
              } else {
                append str "(1) [formatComplexEnt $idx 1] $cellval($idx)  "
              }
            }
          }
          append csvstr ",$str"
          set valnotlist 0
        }

# value is not a list which is the most common
        if {$valnotlist} {
          set str "[formatComplexEnt $refType 1] [$refEntity P21ID]"

# for length measure (and other measures), add the actual measure value
          if {[string first "measure_with_unit" $refType] != -1} {
            ::tcom::foreach refAttribute [$refEntity Attributes] {
              if {[$refAttribute Name] == "value_component"} {set str "[$refAttribute Value] ($str)"}
            }
          }
          append csvstr ",$str"
        }

# -------------------------------------------------------------------------------------------------
# node type 20=AGGREGATE (ENTITIES), usually SET or LIST, try as a tcom list or regular list (SELECT type)
      } elseif {[$objAttribute NodeType] == 20} {
        catch {foreach idx [array names cellval] {unset cellval($idx)}}
        catch {unset cellparam}

# collect the reference id's (P21ID) for the Type of entity in the SET or LIST
        if {[catch {
          ::tcom::foreach val [$objAttribute Value] {
            append cellval([$val Type]) "[$val P21ID] "
          }
        } emsg]} {
          foreach val [$objAttribute Value] {
            if {[string first "handle" $val] != -1} {
              append cellval([$val Type]) "[$val P21ID] "
            } else {
              append cellparam "$val "
            }
          }
        }

# -------------------------------------------------------------------------------------------------
# format cell values for the SET or LIST
        set str ""
        set size 0
        catch {set size [array size cellval]}

        if {[info exists cellparam]} {append str "$cellparam "}
        if {$size > 0} {
          foreach idx [lsort [array names cellval]] {
            set ncell [expr {[llength [split $cellval($idx) " "]] - 1}]
            if {$ncell > 1 || $size > 1} {
              set ok 1
              if {$ncell > $cellLimit1 && ([string first "styled_item" $idx] != -1 || [string first "triangulated" $idx] != -1 || \
                                   [string first "connecting_edge" $idx] != -1 || [string first "3d_element_representation" $idx] != -1 || \
                                   $idx == "node" || $idx == "cartesian_point" || $idx == "advanced_face")} {
                set ok 0
              } elseif {$ncell > $cellLimit2} {
                set ok 0
              }
              if {$ok} {
                append str "($ncell) [formatComplexEnt $idx 1] $cellval($idx)  "
              } else {
                append str "($ncell) [formatComplexEnt $idx 1]  "
              }
            } else {
              append str "(1) [formatComplexEnt $idx 1] $cellval($idx)  "
            }
          }
        }
        append csvstr ",[string trim $str]"
      }
    }

# write to CSV file
    if {[catch {
      puts $fcsv $csvstr
    } emsg]} {
      errorMsg "Error writing to CSV file for: $thisEntType"
    }

# rows exceeded, return of 0 will break the loop to process an entity type
  } else {
    return 0
  }

# -------------------------------------------------------------------------------------------------
# clean up variables to hopefully release some memory
  foreach var {objAttributes attrName refEntity refType} {if {[info exists $var]} {unset $var}}
  update idletasks
  return 1
}
