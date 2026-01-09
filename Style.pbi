; ============================================================================
; Style.pbi v0.6.0 - STAGE 1 (Cascade + Specificity + Inheritance)
; ----------------------------------------------------------------------------
; Erweiterungen (Etappe 1):
;  - Selector-Matching:
;      * tag, .class, #id
;      * tag.class, tag#id, .a.b, tag.a.b
;      * Descendant: "div p" (ohne >, +, ~)
;      * Gruppierung "h1, h2" wird im CSSParser bereits zu einzelnen Regeln expandiert
;  - Cascade:
;      * Specificity (IDs*100 + Classes*10 + Tags)
;      * Reihenfolge: spätere Regeln gewinnen bei gleicher Specificity
;      * Speicherung pro Property in Node\Attributes():
;          css-<prop>       = value
;          cssspec-<prop>   = specificity score
;          cssorder-<prop>  = rule order
;  - Inheritance:
;      * GetComputedStyle erbt inheritable props vom Parent und überschreibt lokal
; ----------------------------------------------------------------------------
; Hinweis: Das System bleibt bewusst kompatibel zu deiner bisherigen "css-..." Attribute-
; Ablage, wird aber jetzt korrekt "CSS-like" überschrieben.
; ============================================================================

XIncludeFile "HTMLParser.pbi"
XIncludeFile "CSSParser.pbi"

DeclareModule Style

  Structure ComputedStyle
    ; Font
    FontSize.i
    FontStyle.i
    FontFamily.s          ; CSS 1

    ; Text
    Color.i
    TextDecoration.i      ; CSS 1 (0=none, 1=underline, 2=line-through, 3=overline, 4=blink)
    TextAlign.i           ; CSS 1 (0=left, 1=center, 2=right, 3=justify)
    LineHeight.i          ; CSS 1

    ; White-space
    WhiteSpace.i         ; 0=normal, 1=pre, 2=pre-wrap

    ; Background
    BackgroundColor.i

    ; Box Model
    Width.i
    Height.i
    MarginTop.i
    MarginRight.i
    MarginBottom.i
    MarginLeft.i
    PaddingTop.i
    PaddingRight.i
    PaddingBottom.i
    PaddingLeft.i

    ; Border
    BorderWidth.i
    BorderStyle.i         ; 0=none, 1=solid, 2=dashed, 3=dotted
    BorderColor.i

    ; Layout
    Display.i             ; 0=block, 1=inline, 2=none
  EndStructure

  Declare ApplyStyleSheet(*Root.HTMLParser::DOMNode, *Sheet.CSSParser::StyleSheet)
  Declare GetComputedStyle(*Node.HTMLParser::DOMNode, *Style.ComputedStyle)

EndDeclareModule

