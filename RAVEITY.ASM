		.386
		jumps
		locals


SCROLL_OFF      EQU 30720       ; Scroller offset, rad 96

SOUNDCHECKER    EQU 64*8

D               EQU 48
LENSMINX        EQU 1
LENSMAXX        EQU 320
LENSMINY        EQU 1
LENSMAXY        EQU 200

CHARS_SEG       EQU 0F000h
CHARS_OFF       EQU 0FA6Eh

IPS             =       50


Code16          segment public use16
		assume cs:Code16, ds:Code16


;≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤
; Main.
;ƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒ
Start:          mov     ax,cs
		mov     ds,ax
		
		mov     ax,Music
		mov     es,ax
		call    InitPlayer

		; Setup virtual screen:
		mov     ax, cs
		add     ax, 1001h
		mov     virtualscr, ax
		mov     es, ax
		xor     eax, eax
		xor     edi, edi
		mov     cx, 16000
		rep     stosd
		
;€€€€€€€€€€€€€€€€€€€€ Start code here 

	mov     ax, 13h         ;Set mode:
	int     10h

	call    SetPalette
	call    LoadCharset
	call    SetupLensCheck

	; €€€€€ Draw the boundarylines:
	mov     DrawLineMinX, 0
	mov     DrawLineMaxX, 320
	mov     DrawLineMinY, 95
	mov     DrawLineColor, 126
	call    DrawHorizLine
	add     DrawLineMinY, 9
	call    DrawHorizLine
	mov     DrawLineMinY, 19
	call    DrawHorizLine
	add     DrawLineMinY, 63
	call    DrawHorizLine
	mov     DrawLineMinY, 117
	call    DrawHorizLine
	add     DrawLineMinY, 64
	call    DrawHorizLine

	; €€€€€€ Draw the background: (This code REALLY stinx)
	push    es

	mov     ax, virtualscr
	mov     es, ax
	xor     di, di
	lea     si, BackgroundColors
	mov     dx, 720  ;((19*320)/4)/2, the first 18 lines in two dwords
@DoFirstBackground:
	mov     cx, 2
	rep     movsd
	lea     si, BackgroundColors
	dec     dx
	jnz     @DoFirstBackground
	mov     dx, 40
@DoFirstAdd:
	lea     si, BackgroundColors
	add     si, 8
	mov     cx, 2
	rep     movsd
	dec     dx
	jnz     @DoFirstAdd
	
	mov     di, 320*83
	mov     dx, 40
@DoSecondPre:
	lea     si, BackgroundColors
	add     si, 8
	mov     cx, 2
	rep     movsd
	dec     dx
	jnz     @DoSecondPre
	mov     dx, 400         ; 320*10/4/2
	;mov     di, 320*84
@DoSecondBackground:
	lea     si, BackgroundColors
	mov     cx, 2
	rep     movsd
	dec     dx
	jnz     @DoSecondBackground
	mov     dx, 40
@DoSecondAdd:
	lea     si, BackgroundColors
	add     si, 8
	mov     cx, 2
	rep     movsd
	dec     dx
	jnz     @DoSecondAdd

	mov     di, 320*105
	mov     dx, 40
@DoThirdPre:
	lea     si, BackgroundColors
	add     si, 8
	mov     cx, 2
	rep     movsd
	dec     dx
	jnz     @DoThirdPre
	mov     dx, 400         ; 320*10/4/2
@DoThirdBackground:
	lea     si, BackgroundColors
	mov     cx, 2
	rep     movsd
	dec     dx
	jnz     @DoThirdBackground
	mov     dx, 40
@DoThirdAdd:
	lea     si, BackgroundColors
	add     si, 8
	mov     cx, 2
	rep     movsd
	dec     dx
	jnz     @DoThirdAdd
	
	mov     di, 320*182
	mov     dx, 40
@DoFourthPre:
	lea     si, BackgroundColors
	add     si, 8
	mov     cx, 2
	rep     movsd
	dec     dx
	jnz     @DoFourthPre
	mov     dx, 760         ; 320*19/4/2
@DoFourthBackground:
	lea     si, BackgroundColors
	mov     cx, 2
	rep     movsd
	dec     dx
	jnz     @DoFourthBackground

	pop     es

	call    DoLens
	
Again:
	call    PlotHot
	call    DoSoundThing
	mov     cx, 64*32

	xor     bx, bx
