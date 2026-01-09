; ============================================================================
; os_functions.pbi v0.0.11 - ALLE IMAGE-FORMATE
; Multi-Plattform OS-Funktionen mit vollständiger Format-Unterstützung
; ============================================================================

DeclareModule OSFunc
  
  ; === Image-Format Konstanten (plattformunabhängig) ===
  #image_png      = 0   ; PNG (verlustfrei, Alpha)
  #image_jpg      = 1   ; JPEG (verlustbehaftet, komprimiert)
  #image_bmp      = 2   ; BMP (unkomprimiert)
  #image_tiff     = 3   ; TIFF (verlustfrei, große Dateien)
  #image_jpeg2000 = 4   ; JPEG 2000 (bessere Kompression als JPEG)
  
  Declare.i LoadImageEx(Image, Filename.s)
  Declare.i CatchImageEx(Image, *MemoryAddress, MemorySize)
  Declare SaveImageEx(Image, FileName.s, ImageType.i = 0, Quality.i = 9)
  
  Declare.i Sound_Load(FileName.s)
  Declare.i Sound_Catch(*MemoryAddress, Size)
  Declare Sound_SetVolume(SoundObject, Volume.f)
  Declare.i Sound_Play(SoundObject, Loop.i = 0)
  Declare.i Sound_Stop(SoundObject)
  Declare Sound_Release(SoundObject)
  
EndDeclareModule

