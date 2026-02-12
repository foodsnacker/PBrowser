; ============================================================================
; BrowserUI.pbi v0.4.0 - CSS 1 RENDERING (Float/Clear + Table)
; Rendering mit CSS 1 Properties:
; - Background-Color pro Box
; - Per-Side Border (top/right/bottom/left)
; - text-indent, text-transform, font-variant (small-caps)
; - word-spacing, letter-spacing
; - list-style-type (disc/circle/square/decimal/roman/alpha/none)
; - OL-Nummerierung
; - Underline, Strikethrough, Overline
; - Subscript, Superscript mit Y-Offset
; NEU v0.4.0:
; - Table-Zellen: Default 1px solid border wenn kein CSS-Border gesetzt
; - Float/Clear: korrekte Positionierung (Layout-seitig, Rendering transparent)
; ============================================================================

XIncludeFile "HTMLParser.pbi"
XIncludeFile "Document.pbi"
XIncludeFile "Layout.pbi"
XIncludeFile "FontCache.pbi"
XIncludeFile "HTTPCache.pbi"
XIncludeFile "CSSParser.pbi"
XIncludeFile "Style.pbi"
XIncludeFile "os_functions.pbi"

DeclareModule BrowserUI
  
  Declare.i Init(Width.i, Height.i, Fullscreen.i=#False)
  Declare Shutdown()
  Declare.i HandleEvents()
  Declare RenderLayout(*LayoutRoot.Layout::LayoutBox, *Doc.Document::Document)
  Declare LoadURL(URL.s)
  Declare LoadHTML(HTML.s, URL.s="inline.html")
  Declare.i GetOrLoadFont(Name.s, Size.i, Style.i, AllowLoad.i=#True)
  Declare.i SaveAsImage(Filename.s, Fileformat = OSFunc::#image_png)
  
  Global *CurrentDoc.Document::Document
  Global *CurrentLayout.Layout::LayoutBox
  
EndDeclareModule

Module BrowserUI
  
  #Window_Main = 0
  #ScrollArea_Main = 1
  #Canvas_Main = 2
  
  Global WindowWidth.i, WindowHeight.i
  Global ContentWidth.i, ContentHeight.i
  Global IsFullscreen.i
  Global NewMap PreloadedFonts()
  
  Procedure.s GetFontKey(Name.s, Size.i, Style.i)
    ProcedureReturn Name + "_" + Str(Size) + "_" + Str(Style)
  EndProcedure
  Procedure.i GetOrLoadFont(Name.s, Size.i, Style.i, AllowLoad.i=#True)
    ProcedureReturn FontCache::GetFont(Name, Size, Style, AllowLoad)
  EndProcedure

  
  Procedure FreeFonts()
    ForEach PreloadedFonts()
      If PreloadedFonts()
        FreeFont(PreloadedFonts())
      EndIf
    Next
    ClearMap(PreloadedFonts())
  EndProcedure

  ; =============================
  ; STAGE 2.6: Tabs + Better Justify
  ; =============================

  Procedure.i CountSpaceRuns(Text.s)
    ; zählt zusammenhängende Space-Sequenzen ("  " zählt als 1)
    Protected i.i, c.i = 0, inSpace.i = #False
    For i = 1 To Len(Text)
      Protected ch.s = Mid(Text, i, 1)
      If ch = " "
        If inSpace = #False
          c + 1
          inSpace = #True
        EndIf
      Else
        inSpace = #False
      EndIf
    Next
    ProcedureReturn c
  EndProcedure

  Procedure.i HasTab(Text.s)
    ProcedureReturn Bool(FindString(Text, Chr(9), 1) > 0)
  EndProcedure

  Procedure.i DrawTextWithTabs(X.i, Y.i, LineStartX.i, Text.s, Color.i, TabWidthPx.i)
    ; Zeichnet Text mit 	 als Tab-Stop. Gibt die neue X-Position (nach dem Text) zurück.
    Protected part.s, i.i, cnt.i
    If TabWidthPx <= 0
      TabWidthPx = 8
    EndIf

    cnt = CountString(Text, Chr(9)) + 1
    For i = 1 To cnt
      part = StringField(Text, i, Chr(9))
      If part <> ""
        DrawText(X, Y, part, Color)
        X + TextWidth(part)
      EndIf
      If i < cnt
        ; zum nächsten Tabstop springen
        Protected rel.i = X - LineStartX
        Protected nextStop.i = ((rel / TabWidthPx) + 1) * TabWidthPx
        X = LineStartX + nextStop
      EndIf
    Next

    ProcedureReturn X
  EndProcedure

  Procedure.i MeasureTextWithTabs(LineStartX.i, X.i, Text.s, TabWidthPx.i)
    ; gibt Breite (neuerX - LineStartX) zurück, berücksichtigt Tabs
    Protected part.s, i.i, cnt.i
    Protected curX.i = X
    If TabWidthPx <= 0
      TabWidthPx = 8
    EndIf
    cnt = CountString(Text, Chr(9)) + 1
    For i = 1 To cnt
      part = StringField(Text, i, Chr(9))
      If part <> ""
        curX + TextWidth(part)
      EndIf
      If i < cnt
        Protected rel.i = curX - LineStartX
        Protected nextStop.i = ((rel / TabWidthPx) + 1) * TabWidthPx
        curX = LineStartX + nextStop
      EndIf
    Next
    ProcedureReturn curX - LineStartX
  EndProcedure
  
  Procedure CollectFontsFromLayout(*Box.Layout::LayoutBox)
    If *Box
      If *Box\FontSize > 0
        Protected FontName.s = "Arial"
        If *Box\FontFamily <> ""
          FontName = *Box\FontFamily
        EndIf
        GetOrLoadFont(FontName, *Box\FontSize, *Box\FontStyle, #True)
      EndIf
      
      ForEach *Box\Children()
        CollectFontsFromLayout(*Box\Children())
      Next
    EndIf
  EndProcedure
  
  Procedure PreloadFontsFromLayout(*LayoutRoot.Layout::LayoutBox)
    If *LayoutRoot
      CollectFontsFromLayout(*LayoutRoot)
    EndIf
  EndProcedure
  
  Procedure.i Init(Width.i, Height.i, Fullscreen.i=#False)
    WindowWidth = Width
    WindowHeight = Height
    ContentWidth = Width
    ContentHeight = Height
    IsFullscreen = Fullscreen
    
    If Fullscreen
      ; === FULLSCREEN-MODUS ===
      If OpenWindow(#Window_Main, 0, 0, Width, Height, "Browser", 
                    #PB_Window_BorderLess | #PB_Window_Maximize)
        If CanvasGadget(#Canvas_Main, 0, 0, Width, Height)
          Debug "[BrowserUI::Init] Fullscreen-Modus: " + Str(Width) + "x" + Str(Height)
          ProcedureReturn #True
        EndIf
      EndIf
      
    Else
      ; === FENSTER-MODUS mit ScrollArea ===
      If OpenWindow(#Window_Main, 0, 0, Width, Height, "Browser v0.0.15", 
                    #PB_Window_SystemMenu | #PB_Window_ScreenCentered | #PB_Window_SizeGadget)
        
        ; ScrollAreaGadget - Initial mit Fenster-Größe
        If ScrollAreaGadget(#ScrollArea_Main, 0, 0, Width, Height, Width, Height, 1, #PB_ScrollArea_Flat)
          
          ; Canvas INNERHALB der ScrollArea - Initial mit Fenster-Größe
          If CanvasGadget(#Canvas_Main, 0, 0, Width, Height, #PB_Canvas_Keyboard)
            
            ; Container schließen
            CloseGadgetList()
            
            Debug "[BrowserUI::Init] Fenster-Modus mit ScrollArea: " + Str(Width) + "x" + Str(Height)
            ProcedureReturn #True
          EndIf
        EndIf
      EndIf
    EndIf
    
    Debug "[BrowserUI::Init] FEHLER: Initialisierung fehlgeschlagen!"
    ProcedureReturn #False
  EndProcedure
  
  Procedure UpdateScrollArea()
    If IsFullscreen
      ProcedureReturn
    EndIf
    
    ; KRITISCHER FIX: Verwende die EXAKTE Content-Höhe aus dem Document
    If *CurrentDoc And *CurrentDoc\ContentHeight > 0
      ContentHeight = *CurrentDoc\ContentHeight
      
      ; Füge einen kleinen Puffer hinzu (z.B. 20px) für besseres Aussehen
      Protected ActualHeight.i = ContentHeight + 20
      
      Debug "[BrowserUI::UpdateScrollArea] Document Content-Höhe: " + Str(ContentHeight)
      Debug "[BrowserUI::UpdateScrollArea] Actual Height (mit Puffer): " + Str(ActualHeight)
      
      ; ScrollArea-Inner-Größe auf EXAKTE Content-Größe setzen
      SetGadgetAttribute(#ScrollArea_Main, #PB_ScrollArea_InnerWidth, ContentWidth)
      SetGadgetAttribute(#ScrollArea_Main, #PB_ScrollArea_InnerHeight, ActualHeight)
      
      ; Canvas-Größe EXAKT anpassen
      ResizeGadget(#Canvas_Main, 0, 0, ContentWidth, ActualHeight)
      
      Debug "[BrowserUI::UpdateScrollArea] ScrollArea Inner: " + Str(ContentWidth) + "x" + Str(ActualHeight)
      Debug "[BrowserUI::UpdateScrollArea] Canvas resized: " + Str(ContentWidth) + "x" + Str(ActualHeight)
    Else
      Debug "[BrowserUI::UpdateScrollArea] WARNUNG: Keine Content-Höhe verfügbar!"
    EndIf
  EndProcedure
  
  Procedure Shutdown()
    If *CurrentLayout
      Layout::FreeLayout(*CurrentLayout)
      *CurrentLayout = 0
    EndIf
    If *CurrentDoc
      Document::Free(*CurrentDoc)
      *CurrentDoc = 0
    EndIf
    
    FreeFonts()
    CloseWindow(#Window_Main)
  EndProcedure
  
  Procedure LoadURL(URL.s)
    Protected HTML.s
    
    If *CurrentLayout
      Layout::FreeLayout(*CurrentLayout)
      *CurrentLayout = 0
    EndIf
    If *CurrentDoc
      Document::Free(*CurrentDoc)
      *CurrentDoc = 0
    EndIf
    
    HTML = HTTPCache::GetHTML(URL)
    *CurrentDoc = Document::Create(HTML, URL)
    *CurrentLayout = Layout::Calculate(*CurrentDoc, ContentWidth, ContentHeight)
    
    UpdateScrollArea()
    PreloadFontsFromLayout(*CurrentLayout)
    RenderLayout(*CurrentLayout, *CurrentDoc)
  EndProcedure
  
  Procedure LoadHTML(HTML.s, URL.s="inline.html")
    If *CurrentLayout
      Layout::FreeLayout(*CurrentLayout)
      *CurrentLayout = 0
    EndIf
    If *CurrentDoc
      Document::Free(*CurrentDoc)
      *CurrentDoc = 0
    EndIf
    
    HTTPCache::AddToCache(URL, HTML, "text/html")
    *CurrentDoc = Document::Create(HTML, URL)
    *CurrentLayout = Layout::Calculate(*CurrentDoc, ContentWidth, ContentHeight)
    
    UpdateScrollArea()
    PreloadFontsFromLayout(*CurrentLayout)
    RenderLayout(*CurrentLayout, *CurrentDoc)
  EndProcedure
  
  ; -------------------------------------------------------
  ; CSS 1 Helper: Text mit Letter-Spacing zeichnen
  ; -------------------------------------------------------
  Procedure.i DrawTextWithLetterSpacing(X.i, Y.i, Text.s, Color.i, Spacing.i)
    Protected lsi.i, lsch.s, lsw.i
    Protected lsX.i = X
    For lsi = 1 To Len(Text)
      lsch = Mid(Text, lsi, 1)
      DrawText(lsX, Y, lsch, Color)
      lsw = TextWidth(lsch)
      lsX + lsw + Spacing
    Next
    ProcedureReturn lsX - X
  EndProcedure

  ; CSS 1 Helper: Textbreite mit Letter-Spacing messen
  Procedure.i MeasureWithLetterSpacing(Text.s, Spacing.i)
    Protected mli.i, mlch.s, mlTotal.i = 0
    For mli = 1 To Len(Text)
      mlch = Mid(Text, mli, 1)
      mlTotal + TextWidth(mlch) + Spacing
    Next
    If Len(Text) > 0
      mlTotal - Spacing  ; letztes Zeichen ohne Spacing
    EndIf
    ProcedureReturn mlTotal
  EndProcedure

  ; CSS 1 Helper: List-Marker formatieren
  Procedure.s FormatListMarker(Index.i, StyleType.i)
    Select StyleType
      Case 0  ; disc
        ProcedureReturn Chr($2022) + " "
      Case 1  ; circle
        ProcedureReturn Chr($25CB) + " "
      Case 2  ; square
        ProcedureReturn Chr($25A0) + " "
      Case 3  ; decimal
        ProcedureReturn Str(Index) + ". "
      Case 4  ; lower-roman
        Protected roman.s = ""
        Protected rn.i = Index
        While rn >= 10 : roman + "x" : rn - 10 : Wend
        If rn >= 9 : roman + "ix" : rn - 9 : EndIf
        If rn >= 5 : roman + "v" : rn - 5 : EndIf
        If rn >= 4 : roman + "iv" : rn - 4 : EndIf
        While rn >= 1 : roman + "i" : rn - 1 : Wend
        ProcedureReturn roman + ". "
      Case 5  ; upper-roman
        Protected uroman.s = ""
        Protected urn.i = Index
        While urn >= 10 : uroman + "X" : urn - 10 : Wend
        If urn >= 9 : uroman + "IX" : urn - 9 : EndIf
        If urn >= 5 : uroman + "V" : urn - 5 : EndIf
        If urn >= 4 : uroman + "IV" : urn - 4 : EndIf
        While urn >= 1 : uroman + "I" : urn - 1 : Wend
        ProcedureReturn uroman + ". "
      Case 6  ; lower-alpha
        If Index >= 1 And Index <= 26
          ProcedureReturn Chr(96 + Index) + ". "
        EndIf
        ProcedureReturn Str(Index) + ". "
      Case 7  ; upper-alpha
        If Index >= 1 And Index <= 26
          ProcedureReturn Chr(64 + Index) + ". "
        EndIf
        ProcedureReturn Str(Index) + ". "
      Case 8  ; none
        ProcedureReturn ""
      Default
        ProcedureReturn Chr($2022) + " "
    EndSelect
  EndProcedure

  ; CSS 1 Helper: Eine Border-Seite zeichnen (Solid/Dashed/Dotted)
  Procedure DrawBorderSide(X1.i, Y1.i, X2.i, Y2.i, Width.i, Style.i, Color.i)
    If Width <= 0 Or Style = 0
      ProcedureReturn
    EndIf
    Protected bsi.i, bsLen.i
    Protected isHoriz.i = Bool(Y1 = Y2)

    Select Style
      Case 1  ; Solid
        If isHoriz
          Box(X1, Y1, X2 - X1, Width, Color)
        Else
          Box(X1, Y1, Width, Y2 - Y1, Color)
        EndIf
      Case 2  ; Dashed
        If isHoriz
          bsLen = X2 - X1
          For bsi = 0 To bsLen Step 10
            Protected dw.i = 5 : If bsi + 5 > bsLen : dw = bsLen - bsi : EndIf
            Box(X1 + bsi, Y1, dw, Width, Color)
          Next
        Else
          bsLen = Y2 - Y1
          For bsi = 0 To bsLen Step 10
            Protected dh.i = 5 : If bsi + 5 > bsLen : dh = bsLen - bsi : EndIf
            Box(X1, Y1 + bsi, Width, dh, Color)
          Next
        EndIf
      Case 3  ; Dotted
        If isHoriz
          For bsi = X1 To X2 Step 3
            Box(bsi, Y1, 1, Width, Color)
          Next
        Else
          For bsi = Y1 To Y2 Step 3
            Box(X1, bsi, Width, 1, Color)
          Next
        EndIf
    EndSelect
  EndProcedure

  ; -------------------------------------------------------
  ; DrawLayoutBox - Hauptrenderingfunktion
  ; -------------------------------------------------------
  Procedure DrawLayoutBox(*Box.Layout::LayoutBox, *Doc.Document::Document)
    Protected ImgSrc.s, ImgID.i
    Protected Font.i
    Protected LineY.i

    If Not *Box Or Not *Box\DOMNode
      ProcedureReturn
    EndIf

    If *Box\DOMNode\Hidden
      ProcedureReturn
    EndIf

    ; ========== CSS 1: Background-Color pro Box ==========
    If *Box\BackgroundColor <> RGB(255, 255, 255) And *Box\Box\Width > 0 And *Box\Box\Height > 0
      DrawingMode(#PB_2DDrawing_Default)
      Box(*Box\Box\X, *Box\Box\Y, *Box\Box\Width, *Box\Box\Height, *Box\BackgroundColor)
      DrawingMode(#PB_2DDrawing_Transparent)
    EndIf

    ; ========== Table-Zelle: Default 1px solid border wenn kein CSS-Border ==========
    If *Box\IsTableCell And *Box\BorderStyle = 0 And *Box\Box\Width > 0 And *Box\Box\Height > 0
      DrawingMode(#PB_2DDrawing_Default)
      ; 1px solid #ccc als Default Table-Border
      Protected tblBorderColor.i = RGB(200, 200, 200)
      Box(*Box\Box\X, *Box\Box\Y, *Box\Box\Width, 1, tblBorderColor)
      Box(*Box\Box\X, *Box\Box\Y + *Box\Box\Height - 1, *Box\Box\Width, 1, tblBorderColor)
      Box(*Box\Box\X, *Box\Box\Y, 1, *Box\Box\Height, tblBorderColor)
      Box(*Box\Box\X + *Box\Box\Width - 1, *Box\Box\Y, 1, *Box\Box\Height, tblBorderColor)
      DrawingMode(#PB_2DDrawing_Transparent)
    EndIf

    ; ========== CSS 1: Per-Side Border Rendering ==========
    If *Box\BorderStyle > 0 And *Box\Box\Width > 0 And *Box\Box\Height > 0
      Protected BorderX.i = *Box\Box\X
      Protected BorderY.i = *Box\Box\Y
      Protected BorderW.i = *Box\Box\Width
      Protected BorderH.i = *Box\Box\Height

      DrawingMode(#PB_2DDrawing_Default)

      ; Top
      If *Box\BorderTopWidth > 0
        DrawBorderSide(BorderX, BorderY, BorderX + BorderW, BorderY, *Box\BorderTopWidth, *Box\BorderStyle, *Box\BorderColor)
      EndIf
      ; Bottom
      If *Box\BorderBottomWidth > 0
        DrawBorderSide(BorderX, BorderY + BorderH - *Box\BorderBottomWidth, BorderX + BorderW, BorderY + BorderH - *Box\BorderBottomWidth, *Box\BorderBottomWidth, *Box\BorderStyle, *Box\BorderColor)
      EndIf
      ; Left
      If *Box\BorderLeftWidth > 0
        DrawBorderSide(BorderX, BorderY, BorderX, BorderY + BorderH, *Box\BorderLeftWidth, *Box\BorderStyle, *Box\BorderColor)
      EndIf
      ; Right
      If *Box\BorderRightWidth > 0
        DrawBorderSide(BorderX + BorderW - *Box\BorderRightWidth, BorderY, BorderX + BorderW - *Box\BorderRightWidth, BorderY + BorderH, *Box\BorderRightWidth, *Box\BorderStyle, *Box\BorderColor)
      EndIf

      DrawingMode(#PB_2DDrawing_Transparent)
    EndIf

    Select *Box\DOMNode\Type
      Case HTMLParser::#NodeType_Element
        ; STAGE 2: InlineRuns auch bei Element-Boxen rendern
        If ListSize(*Box\InlineRuns()) > 0 And ListSize(*Box\LineRunCounts()) > 0
          DrawingMode(#PB_2DDrawing_Transparent)

          Protected BaseFont.s = "Arial"
          If *Box\FontFamily <> "" : BaseFont = *Box\FontFamily : EndIf

          Protected startX.i = *Box\Box\X + *Box\PaddingLeft
          Protected startY.i = *Box\Box\Y + *Box\PaddingTop
          Protected availW.i = *Box\Box\Width - *Box\PaddingLeft - *Box\PaddingRight
          If availW <= 0 : availW = ContentWidth - startX - 20 : EndIf

          Protected lineH.i = *Box\LineHeight
          If lineH <= 0 : lineH = *Box\FontSize + 6 : EndIf

          ; Copy Lists to Arrays
          Protected runTotal.i = ListSize(*Box\InlineRuns())
          If runTotal <= 0
            Goto SkipInlineRuns
          EndIf
          Dim runs.Layout::InlineRun(runTotal - 1)
          Protected ri.i = 0
          ForEach *Box\InlineRuns()
            runs(ri) = *Box\InlineRuns()
            ri + 1
          Next

          Protected lineTotal.i = ListSize(*Box\LineRunCounts())
          If lineTotal <= 0
            Goto SkipInlineRuns
          EndIf
          Dim lineCounts.i(lineTotal - 1)
          Protected li.i = 0
          ForEach *Box\LineRunCounts()
            lineCounts(li) = *Box\LineRunCounts()
            li + 1
          Next

          Protected y.i = startY
          Protected runIndex.i = 0
          Protected bulletDone.i = #False

          For li = 0 To lineTotal - 1
            Protected c.i = lineCounts(li)

            ; Zeilenbreite messen
            Protected baseF.i = GetOrLoadFont(BaseFont, *Box\FontSize, *Box\FontStyle, #False)
            If baseF : DrawingFont(FontID(baseF)) : EndIf
            Protected tabW.i = TextWidth("        ")
            If tabW <= 0 : tabW = 8 : EndIf

            Protected lineW.i = 0
            Protected k.i
            Protected curX.i = 0
            Protected hasTabsInLine.i = #False
            For k = 0 To c - 1
              If runIndex + k >= runTotal : Break : EndIf
              Protected fam.s = runs(runIndex + k)\FontFamily
              If fam = "" : fam = BaseFont : EndIf
              Protected f.i = GetOrLoadFont(fam, runs(runIndex + k)\FontSize, runs(runIndex + k)\FontStyle, #False)
              If f : DrawingFont(FontID(f)) : EndIf
              If HasTab(runs(runIndex + k)\Text)
                hasTabsInLine = #True
              EndIf
              ; Berücksichtige Letter-Spacing beim Messen
              If runs(runIndex + k)\LetterSpacing > 0
                curX + MeasureWithLetterSpacing(runs(runIndex + k)\Text, runs(runIndex + k)\LetterSpacing)
              Else
                curX = MeasureTextWithTabs(0, curX, runs(runIndex + k)\Text, tabW)
              EndIf
            Next
            lineW = curX

            ; Justify
            Protected justifyExtra.f = 0.0
            If *Box\TextAlign = 3 And li < lineTotal - 1 And hasTabsInLine = #False
              Protected gaps.i = 0
              For k = 0 To c - 1
                If runIndex + k >= runTotal : Break : EndIf
                gaps + CountSpaceRuns(runs(runIndex + k)\Text)
              Next
              If gaps > 0 And availW > lineW
                justifyExtra = (availW - lineW) / gaps
              EndIf
            EndIf

            Protected x.i = startX
            ; CSS 1: text-indent auf erste Zeile
            If li = 0 And *Box\TextIndent <> 0
              x + *Box\TextIndent
            EndIf

            Select *Box\TextAlign
              Case 1 : x = startX + (availW - lineW) / 2
              Case 2 : x = startX + (availW - lineW)
            EndSelect

            ; CSS 1: List-Marker (LI) - einmalig
            If *Box\DOMNode\ElementType = HTMLParser::#Element_LI And bulletDone = #False
              Protected bf.i = GetOrLoadFont(BaseFont, *Box\FontSize, *Box\FontStyle, #False)
              If bf
                DrawingFont(FontID(bf))
                Protected listType.i = *Box\ListStyleType
                ; OL-Default: decimal wenn nicht explizit gesetzt
                If *Box\DOMNode\Parent And *Box\DOMNode\Parent\ElementType = HTMLParser::#Element_OL And listType = 0
                  listType = 3
                EndIf
                Protected marker.s = FormatListMarker(*Box\ListItemIndex, listType)
                If marker <> ""
                  DrawText(startX - TextWidth(marker), y, marker, *Box\Color)
                EndIf
              EndIf
              bulletDone = #True
            EndIf

            ; Zeile rendern
            For k = 0 To c - 1
              If runIndex >= runTotal : Break : EndIf

              Protected txt.s = runs(runIndex)\Text
              Protected fam2.s = runs(runIndex)\FontFamily
              If fam2 = "" : fam2 = BaseFont : EndIf

              ; CSS 1: font-variant: small-caps (vereinfacht: uppercase + 80% size)
              Protected renderSize.i = runs(runIndex)\FontSize
              Protected renderStyle.i = runs(runIndex)\FontStyle
              If runs(runIndex)\FontVariant = 1
                txt = UCase(txt)
                renderSize = Int(runs(runIndex)\FontSize * 0.8)
              EndIf

              Protected rf.i = GetOrLoadFont(fam2, renderSize, renderStyle, #False)
              If rf : DrawingFont(FontID(rf)) : EndIf

              Protected yOff.i = 0
              If runs(runIndex)\IsSubscript
                yOff = runs(runIndex)\FontSize / 3
              ElseIf runs(runIndex)\IsSuperscript
                yOff = -runs(runIndex)\FontSize / 3
              EndIf

              Protected drawX.i = x
              Protected x2.i
              Protected w.i

              ; CSS 1: Letter-Spacing
              If runs(runIndex)\LetterSpacing > 0 And Not HasTab(txt)
                w = DrawTextWithLetterSpacing(drawX, y + yOff, txt, runs(runIndex)\Color, runs(runIndex)\LetterSpacing)
                x2 = drawX + w
              ElseIf HasTab(txt)
                x2 = DrawTextWithTabs(drawX, y + yOff, startX, txt, runs(runIndex)\Color, tabW)
                w = x2 - drawX
              Else
                DrawText(drawX, y + yOff, txt, runs(runIndex)\Color)
                w = TextWidth(txt)
                x2 = drawX + w
              EndIf

              ; CSS 1: Word-Spacing (Extra zu justify)
              If runs(runIndex)\WordSpacing > 0
                Protected wsGaps.i = CountSpaceRuns(txt)
                x2 + (wsGaps * runs(runIndex)\WordSpacing)
                w + (wsGaps * runs(runIndex)\WordSpacing)
              EndIf

              ; Text-Decoration
              Select runs(runIndex)\TextDecoration
                Case 1 : Line(drawX, y + yOff + Int(runs(runIndex)\FontSize * 0.92), w, 1, runs(runIndex)\Color)
                Case 2 : Line(drawX, y + yOff + Int(runs(runIndex)\FontSize * 0.55), w, 1, runs(runIndex)\Color)
                Case 3 : Line(drawX, y + yOff + 1, w, 1, runs(runIndex)\Color)
              EndSelect

              x = x2

              ; Justify Extra
              If justifyExtra > 0.0 And HasTab(txt) = #False
                Protected gapRunsHere.i = CountSpaceRuns(txt)
                x + Int(justifyExtra * gapRunsHere)
              EndIf
              runIndex + 1
            Next

            y + lineH
          Next
          SkipInlineRuns:
        EndIf

        ; Spezial-Elemente (IMG/HR)
        Select *Box\DOMNode\ElementType
          Case HTMLParser::#Element_IMG
            ImgSrc = HTMLParser::GetAttribute(*Box\DOMNode, "src")
            If ImgSrc <> ""
              ImgID = HTTPCache::GetImage(ImgSrc)
              If ImgID
                DrawingMode(#PB_2DDrawing_AlphaBlend)
                DrawImage(ImageID(ImgID), *Box\Box\X, *Box\Box\Y)
                DrawingMode(#PB_2DDrawing_Transparent)
              Else
                Font = GetOrLoadFont("Arial", 14, 0, #False)
                If Font
                  DrawingFont(FontID(Font))
                  DrawText(*Box\Box\X, *Box\Box\Y, "[IMG fehlt]", RGB(255, 0, 0))
                EndIf
              EndIf
            EndIf

          Case HTMLParser::#Element_HR
            DrawingMode(#PB_2DDrawing_Default)
            Line(*Box\Box\X, *Box\Box\Y, *Box\Box\Width, 3, RGB(200, 200, 200))
            DrawingMode(#PB_2DDrawing_Transparent)
        EndSelect

      Case HTMLParser::#NodeType_Text
        Protected FontName.s = "Arial"
        If *Box\FontFamily <> ""
          FontName = *Box\FontFamily
        EndIf

        Font = GetOrLoadFont(FontName, *Box\FontSize, *Box\FontStyle, #False)

        If Font
          DrawingFont(FontID(Font))
          DrawingMode(#PB_2DDrawing_Transparent)

          LineY = *Box\Box\Y

          Protected YOffset.i = 0
          If *Box\IsSubscript
            YOffset = *Box\FontSize / 3
          ElseIf *Box\IsSuperscript
            YOffset = -*Box\FontSize / 3
          EndIf

          ForEach *Box\WrappedLines()
            Protected DisplayText.s = *Box\WrappedLines()
            Protected TextX.i = *Box\Box\X
            Protected TextY.i = LineY + YOffset

            ; Bullet für Listen (Fallback für Text-Node-Pfad)
            If *Box\DOMNode\Parent And *Box\DOMNode\Parent\ElementType = HTMLParser::#Element_LI
              DisplayText = Chr($2022) + " " + DisplayText
            EndIf

            Protected LineTextWidth.i = TextWidth(DisplayText)
            Protected AvailableWidth.i = *Box\Box\Width
            If AvailableWidth <= 0
              AvailableWidth = ContentWidth - TextX - 20
            EndIf

            Select *Box\TextAlign
              Case 1 : TextX = TextX + (AvailableWidth - LineTextWidth) / 2
              Case 2 : TextX = TextX + (AvailableWidth - LineTextWidth)
            EndSelect

            DrawText(TextX, TextY, DisplayText, *Box\Color)

            Protected TextW.i = LineTextWidth
            Select *Box\TextDecoration
              Case 1 : Line(TextX, TextY + *Box\FontSize + 2, TextW, 1, *Box\Color)
              Case 2 : Line(TextX, TextY + (*Box\FontSize / 2), TextW, 1, *Box\Color)
              Case 3 : Line(TextX, TextY - 2, TextW, 1, *Box\Color)
            EndSelect

            Protected ActualLineHeight.i = *Box\LineHeight
            If ActualLineHeight <= 0
              ActualLineHeight = *Box\FontSize + 6
            EndIf
            LineY + ActualLineHeight
          Next
        EndIf

    EndSelect

    ForEach *Box\Children()
      DrawLayoutBox(*Box\Children(), *Doc)
    Next
  EndProcedure
  
  Procedure RenderLayout(*LayoutRoot.Layout::LayoutBox, *Doc.Document::Document)
    Debug ""
    Debug "=== BrowserUI::RenderLayout START ==="
    
    PreloadFontsFromLayout(*CurrentLayout)

    If Not StartDrawing(CanvasOutput(#Canvas_Main))
      Debug "FEHLER: Konnte nicht auf Canvas zeichnen!"
      ProcedureReturn
    EndIf
    
    Debug "Canvas Drawing Area: " + Str(OutputWidth()) + "x" + Str(OutputHeight())
    
    DrawingMode(#PB_2DDrawing_Default)
    Box(0, 0, OutputWidth(), OutputHeight(), RGB(255, 255, 255))
    
    DrawingMode(#PB_2DDrawing_Transparent)
    
    If *LayoutRoot
      ForEach *LayoutRoot\Children()
        DrawLayoutBox(*LayoutRoot\Children(), *Doc)
      Next
    Else
      Debug "FEHLER: Layout-Root ist NULL!"
    EndIf
    
    StopDrawing()
    Debug "=== BrowserUI::RenderLayout END ==="
    Debug ""
  EndProcedure
  
  Procedure.i SaveAsImage(Filename.s, Fileformat = OSFunc::#image_png)
    Protected Img.i, Result.i, suffix.s = "png"
    Protected ActualWidth.i, ActualHeight.i

    Select Fileformat
      Case OSFunc::#image_png: suffix = "png"
      Case OSFunc::#image_jpg: suffix = "jpg"
      Case OSFunc::#image_bmp: suffix = "bmp"
      Case OSFunc::#image_tiff: suffix = "tiff"
      Case OSFunc::#image_jpeg2000: suffix = "jp2"
    EndSelect

    If LCase(GetExtensionPart(Filename)) <> suffix
      Filename + "." + suffix
    EndIf

    ; Canvas-Größe ermitteln
    ActualWidth = GadgetWidth(#Canvas_Main)
    ActualHeight = GadgetHeight(#Canvas_Main)

    Debug ""
    Debug "=== SaveAsImage START ==="
    Debug "[SaveAsImage] Speichere als: " + Filename
    Debug "[SaveAsImage] Canvas-Größe: " + Str(ActualWidth) + "x" + Str(ActualHeight)

    ; 32-Bit Image (macOS nutzt intern immer 32-Bit ARGB)
    Img = CreateImage(#PB_Any, ActualWidth, ActualHeight, 32)
    If Img
      PreloadFontsFromLayout(*CurrentLayout)

      If StartDrawing(ImageOutput(Img))
        ; Weißer opaker Hintergrund: ALLE 4 Kanäle (RGBA) auf 255 setzen
        DrawingMode(#PB_2DDrawing_AllChannels)
        Box(0, 0, ActualWidth, ActualHeight, RGBA(255, 255, 255, 255))
        DrawingMode(#PB_2DDrawing_Transparent)

        ; Layout direkt ins Image rendern
        If *CurrentLayout
          ForEach *CurrentLayout\Children()
            DrawLayoutBox(*CurrentLayout\Children(), *CurrentDoc)
          Next
        EndIf

        ; macOS Fix: Alpha-Kanal aller Pixel auf 255 forcen
        ; (DrawText/Box im Transparent-Modus setzen Alpha nicht immer korrekt)
        Protected *buf = DrawingBuffer()
        Protected pitch.i = DrawingBufferPitch()
        Protected pixFmt.i = DrawingBufferPixelFormat()
        Protected alphaOff.i
        If pixFmt = #PB_PixelFormat_32Bits_RGB
          alphaOff = 0   ; macOS ARGB: Alpha ist erstes Byte
        Else
          alphaOff = 3   ; Windows BGRA: Alpha ist letztes Byte
        EndIf

        Protected px.i, py.i, *row
        For py = 0 To ActualHeight - 1
          *row = *buf + (py * pitch)
          For px = 0 To ActualWidth - 1
            PokeA(*row + (px * 4) + alphaOff, 255)
          Next
        Next

        StopDrawing()
      EndIf

      Debug "[SaveAsImage] Image erstellt: " + Str(ImageWidth(Img)) + "x" + Str(ImageHeight(Img))

      Result = OSFunc::SaveImageEx(Img, Filename, Fileformat)
      FreeImage(Img)

      If Result
        Debug "[SaveAsImage] Erfolgreich gespeichert!"
      Else
        Debug "[SaveAsImage] FEHLER beim Speichern!"
      EndIf

      Debug "=== SaveAsImage END ==="
      Debug ""
      ProcedureReturn Result
    Else
      Debug "[SaveAsImage] FEHLER: CreateImage fehlgeschlagen!"
    EndIf

    Debug "=== SaveAsImage END ==="
    Debug ""
    ProcedureReturn #False
  EndProcedure
  
  Procedure.i HandleEvents()
    Protected Event.i, EventGadget.i
    
    Repeat
      Event = WindowEvent()
      
      Select Event
        Case #PB_Event_CloseWindow
          ProcedureReturn #False
          
        Case #PB_Event_SizeWindow
          If Not IsFullscreen
            WindowWidth = WindowWidth(#Window_Main)
            WindowHeight = WindowHeight(#Window_Main)
            
            ResizeGadget(#ScrollArea_Main, 0, 0, WindowWidth, WindowHeight)
            
          EndIf
          
        Case #PB_Event_Gadget
          EventGadget = EventGadget()
          
          Select EventGadget
            Case #Canvas_Main
              ; Canvas-Events
              
          EndSelect
      EndSelect
      
    Until Event = 0
    
    ProcedureReturn #True
  EndProcedure
  
EndModule
; IDE Options = PureBasic 6.21 - C Backend (MacOS X - arm64)
; CursorPosition = 41
; FirstLine = 37
; Folding = ----
; EnableXP
; DPIAware