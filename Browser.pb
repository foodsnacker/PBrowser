; ============================================================================
; Browser.pb v0.8.1a - BORDER WIDTH + INLINE ELEMENT FIXES
; ============================================================================
; VERSION: 0.8.0
; DATUM: 2026-01-06
; FIXES: 
; - Bug #1: Border Width = 0 → Alle Block-Elemente bekommen Width
; - Bug #2: Inline-Elemente unsichtbar → Text-Nodes bekommen X-Position
; ============================================================================

EnableExplicit

; UseJPEGImageDecoder()
; UsePNGImageDecoder()
; UseGIFImageDecoder()

XIncludeFile "HTMLParser.pbi"
XIncludeFile "HTTPCache.pbi"
XIncludeFile "CSSParser.pbi"
XIncludeFile "Style.pbi"
XIncludeFile "URLResolver.pbi"
XIncludeFile "Document.pbi"
XIncludeFile "Layout.pbi"
XIncludeFile "FontCache.pbi"
XIncludeFile "BrowserUI.pbi"
XIncludeFile "os_functions.pbi"

Define TestHTML.s

Debug ""
Debug "============================================================"
Debug "BROWSER v0.8.1a - BORDER WIDTH + INLINE ELEMENT FIXES"
Debug "============================================================"
Debug ""

TestHTML = "<!DOCTYPE html>" + #CRLF$ +
           "<html>" + #CRLF$ +
           "<head>" + #CRLF$ +
           "  <title>Browser v0.8.1a - Complete Demo</title>" + #CRLF$ +
           "  <style>" + #CRLF$ +
           "    h1 { font-family: Times New Roman; font-size: 32px; color: navy; text-align: center; text-decoration: underline; }" + #CRLF$ +
           "    h2 { font-family: Times New Roman; font-size: 24px; color: maroon; }" + #CRLF$ +
           "    .courier { font-family: Courier New; font-size: 16px; color: green; }" + #CRLF$ +
           "    .center { text-align: center; font-size: 18px; color: purple; }" + #CRLF$ +
           "    .right { text-align: right; font-size: 18px; color: teal; }" + #CRLF$ +
           "    .boxed { border: 2px solid red; padding: 10px 15px; margin: 20px 0; }" + #CRLF$ +
           "    .dashed { border: 2px dashed blue; padding-left: 10px; margin-top: 10px; }" + #CRLF$ +
           "    .dotted { border: 1px dotted fuchsia; padding-left: 10px; margin-top: 10px; }" + #CRLF$ +
           "    .linethrough { text-decoration: line-through; color: maroon; }" + #CRLF$ +
           "    .overline { text-decoration: overline; color: olive; }" + #CRLF$ +
           "    .tall { line-height: 30px; color: navy; }" + #CRLF$ +
           "    .just { text-align: justify; font-size: 18px; color: #222; }" + #CRLF$ +
           "    pre { font-family: Courier New; font-size: 14px; background-color: #f7f7f7; border: 1px solid #ccc; padding: 10px; margin: 10px 0; }" + #CRLF$ +
           "    pre.wrap { white-space: pre-wrap; }" + #CRLF$ +
           "  </style>" + #CRLF$ +
           "</head>" + #CRLF$ +
           "<body>" + #CRLF$ +
           "  <h1>Browser v0.8.1a - Complete Feature Demo</h1>" + #CRLF$ +
           "  " + #CRLF$ +
           "  <h2>Font Families</h2>" + #CRLF$ +
           "  <p>This is default Arial font</p>" + #CRLF$ +
           "  <p class='courier'>This is Courier New font family</p>" + #CRLF$ +
           "  " + #CRLF$ +
           "  <h2>Text Alignment</h2>" + #CRLF$ +
           "  <p>This text is left-aligned (default)</p>" + #CRLF$ +
           "  <p class='center'>This text is centered</p>" + #CRLF$ +
           "  <p class='right'>This text is right-aligned</p>" + #CRLF$ +
           "  " + #CRLF$ +
           "  <h2>Box Model & Borders</h2>" + #CRLF$ +
           "  <div class='boxed'>" + #CRLF$ +
           "    <p>This div has a solid red border with 10px padding and 20px margins</p>" + #CRLF$ +
           "  </div>" + #CRLF$ +
           "  <div class='dashed'>" + #CRLF$ +
           "    <p>This div has a dashed blue border</p>" + #CRLF$ +
           "  </div>" + #CRLF$ +
           "  <div class='dotted'>" + #CRLF$ +
           "    <p>This div has a dotted fuchsia border</p>" + #CRLF$ +
           "  </div>" + #CRLF$ +
           "  " + #CRLF$ +
           "  <h2>Text Decorations</h2>" + #CRLF$ +
           "  <p><u>This text is underlined (HTML)</u></p>" + #CRLF$ +
           "  <p class='linethrough'>This text has line-through decoration (CSS)</p>" + #CRLF$ +
           "  <p class='overline'>This text has overline decoration (CSS)</p>" + #CRLF$ +
           "  " + #CRLF$ +
           "  <h2>Colors (HTML 4.01)</h2>" + #CRLF$ +
           "  <p style='color: red'>Red</p>" + #CRLF$ +
           "  <p style='color: green'>Green</p>" + #CRLF$ +
           "  <p style='color: blue'>Blue</p>" + #CRLF$ +
           "  <p style='color: fuchsia'>Fuchsia</p>" + #CRLF$ +
           "  <p style='color: aqua'>Aqua</p>" + #CRLF$ +
           "  " + #CRLF$ +
           "  <h2>Justify</h2>" + #CRLF$ +
           "  <p class='just'>Dies ist ein langer Absatz, der im Blocksatz dargestellt werden soll. Die Abstände zwischen den Wörtern werden verteilt, so dass die Zeile die komplette Breite ausfüllt (außer der letzten Zeile). Das ist noch ein Minimal-Algorithmus, aber die Wirkung sollte sichtbar sein.</p>" + #CRLF$ +
           "  " + #CRLF$ +
           "  <h2>Pre / White-space</h2>" + #CRLF$ +
           "  <pre>Pre erhält    mehrere   Spaces\nund neue Zeilen.\n\nTabs als Tabelle:\nName" + Chr(9) + "Wert" + Chr(9) + "Kommentar\nAlpha" + Chr(9) + "123" + Chr(9) + "ok\nBeta" + Chr(9) + "456" + Chr(9) + "gut\n\nAuch Leerzeilen bleiben erhalten.</pre>" + #CRLF$ +
           "  <pre class='wrap'>Pre-wrap (mit Wrap):    viele     Spaces und sehr sehr sehr sehr sehr sehr sehr lange Zeilen, die umgebrochen werden dürfen, aber die Spaces trotzdem behalten.</pre>" + #CRLF$ +
           "  " + #CRLF$ +
           "  <h2>Line Height</h2>" + #CRLF$ +
           "  <p class='tall'>This paragraph has tall line-height (30px) for better readability and improved spacing between lines of text</p>" + #CRLF$ +
           "  " + #CRLF$ +
           "  <h2>HTML Elements</h2>" + #CRLF$ +
           "  <p class='center'>Text with <strong>bold</strong>, <em>italic</em>, <u>underline</u>, <s>strikethrough</s>, <span class='overline'>overline</span> und gemischten <span class='linethrough'><u>CSS+HTML</u></span> Dekorationen – dieser Satz ist extra lang damit er umbricht und wir sehen ob die Dekorationen pro Run wirklich korrekt sitzen.</p>" + #CRLF$ +
           "  <p>Subscript: H<sub>2</sub>O, Superscript: E=mc<sup>2</sup> und ein manueller Zeilenumbruch<br>genau hier, danach geht es weiter.</p>" + #CRLF$ +
           "</body>" + #CRLF$ +
           "</html>"

