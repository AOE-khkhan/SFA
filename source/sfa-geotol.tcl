proc spmiGeotolStart {entType} {
  global objDesign
  global col entLevel ent entAttrList gt lastEnt opt pmiCol pmiHeading pmiStartCol
  global spmiEntity spmiRow spmiTypesPerFile stepAP tolNames

  if {$opt(DEBUG1)} {outputMsg "START spmiGeotolStart $entType" red}

  set len1 [list length_measure_with_unit value_component]
  set len2 [list length_measure_with_unit_and_measure_representation_item value_component]
  set len3 [list length_measure_with_unit_and_measure_representation_item_and_qualified_representation_item value_component]
  set len4 [list plane_angle_measure_with_unit value_component]

  set dtm [list datum identification]
  set cdt [list common_datum identification]
  set df1 [list datum_feature name product_definitional]
  set df2 [list composite_shape_aspect_and_datum_feature name product_definitional]
  set df3 [list composite_group_shape_aspect_and_datum_feature name product_definitional]
  set dr  [list datum_reference precedence referenced_datum $dtm $cdt]
  set drm [list datum_reference_modifier_with_value modifier_type modifier_value $len1 $len2 $len3]
  set dre [list datum_reference_element name product_definitional base $dtm modifiers $drm]
  set drc [list datum_reference_compartment name product_definitional base $dtm $dre modifiers $drm]
  set rmd [list referenced_modified_datum referenced_datum $dtm modifier]

  set PMIP(datum_feature)                                  $df1
  set PMIP(composite_shape_aspect_and_datum_feature)       $df2
  set PMIP(composite_group_shape_aspect_and_datum_feature) $df3

  set PMIP(datum_reference)             $dr
  set PMIP(datum_reference_element)     $dre
  set PMIP(datum_reference_compartment) $drc
  set PMIP(datum_system)                [list datum_system constituents [list datum_reference_compartment base]]
  set PMIP(referenced_modified_datum)   $rmd
  set PMIP(placed_datum_target_feature) [list placed_datum_target_feature description target_id]
  set PMIP(datum_target)                [list datum_target description target_id]

# set PMIP for all *_tolerance entities (datum_system must be last)
  foreach tol $tolNames {set PMIP($tol) \
    [list $tol magnitude $len1 $len2 $len3 $len4 \
      toleranced_shape_aspect \
        $df1 $df2 $df3 [list centre_of_symmetry_and_datum_feature name] \
        [list composite_group_shape_aspect name] [list composite_shape_aspect name] \
        [list composite_unit_shape_aspect name] [list composite_unit_shape_aspect_and_datum_feature name] \
        [list all_around_shape_aspect name] [list between_shape_aspect name] [list shape_aspect name] [list product_definition_shape name] \
      datum_system [list datum_system name product_definitional] $dr $rmd \
      modifiers \
      modifier \
      displacement [list length_measure_with_unit value_component] \
      unit_size $len1 area_type second_unit_size $len1 $len4 \
      maximum_upper_tolerance $len1 \
    ]
  }

# generate correct PMIP variable accounting for variations
  if {![info exists PMIP($entType)]} {
    foreach tol $tolNames {
      if {[string first $tol $entType] != -1} {
        set PMIP($entType) $PMIP($tol)
        lset PMIP($entType) 0 $entType
        break
      }
    }
  }
  if {![info exists PMIP($entType)]} {return}

  set gt $entType
  set lastEnt {}
  set entAttrList {}
  set pmiCol 0
  set spmiRow($gt) {}

  if {[info exists pmiHeading]} {unset pmiHeading}
  if {[info exists ent]}        {unset ent}

  outputMsg " Adding PMI Representation Analysis" blue
  lappend spmiEntity $entType

  if {[string first "AP203" $stepAP] == 0 || [string first "AP214" $stepAP] == 0} {
    errorMsg "There is no Recommended Practice for PMI Representation in $stepAP files.  Use AP242 for PMI Representation."
  }

  if {$opt(DEBUG1)} {outputMsg \n}
  set entLevel 0
  setEntAttrList $PMIP($gt)
  if {$opt(DEBUG1)} {outputMsg "entAttrList $entAttrList"}
  if {$opt(DEBUG1)} {outputMsg \n}

  set startent [lindex $PMIP($gt) 0]
  set n 0
  set entLevel 0

# get next unused column by checking if there is a colName
  set pmiStartCol($gt) [getNextUnusedColumn $startent]

# process all entities, call spmiGeotolReport
  ::tcom::foreach objEntity [$objDesign FindObjects [join $startent]] {
    if {[$objEntity Type] == $startent} {

      foreach item $tolNames {
        if {[string first $item $startent] != -1} {lappend spmiTypesPerFile $item}
      }

      if {$n < 1048576} {
        if {[expr {$n%2000}] == 0} {
          if {$n > 0} {outputMsg "  $n"}
          update
        }
        spmiGeotolReport $objEntity
        if {$opt(DEBUG1)} {outputMsg \n}
      }
      incr n
    }
  }
  set col($gt) $pmiCol
}

