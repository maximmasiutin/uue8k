{ The fast implementation of the UUE encoder for MS-DOS.  }
{ The program uses optimized Assembly routines with       }
{ Intel 80386 CPU 32-bit instructions.                    }
{ Version 1.1.                                            }
{ Copyright (C) 1995 by FRIENDS Software.                 }
{ Written by Maxim Masiutin. Released on March 1, 1995.   }


procedure Prepare1Str(var Sou,Dst);external;
procedure FlushSection(var Sou,OutBuf;var OutPos,Crc:word;NumStr:byte);external;
function  GetUUxlt(b:byte):char;external;
procedure Mv(var Source, Dest; Count: Word);external;
{$L UUEINC}


procedure UpStr(var s:string);
var i:Byte;l:byte absolute s;
begin for i:=1 to l do s[i]:=UpCase(s[i]) end;

function UpStrg(var s:string):string;
var a:string;
begin
 a:=s;UpStr(a);UpStrg:=a;
end;

Function LowCase(C : Char) : Char; assembler;
asm       mov  al,&C
	  cmp  al,'A'
	  jb   @@Ok
	  cmp  al,'Z'
	  ja   @@Ok
	  add  al,20h
 @@Ok:
end;

function longmul(X, Y: Integer): Longint;inline($5A/$58/$f7/$EA);

function RepSym(Sym:char;Num:byte):string;assembler;
asm     les     di,@Result
	mov     al,Num
	stosb
	xor     cx,cx
	mov     cl,al
	mov     al,Sym
	jcxz    @Nos
	rep     stosb
 @Nos:
end;

procedure LowStr(var s:string);
var i:Byte;l:byte absolute s;
begin for i:=1 to l do s[i]:=LowCase(s[i]) end;

function SStr(a:LongInt;n:Byte;ch:Char):string;
var s:string;i:Byte;
begin
 Str(a:n,s);for i:=1 to n do if s[i]=' ' then s[i]:=ch else break;
 SStr:=s;
end;

function SSStr(a:LongInt):string;
var s:string;
begin
 Str(a,s);SSStr:=s;
end;

procedure WriteF(s:string;l:byte);
var sl:byte absolute s;
begin
 if sl<l then s:=s+RepSym(' ',l-sl);
 Write(s+'  Ä ');
end;

procedure WriteHi(s:string;a:byte);
begin
 TextAttr:=a; InsLine;
 Write(' '+s);
 TextAttr:=NorAttr; WriteLn;
end;

procedure ReportError(s:string);
begin WriteHi(s,ErrAttr);Halt end;

function nd(t:word):byte;
begin
 if t>99 then nd:=3 else
 if t>9  then nd:=2 else
	      nd:=1;
end;

function SmartDIV(L:LongInt;W:Word):Word;assembler;
asm             mov     ax,word ptr [L+0]
		mov     dx,word ptr [L+2]
		div     W
		or      dx,dx
		jz      @@Exit
		inc     ax
@@Exit:
end;

function  Min(a1,a2:integer):integer;inline($58/$5B/$3B/$C3/$7C/$01/$93);

type  ExtMemMoveStruct = record
			  Length       : Longint;
			  SourceHandle : Word;
			  SourceOffset : Longint;
			  DestHandle   : Word;
			  DestOffset   : Longint;
			 end;