@Again:
	mov     al, [Flames + bx + 1]
	mov     ah, [Flames + bx - 1]
	mov     dl, [Flames + bx + 32]
	mov     dh, [Flames + bx]

	add     al, ah
	add     dl, dh
	add     al, dl
	shr     al, 2
	
	mov     [NewFlames + bx + 32], al
	inc     bx
	loop    @Again

	call    EraseLens

	cmp     LensX, LENSMINX
	jl      ChangeLensX
	cmp     LensX, LENSMAXX-D
	jl      NoChangeLensX
ChangeLensX:
	neg     LensXAdd
NoChangeLensX:
	cmp     LensY, LENSMINY
	jl      ChangeLensY
	cmp     Lensy, LENSMAXY-D
	jl      NoChangeLensY
ChangeLensY:
	neg     LensYAdd
NoChangeLensY:
	mov     ax, LensYAdd
	add     LensY, ax
	mov     ax, LensXAdd
	add     LensX, ax
	
	call    PlayMusic
	call    CpyAll
	call    DoScroller
	call    DoLens
	call    Wvsync
	call    ShowVirtualScreen
	
	in      al,60h
	cmp     al,1
	je      Quit            ; Wait until the user have pressed ESC
	jmp     Again

CpyAll:
	mov     ax, ds
	mov     es, ax

	mov     cx, (64*32)/4
	lea     si, NewFlames
	lea     di, Flames
	rep     movsd
	
	mov     ax, virtualscr
	mov     es, ax
	mov     dx, 7
	mov     ax, 320*20-20
@PlotAlot:
	add     ax, 40
	lea     si,Flames
	add     si, 64
	mov     di,ax
	mov     bx,62

@plot_it:
	mov     cx,32/4
	rep     movsd
	add     di,320-32
	dec     bx
	jnz     @plot_it                    ; Plot the flames
	dec     dx
	jnz     @PlotAlot

	mov     dx, 7
	mov     ax, 320*180-20
@PlotAlot2:
	add     ax, 40
	lea     si, Flames
	add     si, 64
	mov     di, ax
	mov     bx, 62

@plot_it2:
	mov     cx, 32/4
	rep     movsd
	sub     di, 320+32
	dec     bx
	jnz     @plot_it2                   ; Plot the flames
	dec     dx
	jnz     @PlotAlot2

	ret

Quit:
	mov     ax, 03h         ;Back to text mode:
	int     10h
	
;€€€€€€€€€€€€€€€€€€€€ End code here
	; stop tune
		;mov     ax, SavedES
		;mov     es, ax
		;mov     ax, SavedDS
		;mov     ds, ax
		;mov     ax, SavedCS
		;mov     cs, ax

		;call    ResetInt
		call    EndPlayer
;INT 21 - DOS - PRINT STRING
;        AH = 09h
;        DS:DX = address of string terminated by "$"
	lea     dx, EndString
	mov     ah, 09h
	int     21h
		
		mov     ax,4c00h
		int     21h

PlotHot:
	push    es
	mov     ax, cs
	mov     es, ax

	mov     bx, [BXSV]
	inc     bx
	cmp     bx, 450
	jb      NoChng
	mov     bx, 280
NoChng:
	mov     [BXSV], bx
	
	mov     cx, 10
HotAgain:
	push    bx
	mov     dh, es:[bx]

	mov     bl, dh
	
	shr     bx, 4
	add     bx, bx
	shr     bx, 1
	sub     bx, 5
	mov     [Flames + bx], 150

	pop     bx
	inc     bx
	loop    HotAgain
	pop     es
	ret

Wvsync:
	mov  dx,03dah
@bettan:
	in   al,dx
	test al,8
	je   @bettan
@bettan2:
	in   al,dx
	test al,8
	jne  @bettan2                    ; Wait for vertical retrace
	ret

;€€ Sets The Palette:
SetPalette:
       mov  dx,03c8h            ; Set up palette,  black -> red
       xor  al,al
       out  dx,al
       inc  dx
       mov  cx,8
@set_red:
       mov  al,16               ; Some stupid comments
       sub  al,cl
       shl  al,3                ; Multiply al with 4
       out  dx,al               
       xor  al,al               ; Xor al with al
       out  dx,al
       out  dx,al
       loop @set_red            ; Loop this 16 times  (nah...no more stupid comments)

       mov  cx,16               ; Set red -> yellow 
