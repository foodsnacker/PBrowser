; ============================================================================
; CSSParser.pbi v0.1.0 - STAGE 1 (Selectors + Grouping)
; ----------------------------------------------------------------------------
; Erweiterungen (Etappe 1):
;  - Selector-Gruppierung: "h1, h2, h3"
;  - Komplexe Selektoren als String erhalten (z.B. "div p", "p.center", "p#main")
;  - Neue SelectorType: #Selector_Complex
;  - Whitespace robust bereinigt (CleanSelector)
; ----------------------------------------------------------------------------
; Hinweis: Matching/Cascade/Specificity passiert in Style.pbi
; ============================================================================

DeclareModule CSSParser

  Enumeration SelectorType
    #Selector_Tag
    #Selector_Class
    #Selector_ID
    #Selector_Complex
  EndEnumeration

  Structure CSSRule
    SelectorType.i
    Selector.s          ; bereinigter Selektor (einzelner Selektor, keine Kommas)
    Map Properties.s()
  EndStructure

  Structure StyleSheet
    List Rules.CSSRule()
  EndStructure

  Declare.i Parse(CSS.s)
  Declare FreeStyleSheet(*Sheet.StyleSheet)

EndDeclareModule

Module CSSParser

  Procedure.s TrimCSS(Text.s)
    ProcedureReturn Trim(Text)
  EndProcedure

  ; Entfernt Zeilenumbrüche/Tabs und trimmt
  Procedure.s CleanSelector(Selector.s)
    Selector = Trim(Selector)
    Selector = RemoveString(Selector, #CR$)
    Selector = RemoveString(Selector, #LF$)
    Selector = RemoveString(Selector, #TAB$)

    ; Mehrfach-Spaces zu einem Space zusammenfassen
    While FindString(Selector, "  ")
      Selector = ReplaceString(Selector, "  ", " ")
    Wend

    Selector = Trim(Selector)
    ProcedureReturn Selector
  EndProcedure

  Procedure.i DetermineSelectorType(Selector.s)
    Protected s.s = CleanSelector(Selector)

    ; Komplex wenn Spaces (Descendant) oder kombinierte Tokens vorkommen
    If FindString(s, " ")
      ProcedureReturn #Selector_Complex
    EndIf

    ; beginnt mit . oder # als "reiner" selector?
    If Left(s, 1) = "."
      ; ".class" ist simple class, ".class#id" wäre complex
      If FindString(Mid(s, 2), ".") Or FindString(Mid(s, 2), "#")
        ProcedureReturn #Selector_Complex
      EndIf
      ProcedureReturn #Selector_Class
    EndIf

    If Left(s, 1) = "#"
      If FindString(Mid(s, 2), ".") Or FindString(Mid(s, 2), "#")
        ProcedureReturn #Selector_Complex
      EndIf
      ProcedureReturn #Selector_ID
    EndIf

    ; tag.class / tag#id → complex
    If FindString(s, ".") Or FindString(s, "#")
      ProcedureReturn #Selector_Complex
    EndIf

    ProcedureReturn #Selector_Tag
  EndProcedure

  Procedure AddRuleFromSelector(*Sheet.StyleSheet, Selector.s, PropertiesPart.s)
    Protected NewRule.CSSRule
    Protected PropList.s, i.i, PropPair.s, PropName.s, PropValue.s, ColonPos.i

    Selector = CleanSelector(Selector)
    If Selector = ""
      ProcedureReturn
    EndIf

    InitializeStructure(@NewRule, CSSRule)
    NewRule\Selector = Selector
    NewRule\SelectorType = DetermineSelectorType(Selector)

    PropList = TrimCSS(PropertiesPart)

    For i = 1 To CountString(PropList, ";") + 1
      PropPair = TrimCSS(StringField(PropList, i, ";"))
      If PropPair <> ""
        ColonPos = FindString(PropPair, ":", 1)
        If ColonPos > 0
          PropName = CleanSelector(Left(PropPair, ColonPos - 1))
          PropValue = TrimCSS(Mid(PropPair, ColonPos + 1))
          If PropName <> "" And PropValue <> ""
            NewRule\Properties(LCase(PropName)) = PropValue
          EndIf
        EndIf
      EndIf
    Next

    AddElement(*Sheet\Rules())
    CopyStructure(@NewRule, *Sheet\Rules(), CSSRule)
  EndProcedure

  Procedure.i Parse(CSS.s)
    Protected *Sheet.StyleSheet
    Protected Pos.i, L.i, Char.s
    Protected InProperties.i
    Protected SelectorPart.s, PropertiesPart.s
    Protected BraceCount.i

    *Sheet = AllocateMemory(SizeOf(StyleSheet))
    If Not *Sheet
      ProcedureReturn 0
    EndIf
    InitializeStructure(*Sheet, StyleSheet)

    L = Len(CSS)
    Pos = 1
    InProperties = #False
    SelectorPart = ""
    PropertiesPart = ""
    BraceCount = 0

    While Pos <= L
      Char = Mid(CSS, Pos, 1)

      If Char = "{"
        InProperties = #True
        BraceCount + 1

      ElseIf Char = "}"
        BraceCount - 1
        If BraceCount = 0
          InProperties = #False

          SelectorPart = CleanSelector(SelectorPart)
          PropertiesPart = TrimCSS(PropertiesPart)

          If SelectorPart <> "" And PropertiesPart <> ""
            ; Gruppierung: "h1, h2, h3"
            Protected sCount.i = CountString(SelectorPart, ",") + 1
            Protected si.i, Sel.s
            For si = 1 To sCount
              Sel = CleanSelector(StringField(SelectorPart, si, ","))
              If Sel <> ""
                AddRuleFromSelector(*Sheet, Sel, PropertiesPart)
              EndIf
            Next
          EndIf

          SelectorPart = ""
          PropertiesPart = ""
        EndIf

      ElseIf InProperties
        PropertiesPart + Char
      Else
        SelectorPart + Char
      EndIf

      Pos + 1
    Wend

    ProcedureReturn *Sheet
  EndProcedure

  Procedure FreeStyleSheet(*Sheet.StyleSheet)
    If *Sheet
      ForEach *Sheet\Rules()
        ClearMap(*Sheet\Rules()\Properties())
      Next
      ClearList(*Sheet\Rules())
      FreeMemory(*Sheet)
    EndIf
  EndProcedure

EndModule

; IDE Options = PureBasic 6.21 LTS (MacOS X - arm64)
; EnableXP
; DPIAware