Module Style

  ; -----------------------------
  ; Helpers: Parsing
  ; -----------------------------
  Procedure.i ParseColor(ColorString.s)
    Protected R.i, G.i, B.i

    ColorString = Trim(ColorString)
    Debug ColorString

    If Left(ColorString, 1) = "#"
      ColorString = Mid(ColorString, 2)

      If Len(ColorString) = 3
        R = Val("$" + Mid(ColorString, 1, 1)) * 17
        G = Val("$" + Mid(ColorString, 2, 1)) * 17
        B = Val("$" + Mid(ColorString, 3, 1)) * 17
      ElseIf Len(ColorString) = 6
        R = Val("$" + Mid(ColorString, 1, 2))
        G = Val("$" + Mid(ColorString, 3, 2))
        B = Val("$" + Mid(ColorString, 5, 2))
      EndIf

      Protected Result.i = RGB(R, G, B)
      Debug "[Style::ParseColor] #" + Left(ColorString, 6) + " → RGB(" + Str(R) + ", " + Str(G) + ", " + Str(B) + ") = " + Str(Result)
      ProcedureReturn Result
    EndIf

    ; HTML 4.01 Named Colors (16 Standard-Farben)
    Select LCase(ColorString)
      Case "black": ProcedureReturn RGB(0, 0, 0)
      Case "silver": ProcedureReturn RGB(192, 192, 192)
      Case "gray", "grey": ProcedureReturn RGB(128, 128, 128)
      Case "white": ProcedureReturn RGB(255, 255, 255)
      Case "maroon": ProcedureReturn RGB(128, 0, 0)
      Case "red": ProcedureReturn RGB(255, 0, 0)
      Case "purple": ProcedureReturn RGB(128, 0, 128)
      Case "fuchsia": ProcedureReturn RGB(255, 0, 255)
      Case "green": ProcedureReturn RGB(0, 128, 0)
      Case "lime": ProcedureReturn RGB(0, 255, 0)
      Case "olive": ProcedureReturn RGB(128, 128, 0)
      Case "yellow": ProcedureReturn RGB(255, 255, 0)
      Case "navy": ProcedureReturn RGB(0, 0, 128)
      Case "blue": ProcedureReturn RGB(0, 0, 255)
      Case "teal": ProcedureReturn RGB(0, 128, 128)
      Case "aqua": ProcedureReturn RGB(0, 255, 255)
      Default: ProcedureReturn RGB(0, 0, 0)
    EndSelect
  EndProcedure

  Procedure.i ParseSize(SizeString.s)
    Protected Value.s = Trim(SizeString)
    Value = RemoveString(Value, "px")
    Value = RemoveString(Value, "pt")
    Value = RemoveString(Value, "em")
    ProcedureReturn Val(Value)
  EndProcedure

  Procedure.i ParseFontWeight(WeightString.s)
    WeightString = LCase(Trim(WeightString))
    If WeightString = "bold" Or Val(WeightString) >= 600
      ProcedureReturn #PB_Font_Bold
    EndIf
    ProcedureReturn 0
  EndProcedure

  Procedure.i ParseFontStyle(StyleString.s)
    StyleString = LCase(Trim(StyleString))
    If StyleString = "italic" Or StyleString = "oblique"
      ProcedureReturn #PB_Font_Italic
    EndIf
    ProcedureReturn 0
  EndProcedure

  ; CSS 1 Parser - Font-Family Mapping (vereinfacht)
  Procedure.s ParseFontFamily(FamilyString.s)
    FamilyString = LCase(Trim(FamilyString))

    FamilyString = RemoveString(FamilyString, "'")
    FamilyString = RemoveString(FamilyString, Chr(34))  ; "

    Select FamilyString
      Case "arial", "helvetica", "sans-serif"
        ProcedureReturn "Arial"
      Case "times", "times new roman", "serif"
        ProcedureReturn "Times New Roman"
      Case "courier", "courier new", "monospace"
        ProcedureReturn "Courier New"
      Default
        ProcedureReturn "Arial"
    EndSelect
  EndProcedure

  Procedure.i ParseTextDecoration(DecoString.s)
    DecoString = LCase(Trim(DecoString))
    Select DecoString
      Case "none": ProcedureReturn 0
      Case "underline": ProcedureReturn 1
      Case "line-through": ProcedureReturn 2
      Case "overline": ProcedureReturn 3
      Default: ProcedureReturn 0
    EndSelect
  EndProcedure

  Procedure.i ParseTextAlign(AlignString.s)
    AlignString = LCase(Trim(AlignString))
    Select AlignString
      Case "left": ProcedureReturn 0
      Case "center": ProcedureReturn 1
      Case "right": ProcedureReturn 2
      Case "justify": ProcedureReturn 3
      Default: ProcedureReturn 0
    EndSelect
  EndProcedure

  Procedure.i ParseLineHeight(HeightString.s, FontSize.i)
    HeightString = Trim(HeightString)

    If FindString(HeightString, "px")
      ProcedureReturn Val(RemoveString(HeightString, "px"))
    EndIf

    If FindString(HeightString, "%")
      Protected Percent.f = ValF(RemoveString(HeightString, "%"))
      ProcedureReturn FontSize * Percent / 100
    EndIf

    Protected Multi.f = ValF(HeightString)
    If Multi > 0
      ProcedureReturn FontSize * Multi
    EndIf

    ProcedureReturn FontSize * 1.2
  EndProcedure

  
  Procedure.i ParseWhiteSpace(WSString.s)
    WSString = LCase(Trim(WSString))
    Select WSString
      Case "normal": ProcedureReturn 0
      Case "pre": ProcedureReturn 1
      Case "pre-wrap": ProcedureReturn 2
      Default: ProcedureReturn 0
    EndSelect
  EndProcedure

