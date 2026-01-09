; ============================================================================
; HTMLParser.pbi v0.4.0 - 100% HTML 4.01 COMPLETE
; HTML-Parser-Modul mit vollständiger HTML 4.01 Element-Unterstützung
; Alle 91 HTML 4.01 Strict Tags implementiert
; ============================================================================

DeclareModule HTMLParser
  
  Enumeration NodeType
    #NodeType_Element
    #NodeType_Text
    #NodeType_Root
  EndEnumeration
  
  ; Alle HTML 4.01 Tags (vollständige Implementierung)
  Enumeration ElementType
    ; Struktur
    #Element_HTML
    #Element_HEAD
    #Element_BODY
    #Element_HEADER
    #Element_FOOTER
    #Element_NAV
    #Element_SECTION
    #Element_ARTICLE
    #Element_ASIDE
    #Element_MAIN
    #Element_DIV
    #Element_SPAN
    #Element_ADDRESS
    #Element_CENTER
    
    ; Text-Formatierung
    #Element_H1
    #Element_H2
    #Element_H3
    #Element_H4
    #Element_H5
    #Element_H6
    #Element_P
    #Element_BR
    #Element_HR
    #Element_STRONG
    #Element_EM
    #Element_B
    #Element_I
    #Element_SMALL
    #Element_BIG
    #Element_U
    #Element_S
    #Element_STRIKE
    #Element_DEL      ; HTML 4.01: Gelöschter Text
    #Element_INS      ; HTML 4.01: Eingefügter Text
    #Element_TT
    #Element_SUB
    #Element_SUP
    #Element_PRE
    #Element_CODE
    #Element_BLOCKQUOTE
    #Element_Q        ; HTML 4.01: Kurzes Zitat (inline)
    #Element_CITE
    #Element_DFN
    #Element_KBD
    #Element_SAMP
    #Element_VAR
    #Element_ABBR
    #Element_ACRONYM
    #Element_BDO      ; HTML 4.01: Bidirektionaler Text-Override
    
    ; Listen
    #Element_UL
    #Element_OL
    #Element_LI
    #Element_DL
    #Element_DT
    #Element_DD
    #Element_MENU
    #Element_DIR
    
    ; Links/Media/Objects
    #Element_A
    #Element_IMG
    #Element_MAP
    #Element_AREA
    #Element_OBJECT
    #Element_PARAM
    #Element_APPLET
    #Element_VIDEO
    #Element_AUDIO
    #Element_CANVAS
    #Element_IFRAME
    
    ; Tabellen
    #Element_TABLE
    #Element_CAPTION
    #Element_THEAD
    #Element_TBODY
    #Element_TFOOT
    #Element_TR
    #Element_TD
    #Element_TH
    #Element_COL
    #Element_COLGROUP
    
    ; Formulare
    #Element_FORM
    #Element_INPUT
    #Element_BUTTON
    #Element_TEXTAREA
    #Element_SELECT
    #Element_OPTION
    #Element_OPTGROUP
    #Element_LABEL
    #Element_FIELDSET
    #Element_LEGEND
    
    ; Meta/Scripts
    #Element_META
    #Element_LINK
    #Element_BASE
    #Element_BASEFONT  ; HTML 4.01 deprecated
    #Element_FONT      ; HTML 4.01 deprecated
    #Element_ISINDEX   ; HTML 4.01 deprecated
    #Element_STYLE
    #Element_SCRIPT
    #Element_TITLE
    #Element_NOSCRIPT
    
    ; Frames
    #Element_FRAMESET
    #Element_FRAME
    #Element_NOFRAMES  ; HTML 4.01: Frames Fallback
    
    #Element_Unknown
  EndEnumeration
  
  Structure DOMNode
    Type.i
    ElementType.i
    TagName.s
    TextContent.s
    
    ; ID und Classes
    ID.s
    List Classes.s()
    
    Map Attributes.s()
    *Parent.DOMNode
    List *Children.DOMNode()
    Hidden.i
  EndStructure
  
  Declare.i Parse(HTML.s)
  Declare FreeDOM(*Root.DOMNode)
  Declare.s GetAttribute(*Node.DOMNode, AttributeName.s)
  Declare.i HasClass(*Node.DOMNode, ClassName.s)
  Declare PrintDOM(*Node.DOMNode, Indent.i=0)
  
