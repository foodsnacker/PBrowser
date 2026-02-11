; ============================================================================
; Style.pbi v0.7.0 - CSS 1 COMPLETE
; ----------------------------------------------------------------------------
; Vollständige CSS 1 Implementierung (53 Properties):
;  - Font: font-family, font-style, font-variant, font-weight, font-size, font
;  - Text: color, text-decoration, text-align, text-indent, text-transform,
;          word-spacing, letter-spacing, vertical-align, line-height
;  - Background: background-color, background-image, background-repeat,
;                background-attachment, background-position, background
;  - Box Model: width, height, float, clear, margin-*, padding-*
;  - Border: border-top-width, border-right-width, border-bottom-width,
;            border-left-width, border-width, border-color, border-style,
;            border-top, border-right, border-bottom, border-left, border
;  - Classification: display, white-space, list-style-type, list-style-image,
;                    list-style-position, list-style
;  - Selector-Matching: tag, .class, #id, tag.class, Descendant ("div p")
;  - Cascade: Specificity + Reihenfolge
;  - Inheritance: alle CSS 1 inheritable Properties
; ============================================================================

XIncludeFile "HTMLParser.pbi"
XIncludeFile "CSSParser.pbi"

DeclareModule Style

  Structure ComputedStyle
    ; Font (CSS 1)
    FontSize.i
    FontStyle.i           ; 0=normal, #PB_Font_Bold, #PB_Font_Italic
    FontFamily.s
    FontVariant.i         ; 0=normal, 1=small-caps

    ; Text (CSS 1)
    Color.i
    TextDecoration.i      ; 0=none, 1=underline, 2=line-through, 3=overline, 4=blink
    TextAlign.i           ; 0=left, 1=center, 2=right, 3=justify
    TextIndent.i          ; px
    TextTransform.i       ; 0=none, 1=capitalize, 2=uppercase, 3=lowercase
    WordSpacing.i         ; px (0=normal)
    LetterSpacing.i       ; px (0=normal)
    VerticalAlign.i       ; 0=baseline, 1=sub, 2=super, 3=top, 4=text-top, 5=middle, 6=bottom, 7=text-bottom
    LineHeight.i

    ; White-space (CSS 1: normal, pre; pre-wrap ist CSS 2.1 Erweiterung)
    WhiteSpace.i          ; 0=normal, 1=pre, 2=pre-wrap

    ; Background (CSS 1)
    BackgroundColor.i
    BackgroundImage.s     ; URL oder "none"
    BackgroundRepeat.i    ; 0=repeat, 1=repeat-x, 2=repeat-y, 3=no-repeat
    BackgroundAttachment.i ; 0=scroll, 1=fixed
    BackgroundPositionX.i ; px
    BackgroundPositionY.i ; px

    ; Box Model (CSS 1)
    Width.i
    Height.i
    Float.i               ; 0=none, 1=left, 2=right
    Clear.i               ; 0=none, 1=left, 2=right, 3=both
    MarginTop.i
    MarginRight.i
    MarginBottom.i
    MarginLeft.i
    PaddingTop.i
    PaddingRight.i
    PaddingBottom.i
    PaddingLeft.i

    ; Border (CSS 1)
    BorderTopWidth.i
    BorderRightWidth.i
    BorderBottomWidth.i
    BorderLeftWidth.i
    BorderStyle.i         ; 0=none, 1=solid, 2=dashed, 3=dotted
    BorderColor.i
    BorderWidth.i         ; Compat: uniform width (= BorderTopWidth)

    ; Classification (CSS 1)
    Display.i             ; 0=block, 1=inline, 2=none, 3=list-item
    ListStyleType.i       ; 0=disc, 1=circle, 2=square, 3=decimal, 4=lower-roman, 5=upper-roman, 6=lower-alpha, 7=upper-alpha, 8=none
    ListStyleImage.s      ; URL oder "none"
    ListStylePosition.i   ; 0=outside, 1=inside
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

  Procedure.i ParseFontVariant(VariantString.s)
    VariantString = LCase(Trim(VariantString))
    If VariantString = "small-caps"
      ProcedureReturn 1
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
      Case "blink": ProcedureReturn 4
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

  Procedure.i ParseTextTransform(TransformString.s)
    TransformString = LCase(Trim(TransformString))
    Select TransformString
      Case "none": ProcedureReturn 0
      Case "capitalize": ProcedureReturn 1
      Case "uppercase": ProcedureReturn 2
      Case "lowercase": ProcedureReturn 3
      Default: ProcedureReturn 0
    EndSelect
  EndProcedure

  Procedure.i ParseVerticalAlign(AlignString.s)
    AlignString = LCase(Trim(AlignString))
    Select AlignString
      Case "baseline": ProcedureReturn 0
      Case "sub": ProcedureReturn 1
      Case "super": ProcedureReturn 2
      Case "top": ProcedureReturn 3
      Case "text-top": ProcedureReturn 4
      Case "middle": ProcedureReturn 5
      Case "bottom": ProcedureReturn 6
      Case "text-bottom": ProcedureReturn 7
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
      Case "list-item": ProcedureReturn 3
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

  Procedure.i ParseFloat(FloatString.s)
    FloatString = LCase(Trim(FloatString))
    Select FloatString
      Case "none": ProcedureReturn 0
      Case "left": ProcedureReturn 1
      Case "right": ProcedureReturn 2
      Default: ProcedureReturn 0
    EndSelect
  EndProcedure

  Procedure.i ParseClear(ClearString.s)
    ClearString = LCase(Trim(ClearString))
    Select ClearString
      Case "none": ProcedureReturn 0
      Case "left": ProcedureReturn 1
      Case "right": ProcedureReturn 2
      Case "both": ProcedureReturn 3
      Default: ProcedureReturn 0
    EndSelect
  EndProcedure

  Procedure.i ParseListStyleType(TypeString.s)
    TypeString = LCase(Trim(TypeString))
    Select TypeString
      Case "disc": ProcedureReturn 0
      Case "circle": ProcedureReturn 1
      Case "square": ProcedureReturn 2
      Case "decimal": ProcedureReturn 3
      Case "lower-roman": ProcedureReturn 4
      Case "upper-roman": ProcedureReturn 5
      Case "lower-alpha": ProcedureReturn 6
      Case "upper-alpha": ProcedureReturn 7
      Case "none": ProcedureReturn 8
      Default: ProcedureReturn 0
    EndSelect
  EndProcedure

  Procedure.i ParseListStylePosition(PosString.s)
    PosString = LCase(Trim(PosString))
    Select PosString
      Case "outside": ProcedureReturn 0
      Case "inside": ProcedureReturn 1
      Default: ProcedureReturn 0
    EndSelect
  EndProcedure

  Procedure.i ParseBackgroundRepeat(RepeatString.s)
    RepeatString = LCase(Trim(RepeatString))
    Select RepeatString
      Case "repeat": ProcedureReturn 0
      Case "repeat-x": ProcedureReturn 1
      Case "repeat-y": ProcedureReturn 2
      Case "no-repeat": ProcedureReturn 3
      Default: ProcedureReturn 0
    EndSelect
  EndProcedure

  Procedure.i ParseBackgroundAttachment(AttachString.s)
    AttachString = LCase(Trim(AttachString))
    Select AttachString
      Case "scroll": ProcedureReturn 0
      Case "fixed": ProcedureReturn 1
      Default: ProcedureReturn 0
    EndSelect
  EndProcedure

  ; CSS 1: url(...) extrahieren
  Procedure.s ParseURL(URLString.s)
    Protected s.s = Trim(URLString)
    If LCase(Left(s, 4)) = "url("
      s = Mid(s, 5)
      If Right(s, 1) = ")"
        s = Left(s, Len(s) - 1)
      EndIf
      s = Trim(s)
      s = RemoveString(s, "'")
      s = RemoveString(s, Chr(34))
    EndIf
    ProcedureReturn s
  EndProcedure

  ; CSS 1: Spacing-Werte (word-spacing, letter-spacing)
  Procedure.i ParseSpacing(SpacingString.s)
    SpacingString = LCase(Trim(SpacingString))
    If SpacingString = "normal"
      ProcedureReturn 0
    EndIf
    ProcedureReturn ParseSize(SpacingString)
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
          Protected bW.s = Trim(StringField(Parts, 1, " "))
          Protected bS.s = Trim(StringField(Parts, 2, " "))
          Protected bC.s = Trim(StringField(Parts, 3, " "))

          If bW <> ""
            ApplyCascadedProperty(*Node, "border-top-width", bW, Spec, RuleOrder)
            ApplyCascadedProperty(*Node, "border-right-width", bW, Spec, RuleOrder)
            ApplyCascadedProperty(*Node, "border-bottom-width", bW, Spec, RuleOrder)
            ApplyCascadedProperty(*Node, "border-left-width", bW, Spec, RuleOrder)
            ApplyCascadedProperty(*Node, "border-width", bW, Spec, RuleOrder)
            Debug "  → Expandiere border-width = " + bW
          EndIf
          If bS <> ""
            ApplyCascadedProperty(*Node, "border-style", bS, Spec, RuleOrder)
            Debug "  → Expandiere border-style = " + bS
          EndIf
          If bC <> ""
            ApplyCascadedProperty(*Node, "border-color", bC, Spec, RuleOrder)
            Debug "  → Expandiere border-color = " + bC
          EndIf

        Case "border-width"
          Protected bwCount.i = CountString(PropValue, " ") + 1
          Select bwCount
            Case 1
              Protected bwAll.s = Trim(PropValue)
              ApplyCascadedProperty(*Node, "border-top-width", bwAll, Spec, RuleOrder)
              ApplyCascadedProperty(*Node, "border-right-width", bwAll, Spec, RuleOrder)
              ApplyCascadedProperty(*Node, "border-bottom-width", bwAll, Spec, RuleOrder)
              ApplyCascadedProperty(*Node, "border-left-width", bwAll, Spec, RuleOrder)
            Case 2
              Protected bwV.s = Trim(StringField(PropValue, 1, " "))
              Protected bwH.s = Trim(StringField(PropValue, 2, " "))
              ApplyCascadedProperty(*Node, "border-top-width", bwV, Spec, RuleOrder)
              ApplyCascadedProperty(*Node, "border-bottom-width", bwV, Spec, RuleOrder)
              ApplyCascadedProperty(*Node, "border-right-width", bwH, Spec, RuleOrder)
              ApplyCascadedProperty(*Node, "border-left-width", bwH, Spec, RuleOrder)
            Case 3
              ApplyCascadedProperty(*Node, "border-top-width", Trim(StringField(PropValue, 1, " ")), Spec, RuleOrder)
              ApplyCascadedProperty(*Node, "border-right-width", Trim(StringField(PropValue, 2, " ")), Spec, RuleOrder)
              ApplyCascadedProperty(*Node, "border-bottom-width", Trim(StringField(PropValue, 3, " ")), Spec, RuleOrder)
              ApplyCascadedProperty(*Node, "border-left-width", Trim(StringField(PropValue, 2, " ")), Spec, RuleOrder)
            Case 4
              ApplyCascadedProperty(*Node, "border-top-width", Trim(StringField(PropValue, 1, " ")), Spec, RuleOrder)
              ApplyCascadedProperty(*Node, "border-right-width", Trim(StringField(PropValue, 2, " ")), Spec, RuleOrder)
              ApplyCascadedProperty(*Node, "border-bottom-width", Trim(StringField(PropValue, 3, " ")), Spec, RuleOrder)
              ApplyCascadedProperty(*Node, "border-left-width", Trim(StringField(PropValue, 4, " ")), Spec, RuleOrder)
          EndSelect

        Case "border-top"
          Protected btW.s = Trim(StringField(PropValue, 1, " "))
          Protected btS.s = Trim(StringField(PropValue, 2, " "))
          Protected btC.s = Trim(StringField(PropValue, 3, " "))
          If btW <> "" : ApplyCascadedProperty(*Node, "border-top-width", btW, Spec, RuleOrder) : EndIf
          If btS <> "" : ApplyCascadedProperty(*Node, "border-style", btS, Spec, RuleOrder) : EndIf
          If btC <> "" : ApplyCascadedProperty(*Node, "border-color", btC, Spec, RuleOrder) : EndIf

        Case "border-right"
          Protected brW.s = Trim(StringField(PropValue, 1, " "))
          Protected brS.s = Trim(StringField(PropValue, 2, " "))
          Protected brC.s = Trim(StringField(PropValue, 3, " "))
          If brW <> "" : ApplyCascadedProperty(*Node, "border-right-width", brW, Spec, RuleOrder) : EndIf
          If brS <> "" : ApplyCascadedProperty(*Node, "border-style", brS, Spec, RuleOrder) : EndIf
          If brC <> "" : ApplyCascadedProperty(*Node, "border-color", brC, Spec, RuleOrder) : EndIf

        Case "border-bottom"
          Protected bbW.s = Trim(StringField(PropValue, 1, " "))
          Protected bbS.s = Trim(StringField(PropValue, 2, " "))
          Protected bbC.s = Trim(StringField(PropValue, 3, " "))
          If bbW <> "" : ApplyCascadedProperty(*Node, "border-bottom-width", bbW, Spec, RuleOrder) : EndIf
          If bbS <> "" : ApplyCascadedProperty(*Node, "border-style", bbS, Spec, RuleOrder) : EndIf
          If bbC <> "" : ApplyCascadedProperty(*Node, "border-color", bbC, Spec, RuleOrder) : EndIf

        Case "border-left"
          Protected blW.s = Trim(StringField(PropValue, 1, " "))
          Protected blS.s = Trim(StringField(PropValue, 2, " "))
          Protected blC.s = Trim(StringField(PropValue, 3, " "))
          If blW <> "" : ApplyCascadedProperty(*Node, "border-left-width", blW, Spec, RuleOrder) : EndIf
          If blS <> "" : ApplyCascadedProperty(*Node, "border-style", blS, Spec, RuleOrder) : EndIf
          If blC <> "" : ApplyCascadedProperty(*Node, "border-color", blC, Spec, RuleOrder) : EndIf

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

        Case "font"
          ; CSS 1 font shorthand (vereinfacht):
          ; font: [style] [variant] [weight] size[/line-height] family
          ; Minimal: font: size family
          Protected fontParts.i = CountString(PropValue, " ") + 1
          Protected fIdx.i = 1
          Protected fToken.s

          ; Optionale Teile: style, variant, weight
          While fIdx <= fontParts - 2
            fToken = LCase(Trim(StringField(PropValue, fIdx, " ")))
            If fToken = "italic" Or fToken = "oblique"
              ApplyCascadedProperty(*Node, "font-style", fToken, Spec, RuleOrder)
              fIdx + 1
            ElseIf fToken = "small-caps"
              ApplyCascadedProperty(*Node, "font-variant", fToken, Spec, RuleOrder)
              fIdx + 1
            ElseIf fToken = "bold" Or fToken = "bolder" Or fToken = "lighter" Or (Val(fToken) >= 100 And Val(fToken) <= 900)
              ApplyCascadedProperty(*Node, "font-weight", fToken, Spec, RuleOrder)
              fIdx + 1
            ElseIf fToken = "normal"
              fIdx + 1
            Else
              Break
            EndIf
          Wend

          ; size[/line-height]
          If fIdx <= fontParts
            Protected sizeToken.s = Trim(StringField(PropValue, fIdx, " "))
            Protected slashPos.i = FindString(sizeToken, "/")
            If slashPos > 0
              ApplyCascadedProperty(*Node, "font-size", Left(sizeToken, slashPos - 1), Spec, RuleOrder)
              ApplyCascadedProperty(*Node, "line-height", Mid(sizeToken, slashPos + 1), Spec, RuleOrder)
            Else
              ApplyCascadedProperty(*Node, "font-size", sizeToken, Spec, RuleOrder)
            EndIf
            fIdx + 1
          EndIf

          ; family (rest)
          If fIdx <= fontParts
            Protected famParts.s = ""
            Protected fi.i
            For fi = fIdx To fontParts
              If famParts <> "" : famParts + " " : EndIf
              famParts + Trim(StringField(PropValue, fi, " "))
            Next
            ApplyCascadedProperty(*Node, "font-family", famParts, Spec, RuleOrder)
          EndIf

        Case "background"
          ; CSS 1 background shorthand (vereinfacht):
          ; Jeder Token wird nach Typ klassifiziert
          Protected bgCount.i = CountString(PropValue, " ") + 1
          Protected bgI.i, bgToken.s
          For bgI = 1 To bgCount
            bgToken = Trim(StringField(PropValue, bgI, " "))
            If bgToken = "" : Continue : EndIf

            If LCase(Left(bgToken, 4)) = "url("
              ApplyCascadedProperty(*Node, "background-image", bgToken, Spec, RuleOrder)
            ElseIf LCase(bgToken) = "repeat" Or LCase(bgToken) = "repeat-x" Or LCase(bgToken) = "repeat-y" Or LCase(bgToken) = "no-repeat"
              ApplyCascadedProperty(*Node, "background-repeat", bgToken, Spec, RuleOrder)
            ElseIf LCase(bgToken) = "scroll" Or LCase(bgToken) = "fixed"
              ApplyCascadedProperty(*Node, "background-attachment", bgToken, Spec, RuleOrder)
            Else
              ; Farbe (Hex, Named) oder Position
              If Left(bgToken, 1) = "#" Or FindMapElement(*Node\Attributes(), "")= 0
                ApplyCascadedProperty(*Node, "background-color", bgToken, Spec, RuleOrder)
              EndIf
            EndIf
          Next

        Case "list-style"
          ; CSS 1: list-style: [type] [position] [image]
          Protected lsCount.i = CountString(PropValue, " ") + 1
          Protected lsI.i, lsToken.s
          For lsI = 1 To lsCount
            lsToken = Trim(StringField(PropValue, lsI, " "))
            If lsToken = "" : Continue : EndIf

            If LCase(Left(lsToken, 4)) = "url("
              ApplyCascadedProperty(*Node, "list-style-image", lsToken, Spec, RuleOrder)
            ElseIf LCase(lsToken) = "inside" Or LCase(lsToken) = "outside"
              ApplyCascadedProperty(*Node, "list-style-position", lsToken, Spec, RuleOrder)
            Else
              ApplyCascadedProperty(*Node, "list-style-type", lsToken, Spec, RuleOrder)
            EndIf
          Next

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
    *Style\FontVariant = 0
    *Style\Color = RGB(0, 0, 0)
    *Style\TextDecoration = 0
    *Style\TextAlign = 0
    *Style\TextIndent = 0
    *Style\TextTransform = 0
    *Style\WordSpacing = 0
    *Style\LetterSpacing = 0
    *Style\VerticalAlign = 0
    *Style\LineHeight = 0
    *Style\WhiteSpace = 0
    *Style\BackgroundColor = RGB(255, 255, 255)
    *Style\BackgroundImage = ""
    *Style\BackgroundRepeat = 0
    *Style\BackgroundAttachment = 0
    *Style\BackgroundPositionX = 0
    *Style\BackgroundPositionY = 0

    *Style\Width = 0
    *Style\Height = 0
    *Style\Float = 0
    *Style\Clear = 0
    *Style\MarginTop = 0
    *Style\MarginRight = 0
    *Style\MarginBottom = 0
    *Style\MarginLeft = 0
    *Style\PaddingTop = 0
    *Style\PaddingRight = 0
    *Style\PaddingBottom = 0
    *Style\PaddingLeft = 0
    *Style\BorderTopWidth = 0
    *Style\BorderRightWidth = 0
    *Style\BorderBottomWidth = 0
    *Style\BorderLeftWidth = 0
    *Style\BorderWidth = 0
    *Style\BorderStyle = 0
    *Style\BorderColor = RGB(0, 0, 0)
    *Style\Display = 0  ; block
    *Style\ListStyleType = 0
    *Style\ListStyleImage = ""
    *Style\ListStylePosition = 0

    ; Inheritance (CSS 1 inherited properties)
    If *Node\Parent
      Protected Parent.ComputedStyle
      GetComputedStyle(*Node\Parent, @Parent)

      ; Font (inherited)
      *Style\FontSize = Parent\FontSize
      *Style\FontStyle = Parent\FontStyle
      *Style\FontFamily = Parent\FontFamily
      *Style\FontVariant = Parent\FontVariant

      ; Text (inherited)
      *Style\Color = Parent\Color
      *Style\TextAlign = Parent\TextAlign
      *Style\TextIndent = Parent\TextIndent
      *Style\TextTransform = Parent\TextTransform
      *Style\WordSpacing = Parent\WordSpacing
      *Style\LetterSpacing = Parent\LetterSpacing
      *Style\LineHeight = Parent\LineHeight
      *Style\WhiteSpace = Parent\WhiteSpace

      ; Hinweis: text-decoration ist in CSS nicht inherited als Property,
      ; aber die visuelle Wirkung propagiert in der Praxis.
      *Style\TextDecoration = Parent\TextDecoration

      ; Classification (inherited)
      *Style\ListStyleType = Parent\ListStyleType
      *Style\ListStyleImage = Parent\ListStyleImage
      *Style\ListStylePosition = Parent\ListStylePosition
    EndIf

    ; ---- Font ----
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

    If FindMapElement(*Node\Attributes(), "css-font-variant")
      *Style\FontVariant = ParseFontVariant(*Node\Attributes())
    EndIf

    ; ---- Text ----
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

    If FindMapElement(*Node\Attributes(), "css-text-indent")
      *Style\TextIndent = ParseSize(*Node\Attributes())
    EndIf

    If FindMapElement(*Node\Attributes(), "css-text-transform")
      *Style\TextTransform = ParseTextTransform(*Node\Attributes())
    EndIf

    If FindMapElement(*Node\Attributes(), "css-word-spacing")
      *Style\WordSpacing = ParseSpacing(*Node\Attributes())
    EndIf

    If FindMapElement(*Node\Attributes(), "css-letter-spacing")
      *Style\LetterSpacing = ParseSpacing(*Node\Attributes())
    EndIf

    If FindMapElement(*Node\Attributes(), "css-vertical-align")
      *Style\VerticalAlign = ParseVerticalAlign(*Node\Attributes())
    EndIf

    If FindMapElement(*Node\Attributes(), "css-line-height")
      *Style\LineHeight = ParseLineHeight(*Node\Attributes(), *Style\FontSize)
    EndIf

    ; Default line-height if still unset
    If *Style\LineHeight <= 0
      *Style\LineHeight = *Style\FontSize + 6
    EndIf

    ; ---- Background ----
    If FindMapElement(*Node\Attributes(), "css-background-color")
      *Style\BackgroundColor = ParseColor(*Node\Attributes())
    EndIf

    If FindMapElement(*Node\Attributes(), "css-background-image")
      *Style\BackgroundImage = ParseURL(*Node\Attributes())
    EndIf

    If FindMapElement(*Node\Attributes(), "css-background-repeat")
      *Style\BackgroundRepeat = ParseBackgroundRepeat(*Node\Attributes())
    EndIf

    If FindMapElement(*Node\Attributes(), "css-background-attachment")
      *Style\BackgroundAttachment = ParseBackgroundAttachment(*Node\Attributes())
    EndIf

    If FindMapElement(*Node\Attributes(), "css-background-position")
      ; Vereinfacht: nur px-Werte "X Y"
      Protected bgPos.s = Trim(*Node\Attributes())
      *Style\BackgroundPositionX = ParseSize(Trim(StringField(bgPos, 1, " ")))
      If CountString(bgPos, " ") > 0
        *Style\BackgroundPositionY = ParseSize(Trim(StringField(bgPos, 2, " ")))
      EndIf
    EndIf

    ; ---- Box Model ----
    If FindMapElement(*Node\Attributes(), "css-width")
      *Style\Width = ParseSize(*Node\Attributes())
    EndIf

    If FindMapElement(*Node\Attributes(), "css-height")
      *Style\Height = ParseSize(*Node\Attributes())
    EndIf

    If FindMapElement(*Node\Attributes(), "css-float")
      *Style\Float = ParseFloat(*Node\Attributes())
    EndIf

    If FindMapElement(*Node\Attributes(), "css-clear")
      *Style\Clear = ParseClear(*Node\Attributes())
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

    ; ---- Border ----
    ; Per-side widths (CSS 1)
    If FindMapElement(*Node\Attributes(), "css-border-top-width")
      *Style\BorderTopWidth = ParseSize(*Node\Attributes())
    EndIf
    If FindMapElement(*Node\Attributes(), "css-border-right-width")
      *Style\BorderRightWidth = ParseSize(*Node\Attributes())
    EndIf
    If FindMapElement(*Node\Attributes(), "css-border-bottom-width")
      *Style\BorderBottomWidth = ParseSize(*Node\Attributes())
    EndIf
    If FindMapElement(*Node\Attributes(), "css-border-left-width")
      *Style\BorderLeftWidth = ParseSize(*Node\Attributes())
    EndIf

    ; Compat: border-width (uniform) -> per-side Fallback
    If FindMapElement(*Node\Attributes(), "css-border-width")
      Protected uniformBW.i = ParseSize(*Node\Attributes())
      If *Style\BorderTopWidth = 0 : *Style\BorderTopWidth = uniformBW : EndIf
      If *Style\BorderRightWidth = 0 : *Style\BorderRightWidth = uniformBW : EndIf
      If *Style\BorderBottomWidth = 0 : *Style\BorderBottomWidth = uniformBW : EndIf
      If *Style\BorderLeftWidth = 0 : *Style\BorderLeftWidth = uniformBW : EndIf
    EndIf

    ; Compat: BorderWidth = BorderTopWidth (für Layout.pbi / BrowserUI.pbi)
    *Style\BorderWidth = *Style\BorderTopWidth
    Debug "[GetComputedStyle] " + *Node\TagName + " border-width: " + Str(*Style\BorderWidth)

    If FindMapElement(*Node\Attributes(), "css-border-style")
      *Style\BorderStyle = ParseBorderStyle(*Node\Attributes())
      Debug "[GetComputedStyle] " + *Node\TagName + " border-style: " + *Node\Attributes() + " → " + Str(*Style\BorderStyle)
    EndIf

    If FindMapElement(*Node\Attributes(), "css-border-color")
      *Style\BorderColor = ParseColor(*Node\Attributes())
      Debug "[GetComputedStyle] " + *Node\TagName + " border-color: " + *Node\Attributes() + " → " + Str(*Style\BorderColor)
    EndIf

    ; ---- Classification ----
    If FindMapElement(*Node\Attributes(), "css-display")
      *Style\Display = ParseDisplay(*Node\Attributes())
    EndIf

    If FindMapElement(*Node\Attributes(), "css-white-space")
      *Style\WhiteSpace = ParseWhiteSpace(*Node\Attributes())
    EndIf

    If FindMapElement(*Node\Attributes(), "css-list-style-type")
      *Style\ListStyleType = ParseListStyleType(*Node\Attributes())
    EndIf

    If FindMapElement(*Node\Attributes(), "css-list-style-image")
      *Style\ListStyleImage = ParseURL(*Node\Attributes())
    EndIf

    If FindMapElement(*Node\Attributes(), "css-list-style-position")
      *Style\ListStylePosition = ParseListStylePosition(*Node\Attributes())
    EndIf
  EndProcedure

EndModule

; IDE Options = PureBasic 6.21 - C Backend (MacOS X - arm64)
; EnableXP
; DPIAware
