; ============================================================================
; Layout.pbi v0.8.1a - BORDER WIDTH FIX (mit Layout-Fixes)
; ----------------------------------------------------------------------------
; Fixes:
;  FIX 1: Block-Flow korrekt (Children nacheinander, PaddingTop/Bottom korrekt,
;         keine doppelten Margins, Box\Y nach MarginTop, Border/Background sauber)
;  FIX 2: Text-Nodes erhhen CurrentY im Block-Kontext (LineHeight/Fallback)
;  FIX 3: <br> nutzt LineHeight/FontSize statt hardcoded 20
;  Drift-Fix A (Lists): UL/OL/MENU/DIR stabil ber Box-Model (kein driftendes +15/+15)
;  Drift-Fix B (IMG): konsistente Width/Height + stabiler vertikaler Advance
; ----------------------------------------------------------------------------
; Basis: dein gepostetes Layout.pbi (v0.8.1a) ? minimal-invasiv
; ============================================================================

XIncludeFile "HTMLParser.pbi"
XIncludeFile "Document.pbi"
XIncludeFile "HTTPCache.pbi"
XIncludeFile "Style.pbi"
XIncludeFile "FontCache.pbi"

DeclareModule Layout

  ; ============================================================
  ; Fixes: UTF-8 Mojibake + Pre-Escapes + Tabs (Tabstops)
  ; ============================================================

  Structure Box
    X.i
    Y.i
    Width.i
    Height.i
  EndStructure

  ; Inline-Run: Ein Stck Text mit einheitlichem Style
  Structure InlineRun
    Text.s
    FontSize.i
    FontStyle.i
    FontFamily.s
    Color.i
    TextDecoration.i  ; 0=none, 1=underline, 2=line-through, 3=overline
    IsSubscript.i
    IsSuperscript.i
  EndStructure

  Structure LayoutBox
    Box.Box
    *DOMNode.HTMLParser::DOMNode

    ; Font & Text
    FontSize.i
    FontStyle.i
    FontFamily.s
    Color.i
    TextDecoration.i
    TextAlign.i
    LineHeight.i
    WhiteSpace.i         ; 0=normal, 1=pre, 2=pre-wrap

    ; Background
    BackgroundColor.i

    ; Box Model
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
    BorderStyle.i
    BorderColor.i

    ; Layout
    Display.i

    ; Sub/Super (HTML 4)
    IsSubscript.i
    IsSuperscript.i

    ; Wrapped Text
    List WrappedLines.s()
    List InlineRuns.InlineRun()
    List LineRunCounts.i()  ; NEU: Anzahl Runs pro Zeile (für Inline-Rendering)
    List *Children.LayoutBox()
  EndStructure

  Declare.i Calculate(*Doc.Document::Document, ViewportWidth.i, ViewportHeight.i)
  Declare FreeLayout(*Root.LayoutBox)
  Declare WrapText(Text.s, FontID.i, MaxWidth.i, List Lines.s())

EndDeclareModule

