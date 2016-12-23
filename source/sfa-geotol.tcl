proc spmiGeotolStart {objDesign entType} {
  global cells col elevel ent entAttrList gt lastEnt opt pmiCol pmiHeading pmiStartCol
  global spmiEntity spmiRow spmiTypesPerFile stepAP tolNames

  if {$opt(DEBUG1)} {outputMsg "START spmiGeotolStart $entType" red}

  set dtm [list datum identification]
  set cdt [list common_datum identification]
  set df1 [list datum_feature name]
  set df2 [list composite_shape_aspect_and_datum_feature name]
  set df3 [list composite_group_shape_aspect_and_datum_feature name]
  set dr  [list datum_reference precedence referenced_datum $dtm $cdt]
  set dre [list datum_reference_element base $dtm modifiers]
  set drc [list datum_reference_compartment base $dtm $dre modifiers [list datum_reference_modifier_with_value modifier_type modifier_value]]
  set rmd [list referenced_modified_datum referenced_datum $dtm modifier]
  
  set len1 [list length_measure_with_unit value_component]
  set len2 [list length_measure_with_unit_and_measure_representation_item value_component]
  set len3 [list length_measure_with_unit_and_measure_representation_item_and_qualified_representation_item value_component]
  set len4 [list plane_angle_measure_with_unit value_component]
 
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
  foreach tol $tolNames {set PMIP($tol) [list $tol magnitude $len1 $len2 $len3 $len4\
                                                  toleranced_shape_aspect \
                                                    $df1 $df2 $df3 [list centre_of_symmetry_and_datum_feature name] \
                                                    [list composite_group_shape_aspect name] [list composite_shape_aspect name] \
                                                    [list composite_unit_shape_aspect name] [list composite_unit_shape_aspect_and_datum_feature name] \
                                                    [list all_around_shape_aspect name] [list between_shape_aspect name] [list shape_aspect name] [list product_definition_shape name] \
                                                  datum_system [list datum_system name] $dr $rmd \
                                                  modifiers \
                                                  modifier \
                                                  displacement [list length_measure_with_unit value_component] \
                                                  unit_size $len1 area_type second_unit_size $len1 \
                                                  maximum_upper_tolerance $len1 \
  ]}

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

  outputMsg " Adding PMI Representation" green
  lappend spmiEntity $entType
  
  if {[string first "AP203" $stepAP] == 0 || $stepAP == "AP214"} {
    errorMsg "Syntax Error: There is no Recommended Practice for PMI Representation in $stepAP files.  Use AP242 for PMI Representation."
  }

  if {$opt(DEBUG1)} {outputMsg \n}
  set elevel 0
  pmiSetEntAttrList $PMIP($gt)
  if {$opt(DEBUG1)} {outputMsg "entAttrList $entAttrList"}
  if {$opt(DEBUG1)} {outputMsg \n}
    
  set startent [lindex $PMIP($gt) 0]
  set n 0
  set elevel 0
  
# get next unused column by checking if there is a colName
  set pmiStartCol($gt) [getNextUnusedColumn $startent 3]
  
# process all entities, call spmiGeotolReport
  ::tcom::foreach objEntity [$objDesign FindObjects [join $startent]] {
    if {[$objEntity Type] == $startent} {

      foreach item $tolNames {
        if {[string first $item $startent] != -1} {lappend spmiTypesPerFile $item}
      }

      if {$n < 10000000} {
        if {[expr {$n%2000}] == 0} {
          if {$n > 0} {outputMsg "  $n"}
          update idletasks
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
  global all_around all_over assocGeom ATR badAttributes between cells col datsys datumCompartment datumFeature datumSystem
  global dim dimrep elevel ent entAttrList entCount gt gtEntity incrcol lastAttr lastEnt noDatum noDimtol objID opt
  global pmiCol pmiHeading pmiModifiers pmiStartCol pmiUnicode ptz recPracNames
  global spmiEnts spmiID spmiIDRow spmiRow spmiTypesPerFile stepAP syntaxErr
  global tol_dimprec tol_dimrep tolNames tolval tzf1 tzfNames worksheet

  if {$opt(DEBUG1)} {outputMsg "spmiGeotolReport" red}
   
# elevel is very important, keeps track level of entity in hierarchy
  incr elevel
  set ind [string repeat " " [expr {4*($elevel-1)}]]

  if {[string first "handle" $objEntity] == -1} {
    #if {$objEntity != ""} {outputMsg "$ind $objEntity" red}
  } else {
    set objType [$objEntity Type]
    set objID   [$objEntity P21ID]
    set objAttributes [$objEntity Attributes]
    set ent($elevel) $objType
    #outputMsg "$objEntity $objType $objID" red

    if {$opt(DEBUG1)} {outputMsg "$ind ENT $elevel #$objID=$objType (ATR=[$objAttributes Count])" blue}
    
    if {$stepAP == "AP242"} {
      if {$objType == "datum_reference"} {
        errorMsg "Syntax Error: Use 'datum_system' instead of 'datum_reference' for PMI Representation in AP242 files.\n[string repeat " " 14]\($recPracNames(pmi242), Sec. 6.9.7)"        
      }
    }

# check if there are rows with gt
    if {$elevel == 1} {
      if {$spmiEnts($objType)} {
        set spmiID $objID
        if {![info exists spmiIDRow($gt,$spmiID)]} {
          incr elevel -1
          return
        }
      }
    }
    
    if {$elevel == 1} {
      catch {unset datsys}
      catch {unset datumFeature}
      catch {unset assocGeom}
      set gtEntity $objEntity
    }
    if {$objType == "datum_system" && [string first "_tolerance" $gt] != -1} {
      set c [string index [cellRange 1 $col($gt)] 0]
      set r $spmiIDRow($gt,$spmiID)
      set datsys [list $c $r $datumSystem($objID)]
    }
    
    ::tcom::foreach objAttribute $objAttributes {
      set objName  [$objAttribute Name]
      if {$elevel < 1} {set elevel 1}
      set ent1 "$ent($elevel) $objName"
      set ent2 "$ent($elevel).$objName"

# look for entities with bad attributes that cause a crash
      set okattr 1
      if {[info exists badAttributes($objType)]} {foreach ba $badAttributes($objType) {if {$ba == $objName} {set okattr 0}}}

      if {$okattr} {
        set objValue [$objAttribute Value]
        set objNodeType [$objAttribute NodeType]
        set objSize [$objAttribute Size]
        set objAttrType [$objAttribute Type]
  
        set idx [lsearch $entAttrList $ent1]

# -----------------
# nodeType = 18, 19
        if {$objNodeType == 18 || $objNodeType == 19} {
          if {[catch {
            if {$idx != -1} {
              if {$opt(DEBUG1)} {outputMsg "$ind   ATR $elevel $objName - $objValue ($objNodeType, $objSize, $objAttrType)"}
              set ATR($elevel) $objName
              set lastAttr $objName
    
              if {[info exists cells($gt)]} {
                set ok 0

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
                      errorMsg "Syntax Error: Missing 'base' attribute on [lindex $ent1 0].\n[string repeat " " 14]\($recPracNames(pmi242), Sec. 6.9.7)"
                      lappend syntaxErr([lindex [split $ent1 " "] 0]) [list $objID [lindex [split $ent1 " "] 1]]
                    } else {
                      set baseType ""
                      catch {set baseType [$objValue Type]}
                      if {$baseType == "common_datum"} {
                        errorMsg "Syntax Error: Use 'datum_reference_element' (common_datum_list) instead of 'common_datum' for the 'base' attribute on [lindex $ent1 0].\n[string repeat " " 14]\($recPracNames(pmi242), Sec. 6.9.8)"
                        lappend syntaxErr([lindex [split $ent1 " "] 0]) [list $objID [lindex [split $ent1 " "] 1]]
                      }
                    }
                  }
                  "*_tolerance* toleranced_shape_aspect" {
                    set oktsa 1
                    if {$objValue != ""} {
                      set tsaType [$objValue Type]
                      set tsaID   [$objValue P21ID]
                    } else {
                      errorMsg "Syntax Error: Missing 'toleranced_shape_aspect' attribute on $objType\n[string repeat " " 14]\($recPracNames(pmi242))"
                      lappend syntaxErr([lindex [split $ent1 " "] 0]) [list [$gtEntity P21ID] [lindex [split $ent1 " "] 1]]
                      set oktsa 0
                    }
                    set noDimtol 1
                    set noDatum  1

# get toleranced geometry
                    if {$oktsa} {
                      getAssocGeom $objValue
                    
# get dimension directly
                      if {[string first "dimensional_" $tsaType] != -1} {
                        if {[info exists dimrep($tsaID)]} {
                          set tol_dimrep $dimrep($tsaID)
                          set noDimtol 0
                        }
                        #set dimtolPath "[$objValue Type] [$objValue P21ID]"
                      }

# get datum feature
                      set str1 "*_tolerance.toleranced_shape_aspect [$gtEntity P21ID] > [$objValue Type] [$objValue P21ID]"
                      if {[string first "datum_feature" [$objValue Type]] != -1} {
                        spmiGetDatumFeature $objValue "Path to Datum Feature (1): $str1"
                        set noDatum 0
                      }                    

# follow dimensional_size or dimensional_location
                      foreach item [list [list dimensional_location relating_shape_aspect] [list dimensional_size applies_to]] {
                        set e1s [$objValue GetUsedIn [string trim [lindex $item 0]] [string trim [lindex $item 1]]]
                        ::tcom::foreach e1 $e1s {
                          if {[string first "dimensional_" [$e1 Type]] != -1} {
                            set tol_dimrep $dimrep([$e1 P21ID])
                            if {$opt(DEBUG2)} {outputMsg "Path to DimTol (1): $str1 << [$e1 Type] [$e1 P21ID] ($tol_dimrep)" green}
                            if {[$e1 Type] != $tsaType} {set dimtolPath "[$e1 Type] [$e1 P21ID]"}
                            set noDimtol 0
                          }
                        }
                      }

# follow SAR to dimensional_location or dimensional_size
                      if {$noDimtol || $noDatum} {
                        foreach item1 [list [list relating_shape_aspect related_shape_aspect 2] [list related_shape_aspect relating_shape_aspect 5]] {
                          set rel1 [lindex $item1 0]
                          set rel2 [lindex $item1 1]
                          set relid [lindex $item1 2]
                          set e1s [$objValue GetUsedIn [string trim shape_aspect_relationship] [string trim $rel1]]
                          ::tcom::foreach e1 $e1s {
                            ::tcom::foreach a1 [$e1 Attributes] {
                              if {[$a1 Name] == $rel2} {
                                set e2 [$a1 Value]
                                set str1 "*_tolerance.toleranced_shape_aspect [$gtEntity P21ID] > [$objValue Type] [$objValue P21ID]\n  << [$e1 Type] [$e1 P21ID] > [$e2 Type] [$e2 P21ID]"
                                if {$noDatum} {
                                  set datumPath [spmiGetDatumFeature $e2 "Path to Datum Feature ($relid): $str1"]
                                  if {$datumPath == ""} {unset datumPath; set noDatum 1}
                                }
                                if {$noDimtol} {
                                  if {[string first "dimensional_" [$e2 Type]] == 0} {
                                    set tol_dimrep $dimrep([$e2 P21ID])
                                    if {$opt(DEBUG2)} {outputMsg "Path to DimTol ($relid\A): $str1 ($tol_dimrep)" green}
                                    set dimtolPath "[$e2 Type] [$e2 P21ID]"
                                    set noDimtol 0
                                    #set dimtolPath "[$e2 Type] [$e2 P21ID][format "%c" 10]([$e1 Type] [$e1 P21ID])"
                                  } else {
                                    if {$noDimtol} {
                                      set dimtolPath [spmiGetDimtol $e2 "$relid" $str1 $e2]
                                      if {$dimtolPath == ""} {unset dimtolPath; set noDimtol 1}
                                    }
                                  }
                                }
                              }
                            }
                          }
                        }

# follow gisu through shape_aspect and advanced_face to get to dimensional tolerance
                        if {$noDimtol || $noDatum} {
                          set e1s [$objValue GetUsedIn [string trim geometric_item_specific_usage] [string trim definition]]
                          ::tcom::foreach e1 $e1s {
                            ::tcom::foreach a1 [$e1 Attributes] {
                              if {[$a1 Name] == "identified_item"} {
                                set e2 [$a1 Value]
                                if {[$e2 Type] == "oriented_edge"} {
                                  ::tcom::foreach a9 [$e2 Attributes] {if {[$a9 Name] == "edge_element"} {set e2 [$a9 Value]}}
                                }
                                set e3s [$e2 GetUsedIn [string trim geometric_item_specific_usage] [string trim identified_item]]
                                ::tcom::foreach e3 $e3s {
                                  if {[$e1 P21ID] != [$e3 P21ID]} {
                                    ::tcom::foreach a3 [$e3 Attributes] {
                                      if {[$a3 Name] == "definition"} {
                                        set e4 [$a3 Value]
                                        set str1 "*_tolerance.toleranced_shape_aspect [$gtEntity P21ID] > [$objValue Type] [$objValue P21ID]\n  << gisu.definition - identified_item [$e1 P21ID] >  [$e2 Type] [$e2 P21ID]\n  << gisu.identified_item - definition [$e3 P21ID]"
                                        if {$noDatum} {
                                          if {![info exists datumFeature] && [string first "datum_feature" [$e4 Type]] != -1} {
                                            set str "Path to Datum Feature (3): $str1 > [$e4 Type] [$e4 P21ID]"
                                            set datumPath [spmiGetDatumFeature $e4 $str]
                                          }
                                        }
                                        if {$noDimtol} {
                                          set dimtolPath [spmiGetDimtol $e4 "3" $str1 $e4]
                                          if {$dimtolPath == ""} {
                                            unset dimtolPath
                                            set noDimtol 1
                                          }
                                        }
                                        if {$noDatum} {
                                          set e6s [$e4 GetUsedIn [string trim shape_aspect_relationship] [string trim related_shape_aspect]]
                                          ::tcom::foreach e6 $e6s {
                                            ::tcom::foreach a6 [$e6 Attributes] {
                                              if {[$a6 Name] == "relating_shape_aspect"} {
                                                set e7 [$a6 Value]
                                                if {[string first "datum_feature" [$e7 Type]] != -1} {
                                                  set str "Path to Datum Feature (3A): $str1 > [$e4 Type] [$e4 P21ID]\n  << [$e6 Type] [$e6 P21ID] > [$e7 Type] [$e7 P21ID]"
                                                  set datumPath [spmiGetDatumFeature $e7 $str]
                                                }                                              
                                              }
                                            }
                                          }
                                        }
                                      }
                                    }
                                  }
                                }
                              }
                            }
                          }
                        }

# follow shape_aspect_relationship, then gisu through shape_aspect and advanced_face to get to dimensional tolerance
                        if {$noDimtol || $noDatum} {
                          set e0s [$objValue GetUsedIn [string trim shape_aspect_relationship] [string trim relating_shape_aspect]]
                          ::tcom::foreach e0 $e0s {
                            ::tcom::foreach a0 [$e0 Attributes] {
                              if {[$a0 Name] == "related_shape_aspect"} {
                                set e01 [$a0 Value]
                                set e1s [$e01 GetUsedIn [string trim geometric_item_specific_usage] [string trim definition]]
                                ::tcom::foreach e1 $e1s {
                                  ::tcom::foreach a1 [$e1 Attributes] {
                                    if {[$a1 Name] == "identified_item"} {
                                      set e2 [$a1 Value]
                                      if {[$e2 Type] == "oriented_edge"} {
                                        ::tcom::foreach a9 [$e2 Attributes] {if {[$a9 Name] == "edge_element"} {set e2 [$a9 Value]}}
                                      }
                                      set e3s [$e2 GetUsedIn [string trim geometric_item_specific_usage] [string trim identified_item]]
                                      ::tcom::foreach e3 $e3s {
                                        if {[$e1 P21ID] != [$e3 P21ID]} {
                                          ::tcom::foreach a3 [$e3 Attributes] {
                                            if {[$a3 Name] == "definition"} {
                                              set e4 [$a3 Value]
                                              set str1 "*_tolerance.toleranced_shape_aspect [$gtEntity P21ID] > [$objValue Type] [$objValue P21ID]\n  << [$e0 Type] [$e0 P21ID] >  [$e01 Type] [$e01 P21ID]\n  << gisu.definition - identified_item [$e1 P21ID] >  [$e2 Type] [$e2 P21ID]\n  << gisu.identified_item - definition [$e3 P21ID]"
                                              if {![info exists datumFeature] && [string first "datum_feature" [$e4 Type]] != -1} {
                                                set str "Path to Datum Feature (4): $str1 > [$e4 Type] [$e4 P21ID]"
                                                set datumPath [spmiGetDatumFeature $e4 $str]
                                              }
                                              if {$noDimtol} {
                                                set dimtolPath [spmiGetDimtol $e4 "4" $str1 $e4]
                                                if {$dimtolPath == ""} {unset dimtolPath}
                                              }

# check for datum feature and dimensional tolerance 
                                              if {$noDatum || $noDimtol} {
                                                set e6s [$e4 GetUsedIn [string trim shape_aspect_relationship] [string trim related_shape_aspect]]
                                                ::tcom::foreach e6 $e6s {
                                                  ::tcom::foreach a6 [$e6 Attributes] {
                                                    if {[$a6 Name] == "relating_shape_aspect"} {
                                                      set e7 [$a6 Value]
                                                      if {[string first "datum_feature" [$e7 Type]] != -1} {
                                                        set str "Path to Datum Feature (4A): $str1 > [$e4 Type] [$e4 P21ID]\n  << [$e6 Type] [$e6 P21ID] > [$e7 Type] [$e7 P21ID]"
                                                        set datumPath [spmiGetDatumFeature $e7 $str]
                                                      }
                                                      if {$noDimtol} {
                                                        set dimtolPath [spmiGetDimtol $e7 "4A" $str1 $e4]
                                                        if {$dimtolPath == ""} {unset dimtolPath}
                                                      }
                                                    }
                                                  }
                                                }
                                              }
                                            }
                                          }
                                        }
                                      }
                                    }
                                  }
                                }
                              }
                            }
                          }
                        }
                      }
# check for all around, between
                      if {[$objValue Type] == "all_around_shape_aspect"} {
                        set ok 1
                        set idx "all_around"
                        set all_around 1
                        lappend spmiTypesPerFile $idx
                      } elseif {[$objValue Type] == "between_shape_aspect"} {
                        set ok 1
                        set idx "between"
                        set between 1
                        lappend spmiTypesPerFile $idx
                      }
                    }
                  }
                  "length_measure_with_unit* value_component" {
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
                                set tzfName1 $tzfName
                                if {$tzfName1 == "spherical"} {set tzfName1 "spherical diameter"}
                                if {[info exists pmiUnicode($tzfName1)]} {
                                  set tzf $pmiUnicode($tzfName1)
                                } else {
                                  set tzf1 "(TZF: $tzfName)"
                                }
                              } else {
                                if {$tzfName == "cylindrical" || $tzfName == "circular"} {
                                  errorMsg "Syntax Error: 'tolerance_zone_form.name' attribute ($tzfName) must be 'cylindrical or circular' on [$gtEntity Type].\n[string repeat " " 14]\($recPracNames(pmi242), Sec. 6.9.2, Table 11)"
                                } elseif {$tzfName != "" && [string tolower $tzfName] != "unknown"} {
                                  errorMsg "Syntax Error: Invalid 'tolerance_zone_form.name' attribute ($tzfName) for a tolerance.\n[string repeat " " 14]\($recPracNames(pmi242), Sec. 6.9.2, Tables 11, 12)"
                                }
                                lappend syntaxErr(tolerance_zone_form) [list [[$attrTZ Value] P21ID] "name"]
                                set tzf1 "(Invalid TZF: $tzfName)"
                              }
                              if {$tzfName == "cylindrical or circular"} {
                                lappend spmiTypesPerFile "tolerance zone diameter"
                              } elseif {$tzfName == "spherical"} {
                                lappend spmiTypesPerFile "tolerance zone spherical diameter"
                                }
# only these tolerances allow a tolerance zone form                              
                              set ok1 0
                              foreach item {"position" "perpendicularity" "parallelism" "angularity" "coaxiality" "concentricity" "straightness"} {
                                set gtol "$item\_tolerance"
                                if {[string first $gtol [$gtEntity Type]] != -1} {set ok1 1}
                              }
                              if {$ok1 == 0 && [string tolower $tzfName] != "unknown"} {
                                set tolType [$gtEntity Type]
                                foreach item $tolNames {if {[string first [$gtEntity Type] $item] != -1} {set tolType $item}}
                                errorMsg "Syntax Error: Tolerance zones are not allowed with $tolType."
                                lappend syntaxErr(tolerance_zone_form) [list [[$attrTZ Value] P21ID] "name"]
                              }
                            }
                          }
                        }
                      }
# get projected tolerance zone
                      set objPZDEntities [$objGuiEntity GetUsedIn [string trim projected_zone_definition] [string trim zone]]
                      ::tcom::foreach objPZDEntity $objPZDEntities {
                        ::tcom::foreach attrPZD [$objPZDEntity Attributes] {
                          if {[$attrPZD Name] == "projected_length"} {
                            ::tcom::foreach attrLEN [[$attrPZD Value] Attributes] {
                              if {[$attrLEN Name] == "value_component"} {
                                set ptz [$attrLEN Value]
                                if {$ptz < 0.} {errorMsg "Syntax Error: Negative projected tolerance zone: $ptz"}
                              }
                            }
                          }
                        }
                      }
# get non-uniform tolerance zone
                      set objPZDEntities [$objGuiEntity GetUsedIn [string trim non_uniform_zone_definition] [string trim zone]]
                      ::tcom::foreach objPZDEntity $objPZDEntities {set ptz "NON-UNIFORM"}
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

# truncate
                          if {[getPrecision $objValue] > 6} {set objValue [string trimright [format "%.6f" $objValue] "0"]}
                          set tolval $objValue
                          set objValue "$tname | $tzf$objValue"

# add projected or non-uniform tolerance zone magnitude value
                          if {$ptz != ""} {
                            if {$ptz != "NON-UNIFORM"} {
                              set idx "projected"
                              append objValue " $pmiModifiers($idx) $ptz"
                              lappend spmiTypesPerFile $idx
                            } else {
                              set objValue "[string range $objValue 0 [string first "|" $objValue]] $ptz"
                              set idx "non-uniform tolerance zone"
                              lappend spmiTypesPerFile $idx
                            }
                          }
                        }
                      }

# get unequally disposed displacement value
                    } elseif {$ATR(1) == "displacement" && [string first "unequally_disposed" $gt] != -1} {
                      set ok 1
                      set idx "unequally_disposed"
                      set objValue " $pmiModifiers($idx) $objValue"
                      lappend spmiTypesPerFile $idx

# get unit-basis tolerance value (6.9.6)
                    } elseif {$ATR(1) == "unit_size"} {
                      set ok 1
                      set objValue " / $objValue"
                      set idx "unit-basis tolerance"
                      lappend spmiTypesPerFile $idx
                    } elseif {$ATR(1) == "second_unit_size"} {
                      set ok 1
                      set objValue "X $objValue"

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
  
                if {$ok && [info exists spmiID]} {
                  set c [string index [cellRange 1 $col($gt)] 0]
                  set r $spmiIDRow($gt,$spmiID)

# column name
                  if {![info exists pmiHeading($col($gt))]} {
                    $cells($gt) Item 3 $c $colName
                    set pmiHeading($col($gt)) 1
                    set pmiCol [expr {max($col($gt),$pmiCol)}]
                    if {[string first "GD&T" $colName] == 0} {
                      addCellComment $gt 3 $c "If toleranced_shape_aspect does not directly refer to a dimension or datum feature, then the association between the geometric tolerance and dimensional tolerance or datum feature is found by looking for a common shape_aspect or geometric item.\n\nAssociated PMI Presentation is on annotation_occurrence worksheets."
                    }
                  }

# keep track of rows with PMI properties
                  if {[lsearch $spmiRow($gt) $r] == -1} {lappend spmiRow($gt) $r}

# value in spreadsheet
                  set val [[$cells($gt) Item $r $c] Value]
                  #outputMsg "$val / $objValue" red
                  if {$val == ""} {
                    $cells($gt) Item $r $c $objValue
                    if {$gt == "datum_system"} {
                      set idx [string trim [expr {int([[$cells($gt) Item $r 1] Value])}]]
                      set datumSystem($idx) $objValue
                    }
                  } else {
                    if {[info exists all_around]} {
                      $cells($gt) Item $r $c  "$pmiModifiers(all_around) | $val"
                      unset all_around
                    } elseif {[string first "X" $objValue] == 0} {
                      if {[string first "/ $pmiUnicode(diameter)" $val] == -1} {
                        $cells($gt) Item $r $c "[string range $val 0 [string first "X" $val]-2] $objValue"
                      }
                    } elseif {[string first $pmiModifiers(unequally_disposed) $objValue] == -1 && $ATR(1) != "unit_size"} {
                      #$cells($gt) Item $r $c "$val | $objValue"
                      if {[string first "handle" $objValue] == -1} {$cells($gt) Item $r $c "$val | $objValue"}
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
            errorMsg "ERROR processing Geotol ($objNodeType $ent2)\n $emsg3"
            set elevel 1
          }

# --------------
# nodeType = 20
        } elseif {$objNodeType == 20} {
          if {[catch {
            if {$idx != -1} {
              if {$opt(DEBUG1)} {outputMsg "$ind   ATR $elevel $objName - $objValue ($objNodeType, $objSize, $objAttrType)"}
    
              if {[info exists cells($gt)]} {
                set ok 0
                set invalid 0
  
                switch -glob $ent1 {
                  "datum_reference_compartment modifiers" -
                  "datum_reference_element modifiers" -
                  "*geometric_tolerance_with_modifiers* modifiers" -
                  "*geometric_tolerance_with_maximum_tolerance* modifiers" {
# get text modifiers
                    if {[string first "handle" $objValue] == -1} {
                      set modlim 5
                      if {$objSize > $modlim} {
                        errorMsg "Possible Syntax Error: More than $modlim Modifiers"
                        lappend syntaxErr([lindex [split $ent1 " "] 0]) [list [$gtEntity P21ID] [lindex [split $ent1 " "] 1]]
                      }
                      set col($gt) $pmiStartCol($gt)
                      set nval ""
                      foreach val $objValue {
                        if {[info exists pmiModifiers($val)]} {
                          if {[string first "degree_of_freedom_constraint" $val] != -1} {
                            lappend dofModifier $pmiModifiers($val)
                          } else {
                            append nval " $pmiModifiers($val)"
                          }
                          set ok 1
                          if {[string first $gt $ent1] == 0} {lappend spmiTypesPerFile $val}
                          
                          if {[string first "_material_condition" $val] != -1 && $stepAP == "AP242"} {
                            if {[string first "max" $val] == 0} {
                              errorMsg "Syntax Error: Use 'maximum_material_requirement' instead of 'maximum_material_condition' for PMI Representation in AP242 files.\n[string repeat " " 14]\($recPracNames(pmi242), Sec. 6.9.3)"
                            } elseif {[string first "least" $val] == 0} {
                              errorMsg "Syntax Error: Use 'least_material_requirement' instead of 'least_material_condition' for PMI Representation in AP242 files.\n[string repeat " " 14]\($recPracNames(pmi242), Sec. 6.9.3)"
                            }  
                          }
                        } else {
                          if {$val != ""} {append nval " \[$val\]"}
                          set ok 1
                          errorMsg "Possible Syntax Error: Unexpected DRF Modifier"
                          lappend syntaxErr([lindex [split $ent1 " "] 0]) [list [$gtEntity P21ID] [lindex [split $ent1 " "] 1]]
                        }
                      }
                      if {[info exists dofModifier]} {
                        set dofModifier [join [lsort $dofModifier] ","]
                        set dofModifier " \[$dofModifier\]"
                        append nval $dofModifier
                        unset dofModifier
                      }
                      set objValue $nval
                    }
                  }
                }

# value in spreadsheet
                if {$ok && [info exists spmiID]} {
                  set c [string index [cellRange 1 $col($gt)] 0]
                  set r $spmiIDRow($gt,$spmiID)

# column name
                  if {![info exists pmiHeading($col($gt))]} {
                    $cells($gt) Item 3 $c $colName
                    set pmiHeading($col($gt)) 1
                    set pmiCol [expr {max($col($gt),$pmiCol)}]
                  }

# keep track of rows with PMI properties
                  if {[lsearch $spmiRow($gt) $r] == -1} {lappend spmiRow($gt) $r}
                  if {$invalid} {lappend syntaxErr($gt) [list $r $col($gt)]}
  
                  set ov $objValue 
                  set val [[$cells($gt) Item $r $c] Value]
                  #outputMsg "$val -- $objValue" green
                  if {$val == ""} {
                    $cells($gt) Item $r $c $ov
                    if {$gt == "datum_reference_compartment"} {
                      set idx [string trim [expr {int([[$cells($gt) Item $r 1] Value])}]]
                      set datumCompartment($idx) $ov
                      #outputMsg "DRC  $idx  $nval" blue
                    }
                  } else {
                    if {[string first "modifiers" $ent1] != -1} {
                      set nval $val$ov
                      $cells($gt) Item $r $c $nval
                      if {$gt == "datum_reference_compartment"} {
                        set idx [string trim [expr {int([[$cells($gt) Item $r 1] Value])}]]
                        set datumCompartment($idx) $nval
                        #outputMsg "DRC  $idx  $nval" red
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
            errorMsg "ERROR processing Geotol ($objNodeType $ent2)\n $emsg3"
            set elevel 1
          }

# ---------------------
# nodeType = 5 (!= 18,19,20)
        } else {
          if {[catch {
            if {$idx != -1} {
              if {$opt(DEBUG1)} {outputMsg "$ind   ATR $elevel $objName - $objValue ($objNodeType, $objAttrType)  ($ent1)"}
    
              if {[info exists cells($gt)]} {
                set ok 0
                set colName ""
                set ov $objValue
                set invalid 0

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
                    if {![string is alpha $ov]} {
                      errorMsg "Syntax Error: 'datum.identification' $ov is not a letter.\n[string repeat " " 14]\($recPracNames(pmi242), Sec. 6.5)"
                    }
                  }
                  "common_datum identification" {
                    set common_datum ""
# common datum (A-B), not the recommended practice
                    errorMsg "Syntax Error: Use 'common_datum_list' instead of 'common_datum' for multiple datum features.\n[string repeat " " 14]\($recPracNames(pmi242), Sec. 6.9.8)"
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
# get datum feature and associated geometry (datum_feature usually set someplace else first)
                    if {![info exists datumFeature] && [string first "datum_feature" [$gtEntity Type]] == -1} {
                      set datumPath [spmiGetDatumFeature $objEntity "Path to Datum Feature (5): *_tolerance.toleranced_shape_aspect [$gtEntity P21ID] > [$objEntity Type] [$objEntity P21ID]"]
                    }
                    if {[string first "datum_feature" [$gtEntity Type]] != -1} {
                      getAssocGeom $gtEntity
                      reportAssocGeom
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
                      errorMsg "Possible Syntax Error: Unexpected Modifier"
                      lappend syntaxErr([lindex [split $ent1 " "] 0]) [list [$gtEntity P21ID] [lindex [split $ent1 " "] 1]]
                    }
                  }
                  "placed_datum_target_feature description" -
                  "datum_target description" {
# datum target description (Section 6.6)
                    catch {unset datumTargetGeom}
                    set datumTargetType $ov
                    set oktarget 1
                    if {[$gtEntity Type] == "placed_datum_target_feature"} {
                      if {$ov != "point" && $ov != "line" && $ov != "rectangle" && $ov != "circle" && $ov != "circular curve"} {
                        set oktarget 0
                      } else {
                        lappend spmiTypesPerFile "$ov placed datum target (6.6)"
                      }
# placed datum target feature geometry
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
                                }
                              }
                            }
                          }
                        }
                      }
                      if {[info exists datumTargetGeom]} {
                        set ok 1
                        set col($gt) [expr {$pmiStartCol($gt)+2}]
                        set colName "Target Geometry[format "%c" 10](Sec. 6.6.2)"
                        set objValue $datumTargetGeom
                        lappend spmiTypesPerFile "placed datum target geometry (6.6.2)"
                      } else {
                        #errorMsg "Syntax Error: Missing target geometry for [$gtEntity Type].\n[string repeat " " 14]\($recPracNames(pmi242), Sec. 6.6.2)"
                      }
                    } else {
                      if {$ov != "area" && $ov != "curve"} {
                        set oktarget 0
                      } else {
                        lappend spmiTypesPerFile "$ov datum target (6.6)"
                      }
# datum target feature geometry
                      set e1s [$gtEntity GetUsedIn [string trim geometric_item_specific_usage] [string trim definition]]
                      ::tcom::foreach e1 $e1s {
                        ::tcom::foreach a1 [$e1 Attributes] {
                          if {[$a1 Name] == "identified_item"} {
                            set e2 [$a1 Value]
                            append datumTargetGeom "[$e2 Type] [$e2 P21ID]"
                          }
                        }
                      }
                      if {[info exists datumTargetGeom]} {
                        set ok 1
                        set col($gt) [expr {$pmiStartCol($gt)+2}]
                        set colName "Target Geometry[format "%c" 10](Sec. 6.6.1)"
                        set objValue $datumTargetGeom
                      } else {
                        errorMsg "Syntax Error: Missing target geometry for [$gtEntity Type].\n[string repeat " " 14]\($recPracNames(pmi242), Sec. 6.6.1)"
                      }
                    }
                    if {!$oktarget} {
                      errorMsg "Syntax Error: Invalid 'description' ($ov) on [$gtEntity Type].\n[string repeat " " 14]\($recPracNames(pmi242), Sec. 6.6.1)"
                      lappend syntaxErr([lindex [split $ent1 " "] 0]) [list $objID [lindex [split $ent1 " "] 1]]
                    }
                  }
                  "placed_datum_target_feature target_id" -
                  "datum_target target_id" {
# datum target IDs (Section 6.6)
                    if {![string is integer $ov]} {
                      errorMsg "Syntax Error: Invalid 'target_id' ($ov) on [$gtEntity Type] (must only be the integer of a Datum Target)\n[string repeat " " 14]\($recPracNames(pmi242), Sec. 6.6)"
                      set invalid 1
                      lappend syntaxErr([lindex [split $ent1 " "] 0]) [list $objID [lindex [split $ent1 " "] 1]]
                    }
                    set e1s [$objEntity GetUsedIn [string trim shape_aspect_relationship] [string trim relating_shape_aspect]]
                    ::tcom::foreach e1 $e1s {
                      ::tcom::foreach a1 [$e1 Attributes] {
                        if {[$a1 Name] == "related_shape_aspect"} {
                          ::tcom::foreach a2 [[$a1 Value] Attributes] {
                            if {[$a2 Name] == "identification"} {
                              set val [$a2 Value]
                              if {[string length $val] > 1 || ![string is alpha $val]} {
                                errorMsg "Syntax Error: Invalid 'identification' ($val) on datum (must only be the letter of a Datum Target)\n[string repeat " " 14]\($recPracNames(pmi242), Sec. 6.6)"
                                set invalid 1
                                lappend syntaxErr(datum) [list [[$a1 Value] P21ID] identification]
                              }
                              set datumTarget "[$a2 Value]$ov"
                            }
                          }
                        }
                      }
                    }
                    if {![info exists datumTarget]} {
                      errorMsg "Syntax Error: Missing relationship to datum for [$objEntity Type].\n[string repeat " " 14]\($recPracNames(pmi242), Sec. 6.6)"
                      #set datumTarget $ov
                    }
                    set ok 1
                    set col($gt) $pmiStartCol($gt)
                    set colName "Datum Target[format "%c" 10](Sec. 6.6)"
                    set objValue "$datumTarget ($datumTargetType)"
                    #lappend spmiTypesPerFile "datum target"
#
# datum target shape representation (Section 6.6.1)
                    set datumTargetRep ""
                    if {[$gtEntity Type] == "placed_datum_target_feature"} {
                      set nval 0
                      set e1s [$objEntity GetUsedIn [string trim property_definition] [string trim definition]]
                      ::tcom::foreach e1 $e1s {
                        set e2s [$e1 GetUsedIn [string trim shape_definition_representation] [string trim definition]]
                        ::tcom::foreach e2 $e2s {
                          ::tcom::foreach a2 [$e2 Attributes] {
                            if {[$a2 Name] == "used_representation"} {
                              set e3 [$a2 Value]
# values in shape_representation_with_parameters
                              if {[$e3 Type] == "shape_representation_with_parameters"} {
                                ::tcom::foreach a3 [$e3 Attributes] {
                                  if {[$a3 Name] == "items"} {
                                    ::tcom::foreach e4 [$a3 Value] {
# datum target position - A2P3D
                                      if {[$e4 Type] == "axis2_placement_3d"} {
                                        ::tcom::foreach a4 [$e4 Attributes] {
                                          if {[$a4 Name] == "name"} {
                                            if {[$a4 Value] != "orientation"} {
                                              errorMsg "Syntax Error: Invalid 'name' ([$a4 Value]) on axis2_placement_3d for a placed datum target (must be 'orientation')\n[string repeat " " 14]\($recPracNames(pmi242), Sec. 6.6.1)"
                                              lappend syntaxErr(axis2_placement_3d) [list [$e4 P21ID] name]
                                            }
                                          } elseif {[$a4 Name] == "location"} {
                                            set e5 [$a4 Value]
                                            ::tcom::foreach a5 [$e5 Attributes] {
                                              if {[$a5 Name] == "coordinates"} {
                                                append datumTargetRep "coordinates "
                                                foreach item [split [$a5 Value] " "] {
                                                  set val [string trimright [format "%.4f" $item] "0"]
                                                  if {$val == "-0."} {set val 0.}
                                                  append datumTargetRep "  $val"
                                                }
                                                append datumTargetRep "[format "%c" 10]   (axis2_placement_3d [$e4 P21ID])"
                                              }
                                            }
                                          }
                                        }
# datum target dimensions - length_measure
                                      } elseif {[$e4 Type] == "length_measure_with_unit_and_measure_representation_item"} {
                                        ::tcom::foreach a4 [$e4 Attributes] {
                                          if {[$a4 Name] == "name"} {
                                            set datumTargetName [$a4 Value]
                                            append datumTargetRep "[format "%c" 10]$datumTargetName   $datumTargetValue"
                                            if {$datumTargetType == "line" && $datumTargetName != "target length"} {
                                              errorMsg "Syntax Error: Invalid 'name' ($datumTargetName) on length_measure for a datum target (must be 'target length' for a '$datumTargetType' target)\n[string repeat " " 14]\($recPracNames(pmi242), Sec. 6.6.1)"
                                            } elseif {$datumTargetType == "circle" && $datumTargetName != "target diameter"} {
                                              errorMsg "Syntax Error: Invalid 'name' ($datumTargetName) on length_measure for a datum target (must be 'target diameter' for a '$datumTargetType' target)\n[string repeat " " 14]\($recPracNames(pmi242), Sec. 6.6.1)"
                                            } elseif {$datumTargetType == "rectangle" && ($datumTargetName != "target length" && $datumTargetName != "target width")} {
                                              errorMsg "Syntax Error: Invalid 'name' ($datumTargetName) on length_measure for a datum target (must be 'target length' or 'target width' for a '$datumTargetType' target)\n[string repeat " " 14]\($recPracNames(pmi242), Sec. 6.6.1)"
                                            } elseif {$datumTargetType == "point"} {
                                              errorMsg "Syntax Error: No length_measure attribute on shape_representation_with_parameters is required for a 'point' datum target\n[string repeat " " 14]\($recPracNames(pmi242), Sec. 6.6.1)"
                                            }
                                          } elseif {[$a4 Name] == "value_component"} {
                                            set datumTargetValue [$a4 Value]
                                            if {$datumTargetValue <= 0. && $datumTargetType != "point"} {
                                              errorMsg "Syntax Error: Target dimension = 0 for a [string totitle $datumTargetType] datum target.\n[string repeat " " 14]\($recPracNames(pmi242), Sec. 6.6.1)"
                                            } 
                                          }
                                        }
# movable datum target direction (6.6.3)
                                      } elseif {[$e4 Type] == "direction"} {
                                        ::tcom::foreach a4 [$e4 Attributes] {
                                          if {[$a4 Name] == "name"} {
                                            if {[$a4 Value] != "movable direction"} {
                                              errorMsg "Syntax Error: Invalid 'name' ([$a4 Value]) on direction for a movable datum target (must be 'movable direction')\n[string repeat " " 14]\($recPracNames(pmi242), Sec. 6.6.3)"
                                            }
                                          } elseif {[$a4 Name] == "direction_ratios"} {
                                            set dirrat [$a4 Value]
                                          }
                                        }
                                        append datumTargetRep "[format "%c" 10]movable target direction   $dirrat[format "%c" 10]   (direction [$e4 P21ID])"
                                        lappend spmiTypesPerFile "movable datum target"
                                        append objValue " (movable)"
                                      } else {
                                        errorMsg "Syntax Error: Invalid 'item' ([$e4 Type]) on shape_representation_with_parameters for a datum target\n[string repeat " " 14]\($recPracNames(pmi242), Sec. 6.6)"
                                      }
                                    }
                                  }
                                }
                              }
                            }
                          }
                        }
                      }
#
# missing target representation
                      if {[string first "." $datumTargetRep] == -1} {
                        errorMsg "Syntax Error: Missing target representation for '$datumTargetType' datum target.\n[string repeat " " 14]\($recPracNames(pmi242), Sec. 6.6.1)"
                        set invalid 1
                      }
                    }
                  }
                  "product_definition_shape name" {
# all over
                    if {$ATR(1) == "toleranced_shape_aspect"} {
                      set ok 1
                      set all_over 1
                      set idx "all over"
                      lappend spmiTypesPerFile $idx
                    }
                  }
                  "*modified_geometric_tolerance* modifier" {
# AP203 get geotol modifier, not used in AP242
                    if {[string first "modified_geometric_tolerance" $objType] != -1 && $stepAP == "AP242"} {
                      errorMsg "Syntax Error: Use 'geometric_tolerance_with_modifiers' instead of 'modified_geometric_tolerance' for PMI Representation in AP242 files.\n[string repeat " " 14]\($recPracNames(pmi242), Sec. 6.9.3)"
                    }
                    set col($gt) $pmiStartCol($gt)
                    set nval ""
                    foreach val $objValue {
                      if {[info exists pmiModifiers($val)]} {
                        append nval " $pmiModifiers($val)"
                        set ok 1
                        lappend spmiTypesPerFile $val
                        if {[string first "_material_condition" $val] != -1 && $stepAP == "AP242"} {
                          if {[string first "max" $val] == 0} {
                            errorMsg "Syntax Error: Use 'maximum_material_requirement' instead of 'maximum_material_condition' for PMI Representation in AP242 files.\n[string repeat " " 14]\($recPracNames(pmi242), Sec. 6.9.3)"
                          } elseif {[string first "least" $val] == 0} {
                            errorMsg "Syntax Error: Use 'least_material_requirement' instead of 'least_material_condition' for PMI Representation in AP242 files.\n[string repeat " " 14]\($recPracNames(pmi242), Sec. 6.9.3)"
                          }  
                        }
                      } else {
                        if {$val != ""} {append nval " \[$val\]"}
                        set ok 1
                        errorMsg "Possible Syntax Error: Unexpected Modifier"
                        set invalid 1
                      }
                    }
                    set objValue $nval
                  }
                  "*geometric_tolerance_with_defined_area_unit* area_type" {
# defined area unit, look for square, rectangle and add " X 0.whatever" to existing value
                    set ok 1
                    if {[lsearch [list square rectangular circular] $objValue] == -1} {
                      errorMsg "Syntax Error: Invalid 'area_type' attribute ($objValue) on geometric_tolerance_with_defined_area_unit.\n[string repeat " " 14]\($recPracNames(pmi242), Sec. 6.9.6)"
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
                  if {$invalid} {lappend syntaxErr($gt) [list $r $col($gt)]}
  
                  set ov $objValue 
                  set val [[$cells($gt) Item $r $c] Value]
                  #outputMsg "$val -- $objValue" blue
                  if {$val == ""} {
                    $cells($gt) Item $r $c $ov
                    if {$gt == "datum_reference_compartment"} {
                      set idx [string trim [expr {int([[$cells($gt) Item $r 1] Value])}]]
                      set datumCompartment($idx) $ov
                      if {[string is double $ov] || [string is integer $ov]} {
                        errorMsg "Syntax Error: Datum identification is a numeric value ([string trim $ov])"
                      }
                    }
                  } else {
                    if {[info exists all_over]} {
                      $cells($gt) Item $r $c "\[ALL OVER\] | $val"
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
                    } elseif {[string first "modifier" $ent1] != -1} {
                      set nval $val$ov
                      $cells($gt) Item $r $c $nval
# area_type for defined area unit
                    } elseif {$ov == "square" || $ov == "rectangular"} {
                      set c1 [string last " " $val]
                      set nval "$val X[string range $val $c1 end]"
                      $cells($gt) Item $r $c $nval
                    } elseif {$ov == "circular"} {
                      regsub -all "/ " $val "/ $pmiUnicode(diameter)" nval
                      $cells($gt) Item $r $c $nval
                    } else {
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
                      $cells($gt) Item $r $c $datumTargetRep
                    }
                  }
                }
              }
            }
          } emsg3]} {
            errorMsg "ERROR processing Geotol ($objNodeType $ent2)\n $emsg3"
            set elevel 1
          }
        }
      }
    }
  }
  incr elevel -1
  
# write a few more things at the end of processing a semantic PMI entity
  if {$elevel == 0} {
    if {[catch {

# check for tolerances that require a datum system (section 6.8, table 10), don't check if using old method of datum_reference
      if {![info exists datsys] && [string first "_tolerance" [$gtEntity Type]] != -1 && ![info exists entCount(datum_reference)]} {
        set ok1 0
        foreach item {"angularity" "circular_runout" "coaxiality" "concentricity" "parallelism" "perpendicularity" "symmetry" "total_runout"} {
          set gtol "$item\_tolerance"
          if {[string first $gtol [$gtEntity Type]] != -1} {set ok1 1}
        }
        if {$ok1} {
          errorMsg "Syntax Error: Datum system required with [$gtEntity Type].\n[string repeat " " 14]\($recPracNames(pmi242), Sec. 6.8)"
          #lappend syntaxErr(tolerance_zone_form) [list [[$attrTZ Value] P21ID] "name"]
        }
      }

      if {[info exists datsys]} {
        set c  [lindex $datsys 0]
        set r  [lindex $datsys 1]
        set ds [lindex $datsys 2]
        set val [[$cells($gt) Item $r $c] Value]

# check for tolerances that do not allow a datum system (section 6.8, table 10)
        set ok1 0
        foreach item {"roundness" "cylindricity" "flatness" "straightness"} {
          set gtol "$item\_tolerance"
          if {[string first $gtol [$gtEntity Type]] != -1} {set ok1 1}
        }
        if {$ok1} {
          errorMsg "Syntax Error: Datum system ($ds) not allowed with [$gtEntity Type].\n[string repeat " " 14]\($recPracNames(pmi242), Sec. 6.8)"
          #lappend syntaxErr(tolerance_zone_form) [list [[$attrTZ Value] P21ID] "name"]
        }

# add datum feature with a triangle and line
        if {[info exists datumFeature]} {
          $cells($gt) Item $r $c "$val | $ds [format "%c" 10]   \u25BD[format "%c" 10]   \u23B9[format "%c" 10]   \[$datumFeature\]"
          unset datumFeature
        } else {
          $cells($gt) Item $r $c "$val | $ds"
        }
      } elseif {[info exists datumFeature]} {
        set c [string index [cellRange 1 $col($gt)] 0]
        set r $spmiIDRow($gt,$spmiID)
        set val [[$cells($gt) Item $r $c] Value]
        $cells($gt) Item $r $c "$val [format "%c" 10]   \u25BD[format "%c" 10]   \u23B9[format "%c" 10]   \[$datumFeature\]"
        unset datumFeature
      }
    } emsg3]} {
      errorMsg "ERROR adding Datum Feature: $emsg3"
    }
    
# check for composite tolerance (not stacked)
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
                  errorMsg "Syntax Error: Use lower case for 'name' attribute ($compval) on geometric_tolerance_relationship.\n[string repeat " " 14]\($recPracNames(pmi242), Sec. 6.9.9)"
                  set compval [string tolower $compval]
                } elseif {$compval == "precedence" || $compval == "simultaneity"} {
                  errorMsg "Syntax Error: 'name' attribute ($compval) not recommended on geometric_tolerance_relationship.\n[string repeat " " 14]\($recPracNames(pmi242), Sec. 6.9.9)"
                } else {
                  errorMsg "Syntax Error: Invalid 'name' attribute ($compval) on geometric_tolerance_relationship.\n[string repeat " " 14]\($recPracNames(pmi242), Sec. 6.9.9)"
                }
              }
            } elseif {[$a1 Name] == "relating_geometric_tolerance"} {
              $cells($gt) Item $r $c "$val[format "%c" 10](composite with [[$a1 Value] P21ID])"
              lappend spmiTypesPerFile "composite tolerance"
            }
          }
        }
      }
    } emsg3]} {
      errorMsg "ERROR checking for Composite Tolerance: $emsg3"
    }

    if {[catch {
    
# add dimensional tolerance and count
      if {[info exists tol_dimrep]} {
        set c [string index [cellRange 1 $col($gt)] 0]
        set r $spmiIDRow($gt,$spmiID)
        set val [[$cells($gt) Item $r $c] Value]

# format tolerance like dimension
        if {[info exists dim(unit)]} {
          if {$dim(unit) == "INCH"} {
            if {[info exists tol_dimprec]} {
              set ntol $tolval
              set tolprec [getPrecision $ntol]
              set n0 [expr {$tol_dimprec-$tolprec}]
              if {$n0 > 0} {
                if {[string first "." $ntol] == -1} {append ntol "."}
                append ntol [string repeat "0" $n0]
              } elseif {$n0 < 0} {
                set form "%."
                append form $tol_dimprec
                append form f
                set ntol [format $form $ntol]
              }
              regsub $tolval $val $ntol val
          
# format projected tolerance like dimension
              if {[info exists ptz]} {
                if {$ptz != "" && $ptz > 0. && $ptz != "NON-UNIFORM"} {
                  set ntol $ptz
                  set tolprec [getPrecision $ntol]
                  set n0 [expr {$tol_dimprec-$tolprec}]
                  if {$n0 > 0} {
                    if {[string first "." $ntol] == -1} {append ntol "."}
                    append ntol [string repeat "0" $n0]
                  } elseif {$n0 < 0} {
                    set form "%."
                    append form $tol_dimprec
                    append form f
                    set ntol [format $form $ntol]
                  }
                  regsub $ptz $val $ntol val
                }
              }
            }
          }
        }

        $cells($gt) Item $r $c "$tol_dimrep[format "%c" 10]$val"
        unset tol_dimrep
      }

# add TZF (tzf1) for those that are wrong or do not have a symbol associated with them
      if {[info exists tzf1]} {
        if {$tzf1 != "" && [string first "unknown" [string tolower $tzf1]] == -1} {
          set c [string index [cellRange 1 $col($gt)] 0]
          set r $spmiIDRow($gt,$spmiID)
          set val [[$cells($gt) Item $r $c] Value]
          $cells($gt) Item $r $c "$val[format "%c" 10]$tzf1"
          unset tzf1
        }
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
    
# path to dimensional tolerance
    if {[info exists dimtolPath]} {
      set c1 [expr {$col($gt)+1}]
      set c [string index [cellRange 1 $c1] 0]
      set r $spmiIDRow($gt,$spmiID)
      set heading "Dimensional Tolerance[format "%c" 10](Sec. 6.2)"
      if {![info exists pmiHeading($c1)]} {
        $cells($gt) Item 3 $c $heading
        set pmiHeading($c1) 1
        set pmiCol [expr {max($c1,$pmiCol)}]
      }
      $cells($gt) Item $r $c $dimtolPath
      unset dimtolPath
    }
    
# path to datum feature
    if {[info exists datumPath]} {
      set c1 [expr {$col($gt)+2}]
      set c [string index [cellRange 1 $c1] 0]
      set r $spmiIDRow($gt,$spmiID)
      set heading "Datum Feature[format "%c" 10](Sec. 6.5)"
      if {![info exists pmiHeading($c1)]} {
        $cells($gt) Item 3 $c $heading
        set pmiHeading($c1) 1
        set pmiCol [expr {max($c1,$pmiCol)}]
      }
      $cells($gt) Item $r $c $datumPath
      unset datumPath
    }
      
# report toleranced geometry
    if {[info exists assocGeom]} {
      set str [reportAssocGeom]
      if {$str != ""  } {
        set c1 [expr {$col($gt)+3}]
        set c [string index [cellRange 1 $c1] 0]
        set r $spmiIDRow($gt,$spmiID)
        if {[string first "datum_feature" [$gtEntity Type]] == -1} {
          set heading "Toleranced Geometry[format "%c" 10](column E)"
        } else {
          set heading "Associated Geometry[format "%c" 10](Sec. 6.5)"
        }
        if {![info exists pmiHeading($c1)]} {
          $cells($gt) Item 3 $c $heading
          set pmiHeading($c1)) 1
          set pmiCol [expr {max($c1,$pmiCol)}]
        }
        $cells($gt) Item $r $c [string trim $str]
        if {[lsearch $spmiRow($gt) $r] == -1} {lappend spmiRow($gt) $r}
      }
    }
  }

  return 0
}

# -------------------------------------------------------------------------------
proc spmiGetDimtol {ent type str1 entDebug} {
  global opt noDimtol dimrep tol_dimrep tol_dimprec dim

  if {[catch {
    catch {unset tol_dimprec}
    foreach item [list [list dimensional_location relating_shape_aspect] [list dimensional_size applies_to]] {
      set ents [$ent GetUsedIn [string trim [lindex $item 0]] [string trim [lindex $item 1]]]
      ::tcom::foreach ent1 $ents {
        if {[info exists dimrep([$ent1 P21ID])]} {
          set tol_dimrep $dimrep([$ent1 P21ID])
          if {[info exists dim(prec,[$ent1 P21ID])]} {set tol_dimprec $dim(prec,[$ent1 P21ID])}
          set dimtolPath "[$ent1 Type] [$ent1 P21ID]"
          set noDimtol 0
          if {$opt(DEBUG2)} {outputMsg "Path to DimTol ($type): $str1 > [$entDebug Type] [$entDebug P21ID] << [$ent1 Type] [$ent1 P21ID] ($tol_dimrep)" green}
          break
        }
      }
    }
  } emsg]} {
    errorMsg "ERROR getting Dimensional Tolerance for Geometric Tolerance: $emsg"
  }
  
  if {$noDimtol} {
    return
  } else {
    return $dimtolPath
  }
}

# -------------------------------------------------------------------------------
proc spmiGetDatumFeature {ent str1} {
  global opt noDatum datumFeature recPracNames
  
  catch {unset datumFeature}

# look for datum feature (ent) as a relating_shape_aspect for shape_aspect_relationship
  if {[catch {
    set ents [$ent GetUsedIn [string trim shape_aspect_relationship] [string trim relating_shape_aspect]]
    ::tcom::foreach ent1 $ents {
      ::tcom::foreach att1 [$ent1 Attributes] {
        if {[$att1 Name] == "related_shape_aspect"} {
          ::tcom::foreach att2 [[$att1 Value] Attributes] {
            if {[$att2 Name] == "identification"} {
              set datumFeature [$att2 Value]
              set datumPath "[formatComplexEnt [$ent Type]] [$ent P21ID]"
              set noDatum 0
              if {$opt(DEBUG2)} {outputMsg "$str1 \[$datumFeature\]" green}
              break
            }
          }
        }
      }
    }

# old way, related and relating are switched
    if {$noDatum} {
      set ents [$ent GetUsedIn [string trim shape_aspect_relationship] [string trim related_shape_aspect]]
      ::tcom::foreach ent1 $ents {
        ::tcom::foreach att1 [$ent1 Attributes] {
          if {[$att1 Name] == "relating_shape_aspect"} {
            ::tcom::foreach att2 [[$att1 Value] Attributes] {
              if {[$att2 Name] == "identification"} {
                set datumFeature [$att2 Value]
                set datumPath "[formatComplexEnt [$ent Type]] [$ent P21ID]"
                set noDatum 0
                if {$opt(DEBUG2)} {outputMsg "$str1 (old) \[$datumFeature\]" green}
                errorMsg "Syntax Error: The related (datum) and relating ([$ent Type]) shape_aspect are reversed.\n[string repeat " " 14]\($recPracNames(pmi242), Sec. 6.5, Fig. 34)"
                break
              }
            }
          }
        }
      }
    }
  } emsg]} {
    errorMsg "ERROR getting Datum Feature for Geometric Tolerance: $emsg"
  }
  
# check for bad letter
  if {[info exists datumFeature]} {
    if {[string length $datumFeature] > 1 || ![string is alpha $datumFeature]} {
      errorMsg "Syntax Error: Datum is not a single letter: $datumFeature\n[string repeat " " 14]\($recPracNames(pmi242), Sec. 6.5)"
    }
  }
  
  if {$noDatum} {
    return
  } else {
    return $datumPath
  }
}

# -------------------------------------------------------------------------------
# start semantic PMI coverage analysis worksheet
proc spmiCoverageStart {{multi 1}} {
  global cells cells1 multiFileDir pmiModifiers pmiModifiersRP pmiUnicode
  global sempmi_coverage sheetLast spmiTypes worksheet worksheet1 worksheets worksheets1 
  #outputMsg "spmiCoverageStart $multi" red

  if {[catch {
    set sempmi_coverage "PMI Representation Coverage"

# multiple files
    if {$multi} {
      set worksheet1($sempmi_coverage) [$worksheets1 Item [expr 2]]
      #$worksheet1($sempmi_coverage) Activate
      $worksheet1($sempmi_coverage) Name $sempmi_coverage
      set cells1($sempmi_coverage) [$worksheet1($sempmi_coverage) Cells]
      $cells1($sempmi_coverage) Item 1 1 "STEP Directory"
      $cells1($sempmi_coverage) Item 1 2 "[file nativename $multiFileDir]"
      $cells1($sempmi_coverage) Item 3 1 "PMI Element   (See Help > PMI Coverage Analysis)"
      set range [$worksheet1($sempmi_coverage) Range "B1:K1"]
      [$range Font] Bold [expr 1]
      $range MergeCells [expr 1]

# single file
    } else {
      set worksheet($sempmi_coverage) [$worksheets Add [::tcom::na] $sheetLast]
      #$worksheet($sempmi_coverage) Activate
      $worksheet($sempmi_coverage) Name $sempmi_coverage
      set cells($sempmi_coverage) [$worksheet($sempmi_coverage) Cells]
      set wsCount [$worksheets Count]
      [$worksheets Item [expr $wsCount]] -namedarg Move Before [$worksheets Item [expr 4]]

      $cells($sempmi_coverage) Item 3 1 "PMI Element (See Help > PMI Coverage Analysis)"
      $cells($sempmi_coverage) Item 3 2 "Count"
      set range [$worksheet($sempmi_coverage) Range "1:3"]
      [$range Font] Bold [expr 1]

      [$worksheet($sempmi_coverage) Range A:A] ColumnWidth [expr 48]
      [$worksheet($sempmi_coverage) Range B:B] ColumnWidth [expr 6]
      [$worksheet($sempmi_coverage) Range D:D] ColumnWidth [expr 48]
    }
    
# add pmi types
    set row1($sempmi_coverage) 3
    set row($sempmi_coverage) 3

# add modifiers
    foreach item $spmiTypes {
      set str0 [join $item]
      set str $str0
      if {$str != "square" && $str != "controlled_radius"} {
        if {[info exists pmiModifiers($str0)]}   {append str "  $pmiModifiers($str0)"}
        if {[info exists pmiModifiersRP($str0)]} {append str "  ($pmiModifiersRP($str0))"}

# tolerance
        set str1 $str
        set c1 [string last "_" $str]
        if {$c1 != -1} {set str1 [string range $str 0 $c1-1]}
        if {[info exists pmiUnicode($str1)]} {append str "  $pmiUnicode($str1)"}

        if {!$multi} {
          $cells($sempmi_coverage) Item [incr row($sempmi_coverage)] 1 $str
        } else {
          $cells1($sempmi_coverage) Item [incr row1($sempmi_coverage)] 1 $str
        }
      }
      #outputMsg $str
    }
  } emsg3]} {
    errorMsg "ERROR starting PMI Representation Coverage worksheet: $emsg3"
  }
}

# -------------------------------------------------------------------------------
# write semantic PMI coverage analysis worksheet
proc spmiCoverageWrite {{fn ""} {sum ""} {multi 1}} {
  global cells cells1 col1 coverageLegend coverageStyle entCount fileList legendColor nfile nistName 
  global sempmi_coverage sempmi_totals spmiCoverages spmiTypes spmiTypesPerFile worksheet worksheet1
  #outputMsg "spmiCoverageWrite $multi" red

  if {[catch {
    if {$multi} {
      set range [$worksheet1($sempmi_coverage) Range [cellRange 3 $col1($sum)] [cellRange 3 $col1($sum)]]
      $range Orientation [expr 90]
      $range HorizontalAlignment [expr -4108]
      $cells1($sempmi_coverage) Item 3 $col1($sum) $fn
    }
    
    if {[info exists entCount(datum)]} {
      for {set i 0} {$i < $entCount(datum)} {incr i} {
        lappend spmiTypesPerFile1 "datum (6.5)"
      }
      if {$multi} {unset entCount(datum)}
    }
    #if {[info exists entCount(placed_datum_target_feature)]} {
    #  for {set i 0} {$i < $entCount(placed_datum_target_feature)} {incr i} {
    #    lappend spmiTypesPerFile1 "placed datum target (6.6)"
    #  }
    #  if {$multi} {unset entCount(placed_datum_target_feature)}
    #}

# add number of pmi types
    if {[info exists spmiTypesPerFile] || [info exists spmiTypesPerFile1]} {
      for {set r 4} {$r <= 130} {incr r} {
        if {$multi} {
          set val [[$cells1($sempmi_coverage) Item $r 1] Value]
        } else {
          set val [[$cells($sempmi_coverage) Item $r 1] Value]
        }
        if {[info exists spmiTypesPerFile]} {
          foreach idx $spmiTypesPerFile {
            if {([string first $idx $val] == 0 && [string first "statistical_tolerance" $val] == -1) || \
                $idx == [lindex [split $val " "] 0]} {

# get current value
              if {$multi} {
                set npmi [[$cells1($sempmi_coverage) Item $r $col1($sum)] Value]
              } else {
                set npmi [[$cells($sempmi_coverage) Item $r 2] Value]
              }

# set or increment npmi
              if {$npmi == ""} {
                set npmi 1
              } else {
                set npmi [expr {int($npmi)+1}]
              }

# write npmi
              if {$multi} {
                $cells1($sempmi_coverage) Item $r $col1($sum) $npmi
                set range [$worksheet1($sempmi_coverage) Range [cellRange $r $col1($sum)] [cellRange $r $col1($sum)]]
              } else {
                $cells($sempmi_coverage) Item $r 2 $npmi
                set range [$worksheet($sempmi_coverage) Range [cellRange $r 2] [cellRange $r 2]]
              }
              $range HorizontalAlignment [expr -4108]
              if {$multi} {incr sempmi_totals($r)}
            }
          }
        }

# exact match
        if {[info exists spmiTypesPerFile1]} {
          foreach idx $spmiTypesPerFile1 {
            if {$idx == $val} {
              if {$multi} {
                set npmi [[$cells1($sempmi_coverage) Item $r $col1($sum)] Value]
              } else {
                set npmi [[$cells($sempmi_coverage) Item $r 2] Value]
              }
              if {$npmi == ""} {
                set npmi 1
              } else {
                set npmi [expr {int($npmi)+1}]
              }
              if {$multi} {
                $cells1($sempmi_coverage) Item $r $col1($sum) $npmi
                set range [$worksheet1($sempmi_coverage) Range [cellRange $r $col1($sum)] [cellRange $r $col1($sum)]]
              } else {
                $cells($sempmi_coverage) Item $r 2 $npmi
                set range [$worksheet($sempmi_coverage) Range [cellRange $r 2] [cellRange $r 2]]
              }
              $range HorizontalAlignment [expr -4108]
              if {$multi} {incr sempmi_totals($r)}
            }
          }          
        }
      }
      catch {if {$multi} {unset spmiTypesPerFile}}
    }

# get spmiCoverages (see sfa-gen.tcl to make sure spmiGetPMI is called)
    if {![info exists nfile]} {
      set nf 0
    } else {
      set nf $nfile
    }
    if {!$multi} {
      foreach idx [lsort [array names spmiCoverages]] {
        set tval [lindex [split $idx ","] 0]
        set fnam [lindex [split $idx ","] 1]
        if {$fnam == $nistName} {
          set coverage($tval) $spmiCoverages($idx)
        }
      }
      #foreach item [lsort [array names spmiCoverages]] {if {$spmiCoverages($item) != ""} {outputMsg "$item $spmiCoverages($item)" green}}
      #foreach item [lsort [array names coverage]] {if {$coverage($item) != ""} {outputMsg "$item $coverage($item)" red}}
    
# check values for color-coding
      for {set r 4} {$r <= [[[$worksheet($sempmi_coverage) UsedRange] Rows] Count]} {incr r} {
        set ttyp [[$cells($sempmi_coverage) Item $r 1] Value]
        set tval [[$cells($sempmi_coverage) Item $r 2] Value]
        if {$ttyp != ""} {
          if {$tval == ""} {set tval 0}
          set tval [expr {int($tval)}]
          #outputMsg "$r  $tval  $ttyp" red
          foreach item [array names coverage] {
            if {[string first $item $ttyp] == 0} {
              set ok 0

# these words appear in other PMI elements and need to be handled separately, e.g. statistical is also in statistical_tolerance
              if {$item != "datum" && $item != "line" && $item != "spherical" && \
                  $item != "statistical" && $item != "basic" && $item != "point"} {
                set ok 1
              } else {
                set str [string range $ttyp 0 [expr {[string last " " $ttyp]-1}]]
                if {$item == $str} {set ok 1}
                if {!$ok} {
                  set str [string range $ttyp 0 [expr {[string last " " $ttyp]-2}]]
                  if {$item == $str} {set ok 1}
                }
                if {!$ok} {
                  set str [string range $ttyp 0 [expr {[string first "<" $ttyp]-3}]]
                  if {$item == $str} {set ok 1}
                }
              }
              if {$ok} {
                set ci $coverage($item)
                catch {set ci [expr {int($ci)}]}
                #outputMsg " $item / $tval / $coverage($item) / $ci" red
# neutral - grey         
                if {$coverage($item) != "" && $ci < 0} {
                  [[$worksheet($sempmi_coverage) Range B$r] Interior] Color $legendColor(gray)
                  set coverageLegend 1
                  lappend coverageStyle "$r $nf gray"
# too few - red or cyan
                } elseif {$tval < $ci} {
                  set str "'$tval/$ci"
                  $cells($sempmi_coverage) Item $r 2 $str
                  [$worksheet($sempmi_coverage) Range B$r] HorizontalAlignment [expr -4108]
                  set coverageLegend 1
                  if {$tval == 0} {
                    [[$worksheet($sempmi_coverage) Range B$r] Interior] Color $legendColor(magenta)
                    lappend coverageStyle "$r $nf magenta $str"
                  } else {
                    [[$worksheet($sempmi_coverage) Range B$r] Interior] Color $legendColor(red)
                    lappend coverageStyle "$r $nf red $str"
                  }
# too many - yellow
                } elseif {$tval > $ci && $tval != 0} {
                  set ci1 $coverage($item)
                  if {$ci1 == ""} {set ci1 0}
                  set str "'$tval/[expr {int($ci1)}]"
                  $cells($sempmi_coverage) Item $r 2 $str
                  [[$worksheet($sempmi_coverage) Range B$r] Interior] Color $legendColor(yellow)
                  [$worksheet($sempmi_coverage) Range B$r] NumberFormat "@"
                  set coverageLegend 1
                  lappend coverageStyle "$r $nf yellow $str"
# just right - green
                } elseif {$tval != 0} {
                  [[$worksheet($sempmi_coverage) Range B$r] Interior] Color $legendColor(green)
                  set coverageLegend 1
                  lappend coverageStyle "$r $nf green"
                }
              }
            }
          }
        }
      }

# multiple files
    } elseif {$nfile == [llength $fileList]} {
      if {[info exists coverageStyle]} {
        foreach item $coverageStyle {
          set r [lindex [split $item " "] 0]
          set c [expr {[lindex [split $item " "] 1]+1}]
          set style [lindex [split $item " "] 2]
          if {[llength $item] > 3} {
            set str [lindex [split $item " "] 3]
            $cells1($sempmi_coverage) Item $r $c $str
            [$worksheet1($sempmi_coverage) Range [cellRange $r $c]] HorizontalAlignment [expr -4108]
          }
          #outputMsg "$r $c $style" green
          [[$worksheet1($sempmi_coverage) Range [cellRange $r $c]] Interior] Color $legendColor($style)
        }
      }
    }
  } emsg3]} {
    errorMsg "ERROR adding to PMI Representation Coverage worksheet: $emsg3"
  }
}

# -------------------------------------------------------------------------------
# format semantic PMI coverage analysis worksheet, also PMI totals
proc spmiCoverageFormat {sum {multi 1}} {
  global cells cells1 col1 coverageLegend coverageStyle excel1 lenfilelist localName opt excelVersion
  global pmiModifiers pmiUnicode recPracNames sempmi_coverage sempmi_totals spmiTypes worksheet worksheet1 

  #outputMsg "spmiCoverageFormat $multi" red

# delete worksheet if no semantic PMI
  if {$multi && ![info exists sempmi_totals]} {
    catch {$excel1 DisplayAlerts False}
    $worksheet1($sempmi_coverage) Delete
    catch {$excel1 DisplayAlerts True}
    return
  }

# total PMI
  if {[catch {
    set i1 1
    if {$multi} {
      set col1($sempmi_coverage) [expr {$lenfilelist+2}]
      $cells1($sempmi_coverage) Item 3 $col1($sempmi_coverage) "Total PMI"
      foreach idx [array names sempmi_totals] {
        $cells1($sempmi_coverage) Item $idx $col1($sempmi_coverage) $sempmi_totals($idx)
      }
      catch {unset sempmi_totals}
    
# pmi names on right, if necessary
      if {$col1($sempmi_coverage) > 20} {
        set r 3
        foreach item $spmiTypes {
          set str0 [join $item]
          set str $str0
          if {$str != "square" && $str != "controlled_radius"} {
            if {[info exists pmiModifiers($str0)]}   {append str "  $pmiModifiers($str0)"}
            set str1 $str
            set c1 [string last "_" $str]
            if {$c1 != -1} {set str1 [string range $str 0 $c1-1]}
            if {[info exists pmiUnicode($str1)]} {append str "  $pmiUnicode($str1)"}
            $cells1($sempmi_coverage) Item [incr r] [expr {$col1($sempmi_coverage)+1}] $str
          }
        }
        set i1 2
      }
      $worksheet1($sempmi_coverage) Activate
    }
 
# horizontal break lines
    set idx1 [list 20 41 54 60 80]
    if {!$multi} {set idx1 [list 3 4 20 41 54 60 80]}
    for {set r 200} {$r >= [lindex $idx1 end]} {incr r -1} {
      if {$multi} {
        set val [[$cells1($sempmi_coverage) Item $r 1] Value]
      } else {
        set val [[$cells($sempmi_coverage) Item $r 1] Value]
      }
      if {$val != ""} {
        lappend idx1 [expr {$r+1}]
        break
      }
    }    

# horizontal lines
    foreach idx $idx1 {
      if {$multi} {
        set range [$worksheet1($sempmi_coverage) Range [cellRange $idx 1] [cellRange $idx [expr {$col1($sempmi_coverage)+$i1-1}]]]
      } else {
        set range [$worksheet($sempmi_coverage) Range [cellRange $idx 1] [cellRange $idx 2]]
      }
      catch {[[$range Borders] Item [expr 8]] Weight [expr 2]}
    }

# vertical line(s)
    if {$multi} {
      for {set i 0} {$i < $i1} {incr i} {
        set range [$worksheet1($sempmi_coverage) Range [cellRange 1 [expr {$col1($sempmi_coverage)+$i}]] [cellRange [expr {[lindex $idx1 end]-1}] [expr {$col1($sempmi_coverage)+$i}]]]
        catch {[[$range Borders] Item [expr 7]] Weight [expr 2]}
      }
      
# fix row 3 height and width
      set range [$worksheet1($sempmi_coverage) Range 3:3]
      $range RowHeight 300
      [$worksheet1($sempmi_coverage) Columns] AutoFit

      $cells1($sempmi_coverage) Item [expr {[lindex $idx1 end]+1}] 1 "Section Numbers refer to the CAx-IF Recommended Practice for $recPracNames(pmi242)"
      set anchor [$worksheet1($sempmi_coverage) Range [cellRange [expr {[lindex $idx1 end]+1}] 1]]
      [$worksheet1($sempmi_coverage) Hyperlinks] Add $anchor [join "https://www.cax-if.org/joint_testing_info.html#recpracs"] [join ""] [join "Link to CAx-IF Recommended Practices"]
      
      if {[info exists coverageStyle]} {spmiCoverageLegend $multi [expr {[lindex $idx1 end]+3}]}
      
      [$worksheet1($sempmi_coverage) Rows] AutoFit
      [$worksheet1($sempmi_coverage) Range "B4"] Select
      [$excel1 ActiveWindow] FreezePanes [expr 1]
      [$worksheet1($sempmi_coverage) Range "A1"] Select
      catch {[$worksheet1($sempmi_coverage) PageSetup] PrintGridlines [expr 1]}

# single file
    } else {
      set i1 3
      for {set i 0} {$i < $i1} {incr i} {
        set range [$worksheet($sempmi_coverage) Range [cellRange 3 [expr {$i+1}]] [cellRange [expr {[lindex $idx1 end]-1}] [expr {$i+1}]]]
        catch {[[$range Borders] Item [expr 7]] Weight [expr 2]}
      }
      
      if {$coverageLegend} {spmiCoverageLegend $multi}
      [$worksheet($sempmi_coverage) Columns] AutoFit

      $cells($sempmi_coverage) Item 1 4 "Section Numbers refer to the CAx-IF Recommended Practice for $recPracNames(pmi242)"
      set range [$worksheet($sempmi_coverage) Range D1:N1]
      $range MergeCells [expr 1]
      set anchor [$worksheet($sempmi_coverage) Range D1]
      [$worksheet($sempmi_coverage) Hyperlinks] Add $anchor [join "https://www.cax-if.org/joint_testing_info.html#recpracs"] [join ""] [join "Link to CAx-IF Recommended Practices"]

      [$worksheet($sempmi_coverage) Range "A1"] Select
      catch {[$worksheet($sempmi_coverage) PageSetup] PrintGridlines [expr 1]}
      $cells($sempmi_coverage) Item 1 1 [file tail $localName]
    }

# errors
  } emsg]} {
    errorMsg "ERROR formatting PMI Representation Coverage worksheet: $emsg"
  }
}

# -------------------------------------------------------------------------------
# add coverage legend
proc spmiCoverageLegend {multi {row 3}} {
  global cells cells1 excel excel1 legendColor sempmi_coverage worksheet worksheet1
  
  if {$multi == 0} {
    set cl $cells($sempmi_coverage)
    set ws $worksheet($sempmi_coverage)
    set r $row
    set c D
  } else {
    set cl $cells1($sempmi_coverage)
    set ws $worksheet1($sempmi_coverage)
    set r $row
    set c A
  }

  if {!$multi} {set e $excel}
  if {$multi} {set e $excel1}
  
  set n 0
  set legend {{"Values as Compared to NIST Test Case Drawing" ""} \
              {"See Help > NIST CAD Models" ""} \
              {"Match" "green"} \
              {"More than expected" "yellow"} \
              {"Less than expected" "red"} \
              {"None found" "magenta"} \
              {"Not in CAx-IF Recommended Practice" "gray"}}
  foreach item $legend {
    set str [lindex $item 0]
    $cl Item $r $c $str

    set range [$ws Range $c$r]
    [$range Font] Bold [expr 1]

    set color [lindex $item 1]
    if {$color != ""} {[$range Interior] Color $legendColor($color)}

    if {[expr {int([$e Version])}] >= 12} {
      [[$range Borders] Item [expr 10]] Weight [expr 2]
      [[$range Borders] Item [expr 7]] Weight [expr 2]
      incr n
      if {$n == 1} {
        [[$range Borders] Item [expr 8]] Weight [expr 2]
      } elseif {$n == [llength $legend]} {
        [[$range Borders] Item [expr 9]] Weight [expr 2]
      }
    }
    incr r    
  }
}