# -------------------------------------------------------------------------------
proc spmiGeotolReport {objEntity} {
  global all_around all_over assocGeom ATR axisval badAttributes between cells col datsys datumCompartment datumFeature datumModValue datumTargetDesc datumSymbol
  global datumSystem dim datumEntType datumGeom datumIDs datumTargetType datumTargetView dimtolEntType dimtolGeom entLevel ent entAttrList entCount gt
  global gtEntity nistName objID opt pmiCol pmiHeading pmiModifiers pmiStartCol pmiUnicode ptz ptzError recPracNames spaces spmiEnts spmiID spmiIDRow
  global spmiRow spmiTypesPerFile stepAP syntaxErr tolNames tolStandard tolStandards tolval tzf1 tzfNames tzWithDatum worksheet
  global objDesign

  if {$opt(DEBUG1)} {outputMsg "spmiGeotolReport" red}

# entLevel is very important, keeps track level of entity in hierarchy
  incr entLevel
  set ind [string repeat " " [expr {4*($entLevel-1)}]]

  if {[string first "handle" $objEntity] != -1} {
    set objType [$objEntity Type]
    set objID   [$objEntity P21ID]
    set objAttributes [$objEntity Attributes]
    set ent($entLevel) $objType

    if {$opt(DEBUG1)} {outputMsg "$ind ENT $entLevel #$objID=$objType (ATR=[$objAttributes Count])" blue}

    if {[string first "AP242" $stepAP] == 0} {
      if {$objType == "datum_reference"} {
        set msg "Syntax Error: Use 'datum_system' instead of 'datum_reference' for PMI Representation in AP242 files.$spaces\($recPracNames(pmi242), Sec. 6.9.7)"
        errorMsg $msg
        lappend syntaxErr(datum_reference) [list 1 1 $msg]
      }
    }

# check if there are rows with gt
    if {$entLevel == 1} {
      if {$spmiEnts($objType)} {
        set spmiID $objID
        if {![info exists spmiIDRow($gt,$spmiID)]} {
          incr entLevel -1
          return
        }
      }
    }

    if {$entLevel == 1} {
      catch {unset datsys}
      catch {unset datumFeature}
      catch {unset assocGeom}
      set gtEntity $objEntity
    }
    if {$objType == "datum_system" && [string first "_tolerance" $gt] != -1} {
      set c [string index [cellRange 1 $col($gt)] 0]
      set r $spmiIDRow($gt,$spmiID)
      if {[catch {
        set datsys [list $c $r $datumSystem($objID)]
      } emsg]} {
        errorMsg "Datum system not found: $emsg"
      }
    }

    ::tcom::foreach objAttribute $objAttributes {
      set objName  [$objAttribute Name]
      if {$entLevel < 1} {set entLevel 1}
      set ent1 "$ent($entLevel) $objName"
      set ent2 "$ent($entLevel).$objName"

# look for entities with bad attributes that cause a crash
      set okattr 1
      if {[info exists badAttributes($objType)]} {foreach ba $badAttributes($objType) {if {$ba == $objName} {set okattr 0}}}

# get attribute value
      if {[catch {
        set objValue [$objAttribute Value]
      } emsg]} {
        set okattr 0
      }

# attribute OK
      if {$okattr} {
        set objNodeType [$objAttribute NodeType]
        set objSize     [$objAttribute Size]
        set objAttrType [$objAttribute Type]

        set idx [lsearch $entAttrList $ent1]

# -----------------
# nodeType = 18, 19
        if {$objNodeType == 18 || $objNodeType == 19} {
          if {[catch {
            if {$idx != -1} {
              if {$opt(DEBUG1)} {outputMsg "$ind   ATR $entLevel $objName - $objValue ($objNodeType-[$objAttribute AggNodeType], $objSize, $objAttrType)"}
              set ATR($entLevel) $objName

              if {[info exists cells($gt)]} {
                set ok 0
                set invalid ""

# get values for these entity and attribute pairs
                switch -glob $ent1 {
                  "datum_reference_compartment base" {
# datum_reference_compartment.base refers to a datum or datum_reference_element(s)
                    if {$gt == "datum_system" && [info exists datumCompartment($objID)]} {
                      set col($gt) $pmiStartCol($gt)
                      set ok 1
                      set objValue $datumCompartment($objID)
                      set colName "Datum Reference Frame[format "%c" 10](Sec. 6.9.7, 6.9.8)"
                    } elseif {$gt == "datum_reference_compartment" && $objValue == ""} {
                      set msg "Syntax Error: Missing 'base' attribute on [lindex $ent1 0].$spaces\($recPracNames(pmi242), Sec. 6.9.7)"
                      errorMsg $msg
                      lappend syntaxErr([lindex [split $ent1 " "] 0]) [list $objID [lindex [split $ent1 " "] 1] $msg]
                    } else {
                      set baseType ""
                      catch {set baseType [$objValue Type]}
                      if {$baseType == "common_datum"} {
                        set msg "Syntax Error: Use 'datum_reference_element' (common_datum_list) instead of 'common_datum' for the 'base' attribute on [lindex $ent1 0].$spaces\($recPracNames(pmi242), Sec. 6.9.8)"
                        errorMsg $msg
                        lappend syntaxErr([lindex [split $ent1 " "] 0]) [list $objID [lindex [split $ent1 " "] 1] $msg]
                      }
                    }
                  }
                  "*_tolerance* toleranced_shape_aspect" {
                    set oktsa 1
                    if {$objValue != ""} {
                      set tsaType [$objValue Type]
                      set tsaID   [$objValue P21ID]
                    } else {
                      set oktsa 0
                      set msg "Syntax Error: Missing 'toleranced_shape_aspect' attribute on [formatComplexEnt $objType]$spaces\($recPracNames(pmi242), Sec. 6.9)"
                      errorMsg $msg
                      lappend syntaxErr([lindex [split $ent1 " "] 0]) [list [$gtEntity P21ID] [lindex [split $ent1 " "] 1] $msg]
                    }

# get toleranced geometry
                    if {$oktsa} {
                      getAssocGeom $objValue

# check for all around
                      if {[$objValue Type] == "all_around_shape_aspect"} {
                        set ok 1
                        set idx "all_around"
                        set all_around 1
                        lappend spmiTypesPerFile $idx

# check for between
                      } elseif {[$objValue Type] == "between_shape_aspect"} {
                        set ok 1
                        set idx "between"
                        set between 1
                        lappend spmiTypesPerFile $idx
                      }
                    }
                  }
                  "*_tolerance* magnitude" {
# check that the tolerance magnitude is a length_measure_with_unit
                    if {$objValue != ""} {
                      set magType [$objValue Type]
                      if {[string first "length_measure_with_unit" $magType] == -1 || ([string first "length_measure_with_unit" $magType] != [string last "length_measure_with_unit" $magType])} {
                        set msg "Syntax Error: Wrong type of tolerance value on [formatComplexEnt [$gtEntity Type]]: [formatComplexEnt $magType]$spaces\($recPracNames(pmi242), Sec. 6.9.1, Figure 43)"
                        errorMsg $msg
                        lappend syntaxErr([lindex [split $ent1 " "] 0]) [list [$gtEntity P21ID] [lindex [split $ent1 " "] 1] $msg]
                      }

# check for missing magnitude and possibly non-uniform tolerance zone
                    } else {
                      set nonUniform 0
                      set e0s [$gtEntity GetUsedIn [string trim tolerance_zone] [string trim defining_tolerance]]
                      ::tcom::foreach e0 $e0s {
                        set e1s [$e0 GetUsedIn [string trim non_uniform_zone_definition] [string trim zone]]
                        ::tcom::foreach e1 $e1s {
                          set tol [$gtEntity Type]
                          set c1 [string first "_tolerance" $tol]
                          set tname [string range $tol 0 $c1-1]
                          if {[info exists pmiUnicode($tname)]} {set tname $pmiUnicode($tname)}
                          set objValue "$tname | NON-UNIFORM"
                          lappend spmiTypesPerFile "non-uniform tolerance zone"
                          set colName "GD&T[format "%c" 10]Annotation"
                          set col($gt) $pmiStartCol($gt)
                          set ok 1
                          set nonUniform 1
                        }
                      }
                      if {!$nonUniform} {
                        set msg "Syntax Error: Missing tolerance 'magnitude' on [formatComplexEnt [$gtEntity Type]]$spaces\($recPracNames(pmi242), Sec. 6.9.1, Figure 43)"
                        errorMsg $msg
                        lappend syntaxErr([lindex [split $ent1 " "] 0]) [list [$gtEntity P21ID] [lindex [split $ent1 " "] 1] $msg]
                      }
                    }

# check for ASME Y14.5:2018 and removed tolerances
                    if {[string first "concentricity" $ent1] != -1 || [string first "symmetry" $ent1] != -1} {
                      foreach std $tolStandards {
                        if {[string first "Y14.5" $std] != -1 && [string first "2018" $std] != -1} {errorMsg "[$gtEntity Type] is no longer valid in $std"}
                      }
                    }
                  }
                  "plane_angle_measure_with_unit* value_component" -
                  "length_measure_with_unit* value_component" {

# datum reference modifier (not commonly used)
                    if {[info exists datumModValue]} {
                      if {$datumModValue != ""} {
                        set val [trimNum $objValue 3]
                        if {[string index $val end] == "."} {set val [string range $val 0 end-1]}
                        append datumModValue $val
                      }
                    }

# get tolerance zone form, usually 'cylindrical or circular', 'spherical'
                    set tzf  ""
                    set tzf1 ""
                    set ptz  ""
                    set objGuiEntities [$gtEntity GetUsedIn [string trim tolerance_zone] [string trim defining_tolerance]]
                    ::tcom::foreach objGuiEntity $objGuiEntities {
                      ::tcom::foreach attrTZ [$objGuiEntity Attributes] {
                        if {[$attrTZ Name] == "form"} {
                          ::tcom::foreach attrTZF [[$attrTZ Value] Attributes] {
                            if {[$attrTZF Name] == "name"} {
                              set tzfName [$attrTZF Value]
                              if {[lsearch $tzfNames $tzfName] != -1} {

# tzf symbol
                                set tzfName1 $tzfName
                                if {$tzfName1 == "spherical" || $tzfName1 == "within a sphere"} {set tzfName1 "spherical diameter"}
                                if {[info exists pmiUnicode($tzfName1)]} {set tzf $pmiUnicode($tzfName1)}

# invalid tzf
                              } else {
                                set msg ""
                                if {$tzfName != ""} {
                                  set msg "Syntax Error: Bad tolerance_zone_form 'name' attribute ($tzfName) on [formatComplexEnt [$gtEntity Type]]$spaces\($recPracNames(pmi242), Sec. 6.9.2, Tables 11, 12)"
                                  errorMsg $msg
                                  set invalid $msg
                                  lappend syntaxErr(tolerance_zone_form) [list [[$attrTZ Value] P21ID] "name" $msg]
                                  set tzf1 "(Invalid TZF: $tzfName)"
                                } elseif {$tzfName == ""} {
                                  set msg "Syntax Error: Missing tolerance_zone_form 'name' attribute.$spaces\($recPracNames(pmi242), Sec. 6.9.2, Tables 11, 12)"
                                  errorMsg $msg
                                  lappend syntaxErr(tolerance_zone_form) [list [[$attrTZ Value] P21ID] "name" $msg]
                                }
                              }

                              if {$tzfName == "cylindrical or circular"} {
                                lappend spmiTypesPerFile "tolerance zone diameter"
                              } elseif {$tzfName == "spherical"} {
                                lappend spmiTypesPerFile "tolerance zone spherical diameter"
                              } elseif {$tzfName == "within a cylinder"} {
                                lappend spmiTypesPerFile "tolerance zone $tzfName"
                              } else {
                                lappend spmiTypesPerFile "tolerance zone other"
                              }

# only these tolerances allow a tolerance zone form for diameters
                              if {[string first "diameter" [string tolower $tzfName]] != -1} {
                                set ok1 0
                                foreach item {"position" "perpendicularity" "parallelism" "angularity" "coaxiality" "concentricity" "straightness"} {
                                  set gtol "$item\_tolerance"
                                  if {[string first $gtol [$gtEntity Type]] != -1} {set ok1 1}
                                }
                                if {$ok1 == 0 && [string tolower $tzfName] != "unknown"} {
                                  set tolType [$gtEntity Type]
                                  foreach item $tolNames {if {[string first [$gtEntity Type] $item] != -1} {set tolType $item}}
                                  set msg "Syntax Error: Tolerance zones are not allowed with [formatComplexEnt $tolType].$spaces\($recPracNames(pmi242), Sec. 6.9.2)"
                                  errorMsg $msg
                                  lappend syntaxErr(tolerance_zone_form) [list [[$attrTZ Value] P21ID] "name" $msg]
                                }
                              }
                            }
                          }
                        }
                      }

# get projected tolerance zone
                      set e0s [$objGuiEntity GetUsedIn [string trim projected_zone_definition] [string trim zone]]
                      ::tcom::foreach e0 $e0s {
                        ::tcom::foreach a0 [$e0 Attributes] {

# length
                          if {[$a0 Name] == "projected_length"} {
                            ::tcom::foreach a1 [[$a0 Value] Attributes] {
                              if {[$a1 Name] == "value_component"} {
                                set ptz [$a1 Value]
                                if {$ptz < 0.} {
                                  set msg "Syntax Error: Negative projected tolerance zone: $ptz$spaces\($recPracNames(pmi242), Sec. 6.9.2.2)"
                                  errorMsg $msg
                                  lappend syntaxErr(projected_zone_definition) [list [$e0 P21ID] "projected_length" $msg]
                                }
                              }
                            }

# projection_end
                          } elseif {[$a0 Name] == "projection_end"} {
                            set msg ""
                            if {[$a0 Value] != ""} {
                              set e1 [$a0 Value]
                              set e2s [$e1 GetUsedIn [string trim geometric_item_specific_usage] [string trim definition]]
                              set ngisu 0
                              ::tcom::foreach e2 $e2s {
                                incr ngisu
                                set e3 [[[$e2 Attributes] Item [expr 5]] Value]
                                set e3type [$e3 Type]
                                if {$e3type != "advanced_face" && $e3type != "edge_curve" && $e3type != "edge_loop" && $e3type != "path"} {
                                  set msg "Syntax Error: Projected tolerance zone 'projection_end' refers to invalid GISU identified_item '$e3type'.$spaces\($recPracNames(pmi242), Sec. 6.9.2.2)"
                                }
                                set e4 [[[$e3 Attributes] Item [expr 3]] Value]
                                errorMsg "Projected tolerance zone 'projection_end' refers to a '[$e4 Type]' through GISU ($recPracNames(pmi242), Sec. 6.9.2.2)"
                              }
                              if {$ngisu == 0 && [$e1 Type] == "shape_aspect"} {
                                set msg "Syntax Error: projection_end attribute '[$e1 Type]' is not referred to by a GISU.$spaces\($recPracNames(pmi242), Sec. 6.9.2.2)"
                              }
                            } else {
                              set msg "Syntax Error: Missing required 'projection_end' attribute on 'projected_zone_definition'.$spaces\($recPracNames(pmi242), Sec. 6.9.2.2)"
                            }
                            if {$msg != ""} {
                              errorMsg $msg
                              lappend syntaxErr(projected_zone_definition) [list [$e0 P21ID] "projection_end" $msg]
                              set ptzError 1
                            }
                          }
                        }
                      }
                    }

# get directed or oriented tolerance zone (AP242e2 for ISO 1101 intersection and orientation plane)
                    foreach tz [list directed oriented] {
                      set e0s [$gtEntity GetUsedIn [string trim $tz\_tolerance_zone] [string trim defining_tolerance]]
                      ::tcom::foreach e0 $e0s {
                        set ds [[[$e0 Attributes] Item [expr 7]] Value]
                        ::tcom::foreach attr [$e0 Attributes] {if {[$attr Name] == "direction" || [$attr Name] == "orientation"} {set dir [$attr Value]}}
                        if {$tz == "oriented"} {
                          set e1 [[[$e0 Attributes] Item [expr 9]] Value]
                          set angle [trimNum [[[$e1 Attributes] Item [expr 1]] Value]]
                        }
                        if {[info exists pmiUnicode($dir)]} {
                          set tzWithDatum($tz) "\u25C1 $pmiUnicode($dir) | $datumSystem([$ds P21ID])"
                          lappend spmiTypesPerFile "intersection/orientation plane indicator"
                          if {$tz == "oriented"} {
                            append tzWithDatum($tz) " \u25B7 \[$angle$pmiUnicode(degree)\]"
                          }
                        } else {
                          set msg "Syntax Error: Bad orientation attribute '$dir' on '$tz\_tolerance_zone'."
                          errorMsg $msg
                          lappend syntaxErr($tz\_tolerance_zone) [list [$e0 P21ID] "orientation" $msg]
                        }
                      }
                    }

                    set col($gt) $pmiStartCol($gt)

# set tolerance symbol from pmiUnicode for the geometric tolerance
                    if {$ATR(1) == "magnitude"} {
                      set ok 1
                      foreach tol $tolNames {
                        if {[string first $tol $gt] != -1} {
                          set c1 [string first "_tolerance" $tol]
                          set tname [string range $tol 0 $c1-1]
                          if {[info exists pmiUnicode($tname)]} {set tname $pmiUnicode($tname)}
                          if {[info exists dim(unit)]} {
                            if {$dim(unit) == "INCH"} {
                              if {$objValue < 1} {set objValue [string range $objValue 1 end]}
                            }
                          }

# truncate tolerance zone magnitude value
                          if {[getPrecision $objValue] > 6} {set objValue [string trimright [format "%.6f" $objValue] "0"]}
                          if {$objValue == 0.} {set objValue 0}
                          set tolval $objValue
                          set objValue "$tname | $tzf$objValue"

# add projected zone magnitude value
                          if {$ptz != ""} {
                            set idx "projected"
                            append objValue " $pmiModifiers($idx) $ptz"
                            lappend spmiTypesPerFile $idx
                          }
                        }
                      }

# get unequally disposed displacement value
                    } elseif {$ATR(1) == "displacement" && [string first "unequally_disposed" $gt] != -1} {
                      set ok 1
                      set idx "unequally_disposed"
                      if {$tolStandard(type) != "ISO"} {
                        set objValue " $pmiModifiers($idx) $objValue"
                      } else {
                        set objValue " UZ $objValue"
                      }
                      lappend spmiTypesPerFile $idx

# get ASME unit basis (ISO restricted area) tolerance value (6.9.6)
                    } elseif {$ATR(1) == "unit_size"} {
                      set ok 1
                      if {[string range $objValue end-1 end] == ".0"} {set objValue [string range $objValue 0 end-2]}
                      if {$objValue == 0.} {
                        set msg "Syntax Error: Tolerance unit-basis size = 0 for [formatComplexEnt $gt]$spaces\($recPracNames(pmi242), Sec. 6.9.6)"
                        errorMsg $msg
                        lappend syntaxErr([$gtEntity Type]) [list [$gtEntity P21ID] $ATR(1) $msg]
                      }
                      set objValue " / $objValue"
                      set idx "unit-basis tolerance"
                      lappend spmiTypesPerFile $idx
                    } elseif {$ATR(1) == "second_unit_size"} {
                      set ok 1
                      if {[string range $objValue end-1 end] == ".0"} {set objValue [string range $objValue 0 end-2]}
                      if {$objValue == 0.} {
                        set msg "Syntax Error: Tolerance second unit size = 0 for [formatComplexEnt $gt]$spaces\($recPracNames(pmi242), Sec. 6.9.6)"
                        errorMsg $msg
                        lappend syntaxErr([$gtEntity Type]) [list [$gtEntity P21ID] $ATR(1) $msg]
                      }
                      set objValue "X $objValue"
                      if {[string first "angle" $ent1] != -1} {append objValue $pmiUnicode(degree)}

# get maximum tolerance value (6.9.5)
                    } elseif {$ATR(1) == "maximum_upper_tolerance"} {
                      set ok 1
                      set objValue "$tzf$objValue MAX"
                      set idx "tolerance with max value"
                      lappend spmiTypesPerFile $idx
                    }

                    set colName "GD&T[format "%c" 10]Annotation"
                  }
                }

# write to spreadsheet
                if {$ok && [info exists spmiID]} {
                  set c [string index [cellRange 1 $col($gt)] 0]
                  set r $spmiIDRow($gt,$spmiID)

# column name
                  if {![info exists pmiHeading($col($gt))]} {
                    if {[info exists colName]} {
                      $cells($gt) Item 3 $c $colName
                      if {[string first "GD&T" $colName] != -1} {
                        set comment "See Help > User Guide (section 6.9) for an explanation of how the annotations below are constructed."
                        append comment "\n\nThe geometric tolerance might be shown with associated dimensions (above) and datum features (below).  That depends on any of the two referring to the same Associated Geometry as the Toleranced Geometry in the column to the right.  See the Associated Geometry columns on the 'dimensional_characteristic_representation' (DCR) and 'datum_feature' worksheets to see if they match the Toleranced Geometry."
                        append comment "\n\nSee the DCR worksheet for an explanation of Repetitive Dimensions."
                        if {$nistName != ""} {
                          append comment "\n\nSee the PMI Representation Summary worksheet to see how the GD&T Annotation below compares to the expected PMI."
                        }
                        addCellComment $gt 3 $c $comment
                      }
                    }
                    set pmiHeading($col($gt)) 1
                    set pmiCol [expr {max($col($gt),$pmiCol)}]
                  }

# keep track of rows with PMI properties
                  if {[lsearch $spmiRow($gt) $r] == -1} {lappend spmiRow($gt) $r}
                  if {$invalid != ""} {lappend syntaxErr($gt) [list "-$r" $col($gt) $invalid]}

# value in spreadsheet
                  set val [[$cells($gt) Item $r $c] Value]

                  if {$val == ""} {
                    $cells($gt) Item $r $c $objValue
                    if {$gt == "datum_system"} {
                      set idx [string trim [expr {int([[$cells($gt) Item $r 1] Value])}]]
                      set datumSystem($idx) $objValue
                    }
                  } else {

# all around
                    if {[info exists all_around]} {
                      $cells($gt) Item $r $c  "$pmiModifiers(all_around) | $val"
                      unset all_around
# unit basis rectangle
                    } elseif {[string first "X" $objValue] == 0} {
                      if {[string first "/ $pmiUnicode(diameter)" $val] == -1} {
                        if {[string first "X" $val] == -1} {
                          $cells($gt) Item $r $c "$val $objValue"
                        } else {
                          errorMsg "Specifying a 'second_unit_size' for a square 'area_type' is redundant."
                        }
                      }
# unequally disposed
                    } elseif {[string first $pmiModifiers(unequally_disposed) $objValue] == -1 && [string first "UZ" $objValue] == -1 && $ATR(1) != "unit_size"} {
                      if {[string first "handle" $objValue] == -1} {$cells($gt) Item $r $c "$val | $objValue"}

# all others
                    } else {
                      $cells($gt) Item $r $c "$val$objValue"
                    }
                    if {$gt == "datum_system"} {
                      set idx [string trim [expr {int([[$cells($gt) Item $r 1] Value])}]]
                      set datumSystem($idx) "$val | $objValue"
                    }
                  }

# keep track of max column
                  set pmiCol [expr {max($col($gt),$pmiCol)}]
                }
              }

# if referred to another, get the entity
              if {[string first "handle" $objValue] != -1} {
                if {[catch {
                  [$objValue Type]
                  set errstat [spmiGeotolReport $objValue]
                  if {$errstat} {break}
                } emsg1]} {

# referred entity is actually a list of entities
                  if {[catch {
                    ::tcom::foreach val1 $objValue {spmiGeotolReport $val1}
                  } emsg2]} {
                    foreach val2 $objValue {spmiGeotolReport $val2}
                  }
                }
              }
            }
          } emsg3]} {
            set msg "ERROR processing Semantic PMI ($objNodeType $ent2): $emsg3"
            errorMsg $msg
            lappend syntaxErr([lindex $ent1 0]) [list $objID [lindex $ent1 1] $msg]
            set entLevel 1
          }

# --------------
# nodeType = 20
        } elseif {$objNodeType == 20} {
          if {[catch {
            if {$idx != -1} {
              if {$opt(DEBUG1)} {outputMsg "$ind   ATR $entLevel $objName - $objValue ($objNodeType-[$objAttribute AggNodeType], $objSize, $objAttrType)"}

              if {[info exists cells($gt)]} {
                set ok 0
                set invalid ""

                switch -glob $ent1 {
                  "datum_reference_compartment modifiers" -
                  "datum_reference_element modifiers" -
                  "*geometric_tolerance_with_modifiers* modifiers" -
                  "*geometric_tolerance_with_maximum_tolerance* modifiers" {

# get datum or tolerance modifiers
                    set modlim 5
                    if {$objSize > $modlim} {
                      set msg "Possible Error: More than $modlim datum or tolerance modifiers"
                      errorMsg $msg
                      lappend syntaxErr([lindex [split $ent1 " "] 0]) [list [$gtEntity P21ID] [lindex [split $ent1 " "] 1] $msg]
                    }
                    set col($gt) $pmiStartCol($gt)
                    set nval ""
                    set datumModValue ""
                    foreach val $objValue {
                      if {[string first "handle" $val] == -1} {
                        if {[info exists pmiModifiers($val)]} {
                          if {[string first "degree_of_freedom_constraint" $val] != -1} {
                            lappend dofModifier $pmiModifiers($val)
                          } else {
                            append nval " $pmiModifiers($val)"
                          }
                          set ok 1
                          if {[string first $gt $ent1] == 0} {lappend spmiTypesPerFile $val}

                          if {[string first "_material_condition" $val] != -1 && [string first "AP242" $stepAP] == 0} {
                            if {[string first "max" $val] == 0} {
                              set msg "Syntax Error: Use 'maximum_material_requirement' instead of 'maximum_material_condition' for PMI Representation in AP242 files.$spaces\($recPracNames(pmi242), Sec. 6.9.3)"
                              errorMsg $msg
                              lappend syntaxErr([lindex [split $ent1 " "] 0]) [list [$gtEntity P21ID] [lindex [split $ent1 " "] 1] $msg]
                            } elseif {[string first "least" $val] == 0} {
                              set msg "Syntax Error: Use 'least_material_requirement' instead of 'least_material_condition' for PMI Representation in AP242 files.$spaces\($recPracNames(pmi242), Sec. 6.9.3)"
                              errorMsg $msg
                              lappend syntaxErr([lindex [split $ent1 " "] 0]) [list [$gtEntity P21ID] [lindex [split $ent1 " "] 1] $msg]
                            }
                          }
                        } else {
                          if {$val != ""} {append nval " \[$val\]"}
                          set ok 1
                          set msg "Syntax Error: Datum reference frame modifier '$val' is not supported.$spaces\($recPracNames(pmi242), Sec. 6.9.7)"
                          errorMsg $msg
                          lappend syntaxErr([lindex [split $ent1 " "] 0]) [list [$gtEntity P21ID] [lindex [split $ent1 " "] 1] $msg]
                        }

# reference to datum_reference_modifier_with_value
                      } else {
                        set datumModValue "\["
                        lappend spmiTypesPerFile "datum with modifiers (6.9.7)"
                        if {[catch {
                          ::tcom::foreach val1 $val {spmiGeotolReport $val1}
                        } emsg2]} {
                          foreach val2 $val {spmiGeotolReport $val2}
                        }
                        append datumModValue "\]"
                        set ok 1
                      }
                    }

# DOF modifier
                    if {[info exists dofModifier]} {
                      set dofModifier [join [lsort $dofModifier] ","]
                      set dofModifier " \[$dofModifier\]"
                      append nval $dofModifier
                      unset dofModifier
                    }
                    set objValue $nval

# add datum_reference_modifier_with_value
                    append objValue $datumModValue
                  }
                }

# value in spreadsheet
                if {$ok && [info exists spmiID]} {
                  set c [string index [cellRange 1 $col($gt)] 0]
                  set r $spmiIDRow($gt,$spmiID)

# column name
                  if {![info exists pmiHeading($col($gt))]} {
                    if {[info exists colName]} {$cells($gt) Item 3 $c $colName}
                    set pmiHeading($col($gt)) 1
                    set pmiCol [expr {max($col($gt),$pmiCol)}]
                  }

# keep track of rows with PMI properties
                  if {[lsearch $spmiRow($gt) $r] == -1} {lappend spmiRow($gt) $r}
                  if {$invalid != ""} {lappend syntaxErr($gt) [list "-$r" $col($gt) $invalid]}

# write tolerance with modifier
                  set ov $objValue
                  set val [[$cells($gt) Item $r $c] Value]

                  if {$val == ""} {
                    $cells($gt) Item $r $c $ov
                    if {$gt == "datum_reference_compartment"} {
                      set idx [string trim [expr {int([[$cells($gt) Item $r 1] Value])}]]
                      set datumCompartment($idx) $ov
                    }
                  } else {
                    if {[string first "modifiers" $ent1] != -1} {
                      set nval $val$ov
                      $cells($gt) Item $r $c $nval
                      if {$gt == "datum_reference_compartment"} {
                        set idx [string trim [expr {int([[$cells($gt) Item $r 1] Value])}]]
                        set datumCompartment($idx) $nval
                      }
                    } else {
                      $cells($gt) Item $r $c "$val[format "%c" 10]$ov"
                    }
                  }

# keep track of max column
                  set pmiCol [expr {max($col($gt),$pmiCol)}]
                }
              }

# -------------------------------------------------
# recursively get the entities that are referred to
              if {[catch {
                ::tcom::foreach val3 $objValue {spmiGeotolReport $val3}
              } emsg]} {
                foreach val4 $objValue {spmiGeotolReport $val4}
              }
            }
          } emsg3]} {
            set msg "ERROR processing Semantic PMI ($objNodeType $ent2): $emsg3"
            errorMsg $msg
            lappend syntaxErr([lindex $ent1 0]) [list $objID [lindex $ent1 1] $msg]
            set entLevel 1
          }

# ---------------------
# nodeType = 5 (!= 18,19,20)
        } else {
          if {[catch {
            if {$idx != -1} {
              if {$opt(DEBUG1)} {outputMsg "$ind   ATR $entLevel $objName - $objValue ($objNodeType, $objAttrType)  ($ent1)"}

              if {[info exists cells($gt)]} {
                set ok 0
                set colName ""
                set ov $objValue
                set invalid ""

# get values for these entity and attribute pairs
                switch -glob $ent1 {
                  "datum identification" {
# get the datum letter
                    set ok 1
                    set col($gt) $pmiStartCol($gt)
                    set c1 [string last "_" $gt]
                    if {$c1 != -1} {
                      set colName "[string range $gt $c1+1 end][format "%c" 10](Sec. 6.9.7, 6.9.8)"
                    } else {
                      set colName "Datum Identification"
                    }
                    set ov [string trim $ov]

# check all datum entities once
                    if {![info exists datumIDs]} {
                      ::tcom::foreach datum [$objDesign FindObjects [string trim datum]] {
                        set letter [[[$datum Attributes] Item [expr 5]] Value]
                        set id [$datum P21ID]

# check for multiple datum identification
                        if {[string length $letter] > 0} {
                          if {[info exists datumIDs]} {
                            if {[lsearch $datumIDs $letter] != -1} {
                              set msg "Multiple 'datum' entities use the same letter for the 'identification' attribute.  They should be unique."
                              errorMsg $msg
                              lappend syntaxErr(datum) [list $id identification $msg]
                            }
                          }
                          lappend datumIDs $letter

# check for datum identification with too many letters
                          set nlet 2
                          if {$tolStandard(type) == "ISO"} {set nlet 3}
                          if {![string is alpha $letter] || [string length $letter] > $nlet} {
                            set msg "Datum 'identification' attribute cannot be more than $nlet letters (no numbers) based on the tolerancing standard."
                            errorMsg $msg
                            lappend syntaxErr(datum) [list $id identification $msg]
                          }

# check for datum in SAR related_shape_aspect
                          set e1s [$datum GetUsedIn [string trim shape_aspect_relationship] [string trim related_shape_aspect]]
                          set n 0
                          ::tcom::foreach e1 $e1s {incr n}
                          if {$n == 0} {
                            set msg "Syntax Error: Datum is not referenced by 'related_shape_aspect' on 'shape_aspect_relationship'.$spaces\($recPracNames(pmi242), Sec. 6.5, Figure 35)"
                            errorMsg $msg
                            lappend syntaxErr(datum) [list $id ID $msg]
                          }

# missing identification
                        } else {
                          set msg "Syntax Error: Missing datum 'identification' attribute.$spaces\($recPracNames(pmi242), Sec. 6.5)"
                          errorMsg $msg
                          lappend syntaxErr(datum) [list $id identification $msg]
                        }
                      }
                    }
                  }
                  "common_datum identification" {
                    set common_datum ""
# common datum (A-B), not the recommended practice
                    set msg "Syntax Error: Use 'common_datum_list' instead of 'common_datum' for multiple datum features.$spaces\($recPracNames(pmi242), Sec. 6.9.8)"
                    errorMsg $msg
                    lappend syntaxErr([lindex [split $ent1 " "] 0]) [list $objID [lindex [split $ent1 " "] 1] $msg]
                    set e1s [$objEntity GetUsedIn [string trim shape_aspect_relationship] [string trim relating_shape_aspect]]
                    ::tcom::foreach e1 $e1s {
                      ::tcom::foreach a1 [$e1 Attributes] {
                        if {[$a1 Name] == "related_shape_aspect"} {
                          ::tcom::foreach a2 [[$a1 Value] Attributes] {
                            if {[$a2 Name] == "identification"} {
                              set val [$a2 Value]
                              if {$common_datum == ""} {
                                set common_datum $val
                              } else {
                                append common_datum "-$val"
                              }
                            }
                          }
                        }
                      }
                    }
                    set objValue $common_datum
                    set ok 1
                    set col($gt) $pmiStartCol($gt)
                    set c1 [string last "_" $gt]
                    if {$c1 != -1} {
                      set colName "[string range $gt $c1+1 end][format "%c" 10](Sec. 6.9.7, 6.9.8)"
                    } else {
                      set colName "Datum Identification"
                    }
                  }
                  "*datum_feature* name" {
# get datum feature, associated geometry, and symbol
                    if {[string first "datum_feature" [$gtEntity Type]] != -1} {
                      getAssocGeom $gtEntity
                      if {[info exists spmiIDRow($gt,$spmiID)]} {
                        set datumGeom [reportAssocGeom [$gtEntity Type] $spmiIDRow($gt,$spmiID)]
                      } else {
                        set datumGeom [reportAssocGeom [$gtEntity Type]]
                      }
                      set datumGeomEnts ""
                      foreach item [split $datumGeom "\n"] {
                        if {[string first "shape_aspect" $item] == -1 && \
                            [string first "advanced_face" $item] == -1 && \
                            [string first "centre_of_symmetry" $item] == -1 && \
                            [string first "datum_feature" $item] == -1} {lappend datumGeomEnts $item}
                      }
                      set datumGeomEnts [join [lsort $datumGeomEnts]]
                      set datumEntType($datumGeomEnts) "[formatComplexEnt [$gtEntity Type]] [$gtEntity P21ID]"

                      set e1s [$gtEntity GetUsedIn [string trim shape_aspect_relationship] [string trim relating_shape_aspect]]
                      ::tcom::foreach e1 $e1s {
                        if {[string first "relationship" [$e1 Type]] != -1} {
                          ::tcom::foreach a1 [$e1 Attributes] {
                            if {[$a1 Name] == "related_shape_aspect"} {
                              if {[catch {
                                ::tcom::foreach a2 [[$a1 Value] Attributes] {
                                  if {[$a2 Name] == "identification"} {set datumSymbol($datumGeomEnts) [$a2 Value]}
                                }
                              } emsg]} {
                                set msg "Syntax Error: Bad 'related_shape_aspect' attribute on 'shape_aspect_relationship'."
                                errorMsg $msg
                                lappend syntaxErr(shape_aspect_relationship) [list [$e1 P21ID] "related_shape_aspect" $msg]
                              }
                            }
                          }
                        }
                      }
                      if {[info exists datumSymbol($datumGeomEnts)]} {
                        set ok 1
                        set objValue $datumSymbol($datumGeomEnts)
                        set col($gt) $pmiStartCol($gt)
                        set colName "Datum[format "%c" 10](Sec. 6.5)"
                      }
                    }
                  }
                  "referenced_modified_datum modifier" {
# AP203 datum modifier method
                    if {[info exists pmiModifiers($objValue)]} {
                      set objValue " $pmiModifiers($objValue)"
                      lappend spmiTypesPerFile $objValue
                      set ok 1
                    } else {
                      if {$objValue != ""} {set objValue " \[$objValue\]"}
                      set ok 1
                      set msg "Syntax Error: Datum reference frame modifier '$objValue' is not supported.$spaces\($recPracNames(pmi242), Sec. 6.9.7)"
                      errorMsg $msg
                      lappend syntaxErr([lindex [split $ent1 " "] 0]) [list [$gtEntity P21ID] [lindex [split $ent1 " "] 1] $msg]
                    }
                  }
                  "placed_datum_target_feature description" -
                  "datum_target description" {
# datum target description (Section 6.6)
                    catch {unset datumTargetGeom}
                    set datumTargetType $ov
                    set oktarget 1

# check target type
                    set msg ""
                    set dtemsg "Syntax Error: Bad 'description' attribute ($ov) on [$gtEntity Type].$spaces\($recPracNames(pmi242), Sec. 6.6.1, Table 9)"
                    if {[lsearch $datumTargetDesc $ov] != -1} {
                      lappend spmiTypesPerFile "$ov datum target (6.6)"
                      if {$nistName != ""} {lappend spmiTypesPerFile "all datum targets"}
                      if {[$gtEntity Type] == "datum_target" && $ov != "area" && $ov != "curve"} {set msg $dtmsg}
                    } else {
                      set msg $dtemsg
                    }
                    if {$msg != ""} {
                      errorMsg $msg
                      lappend syntaxErr([lindex [split $ent1 " "] 0]) [list $objID [lindex [split $ent1 " "] 1] $msg]
                    }

# placed datum target feature geometry (feature_for_datum_target_relationship)
                    if {[$gtEntity Type] == "placed_datum_target_feature"} {
                      set e0s [$gtEntity GetUsedIn [string trim feature_for_datum_target_relationship] [string trim related_shape_aspect]]
                      ::tcom::foreach e0 $e0s {
                        ::tcom::foreach a0 [$e0 Attributes] {
                          if {[$a0 Name] == "relating_shape_aspect"} {
                            set e1 [$a0 Value]
                            set e1s [$e1 GetUsedIn [string trim geometric_item_specific_usage] [string trim definition]]
                            ::tcom::foreach e1 $e1s {
                              ::tcom::foreach a1 [$e1 Attributes] {
                                if {[$a1 Name] == "identified_item"} {
                                  set e2 [$a1 Value]
                                  append datumTargetGeom "[$e2 Type] [$e2 P21ID]"

# save datum target feature geometric entity for view
                                  set datumTargetView([$gtEntity P21ID]-feature) [list $e2]
                                }
                              }
                            }
                          }
                        }
                      }

# check optional datum target feature (geometry)
                      if {[info exists datumTargetGeom]} {
                        set ok 1
                        set col($gt) [expr {$pmiStartCol($gt)+2}]
                        set colName "Target Feature[format "%c" 10](Sec. 6.6.2)"
                        set objValue $datumTargetGeom
                        lappend spmiTypesPerFile "placed datum target geometry (6.6.2)"

# bad feature for a point
                        if {$ov == "point" && [string first "advanced_face" $datumTargetGeom] != -1} {
                          set msg "Target feature for a 'point' datum target should not be a 'face'."
                          errorMsg $msg
                          lappend syntaxErr([$gtEntity Type]) [list [$gtEntity P21ID] "Target Feature" $msg]
                        }
                      }

# datum target geometry
                    } elseif {[$gtEntity Type] == "datum_target"} {
                      set e1s [$gtEntity GetUsedIn [string trim geometric_item_specific_usage] [string trim definition]]
                      ::tcom::foreach e1 $e1s {
                        ::tcom::foreach a1 [$e1 Attributes] {
                          if {[$a1 Name] == "identified_item"} {
                            set e2 [$a1 Value]
                            append datumTargetGeom "[$e2 Type] [$e2 P21ID]"

# save datum target geometric entity for view
                            set datumTargetView([$gtEntity P21ID]) [list $e2]
                          }
                        }
                      }
                      if {[info exists datumTargetGeom]} {
                        set ok 1
                        set col($gt) [expr {$pmiStartCol($gt)+2}]
                        set colName "Target Geometry[format "%c" 10](Sec. 6.6.1)"
                        set objValue $datumTargetGeom
                      } elseif {$ov == "curve" || $ov == "area"} {
                        set msg "Syntax Error: Missing '$ov' target geometry for [$gtEntity Type].$spaces\($recPracNames(pmi242), Sec. 6.6.1)"
                        errorMsg $msg
                        lappend syntaxErr(datum_target) [list $objID "Target Geometry" $msg]
                      }
                    }
                  }
                  "placed_datum_target_feature target_id" -
                  "datum_target target_id" {
# datum target IDs (Section 6.6)
                    if {![string is integer $ov]} {
                      set msg "Syntax Error: Only integers are valid for datum target 'target_id'.$spaces\($recPracNames(pmi242), Sec. 6.6)"
                      errorMsg $msg
                      lappend syntaxErr([lindex [split $ent1 " "] 0]) [list $objID [lindex [split $ent1 " "] 1] $msg]
                    }
                    set e1s [$objEntity GetUsedIn [string trim shape_aspect_relationship] [string trim relating_shape_aspect]]
                    ::tcom::foreach e1 $e1s {
                      if {[string first "relationship" [$e1 Type]] != -1} {
                        ::tcom::foreach a1 [$e1 Attributes] {
                          if {[$a1 Name] == "related_shape_aspect"} {
                            ::tcom::foreach a2 [[$a1 Value] Attributes] {
                              if {[$a2 Name] == "identification"} {
                                set datumTarget "[$a2 Value]$ov"

# add datumTarget to datumTargetView
                                if {[info exists datumTargetView([$gtEntity P21ID])]} {
                                  if {[string first "handle" [lindex $datumTargetView([$gtEntity P21ID]) 0]] != -1} {
                                    lappend datumTargetView([$gtEntity P21ID]) $datumTarget
                                  }
                                }
                                if {[info exists datumTargetView([$gtEntity P21ID]-feature)]} {
                                  lappend datumTargetView([$gtEntity P21ID]-feature) $datumTarget
                                }
                              }
                            }
                          }
                        }
                      }
                    }

                    set ok 1
                    if {[info exists datumTarget]} {
                      set col($gt) $pmiStartCol($gt)
                      set colName "Datum Target[format "%c" 10](Sec. 6.6)"
                      if {$datumTargetType != "circle" && $datumTargetType != "rectangle"} {
                        set objValue "$datumTarget ($datumTargetType)"
                      } else {
                        set objValue "$datumTarget"
                      }
                    } else {
                      set msg "Syntax Error: Missing shape_aspect_relationship to 'datum' for [$objEntity Type].$spaces\($recPracNames(pmi242), Sec. 6.6)"
                      errorMsg $msg
                      lappend syntaxErr(placed_datum_target_feature) [list $objID "Datum Target" $msg]
                    }

# datum target shape representation (Section 6.6.1)
                    set datumTargetRep ""
                    set ndtv 0
                    if {[$gtEntity Type] == "placed_datum_target_feature"} {
                      if {[catch {
                        set nval 0
                        set e1s [$objEntity GetUsedIn [string trim property_definition] [string trim definition]]
                        ::tcom::foreach e1 $e1s {
                          set e2s [$e1 GetUsedIn [string trim shape_definition_representation] [string trim definition]]
                          ::tcom::foreach e2 $e2s {
                            set a2 [[$e2 Attributes] Item [expr 2]]
                            set e3 [$a2 Value]

# values in shape_representation_with_parameters
                            if {[$e3 Type] == "shape_representation_with_parameters"} {
                              set a3 [[$e3 Attributes] Item [expr 2]]
                              ::tcom::foreach e4 [$a3 Value] {

# get datum target position first
                                if {[$e4 Type] == "axis2_placement_3d"} {
                                  set a4 [[$e4 Attributes] Item [expr 1]]
                                  if {[$a4 Value] != "orientation"} {
                                    set msg "Syntax Error: Bad 'name' ([$a4 Value]) on axis2_placement_3d for a placed datum target, must be 'orientation'.$spaces\($recPracNames(pmi242), Sec. 6.6.1)"
                                    errorMsg $msg
                                    lappend syntaxErr(axis2_placement_3d) [list [$e4 P21ID] name $msg]
                                  }

# origin
                                  set axisval [x3dGetA2P3D $e4]
                                  set origin [vectrim [lindex $axisval 0] 1]
                                  append datumTargetRep "[format "%c" 10]axis2_placement_3d [$e4 P21ID]"
                                  append datumTargetRep "[format "%c" 10]  origin  $origin"

# check if values are ok
                                  set msg ""
                                  if {$origin == "0. 0. 0."} {
                                    append msg "[string totitle $datumTargetType] datum target located at '0 0 0'  "
                                  }
                                  set axis   [lindex $axisval 1]
                                  set refdir [lindex $axisval 2]
                                  if {[veclen $axis] == 0 || [veclen $refdir] == 0} {
                                    append msg "Syntax Error: The orientation axis or ref_direction vector is '0 0 0' for a $datumTargetType datum target.  "
                                  } elseif {[veclen [veccross $axis $refdir]] == 0} {
                                    append msg "Syntax Error: The orientation axis and ref_direction vectors are congruent for a $datumTargetType datum target.  "
                                  }
                                  if {$msg != ""} {
                                    set msg [string trim $msg]
                                    errorMsg $msg
                                    lappend syntaxErr([$gtEntity Type]) [list [$gtEntity P21ID] "Target Representation" $msg]
                                  }

# point datum target view
                                  if {$datumTargetType == "point"} {set datumTargetView([$gtEntity P21ID]) [list $datumTargetType $axisval $datumTarget]}
                                }
                              }

# datum target dimensions - length_measure
                              ::tcom::foreach e4 [$a3 Value] {
                                if {[string first "length_measure_with_unit_and_measure_representation_item" [$e4 Type]] != -1} {
                                  ::tcom::foreach a4 [$e4 Attributes] {
                                    if {[$a4 Name] == "name"} {
                                      set datumTargetName [$a4 Value]
                                      regsub -all "  " $datumTargetName " " datumTargetName
                                      append datumTargetRep "[format "%c" 10]$datumTargetName   $datumTargetValue"

# bad target attributes
                                      set msg ""
                                      if {$datumTargetType == "line" && $datumTargetName != "target length"} {
                                        set msg "Syntax Error: Bad datum target 'name' ($datumTargetName) on [formatComplexEnt [$e4 Type]], use 'target length' for a '$datumTargetType' target$spaces\($recPracNames(pmi242), Sec. 6.6.1)"
                                      } elseif {$datumTargetType == "circle" && $datumTargetName != "target diameter"} {
                                        set msg "Syntax Error: Bad datum target 'name' ($datumTargetName) on [formatComplexEnt [$e4 Type]], use 'target diameter' for a '$datumTargetType' target$spaces\($recPracNames(pmi242), Sec. 6.6.1)"
                                      } elseif {$datumTargetType == "rectangle" && ($datumTargetName != "target length" && $datumTargetName != "target width")} {
                                        set msg "Syntax Error: Bad datum target 'name' ($datumTargetName) on [formatComplexEnt [$e4 Type]], use 'target length' or 'target width' for a '$datumTargetType' target$spaces\($recPracNames(pmi242), Sec. 6.6.1)"
                                      } elseif {$datumTargetType == "point"} {
                                        set msg "Syntax Error: No length_measure attribute on shape_representation_with_parameters is required for a 'point' datum target$spaces\($recPracNames(pmi242), Sec. 6.6.1)"

# add target dimensions to PMI
                                      } else {
                                        set dtv $datumTargetValue
                                        if {[string range $dtv end-1 end] == ".0"} {set dtv [string range $dtv 0 end-2]}
                                        if {$datumTargetType == "circle"} {
                                          set objValue $pmiUnicode(diameter)$dtv[format "%c" 10]$objValue
                                        } elseif {$datumTargetType == "line"} {
                                          append objValue "[format "%c" 10](L = [trimNum $dtv])"
                                        } elseif {$datumTargetType == "circular curve"} {
                                          append objValue "[format "%c" 10](D = [trimNum $dtv])"

# rectangular, smaller value first
                                        } elseif {$datumTargetType == "rectangle"} {
                                          incr ndtv
                                          if {$ndtv == 1} {
                                            set dtv1 $dtv
                                          } elseif {$ndtv == 2} {
                                            if {$dtv > $dtv1} {
                                              append dtv1 "x$dtv"
                                            } else {
                                              set dtv1 "$dtv\x$dtv1"
                                            }
                                            set objValue $dtv1[format "%c" 10]$objValue
                                          }
                                        }
                                        if {$origin == "0. 0. 0."} {append objValue "[format "%c" 10](origin = 0 0 0)"}
                                      }

# save datum target for view
                                      if {[info exists axisval]} {
                                        if {$datumTargetType != "rectangle" || $ndtv == 1} {
                                          set datumTargetView([$gtEntity P21ID]) [list $datumTargetType $axisval [list $datumTargetName $dtv]]
                                          if {[info exists datumTarget] && $datumTargetType != "rectangle"} {lappend datumTargetView([$gtEntity P21ID]) $datumTarget}
                                        } elseif {$ndtv == 2} {
                                          lappend datumTargetView([$gtEntity P21ID]) [list $datumTargetName $dtv]
                                          if {[info exists datumTarget]} {lappend datumTargetView([$gtEntity P21ID]) $datumTarget}
                                        }
                                      }

# error message
                                      if {$msg != ""} {
                                        errorMsg $msg
                                        lappend syntaxErr([$gtEntity Type]) [list [$gtEntity P21ID] "Target Representation" $msg]
                                      }

# bad size
                                    } elseif {[$a4 Name] == "value_component"} {
                                      set datumTargetValue [$a4 Value]
                                      if {$datumTargetValue <= 0. && $datumTargetType != "point"} {
                                        set msg "Syntax Error: Datum target '$datumTargetType' dimension = 0$spaces\($recPracNames(pmi242), Sec. 6.6.1)"
                                        errorMsg $msg
                                        lappend syntaxErr([$gtEntity Type]) [list [$gtEntity P21ID] "Target Representation" $msg]
                                      }
                                    }
                                  }

# movable datum target direction (6.6.3)
                                } elseif {[$e4 Type] == "direction"} {
                                  ::tcom::foreach a4 [$e4 Attributes] {
                                    if {[$a4 Name] == "name"} {
                                      if {[$a4 Value] != "movable direction"} {
                                        set msg "Syntax Error: Bad 'name' ([$a4 Value]) on 'direction' for a movable datum target, must be 'movable direction'$spaces\($recPracNames(pmi242), Sec. 6.6.3)"
                                        errorMsg $msg
                                        lappend syntaxErr(direction) [list [$e4 P21ID] "name" $msg]
                                      }
                                    } elseif {[$a4 Name] == "direction_ratios"} {
                                      set dirrat [$a4 Value]
                                    }
                                  }
                                  append datumTargetRep "[format "%c" 10]movable target direction   $dirrat[format "%c" 10]   (direction [$e4 P21ID])"
                                  lappend spmiTypesPerFile "movable datum target"
                                  append objValue " (movable)"

# bad items
                                } elseif {[$e4 Type] != "axis2_placement_3d"} {
                                  set msg "Syntax Error: Bad 'item' ([formatComplexEnt [$e4 Type]]) on shape_representation_with_parameters for a datum target$spaces\($recPracNames(pmi242), Sec. 6.6)"
                                  errorMsg $msg
                                  lappend syntaxErr(shape_representation_with_parameters) [list [$e3 P21ID] "item" $msg]
                                }
                              }
                            }
                          }
                        }

# missing target length, width, or diameter
                        if {$datumTargetType == "line" || $datumTargetType == "rectangle"} {
                          if {[string first "target length" $datumTargetRep] == -1} {
                            set msg "Syntax Error: Missing 'target length' for '$datumTargetType' on [$gtEntity Type].$spaces\($recPracNames(pmi242), Sec. 6.6.1, Table 9)"
                            errorMsg $msg
                            lappend syntaxErr([$gtEntity Type]) [list [$gtEntity P21ID] "Target Representation" $msg]
                          }
                          if {$datumTargetType == "rectangle" && [string first "target width" $datumTargetRep] == -1} {
                            set msg "Syntax Error: Missing 'target width' for '$datumTargetType' on [$gtEntity Type].$spaces\($recPracNames(pmi242), Sec. 6.6.1, Table 9)"
                            errorMsg $msg
                            lappend syntaxErr([$gtEntity Type]) [list [$gtEntity P21ID] "Target Representation" $msg]
                          }
                        } elseif {$datumTargetType == "circle" || $datumTargetType == "circular curve"} {
                          if {[string first "target diameter" $datumTargetRep] == -1} {
                            set msg "Syntax Error: Missing 'target diameter' for '$datumTargetType' on [$gtEntity Type].$spaces\($recPracNames(pmi242), Sec. 6.6.1, Table 9)"
                            errorMsg $msg
                            lappend syntaxErr([$gtEntity Type]) [list [$gtEntity P21ID] "Target Representation" $msg]
                          }

# missing target representation
                        } elseif {[string first "." $datumTargetRep] == -1 && $datumTargetType != "area" && $datumTargetType != "curve"} {
                          set msg "Syntax Error: Missing target representation (shape_representation_with_parameters) for '$datumTargetType' on [$gtEntity Type].$spaces\($recPracNames(pmi242), Sec. 6.6.1, Figure 38)"
                          errorMsg $msg
                          set invalid $msg
                        }
                      } emsg]} {
                        errorMsg "ERROR processing datum target (placed_datum_target_feature): $emsg"
                      }
                    }
                  }
                  "product_definition_shape name" {
# all over
                    if {$ATR(1) == "toleranced_shape_aspect"} {
                      set ok 1
                      set all_over 1
                      set idx "all_over"
                      lappend spmiTypesPerFile $idx
                    }
                  }
                  "datum_reference_* name" {
# datum_reference_element or _compartment name attribute should be blank
                    if {$objValue != "" && [string first "datum_reference_" [$gtEntity Type]] != -1} {
                      set msg "The [$gtEntity Type] 'name' attribute should be blank."
                      errorMsg $msg
                      lappend syntaxErr([$gtEntity Type]) [list [$gtEntity P21ID] "name" $msg]
                    }
                  }
                  "datum_system product_definitional" -
                  "datum_reference_element product_definitional" -
                  "datum_reference_compartment product_definitional" {
# product_definitional should be false
                    if {$objValue == 1 && $objType == [lindex $ent1 0]} {
                      set msg "The $objType 'product_definitional' attribute should be FALSE."
                      errorMsg $msg
                      lappend syntaxErr($objType) [list $objID "product_definitional" $msg]
                    }
                  }
                  "*datum_feature* product_definitional"  {
# product_definitional should be true
                    if {$objValue == 0 && [$gtEntity Type] == [lindex $ent1 0]} {
                      set msg "The [$gtEntity Type] 'product_definitional' attribute should be TRUE."
                      errorMsg $msg
                      lappend syntaxErr([$gtEntity Type]) [list [$gtEntity P21ID] "product_definitional" $msg]
                    }
                  }
                  "*modified_geometric_tolerance* modifier" {
# AP203 get geotol modifier, not used in AP242
                    if {[string first "modified_geometric_tolerance" $objType] != -1 && [string first "AP242" $stepAP] == 0} {
                      set msg "Syntax Error: Use 'geometric_tolerance_with_modifiers' instead of 'modified_geometric_tolerance' for PMI Representation in AP242 files.$spaces\($recPracNames(pmi242), Sec. 6.9.3)"
                      errorMsg $msg
                      lappend syntaxErr($objType) [list 1 1 $msg]
                    }
                    set col($gt) $pmiStartCol($gt)
                    set nval ""
                    foreach val $objValue {
                      if {[info exists pmiModifiers($val)]} {
                        append nval " $pmiModifiers($val)"
                        set ok 1
                        lappend spmiTypesPerFile $val
                        if {[string first "_material_condition" $val] != -1 && [string first "AP242" $stepAP] == 0} {
                          if {[string first "max" $val] == 0} {
                            set msg "Syntax Error: Use 'maximum_material_requirement' instead of 'maximum_material_condition' for PMI Representation in AP242 files.$spaces\($recPracNames(pmi242), Sec. 6.9.3)"
                            errorMsg $msg
                            lappend syntaxErr([lindex [split $ent1 " "] 0]) [list [$gtEntity P21ID] [lindex [split $ent1 " "] 1] $msg]
                          } elseif {[string first "least" $val] == 0} {
                            set msg "Syntax Error: Use 'least_material_requirement' instead of 'least_material_condition' for PMI Representation in AP242 files.$spaces\($recPracNames(pmi242), Sec. 6.9.3)"
                            errorMsg $msg
                            lappend syntaxErr([lindex [split $ent1 " "] 0]) [list [$gtEntity P21ID] [lindex [split $ent1 " "] 1] $msg]
                          }
                        }
                      } else {
                        if {$val != ""} {append nval " \[$val\]"}
                        set ok 1
                        set msg "Syntax Error: [$gtEntity Type] modifier '$val' is not supported.$spaces\($recPracNames(pmi242), Sec. 6.9.3)"
                        errorMsg $msg
                        set invalid $msg
                      }
                    }
                    set objValue $nval
                  }
                  "*geometric_tolerance_with_defined_area_unit* area_type" {
# defined area unit, look for square, rectangle and add " X 0.whatever" to existing value
                    set ok 1
                    if {[lsearch [list square rectangular circular cylindrical spherical] $objValue] == -1} {
                      set msg "Syntax Error: Bad 'area_type' attribute ($objValue) on geometric_tolerance_with_defined_area_unit.$spaces\($recPracNames(pmi242), Sec. 6.9.6)"
                      errorMsg $msg
                      lappend syntaxErr([lindex [split $ent1 " "] 0]) [list [$gtEntity P21ID] [lindex [split $ent1 " "] 1] $msg]
                    }
                  }
                  "datum_reference_modifier_with_value modifier_type" {
                    if {$objValue == "circular_or_cylindrical"} {
                      append datumModValue $pmiUnicode(diameter)
                    } elseif {$objValue == "spherical"} {
                      append datumModValue "S"
                      append datumModValue $pmiUnicode(diameter)
                    } elseif {$objValue == "projected"} {
                      append datumModValue "\u24C5"
                    } elseif {$objValue != "distance"} {
                      set msg "Syntax Error: datum_reference_modifier_with_value modifier_type '$objValue' is not supported.$spaces\($recPracNames(pmi242), Sec. 6.9.7)"
                      errorMsg $msg
                      lappend syntaxErr([lindex [split $ent1 " "] 0]) [list [$gtEntity P21ID] [lindex [split $ent1 " "] 1] $msg]
                    }
                  }
                }

# value in spreadsheet
                if {$ok && [info exists spmiID]} {
                  set c [string index [cellRange 1 $col($gt)] 0]
                  set r $spmiIDRow($gt,$spmiID)

# column name
                  if {$colName != ""} {
                    if {![info exists pmiHeading($col($gt))]} {
                      $cells($gt) Item 3 $c $colName
                      set pmiHeading($col($gt)) 1
                      set pmiCol [expr {max($col($gt),$pmiCol)}]
                    }
                  }

# keep track of rows with semantic PMI
                  if {[lsearch $spmiRow($gt) $r] == -1} {lappend spmiRow($gt) $r}
                  if {$invalid != ""} {lappend syntaxErr($gt) [list "-$r" $col($gt) $invalid]}

                  set ov $objValue
                  set val [[$cells($gt) Item $r $c] Value]

                  if {$val == ""} {
                    $cells($gt) Item $r $c $ov
                    if {$gt == "datum_reference_compartment"} {
                      set idx [string trim [expr {int([[$cells($gt) Item $r 1] Value])}]]
                      set datumCompartment($idx) $ov
                    }
                  } else {
                    if {[info exists all_over]} {
                      $cells($gt) Item $r $c "$pmiModifiers(all_over) | $val"
                      errorMsg "The All Over symbol is approximated with $pmiModifiers(all_over) ($recPracNames(pmi242), Sec. 6.3)"
                      unset all_over

# common or multiple datum features (section 6.9.8)
                    } elseif {$ent1 == "datum identification"} {
                      if {$gt == "datum_reference_compartment"} {
                        set nval $val-$ov
                        lappend spmiTypesPerFile "multiple datum features"
                      } elseif {[string first "_tolerance" $gt] != -1} {
                        set nval "$val | $ov"
                      } else {
                        set nval $val$ov
                      }
                      $cells($gt) Item $r $c $nval
                      if {$gt == "datum_reference_compartment"} {
                        set idx [string trim [expr {int([[$cells($gt) Item $r 1] Value])}]]
                        set datumCompartment($idx) $nval
                      }
                    } elseif {$ent1 == "common_datum identification"} {
                      set nval "$val | $ov"
                      $cells($gt) Item $r $c $nval

# insert modifier (AP203)
                    } elseif {[string first "modified_geometric_tolerance" $ent1] != -1} {
                      set sval [split $val "|"]
                      lset sval 1 "[string trimright [lindex $sval 1]]$ov "
                      set nval [join $sval "|"]
                      $cells($gt) Item $r $c $nval

# append modifier
                    } elseif {[string first "modifier" $ent1] != -1 && $ov != "rectangular"} {
                      set nval $val$ov
                      $cells($gt) Item $r $c $nval

# area_type for defined area unit (unit basis, restricted area)
                    } elseif {$ov == "square"} {
                      set c1 [string last " " $val]
                      set nval "$val X [string range $val $c1+1 end]"
                      $cells($gt) Item $r $c $nval
                    } elseif {$ov == "circular"} {
                      regsub -all "/ " $val "/ $pmiUnicode(diameter)" nval
                      $cells($gt) Item $r $c $nval
                    } elseif {$ov != "rectangular" && $ov != "cylindrical" && $ov != "spherical"} {
                      $cells($gt) Item $r $c "$val[format "%c" 10]$ov"
                    }
                  }
# keep track of max column
                  set pmiCol [expr {max($col($gt),$pmiCol)}]
# datum target representation, add column
                  if {[$gtEntity Type] == "placed_datum_target_feature" && [info exists datumTargetRep]} {
                    if {$datumTargetRep != ""} {
                      set col($gt) [expr {$pmiStartCol($gt)+1}]
                      set colName "Target Representation[format "%c" 10](Sec. 6.6.1)"
                      set c [string index [cellRange 1 $col($gt)] 0]
                      if {$colName != ""} {
                        if {![info exists pmiHeading($col($gt))]} {
                          $cells($gt) Item 3 $c $colName
                          set pmiHeading($col($gt)) 1
                          set pmiCol [expr {max($col($gt),$pmiCol)}]
                        }
                      }
                      $cells($gt) Item $r $c [string trim $datumTargetRep]
                    }
                  }
                }
              }
            }
          } emsg3]} {
            set msg "ERROR processing Semantic PMI ($objNodeType $ent2): $emsg3"
            errorMsg $msg
            lappend syntaxErr([lindex $ent1 0]) [list $objID [lindex $ent1 1] $msg]
            set entLevel 1
          }
        }
      }
    }
  }
  incr entLevel -1

# write a few more things at the end of processing a semantic PMI entity
  if {$entLevel == 0} {
    if {[catch {

# check for unique datum systems
    #if {$gt == "datum_system" && [llength [array names datumSystem]] == $entCount(datum_system)} {
    #  foreach id [array names datumSystem] {lappend ds($datumSystem($id)) $id}
    #  foreach id [array names ds] {
    #    if {[llength $ds($id)] > 1} {
    #      foreach id1 $ds($id) {
    #        set msg "Multiple 'datum_system' entities have identical Datum Reference Frames.  They should be unique."
    #        errorMsg $msg
    #        lappend syntaxErr(datum_system) [list $id1 "Datum Reference Frame" $msg]
    #      }
    #    }
    #  }
    #}

# check for tolerances that require a datum system (section 6.8, table 10), don't check if using old method of datum_reference
      if {![info exists datsys] && [string first "_tolerance" [$gtEntity Type]] != -1 && ![info exists entCount(datum_reference)]} {
        set ok1 0
        foreach item {"angularity" "circular_runout" "coaxiality" "concentricity" "parallelism" "perpendicularity" "symmetry" "total_runout"} {
          set gtol "$item\_tolerance"
          if {[string first $gtol [$gtEntity Type]] != -1} {set ok1 1; set gtol1 $gtol}
        }
        if {$ok1} {
          set msg "Syntax Error: Datum system required with $gtol1.$spaces\($recPracNames(pmi242), Sec. 6.8, Table 10)"
          errorMsg $msg
          lappend syntaxErr([$gtEntity Type]) [list [$gtEntity P21ID] "GD&T" $msg]
        }
      }

# add datum reference frame (datum_system)
      if {[info exists datsys]} {
        set c  [lindex $datsys 0]
        set r  [lindex $datsys 1]
        set ds [lindex $datsys 2]
        set val [[$cells($gt) Item $r $c] Value]
        $cells($gt) Item $r $c "$val | $ds"
        lappend spmiTypesPerFile "datum system"

# check for tolerances that do not allow a datum system (section 6.8, table 10)
        set ok1 0
        foreach item {"cylindricity" "flatness" "roundness" "straightness"} {
          set gtol "$item\_tolerance"
          if {[string first $gtol [$gtEntity Type]] != -1} {set ok1 1; set gtol1 $gtol}
        }
        if {$ok1} {
          set msg "Syntax Error: Datum system ($ds) not allowed with $gtol1.$spaces\($recPracNames(pmi242), Sec. 6.8, Table 10)"
          errorMsg $msg
          lappend syntaxErr([$gtEntity Type]) [list [$gtEntity P21ID] "datum_system" $msg]
        }
      }

# add directed or oriented tolerance zone
      foreach tz [list directed oriented] {
        if {[info exists tzWithDatum($tz)]} {
          set val [[$cells($gt) Item $r $c] Value]
          $cells($gt) Item $r $c "$val |  $tzWithDatum($tz)"
          unset tzWithDatum($tz)
        }
      }

    } emsg3]} {
      errorMsg "ERROR adding Datum Feature: $emsg3"
    }

# check for composite tolerance (not stacked)
    set compositeID ""
    if {[catch {
      if {[string first "tolerance" $gt] != -1} {
        set c [string index [cellRange 1 $col($gt)] 0]
        set r $spmiIDRow($gt,$spmiID)
        set val [[$cells($gt) Item $r $c] Value]
        set e1s [$objEntity GetUsedIn [string trim geometric_tolerance_relationship] [string trim related_geometric_tolerance]]
        ::tcom::foreach e1 $e1s {
          ::tcom::foreach a1 [$e1 Attributes] {
            if {[$a1 Name] == "name"} {
              set compval [$a1 Value]
              if {$compval != "composite"} {
                if {[string tolower $compval] == "composite"} {
                  set msg "Syntax Error: Use lower case for 'name' attribute ($compval) on geometric_tolerance_relationship.$spaces\($recPracNames(pmi242), Sec. 6.9.9)"
                  set compval [string tolower $compval]
                } elseif {$compval == "precedence" || $compval == "simultaneity"} {
                  set msg "Syntax Error: 'name' attribute ($compval) not recommended on geometric_tolerance_relationship.$spaces\($recPracNames(pmi242), Sec. 6.9.9)"
                } else {
                  set msg "Syntax Error: Bad 'name' attribute ($compval) on geometric_tolerance_relationship.$spaces\($recPracNames(pmi242), Sec. 6.9.9)"
                }
                errorMsg $msg
                lappend syntaxErr(geometric_tolerance_relationship) [list [$e1 P21ID] "name" $msg]
              }
            } elseif {[$a1 Name] == "relating_geometric_tolerance"} {
              #$cells($gt) Item $r $c "$val[format "%c" 10](composite with [[$a1 Value] P21ID])"
              set compositeID [[$a1 Value] P21ID]
              lappend spmiTypesPerFile "composite tolerance"
            }
          }
        }
      }
    } emsg3]} {
      errorMsg "ERROR checking for Composite Tolerance: $emsg3"
    }

    if {[catch {

# get dimensional tolerance by checking dimtols for the same associated geometry
      if {[info exists assocGeom]} {
        catch {unset tolDimrep}
        if {[info exists spmiIDRow($gt,$spmiID)]} {
          set geotolGeom [reportAssocGeom $gt $spmiIDRow($gt,$spmiID)]
        } else {
          set geotolGeom [reportAssocGeom $gt]
        }

        set geotolGeomEnts ""
        foreach item [split $geotolGeom "\n"] {
          if {[string first "shape_aspect" $item] == -1 && \
              [string first "advanced_face" $item] == -1 && \
              [string first "centre_of_symmetry" $item] == -1 && \
              [string first "datum_feature" $item] == -1} {lappend geotolGeomEnts $item}
        }
        set geotolGeomEnts [join [lsort $geotolGeomEnts]]

# exact match
        if {[info exists dimtolGeom($geotolGeomEnts)]} {
          set tolDimrep [lindex $dimtolGeom($geotolGeomEnts) 0]
          set tolDimprec [getPrecision $tolDimrep]

# partial match
        } else {
          foreach item [array names dimtolGeom] {
            if {[string first $geotolGeomEnts $item] != -1 && [string first "surface" $geotolGeomEnts] != -1} {
              set tolDimrep [lindex $dimtolGeom($item) 0]
              break
            }
          }
        }
      }

# add dimensional tolerance
      if {[info exists tolDimrep] && [string first "tolerance" $gt] != -1} {
        set c [string index [cellRange 1 $col($gt)] 0]
        set r $spmiIDRow($gt,$spmiID)
        set val [[$cells($gt) Item $r $c] Value]

# modify tolerance zone to the same precision as the dimension
        if {[info exists dim(unit)] && $dim(unitOK)} {
          if {$dim(unit) == "INCH"} {
            if {[info exists tolDimprec]} {
              set ntol $tolval
              set tolprec [getPrecision $ntol]
              if {$tolprec > 3} {set tolprec 3}
              if {$tolDimprec > 3} {set tolDimprec 3}
              set n0 [expr {$tolDimprec-$tolprec}]

# add trailing zeros
              if {$n0 > 0} {
                if {[string first "." $ntol] == -1} {append ntol "."}
                append ntol [string repeat "0" $n0]

# truncate
              } elseif {$n0 < 0 && $n0 > -3 && $tolprec > 3} {
                set form "%."
                append form $tolDimprec
                append form f
                set ntol [format $form $ntol]
              }
              regsub -- $tolval $val $ntol val

# modify projected tolerance zone to dimension precision
              if {[info exists ptz]} {
                if {$ptz != "" && $ptz > 0. && $ptz != "NON-UNIFORM"} {
                  set ntol $ptz
                  set tolprec [getPrecision $ntol]
                  set n0 [expr {$tolDimprec-$tolprec}]
                  if {$n0 > 0} {
                    if {[string first "." $ntol] == -1} {append ntol "."}
                    append ntol [string repeat "0" $n0]
                  } elseif {$n0 < 0 && $n0 > -3 && $tolprec > 3} {
                    set form "%."
                    append form $tolDimprec
                    append form f
                    set ntol [format $form $ntol]
                  }
                  regsub -- $ptz $val $ntol val
                }
              }
            }
          }
        }
        $cells($gt) Item $r $c "$tolDimrep[format "%c" 10]$val"
        unset tolDimrep
        lappend spmiTypesPerFile "dimension association to geometric tolerance"
      }

# add datum feature with a triangle and line
      if {[string first "tolerance" $gt] != -1 && [info exists geotolGeomEnts]} {
        if {[info exists datumSymbol($geotolGeomEnts)]} {
          set val [[$cells($gt) Item $r $c] Value]
          $cells($gt) Item $r $c "$val [format "%c" 10]   \u25BD[format "%c" 10]   \u23B9[format "%c" 10]   \[$datumSymbol($geotolGeomEnts)\]"
          lappend spmiTypesPerFile "datum feature association to geometric tolerance"
        }
      }

# fix position of some modifiers to be under or over the FCF
      catch {
        set val [[$cells($gt) Item $r $c] Value]
        foreach mod {"ACS" "ALS"} {
          set c1 [string first $mod $val]
          if {$c1 != -1} {
            set val [string range $val 0 $c1-1][string range $val $c1+3 end]
            $cells($gt) Item $r $c "$mod[format "%c" 10]$val"
          }
        }
      }
      catch {
        set val [[$cells($gt) Item $r $c] Value]
        foreach mod {"LE" "MD" "LD" "PD"} {
          set c1 [string first $mod $val]
          if {$c1 != -1} {
            set val [string range $val 0 $c1-1][string range $val $c1+2 end]
            $cells($gt) Item $r $c "$val[format "%c" 10]$mod"
          }
        }
      }
      catch {
        set val [[$cells($gt) Item $r $c] Value]
        set c1 [string first "ERE" $val]
        if {$c1 != -1} {
          set val [string range $val 0 $c1-1][string range $val $c1+3 end]
          $cells($gt) Item $r $c "$val[format "%c" 10]EACH RADIAL ELEMENT"
        }
      }
      catch {
        set val [[$cells($gt) Item $r $c] Value]
        set c1 [string first "SEP REQT" $val]
        if {$c1 != -1} {
          set val [string range $val 0 $c1-1][string range $val $c1+9 end]
          $cells($gt) Item $r $c "$val[format "%c" 10]SEP REQT"
        }
      }

# add TZF (tzf1) for those that are wrong or do not have a symbol associated with them
      if {[info exists tzf1]} {
        if {$tzf1 != ""} {
          set c [string index [cellRange 1 $col($gt)] 0]
          set r $spmiIDRow($gt,$spmiID)
          set val [[$cells($gt) Item $r $c] Value]
          $cells($gt) Item $r $c "$val[format "%c" 10]$tzf1"
          unset tzf1
        }
      }

# add composite
      if {$compositeID != ""} {
        set val [[$cells($gt) Item $r $c] Value]
        $cells($gt) Item $r $c "$val[format "%c" 10](composite with $compositeID)"
      }

    } emsg3]} {
      errorMsg "ERROR adding Dimensional Tolerance and Feature Count: $emsg3"
    }

# between
    if {[info exists between]} {
      set nval "$val[format "%c" 10]$pmiModifiers(between)"
      $cells($gt) Item $r $c $nval
      unset between
    }

# projected tolerance zone error
    if {[info exists ptzError]} {
      if {$ptzError} {
        set val [[$cells($gt) Item $r $c] Value]
        $cells($gt) Item $r $c "$val[format "%c" 10](projection_end error)"
        unset ptzError
      }
    }

# associated dimensional tolerance for geometric tolerances
    if {[info exists geotolGeomEnts] && [string first "datum_feature" $gt] == -1} {
      if {[info exists dimtolEntType($geotolGeomEnts)]} {
        set c1 [expr {$col($gt)+1}]
        set c [string index [cellRange 1 $c1] 0]
        set r $spmiIDRow($gt,$spmiID)
        set heading "Dimensional Tolerance[format "%c" 10](Sec. 6.2)"
        if {![info exists pmiHeading($c1)]} {
          $cells($gt) Item 3 $c $heading
          set pmiHeading($c1) 1
          set pmiCol [expr {max($c1,$pmiCol)}]
        }
        $cells($gt) Item $r $c $dimtolEntType($geotolGeomEnts)
      }
    }

# datum feature entity
    if {[info exists geotolGeomEnts] && [string first "datum_feature" $gt] == -1} {
      if {[info exists datumEntType($geotolGeomEnts)]} {
        set c1 [expr {$col($gt)+2}]
        set c [string index [cellRange 1 $c1] 0]
        set r $spmiIDRow($gt,$spmiID)
        set heading "Datum Feature[format "%c" 10](Sec. 6.5)"
        if {![info exists pmiHeading($c1)]} {
          $cells($gt) Item 3 $c $heading
          set pmiHeading($c1) 1
          set pmiCol [expr {max($c1,$pmiCol)}]
        }
        $cells($gt) Item $r $c $datumEntType($geotolGeomEnts)
      }
    }

# report toleranced geometry
    if {[info exists geotolGeom]} {
      if {$geotolGeom != ""} {
        set c1 [expr {$col($gt)+3}]
        set c [string index [cellRange 1 $c1] 0]
        set r $spmiIDRow($gt,$spmiID)
        if {[string first "datum_feature" [$gtEntity Type]] == -1} {
          set head1 "Toleranced"
          set heading "$head1 Geometry[format "%c" 10](column E)"
        } else {
          set head1 "Associated"
          set heading "$head1 Geometry[format "%c" 10](Sec. 6.5)"
        }
        if {![info exists pmiHeading($c1)]} {
          $cells($gt) Item 3 $c $heading
          set pmiHeading($c1) 1
          set pmiCol [expr {max($c1,$pmiCol)}]
          set comment "See Help > User Guide (section 5.1.5) for an explanation of $head1 Geometry."
          addCellComment $gt 3 $c $comment
        }
        $cells($gt) Item $r $c [string trim $geotolGeom]
        if {[lsearch $spmiRow($gt) $r] == -1} {lappend spmiRow($gt) $r}

        if {[string first "*" $geotolGeom] != -1} {
          set comment "Geometry IDs marked with an asterisk (*) are also Supplemental Geometry.  ($recPracNames(suppgeom), Sec. 4.3, Fig. 4)"
          addCellComment $gt 3 $c $comment
          set str "Datum"
          if {[string first "tolerance" $gt] != -1} {set str "Tolerance"}
          errorMsg "Some Toleranced Geometry for a $str is also Supplemental Geometry."
        }

        if {[string first "manifold_solid_brep" $geotolGeom] != -1 && [string first "surface" $gt] == -1} {
          errorMsg "Toleranced Geometry for a [formatComplexEnt $gt]\n contains a 'manifold_solid_brep'."
          addCellComment $gt $r $c "Toleranced Geometry contains a 'manifold_solid_brep'"
        }
      }

# missing toleranced geometry
    } elseif {[string first "_tolerance" $gt] != -1} {
      if {$oktsa} {
        set msg "Toleranced Geometry not found for a [formatComplexEnt $gt].  If the tolerance should have Toleranced Geometry, then check GISU or IIRU 'definition' attribute or shape_aspect_relationship 'relating_shape_aspect' attribute.  Select Inverse Relationships on the Options tab to check relationships.\n  ($recPracNames(pmi242), Sec. 6.9.2)"
        errorMsg $msg
        lappend syntaxErr($gt) [list "-$spmiIDRow($gt,$spmiID)" "Toleranced Geometry" $msg]
      }
    }
  }

  return 0
}