Module OSFunc
  
  CompilerIf #PB_Compiler_OS = #PB_OS_MacOS
    
    Debug "[OSFunc] Kompiliert für macOS - NSImageRep wird verwendet"
    
    ImportC "-framework Accelerate"
      vImageUnpremultiplyData_RGBA8888 (*src, *dest, flags) 
    EndImport
    
    Procedure.i LoadImageEx(Image, Filename.s)
      Protected.i Result, Rep, vImg.vImage_Buffer
      Protected Size.NSSize, Point.NSPoint
      
      Debug "[OSFunc::LoadImageEx] Lade Datei: " + Filename
      
      CocoaMessage(@Rep, 0, "NSImageRep imageRepWithContentsOfFile:$", @Filename)
      If Rep
        Size\width = CocoaMessage(0, Rep, "pixelsWide")
        Size\height = CocoaMessage(0, Rep, "pixelsHigh")
        
        Debug "[OSFunc::LoadImageEx] NSImageRep gefunden: " + Str(Size\width) + "x" + Str(Size\height)
        
        If Size\width And Size\height
          CocoaMessage(0, Rep, "setSize:@", @Size)
        Else
          CocoaMessage(@Size, Rep, "size")
        EndIf
        
        If Size\width And Size\height
          Result = CreateImage(Image, Size\width, Size\height, 32, #PB_Image_Transparent)
          If Result
            If Image = #PB_Any : Image = Result : EndIf
            StartDrawing(ImageOutput(Image))
            CocoaMessage(0, Rep, "drawAtPoint:@", @Point)
            
            If CocoaMessage(0, Rep, "hasAlpha")
              vImg\data = DrawingBuffer()
              vImg\width = OutputWidth()
              vImg\height = OutputHeight()
              vImg\rowBytes = DrawingBufferPitch()
              vImageUnPremultiplyData_RGBA8888(@vImg, @vImg, 0)
            EndIf
            
            StopDrawing()
            Debug "[OSFunc::LoadImageEx] Bild erfolgreich geladen: ID=" + Str(Result)
          Else
            Debug "[OSFunc::LoadImageEx] FEHLER: CreateImage fehlgeschlagen!"
          EndIf
        Else
          Debug "[OSFunc::LoadImageEx] FEHLER: Ungültige Bildgröße!"
        EndIf
      Else
        Debug "[OSFunc::LoadImageEx] FEHLER: NSImageRep konnte nicht erstellt werden!"
      EndIf
      
      ProcedureReturn Result
    EndProcedure
    
    Procedure.i CatchImageEx(Image, *MemoryAddress, MemorySize)
      Protected.i Result, DataObj, Class, Rep, vImg.vImage_Buffer
      Protected Size.NSSize, Point.NSPoint
      
      Debug "[OSFunc::CatchImageEx] Lade Bild aus Speicher, Größe: " + Str(MemorySize) + " Bytes"
      
      CocoaMessage(@DataObj, 0, "NSData dataWithBytesNoCopy:", *MemoryAddress, "length:", MemorySize, "freeWhenDone:", #NO)
      
      If DataObj
        Debug "[OSFunc::CatchImageEx] NSData erstellt"
        CocoaMessage(@Class, 0, "NSImageRep imageRepClassForData:", DataObj)
        
        If Class
          Debug "[OSFunc::CatchImageEx] NSImageRep-Klasse gefunden"
          CocoaMessage(@Rep, Class, "imageRepWithData:", DataObj)
          
          If Rep
            Size\width = CocoaMessage(0, Rep, "pixelsWide")
            Size\height = CocoaMessage(0, Rep, "pixelsHigh")
            
            Debug "[OSFunc::CatchImageEx] NSImageRep erstellt: " + Str(Size\width) + "x" + Str(Size\height)
            
            If Size\width And Size\height
              CocoaMessage(0, Rep, "setSize:@", @Size)
            Else
              CocoaMessage(@Size, Rep, "size")
            EndIf
            
            If Size\width And Size\height
              Result = CreateImage(Image, Size\width, Size\height, 32, #PB_Image_Transparent)
              If Result
                If Image = #PB_Any : Image = Result : EndIf
                StartDrawing(ImageOutput(Image))
                CocoaMessage(0, Rep, "drawAtPoint:@", @Point)
                
                If CocoaMessage(0, Rep, "hasAlpha")
                  vImg\data = DrawingBuffer()
                  vImg\width = OutputWidth()
                  vImg\height = OutputHeight()
                  vImg\rowBytes = DrawingBufferPitch()
                  vImageUnPremultiplyData_RGBA8888(@vImg, @vImg, 0)
                EndIf
                
                StopDrawing()
                Debug "[OSFunc::CatchImageEx] Bild erfolgreich aus Speicher geladen: ID=" + Str(Result)
              Else
                Debug "[OSFunc::CatchImageEx] FEHLER: CreateImage fehlgeschlagen!"
              EndIf
            Else
              Debug "[OSFunc::CatchImageEx] FEHLER: Ungültige Bildgröße!"
            EndIf
          Else
            Debug "[OSFunc::CatchImageEx] FEHLER: imageRepWithData fehlgeschlagen!"
          EndIf
        Else
          Debug "[OSFunc::CatchImageEx] FEHLER: Keine ImageRep-Klasse für diese Daten!"
        EndIf
      Else
        Debug "[OSFunc::CatchImageEx] FEHLER: NSData konnte nicht erstellt werden!"
      EndIf
      
      ProcedureReturn Result
    EndProcedure
    
    Procedure.i SaveImageEx(Image, FileName.s, ImageType.i = 0, Quality.i = 9)
      ; === macOS NSBitmapImageFileType Konstanten ===
      ; NSTIFFFileType = 0
      ; NSBMPFileType = 1
      ; NSGIFFileType = 2  (NICHT UNTERSTÜTZT - GIF ist Read-Only)
      ; NSJPEGFileType = 3
      ; NSPNGFileType = 4
      ; NSJPEG2000FileType = 5
      
      Protected Type.i
      Protected FormatName.s
      Protected ok = #False
      
      Select ImageType
        Case #image_png
          Type = 4  ; NSPNGFileType
          FormatName = "PNG"
          
        Case #image_jpg
          Type = 3  ; NSJPEGFileType
          FormatName = "JPEG"
          
        Case #image_bmp
          Type = 1  ; NSBMPFileType
          FormatName = "BMP"
          
        Case #image_tiff
          Type = 0  ; NSTIFFFileType
          FormatName = "TIFF"
          
        Case #image_jpeg2000
          Type = 5  ; NSJPEG2000FileType
          FormatName = "JPEG 2000"
          
        Default
          Type = 4  ; Default: PNG
          FormatName = "PNG (Default)"
      EndSelect
      
      Debug "[OSFunc::SaveImageEx] Speichere als " + FormatName + ": " + FileName
      Debug "[OSFunc::SaveImageEx] NSBitmapImageFileType = " + Str(Type)
      
      Protected Compression.f = Quality / 10.0
      If Compression < 0.0 : Compression = 0.0 : EndIf
      If Compression > 1.0 : Compression = 1.0 : EndIf
      
      Protected c.i = CocoaMessage(0, 0, "NSNumber numberWithFloat:@", @Compression)
      Protected p.i = CocoaMessage(0, 0, "NSDictionary dictionaryWithObject:", c, "forKey:$", @"NSImageCompressionFactor")
      Protected imageReps.i = CocoaMessage(0, ImageID(Image), "representations")
      Protected imageData.i = CocoaMessage(0, 0, "NSBitmapImageRep representationOfImageRepsInArray:", imageReps, "usingType:", Type, "properties:", p)
      
      If imageData
        CocoaMessage(0, imageData, "writeToFile:$", @FileName, "atomically:", #NO)
        Debug "[OSFunc::SaveImageEx] Bild erfolgreich gespeichert"
        ok = #True
      Else
        Debug "[OSFunc::SaveImageEx] FEHLER: Konnte Bilddaten nicht erstellen!"
      EndIf
      
      ProcedureReturn ok
    EndProcedure
    
    Procedure.i Sound_Load(FileName.s)
      ProcedureReturn CocoaMessage(0, CocoaMessage(0, 0, "NSSound alloc"), "initWithContentsOfFile:$", @FileName, "byReference:", #YES)
    EndProcedure
    
    Procedure.i Sound_Catch(*MemoryAddress, Size)
      Protected Result.i = CocoaMessage(0, 0, "NSData dataWithBytes:", *MemoryAddress, "length:", Size)
      If Result
        Result = CocoaMessage(0, CocoaMessage(0, 0, "NSSound alloc"), "initWithData:", Result)
      EndIf
      ProcedureReturn Result
    EndProcedure
    
    Procedure Sound_SetVolume(SoundObject, Volume.f)
      CocoaMessage(0, SoundObject, "setVolume:@", @Volume)
    EndProcedure
    
    Procedure.i Sound_Play(SoundObject, Loop.i = 0)
      Protected currentTime.d
      CocoaMessage(0, SoundObject, "setLoops:", Loop)
      CocoaMessage(0, SoundObject, "setCurrentTime:@", @currentTime)
      ProcedureReturn CocoaMessage(0, SoundObject, "play")
    EndProcedure
    
    Procedure.i Sound_Stop(SoundObject)
      ProcedureReturn CocoaMessage(0, SoundObject, "stop")
    EndProcedure
    
    Procedure Sound_Release(SoundObject)
      CocoaMessage(0, SoundObject, "release")
    EndProcedure
    
  CompilerElse
    
    Debug "[OSFunc] Kompiliert für Windows/Linux - Standard PureBasic Image-Funktionen"
    
    ; === Image-Decoder aktivieren ===
    UseJPEGImageDecoder()
    UsePNGImageDecoder()
    UseTIFFImageDecoder()
    UseBMPImageDecoder()
    ; GIF wird NICHT aktiviert (nativ in PureBasic)
    
    ; JPEG2000 ist oft nicht verfügbar
    CompilerIf Defined(UseJPEG2000ImageDecoder, #PB_Procedure)
      UseJPEG2000ImageDecoder()
      Debug "[OSFunc] JPEG2000 Decoder verfügbar"
    CompilerElse
      Debug "[OSFunc] JPEG2000 Decoder NICHT verfügbar"
    CompilerEndIf
    
    Procedure.i LoadImageEx(Image, Filename.s)
      Debug "[OSFunc::LoadImageEx] Lade Datei: " + Filename
      Protected Result.i = LoadImage(Image, Filename)
      If Result
        Debug "[OSFunc::LoadImageEx] Bild geladen: ID=" + Str(Result)
      Else
        Debug "[OSFunc::LoadImageEx] FEHLER: LoadImage fehlgeschlagen!"
      EndIf
      ProcedureReturn Result
    EndProcedure
    
    Procedure.i CatchImageEx(Image, *MemoryAddress, MemorySize)
      Debug "[OSFunc::CatchImageEx] Lade Bild aus Speicher, Größe: " + Str(MemorySize) + " Bytes"
      Protected Result.i = CatchImage(Image, *MemoryAddress, MemorySize)
      If Result
        Debug "[OSFunc::CatchImageEx] Bild geladen: ID=" + Str(Result) + ", " + Str(ImageWidth(Result)) + "x" + Str(ImageHeight(Result))
      Else
        Debug "[OSFunc::CatchImageEx] FEHLER: CatchImage fehlgeschlagen!"
      EndIf
      ProcedureReturn Result
    EndProcedure
    
    Procedure SaveImageEx(Image, FileName.s, ImageType.i = 0, Quality.i = 9)
      Protected FormatName.s
      
      Select ImageType
        Case #image_png
          FormatName = "PNG"
          SaveImage(Image, FileName, #PB_ImagePlugin_PNG)
          
        Case #image_jpg
          FormatName = "JPEG"
          SaveImage(Image, FileName, #PB_ImagePlugin_JPEG, Quality)
          
        Case #image_bmp
          FormatName = "BMP"
          SaveImage(Image, FileName, #PB_ImagePlugin_BMP)
          
        Case #image_tiff
          FormatName = "TIFF"
          CompilerIf Defined(#PB_ImagePlugin_TIFF, #PB_Constant)
            SaveImage(Image, FileName, #PB_ImagePlugin_TIFF)
          CompilerElse
            Debug "[OSFunc::SaveImageEx] WARNUNG: TIFF nicht verfügbar, speichere als PNG"
            SaveImage(Image, FileName, #PB_ImagePlugin_PNG)
          CompilerEndIf
          
        Case #image_jpeg2000
          FormatName = "JPEG 2000"
          CompilerIf Defined(#PB_ImagePlugin_JPEG2000, #PB_Constant)
            SaveImage(Image, FileName, #PB_ImagePlugin_JPEG2000, Quality)
          CompilerElse
            Debug "[OSFunc::SaveImageEx] WARNUNG: JPEG2000 nicht verfügbar, speichere als JPEG"
            SaveImage(Image, FileName, #PB_ImagePlugin_JPEG, Quality)
          CompilerEndIf
          
        Default
          FormatName = "PNG (Default)"
          SaveImage(Image, FileName, #PB_ImagePlugin_PNG)
      EndSelect
      
      Debug "[OSFunc::SaveImageEx] Gespeichert als " + FormatName + ": " + FileName
    EndProcedure
    
    Procedure.i Sound_Load(FileName.s)
      ProcedureReturn LoadSound(#PB_Any, FileName)
    EndProcedure
    
    Procedure.i Sound_Catch(*MemoryAddress, Size)
      ProcedureReturn CatchSound(#PB_Any, *MemoryAddress, Size)
    EndProcedure
    
    Procedure Sound_SetVolume(SoundObject, Volume.f)
      SetSoundVolume(SoundObject, Val(Str(Volume * 100)))
    EndProcedure
    
    Procedure.i Sound_Play(SoundObject, Loop.i = 0)
      ProcedureReturn PlaySound(SoundObject, #PB_Sound_Loop * Bool(Loop))
    EndProcedure
    
    Procedure.i Sound_Stop(SoundObject)
      StopSound(SoundObject)
      ProcedureReturn #True
    EndProcedure
    
    Procedure Sound_Release(SoundObject)
      FreeSound(SoundObject)
    EndProcedure
    
  CompilerEndIf
  
EndModule
; IDE Options = PureBasic 6.21 - C Backend (MacOS X - arm64)
; CursorPosition = 202
; FirstLine = 189
; Folding = -----
; EnableXP
; DPIAware