@set_yellow:
       mov  al,60
       out  dx,al
       mov  al,16
       sub  al,cl
       shl  al,2
       out  dx,al
       xor  al,al
       out  dx,al
       loop @set_yellow

       mov  cx,16               ; set yellow -> white
@set_white:
       mov  al,60
       out  dx,al
       out  dx,al
       mov  al,16
       sub  al,cl
       shl  al,2
       out  dx,al
       loop @set_white

       mov  cx,0Fh              ; Set remaing colors to white
       mov  al,63
@whithey:
       out  dx,al
       out  dx,al
       out  dx,al
       loop @whithey

       ;€€€€€€€€€ New palette start:
       mov  al, 128
       mov  dx, 03C8h
       out  dx, al
       inc  dx
       mov  cx,8
@@set_red:
       xor  al,al               ; Xor al with al
       out  dx,al
       out  dx,al
       mov  al,16               ; Some stupid comments
       sub  al,cl
       shl  al,3                ; Multiply al with 4
       out  dx,al               
       loop @@set_red            ; Loop this 16 times  (nah...no more stupid comments)

       mov  cx,16               ; Set red -> yellow 
@@set_yellow:
       xor  al,al
       out  dx,al

       mov  al,16
       sub  al,cl
       shl  al,2
       out  dx,al

       mov  al,60
       out  dx,al

       loop @@set_yellow

       mov  cx,16               ; set yellow -> white
@@set_white:
       mov  al,60
       out  dx,al
       out  dx,al
       mov  al,16
       sub  al,cl
       shl  al,2
       out  dx,al
       loop @@set_white

       mov  cx,0Fh              ; Set remaing colors to white
       mov  al,63
@@whithey:
       out  dx,al
       out  dx,al
       out  dx,al
       loop @@whithey

       mov  bx, 122
       xor  cx, cx

@DoAnd:
       mov  dx, 03C8h           ; Write reg 125
       mov  ax, bx
       out  dx, al

       inc  dx

       mov  ax, cx
       shl  al, 3
       out  dx, al
       shr  al, 1
       out  dx, al
       shl  al, 1
       out  dx, al

       mov  dx, 03C8h
       mov  ax, bx
       add  ax, 128
       out  dx, al

       inc  dx
       mov  ax, cx
       shl  al, 3
       out  dx, al
       shr  al, 1
       out  dx, al
       shl  al, 2
       cmp  al, 63
       jb   NoLowerColor
       mov  al, 63
NoLowerColor:
       out  dx, al

       inc  bx
       inc  cx
       cmp  cx, 5
       jne  @DoAnd

       mov  dx, 03C8h
       mov  al, 81
       out  dx, al

       inc  dx
       mov  al, 48
       out  dx, al
       mov  al, 32
       out  dx, al
       mov  al, 63
       out  dx, al

       mov  dx, 03C7h           ; Read 81
       mov  al, 81
       out  dx, al

       mov  dx, 03C9h
       in   al, dx
       mov  SavedRed, al
       in   al, dx
       mov  SavedGreen, al
       in   al, dx
       mov  SavedBlue, al

       mov  dx, 03C8h           ; Write reg (81 + 128) = 209
       mov  al, 209
       out  dx, al

       inc  dx
       mov  al, SavedRed
       out  dx, al
       mov  al, SavedGreen
       out  dx, al
       mov  al, SavedBlue
       shl  al, 1
       cmp  al, 63
       jb   NoChange209Color
       mov  al, 63
NoChange209Color:
       out  dx, al

       ;€€€€€€€€€ New Palette end

       ret

;€€ End SetPalette

;************************************************************************
;       This proc handles the scroller
;************************************************************************
PROC    DoScroller      NEAR
	push    ax 
	push    bx 
	push    cx 
	push    dx 
	push    es 
	push    ds 
	push    si 
	push    di
	push    bp

	push    ds
	mov     ax, virtualscr 
	mov     es, ax
	mov     ds, ax
	mov     di, SCROLL_OFF
	mov     si, SCROLL_OFF + 1
	;mov     si, SCROLL_OFF + 4
	mov     dx, 8
DoLineAgain:
	mov     cx, 316/4
	rep movsd
	mov     cx, 3
	;sub     si, 3
	rep     movsb
	inc     di
	inc     si
	dec     dx
	jnz     DoLineAgain
	pop     ds                      ; Reload DS
	xor     ax, ax
	; Draw line:
	lea     bx, ScrollerText
	mov     al, ScrollerLetter
	add     bx, ax
	mov     al, ds:[bx]
	cmp     al, 0
	jne     NoResetLetter
	mov     ScrollerLetter, 0
	mov     ScrollerRow, 0
	jmp     NotResetRow