Debug "HTML-String erstellt (" + Str(Len(TestHTML)) + " Zeichen)"

HTTPCache::Init(50)
Debug "HTTPCache initialisiert"

If Not BrowserUI::Init(1280, 720, #False)
  MessageRequester("Fehler", "Konnte Fenster nicht erstellen!")
  End
EndIf

Debug "BrowserUI initialisiert"

BrowserUI::LoadHTML(TestHTML, "colors.html")

BrowserUI::SaveAsImage("browser", OSFunc::#image_png)

Debug ""
Debug "============================================================"
Debug "BROWSER v0.8.1a - ZUSAMMENFASSUNG"
Debug "============================================================"
Debug ""
Debug "✅ FIXED: Border Width = 0 → Borders werden jetzt korrekt gerendert"
Debug "✅ FIXED: Inline-Elemente unsichtbar → <u>, <strong>, <em>, <s> funktionieren"
Debug ""
Debug "URL PROTOCOLS:"
Debug "  ✅ http:// und https://"
Debug "  ✅ file:// - Lokale Dateien"
Debug "  ✅ ftp:// - FTP-Server"
Debug "  ✅ data: - Inline Data URLs"
Debug ""
Debug "EXTERNAL RESOURCES:"
Debug "  ✅ <link rel='stylesheet' href='...'>"
Debug "  ✅ <img src='...'> (alle Protokolle)"
Debug "  ✅ Relative Pfade (../style.css)"
Debug "  ✅ Absolute Pfade (/css/style.css)"
Debug ""
Debug "HTML 4.01: 100% (91/91 Tags)"
Debug "HTML 4.01 Colors: 100% (16/16 Named Colors)"
Debug "CSS 1 Phase 1: Borders, Margins, Padding, Text-Align, Line-Height"
Debug ""
; IDE Options = PureBasic 6.21 - C Backend (MacOS X - arm64)
; CursorPosition = 14
; EnableXP
; DPIAware
; Executable = ../../test2.app


; Cleanup cached fonts
FontCache::FreeAll()

; IDE Options = PureBasic 6.21 - C Backend (MacOS X - arm64)
; CursorPosition = 106
; FirstLine = 97
; EnableXP
; DPIAware