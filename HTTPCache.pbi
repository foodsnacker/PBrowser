; ============================================================================
; HTTPCache.pbi
; HTTP-Caching mit Base64
; ============================================================================

XIncludeFile "os_functions.pbi"

DeclareModule HTTPCache
  
  Structure CacheEntry
    URL.s
    Content.s
    ImageID.i
    ContentType.s
    Timestamp.q
    Size.i
  EndStructure
  
  Declare Init(MaxSizeMB.i = 50)
  Declare Shutdown()
  Declare.s GetHTML(URL.s)
  Declare.i GetImage(URL.s)
  Declare.i AddToCache(URL.s, Content.s, ContentType.s)
  Declare Clear()
  Declare.i GetCacheSize()
  Declare.i GetEntryCount()
  
EndDeclareModule

Module HTTPCache
  
  Global NewMap Cache.CacheEntry()
  Global MaxCacheSize.q
  Global CurrentCacheSize.q
  
  Procedure Init(MaxSizeMB.i = 50)
    MaxCacheSize = MaxSizeMB * 1024 * 1024
    CurrentCacheSize = 0
  EndProcedure
  
  Procedure Shutdown()
    ForEach Cache()
      If Cache()\ImageID
        FreeImage(Cache()\ImageID)
      EndIf
    Next
    ClearMap(Cache())
    CurrentCacheSize = 0
  EndProcedure
  
  Procedure Clear()
    Shutdown()
    Init()
  EndProcedure
  
  Procedure.i GetCacheSize()
    ProcedureReturn CurrentCacheSize
  EndProcedure
  
  Procedure.i GetEntryCount()
    ProcedureReturn MapSize(Cache())
  EndProcedure
  
  Procedure.s DetermineContentType(URL.s)
    Protected Ext.s = LCase(GetExtensionPart(URL))
    Select Ext
      Case "html", "htm": ProcedureReturn "text/html"
      Case "css": ProcedureReturn "text/css"
      Case "js": ProcedureReturn "text/javascript"
      Case "jpg", "jpeg": ProcedureReturn "image/jpeg"
      Case "png": ProcedureReturn "image/png"
      Case "gif": ProcedureReturn "image/gif"
      Case "webp": ProcedureReturn "image/webp"
      Default: ProcedureReturn "text/plain"
    EndSelect
  EndProcedure
  
  Procedure EvictOldest()
    Protected OldestKey.s, OldestTime.q = 999999999999999
    
    ForEach Cache()
      If Cache()\Timestamp < OldestTime
        OldestTime = Cache()\Timestamp
        OldestKey = MapKey(Cache())
      EndIf
    Next
    
    If OldestKey <> ""
      If FindMapElement(Cache(), OldestKey)
        If Cache()\ImageID
          FreeImage(Cache()\ImageID)
        EndIf
        CurrentCacheSize - Cache()\Size
        DeleteMapElement(Cache())
      EndIf
    EndIf
  EndProcedure
  
  Procedure.i AddToCache(URL.s, Content.s, ContentType.s)
    Protected Size.i = Len(Content)
    
    While CurrentCacheSize + Size > MaxCacheSize
      EvictOldest()
    Wend
    
    AddMapElement(Cache(), URL)
    Cache()\URL = URL
    Cache()\Content = Content
    Cache()\ContentType = ContentType
    Cache()\Timestamp = ElapsedMilliseconds()
    Cache()\Size = Size
    CurrentCacheSize + Size
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure.s GetHTML(URL.s)
    Protected File.i, Result.s, Buffer.s
    
    If FindMapElement(Cache(), URL)
      ProcedureReturn Cache()\Content
    EndIf
    
    File = ReceiveHTTPFile(URL, "")
    If File
      While Not Eof(File)
        Buffer = ReadString(File, #PB_UTF8)
        Result + Buffer + #CRLF$
      Wend
      CloseFile(File)
      
      AddToCache(URL, Result, DetermineContentType(URL))
    Else
      Result = "<html><body><h1>Fehler</h1><p>URL konnte nicht geladen werden: " + URL + "</p></body></html>"
    EndIf
    
    ProcedureReturn Result
  EndProcedure
  
  Procedure.i LoadBase64Image(DataURL.s)
    Protected CommaPos.i, Base64Data.s, *Buffer, BufferSize.i, Img.i
    
    CommaPos = FindString(DataURL, ",", 1)
    If CommaPos = 0
      ProcedureReturn 0
    EndIf
    
    Base64Data = Mid(DataURL, CommaPos + 1)
    
    BufferSize = Len(Base64Data)
    *Buffer = AllocateMemory(BufferSize)
    If Not *Buffer
      ProcedureReturn 0
    EndIf
    
    BufferSize = Base64Decoder(Base64Data, *Buffer, BufferSize)
    
    If BufferSize > 0
      Img = OSFunc::CatchImageEx(#PB_Any, *Buffer, BufferSize)
    EndIf
    
    FreeMemory(*Buffer)
    
    ProcedureReturn Img
  EndProcedure
  
  Procedure.i GetImage(URL.s)
    Protected Img.i, TempFile.s, Size.i
    
    If Left(URL, 5) = "data:"
      If FindMapElement(Cache(), URL)
        If Cache()\ImageID
          ProcedureReturn Cache()\ImageID
        EndIf
      EndIf
      
      Img = LoadBase64Image(URL)
      
      If Img
        Size = 1024 * 50
        
        While CurrentCacheSize + Size > MaxCacheSize
          EvictOldest()
        Wend
        
        AddMapElement(Cache(), URL)
        Cache()\URL = URL
        Cache()\ImageID = Img
        Cache()\ContentType = "image/base64"
        Cache()\Timestamp = ElapsedMilliseconds()
        Cache()\Size = Size
        CurrentCacheSize + Size
        
        ProcedureReturn Img
      EndIf
      
      ProcedureReturn 0
    EndIf
    
    If FindMapElement(Cache(), URL)
      If Cache()\ImageID
        ProcedureReturn Cache()\ImageID
      EndIf
    EndIf
    
    TempFile = GetTemporaryDirectory() + "img_" + Str(Random(999999)) + "." + GetExtensionPart(URL)
    
    If ReceiveHTTPFile(URL, TempFile)
      Img = OSFunc::LoadImageEx(#PB_Any, TempFile)
      DeleteFile(TempFile)
      
      If Img
        Size = 1024 * 100
        
        While CurrentCacheSize + Size > MaxCacheSize
          EvictOldest()
        Wend
        
        AddMapElement(Cache(), URL)
        Cache()\URL = URL
        Cache()\ImageID = Img
        Cache()\ContentType = DetermineContentType(URL)
        Cache()\Timestamp = ElapsedMilliseconds()
        Cache()\Size = Size
        CurrentCacheSize + Size
        
        ProcedureReturn Img
      EndIf
    EndIf
    
    ProcedureReturn 0
  EndProcedure
  
EndModule