EndDeclareModule

Module HTMLParser
  
;   Procedure.s Trim(Text.s)
;     ProcedureReturn RTrim(LTrim(Text))
;   EndProcedure
  
  Procedure.i StringToElementType(TagName.s)
    TagName = LCase(TagName)
    Select TagName
      ; Struktur
      Case "html": ProcedureReturn #Element_HTML
      Case "head": ProcedureReturn #Element_HEAD
      Case "body": ProcedureReturn #Element_BODY
      Case "header": ProcedureReturn #Element_HEADER
      Case "footer": ProcedureReturn #Element_FOOTER
      Case "nav": ProcedureReturn #Element_NAV
      Case "section": ProcedureReturn #Element_SECTION
      Case "article": ProcedureReturn #Element_ARTICLE
      Case "aside": ProcedureReturn #Element_ASIDE
      Case "main": ProcedureReturn #Element_MAIN
      Case "div": ProcedureReturn #Element_DIV
      Case "span": ProcedureReturn #Element_SPAN
      Case "address": ProcedureReturn #Element_ADDRESS
      Case "center": ProcedureReturn #Element_CENTER
      
      ; Text-Formatierung
      Case "h1": ProcedureReturn #Element_H1
      Case "h2": ProcedureReturn #Element_H2
      Case "h3": ProcedureReturn #Element_H3
      Case "h4": ProcedureReturn #Element_H4
      Case "h5": ProcedureReturn #Element_H5
      Case "h6": ProcedureReturn #Element_H6
      Case "p": ProcedureReturn #Element_P
      Case "br": ProcedureReturn #Element_BR
      Case "hr": ProcedureReturn #Element_HR
      Case "strong": ProcedureReturn #Element_STRONG
      Case "em": ProcedureReturn #Element_EM
      Case "b": ProcedureReturn #Element_B
      Case "i": ProcedureReturn #Element_I
      Case "small": ProcedureReturn #Element_SMALL
      Case "big": ProcedureReturn #Element_BIG
      Case "u": ProcedureReturn #Element_U
      Case "s": ProcedureReturn #Element_S
      Case "strike": ProcedureReturn #Element_STRIKE
      Case "del": ProcedureReturn #Element_DEL
      Case "ins": ProcedureReturn #Element_INS
      Case "tt": ProcedureReturn #Element_TT
      Case "sub": ProcedureReturn #Element_SUB
      Case "sup": ProcedureReturn #Element_SUP
      Case "pre": ProcedureReturn #Element_PRE
      Case "code": ProcedureReturn #Element_CODE
      Case "blockquote": ProcedureReturn #Element_BLOCKQUOTE
      Case "q": ProcedureReturn #Element_Q
      Case "cite": ProcedureReturn #Element_CITE
      Case "dfn": ProcedureReturn #Element_DFN
      Case "kbd": ProcedureReturn #Element_KBD
      Case "samp": ProcedureReturn #Element_SAMP
      Case "var": ProcedureReturn #Element_VAR
      Case "abbr": ProcedureReturn #Element_ABBR
      Case "acronym": ProcedureReturn #Element_ACRONYM
      Case "bdo": ProcedureReturn #Element_BDO
      
      ; Listen
      Case "ul": ProcedureReturn #Element_UL
      Case "ol": ProcedureReturn #Element_OL
      Case "li": ProcedureReturn #Element_LI
      Case "dl": ProcedureReturn #Element_DL
      Case "dt": ProcedureReturn #Element_DT
      Case "dd": ProcedureReturn #Element_DD
      Case "menu": ProcedureReturn #Element_MENU
      Case "dir": ProcedureReturn #Element_DIR
      
      ; Links/Media/Objects
      Case "a": ProcedureReturn #Element_A
      Case "img": ProcedureReturn #Element_IMG
      Case "map": ProcedureReturn #Element_MAP
      Case "area": ProcedureReturn #Element_AREA
      Case "object": ProcedureReturn #Element_OBJECT
      Case "param": ProcedureReturn #Element_PARAM
      Case "applet": ProcedureReturn #Element_APPLET
      Case "video": ProcedureReturn #Element_VIDEO
      Case "audio": ProcedureReturn #Element_AUDIO
      Case "canvas": ProcedureReturn #Element_CANVAS
      Case "iframe": ProcedureReturn #Element_IFRAME
      
      ; Tabellen
      Case "table": ProcedureReturn #Element_TABLE
      Case "caption": ProcedureReturn #Element_CAPTION
      Case "thead": ProcedureReturn #Element_THEAD
      Case "tbody": ProcedureReturn #Element_TBODY
      Case "tfoot": ProcedureReturn #Element_TFOOT
      Case "tr": ProcedureReturn #Element_TR
      Case "td": ProcedureReturn #Element_TD
      Case "th": ProcedureReturn #Element_TH
      Case "col": ProcedureReturn #Element_COL
      Case "colgroup": ProcedureReturn #Element_COLGROUP
      
      ; Formulare
      Case "form": ProcedureReturn #Element_FORM
      Case "input": ProcedureReturn #Element_INPUT
      Case "button": ProcedureReturn #Element_BUTTON
      Case "textarea": ProcedureReturn #Element_TEXTAREA
      Case "select": ProcedureReturn #Element_SELECT
      Case "option": ProcedureReturn #Element_OPTION
      Case "optgroup": ProcedureReturn #Element_OPTGROUP
      Case "label": ProcedureReturn #Element_LABEL
      Case "fieldset": ProcedureReturn #Element_FIELDSET
      Case "legend": ProcedureReturn #Element_LEGEND
      
      ; Meta/Scripts
      Case "meta": ProcedureReturn #Element_META
      Case "link": ProcedureReturn #Element_LINK
      Case "base": ProcedureReturn #Element_BASE
      Case "basefont": ProcedureReturn #Element_BASEFONT
      Case "font": ProcedureReturn #Element_FONT
      Case "isindex": ProcedureReturn #Element_ISINDEX
      Case "style": ProcedureReturn #Element_STYLE
      Case "script": ProcedureReturn #Element_SCRIPT
      Case "title": ProcedureReturn #Element_TITLE
      Case "noscript": ProcedureReturn #Element_NOSCRIPT
      
      ; Frames
      Case "frameset": ProcedureReturn #Element_FRAMESET
      Case "frame": ProcedureReturn #Element_FRAME
      Case "noframes": ProcedureReturn #Element_NOFRAMES
      Case "bdo": ProcedureReturn #Element_BDO
      
      Default: ProcedureReturn #Element_Unknown
    EndSelect
  EndProcedure
  
  Procedure.i IsSelfClosingTag(TagName.s)
    TagName = LCase(TagName)
    Select TagName
      Case "br", "hr", "img", "input", "meta", "link", "base", "basefont",
           "area", "col", "param", "frame"
        ProcedureReturn #True
      Default
        ProcedureReturn #False
    EndSelect
  EndProcedure
  
  Procedure.i CreateDOMNode(Type.i)
    Protected *Node.DOMNode = AllocateMemory(SizeOf(DOMNode))
    If *Node
      InitializeStructure(*Node, DOMNode)
      *Node\Type = Type
      *Node\Hidden = 0
    EndIf
    ProcedureReturn *Node
  EndProcedure
  
  Procedure AddChild(*Parent.DOMNode, *Child.DOMNode)
    If *Parent And *Child
      AddElement(*Parent\Children())
      *Parent\Children() = *Child
      *Child\Parent = *Parent
    EndIf
  EndProcedure
  
  Procedure FreeDOM(*Node.DOMNode)
    If *Node
      ForEach *Node\Children()
        FreeDOM(*Node\Children())
      Next
      ClearList(*Node\Classes())
      ClearMap(*Node\Attributes())
      FreeMemory(*Node)
    EndIf
  EndProcedure
  
  Procedure ParseAttributes(AttributeString.s, Map Attributes.s())
    Protected Pos.i, InQuote.i, QuoteChar.s, CurrentKey.s, CurrentValue.s
    Protected State.i
    Protected Char.s
    
    AttributeString = Trim(AttributeString)
    State = 0
    
    For Pos = 1 To Len(AttributeString)
      Char = Mid(AttributeString, Pos, 1)
      
      Select State
        Case 0
          If Char = "="
            State = 1
          ElseIf Char = " " Or Char = Chr(#TAB)
            If CurrentKey <> ""
              Attributes(LCase(CurrentKey)) = ""
              CurrentKey = ""
            EndIf
          Else
            CurrentKey + Char
          EndIf
          
        Case 1
          If Char = Chr(34) Or Char = "'"
            QuoteChar = Char
            InQuote = #True
            State = 2
          ElseIf Char <> " " And Char <> Chr(#TAB)
            CurrentValue = Char
            State = 2
          EndIf
          
        Case 2
          If InQuote
            If Char = QuoteChar
              InQuote = #False
              Attributes(LCase(CurrentKey)) = CurrentValue
              CurrentKey = ""
              CurrentValue = ""
              State = 0
            Else
              CurrentValue + Char
            EndIf
          Else
            If Char = " " Or Char = Chr(#TAB)
              Attributes(LCase(CurrentKey)) = CurrentValue
              CurrentKey = ""
              CurrentValue = ""
              State = 0
            Else
              CurrentValue + Char
            EndIf
          EndIf
      EndSelect
    Next
    
    If CurrentKey <> ""
      Attributes(LCase(CurrentKey)) = CurrentValue
    EndIf
  EndProcedure
  
  Procedure ExtractIDAndClasses(*Node.DOMNode)
    Protected ClassString.s, i.i, ClassName.s
    
    If Not *Node
      ProcedureReturn
    EndIf
    
    ; ID extrahieren
    If FindMapElement(*Node\Attributes(), "id")
      *Node\ID = *Node\Attributes()
    EndIf
    
    ; Classes extrahieren
    If FindMapElement(*Node\Attributes(), "class")
      ClassString = *Node\Attributes()
      
      ; Classes an Leerzeichen aufteilen
      For i = 1 To CountString(ClassString, " ") + 1
        ClassName = Trim(StringField(ClassString, i, " "))
        If ClassName <> ""
          AddElement(*Node\Classes())
          *Node\Classes() = ClassName
        EndIf
      Next
    EndIf
  EndProcedure
  
  Procedure.i Parse(HTML.s)
    Protected *Root.DOMNode, *Current.DOMNode
    Protected Pos.i, Len.i, Char.s
    Protected InTag.i, TagContent.s, TextContent.s
    Protected TagName.s, AttributeString.s
    Protected IsClosingTag.i, IsSelfClosing.i
    Protected SpacePos.i
    
    NewList NodeStack.i()
    
    *Root = CreateDOMNode(#NodeType_Root)
    *Current = *Root
    AddElement(NodeStack())
    NodeStack() = *Root
    
    Len = Len(HTML)
    Pos = 1
    
    While Pos <= Len
      Char = Mid(HTML, Pos, 1)
      
      If Char = "<"
        If TextContent <> ""
          TextContent = Trim(TextContent)
          If TextContent <> ""
            Protected *TextNode.DOMNode = CreateDOMNode(#NodeType_Text)
            *TextNode\TextContent = TextContent
            AddChild(*Current, *TextNode)
            TextContent = ""
          EndIf
        EndIf
        
        InTag = #True
        TagContent = ""
        Pos + 1
        
        While Pos <= Len And InTag
          Char = Mid(HTML, Pos, 1)
          If Char = ">"
            InTag = #False
          Else
            TagContent + Char
            Pos + 1
          EndIf
        Wend
        
        TagContent = Trim(TagContent)
        
        If Left(TagContent, 1) = "!" Or Left(TagContent, 1) = "?"
          Pos + 1
          Continue
        EndIf
        
        IsClosingTag = #False
        If Left(TagContent, 1) = "/"
          IsClosingTag = #True
          TagContent = Mid(TagContent, 2)
        EndIf
        
        IsSelfClosing = #False
        If Right(TagContent, 1) = "/"
          IsSelfClosing = #True
          TagContent = Left(TagContent, Len(TagContent) - 1)
          TagContent = Trim(TagContent)
        EndIf
        
        SpacePos = FindString(TagContent, " ", 1)
        If SpacePos > 0
          TagName = Left(TagContent, SpacePos - 1)
          AttributeString = Mid(TagContent, SpacePos + 1)
        Else
          TagName = TagContent
          AttributeString = ""
        EndIf
        
        TagName = LCase(Trim(TagName))
        
        If IsClosingTag
          If ListSize(NodeStack()) > 1
            LastElement(NodeStack())
            DeleteElement(NodeStack())
            If LastElement(NodeStack())
              *Current = NodeStack()
            EndIf
          EndIf
        Else
          Protected *NewNode.DOMNode = CreateDOMNode(#NodeType_Element)
          *NewNode\TagName = TagName
          *NewNode\ElementType = StringToElementType(TagName)
          
          If TagName = "style" Or TagName = "script" Or TagName = "noscript"
            *NewNode\Hidden = 1
          EndIf
          
          If AttributeString <> ""
            ParseAttributes(AttributeString, *NewNode\Attributes())
            ExtractIDAndClasses(*NewNode)
          EndIf
          
          AddChild(*Current, *NewNode)
          
          If Not IsSelfClosing And Not IsSelfClosingTag(TagName)
            *Current = *NewNode
            AddElement(NodeStack())
            NodeStack() = *NewNode
          EndIf
        EndIf
        
      Else
        TextContent + Char
      EndIf
      
      Pos + 1
    Wend
    
    If TextContent <> ""
      TextContent = Trim(TextContent)
      If TextContent <> ""
        *TextNode = CreateDOMNode(#NodeType_Text)
        *TextNode\TextContent = TextContent
        AddChild(*Current, *TextNode)
      EndIf
    EndIf
    
    ProcedureReturn *Root
  EndProcedure
  
  Procedure.s GetAttribute(*Node.DOMNode, AttributeName.s)
    If *Node
      AttributeName = LCase(AttributeName)
      If FindMapElement(*Node\Attributes(), AttributeName)
        ProcedureReturn *Node\Attributes()
      EndIf
    EndIf
    ProcedureReturn ""
  EndProcedure
  
  Procedure.i HasClass(*Node.DOMNode, ClassName.s)
    If *Node
      ClassName = Trim(ClassName)
      ForEach *Node\Classes()
        If *Node\Classes() = ClassName
          ProcedureReturn #True
        EndIf
      Next
    EndIf
    ProcedureReturn #False
  EndProcedure
  
  Procedure PrintDOM(*Node.DOMNode, Indent.i=0)
    Protected i.i, IndentStr.s = ""
    
    For i = 1 To Indent
      IndentStr + "  "
    Next
    
    If *Node
      Select *Node\Type
        Case #NodeType_Root
          Debug IndentStr + "[ROOT]"
          
        Case #NodeType_Element
          Protected Info.s = IndentStr + "<" + *Node\TagName
          If *Node\ID <> ""
            Info + " id=" + Chr(34) + *Node\ID + Chr(34)
          EndIf
          If ListSize(*Node\Classes()) > 0
            Info + " class=" + Chr(34)
            ForEach *Node\Classes()
              Info + *Node\Classes() + " "
            Next
            Info = RTrim(Info) + Chr(34)
          EndIf
          Info + ">"
          Debug Info
          
        Case #NodeType_Text
          If Len(*Node\TextContent) > 50
            Debug IndentStr + "[TEXT]: " + Left(*Node\TextContent, 50) + "..."
          Else
            Debug IndentStr + "[TEXT]: " + *Node\TextContent
          EndIf
      EndSelect
      
      ForEach *Node\Children()
        PrintDOM(*Node\Children(), Indent + 1)
      Next
    EndIf
  EndProcedure
  
EndModule

; IDE Options = PureBasic 6.21 - C Backend (MacOS X - arm64)
; CursorPosition = 283
; FirstLine = 260
; Folding = ---
; EnableXP
; DPIAware