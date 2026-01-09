; ============================================================================
; BrowserUI.pbi v0.2.0 - HTML 4 RENDERING
; Rendering mit Text-Dekorationen:
; - Underline, Strikethrough
; - Subscript, Superscript mit Y-Offset
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
    
    ; Rendere Border wenn vorhanden
    If *Box\BorderWidth > 0 And *Box\BorderStyle > 0
      Protected BorderX.i = *Box\Box\X
      Protected BorderY.i = *Box\Box\Y
      Protected BorderW.i = *Box\Box\Width
      Protected BorderH.i = *Box\Box\Height
      
      Debug "[Border] Element: " + *Box\DOMNode\TagName + " X:" + Str(BorderX) + " Y:" + Str(BorderY) + " W:" + Str(BorderW) + " H:" + Str(BorderH) + " Style:" + Str(*Box\BorderStyle)
      
      ; Setze DrawingMode für Borders
      DrawingMode(#PB_2DDrawing_Outlined)
      
      Select *Box\BorderStyle
        Case 1  ; Solid
          Box(BorderX, BorderY, BorderW, BorderH, *Box\BorderColor)
          
        Case 2  ; Dashed
          ; Zeichne gestrichelte Linie (simplified)
          ; Step kann in PureBasic keine Variable sein, daher hardcoded
          Protected i.i
          
          ; Top
          For i = BorderX To BorderX + BorderW Step 10
            Line(i, BorderY, 5, 1, *Box\BorderColor)
          Next
          
          ; Bottom
          For i = BorderX To BorderX + BorderW Step 10
            Line(i, BorderY + BorderH, 5, 1, *Box\BorderColor)
          Next
          
          ; Left
          For i = BorderY To BorderY + BorderH Step 10
            Line(BorderX, i, 1, 5, *Box\BorderColor)
          Next
          
          ; Right
          For i = BorderY To BorderY + BorderH Step 10
            Line(BorderX + BorderW, i, 1, 5, *Box\BorderColor)
          Next
          
        Case 3  ; Dotted
          ; Zeichne gepunktete Linie
          ; Step kann in PureBasic keine Variable sein, daher hardcoded
          Protected j.i
          
          ; Top
          For j = BorderX To BorderX + BorderW Step 3
            Plot(j, BorderY, *Box\BorderColor)
          Next
          
          ; Bottom
          For j = BorderX To BorderX + BorderW Step 3
            Plot(j, BorderY + BorderH, *Box\BorderColor)
          Next
          
          ; Left
          For j = BorderY To BorderY + BorderH Step 3
            Plot(BorderX, j, *Box\BorderColor)
          Next
          
          ; Right
          For j = BorderY To BorderY + BorderH Step 3
            Plot(BorderX + BorderW, j, *Box\BorderColor)
          Next
      EndSelect
      
      ; Setze DrawingMode zurück für Text
      DrawingMode(#PB_2DDrawing_Transparent)
    EndIf
    
    Select *Box\DOMNode\Type
      Case HTMLParser::#NodeType_Element
        ; STAGE 2: InlineRuns auch bei Element-Boxen rendern (z.B. <p>, <h1>, <li>, <div> inline)
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

          ; Copy Lists to Arrays (einfache Indexierung)
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

            ; Breite dieser Zeile exakt berechnen (gemischte Fonts, Tabs berücksichtigt)
            ; TabStops: orientieren sich an der Breite von 8 Spaces im Base-Font.
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
              curX = MeasureTextWithTabs(0, curX, runs(runIndex + k)\Text, tabW)
            Next
            lineW = curX

            ; Justify: Extra pro SPACE-RUN ("  " zählt als 1), nicht auf letzter Zeile
            ; Bei Tabs deaktivieren (Tabs sind feste Stops)
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
            Select *Box\TextAlign
              Case 1 ; center
                x = startX + (availW - lineW) / 2
              Case 2 ; right
                x = startX + (availW - lineW)
              Default
                ; left/justify -> left
            EndSelect

            ; Bullet (nur für LI) - einmalig
            If *Box\DOMNode\ElementType = HTMLParser::#Element_LI And bulletDone = #False
              Protected bf.i = GetOrLoadFont(BaseFont, *Box\FontSize, *Box\FontStyle, #False)
              If bf
                DrawingFont(FontID(bf))
                DrawText(startX - TextWidth("• "), y, "• ", *Box\Color)
              EndIf
              bulletDone = #True
            EndIf

            ; Zeile rendern
            For k = 0 To c - 1
              If runIndex >= runTotal : Break : EndIf

              Protected txt.s = runs(runIndex)\Text
              Protected fam2.s = runs(runIndex)\FontFamily
              If fam2 = "" : fam2 = BaseFont : EndIf
              Protected rf.i = GetOrLoadFont(fam2, runs(runIndex)\FontSize, runs(runIndex)\FontStyle, #False)
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

              If HasTab(txt)
                x2 = DrawTextWithTabs(drawX, y + yOff, startX, txt, runs(runIndex)\Color, tabW)
                w = x2 - drawX
              Else
                DrawText(drawX, y + yOff, txt, runs(runIndex)\Color)
                w = TextWidth(txt)
                x2 = drawX + w
              EndIf

              ; Decoration-Positionen etwas stabiler (Top-basierte DrawText Koordinaten)
              Select runs(runIndex)\TextDecoration
                Case 1 ; underline
                  Line(drawX, y + yOff + Int(runs(runIndex)\FontSize * 0.92), w, 1, runs(runIndex)\Color)
                Case 2 ; line-through
                  Line(drawX, y + yOff + Int(runs(runIndex)\FontSize * 0.55), w, 1, runs(runIndex)\Color)
                Case 3 ; overline
                  Line(drawX, y + yOff + 1, w, 1, runs(runIndex)\Color)
              EndSelect

              x = x2

              ; Better-Justify: Extra pro SPACE-RUN (nicht bei Tabs)
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
        ; FontFamily from CSS or default to Arial
        Protected FontName.s = "Arial"
        If *Box\FontFamily <> ""
          FontName = *Box\FontFamily
        EndIf
        
        
        Font = GetOrLoadFont(FontName, *Box\FontSize, *Box\FontStyle, #False)
        
        If Font
          DrawingFont(FontID(Font))
          DrawingMode(#PB_2DDrawing_Transparent)
          
          LineY = *Box\Box\Y
          
          ; Vertikale Verschiebung für Sub/Superscript
          Protected YOffset.i = 0
          If *Box\IsSubscript
            YOffset = *Box\FontSize / 3  ; nach unten verschieben
          ElseIf *Box\IsSuperscript
            YOffset = -*Box\FontSize / 3  ; nach oben verschieben
          EndIf
          
          ForEach *Box\WrappedLines()
            Protected DisplayText.s = *Box\WrappedLines()
            Protected TextX.i = *Box\Box\X
            Protected TextY.i = LineY + YOffset
            
            ; Bullet für Listen
            If *Box\DOMNode\Parent And *Box\DOMNode\Parent\ElementType = HTMLParser::#Element_LI
              DisplayText = "• " + DisplayText
            EndIf
            
            ; Text-Align anwenden
            Protected LineTextWidth.i = TextWidth(DisplayText)
            Protected AvailableWidth.i = *Box\Box\Width
            
            ; Fallback wenn Box-Width nicht gesetzt
            If AvailableWidth <= 0
              AvailableWidth = ContentWidth - TextX - 20  ; 20px Padding rechts
            EndIf
            
            Select *Box\TextAlign
              Case 1  ; Center
                TextX = TextX + (AvailableWidth - LineTextWidth) / 2
              Case 2  ; Right
                TextX = TextX + (AvailableWidth - LineTextWidth)
              Case 3  ; Justify (simplified - just left-align for now)
                ; Justify würde Wort-Spacing anpassen, für jetzt: left-align
                TextX = TextX
              Default  ; Left (0)
                TextX = TextX
            EndSelect
            
            ; Text zeichnen
            DrawText(TextX, TextY, DisplayText, *Box\Color)
            
            ; Text-Dekorationen zeichnen
            Protected TextWidth.i = LineTextWidth
            
            Select *Box\TextDecoration
              Case 1  ; Underline
                Protected UnderlineY.i = TextY + *Box\FontSize + 2
                Line(TextX, UnderlineY, TextWidth, 1, *Box\Color)
                
              Case 2  ; Line-through (Strikethrough)
                Protected StrikeY.i = TextY + (*Box\FontSize / 2)
                Line(TextX, StrikeY, TextWidth, 1, *Box\Color)
                
              Case 3  ; Overline
                Protected OverlineY.i = TextY - 2
                Line(TextX, OverlineY, TextWidth, 1, *Box\Color)
            EndSelect
            
            ; Nutze LineHeight statt hardcoded spacing
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
    
    ; Canvas DIREKT grabben
    If StartDrawing(CanvasOutput(#Canvas_Main))
      
      Img = GrabDrawingImage(#PB_Any, 0, 0, ActualWidth, ActualHeight)
      
      StopDrawing()
      
      If Img
        Debug "[SaveAsImage] Image gegrabbt: " + Str(ImageWidth(Img)) + "x" + Str(ImageHeight(Img))
        
        Result = OSFunc::SaveImageEx(Img, Filename, Fileformat)
        FreeImage(Img)
        
        If Result
          Debug "[SaveAsImage] ✅ Erfolgreich gespeichert!"
        Else
          Debug "[SaveAsImage] ❌ FEHLER beim Speichern!"
        EndIf
        
        Debug "=== SaveAsImage END ==="
        Debug ""
        ProcedureReturn Result
      Else
        Debug "[SaveAsImage] ❌ FEHLER: GrabDrawingImage fehlgeschlagen!"
      EndIf
    Else
      Debug "[SaveAsImage] ❌ FEHLER: Konnte Canvas nicht öffnen!"
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