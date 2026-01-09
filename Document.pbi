; ============================================================================
; Document.pbi v0.6.0
; Document mit CSS und External Stylesheet Support
; ============================================================================

XIncludeFile "HTMLParser.pbi"
XIncludeFile "CSSParser.pbi"
XIncludeFile "Style.pbi"
XIncludeFile "URLResolver.pbi"

DeclareModule Document
  
  Structure DocumentInfo
    Title.s
    BaseURL.s
    Charset.s
  EndStructure
  
  Structure Document
    *RootNode.HTMLParser::DOMNode
    Info.DocumentInfo
    URL.s
    ContentWidth.i
    ContentHeight.i
    *StyleSheet.CSSParser::StyleSheet
  EndStructure
  
  Declare.i Create(HTML.s, URL.s)
  Declare Free(*Doc.Document)
  Declare ExtractMetadata(*Doc.Document)
  
EndDeclareModule

Module Document
  
  Procedure.i Create(HTML.s, URL.s)
    Protected *Doc.Document = AllocateMemory(SizeOf(Document))
    
    If *Doc
      InitializeStructure(*Doc, Document)
      *Doc\RootNode = HTMLParser::Parse(HTML)
      *Doc\URL = URL
      *Doc\Info\BaseURL = URL  ; Setze BaseURL für relative Pfade
      *Doc\Info\Charset = "UTF-8"
      
      ExtractMetadata(*Doc)
    EndIf
    
    ProcedureReturn *Doc
  EndProcedure
  
  Procedure Free(*Doc.Document)
    If *Doc
      If *Doc\RootNode
        HTMLParser::FreeDOM(*Doc\RootNode)
      EndIf
      If *Doc\StyleSheet
        CSSParser::FreeStyleSheet(*Doc\StyleSheet)
      EndIf
      FreeMemory(*Doc)
    EndIf
  EndProcedure
  
  Procedure.s FindTitle(*Node.HTMLParser::DOMNode)
    Protected Result.s = ""
    
    If *Node
      If *Node\ElementType = HTMLParser::#Element_TITLE
        ForEach *Node\Children()
          If *Node\Children()\Type = HTMLParser::#NodeType_Text
            Result = *Node\Children()\TextContent
            ProcedureReturn Result
          EndIf
        Next
      EndIf
      
      ForEach *Node\Children()
        Result = FindTitle(*Node\Children())
        If Result <> ""
          ProcedureReturn Result
        EndIf
      Next
    EndIf
    
    ProcedureReturn ""
  EndProcedure
  
  Procedure ExtractStyleTags(*Node.HTMLParser::DOMNode, List Styles.s())
    If *Node
      If *Node\ElementType = HTMLParser::#Element_STYLE
        ForEach *Node\Children()
          If *Node\Children()\Type = HTMLParser::#NodeType_Text
            AddElement(Styles())
            Styles() = *Node\Children()\TextContent
          EndIf
        Next
      EndIf
      
      ForEach *Node\Children()
        ExtractStyleTags(*Node\Children(), Styles())
      Next
    EndIf
  EndProcedure
  
  Procedure ExtractLinkTags(*Node.HTMLParser::DOMNode, *Doc.Document, List Styles.s())
    Protected Href.s, Rel.s, FullURL.s, CSS.s
    
    If *Node
      If *Node\ElementType = HTMLParser::#Element_LINK
        ; Prüfe ob stylesheet
        If FindMapElement(*Node\Attributes(), "rel")
          Rel = LCase(Trim(*Node\Attributes()))
          
          If Rel = "stylesheet"
            ; Lade externes Stylesheet
            If FindMapElement(*Node\Attributes(), "href")
              Href = *Node\Attributes()
              
              ; Löse relative URL auf
              FullURL = URLResolver::ResolveURL(*Doc\Info\BaseURL, Href)
              
              Debug "[Document] Lade externes Stylesheet: " + FullURL
              
              ; Lade CSS
              CSS = URLResolver::LoadResource(FullURL)
              
              If CSS <> ""
                AddElement(Styles())
                Styles() = CSS
                Debug "[Document] Stylesheet geladen: " + Str(Len(CSS)) + " Zeichen"
              Else
                Debug "[Document] Stylesheet konnte nicht geladen werden: " + FullURL
              EndIf
            EndIf
          EndIf
        EndIf
      EndIf
      
      ForEach *Node\Children()
        ExtractLinkTags(*Node\Children(), *Doc, Styles())
      Next
    EndIf
  EndProcedure
  
  Procedure ApplyInlineStyles(*Node.HTMLParser::DOMNode)
    ; Parse style="" Attribute und setze als css-* Attribute
    If *Node
      If FindMapElement(*Node\Attributes(), "style")
        Protected StyleAttr.s = *Node\Attributes()
        Protected i.i, Pair.s, PropName.s, PropValue.s, ColonPos.i
        
        ; Parse "color: red; font-size: 16px"
        For i = 1 To CountString(StyleAttr, ";") + 1
          Pair = Trim(StringField(StyleAttr, i, ";"))
          If Pair <> ""
            ColonPos = FindString(Pair, ":", 1)
            If ColonPos > 0
              PropName = LCase(Trim(Left(Pair, ColonPos - 1)))
              PropValue = Trim(Mid(Pair, ColonPos + 1))
              
              If PropName <> "" And PropValue <> ""
                ; Setze als css-* Attribut
                *Node\Attributes("css-" + PropName) = PropValue
              EndIf
            EndIf
          EndIf
        Next
      EndIf
      
      ; Rekursiv auf Kinder anwenden
      ForEach *Node\Children()
        ApplyInlineStyles(*Node\Children())
      Next
    EndIf
  EndProcedure
  
  Procedure ExtractMetadata(*Doc.Document)
    If *Doc And *Doc\RootNode
      *Doc\Info\Title = FindTitle(*Doc\RootNode)
      
      NewList AllStyles.s()
      
      ; 1. Sammle <style> Tags (inline CSS)
      ExtractStyleTags(*Doc\RootNode, AllStyles())
      
      ; 2. Sammle <link> Tags (externe Stylesheets)
      ExtractLinkTags(*Doc\RootNode, *Doc, AllStyles())
      
      ; 3. Kombiniere und parse CSS
      Protected CombinedCSS.s = ""
      ForEach AllStyles()
        CombinedCSS + AllStyles() + " "
      Next
      
      If CombinedCSS <> ""
        *Doc\StyleSheet = CSSParser::Parse(CombinedCSS)
        
        If *Doc\StyleSheet
          Style::ApplyStyleSheet(*Doc\RootNode, *Doc\StyleSheet)
        EndIf
      EndIf
      
      ; 4. Parse inline style="" Attribute
      ApplyInlineStyles(*Doc\RootNode)
    EndIf
  EndProcedure
  
EndModule