Procedure.i ParseDisplay(DisplayString.s)
    DisplayString = LCase(Trim(DisplayString))
    Select DisplayString
      Case "block": ProcedureReturn 0
      Case "inline": ProcedureReturn 1
      Case "none": ProcedureReturn 2
      Default: ProcedureReturn 0
    EndSelect
  EndProcedure

  Procedure.i ParseBorderStyle(StyleString.s)
    StyleString = LCase(Trim(StyleString))
    Select StyleString
      Case "none": ProcedureReturn 0
      Case "solid": ProcedureReturn 1
      Case "dashed": ProcedureReturn 2
      Case "dotted": ProcedureReturn 3
      Default: ProcedureReturn 0
    EndSelect
  EndProcedure

  ; -----------------------------
  ; Helpers: Selector Matching
  ; -----------------------------
  Procedure.s NormalizeSpaces(s.s)
    s = Trim(s)
    While FindString(s, "  ")
      s = ReplaceString(s, "  ", " ")
    Wend
    ProcedureReturn s
  EndProcedure

  Procedure.i NodeHasClass(*Node.HTMLParser::DOMNode, ClassName.s)
    If Not *Node
      ProcedureReturn #False
    EndIf
    ForEach *Node\Classes()
      If LCase(*Node\Classes()) = LCase(ClassName)
        ProcedureReturn #True
      EndIf
    Next
    ProcedureReturn #False
  EndProcedure

  ; part: "tag", ".c", "#id", "tag.c", "tag#id", ".a.b", "tag.a.b#id"
  Procedure.i MatchesSimpleSelector(*Node.HTMLParser::DOMNode, part.s)
    Protected tag.s, id.s
    Protected classes.s
    Protected p.s = part

    If Not *Node Or p = ""
      ProcedureReturn #False
    EndIf

    ; split id
    Protected hashPos.i = FindString(p, "#", 1)
    If hashPos > 0
      id = Mid(p, hashPos + 1)
      p = Left(p, hashPos - 1)
      ; id may still contain ".class" after it in weird selectors, ignore after first '.' for now
      Protected dotInId.i = FindString(id, ".", 1)
      If dotInId > 0
        id = Left(id, dotInId - 1)
      EndIf
    EndIf

    ; tag is before first '.'
    Protected dotPos.i = FindString(p, ".", 1)
    If dotPos > 0
      tag = Left(p, dotPos - 1)
      classes = Mid(p, dotPos + 1)
    Else
      tag = p
      classes = ""
    EndIf

    tag = LCase(Trim(tag))
    If tag = "*"
      tag = ""
    EndIf

    ; Tag check (if present)
    If tag <> ""
      If LCase(*Node\TagName) <> tag
        ProcedureReturn #False
      EndIf
    EndIf

    ; ID check (if present)
    If id <> ""
      If LCase(*Node\ID) <> LCase(Trim(id))
        ProcedureReturn #False
      EndIf
    EndIf

    ; Class checks (all must exist)
    If classes <> ""
      Protected cCount.i = CountString(classes, ".") + 1
      Protected i.i, c.s
      For i = 1 To cCount
        c = Trim(StringField(classes, i, "."))
        If c <> ""
          If Not NodeHasClass(*Node, c)
            ProcedureReturn #False
          EndIf
        EndIf
      Next
    EndIf

    ProcedureReturn #True
  EndProcedure

  ; Descendant only: "div p span"
  Procedure.i SelectorMatchesNode(*Node.HTMLParser::DOMNode, Selector.s)
    Protected sel.s = NormalizeSpaces(Selector)
    If sel = ""
      ProcedureReturn #False
    EndIf

    ; split into parts by space
    Protected partCount.i = CountString(sel, " ") + 1
    Protected parts.s

    ; We match from last to first
    Protected idx.i = partCount
    Protected *cur.HTMLParser::DOMNode = *Node

    While idx >= 1
      parts = Trim(StringField(sel, idx, " "))
      If parts = ""
        idx - 1
        Continue
      EndIf

      If idx = partCount
        ; last part must match current node
        If Not MatchesSimpleSelector(*cur, parts)
          ProcedureReturn #False
        EndIf
        idx - 1
      Else
        ; find an ancestor that matches this part
        Protected found.i = #False
        *cur = *cur\Parent
        While *cur
          If MatchesSimpleSelector(*cur, parts)
            found = #True
            Break
          EndIf
          *cur = *cur\Parent
        Wend

        If Not found
          ProcedureReturn #False
        EndIf

        idx - 1
      EndIf
    Wend

    ProcedureReturn #True
  EndProcedure

  Procedure.i CalcSpecificity(Selector.s)
    Protected sel.s = NormalizeSpaces(Selector)
    Protected ids.i = 0, classes.i = 0, tags.i = 0

    If sel = ""
      ProcedureReturn 0
    EndIf

    Protected partCount.i = CountString(sel, " ") + 1
    Protected i.i, part.s

    For i = 1 To partCount
      part = Trim(StringField(sel, i, " "))
      If part = ""
        Continue
      EndIf

      ids + CountString(part, "#")
      classes + CountString(part, ".")

      ; tag exists if first char not '.' or '#'
      Protected t.s = part
      Protected p1.i = FindString(t, "#", 1)
      Protected p2.i = FindString(t, ".", 1)
      Protected cut.i = 0
      If p1 > 0 And p2 > 0
        cut = p1
        If p2 < cut : cut = p2 : EndIf
      ElseIf p1 > 0
        cut = p1
      ElseIf p2 > 0
        cut = p2
      EndIf

      Protected tag.s
      If cut > 0
        tag = Left(t, cut - 1)
      Else
        tag = t
      EndIf

      tag = LCase(Trim(tag))
      If tag <> "" And tag <> "*"
        ; ".class" -> tag is "" (ok)
        If Left(tag, 1) <> "." And Left(tag, 1) <> "#"
          tags + 1
        EndIf
      EndIf
    Next

    ProcedureReturn ids * 100 + classes * 10 + tags
  EndProcedure

  ; -----------------------------
  ; Cascade: apply property with specificity/order
  ; -----------------------------
  Procedure ApplyCascadedProperty(*Node.HTMLParser::DOMNode, PropNameLower.s, PropValue.s, Spec.i, Order.i)
    If Not *Node
      ProcedureReturn
    EndIf

    Protected keyValue.s = "css-" + PropNameLower
    Protected keySpec.s = "cssspec-" + PropNameLower
    Protected keyOrder.s = "cssorder-" + PropNameLower

    Protected oldSpec.i = -1
    Protected oldOrder.i = -1

    If FindMapElement(*Node\Attributes(), keySpec)
      oldSpec = Val(*Node\Attributes())
    EndIf
    If FindMapElement(*Node\Attributes(), keyOrder)
      oldOrder = Val(*Node\Attributes())
    EndIf

    If Spec > oldSpec Or (Spec = oldSpec And Order >= oldOrder)
      *Node\Attributes(keyValue) = PropValue
      *Node\Attributes(keySpec) = Str(Spec)
      *Node\Attributes(keyOrder) = Str(Order)
    EndIf
  EndProcedure

  Procedure ApplyRuleToNode(*Node.HTMLParser::DOMNode, *Rule.CSSParser::CSSRule, RuleOrder.i)
    If Not *Node Or Not *Rule
      ProcedureReturn
    EndIf

    If Not SelectorMatchesNode(*Node, *Rule\Selector)
      ProcedureReturn
    EndIf

    Protected Spec.i = CalcSpecificity(*Rule\Selector)
    Debug "[Style::ApplyRuleToNode] Regel matched: '" + *Rule\Selector + "' auf <" + *Node\TagName + "> (spec=" + Str(Spec) + ", order=" + Str(RuleOrder) + ")"

    ForEach *Rule\Properties()
      Protected PropName.s = LCase(MapKey(*Rule\Properties()))
      Protected PropValue.s = *Rule\Properties()

      ; Expandiere Shorthand Properties
      Select PropName
        Case "border"
          Protected Parts.s = PropValue
          Protected W.s = Trim(StringField(Parts, 1, " "))
          Protected S.s = Trim(StringField(Parts, 2, " "))
          Protected C.s = Trim(StringField(Parts, 3, " "))

          If W <> ""
            ApplyCascadedProperty(*Node, "border-width", W, Spec, RuleOrder)
            Debug "  → Expandiere border-width = " + W
          EndIf
          If S <> ""
            ApplyCascadedProperty(*Node, "border-style", S, Spec, RuleOrder)
            Debug "  → Expandiere border-style = " + S
          EndIf
          If C <> ""
            ApplyCascadedProperty(*Node, "border-color", C, Spec, RuleOrder)
            Debug "  → Expandiere border-color = " + C
          EndIf

        Case "margin"
          Protected NumValues.i = CountString(PropValue, " ") + 1
          Select NumValues
            Case 1
              Protected AllM.s = Trim(PropValue)
              ApplyCascadedProperty(*Node, "margin-top", AllM, Spec, RuleOrder)
              ApplyCascadedProperty(*Node, "margin-right", AllM, Spec, RuleOrder)
              ApplyCascadedProperty(*Node, "margin-bottom", AllM, Spec, RuleOrder)
              ApplyCascadedProperty(*Node, "margin-left", AllM, Spec, RuleOrder)
              Debug "  → Expandiere margin (all) = " + AllM

            Case 2
              Protected MV.s = Trim(StringField(PropValue, 1, " "))
              Protected MH.s = Trim(StringField(PropValue, 2, " "))
              ApplyCascadedProperty(*Node, "margin-top", MV, Spec, RuleOrder)
              ApplyCascadedProperty(*Node, "margin-bottom", MV, Spec, RuleOrder)
              ApplyCascadedProperty(*Node, "margin-left", MH, Spec, RuleOrder)
              ApplyCascadedProperty(*Node, "margin-right", MH, Spec, RuleOrder)
              Debug "  → Expandiere margin (v/h) = " + MV + " / " + MH

            Case 4
              ApplyCascadedProperty(*Node, "margin-top", Trim(StringField(PropValue, 1, " ")), Spec, RuleOrder)
              ApplyCascadedProperty(*Node, "margin-right", Trim(StringField(PropValue, 2, " ")), Spec, RuleOrder)
              ApplyCascadedProperty(*Node, "margin-bottom", Trim(StringField(PropValue, 3, " ")), Spec, RuleOrder)
              ApplyCascadedProperty(*Node, "margin-left", Trim(StringField(PropValue, 4, " ")), Spec, RuleOrder)
              Debug "  → Expandiere margin (4) = " + PropValue
          EndSelect

        Case "padding"
          NumValues = CountString(PropValue, " ") + 1
          Select NumValues
            Case 1
              Protected AllP.s = Trim(PropValue)
              ApplyCascadedProperty(*Node, "padding-top", AllP, Spec, RuleOrder)
              ApplyCascadedProperty(*Node, "padding-right", AllP, Spec, RuleOrder)
              ApplyCascadedProperty(*Node, "padding-bottom", AllP, Spec, RuleOrder)
              ApplyCascadedProperty(*Node, "padding-left", AllP, Spec, RuleOrder)
              Debug "  → Expandiere padding (all) = " + AllP

            Case 2
              Protected PV.s = Trim(StringField(PropValue, 1, " "))
              Protected PH.s = Trim(StringField(PropValue, 2, " "))
              ApplyCascadedProperty(*Node, "padding-top", PV, Spec, RuleOrder)
              ApplyCascadedProperty(*Node, "padding-bottom", PV, Spec, RuleOrder)
              ApplyCascadedProperty(*Node, "padding-left", PH, Spec, RuleOrder)
              ApplyCascadedProperty(*Node, "padding-right", PH, Spec, RuleOrder)
              Debug "  → Expandiere padding (v/h) = " + PV + " / " + PH

            Case 4
              ApplyCascadedProperty(*Node, "padding-top", Trim(StringField(PropValue, 1, " ")), Spec, RuleOrder)
              ApplyCascadedProperty(*Node, "padding-right", Trim(StringField(PropValue, 2, " ")), Spec, RuleOrder)
              ApplyCascadedProperty(*Node, "padding-bottom", Trim(StringField(PropValue, 3, " ")), Spec, RuleOrder)
              ApplyCascadedProperty(*Node, "padding-left", Trim(StringField(PropValue, 4, " ")), Spec, RuleOrder)
              Debug "  → Expandiere padding (4) = " + PropValue
          EndSelect

        Default
          ApplyCascadedProperty(*Node, PropName, PropValue, Spec, RuleOrder)
          Debug "  → Setze Attribut: css-" + PropName + " = " + PropValue
      EndSelect
    Next
  EndProcedure

  Procedure ApplyStyleSheetToTree(*Node.HTMLParser::DOMNode, *Sheet.CSSParser::StyleSheet, *OrderCounter.Integer)
    If Not *Node Or Not *Sheet
      ProcedureReturn
    EndIf

    ForEach *Sheet\Rules()
      *OrderCounter\i + 1
      ApplyRuleToNode(*Node, *Sheet\Rules(), *OrderCounter\i)
    Next

    ForEach *Node\Children()
      ApplyStyleSheetToTree(*Node\Children(), *Sheet, *OrderCounter)
    Next
  EndProcedure

  Procedure ApplyStyleSheet(*Root.HTMLParser::DOMNode, *Sheet.CSSParser::StyleSheet)
    Debug ""
    Debug "=== Style::ApplyStyleSheet START ==="

    If *Root And *Sheet
      Debug "StyleSheet hat " + Str(ListSize(*Sheet\Rules())) + " Regeln"
      Protected counter.Integer
      counter\i = 0
      ApplyStyleSheetToTree(*Root, *Sheet, @counter)
    Else
      Debug "FEHLER: Root oder StyleSheet ist NULL!"
    EndIf

    Debug "=== Style::ApplyStyleSheet END ==="
    Debug ""
  EndProcedure

  ; -----------------------------
  ; Computed Style (mit Inheritance)
  ; -----------------------------
  Procedure GetComputedStyle(*Node.HTMLParser::DOMNode, *Style.ComputedStyle)
    If Not *Node Or Not *Style
      ProcedureReturn
    EndIf

    ; Defaults
    *Style\FontSize = 14
    *Style\FontStyle = 0
    *Style\FontFamily = "Arial"
    *Style\Color = RGB(0, 0, 0)
    *Style\TextDecoration = 0
    *Style\TextAlign = 0
    *Style\LineHeight = 0
    *Style\WhiteSpace = 0
    *Style\BackgroundColor = RGB(255, 255, 255)

    *Style\Width = 0
    *Style\Height = 0
    *Style\MarginTop = 0
    *Style\MarginRight = 0
    *Style\MarginBottom = 0
    *Style\MarginLeft = 0
    *Style\PaddingTop = 0
    *Style\PaddingRight = 0
    *Style\PaddingBottom = 0
    *Style\PaddingLeft = 0
    *Style\BorderWidth = 0
    *Style\BorderStyle = 0
    *Style\BorderColor = RGB(0, 0, 0)
    *Style\Display = 0  ; block

    ; Inheritance (subset, CSS-ish)
    If *Node\Parent
      Protected Parent.ComputedStyle
      GetComputedStyle(*Node\Parent, @Parent)

      *Style\FontSize = Parent\FontSize
      *Style\FontStyle = Parent\FontStyle
      *Style\FontFamily = Parent\FontFamily
      *Style\Color = Parent\Color
      *Style\TextAlign = Parent\TextAlign
      *Style\LineHeight = Parent\LineHeight
      *Style\WhiteSpace = Parent\WhiteSpace

      ; Hinweis: text-decoration ist in CSS2 nicht "inherited" als Property,
      ; aber die visuelle Wirkung propagiert in der Praxis. Für dein Projekt
      ; ist diese Vererbung aktuell hilfreich (und kompatibel zu bisherigem Verhalten).
      *Style\TextDecoration = Parent\TextDecoration
    EndIf

    ; Font
    If FindMapElement(*Node\Attributes(), "css-font-size")
      *Style\FontSize = ParseSize(*Node\Attributes())
    EndIf

    If FindMapElement(*Node\Attributes(), "css-font-weight")
      *Style\FontStyle | ParseFontWeight(*Node\Attributes())
    EndIf

    If FindMapElement(*Node\Attributes(), "css-font-style")
      *Style\FontStyle | ParseFontStyle(*Node\Attributes())
    EndIf

    If FindMapElement(*Node\Attributes(), "css-font-family")
      *Style\FontFamily = ParseFontFamily(*Node\Attributes())
    EndIf

    ; Text
    If FindMapElement(*Node\Attributes(), "css-color")
      *Style\Color = ParseColor(*Node\Attributes())
      Debug "[Style::GetComputedStyle] Node <" + *Node\TagName + "> hat css-color: " + *Node\Attributes() + " → " + Str(*Style\Color)
    EndIf

    If FindMapElement(*Node\Attributes(), "css-text-decoration")
      *Style\TextDecoration = ParseTextDecoration(*Node\Attributes())
      Debug "[GetComputedStyle] " + *Node\TagName + " text-decoration: " + *Node\Attributes() + " → " + Str(*Style\TextDecoration)
    EndIf

    If FindMapElement(*Node\Attributes(), "css-text-align")
      *Style\TextAlign = ParseTextAlign(*Node\Attributes())
    EndIf

    If FindMapElement(*Node\Attributes(), "css-line-height")
      *Style\LineHeight = ParseLineHeight(*Node\Attributes(), *Style\FontSize)
    EndIf

    ; Default line-height if still unset
    If *Style\LineHeight <= 0
      *Style\LineHeight = *Style\FontSize + 6
    EndIf

    ; Background
    If FindMapElement(*Node\Attributes(), "css-background-color")
      *Style\BackgroundColor = ParseColor(*Node\Attributes())
    EndIf

    ; Box Model
    If FindMapElement(*Node\Attributes(), "css-width")
      *Style\Width = ParseSize(*Node\Attributes())
    EndIf

    If FindMapElement(*Node\Attributes(), "css-height")
      *Style\Height = ParseSize(*Node\Attributes())
    EndIf

    If FindMapElement(*Node\Attributes(), "css-margin-top")
      *Style\MarginTop = ParseSize(*Node\Attributes())
    EndIf

    If FindMapElement(*Node\Attributes(), "css-margin-right")
      *Style\MarginRight = ParseSize(*Node\Attributes())
    EndIf

    If FindMapElement(*Node\Attributes(), "css-margin-bottom")
      *Style\MarginBottom = ParseSize(*Node\Attributes())
    EndIf

    If FindMapElement(*Node\Attributes(), "css-margin-left")
      *Style\MarginLeft = ParseSize(*Node\Attributes())
    EndIf

    If FindMapElement(*Node\Attributes(), "css-padding-top")
      *Style\PaddingTop = ParseSize(*Node\Attributes())
    EndIf

    If FindMapElement(*Node\Attributes(), "css-padding-right")
      *Style\PaddingRight = ParseSize(*Node\Attributes())
    EndIf

    If FindMapElement(*Node\Attributes(), "css-padding-bottom")
      *Style\PaddingBottom = ParseSize(*Node\Attributes())
    EndIf

    If FindMapElement(*Node\Attributes(), "css-padding-left")
      *Style\PaddingLeft = ParseSize(*Node\Attributes())
    EndIf

    ; Border
    If FindMapElement(*Node\Attributes(), "css-border-width")
      *Style\BorderWidth = ParseSize(*Node\Attributes())
      Debug "[GetComputedStyle] " + *Node\TagName + " border-width: " + *Node\Attributes() + " → " + Str(*Style\BorderWidth)
    EndIf

    If FindMapElement(*Node\Attributes(), "css-border-style")
      *Style\BorderStyle = ParseBorderStyle(*Node\Attributes())
      Debug "[GetComputedStyle] " + *Node\TagName + " border-style: " + *Node\Attributes() + " → " + Str(*Style\BorderStyle)
    EndIf

    If FindMapElement(*Node\Attributes(), "css-border-color")
      *Style\BorderColor = ParseColor(*Node\Attributes())
      Debug "[GetComputedStyle] " + *Node\TagName + " border-color: " + *Node\Attributes() + " → " + Str(*Style\BorderColor)
    EndIf

    ; Display
    If FindMapElement(*Node\Attributes(), "css-display")
      *Style\Display = ParseDisplay(*Node\Attributes())
    EndIf

    ; White-space
    If FindMapElement(*Node\Attributes(), "css-white-space")
      *Style\WhiteSpace = ParseWhiteSpace(*Node\Attributes())
    EndIf
  EndProcedure

EndModule

; IDE Options = PureBasic 6.21 - C Backend (MacOS X - arm64)
; EnableXP
; DPIAware