NoResetLetter:
	mov     dl, 64
	mul     dl
	lea     bx, CharBuffer
	add     bx, ax
	xor     ax, ax
	mov     al, ScrollerRow
	add     bx, ax
	mov     di, SCROLL_OFF + 319
	mov     cx, 8
ContDrawLine:
	mov     al, ds:[bx]
	mov     es:[di], al
	add     bx, 8
	add     di, 320
	loop    ContDrawLine
	inc     ScrollerRow
	cmp     ScrollerRow, 8
	jne     NotResetRow
	inc     ScrollerLetter
	mov     ScrollerRow, 0
NotResetRow:
	pop     bp
	pop     di 
	pop     si 
	pop     ds 
	pop     es 
	pop     dx 
	pop     cx
	pop     bx 
	pop     ax
	ret
ENDP    DoScroller

PROC    DoLens          NEAR
	push    ax 
	push    bx 
	push    cx 
	push    dx 
	push    si 
	push    di 
	push    bp 
	push    es 
	push    ds
	
	;       Save background:
	xor     dx, dx                  ; Calculate OFFSET
	mov     ax, LensY
	mov     dh, al
	shl     ax, 6
	add     ax, dx
	add     ax, LensX
	push    ax                      ; Save Offset for later
	
	mov     si, ax                  ; SI->OFFSET

	mov     ax, ds                  ; ES->DATA
	mov     es, ax

	mov     ax, virtualscr
	mov     ds, ax                  ; DS->SCREEN

	lea     di, LensBack            ; DI->BUFFER

	mov     dx, 48
ContDrawLens:
	mov     cx, 12
	rep     movsd
	add     si, 320-48
	dec     dx
	jnz     ContDrawLens

	; Do the lens stuff:
	mov     ax, es                  ; Set segment regs:
	mov     ds, ax
	mov     ax, virtualscr
	mov     es, ax
	pop     di                      ; DI points to offset
	;mov     si, OFFSET lens
	xor     si, si
	xor     bp, bp

	mov     dx, 48
@NextLensRow:
	mov     cx, 48
@@NextLensDot:
	mov     bx, [lens + si]
	cmp     bx, [LensCheck + si]
	je      NoLensEffect
	mov     al, Byte Ptr [LensBack + bx]
	add     al, 128
	mov     Byte Ptr es:[di + bp], al
NoLensEffect:
	inc     bp
	add     si, 2
	loop    @@NextLensDot
	add     bp, 320 - D
	dec     dx
	jnz     @NextLensRow
	
	pop     ds 
	pop     es 
	pop     bp 
	pop     di 
	pop     si 
	pop     dx 
	pop     cx 
	pop     bx 
	pop     ax
		ret
ENDP    DoLens

PROC    EraseLens       NEAR
	push    ax 
	push    bx 
	push    cx 
	push    dx 
	push    si 
	push    di 
	push    bp 
	push    es 
	push    ds

	;       Restore background:
	xor     dx, dx                  ; Calculate OFFSET
	mov     ax, LensY
	mov     dh, al
	shl     ax, 6
	add     ax, dx
	add     ax, LensX

	mov     di, ax                  ; DI->OFFSET

	mov     ax, virtualscr
	mov     es, ax                  ; ES->SCREEN

	lea     si, LensBack            ; SI->BUFFER

	mov     dx, 48
ContEraseLens:
	mov     cx, 12
	rep     movsd
	add     di, 320-48
	dec     dx
	jnz     ContEraseLens

	pop     ds 
	pop     es 
	pop     bp 
	pop     di 
	pop     si 
	pop     dx 
	pop     cx 
	pop     bx 
	pop     ax

		ret
ENDP    EraseLens       

;************************************************************************
; Loads the BIOS char set in the CharBuffer
	PUBLIC LoadCharset
LoadCharset     PROC    NEAR
	;mov     ax, CHARS_SEG
	;mov     es, ax
	mov     ax, ds
	mov     es, ax
	;mov     di, CHARS_OFF
	lea     di, alphabet
	lea     si, CharBuffer
	mov     cx, 128*8
	xor     ax, ax
@Loop1:
	mov     dl, es:[di]
	mov     al, 128
