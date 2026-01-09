; ============================================================================
; URLResolver.pbi v0.6.0
; URL-Auflösung und Resource-Loading
; Unterstützt: http://, https://, file://, ftp://, data:
; ============================================================================

DeclareModule URLResolver
  
  Enumeration Protocol
    #Protocol_Unknown
    #Protocol_HTTP
    #Protocol_HTTPS
    #Protocol_File
    #Protocol_FTP
    #Protocol_Data
  EndEnumeration
  
  ; Ermittle Protokoll aus URL
  Declare.i GetProtocol(URL.s)
  
  ; Löse relative URL zu absoluter URL auf (basierend auf BaseURL)
  Declare.s ResolveURL(BaseURL.s, RelativeURL.s)
  
  ; Lade Resource von URL (universell für alle Protokolle)
  Declare.s LoadResource(URL.s)
  
  ; Extrahiere Directory aus URL (für relative Pfade)
  Declare.s GetBaseDirectory(URL.s)
  
EndDeclareModule

Module URLResolver
  
  Procedure.i GetProtocol(URL.s)
    URL = LCase(Trim(URL))
    
    If Left(URL, 7) = "http://"
      ProcedureReturn #Protocol_HTTP
    ElseIf Left(URL, 8) = "https://"
      ProcedureReturn #Protocol_HTTPS
    ElseIf Left(URL, 7) = "file://"
      ProcedureReturn #Protocol_File
    ElseIf Left(URL, 6) = "ftp://"
      ProcedureReturn #Protocol_FTP
    ElseIf Left(URL, 5) = "data:"
      ProcedureReturn #Protocol_Data
    Else
      ProcedureReturn #Protocol_Unknown
    EndIf
  EndProcedure
  
  Procedure.s GetBaseDirectory(URL.s)
    Protected LastSlash.i
    
    ; Finde letzten Slash
    LastSlash = 0
    Protected i.i
    For i = 1 To Len(URL)
      If Mid(URL, i, 1) = "/"
        LastSlash = i
      EndIf
    Next
    
    If LastSlash > 0
      ProcedureReturn Left(URL, LastSlash)
    Else
      ProcedureReturn URL
    EndIf
  EndProcedure
  
  Procedure.s ResolveURL(BaseURL.s, RelativeURL.s)
    Protected Result.s
    Protected Protocol.i
    
    RelativeURL = Trim(RelativeURL)
    BaseURL = Trim(BaseURL)
    
    ; Wenn RelativeURL bereits absolut ist (hat Protokoll), direkt zurückgeben
    Protocol = GetProtocol(RelativeURL)
    If Protocol <> #Protocol_Unknown
      ProcedureReturn RelativeURL
    EndIf
    
    ; Leere BaseURL → RelativeURL ist absolut
    If BaseURL = ""
      ProcedureReturn RelativeURL
    EndIf
    
    ; Wenn RelativeURL mit / startet → absolut vom Root
    If Left(RelativeURL, 1) = "/"
      ; Extrahiere Protocol + Host aus BaseURL
      Protocol = GetProtocol(BaseURL)
      Select Protocol
        Case #Protocol_HTTP
          ; http://example.com/path/file.html → http://example.com
          Protected HostEnd.i = FindString(BaseURL, "/", 8)
          If HostEnd > 0
            Result = Left(BaseURL, HostEnd - 1) + RelativeURL
          Else
            Result = BaseURL + RelativeURL
          EndIf
          
        Case #Protocol_HTTPS
          HostEnd = FindString(BaseURL, "/", 9)
          If HostEnd > 0
            Result = Left(BaseURL, HostEnd - 1) + RelativeURL
          Else
            Result = BaseURL + RelativeURL
          EndIf
          
        Case #Protocol_File
          ; file:///path/to/file.html → file://
          Result = "file://" + RelativeURL
          
        Case #Protocol_FTP
          HostEnd = FindString(BaseURL, "/", 7)
          If HostEnd > 0
            Result = Left(BaseURL, HostEnd - 1) + RelativeURL
          Else
            Result = BaseURL + RelativeURL
          EndIf
          
        Default
          Result = RelativeURL
      EndSelect
      
      ProcedureReturn Result
    EndIf
    
    ; Relative URL → kombiniere mit BaseURL Directory
    Protected BaseDir.s = GetBaseDirectory(BaseURL)
    
    ; Handle ../ (Parent Directory)
    While Left(RelativeURL, 3) = "../"
      RelativeURL = Mid(RelativeURL, 4)
      ; Entferne letztes Directory aus BaseDir
      BaseDir = GetBaseDirectory(Left(BaseDir, Len(BaseDir) - 1))
    Wend
    
    ; Kombiniere BaseDir + RelativeURL
    If Right(BaseDir, 1) = "/"
      Result = BaseDir + RelativeURL
    Else
      Result = BaseDir + "/" + RelativeURL
    EndIf
    
    ProcedureReturn Result
  EndProcedure
  
  Procedure.s LoadResource(URL.s)
    Protected Protocol.i
    Protected Result.s
    Protected TempFile.s
    Protected File.i
    Protected FilePath.s
    
    Protocol = GetProtocol(URL)
    
    Select Protocol
      Case #Protocol_HTTP, #Protocol_HTTPS
        ; HTTP(S) Download
        TempFile = GetTemporaryDirectory() + "resource_" + Str(Random(999999)) + ".tmp"
        
        If ReceiveHTTPFile(URL, TempFile)
          File = ReadFile(#PB_Any, TempFile, #PB_UTF8)
          If File
            While Not Eof(File)
              Result + ReadString(File, #PB_UTF8) + #CRLF$
            Wend
            CloseFile(File)
          EndIf
          DeleteFile(TempFile)
        Else
          Debug "[URLResolver] HTTP-Download fehlgeschlagen: " + URL
        EndIf
        
      Case #Protocol_File
        ; Lokale Datei
        FilePath = Mid(URL, 8)  ; Entferne "file://"
        
        ; Windows: file:///C:/path → C:/path
        ; Unix: file:///path → /path
        CompilerIf #PB_OS_Windows
          If Left(FilePath, 1) = "/"
            FilePath = Mid(FilePath, 2)  ; Entferne führenden /
          EndIf
        CompilerEndIf
        
        Debug "[URLResolver] Trying to load file: '" + FilePath + "'"
        
        File = ReadFile(#PB_Any, FilePath)
        If File
          While Not Eof(File)
            Result + ReadString(File) + #CRLF$
          Wend
          CloseFile(File)
          Debug "[URLResolver] Lokale Datei geladen: " + FilePath + " (" + Str(Len(Result)) + " Zeichen)"
        Else
          Debug "[URLResolver] Lokale Datei nicht gefunden: " + FilePath
        EndIf
        
      Case #Protocol_FTP
        ; FTP Download
        ; FTP Connection benötigt: OpenFTP, ReceiveFTPFile, CloseFTP
        ; Für einfachheit: Erstelle temporäre Datei
        TempFile = GetTemporaryDirectory() + "ftp_" + Str(Random(999999)) + ".tmp"
        
        ; Öffne FTP Connection
        ; OpenFTP(#ID, Server$, Port, User$, Pass$)
        Protected FTPConnection.i = OpenFTP(#PB_Any, URL, "", "", 21)
        
        If FTPConnection
          ; Extrahiere Dateiname aus URL (nach letztem /)
          Protected FileName.s = ""
          Protected i.i
          For i = Len(URL) To 1 Step -1
            If Mid(URL, i, 1) = "/"
              FileName = Mid(URL, i + 1)
              Break
            EndIf
          Next
          
          If FileName <> ""
            If ReceiveFTPFile(FTPConnection, FileName, TempFile)
              File = ReadFile(#PB_Any, TempFile, #PB_UTF8)
              If File
                While Not Eof(File)
                  Result + ReadString(File, #PB_UTF8) + #CRLF$
                Wend
                CloseFile(File)
              EndIf
              DeleteFile(TempFile)
              Debug "[URLResolver] FTP-Download erfolgreich: " + URL
            Else
              Debug "[URLResolver] FTP-Download fehlgeschlagen: " + URL
            EndIf
          EndIf
          
          CloseFTP(FTPConnection)
        Else
          Debug "[URLResolver] FTP-Connection fehlgeschlagen: " + URL
        EndIf
        
      Case #Protocol_Data
        ; Data URL (data:text/css;base64,...)
        Protected CommaPos.i = FindString(URL, ",", 1)
        If CommaPos > 0
          Protected DataContent.s = Mid(URL, CommaPos + 1)
          
          ; Prüfe ob Base64
          If FindString(URL, ";base64,", 1) > 0
            ; Base64 dekodieren
            Protected *Buffer, BufferSize.i
            BufferSize = Len(DataContent)
            *Buffer = AllocateMemory(BufferSize)
            
            If *Buffer
              BufferSize = Base64Decoder(DataContent, *Buffer, BufferSize)
              
              If BufferSize > 0
                Result = PeekS(*Buffer, BufferSize, #PB_UTF8)
              EndIf
              
              FreeMemory(*Buffer)
            EndIf
          Else
            ; Plain text
            Result = DataContent
          EndIf
          
          Debug "[URLResolver] Data URL dekodiert (" + Str(Len(Result)) + " Zeichen)"
        EndIf
        
      Default
        Debug "[URLResolver] Unbekanntes Protokoll: " + URL
    EndSelect
    
    ProcedureReturn Result
  EndProcedure
  
EndModule