var   XMSdetect    : Boolean;                { XMS driver detected and valid }
      XMScontrol   : Pointer;            { Pointer to XMS's control function }
      XMShandle,
      XMSfree	   : Word;
      XMSavail	   : LongInt;

Procedure DetectXMS; assembler;
asm             mov     ax,4300h                    { Standard XMS detection }
		int     2Fh
		cmp     al,80h
		jne     @@NoXMSdriver
		mov     XMSdetect,1
		mov     ax,4310h { Get the address of the XMS control funct. }
		int     2Fh
		mov     XMSControl.Word,bx
		mov     XMSControl+2.Word,es
		mov     ah,00h                      { Get XMS Version Number }
		call    dword ptr XMSControl
		cmp     ax,$0200
		jae     @@LocEx
@@NoXMSdriver:  mov     XMSdetect,0
@@LocEx:
end;

procedure GetFreeXMS; assembler;
asm             mov     ah,8            { Get amount of free extended memory }
		call    dword ptr XMScontrol
		or      ax,ax
		jne     @@OK
		mov     dx,ax
@@OK:		mov	XMSFree,ax
end;

procedure AllocateXMS(Size : Word);assembler;
{ Return handle of allocated block; FFFF if not enough memory }
asm             mov     ah,9                      { Allocate extended memory }
		mov     dx,Size
		call    dword ptr XMScontrol
		cmp     ax,1
		je      @@OK
		mov     dx,$FFFF
@@OK:           mov     ax,dx
		mov	XMShandle,ax
end;

procedure FreeXMS; assembler;
asm             mov     ah,10
		mov     dx,XMShandle
		call    dword ptr XMScontrol
end;

{*** Temporary local variable ***}
var Temp : ExtMemMoveStruct;

Procedure MoveToXMS(var Source;
		    DestOffset, Size : Longint); assembler;
asm             xor     ax,ax
		mov     Temp.SourceHandle.Word,ax
		les     ax,DestOffset
		mov     Temp.DestOffset.Word,ax
		mov     Temp.DestOffset+2.Word,es
		les     ax,Source
		mov     Temp.SourceOffset.Word,ax
		mov     Temp.SourceOffset+2.Word,es
		les     ax,Size
		mov     Temp.Length.Word,ax
		mov     Temp.Length+2.Word,es
		mov     ax,XMShandle
		mov     Temp.DestHandle,ax
		mov     si,offset Temp
		mov     ah,11
		call    dword ptr XMScontrol
end;

Procedure MoveFromXMS(var Destination;
		      SourceOffset, Size : Longint); assembler;
asm             xor     ax,ax
		mov     Temp.DestHandle.Word,ax
		les     ax,SourceOffset
		mov     Temp.SourceOffset.Word,ax
                mov     Temp.SourceOffset+2.Word,es
		les     ax,Destination
                mov     Temp.DestOffset.Word,ax
                mov     Temp.DestOffset+2.Word,es
		les     ax,Size
		mov     Temp.Length.Word,ax
		mov     Temp.Length+2.Word,es
		mov     ax,XMShandle
                mov     Temp.SourceHandle,ax
                mov     si,offset Temp
                mov     ah,11
		call    dword ptr XMScontrol
end;

procedure ExitPrc;
var s:string;
begin
  if XMSAllocated then FreeXMS;
  case ExitCode of
	0 : Halt(0);
	2 : s:='File not found';
	3 : s:='Path not found';
	4 : s:='Too many open files';
	5 : s:='File access denied';
       15 : s:='Invalid drive number';
      100 : s:='Disk read error';
      101 : s:='Disk write error';
      103 : s:='File not open';
      106 : s:='Invalid numeric format';
      150 : s:='Disk is write-protected';
      151 : s:='Bad drive request struct length';
      152 : s:='Drive not ready';
      154 : s:='CRC error in data';
      156 : s:='Disk seek error';
      157 : s:='Unknown media type';
      158 : s:='Sector Not Found';
      160 : s:='Device write fault';
      161 : s:='Device read fault';
      162 : s:='Hardware failure';
      203 : s:='Memory overflow';
      204 : s:='Invalid pointer operation';
      255 : s:='User break - abnormal termination';
  else s:='Unknown error #'+SSStr(ExitCode);
  end;
 WriteLn;WriteLn;
 TextAttr:=7;
 WriteLn('   ***  '+s+'  ***');
 Halt(ExitCode);
end;

procedure Crc(var Buf;Size:word;var PrevSum:word);assembler;
asm
	mov	cx,Size
	jcxz	@@End
	push	ds
	lds	si,Buf
	les	di,PrevSum
	mov	dx,word ptr [es:di]
	xor	ax,ax
 @@1:	lodsb
	ror	dx,1
	add	dx,ax
	loop    @@1
	pop     ds
	mov	word ptr es:[di],dx
 @@End:
end;