Module Layout
  
  
  Procedure.s FixMojibakeUTF8(Text.s)
    ; Heuristik: nur wenn typische Mojibake-Sequenzen vorkommen
    If FindString(Text, "Ã") = 0 And FindString(Text, "Â") = 0
      ProcedureReturn Text
    EndIf

    Protected L = Len(Text)
    If L <= 0
      ProcedureReturn Text
    EndIf

    ; Re-interpret each 0..255 char as a byte and decode as UTF-8
    Protected *buf = AllocateMemory(L + 1)
    If *buf = 0
      ProcedureReturn Text
    EndIf

    Protected i
    For i = 1 To L
      PokeA(*buf + (i - 1), Asc(Mid(Text, i, 1)) & $FF)
    Next
    PokeA(*buf + L, 0)

    Protected out.s = PeekS(*buf, -1, #PB_UTF8)
    FreeMemory(*buf)

    If out <> ""
      ProcedureReturn out
    EndIf
    ProcedureReturn Text
  EndProcedure

  Procedure.s UnescapePreEscapes(Text.s)
    ; Unterstützt Backslash-Escapes aus Demo-Strings: \n \r\n \t
    ; (PureBasic kennt keine String-Escapes per \, deshalb müssen wir das manuell machen.)
    If FindString(Text, "\") = 0
      ProcedureReturn Text
    EndIf

    ; Wichtig: \r\n zuerst
    Text = ReplaceString(Text, "\r\n", #LF$)
    Text = ReplaceString(Text, "\n", #LF$)
    Text = ReplaceString(Text, "\t", #TAB$)
    ProcedureReturn Text
  EndProcedure

  Procedure.i GetWhiteSpaceMode(*Node.HTMLParser::DOMNode)
    ; 0=normal, 1=pre, 2=pre-wrap
    Protected mode.i = 0
    If Not *Node
      ProcedureReturn 0
    EndIf

    ; Default für <pre>
    If *Node\Type = HTMLParser::#NodeType_Element And *Node\ElementType = HTMLParser::#Element_PRE
      mode = 1
    EndIf

    ; CSS override
    If FindMapElement(*Node\Attributes(), "css-white-space")
      Protected ws.s = LCase(HTMLParser::GetAttribute(*Node, "css-white-space"))
      If ws = "pre"
        mode = 1
      ElseIf ws = "pre-wrap"
        mode = 2
      ElseIf ws = "normal"
        mode = 0
      EndIf
    EndIf

    ProcedureReturn mode
  EndProcedure

  Procedure.s ExpandTabsWithStops(Text.s, *Width.Integer, SpaceW.i, TabSizeSpaces.i = 8)
    ; Expandiert TABs zu Spaces anhand echter Tabstop-Positionen (wie im Terminal).
    ; *Width enthält aktuelle X-Position (in Pixeln) und wird aktualisiert.
    Protected tabW.i = SpaceW * TabSizeSpaces
    If tabW <= 0 : tabW = 1 : EndIf

    Protected out.s = ""
    Protected seg.s
    Protected i.i, L.i = Len(Text)
    Protected ch.s
    Protected start.i = 1

    For i = 1 To L
      ch = Mid(Text, i, 1)
      If ch = #TAB$
        ; segment vor TAB
        If i > start
          seg = Mid(Text, start, i - start)
          out + seg
          *Width\i + TextWidth(seg)
        EndIf

        ; nächster Tabstop
        Protected nextStop.i = (( *Width\i / tabW ) + 1) * tabW
        Protected delta.i = nextStop - *Width\i
        Protected spaces.i
        If SpaceW > 0
          spaces = (delta + SpaceW - 1) / SpaceW
        Else
          spaces = 4
        EndIf

        If spaces < 1 : spaces = 1 : EndIf
        out + RSet("", spaces, " ")
        *Width\i = nextStop

        start = i + 1
      EndIf
    Next

    If start <= L
      seg = Mid(Text, start, L - start + 1)
      out + seg
      *Width\i + TextWidth(seg)
    EndIf

    ProcedureReturn out
  EndProcedure

  Procedure.i CreateBox()
    Protected *Box.LayoutBox = AllocateMemory(SizeOf(LayoutBox))
    If *Box
      InitializeStructure(*Box, LayoutBox)
      NewList *Box\WrappedLines()
      NewList *Box\InlineRuns()
      NewList *Box\LineRunCounts()
      NewList *Box\Children()
    EndIf
    ProcedureReturn *Box
  EndProcedure

  Procedure FreeLayout(*Box.LayoutBox)
    If *Box
      ForEach *Box\Children()
        FreeLayout(*Box\Children())
      Next
      ClearList(*Box\Children())
      ClearList(*Box\WrappedLines())
      ClearList(*Box\InlineRuns())
      ClearList(*Box\LineRunCounts())
      FreeMemory(*Box)
    EndIf
  EndProcedure

  ; Sammle alle Inline-Content (Text + Inline-Elemente) rekursiv
  Procedure CollectInlineRuns(*Node.HTMLParser::DOMNode, List Runs.InlineRun(),
                              ParentFontSize.i=14, ParentFontStyle.i=0, ParentFontFamily.s="Arial",
                              ParentColor.i=0, ParentDecoration.i=0, ParentSub.i=0, ParentSup.i=0, WhiteSpaceMode.i=0)
    Protected FontSize.i, FontStyle.i, Color.i, Decoration.i, IsSub.i, IsSup.i
    Protected FontFamily.s
    Protected CSSStyle.Style::ComputedStyle

    If Not *Node Or *Node\Hidden
      ProcedureReturn
    EndIf

    Select *Node\Type
      Case HTMLParser::#NodeType_Text
        ; Text-Node: Erstelle Run mit Parent-Styles
        If (WhiteSpaceMode > 0 And *Node\TextContent <> "") Or (WhiteSpaceMode = 0 And Trim(*Node\TextContent) <> "")  ; Whitespace handling
          AddElement(Runs())
          Runs()\Text = FixMojibakeUTF8(*Node\TextContent)
          Runs()\FontSize = ParentFontSize
          Runs()\FontStyle = ParentFontStyle
          Runs()\FontFamily = ParentFontFamily
          Runs()\Color = ParentColor
          Runs()\TextDecoration = ParentDecoration
          Runs()\IsSubscript = ParentSub
          Runs()\IsSuperscript = ParentSup
        EndIf

      Case HTMLParser::#NodeType_Element
        ; Inline-Element: Vererbe/ändere Styles und gehe rekursiv weiter


        ; STAGE 2: <br> als expliziter Zeilenumbruch in InlineRuns
        If *Node\ElementType = HTMLParser::#Element_BR
          AddElement(Runs())
          Runs()\Text = "\n"  ; newline marker
          Runs()\FontSize = ParentFontSize
          Runs()\FontStyle = ParentFontStyle
          Runs()\FontFamily = ParentFontFamily
          Runs()\Color = ParentColor
          Runs()\TextDecoration = ParentDecoration
          Runs()\IsSubscript = ParentSub
          Runs()\IsSuperscript = ParentSup
          ProcedureReturn
        EndIf

        FontSize = ParentFontSize
        FontStyle = ParentFontStyle
        FontFamily = ParentFontFamily
        Color = ParentColor
        Decoration = ParentDecoration
        IsSub = ParentSub
        IsSup = ParentSup

        ; Element-spezifische Styles
        Select *Node\ElementType
          Case HTMLParser::#Element_STRONG, HTMLParser::#Element_B
            FontStyle | #PB_Font_Bold
          Case HTMLParser::#Element_EM, HTMLParser::#Element_I, HTMLParser::#Element_CITE,
               HTMLParser::#Element_DFN, HTMLParser::#Element_VAR
            FontStyle | #PB_Font_Italic
          Case HTMLParser::#Element_U, HTMLParser::#Element_INS
            Decoration = 1
          Case HTMLParser::#Element_S, HTMLParser::#Element_STRIKE, HTMLParser::#Element_DEL
            Decoration = 2
          Case HTMLParser::#Element_SUB
            IsSub = 1
            FontSize = 10
          Case HTMLParser::#Element_SUP
            IsSup = 1
            FontSize = 10
          Case HTMLParser::#Element_SMALL
            FontSize = 11
          Case HTMLParser::#Element_BIG
            FontSize = 18
        EndSelect

        ; CSS überschreibt Element-Defaults
        Style::GetComputedStyle(*Node, @CSSStyle)
        ; Color: nur überschreiben wenn Property vorhanden (RGB(0,0,0)=0 ist gültig)
        If FindMapElement(*Node\Attributes(), "css-color")
          Color = CSSStyle\Color
        EndIf
        If CSSStyle\FontSize > 0
          FontSize = CSSStyle\FontSize
        EndIf
        If CSSStyle\FontStyle > 0
          FontStyle | CSSStyle\FontStyle
        EndIf
        ; FontFamily: wenn CSS etwas gesetzt hat, nehmen – sonst Parent
        If CSSStyle\FontFamily <> ""
          FontFamily = CSSStyle\FontFamily
        EndIf

        ; Text-Decoration: ComputedStyle enthält bereits Vererbung
        Decoration = CSSStyle\TextDecoration

        ; white-space erben/überschreiben (für <pre> / css-white-space)
        Protected childWS.i = WhiteSpaceMode
        If *Node\ElementType = HTMLParser::#Element_PRE
          childWS = 1
        EndIf
        If FindMapElement(*Node\Attributes(), "css-white-space")
          Protected ws.s = LCase(HTMLParser::GetAttribute(*Node, "css-white-space"))
          If ws = "pre"
            childWS = 1
          ElseIf ws = "pre-wrap"
            childWS = 2
          ElseIf ws = "normal"
            childWS = 0
          EndIf
        EndIf

        ; Rekursiv durch Children
        ForEach *Node\Children()
          CollectInlineRuns(*Node\Children(), Runs(), FontSize, FontStyle, FontFamily, Color,
                            Decoration, IsSub, IsSup, childWS)
        Next
    EndSelect
  EndProcedure

  Procedure GetDefaultFontSize(ElementType.i)
    Select ElementType
      Case HTMLParser::#Element_H1: ProcedureReturn 32
      Case HTMLParser::#Element_H2: ProcedureReturn 24
      Case HTMLParser::#Element_H3: ProcedureReturn 18
      Case HTMLParser::#Element_H4: ProcedureReturn 16
      Case HTMLParser::#Element_H5: ProcedureReturn 14
      Case HTMLParser::#Element_H6: ProcedureReturn 12
      Case HTMLParser::#Element_SMALL: ProcedureReturn 11
      Case HTMLParser::#Element_BIG: ProcedureReturn 18
      Case HTMLParser::#Element_SUB, HTMLParser::#Element_SUP: ProcedureReturn 10
      Default: ProcedureReturn 14
    EndSelect
  EndProcedure

  Procedure GetDefaultFontStyle(ElementType.i)
    Select ElementType
      Case HTMLParser::#Element_H1, HTMLParser::#Element_H2, HTMLParser::#Element_H3,
           HTMLParser::#Element_H4, HTMLParser::#Element_H5, HTMLParser::#Element_H6
        ProcedureReturn #PB_Font_Bold
      Case HTMLParser::#Element_STRONG, HTMLParser::#Element_B
        ProcedureReturn #PB_Font_Bold
      Case HTMLParser::#Element_EM, HTMLParser::#Element_I, HTMLParser::#Element_CITE,
           HTMLParser::#Element_DFN, HTMLParser::#Element_VAR
        ProcedureReturn #PB_Font_Italic
      Default
        ProcedureReturn 0
    EndSelect
  EndProcedure

  Procedure.i IsBlockElement(ElementType.i)
    Select ElementType
      Case HTMLParser::#Element_DIV, HTMLParser::#Element_P,
           HTMLParser::#Element_H1, HTMLParser::#Element_H2, HTMLParser::#Element_H3,
           HTMLParser::#Element_H4, HTMLParser::#Element_H5, HTMLParser::#Element_H6,
           HTMLParser::#Element_UL, HTMLParser::#Element_OL, HTMLParser::#Element_LI,
           HTMLParser::#Element_DL, HTMLParser::#Element_DT, HTMLParser::#Element_DD,
           HTMLParser::#Element_MENU, HTMLParser::#Element_DIR,
           HTMLParser::#Element_ADDRESS, HTMLParser::#Element_CENTER,
           HTMLParser::#Element_TABLE, HTMLParser::#Element_TR, HTMLParser::#Element_THEAD,
           HTMLParser::#Element_TBODY, HTMLParser::#Element_TFOOT,
           HTMLParser::#Element_BLOCKQUOTE, HTMLParser::#Element_PRE,
           HTMLParser::#Element_FIELDSET, HTMLParser::#Element_FORM,
           HTMLParser::#Element_FRAMESET, HTMLParser::#Element_NOFRAMES
        ProcedureReturn #True
      Default
        ProcedureReturn #False
    EndSelect
  EndProcedure

  Procedure WrapText(Text.s, FontID.i, MaxWidth.i, List Lines.s())
    Protected TempImg.i, Word.s, CurrentLine.s, TestLine.s, i.i

    ClearList(Lines())

    TempImg = CreateImage(#PB_Any, 100, 100)
    If StartDrawing(ImageOutput(TempImg))
      DrawingFont(FontID)

      CurrentLine = ""

      For i = 1 To CountString(Text, " ") + 1
        Word = StringField(Text, i, " ")

        If CurrentLine = ""
          TestLine = Word
        Else
          TestLine = CurrentLine + " " + Word
        EndIf

        If TextWidth(TestLine) <= MaxWidth
          CurrentLine = TestLine
        Else
          If CurrentLine <> ""
            AddElement(Lines())
            Lines() = CurrentLine
          EndIf
          CurrentLine = Word
        EndIf
      Next

      If CurrentLine <> ""
        AddElement(Lines())
        Lines() = CurrentLine
      EndIf

      StopDrawing()
    EndIf

    FreeImage(TempImg)
  EndProcedure


  ; ------------------------------------------------------------
  ; STAGE 2: Inline-Layout Helpers
  ; ------------------------------------------------------------
  Procedure.s NormalizeInlineText(Text.s, WhiteSpaceMode.i)
    ; WhiteSpaceMode: 0=normal, 1=pre, 2=pre-wrap
    Text = FixMojibakeUTF8(Text)

    If WhiteSpaceMode = 0
      Text = ReplaceString(Text, #CRLF$, " ")
      Text = ReplaceString(Text, #CR$, " ")
      Text = ReplaceString(Text, #LF$, " ")
      Text = ReplaceString(Text, #TAB$, " ")
      While FindString(Text, "  ")
        Text = ReplaceString(Text, "  ", " ")
      Wend
      ProcedureReturn Text
    EndIf

    ; pre / pre-wrap
    Text = ReplaceString(Text, #CRLF$, #LF$)
    Text = ReplaceString(Text, #CR$, #LF$)
    ; Demo-Backslash-Escapes ( , 	, ) nur in pre/pre-wrap
    Text = UnescapePreEscapes(Text)
    ; TAB bleibt als #TAB$ erhalten -> wird später per Tabstops expanded
    ProcedureReturn Text
  EndProcedure

  Procedure TokenizePreWrap(LineText.s, List Tokens.s())
    ClearList(Tokens())
    Protected i.i = 1, L.i = Len(LineText), ch.s, cur.s, isSpace.i, newIsSpace.i
    If L = 0 : ProcedureReturn : EndIf

    ch = Mid(LineText, 1, 1)
    isSpace = Bool(ch = " ")
    cur = ch

    For i = 2 To L
      ch = Mid(LineText, i, 1)
      newIsSpace = Bool(ch = " ")
      If newIsSpace = isSpace
        cur + ch
      Else
        AddElement(Tokens()) : Tokens() = cur
        cur = ch
        isSpace = newIsSpace
      EndIf
    Next
    AddElement(Tokens()) : Tokens() = cur
  EndProcedure

  ; Prüft ob ein Node nur Inline-Content enthält (keine Block-Children, keine IMG/HR/BR etc.)
  Procedure.i HasOnlyInlineContent(*Node.HTMLParser::DOMNode)
    If Not *Node
      ProcedureReturn #True
    EndIf

    ForEach *Node\Children()
      Protected *C.HTMLParser::DOMNode = *Node\Children()
      If Not *C Or *C\Hidden
        Continue
      EndIf

      If *C\Type = HTMLParser::#NodeType_Element
        Select *C\ElementType
          Case HTMLParser::#Element_BR, HTMLParser::#Element_HR, HTMLParser::#Element_IMG,
               HTMLParser::#Element_UL, HTMLParser::#Element_OL, HTMLParser::#Element_DL,
               HTMLParser::#Element_TABLE, HTMLParser::#Element_FORM
            ProcedureReturn #False
        EndSelect

        If IsBlockElement(*C\ElementType)
          ProcedureReturn #False
        EndIf

        ; Rekursiv: wenn Child wiederum Block enthält -> false
        If Not HasOnlyInlineContent(*C)
          ProcedureReturn #False
        EndIf
      EndIf
    Next

    ProcedureReturn #True
  EndProcedure

  ; Wrapped InlineRuns in Zeilen um und schreibt sie in *Box\InlineRuns() + *Box\LineRunCounts()
Procedure WrapInlineRunsToBox(*Box.LayoutBox, List Runs.InlineRun(), MaxWidth.i, BaseFontFamily.s, WhiteSpaceMode.i)
    Protected TempImg.i
    Protected CurrentWidth.i, LineRunsCount.i
    Protected LineText.s

    Protected famBase.s, key.s
    Protected runText.s, runText2.s
    Protected partCount.i, pi.i
    Protected part.s
    Protected wCount.i, wi.i
    Protected word.s, seg.s
    Protected segW.i, tokW.i, partW.i
    Protected f.i

    NewList Tokens.s()

    ClearList(*Box\InlineRuns())
    ClearList(*Box\LineRunCounts())
    ClearList(*Box\WrappedLines())

    If MaxWidth <= 0
      MaxWidth = 10
    EndIf

    ; ------------------------------------------------------------
    ; PRELOAD FONTS (WICHTIG: außerhalb StartDrawing!)
    ; ------------------------------------------------------------
    ForEach Runs()
      famBase = BaseFontFamily
      If Runs()\FontFamily <> "" : famBase = Runs()\FontFamily : EndIf
      If famBase = "" : famBase = "Arial" : EndIf
      FontCache::GetFont(famBase, Runs()\FontSize, Runs()\FontStyle, #True)
    Next

    TempImg = CreateImage(#PB_Any, 32, 32)
    If Not TempImg
      ProcedureReturn
    EndIf

    If StartDrawing(ImageOutput(TempImg))

      CurrentWidth = 0
      LineRunsCount = 0
      LineText = ""

      ForEach Runs()

        ; Expliziter Zeilenumbruch (z.B. <br>)
        If Runs()\Text = #LF$
          AddElement(*Box\LineRunCounts()) : *Box\LineRunCounts() = LineRunsCount
          AddElement(*Box\WrappedLines())  : *Box\WrappedLines()  = LineText
          CurrentWidth = 0 : LineRunsCount = 0 : LineText = ""
          Continue
        EndIf

        runText = NormalizeInlineText(Runs()\Text, WhiteSpaceMode)
        If runText = ""
          Continue
        EndIf

        famBase = BaseFontFamily
        If Runs()\FontFamily <> "" : famBase = Runs()\FontFamily : EndIf
        If famBase = "" : famBase = "Arial" : EndIf

        f = FontCache::GetFont(famBase, Runs()\FontSize, Runs()\FontStyle, #False)
        If f : DrawingFont(FontID(f)) : EndIf

        ; pre/pre-wrap: Newlines innerhalb des Textes berücksichtigen
        partCount = CountString(runText, #LF$) + 1

        For pi = 1 To partCount
          part = StringField(runText, pi, #LF$)

          If WhiteSpaceMode = 1
            ; pre: keine Wort-Wraps, Spaces bleiben
            If part <> ""
              Protected w.Integer : w\i = CurrentWidth
              part = ExpandTabsWithStops(part, @w, TextWidth(" "))
              CurrentWidth = w\i
              partW = 0

              AddElement(*Box\InlineRuns())
              *Box\InlineRuns()\Text = part
              *Box\InlineRuns()\FontSize = Runs()\FontSize
              *Box\InlineRuns()\FontStyle = Runs()\FontStyle
              *Box\InlineRuns()\FontFamily = famBase
              *Box\InlineRuns()\Color = Runs()\Color
              *Box\InlineRuns()\TextDecoration = Runs()\TextDecoration
              *Box\InlineRuns()\IsSubscript = Runs()\IsSubscript
              *Box\InlineRuns()\IsSuperscript = Runs()\IsSuperscript

              LineRunsCount + 1
              CurrentWidth + partW
              LineText + part
            EndIf

          ElseIf WhiteSpaceMode = 2
            ; pre-wrap: Tokens (Spaces/Non-Spaces) wrappen
            ClearList(Tokens())
            TokenizePreWrap(part, Tokens())

            ForEach Tokens()
              If Tokens() = "" : Continue : EndIf

              tokW = TextWidth(Tokens())

              If CurrentWidth > 0 And (CurrentWidth + tokW) > MaxWidth
                AddElement(*Box\LineRunCounts()) : *Box\LineRunCounts() = LineRunsCount
                AddElement(*Box\WrappedLines())  : *Box\WrappedLines()  = LineText
                CurrentWidth = 0 : LineRunsCount = 0 : LineText = ""
              EndIf

              AddElement(*Box\InlineRuns())
              *Box\InlineRuns()\Text = Tokens()
              *Box\InlineRuns()\FontSize = Runs()\FontSize
              *Box\InlineRuns()\FontStyle = Runs()\FontStyle
              *Box\InlineRuns()\FontFamily = famBase
              *Box\InlineRuns()\Color = Runs()\Color
              *Box\InlineRuns()\TextDecoration = Runs()\TextDecoration
              *Box\InlineRuns()\IsSubscript = Runs()\IsSubscript
              *Box\InlineRuns()\IsSuperscript = Runs()\IsSuperscript

              LineRunsCount + 1
              CurrentWidth + tokW
              LineText + Tokens()
            Next

          Else
            ; normal: collapse + word wrapping
            runText2 = Trim(runText)
            If runText2 <> ""
              wCount = CountString(runText2, " ") + 1

              For wi = 1 To wCount
                word = StringField(runText2, wi, " ")
                If word = "" : Continue : EndIf

                seg = word
                If wi < wCount
                  seg + " "
                EndIf

                segW = TextWidth(seg)

                If CurrentWidth > 0 And (CurrentWidth + segW) > MaxWidth
                  AddElement(*Box\LineRunCounts()) : *Box\LineRunCounts() = LineRunsCount
                  AddElement(*Box\WrappedLines())  : *Box\WrappedLines()  = LineText
                  CurrentWidth = 0 : LineRunsCount = 0 : LineText = ""
                EndIf

                AddElement(*Box\InlineRuns())
                *Box\InlineRuns()\Text = seg
                *Box\InlineRuns()\FontSize = Runs()\FontSize
                *Box\InlineRuns()\FontStyle = Runs()\FontStyle
                *Box\InlineRuns()\FontFamily = famBase
                *Box\InlineRuns()\Color = Runs()\Color
                *Box\InlineRuns()\TextDecoration = Runs()\TextDecoration
                *Box\InlineRuns()\IsSubscript = Runs()\IsSubscript
                *Box\InlineRuns()\IsSuperscript = Runs()\IsSuperscript

                LineRunsCount + 1
                CurrentWidth + segW
                LineText + seg
              Next
            EndIf
          EndIf

          ; newline zwischen parts
          If pi < partCount
            AddElement(*Box\LineRunCounts()) : *Box\LineRunCounts() = LineRunsCount
            AddElement(*Box\WrappedLines())  : *Box\WrappedLines()  = LineText
            CurrentWidth = 0 : LineRunsCount = 0 : LineText = ""
          EndIf
        Next

      Next

      If LineRunsCount > 0
        AddElement(*Box\LineRunCounts()) : *Box\LineRunCounts() = LineRunsCount
        AddElement(*Box\WrappedLines())  : *Box\WrappedLines()  = LineText
      EndIf

      StopDrawing()
    EndIf

    FreeImage(TempImg)
  EndProcedure

  Procedure LayoutNode(*Node.HTMLParser::DOMNode, *ParentBox.LayoutBox,
                       ViewportWidth.i, CurrentX.i, CurrentY.i)
    Protected *Box.LayoutBox
    Protected FontSize.i, FontStyle.i, Font.i, Color.i, BackgroundColor.i
    Protected IsBlock.i, LineHeight.i
    Protected ImgSrc.s, ImgID.i
    Protected CSSStyle.Style::ComputedStyle
    Protected HasCSSColor.i  ; NEUE VARIABLE!
    ; Shared temps (PureBasic: keine erneuten Protected-Deklarationen in Select/Case)
    Protected mTop, mBottom.i, mLeft.i, mRight.i
    Protected pTop, pBottom.i, pLeft.i, pRight.i
    Protected ContentX, ContentY.i
    Protected BaseFamily.s

    If Not *Node
      ProcedureReturn CurrentY
    EndIf

    If *Node\Hidden
      ProcedureReturn CurrentY
    EndIf

    *Box = CreateBox()
    *Box\DOMNode = *Node
    *Box\Box\X = CurrentX
    *Box\Box\Y = CurrentY

    Select *Node\Type

      Case HTMLParser::#NodeType_Root
        ForEach *Node\Children()
          CurrentY = LayoutNode(*Node\Children(), *Box, ViewportWidth, CurrentX, CurrentY)
        Next
        *Box\Box\Height = CurrentY - *Box\Box\Y
        *Box\Box\Width  = ViewportWidth - CurrentX

      Case HTMLParser::#NodeType_Element

        ; CSS-Style holen
        Style::GetComputedStyle(*Node, @CSSStyle)

        FontSize = GetDefaultFontSize(*Node\ElementType)
        FontStyle = GetDefaultFontStyle(*Node\ElementType)
        Color = RGB(0, 0, 0)
        BackgroundColor = RGB(255, 255, 255)
        HasCSSColor = #False

        ; KRITISCHER FIX: prfen ob CSS-Color gesetzt wurde!
        ; (RGB(0,0,0) ist 0 ? nicht mit "Color<>0" prfen)
        If FindMapElement(*Node\Attributes(), "css-color")
          Color = CSSStyle\Color
          HasCSSColor = #True
        EndIf

        ; FontSize aus CSS
        If CSSStyle\FontSize > 0
          FontSize = CSSStyle\FontSize
        EndIf

        ; FontStyle kombinieren (Bold + Italic mit Bitwise OR)
        If CSSStyle\FontStyle > 0
          FontStyle = FontStyle | CSSStyle\FontStyle
        EndIf

        ; Background-Color
        If FindMapElement(*Node\Attributes(), "css-background-color")
          BackgroundColor = CSSStyle\BackgroundColor
        EndIf

        IsBlock = IsBlockElement(*Node\ElementType)

        ; Kopiere alle Style-Properties in LayoutBox
        *Box\FontSize = FontSize
        *Box\FontStyle = FontStyle
        *Box\FontFamily = CSSStyle\FontFamily
        *Box\Color = Color
        *Box\TextDecoration = CSSStyle\TextDecoration
        *Box\TextAlign = CSSStyle\TextAlign
        *Box\LineHeight = CSSStyle\LineHeight
        *Box\WhiteSpace = GetWhiteSpaceMode(*Node)
        *Box\BackgroundColor = BackgroundColor

        Debug "[LayoutNode] <" + *Node\TagName + "> FontFamily: '" + *Box\FontFamily + "', TextAlign: " + Str(*Box\TextAlign)

        ; Box Model
        *Box\MarginTop = CSSStyle\MarginTop
        *Box\MarginRight = CSSStyle\MarginRight
        *Box\MarginBottom = CSSStyle\MarginBottom
        *Box\MarginLeft = CSSStyle\MarginLeft
        *Box\PaddingTop = CSSStyle\PaddingTop
        *Box\PaddingRight = CSSStyle\PaddingRight
        *Box\PaddingBottom = CSSStyle\PaddingBottom
        *Box\PaddingLeft = CSSStyle\PaddingLeft

        ; Border
        *Box\BorderWidth = CSSStyle\BorderWidth
        *Box\BorderStyle = CSSStyle\BorderStyle
        *Box\BorderColor = CSSStyle\BorderColor

        Debug "[LayoutNode] <" + *Node\TagName + "> Border: W=" + Str(*Box\BorderWidth) + " S=" + Str(*Box\BorderStyle) + " C=" + Str(*Box\BorderColor)

        ; Display
        *Box\Display = CSSStyle\Display

        ; Sub/Super Override (HTML 4 Elements)
        *Box\IsSubscript = 0
        *Box\IsSuperscript = 0
        Select *Node\ElementType
          Case HTMLParser::#Element_SUB
            *Box\IsSubscript = 1
          Case HTMLParser::#Element_SUP
            *Box\IsSuperscript = 1
        EndSelect

        ; HTML 4 Text-Decoration nur als Fallback wenn CSS nichts gesetzt hat
        If *Box\TextDecoration = 0
          Select *Node\ElementType
            Case HTMLParser::#Element_U, HTMLParser::#Element_INS
              *Box\TextDecoration = 1  ; underline
            Case HTMLParser::#Element_S, HTMLParser::#Element_STRIKE, HTMLParser::#Element_DEL
              *Box\TextDecoration = 2  ; line-through
          EndSelect
        EndIf

        Select *Node\ElementType

          ; ------------------------------------------------------------
          ; FIX 3: BR nutzt LineHeight/FontSize statt hardcoded 20
          ; ------------------------------------------------------------
          Case HTMLParser::#Element_BR
            Protected lhBR.i = 20

            If CSSStyle\LineHeight > 0
              lhBR = CSSStyle\LineHeight
            ElseIf *Node\Parent
              Protected psBR.Style::ComputedStyle
              Style::GetComputedStyle(*Node\Parent, @psBR)
              If psBR\LineHeight > 0
                lhBR = psBR\LineHeight
              ElseIf psBR\FontSize > 0
                lhBR = psBR\FontSize + 6
              EndIf
            EndIf

            *Box\Box\Width = ViewportWidth - CurrentX
            *Box\Box\Height = lhBR
            CurrentY + lhBR

          Case HTMLParser::#Element_HR
            CurrentY + 15
            *Box\Box\Height = 4
            *Box\Box\Width = ViewportWidth - 60
            CurrentY + 19

          ; ------------------------------------------------------------
          ; Drift-Fix B: IMG konsistent
          ; ------------------------------------------------------------
          Case HTMLParser::#Element_IMG
            ImgSrc = HTMLParser::GetAttribute(*Node, "src")
            *Box\Box\Width = ViewportWidth - CurrentX

            If ImgSrc <> ""
              ImgID = HTTPCache::GetImage(ImgSrc)
              If ImgID
                *Box\Box\Width  = ImageWidth(ImgID)
                *Box\Box\Height = ImageHeight(ImgID)
              Else
                ; Placeholder
                *Box\Box\Width  = 120
                *Box\Box\Height = 60
              EndIf
            Else
              *Box\Box\Width  = 120
              *Box\Box\Height = 60
            EndIf

            ; stabiler Advance (wie vorher: +15 Abstand), aber nur EINMAL
            CurrentY + *Box\Box\Height + 15

          ; ------------------------------------------------------------
          ; FIX 1: Block-Flow korrekt fr typische Block-Container
          ; ------------------------------------------------------------
          Case HTMLParser::#Element_P, HTMLParser::#Element_H1, HTMLParser::#Element_H2,
               HTMLParser::#Element_H3, HTMLParser::#Element_H4, HTMLParser::#Element_H5,
               HTMLParser::#Element_H6

            ; STAGE 2: Inline-Formatting-Context für Absatz & Überschriften
            mTop = 15
            mBottom = 15
            mLeft = CSSStyle\MarginLeft
            mRight = CSSStyle\MarginRight

            If CSSStyle\MarginTop > 0 : mTop = CSSStyle\MarginTop : EndIf
            If CSSStyle\MarginBottom > 0 : mBottom = CSSStyle\MarginBottom : EndIf

            pTop = CSSStyle\PaddingTop
            pBottom = CSSStyle\PaddingBottom
            pLeft = CSSStyle\PaddingLeft
            pRight = CSSStyle\PaddingRight

            If IsBlock
              CurrentY + mTop
            EndIf

            *Box\Box\X = CurrentX + mLeft
            *Box\Box\Y = CurrentY
            *Box\Box\Width = (ViewportWidth - (CurrentX + mLeft)) - mRight

            ContentX = *Box\Box\X + pLeft
            ContentY = CurrentY + pTop

            ; InlineRuns sammeln (inkl. <br> als \n Marker)
            BaseFamily = "Arial"
            If *Box\FontFamily <> "" : BaseFamily = *Box\FontFamily : EndIf

            Protected NewList Runs2.InlineRun()
            CollectInlineRuns(*Node, Runs2(), FontSize, FontStyle, BaseFamily, Color, *Box\TextDecoration, 0, 0, GetWhiteSpaceMode(*Node))

            ; Zeilenhöhe
            Protected LH.i = *Box\LineHeight
            If LH <= 0 : LH = FontSize + 6 : EndIf

            ; verfügbare Breite
            Protected AvailW.i = *Box\Box\Width - pLeft - pRight
            If AvailW < 50 : AvailW = 50 : EndIf

            ; Pre-Wrap in Box (erzeugt InlineRuns-Segmente + LineRunCounts + WrappedLines)
            WrapInlineRunsToBox(*Box, Runs2(), AvailW, BaseFamily, *Box\WhiteSpace)

            Protected Lines.i = ListSize(*Box\LineRunCounts())
            If Lines <= 0 : Lines = 1 : EndIf

            CurrentY = ContentY + (Lines * LH)
            CurrentY + pBottom

            *Box\Box\Height = CurrentY - *Box\Box\Y

            If IsBlock
              CurrentY + mBottom
            EndIf

          Case HTMLParser::#Element_DIV,
               HTMLParser::#Element_ADDRESS, HTMLParser::#Element_CENTER, HTMLParser::#Element_BLOCKQUOTE,
               HTMLParser::#Element_FIELDSET

            ; ------------------------------------------------------------
            ; STAGE 2: Inline-Flow für reine Inline-Inhalte (P/Hx etc.)
            ; ------------------------------------------------------------
            mTop = 15
            mBottom = 15
            mLeft = CSSStyle\MarginLeft
            mRight = CSSStyle\MarginRight

            If CSSStyle\MarginTop > 0 : mTop = CSSStyle\MarginTop : EndIf
            If CSSStyle\MarginBottom > 0 : mBottom = CSSStyle\MarginBottom : EndIf

            pTop = CSSStyle\PaddingTop
            pBottom = CSSStyle\PaddingBottom
            pLeft = CSSStyle\PaddingLeft
            pRight = CSSStyle\PaddingRight

            If IsBlock
              CurrentY + mTop
            EndIf

            *Box\Box\X = CurrentX + mLeft
            *Box\Box\Y = CurrentY
            *Box\Box\Width = (ViewportWidth - (CurrentX + mLeft)) - mRight

            If HasOnlyInlineContent(*Node)
              availW.i = *Box\Box\Width - pLeft - pRight
              If availW <= 0 : availW = *Box\Box\Width : EndIf

              baseFamily.s = "Arial"
              If *Box\FontFamily <> "" : baseFamily = *Box\FontFamily : EndIf

              NewList Runs.InlineRun()
              CollectInlineRuns(*Node, Runs(), FontSize, FontStyle, baseFamily, Color, *Box\TextDecoration, 0, 0, GetWhiteSpaceMode(*Node))

              WrapInlineRunsToBox(*Box, Runs(), availW, baseFamily, *Box\WhiteSpace)

              lh.i = *Box\LineHeight
              If lh <= 0 : lh = FontSize + 6 : EndIf

              lineCount.i = ListSize(*Box\LineRunCounts())
              *Box\Box\Height = pTop + (lineCount * lh) + pBottom

              CurrentY + *Box\Box\Height
            Else
              ; Fallback: klassischer Block-Flow
              contentX.i = *Box\Box\X + pLeft
              contentY.i = CurrentY + pTop
              CurrentY = contentY
              ForEach *Node\Children()
                CurrentY = LayoutNode(*Node\Children(), *Box, ViewportWidth, contentX, CurrentY)
              Next
              CurrentY + pBottom
              *Box\Box\Height = CurrentY - *Box\Box\Y
            EndIf

            If IsBlock
              CurrentY + mBottom
            EndIf

Case HTMLParser::#Element_UL, HTMLParser::#Element_OL, HTMLParser::#Element_MENU, HTMLParser::#Element_DIR

            Protected lmTop.i = 15
            Protected lmBottom.i = 15
            Protected lpTop.i = 0
            Protected lpBottom.i = 0
            Protected indent.i = 50

            If CSSStyle\MarginTop    > 0 : lmTop    = CSSStyle\MarginTop    : EndIf
            If CSSStyle\MarginBottom > 0 : lmBottom = CSSStyle\MarginBottom : EndIf
            If CSSStyle\PaddingTop   > 0 : lpTop    = CSSStyle\PaddingTop   : EndIf
            If CSSStyle\PaddingBottom> 0 : lpBottom = CSSStyle\PaddingBottom: EndIf

            ; Indent: CSS PaddingLeft wenn vorhanden, sonst default 50
            If CSSStyle\PaddingLeft > 0
              indent = CSSStyle\PaddingLeft
            EndIf

            CurrentY + lmTop
            *Box\Box\X = CurrentX
            *Box\Box\Y = CurrentY

            CurrentY + lpTop

            ForEach *Node\Children()
              CurrentY = LayoutNode(*Node\Children(), *Box, ViewportWidth, CurrentX + indent, CurrentY)
            Next

            CurrentY + lpBottom

            *Box\Box\Height = CurrentY - *Box\Box\Y
            *Box\Box\Width  = ViewportWidth - CurrentX  ; ? FIX #1 fr Border-Rendering

            CurrentY + lmBottom

          Case HTMLParser::#Element_DL
            CurrentY + 15
            ForEach *Node\Children()
              CurrentY = LayoutNode(*Node\Children(), *Box, ViewportWidth, CurrentX + 30, CurrentY)
            Next
            CurrentY + 15
            *Box\Box\Height = CurrentY - *Box\Box\Y
            *Box\Box\Width = ViewportWidth - CurrentX  ; ? FIX #1

          Case HTMLParser::#Element_DT
            CurrentY + 10
            *Box\Box\X = CurrentX
            *Box\Box\Y = CurrentY
            *Box\Box\Width = ViewportWidth - CurrentX

            If HasOnlyInlineContent(*Node)
              Protected NewList dtRuns.InlineRun()
              Protected dtFam.s = "Arial" : If *Box\FontFamily <> "" : dtFam = *Box\FontFamily : EndIf
              CollectInlineRuns(*Node, dtRuns(), FontSize, FontStyle, dtFam, Color, *Box\TextDecoration, 0, 0, GetWhiteSpaceMode(*Node))
              Protected dtLH.i = *Box\LineHeight : If dtLH <= 0 : dtLH = FontSize + 6 : EndIf
              WrapInlineRunsToBox(*Box, dtRuns(), *Box\Box\Width, dtFam, *Box\WhiteSpace)
              Protected dtLines.i = ListSize(*Box\LineRunCounts()) : If dtLines <= 0 : dtLines = 1 : EndIf
              CurrentY + (dtLines * dtLH)
            Else
              ForEach *Node\Children()
                CurrentY = LayoutNode(*Node\Children(), *Box, ViewportWidth, CurrentX, CurrentY)
              Next
            EndIf

            CurrentY + 5
            *Box\Box\Height = CurrentY - *Box\Box\Y

          Case HTMLParser::#Element_DD
            CurrentY + 5
            *Box\Box\X = CurrentX
            *Box\Box\Y = CurrentY
            *Box\Box\Width = ViewportWidth - CurrentX

            If HasOnlyInlineContent(*Node)
              Protected NewList ddRuns.InlineRun()
              Protected ddFam.s = "Arial" : If *Box\FontFamily <> "" : ddFam = *Box\FontFamily : EndIf
              CollectInlineRuns(*Node, ddRuns(), FontSize, FontStyle, ddFam, Color, *Box\TextDecoration, 0, 0, GetWhiteSpaceMode(*Node))
              Protected ddLH.i = *Box\LineHeight : If ddLH <= 0 : ddLH = FontSize + 6 : EndIf
              WrapInlineRunsToBox(*Box, ddRuns(), *Box\Box\Width - 40, ddFam, *Box\WhiteSpace)
              Protected ddLines.i = ListSize(*Box\LineRunCounts()) : If ddLines <= 0 : ddLines = 1 : EndIf
              CurrentY + (ddLines * ddLH)
            Else
              ForEach *Node\Children()
                CurrentY = LayoutNode(*Node\Children(), *Box, ViewportWidth, CurrentX + 40, CurrentY)
              Next
            EndIf

            CurrentY + 10
            *Box\Box\Height = CurrentY - *Box\Box\Y

          Case HTMLParser::#Element_LI
            *Box\Box\X = CurrentX
            *Box\Box\Y = CurrentY
            *Box\Box\Width = ViewportWidth - CurrentX

            If HasOnlyInlineContent(*Node)
              Protected NewList liRuns.InlineRun()
              Protected liFam.s = "Arial" : If *Box\FontFamily <> "" : liFam = *Box\FontFamily : EndIf
              CollectInlineRuns(*Node, liRuns(), FontSize, FontStyle, liFam, Color, *Box\TextDecoration, 0, 0, GetWhiteSpaceMode(*Node))
              Protected liLH.i = *Box\LineHeight : If liLH <= 0 : liLH = FontSize + 6 : EndIf
              WrapInlineRunsToBox(*Box, liRuns(), *Box\Box\Width, liFam, *Box\WhiteSpace)
              Protected liLines.i = ListSize(*Box\LineRunCounts()) : If liLines <= 0 : liLines = 1 : EndIf
              CurrentY + (liLines * liLH)
            Else
              ForEach *Node\Children()
                CurrentY = LayoutNode(*Node\Children(), *Box, ViewportWidth, CurrentX, CurrentY)
              Next
            EndIf

            *Box\Box\Height = CurrentY - *Box\Box\Y

          ; INLINE ELEMENTS - behandeln Children inline ohne Y zu incrementieren
          Case HTMLParser::#Element_STRONG, HTMLParser::#Element_B,
               HTMLParser::#Element_EM, HTMLParser::#Element_I,
               HTMLParser::#Element_U, HTMLParser::#Element_S, HTMLParser::#Element_STRIKE,
               HTMLParser::#Element_SUB, HTMLParser::#Element_SUP,
               HTMLParser::#Element_SMALL, HTMLParser::#Element_SPAN,
               HTMLParser::#Element_A, HTMLParser::#Element_CODE,
               HTMLParser::#Element_INS, HTMLParser::#Element_DEL,
               HTMLParser::#Element_CITE, HTMLParser::#Element_DFN,
               HTMLParser::#Element_VAR, HTMLParser::#Element_ABBR,
               HTMLParser::#Element_ACRONYM

            ForEach *Node\Children()
              CurrentY = LayoutNode(*Node\Children(), *Box, ViewportWidth, CurrentX, CurrentY)
            Next
            ; CurrentY bleibt gleich

          Default
            ForEach *Node\Children()
              CurrentY = LayoutNode(*Node\Children(), *Box, ViewportWidth, CurrentX, CurrentY)
            Next
            *Box\Box\Height = CurrentY - *Box\Box\Y
            *Box\Box\Width = ViewportWidth - CurrentX  ; FIX: Width fr Border-Rendering

        EndSelect

      Case HTMLParser::#NodeType_Text

        ; WHITESPACE-FIX: Ignoriere reine Whitespace/Newline Text-Nodes
        If Trim(*Node\TextContent) = ""
          ProcedureReturn CurrentY
        EndIf

        FontSize = 14
        FontStyle = 0
        Color = RGB(0, 0, 0)
        HasCSSColor = #False
        Protected TextDecoration.i = 0
        Protected IsSubscript.i = 0
        Protected IsSuperscript.i = 0

        ; KRITISCHER FIX: CSS-Vererbung vom Parent-DOM-Node!
        If *Node\Parent
          Protected ParentStyle.Style::ComputedStyle
          Style::GetComputedStyle(*Node\Parent, @ParentStyle)

          If FindMapElement(*Node\Parent\Attributes(), "css-color")
            Color = ParentStyle\Color
            HasCSSColor = #True
          EndIf

          If ParentStyle\FontSize > 0
            FontSize = ParentStyle\FontSize
          Else
            FontSize = GetDefaultFontSize(*Node\Parent\ElementType)
          EndIf

          If ParentStyle\FontStyle > 0
            FontStyle = ParentStyle\FontStyle
          Else
            FontStyle = GetDefaultFontStyle(*Node\Parent\ElementType)
          EndIf

          Select *Node\Parent\ElementType
            Case HTMLParser::#Element_SUB
              IsSubscript = 1
            Case HTMLParser::#Element_SUP
              IsSuperscript = 1
          EndSelect
        EndIf

        ; CSS 1 Properties
        Protected FontFamily.s = "Arial"
        Protected TextAlign.i = 0
        LineHeight = FontSize + 6

        If *Node\Parent
          Protected ParentStyle2.Style::ComputedStyle
          Style::GetComputedStyle(*Node\Parent, @ParentStyle2)

          If ParentStyle2\FontFamily <> ""
            FontFamily = ParentStyle2\FontFamily
          EndIf

          TextAlign = ParentStyle2\TextAlign

          If ParentStyle2\LineHeight > 0
            LineHeight = ParentStyle2\LineHeight
          EndIf

          If ParentStyle2\TextDecoration > 0
            TextDecoration = ParentStyle2\TextDecoration
          ElseIf TextDecoration = 0
            Select *Node\Parent\ElementType
              Case HTMLParser::#Element_U, HTMLParser::#Element_INS
                TextDecoration = 1
              Case HTMLParser::#Element_S, HTMLParser::#Element_STRIKE, HTMLParser::#Element_DEL
                TextDecoration = 2
            EndSelect
          EndIf
        EndIf

        *Box\FontSize = FontSize
        *Box\FontStyle = FontStyle
        *Box\FontFamily = FontFamily
        *Box\Color = Color
        *Box\BackgroundColor = RGB(255, 255, 255)
        *Box\TextDecoration = TextDecoration
        *Box\TextAlign = TextAlign
        *Box\LineHeight = LineHeight
        *Box\WhiteSpace = ParentStyle2\WhiteSpace
        *Box\IsSubscript = IsSubscript
        *Box\IsSuperscript = IsSuperscript

        Debug "[Text-Node] Parent: <" + *Node\Parent\TagName + "> TextDecoration=" + Str(TextDecoration)

        Font = FontCache::GetFont("Arial", FontSize, FontStyle, #True)

        ; INLINE-FIX: Prfe ob Parent ein Inline-Element ist
        Protected ParentIsInline.i = #False
        If *Node\Parent
          Select *Node\Parent\ElementType
            Case HTMLParser::#Element_SPAN, HTMLParser::#Element_A,
                 HTMLParser::#Element_STRONG, HTMLParser::#Element_EM,
                 HTMLParser::#Element_B, HTMLParser::#Element_I,
                 HTMLParser::#Element_U, HTMLParser::#Element_S,
                 HTMLParser::#Element_STRIKE, HTMLParser::#Element_DEL,
                 HTMLParser::#Element_INS, HTMLParser::#Element_SMALL,
                 HTMLParser::#Element_BIG, HTMLParser::#Element_TT,
                 HTMLParser::#Element_CODE, HTMLParser::#Element_KBD,
                 HTMLParser::#Element_SAMP, HTMLParser::#Element_VAR,
                 HTMLParser::#Element_CITE, HTMLParser::#Element_DFN,
                 HTMLParser::#Element_ABBR, HTMLParser::#Element_ACRONYM,
                 HTMLParser::#Element_Q, HTMLParser::#Element_SUB,
                 HTMLParser::#Element_SUP
              ParentIsInline = #True
          EndSelect
        EndIf

        If ParentIsInline
          ; Inline-Text: CurrentY bleibt gleich
          AddElement(*Box\WrappedLines())
          *Box\WrappedLines() = *Node\TextContent
          *Box\Box\Y = CurrentY
          *Box\Box\Height = FontSize + 6
        Else
          ; Block-Text: FIX 2 ? CurrentY erhhen (LineHeight/Fallback)
          AddElement(*Box\WrappedLines())
          *Box\WrappedLines() = *Node\TextContent
          *Box\Box\Y = CurrentY
          *Box\Box\Height = FontSize + 6

          If LineHeight > 0
            CurrentY + LineHeight
          Else
            CurrentY + (FontSize + 6)
          EndIf
        EndIf

    EndSelect

    If *ParentBox
      AddElement(*ParentBox\Children())
      *ParentBox\Children() = *Box
    EndIf

    ProcedureReturn CurrentY
  EndProcedure

  Procedure.i Calculate(*Doc.Document::Document, ViewportWidth.i, ViewportHeight.i)
    Protected *RootBox.LayoutBox
    Protected FinalHeight.i

    If Not *Doc Or Not *Doc\RootNode
      ProcedureReturn 0
    EndIf

    *RootBox = CreateBox()
    *RootBox\Box\Width = ViewportWidth

    FinalHeight = LayoutNode(*Doc\RootNode, *RootBox, ViewportWidth, 0, 0)

    *RootBox\Box\Height = FinalHeight
    *Doc\ContentWidth = ViewportWidth
    *Doc\ContentHeight = FinalHeight

    ProcedureReturn *RootBox
  EndProcedure

EndModule
; IDE Options = PureBasic 6.21 - C Backend (MacOS X - arm64)
; CursorPosition = 488
; FirstLine = 471
; Folding = ----
; EnableXP
; DPIAware