@@Loop2: 
	test    dl, al
	jz      NoBit
	mov     Byte ptr [si], 81
	jmp     DoneBit
NoBit:
	mov     Byte ptr [si], 0
DoneBit:              
	inc     si
	shr     al, 1
	cmp     ax, 0
	jg      @@Loop2
	inc     di
	loop    @Loop1
		ret
LoadCharset     ENDP

PROC    DrawHorizLine    NEAR
	xor     dx, dx
	mov     ax, DrawLineMinY
	mov     dh, al
	shl     ax, 6
	add     ax, dx
	add     ax, DrawLineMinX
	mov     bx, ax
	mov     ax, virtualscr
	mov     es, ax
	mov     ax, DrawLineMinX
	mov     dx, DrawLineMaxX
	sub     dx, ax
	mov     al, DrawLineColor
@DrawHorizLineAgain:
	mov     es:[bx], al
	inc     bx
	dec     dx
	jnz     @DrawHorizLineAgain
	
		ret
ENDP    DrawHorizLine

PROC    SetupLensCheck  NEAR
	push    ax
	push    bx
	push    cx

	xor     bx, bx
	mov     cx, 48*48
	xor     ax, ax
@SetupLensMore:
	;mov     Word Ptr [LensCheck + bx], ax
	mov     Word Ptr [LensCheck + bx], ax
	add     bx, 2
	inc     ax
	loop    @SetupLensMore

	pop     cx
	pop     bx
	pop     ax
		ret
ENDP    SetupLensCheck

PROC    DoSoundThing    NEAR
	; Check if sound effect:

	push    ax
	push    bx
	push    es
	
	mov     ax, virtualscr
	mov     es, ax

	dec     CurSoundThing
	cmp     CurSoundThing, 8
	ja      SoundNotYet

	cmp     CurSoundThing, 0
	ja      NoResetEverythingYet
	
	add     SoundIndex, 2
	mov     bx, SoundIndex
	cmp     Word Ptr [SoundThing + bx], 0
	jne     NoResetSoundThing
	mov     SoundIndex, 0
NoResetSoundThing:
	mov     bx, SoundIndex
	mov     ax, [SoundThing + bx]
	mov     CurSoundThing, ax

	; Set 81 palette higher:
	mov     dx, 03C8h
	mov     al, 81
	out     dx, al

	inc     dx
	mov     al, 63
	out     dx, al
	out     dx, al
	out     dx, al

	mov     dx, 03C8h
	mov     al, 209
	out     dx, al

	inc     dx
	mov     al, 63
	out     dx, al
	out     dx, al
	out     dx, al
		       
NoResetEverythingYet:
	; Clear Out The Flames:
	mov     bx, 26
LoopSoundThing:
	mov     [Flames + bx], 0
	dec     bx
	cmp     bx, 3
	jnz     LoopSoundThing

SoundNotYet:

	; Lower scrolelr color (81):
	mov     dx, 03C7h
	mov     al, 81
	out     dx, al

	mov     dx, 03C9h
	in      al, dx
	mov     DoRed, al
	cmp     al, SavedRed
	jna     DontLowerRed
	dec     DoRed
DontLowerRed:
	
	in      al, dx
	mov     DoGreen, al
	cmp     al, SavedGreen
	jna     DontLowerGreen
	dec     DoGreen
DontLowerGreen:

	in      al, dx
	mov     DoBlue, al
	cmp     al, SavedBlue
	jna     DontLowerBlue
	dec     DoBlue
DontLowerBlue:

	mov     dx, 03C8h
	mov     al, 81
	out     dx, al

	inc     dx
	mov     al, DoRed
	out     dx, al
	mov     al, DoGreen
	out     dx, al
	mov     al, DoBlue
	out     dx, al

	;€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€

	mov     dx, 03C7h
	mov     al, 209
	out     dx, al

	mov     dx, 03C9h
	in      al, dx
	mov     Do2ndRed, al
	cmp     al, SavedRed
	jna     @DontLowerRed
	dec     Do2ndRed
@DontLowerRed:
	
	in      al, dx
	mov     Do2ndGreen, al
	cmp     al, SavedGreen
	jna     @DontLowerGreen
	dec     Do2ndGreen
@DontLowerGreen:

	in      al, dx
	mov     Do2ndBlue, al
	mov     dl, SavedBlue
	shl     dl, 1
	cmp     dl, 63
	jna     @@DontSetBlue
	mov     dl, 63
