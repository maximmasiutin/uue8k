; The fast implementation of the UUE encoder for MS-DOS.
; The program uses optimized Assembly routines with
; Intel 80386 CPU 32-bit instructions.
; Version 1.1.
; Copyright (C) 1995 by FRIENDS Software.
; Written by Maxim Masiutin. Released on March 1, 1995.

	ideal
	p186
	jumps
	smart
	model	tPascal
	DataSeg
extrn	Test8086 : byte

	CodeSeg

public	Prepare1Str
public	XLatStr
public	GetUUxlt
public  FlushSection
public	Mv

proc	Mv	near
	arg	Source:dword,Dest:dword,Count:word
	uses	ds
	cld
	les	di,[Dest]
	mov	cx,[Count]
	cmp	[Test8086],2
	lds	si,[Source]
	jcxz	@@End
	jb	@@186
	mov	ax,cx
	shr	cx,2
	and	ax,3
	p386
	rep	movsd
	p186
	mov	cx,ax
@@Last: rep	movsb
	jmp	@@End
@@186:  shr	cx,1
	rep	movsw
	adc	cx,cx
	jmp	@@Last
@@End:	ret
	endp
proc	Prepare1Str near
	arg	Sou:dword,Dst:dword
	push	ds
	lds	si,[Sou]
	les   	di,[Dst]
	mov	cx,15
	mov	bx,offset UUxlt
  @@L:	mov	al,[ds:si+2]
	mov	dh,al
	and	al,00111111b
	shr	dh,6
  SegCS xlat
	mov	[es:di+3],al
	mov	al,[ds:si+1]
	mov	dl,al
	shl	al,2
	and	al,00111100b
	shr	dl,4
	or	al,dh
  SegCS xlat
	mov	[es:di+2],al
	mov	al,[ds:si]
	add	si,3
	mov	dh,al
	shl	al,4
	and	al,00110000b
	shr	dh,2
	or 	al,dl
  SegCS xlat
	mov	[es:di+1],al
	mov	al,dh
  SegCS xlat
	mov	[es:di],al
	add	di,4
	loop  	@@L
	pop	ds
	ret
	endp

proc	XLatStr near
	arg	s:dword
	les	di,[s]
	mov	bx,offset UUxlt
	mov	cl,[es:di]
	inc	di
	mov	ch,0
  @@L:  mov     al,[es:di]
  SegCS	xlat
	stosb
	loop	@@L
	ret
	endp

proc	GetUUxlt near
	arg	a:byte
	mov	al,[a]
	mov	bx,offset UUxlt
  SegCS xlat
	ret
	endp

	macro	StoreM
	mov	ax,4Dh
	ror	cx,1
	add	cx,ax
	stosb
	endm

	macro	CrLf
	mov	dl,0Ah
	ror	cx,1
	add	cx,dx
	mov	ax,0A0Dh
	stosw
	dec	[StrL]
	endm

	macro	OutAX
	mov	dl,al
	ror	cx,1
	add	cx,dx
	mov	dl,ah
	ror	cx,1
	add	cx,dx
	stosw
	endm

proc	FlushSection near
	uses	ds
	arg	Sou:dword,OutBuf:dword,OutPos:dword,Crc:dword,StrL:byte
	les	di,[Crc]
	mov	cx,[es:di]
	les	di,[OutPos]
	mov	ax,[es:di]
	les	di,[OutBuf]
	add	di,ax
	mov	bx,offset UUxlt
	cmp	[Test8086],2
	lds	si,[Sou]
	jb	@@186
	p386
 @@str3:
	StoreM
	rept	15
	mov	al,[ds:si+2]
	mov	dh,al
	and	al,00111111b
  SegCS xlat
	mov	ah,al
	shr	dh,6
	mov	al,[ds:si+1]
	mov	dl,al
	shl	al,2
	and	al,00111100b
	shr	dl,4
	or	al,dh
  SegCS	xlat
	shl	eax,8
	mov	al,[ds:si]
	add	si,3
	mov	dh,al
	shl	al,4
	and	al,00110000b
	shr	dh,2
	or 	al,dl
  SegCS	xlat
	shl	eax,8
	mov	al,dh
  SegCS xlat
	stosd
	movzx	dx,al
	ror	cx,1
	add	cx,dx
	mov	dl,ah
	ror	cx,1
	add	cx,dx
	shr	eax,16
	mov	dl,al
	ror	cx,1
	add	cx,dx
	mov	dl,ah
	ror	cx,1
	add	cx,dx
	endm
	CrLf
	jnz	@@str3
	p186
	jmp	@@End
@@186:
 @@str1:
	push	bp
	StoreM
	rept	15
	mov	al,[ds:si+2]
	mov	dh,al
	and	al,00111111b
	shr	dh,6
  SegCS xlat
	mov	ah,al
	mov	al,[ds:si+1]
	mov	dl,al
	shl	al,2
	and	al,00111100b
	shr	dl,4
	or	al,dh
  SegCS xlat
	mov	bp,ax
	mov	al,[ds:si]
	add	si,3
	mov	dh,al
	shl	al,4
	and	al,00110000b
	shr	dh,2
	or 	al,dl
  SegCS xlat
	mov	ah,al
	mov	al,dh
  SegCS xlat
	xor	dx,dx
	OutAX
	mov	ax,bp
	OutAX
	endm
	pop	bp
	CrLf
	jnz	@@str1
@@End:  sub	di,[word ptr OutBuf]
	les	si,[OutPos]
	mov	[es:si],di
	les	si,[Crc]
	mov	[es:si],cx
	ret
	endp

UUxlt	db '`!"#$%&''()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_'

	end