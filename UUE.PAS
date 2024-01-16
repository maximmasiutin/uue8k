{ The fast implementation of the UUE encoder for MS-DOS.  }
{ The program uses optimized Assembly routines with       }
{ Intel 80386 CPU 32-bit instructions.                    }
{ Version 1.1.                                            }
{ Copyright (C) 1995 by FRIENDS Software.                 }
{ Written by Maxim Masiutin. Released on March 1, 1995.   }

{$A-,B-,D+,E+,F-,G+,I+,L+,N+,O-,P-,Q-,R-,S-,T-,V-,X+,Y+}
{$M 16384,0,655360}

program FriendsUUEncoder;

uses Crt,Dos;

const
        XMSAllocated    : boolean=False;
        EntireCRC       : word=0;
        MaxSectSize     = $1200;
        BufSize         = $8000;
        AlignSafe       = $30;
        XMSAlign        = $10;
        Title           = '< uuencode 1.1 by FRIENDS Software >';
        HiAttr          = $3F;
        HelpAttr        = $1E;
        NorAttr         = $07;
        ErrAttr         = $4F;
        GaugeLen        = 39;
        GaugeStart      = 22;
        MaxSectNum      = 900;
        WeakBrick       = 'ù';
        BoldBrick       = 'þ';

type
        Str3            = string[3];
        Str8            = string[8];
        Str12           = string[12];
        Str20           = string[20];
        Str60           = string[60];
        PSectArr        = ^TSectArr;
        TSectArr        = array[1..MaxSectSize+AlignSafe] of Byte;
        TDskBufArr      = array[1..BufSize] of byte;
var
        ParStr          : PathStr;
        ConvSect,
        XMSsect,
        NumSect,
        SouSize,
        FTime,
        SectSize        : LongInt;
        SouName         : Str12;
        OutName         : Str8;
        SectPtr         : array[1..MaxSectNum] of PSectArr;
        LastSect        : array[1..MaxSectSize+AlignSafe] of byte;
        DskBuf          : TDskBufArr;
        LastSectSize    : LongInt;

{$I UUEINC.PAS}