@@DontSetBlue:
	cmp     al, dl
	jna     @DontLowerBlue
	dec     Do2ndBlue
@DontLowerBlue:

	mov     dx, 03C8h
	mov     al, 209
	out     dx, al

	inc     dx
	mov     al, Do2ndRed
	out     dx, al
	mov     al, Do2ndGreen
	out     dx, al
	mov     al, Do2ndBlue
	out     dx, al



	;€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€

	pop     es
	pop     cx
	pop     ax

		ret
ENDP    DoSoundThing

;≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤
; This PROC copys the virtualscr buffer to videomem
;
;≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤
PROC    ShowVirtualScreen     NEAR
	push    ax
	push    cx
	push    es
	push    ds
	push    si
	push    di

	mov     ax, 0A000h
	mov     es, ax
	mov     ax, virtualscr
	mov     ds, ax
	xor     si, si
	xor     di, di
	mov     cx, 16000               ; 64000/4 = 16000
	rep     movsd

	pop     di
	pop     si
	pop     ds
	pop     es
	pop     cx
	pop     ax
		ret
ENDP    ShowVirtualScreen

		include         Player.Asm

label   EndString
	db      '                           Code and Font: DaÓdaLuS', 13, 10
	db      '               Thanx to Reality Productions for releasing their', 13, 10
	db      '                                  RAD player', 13, 10
	db      '                  Stole the muzac from Skaven/Future Crew ;)', 13, 10, 13, 10, 13, 10, 13, 10
	db      '                        Call Raveity: +?? (?)?? ??????', 13, 10
	db      '                                22:00 - 08:00', 13, 10
	db      '                    Sysop: CK_RaVe_MAN    Cosysop: Prisma',13, 10
	db      13, 10, 13, 10, 13, 10, 13, 10, '$'
label   ScrollerText
	db      ' - = < Call Raveity < = -         ' 
	db      'Loads of MODs, ANSIs and more...         '
	db      'Sysop: CK_RaVe_MAN    Cosysop: Prisma         '
	db      '22:00 - 08:00         '
	db      'Raveity: +?? (?)?? ??????         '
	db      'This incredible demo was coded by DaEdaLuS         '
	db      0
label   SoundThing
	dw      SOUNDCHECKER/2, SOUNDCHECKER/2, SOUNDCHECKER/2, SOUNDCHECKER/2
	dw      SOUNDCHECKER/4, SOUNDCHECKER/4, SOUNDCHECKER/4
	dw      SOUNDCHECKER/8, SOUNDCHECKER/8, SOUNDCHECKER/4 ,SOUNDCHECKER/4
	dw      SOUNDCHECKER/4
	dw      SOUNDCHECKER/8, SOUNDCHECKER/8, 0
	SoundIndex      dw 0
	CurSoundThing   dw SOUNDCHECKER/2 + 4
	
	include lens.inc
	include alphabet.inc
	label   BackgroundColors
	db      124, 124, 124, 124, 124, 124, 124, 124
	db      125, 125, 125, 125, 125, 125, 125, 125
	;db      126, 126, 126, 126, 126, 126, 126, 126
	
	virtualscr      dw 0
	BXSV            dw 280
	LensX           dw 120
	LensY           dw 76
	LensXadd        dw 1
	LensYAdd        dw 1
	LensBack        db 48*48 dup (0)
	LensCheck       dw 48*48 dup (0)
	DrawLineMaxX    dw 0
	DrawLineMaxY    dw 0
	DrawLineMinX    dw 0
	DrawLineMinY    dw 0
	DrawLineColor   db 0
	ScrollerLetter  db 0
	ScrollerRow     db 0
	SavedRed        db 0
	SavedGreen      db 0
	SavedBlue       db 0
	DoRed           db 0
	DoGreen         db 0
	DoBlue          db 0
	Do2ndRed        db 0
	Do2ndGreen      db 0
	Do2ndBlue       db 0
	Test2           db 0,0,0,0,0,0,0,0,0,0,0
	CharBuffer      db 128*8*8  DUP (?) ; Char buffer...;)
	Flames          db 32*64 dup (0)
	NewFlames       db 32*64 dup (0)


OldInt          dd      ?
TimerCnt        dw      ?
TimerSteps      dw      ?
		ends



Music           segment para public use16
		include music.inc
		ends



Stack16         segment para public use16 stack
		dw      100h dup (?)
		ends

		end     Start
