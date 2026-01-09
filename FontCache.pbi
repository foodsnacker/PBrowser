; ============================================================================
; FontCache.pbi v0.8.1a
; ----------------------------------------------------------------------------
; Zentrales Font-Caching für das Projekt.
; WICHTIG:
;   - LoadFont() darf NICHT innerhalb eines aktiven StartDrawing() aufgerufen werden.
;   - Daher: Fonts vor StartDrawing() preloaden (allowLoad=#True),
;            beim Rendern nur noch allowLoad=#False verwenden.
; ----------------------------------------------------------------------------
; API:
;   FontCache::GetFont(family, size, style, allowLoad)
;   FontCache::FreeAll()
; ============================================================================

DeclareModule FontCache
  Declare Init()
  Declare FreeAll()
  Declare.i GetFont(Family.s, Size.i, Style.i, allowLoad.i = #True)
EndDeclareModule

Module FontCache

  Global NewMap gFont.i()

  Procedure Init()
    ; nothing required
  EndProcedure

  Procedure.s NormalizeFamily(Family.s)
    Family = Trim(Family)
    If Family = ""
      Family = "Arial"
    EndIf
    ProcedureReturn Family
  EndProcedure

  Procedure.s MakeKey(Family.s, Size.i, Style.i)
    ProcedureReturn LCase(NormalizeFamily(Family)) + "|" + Str(Size) + "|" + Str(Style)
  EndProcedure

  Procedure FreeAll()
    ForEach gFont()
      If gFont()
        FreeFont(gFont())
      EndIf
    Next
    ClearMap(gFont())
  EndProcedure

  Procedure.i GetFont(Family.s, Size.i, Style.i, allowLoad.i = #True)
    Protected key.s = MakeKey(Family, Size, Style)

    If FindMapElement(gFont(), key)
      ProcedureReturn gFont()
    EndIf

    If allowLoad
      Protected fam.s = NormalizeFamily(Family)
      Protected f.i = LoadFont(#PB_Any, fam, Size, Style)
      If f
        gFont(key) = f
      EndIf
      ProcedureReturn f
    EndIf

    ProcedureReturn 0
  EndProcedure

EndModule