procedure RefreshGauge(c,t:word);
var bld,d,gl:word;
begin
 d:=nd(t);gl:=GaugeLen-(d-1)*2;bld:=(c*gl) div t;
 Write(SStr(c,d,' ')+' of '+SStr(t,d,' ')+' ['+
       RepSym(BoldBrick,bld)+
       RepSym(WeakBrick,gl-bld)+
       '] '+SStr(c*100 div t,3,' ')+'%'+
       RepSym(#8,gl+12+d+d)
      );
end;

procedure HandleParams;

 procedure Help;
 begin
  WriteHi('Usage : UUE <file-to-encode>',HelpAttr);
  WriteLn('    Ú'+RepSym('Ä',71)+'¿'+#13#10,
          '    ³ To get the author mail a message to Maxim Masyutin aka Blue Carnation ³'#13#10,
          '    ³            2:469/84@fidonet.org (Russian/English/Romanian)            ³'#13#10,
          '    ³                 or call (0422)246-530 voice (Russian)                 ³'#13#10+
          '    À'+RepSym('Ä',71)+'Ù');
  Halt;
 end;

var
        D  : DirStr;
        N  : NameStr;
        E  : ExtStr;

begin
 if ParamCount<>1 then Help;
 ParStr:=ParamStr(1);
 if Pos('?',ParStr)<>0 then Help;
 if Pos('/',ParStr)<>0 then Help;
 UpStr(ParStr);
 if ParStr='-H' then Help;
 FSPlit(ParStr,D,N,E);
 OutName:=N;
 SouName:=N+E;
 LowStr(SouName);
end;

procedure CheckIO(FN:PathStr);
begin
 if IOResult = 0 then Exit;
 ReportError('Failed to open '+FN);
end;

procedure ReadSource;
var
        f       :  file;
        BufPos  :  word;
        SouLeft :  LongInt;

 procedure BRead(var Buf:TDskBufArr;Sz:word);
 var s:word;
 begin
  BlockRead(f,Buf,Sz,s);
  if s<>Sz then Halt(100); {Disk read error}
  Crc(Buf,Sz,EntireCRC);
 end;

 procedure ReadLastSect;
 begin
  BRead(DskBuf,SouLeft);
  SouLeft:=0;
  Close(f);
 end;

 procedure ReadPortion;
 begin
  if SouLeft>BufSize then
  begin
   BRead(DskBuf,BufSize);
   Dec(SouLeft,BufSize);
  end else ReadLastSect;
 end;

 procedure GetBlock(var InBuf;Sz:word);
 var Buf:TDskBufArr absolute InBuf;
 begin
  if SouLeft=-1 then
  begin
   BufPos:=Sz;
   if SouSize>BufSize then
   begin
    BRead(DskBuf,BufSize);
    SouLeft:=SouSize-BufSize;
   end else begin SouLeft:=SouSize;ReadLastSect end;
   Mv(DskBuf,Buf,Sz);
  end else
  begin
   if BufPos+Sz>=BufSize then
   begin
    if BufPos+Sz=BufSize then
    begin
     Mv(DskBuf[BufPos+1],Buf,Sz);
     ReadPortion;BufPos:=0;
    end else
    begin
     Mv(DskBuf[BufPos+1],Buf,BufSize-BufPos);
     ReadPortion;
     Mv(DskBuf,Buf[BufSize-BufPos+1],Sz-(BufSize-BufPos));
     BufPos:=Sz-(BufSize-BufPos);
    end;
   end else begin Mv(DskBuf[BufPos+1],Buf,Sz);Inc(BufPos,Sz) end;
  end;
 end;

 procedure ReadConvSect;
 var i:word;
 begin
  for i:=1 to ConvSect do
  begin
   GetMem(SectPtr[i],SectSize);
   GetBlock(SectPtr[i]^,SectSize);
   RefreshGauge(i,NumSect+1);
  end;
 end;

 procedure ReadXMSSect;
 var i:word;
 begin
  for i:=1 to XMSSect do
  begin
   GetBlock(LastSect,SectSize);
   RefreshGauge(i+ConvSect,NumSect+1);
   MoveToXMS(LastSect,(i-1)*(SectSize+XMSAlign),SectSize);
  end;
 end;

procedure CalcLSsize;
var ls:LongInt;
begin
 ls:=SouSize-LongMul(SectSize,NumSect);
 while ls<SectSize div 2 do
 begin
  Inc(ls,SectSize);
  Dec(NumSect);
 end;
 LastSectSize:=ls;
end;

var
    MemReq,ma   :  LongInt;

begin
 FileMode:=0;SouLeft:=-1;
 Assign(f,ParStr);
 {$I-}GetFTime(f,FTime);CheckIO(ParStr);Reset(f,1);CheckIO(ParStr);{$I+}
 SouSize:=FileSize(f);
 if SouSize<3 then ReportError('Input file ('+ParStr+') is too small');
 NumSect:=SmartDIV(SouSize,MaxSectSize)-1;
 if NumSect>MaxSectNum then ReportError('File '+UpStrg(SouName)+' consists of more than '+
                         SSStr(MaxSectNum)+' sections');
 if NumSect=0 then LastSectSize:=SouSize else
 begin
  SectSize:=SmartDIV(SmartDIV(SouSize,NumSect+1),45)*45;
  CalcLSSize;
 end;
 MemReq:=(NumSect+2)*(SectSize+$200);ma:=MemAvail;
 if ma<MemReq then
 begin
  DetectXMS;
  if XMSDetect then
  begin
   GetFreeXMS;
   XMSavail:=LongMul(XMSfree,1024);
   Inc(ma,XMSAvail);
  end
 end;

 if MemReq>ma then
 begin
  WriteLn('       ***  Not enough memory available. Only ',ma div 1024,
          ' KB actually free  ***');
  ReportError(SSStr(MemReq div 1024)+' KB required '+
          'to encode '+ParStr);
 end;
 ConvSect:=Min(SmartDiv(MemAvail,SectSize+AlignSafe+$100),NumSect);
 XMSsect:=NumSect-ConvSect;
 if XMSSect>0 then
 begin
  AllocateXMS(SmartDIV((SectSize+XMSAlign)*XMSSect,1024));
  if XMSHandle=$FFFF then ReportError('Error allocating XMS block');
  XMSAllocated:=True;
 end;
 WriteF(' Reading '+UpStrg(SouName),GaugeStart);
 if NumSect>0 then
 begin
  RefreshGauge(0,NumSect+1);
  ReadConvSect;
  ReadXMSSect;
 end;
 GetBlock(LastSect,LastSectSize);
 RefreshGauge(NumSect+1,NumSect+1);
end;

procedure WriteUUE;
var
        TxtBufSize,
        SecCRC,SecCRCs,
        StrPerLastS,
        nl,SectNo       : word;
        StrPerSect      : byte;
        t               : file;
        ONl             : byte absolute OutName;
        LN              : Str12;

procedure WriteT(s:string);
var sl:byte absolute s;
begin
 Mv(s[1],DskBuf[TxtBufSize+1],sl);
 Inc(TxtBufSize,sl);
end;

procedure WriteLnT(s:string);
begin
 WriteT(s+#13#10);
end;

procedure WriteLnCRC(s:string);
var sl:byte;
begin
 sl:=Byte(s[0]);
 Inc(sl);Inc(SecCRCs,sl);s[sl]:=#10;
 Crc(s[1],sl,SecCRC);
 WriteLnT(s);
end;

procedure FlushT;
begin
 {$I-}Rewrite(t,1);CheckIO(LN);{$I+}
 BlockWrite(t,DskBuf,TxtBufSize);
 Close(t);
end;

procedure StartSection;
var o:string;
begin
 Inc(SectNo);TxtBufSize:=0;SecCRC:=0;SecCRCs:=0;
 if nl>0 then LN:=OutName+SStr(SectNo,nl,'0') else LN:=OutName;LN:=LN+'.UUE';
 Assign(t,LN);
 if NumSect>0 then o:=' of '+SSStr(NumSect+1) else o:='';
 WriteLnT('section '+SSStr(SectNo)+o+' of file '+SouName+'  '+Title+#13#10);
 if SectNo=1 then
 begin
  WriteLnT('filetime '+SSStr(FTime));
  WriteLnCRC('begin 644 '+SouName);
 end;
end;

procedure EndSection;
var f,t:Str20;
begin
 RefreshGauge(SectNo,NumSect+1);
 if SectNo=NumSect+1 then
 begin
  WriteLnCRC('`');
  WriteLnCRC('end');
 end else
 begin
  WriteLnT('');
 end;
 if NumSect=0 then begin f:='"begin"';t:='"end"' end else
 if SectNo=1 then begin f:='"begin"';t:='last encoded line' end else
 if SectNo=NumSect+1 then begin f:='first encoded line';t:='"end"' end else
                     begin f:='first';t:='last encoded line' end;

 WriteLnT('sum -r/size '+SSStr(SecCRC)+'/'+SSStr(SecCRCs)+' section (from '+f+' to '+t+')');
 if SectNo=NumSect+1 then WriteLnT('sum -r/size '+SSStr(EntireCRC)+
  '/'+SSStr(SouSize)+' entire input file');
 WriteT(#13#10#26);
 FlushT;
end;

procedure WriteStr(var Buf;NumBytes:word);
var d  : Str60;
    dl : byte absolute d;
    s  : array[1..45] of byte;
begin
 Mv(Buf,s,NumBytes);
 if NumBytes<45 then FillChar(s[NumBytes+1],45-NumBytes,0);
 Prepare1Str(s,d[1]);
 dl:=SmartDiv((NumBytes*4),3);
 WriteLnCRC(GetUUxlt(NumBytes)+d);
end;

procedure WriteSection(var Buf;ss:word);
begin
 FlushSection(Buf,DskBuf,TxtBufSize,SecCRC,ss);
 Inc(SecCRCs,ss*62);
end;

procedure WriteCompleteSection(var Buf);
begin
 WriteSection(Buf,StrPerSect);
end;

procedure WriteConvSection;
begin
 StartSection;
 WriteCompleteSection(SectPtr[SectNo]^);
 FreeMem(SectPtr[SectNo],SectSize);
 EndSection;
end;

procedure WriteXMSSections;
var p:PSectArr;
    xm:word;
 procedure WriteXMSSection;
 begin
  StartSection;
  MoveFromXMS(p^,(xm-1)*(SectSize+XMSAlign),SectSize);
  WriteCompleteSection(p^);
  EndSection;
 end;
begin
 GetMem(p,SectSize+XMSAlign);
 for xm:=1 to XMSSect do WriteXMSSection;
 FreeMem(p,SectSize+XMSAlign);
end;

procedure WriteLastSection;
var i:word;
begin
 StartSection;
 i:=StrPerLastS-1;
 if i>0 then WriteSection(LastSect,i);
 WriteStr(LastSect[(i)*45+1],LastSectSize-(i)*45);
 EndSection;
end;

procedure WriteUS;
var s:string;
begin
 WriteLn;
 s:=' Writing UUE section'; if NumSect>0 then s:=s+'s';
 WriteF(s,GaugeStart);
end;

procedure DoWrite;
var i: word;
begin
 for i:=1 to ConvSect do WriteConvSection;
end;

begin
 WriteUS;
 RefreshGauge(0,NumSect+1);
 StrPerSect:=SectSize div 45;
 StrPerLastS:=SmartDIV(LastSectSize,45);
 SectNo:=0;
 if NumSect>=99 then begin ONl:=Min(ONl,5);nl:=3 end else
 if NumSect>=9  then begin ONl:=Min(ONl,6);nl:=2 end else
 if NumSect>=1 then begin ONl:=Min(ONl,7);nl:=1 end else nl:=0;
 DoWrite;
 WriteXMSSections;
 WriteLastSection;
end;

procedure WriteN(s:string);
begin WriteHi(s,HiAttr) end;

procedure WriteTitle;
begin
 WriteLn;
 WriteN('8Kb UU-ENCODE FOR PC  Version 1.1  Copyright (C) 1995 by FRIENDS Software');
end;

procedure ReportOK;
begin
 WriteLn;
 WriteN('Complete');
 WriteLn;
end;

begin
 ExitProc:=@ExitPrc;
 WriteTitle;
 HandleParams;
 ReadSource;
 WriteUUE;
 ReportOK;
end.
