{ The fast implementation of the UUE encoder for MS-DOS.  }
{ The program uses optimized Assembly routines with       }
{ Intel 80386 CPU 32-bit instructions.                    }
{ Version 1.1.                                            }
{ Copyright (C) 1995 by FRIENDS Software.                 }
{ Written by Maxim Masiutin. Released on March 1, 1995.   }

uses    Dos;

procedure CalcChkSum(var Buf;Size:word;var PrevSum:word);assembler;
asm
        mov     cx,Size
        jcxz    @@End
        push    ds
        lds     si,Buf
        les     di,PrevSum
        mov     dx,word ptr [es:di]
        xor     ax,ax
 @@1:   lodsb
        ror     dx,1
        add     dx,ax
        loop    @@1
        pop     ds
        mov     word ptr es:[di],dx
 @@End:
end;

const
        BufSize  = 16*1024;

var
        f        : file;
        ChkSum   : word;
        FSize    : LongInt;
        Buf      : array[1..BufSize] of Byte;
        i        : word;
        FName    : PathStr;

begin
 if ParamCount<>1 then Exit; FName:=ParamStr(1);

 WriteLn('Calculating UUE CheckSum of "'+FName+'"...');

 FileMode:=0; Assign(f,FName); Reset(f,1);FSize:=FileSize(f);

 ChkSum:=0;

 for i:=1 to FSize div BufSize do
 begin
  BlockRead(f,Buf,BufSize);
  CalcChkSum(Buf,BufSize,ChkSum);
 end;

 i:=FSize mod BufSize;
 if i>0 then
 begin
  BlockRead(f,Buf,i);
  CalcChkSum(Buf,i,ChkSum);
 end;

 WriteLn('sum -r/size ',ChkSum,'/',FSize,' entire input file');
 Close(f);

end.
