unit mpProtocol;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, mpRed, MasterPaskalForm, mpParser, StrUtils, mpDisk, mpTime,mpMiner, mpBlock,
  Zipper, mpcoin, mpCripto, mpMn;

function GetPTCEcn():String;
Function GetOrderFromString(textLine:String):OrderData;
function GetStringFromOrder(order:orderdata):String;
function GetStringFromBlockHeader(blockheader:BlockHeaderdata):String;
Function ProtocolLine(tipo:integer):String;
Procedure ParseProtocolLines();
function IsValidProtocol(line:String):Boolean;
Procedure PTC_Getnodes(Slot:integer);
function GetNodesString():string;
Procedure PTC_SendLine(Slot:int64;Message:String);
Procedure ClearOutTextToSlot(slot:integer);
Function GetTextToSlot(slot:integer):string;
function GetNodeFromString(NodeDataString: string): NodeData;
Procedure ProcessPing(LineaDeTexto: string; Slot: integer; Responder:boolean);
function GetPingString():string;
procedure PTC_SendPending(Slot:int64);
Procedure PTC_SendMNs(Slot:int64);
Procedure PTC_SendResumen(Slot:int64);
Function ZipSumary():boolean;
Function ZipHeaders():boolean;
function CreateZipBlockfile(firstblock:integer):string;
Procedure PTC_SendBlocks(Slot:integer;TextLine:String);
Procedure INC_PTC_Custom(TextLine:String;connection:integer);
Procedure PTC_Custom(TextLine:String);
function ValidateTrfr(order:orderdata;Origen:String):integer;
Function IsOrderIDAlreadyProcessed(OrderText:string):Boolean;
Procedure INC_PTC_Order(TextLine:String;connection:integer);
Function PTC_Order(TextLine:String):String;
Procedure PTC_AdminMSG(TextLine:String);
Procedure PTC_NetReqs(textline:string);
function RequestAlreadyexists(reqhash:string):string;
Procedure UpdateMyRequests(tipo:integer;timestamp:string;bloque:integer;hash,hashvalue:string);
Function PTC_BestHash(Linea:string):String;
Procedure PTC_SendUpdateHeaders(Slot:integer;Linea:String);
Procedure PTC_HeadUpdate(linea:String);

function GetMNfromText(LineText:String):TMasterNode;
function GetTextFromMN(node:TMasterNode):string;
function NodeAlreadyadded(Node:TMasterNode):boolean;

Procedure SetNMSData(diff,hash,miner:string);
Function GetNMSData():TNMSData;

// CS Incoming
Procedure AddToIncoming(Index:integer;texto:string);
Function GetIncoming(Index:integer):String;
Function LengthIncoming(Index:integer):integer;
Procedure ClearIncoming(Index:integer);


CONST
  OnlyHeaders = 0;
  Getnodes = 1;
  Nodes = 2;
  Ping = 3;
  Pong = 4;
  GetPending = 5;
  GetResumen = 7;
  LastBlock = 8;
  Custom = 9;
  NodeReport = 10;
  GetMNs = 11;
  BestHash = 12;
  MNReport =13;
  MNCheck = 14;
  GetChecks = 15;
  GetMNsFile = 16;
  MNFile = 17;
  GetHeadUpdate = 18;
  HeadUpdate = 19;

implementation

uses
  mpGui;

// Devuelve el puro encabezado con espacio en blanco al final
function GetPTCEcn():String;
Begin
result := 'PSK '+IntToStr(protocolo)+' '+ProgramVersion+subversion+' '+UTCTime+' ';
End;

// convierte los datos de la cadena en una order
Function GetOrderFromString(textLine:String):OrderData;
var
  orderinfo : OrderData;
Begin
OrderInfo := Default(OrderData);
TRY
OrderInfo.OrderID    := Parameter(textline,1);
OrderInfo.OrderLines := StrToInt(Parameter(textline,2));
OrderInfo.OrderType  := Parameter(textline,3);
OrderInfo.TimeStamp  := StrToInt64(Parameter(textline,4));
OrderInfo.reference  := Parameter(textline,5);
OrderInfo.TrxLine    := StrToInt(Parameter(textline,6));
OrderInfo.Sender     := Parameter(textline,7);
OrderInfo.Address    := Parameter(textline,8);
OrderInfo.Receiver   := Parameter(textline,9);
OrderInfo.AmmountFee := StrToInt64(Parameter(textline,10));
OrderInfo.AmmountTrf := StrToInt64(Parameter(textline,11));
OrderInfo.Signature  := Parameter(textline,12);
OrderInfo.TrfrID     := Parameter(textline,13);
EXCEPT ON E:Exception do
   begin
   ToExcLog('Error GetOrderFromString : '+E.Message);
   end;
END;{TRY}
Result := OrderInfo;
End;

// Convierte una orden en una cadena para compartir
function GetStringFromOrder(order:orderdata):String;
Begin
result:= Order.OrderType+' '+
         Order.OrderID+' '+
         IntToStr(order.OrderLines)+' '+
         order.OrderType+' '+
         IntToStr(Order.TimeStamp)+' '+
         Order.reference+' '+
         IntToStr(order.TrxLine)+' '+
         order.Sender+' '+
         Order.Address+' '+
         Order.Receiver+' '+
         IntToStr(Order.AmmountFee)+' '+
         IntToStr(Order.AmmountTrf)+' '+
         Order.Signature+' '+
         Order.TrfrID;
End;

// devuelve una cadena con los datos de la cabecera de un bloque
function GetStringFromBlockHeader(BlockHeader:blockheaderdata):String;
Begin
result := 'Number:'+IntToStr(BlockHeader.Number)+' '+
          'Start:' +IntToStr(BlockHeader.TimeStart)+' '+
          'End:'+IntToStr(BlockHeader.TimeEnd)+' '+
          'Total:'+IntToStr(BlockHeader.TimeTotal)+' '+
          '20:'+IntToStr(BlockHeader.TimeLast20)+' '+
          'Trxs:'+IntToStr(BlockHeader.TrxTotales)+' '+
          'Diff:'+IntToStr(BlockHeader.Difficult)+' '+
          'Target:'+BlockHeader.TargetHash+' '+
          'Solution:'+BlockHeader.Solution+' '+
          'NextDiff:'+IntToStr(BlockHeader.NxtBlkDiff)+' '+
          'Miner:'+BlockHeader.AccountMiner+' '+
          'Fee:'+IntToStr(BlockHeader.MinerFee)+' '+
          'Reward:'+IntToStr(BlockHeader.Reward);

End;

//Devuelve la linea de protocolo solicitada
Function ProtocolLine(tipo:integer):String;
var
  Resultado : String = '';
  Encabezado : String = '';
  TempStr    : string = '';
Begin
Encabezado := 'PSK '+IntToStr(protocolo)+' '+ProgramVersion+subversion+' '+UTCTime+' ';
if tipo = OnlyHeaders then
   resultado := '';
if tipo = GetNodes then
   Resultado := '$GETNODES';
if tipo = Nodes then
   Resultado := '$NODES'+GetNodesString();
if tipo = Ping then
   Resultado := '$PING '+GetPingString;
if tipo = Pong then
   Resultado := '$PONG '+GetPingString;
if tipo = GetPending then
   Resultado := '$GETPENDING';
if tipo = GetResumen then
   Resultado := '$GETRESUMEN';
if tipo = LastBlock then
   Resultado := '$LASTBLOCK '+IntToStr(mylastblock);
if tipo = Custom then
   Resultado := '$CUSTOM ';
if tipo = NodeReport then    // DEPRECATED
   begin
   Resultado := '$MNREPORT '+MN_IP+' '+MN_Port+' '+TempStr+' '+MN_Sign+' '+MyLastBlock.ToString+' '+
      MyLastBlockHash+' '+GetMNSignature;
   end;
if tipo = GetMNs then
   Resultado := '$GETMNS';
if tipo = BestHash then
   Resultado := '$BESTHASH';
if tipo = MNReport then
   Resultado := '$MNREPO '+GetMNReportString;
if tipo = MNCheck then
   Resultado := '$MNCHECK ';
if Tipo = GetChecks then
   Resultado := '$GETCHECKS';
if tipo = GetMNsFile then
   Resultado := 'GETMNSFILE';
if tipo = MNFile then
   Resultado := 'MNFILE';
if tipo = GetHeadUpdate then
   Resultado := 'GETHEADUPDATE '+MyLastBlock.ToString;
if tipo = HeadUpdate then
   Resultado := 'HEADUPDATE';

Resultado := Encabezado+Resultado;
Result := resultado;
End;

Procedure AddToIncoming(Index:integer;texto:string);
Begin
EnterCriticalSection(CSIncomingArr[Index]);
SlotLines[Index].Add(texto);
LeaveCriticalSection(CSIncomingArr[Index]);
End;

Function GetIncoming(Index:integer):String;
Begin
result := '';
EnterCriticalSection(CSIncomingArr[Index]);
if SlotLines[Index].Count > 0 then
   begin
   result := SlotLines[Index][0];
   SlotLines[index].Delete(0);
   end;
LeaveCriticalSection(CSIncomingArr[Index]);
End;

Function LengthIncoming(Index:integer):integer;
Begin
EnterCriticalSection(CSIncomingArr[Index]);
result := SlotLines[Index].Count;
LeaveCriticalSection(CSIncomingArr[Index]);
End;

Procedure ClearIncoming(Index:integer);
Begin
EnterCriticalSection(CSIncomingArr[Index]);
SlotLines[Index].Clear;
LeaveCriticalSection(CSIncomingArr[Index]);
End;

// Procesa todas las lineas procedentes de las conexiones
Procedure ParseProtocolLines();
var
  contador : integer = 0;
  UsedProtocol : integer = 0;
  UsedVersion : string = '';
  PeerTime: String = '';
  Linecomando : string = '';
  ProcessLine : String;
Begin
SetCurrentJob('ParseProtocolLines',true);
for contador := 1 to MaxConecciones do
   begin
   if ( (LengthIncoming(contador) > 200) and (not IsSeedNode(Conexiones[contador].ip)) ) then
      begin
      Consolelinesadd('POSSIBLE ATTACK FROM: '+Conexiones[contador].ip);
      UpdateBotData(conexiones[contador].ip);
      CerrarSlot(contador);
      continue;
      end;
   While LengthIncoming(contador) > 0 do
      begin
      ProcessLine := GetIncoming(contador);
      UsedProtocol := StrToIntDef(Parameter(ProcessLine,1),1);
      UsedVersion := Parameter(ProcessLine,2);
      PeerTime := Parameter(ProcessLine,3);
      LineComando := Parameter(ProcessLine,4);
      if ((not IsValidProtocol(ProcessLine)) and (not Conexiones[contador].Autentic)) then
         // La linea no es valida y proviene de una conexion no autentificada
         begin
         ConsoleLinesAdd(LangLine(22)+conexiones[contador].ip+'->'+ProcessLine); //CONNECTION REJECTED: INVALID PROTOCOL ->
         UpdateBotData(conexiones[contador].ip);
         CerrarSlot(contador);
         end
      else if UpperCase(LineComando) = 'DUPLICATED' then
         begin
         ConsoleLinesAdd('You are already connected to '+conexiones[contador].ip); //CONNECTION REJECTED: INVALID PROTOCOL ->
         CerrarSlot(contador);
         end
      else if UpperCase(LineComando) = 'OLDVERSION' then
         begin
         ConsoleLinesAdd('You need update your wallet to connect to '+conexiones[contador].ip); //CONNECTION REJECTED: INVALID PROTOCOL ->
         CerrarSlot(contador);
         end
      else if UpperCase(LineComando) = '$GETNODES' then PTC_Getnodes(contador)
      else if UpperCase(LineComando) = '$NEWBL' then PTC_Getnodes(contador)   // DEPRECATED
      else if UpperCase(LineComando) = '$PING' then ProcessPing(ProcessLine,contador,true)
      else if UpperCase(LineComando) = '$PONG' then ProcessPing(ProcessLine,contador,false)
      else if UpperCase(LineComando) = '$GETPENDING' then PTC_SendPending(contador)
      else if UpperCase(LineComando) = '$GETMNS' then SendMNsList(contador)
      else if UpperCase(LineComando) = '$GETRESUMEN' then PTC_SendResumen(contador)
      else if UpperCase(LineComando) = '$LASTBLOCK' then PTC_SendBlocks(contador,ProcessLine)
      else if UpperCase(LineComando) = '$CUSTOM' then INC_PTC_Custom(GetOpData(ProcessLine),contador)
      else if UpperCase(LineComando) = 'ORDER' then INC_PTC_Order(ProcessLine, contador)
      else if UpperCase(LineComando) = 'ADMINMSG' then PTC_AdminMSG(ProcessLine)
      else if UpperCase(LineComando) = 'NETREQ' then PTC_NetReqs(ProcessLine)
      else if UpperCase(LineComando) = '$REPORTNODE' then PTC_Getnodes(contador) // DEPRECATED
      else if UpperCase(LineComando) = '$MNREPO' then AddWaitingMNs(ProcessLine)//
      else if UpperCase(LineComando) = '$BESTHASH' then PTC_BestHash(ProcessLine)
      else if UpperCase(LineComando) = '$MNCHECK' then PTC_MNCheck(ProcessLine)
      else if UpperCase(LineComando) = '$GETCHECKS' then PTC_SendChecks(contador)
      else if UpperCase(LineComando) = 'GETMNSFILE' then PTC_SendLine(contador,ProtocolLine(MNFILE)+' $'+GetMNsFileData)
      else if UpperCase(LineComando) = 'MNFILE' then PTC_MNFile(ProcessLine)
      else if UpperCase(LineComando) = 'GETHEADUPDATE' then PTC_SendUpdateHeaders(contador,ProcessLine)
      else if UpperCase(LineComando) = 'HEADUPDATE' then PTC_HeadUpdate(ProcessLine)


      else
         Begin  // El comando recibido no se reconoce. Verificar protocolos posteriores.
         ConsoleLinesAdd(LangLine(23)+ProcessLine+') '+intToStr(contador)); //Unknown command () in slot: (
         end;
      end;
   end;
SetCurrentJob('ParseProtocolLines',false);
End;

// Verifica si una linea recibida en una conexion es una linea valida de protocolo
function IsValidProtocol(line:String):Boolean;
Begin
if copy(line,1,4) = 'PSK ' then result := true
else result := false;
End;

// Procesa una solicitud de nodos
Procedure PTC_Getnodes(Slot:integer);
Begin
//PTC_SendLine(slot,ProtocolLine(Nodes));
End;

// Devuelve una cadena con la info de los 50 primeros nodos validos.
function GetNodesString():string;
var
  NodesString : String = '';
  NodesAdded : integer = 0;
  Counter : integer;
Begin
for counter := 0 to length(ListaNodos)-1 do
   begin
   NodesString := NodesString+' '+ListaNodos[counter].ip+':'+ListaNodos[counter].port+':'
   +ListaNodos[counter].LastConexion+':';
   NodesAdded := NodesAdded+1;
   if NodesAdded>50 then break;
   end;
result := NodesString;
End;

// Envia una linea a un determinado slot
Procedure PTC_SendLine(Slot:int64;Message:String);
Begin
if slot <= length(conexiones)-1 then
   begin
   if ((conexiones[Slot].tipo='CLI') and (not conexiones[Slot].IsBusy)) then
      begin
      if SendDirectToPeer then
         begin
         TRY
         Conexiones[Slot].context.Connection.IOHandler.WriteLn(Message);
         EXCEPT On E :Exception do
            begin
            ConsoleLinesAdd(E.Message);
            ToExcLog('Error sending line: '+E.Message);
            CerrarSlot(Slot);
            end;
         END;{TRY}
         end
      else
         begin
         EnterCriticalSection(CSOutGoingArr[slot]);
         Insert(Message,ArrayOutgoing[slot],length(ArrayOutgoing[slot]));
         LeaveCriticalSection(CSOutGoingArr[slot]);
         end;
      end;
   if ((conexiones[Slot].tipo='SER') and (not conexiones[Slot].IsBusy)) then
      begin
      TRY
      CanalCliente[Slot].IOHandler.WriteLn(Message);
      EXCEPT On E :Exception do
         begin
         ConsoleLinesAdd(E.Message);
         ToExcLog('Error sending line: '+E.Message);
         CerrarSlot(Slot);
         end;
      END;{TRY}
      end;
   end
else ToExcLog('Invalid PTC_SendLine slot: '+IntToStr(slot));
end;

Procedure ClearOutTextToSlot(slot:integer);
Begin
EnterCriticalSection(CSOutGoingArr[slot]);
SetLength(ArrayOutgoing[slot],0);
LeaveCriticalSection(CSOutGoingArr[slot]);
End;

Function GetTextToSlot(slot:integer):string;
Begin
result := '';
if ( (Slot>1) and (slot<=MaxConecciones) ) then
   begin
   EnterCriticalSection(CSOutGoingArr[slot]);
   if length(ArrayOutgoing[slot])>0 then
      begin
      result:= ArrayOutgoing[slot][0];
      Delete(ArrayOutgoing[slot],0,1);
      end;
   LeaveCriticalSection(CSOutGoingArr[slot]);
   end;
End;

// Devuelve la info de un nodo a partir de una cadena pre-tratada
function GetNodeFromString(NodeDataString: string): NodeData;
var
  Resultado : NodeData;
Begin
Resultado.ip:= GetCommand(NodeDataString);
Resultado.port:=Parameter(NodeDataString,1);
Resultado.LastConexion:=Parameter(NodeDataString,2);
Result := Resultado;
End;

// Procesa un ping recibido y envia el PONG si corresponde.
Procedure ProcessPing(LineaDeTexto: string; Slot: integer; Responder:boolean);
var
  PProtocol, PVersion, PConexiones, PTime, PLastBlock, PLastBlockHash, PSumHash, PPending : string;
  PResumenHash, PConStatus, PListenPort, PMNsHash, PMNsCount, BestHashDiff, MnsCheckCount : String;
Begin
PProtocol      := Parameter(LineaDeTexto,1);
PVersion       := Parameter(LineaDeTexto,2);
PTime          := Parameter(LineaDeTexto,3);
PConexiones    := Parameter(LineaDeTexto,5);
PLastBlock     := Parameter(LineaDeTexto,6);
PLastBlockHash := Parameter(LineaDeTexto,7);
PSumHash       := Parameter(LineaDeTexto,8);
PPending       := Parameter(LineaDeTexto,9);
PResumenHash   := Parameter(LineaDeTexto,10);
PConStatus     := Parameter(LineaDeTexto,11);
PListenPort    := Parameter(LineaDeTexto,12);
PMNsHash       := Parameter(LineaDeTexto,13);
PMNsCount      := Parameter(LineaDeTexto,14);
BestHashDiff   := Parameter(LineaDeTexto,15);
MnsCheckCount  := Parameter(LineaDeTexto,16);
conexiones[slot].Autentic     :=true;
conexiones[slot].Connections  :=StrToIntDef(PConexiones,1);
conexiones[slot].Version      :=PVersion;
conexiones[slot].Lastblock    :=PLastBlock;
conexiones[slot].LastblockHash:=PLastBlockHash;
conexiones[slot].SumarioHash  :=PSumHash;
conexiones[slot].Pending      :=StrToIntDef(PPending,0);
conexiones[slot].Protocol     :=StrToIntDef(PProtocol,0);
conexiones[slot].offset       :=StrToInt64(PTime)-StrToInt64(UTCTime);
conexiones[slot].lastping     :=UTCTime;
conexiones[slot].ResumenHash  :=PResumenHash;
conexiones[slot].ConexStatus  :=StrToIntDef(PConStatus,0);
conexiones[slot].ListeningPort:=StrToIntDef(PListenPort,-1);
conexiones[slot].MNsHash      :=PMNsHash;
conexiones[slot].MNsCount     :=StrToIntDef(PMNsCount,0);
conexiones[slot].BestHashDiff := BestHashDiff;
conexiones[slot].MNChecksCount:=StrToIntDef(MnsCheckCount,0);
if responder then PTC_SendLine(slot,ProtocolLine(4));
if responder then G_TotalPings := G_TotalPings+1;
End;

// Devuelve la informacion contenida en un ping
function GetPingString():string;
var
  Port : integer = 0;
Begin
if Form1.Server.Active then port := Form1.Server.DefaultPort else port:= -1 ;
result :=IntToStr(GetTotalConexiones())+' '+
         IntToStr(MyLastBlock)+' '+
         MyLastBlockHash+' '+
         MySumarioHash+' '+
         GetPendingCount.ToString+' '+
         MyResumenHash+' '+
         IntToStr(MyConStatus)+' '+
         IntToStr(port)+' '+
         copy(MyMNsHash,0,5)+' '+
         IntToStr(GetMNsListLength)+' '+
         GetNMSData.Diff+' '+
         GetMNsChecksCount.ToString;
End;

// Envia las TXs pendientes al slot indicado
procedure PTC_SendPending(Slot:int64);
var
  contador : integer;
  Encab : string;
  Textline : String;
  TextOrder : String;
  CopyPendingTXs : Array of OrderData;
Begin
Encab := GetPTCEcn;
TextOrder := encab+'ORDER ';
// Send the current best hash
PTC_SendLine(slot,GetPTCEcn+'$BESTHASH '+GetNMSData.Miner+' '+GetNMSData.Hash+' '+(MyLastBlock+1).ToString+' '+(LastBlockData.TimeEnd+10).ToString);

if GetPendingCount > 0 then
   begin
   EnterCriticalSection(CSPending);
   SetLength(CopyPendingTXs,0);
   CopyPendingTXs := copy(PendingTXs,0,length(PendingTXs));
   LeaveCriticalSection(CSPending);
   for contador := 0 to Length(CopyPendingTXs)-1 do
      begin
      Textline := GetStringFromOrder(CopyPendingTXs[contador]);
      if (CopyPendingTXs[contador].OrderType='CUSTOM') then
         begin
         PTC_SendLine(slot,Encab+'$'+TextLine);
         end;
      if (CopyPendingTXs[contador].OrderType='TRFR') then
         begin
         if CopyPendingTXs[contador].TrxLine=1 then TextOrder:= TextOrder+IntToStr(CopyPendingTXs[contador].OrderLines)+' ';
         TextOrder := TextOrder+'$'+GetStringfromOrder(CopyPendingTXs[contador])+' ';
         if CopyPendingTXs[contador].OrderLines=CopyPendingTXs[contador].TrxLine then
            begin
            Setlength(TextOrder,length(TextOrder)-1);
            PTC_SendLine(slot,TextOrder);
            TextOrder := encab+'ORDER ';
            end;
         end;
      end;
   Tolog('Sent '+IntToStr(Length(CopyPendingTXs))+' pendingTxs to '+conexiones[slot].ip);
   SetLength(CopyPendingTXs,0);
   end;
End;

Procedure PTC_SendMNs(Slot:int64);
var
  contador : integer;
  Encab : string;
  Textline : String;
  TextOrder : String;
  CopyMNsArray : Array of TMasternode;
Begin
Encab := GetPTCEcn;
TextOrder := encab+'$REPORTNODE ';
if Length(MNsArray) > 0 then
   begin
   //EnterCriticalSection(CSMNsArray);
   SetLength(CopyMNsArray,0);
   CopyMNsArray := copy(MNsArray,0,length(MNsArray));
   //LeaveCriticalSection(CSMNsArray);
   for contador := 0 to Length(CopyMNsArray)-1 do
      begin
      Textline := GetTextFromMN(CopyMNsArray[contador]);
      PTC_SendLine(slot,TextOrder+TextLine);
      end;
   end;
End;

// Send headers file to peer
Procedure PTC_SendResumen(Slot:int64);
var
  MemStream   : TMemoryStream;
Begin
SetCurrentJob('PTC_SendResumen',true);
MemStream := TMemoryStream.Create;
EnterCriticalSection(CSHeadAccess);
MemStream.LoadFromFile(ResumenFilename);
LeaveCriticalSection(CSHeadAccess);
if conexiones[slot].tipo='CLI' then
   begin
      TRY
      Conexiones[slot].context.Connection.IOHandler.WriteLn('RESUMENFILE');
      Conexiones[slot].context.connection.IOHandler.Write(MemStream,0,true);
      EXCEPT on E:Exception do
         begin
         Form1.TryCloseServerConnection(Conexiones[Slot].context);
         ToExcLog('SERVER: Error sending headers file ('+E.Message+')');
         end;
      END; {TRY}
   end;
if conexiones[slot].tipo='SER' then
   begin
      TRY
      CanalCliente[slot].IOHandler.WriteLn('RESUMENFILE');
      CanalCliente[slot].IOHandler.Write(MemStream,0,true);
      EXCEPT on E:Exception do
         begin
         ToExcLog('CLIENT: Error sending Headers file ('+E.Message+')');
         CerrarSlot(slot);
         end;
      END;{TRY}
   end;
MemStream.Free;
SetCurrentJob('PTC_SendResumen',false);
//ConsoleLinesAdd(LangLine(91));//'Headers file sent'
End;

// Zips the sumary file
Function ZipSumary():boolean;
var
  MyZipFile: TZipper;
  archivename: String;
Begin
result := false;
MyZipFile := TZipper.Create;
MyZipFile.FileName := ZipSumaryFileName;
EnterCriticalSection(CSSumary);
   TRY
   {$IFDEF WINDOWS}
   archivename:= StringReplace(SumarioFilename,'\','/',[rfReplaceAll]);
   {$ENDIF}
   {$IFDEF UNIX}
   archivename:= SumarioFilename;
   {$ENDIF}
   archivename:= StringReplace(archivename,'NOSODATA','data',[rfReplaceAll]);
   MyZipFile.Entries.AddFileEntry(SumarioFilename, archivename);
   MyZipFile.ZipAllFiles;
   result := true;
   EXCEPT ON E:Exception do
      begin
      ToExcLog('Error zipping summary');
      end;
   END{Try};
MyZipFile.Free;
LeaveCriticalSection(CSSumary);
End;

// Zips the sumary file
Function ZipHeaders():boolean;
var
  MyZipFile: TZipper;
  archivename: String;
Begin
result := false;
MyZipFile := TZipper.Create;
MyZipFile.FileName := ZipHeadersFileName;
EnterCriticalSection(CSHeadAccess);
   TRY
   {$IFDEF WINDOWS}
   archivename:= StringReplace(ResumenFilename,'\','/',[rfReplaceAll]);
   {$ENDIF}
   {$IFDEF UNIX}
   archivename:= ResumenFilename;
   {$ENDIF}
   archivename:= StringReplace(archivename,'NOSODATA','data',[rfReplaceAll]);
   MyZipFile.Entries.AddFileEntry(ResumenFilename, archivename);
   MyZipFile.ZipAllFiles;
   result := true;
   EXCEPT ON E:Exception do
      ToExcLog('Error on Zip Headers file: '+E.Message);
   END{Try};
MyZipFile.Free;
LeaveCriticalSection(CSHeadAccess);
End;

// Creates the zip block file
function CreateZipBlockfile(firstblock:integer):string;
var
  MyZipFile: TZipper;
  ZipFileName:String;
  LastBlock : integer;
  contador : integer;
  filename, archivename: String;
Begin
result := '';
LastBlock := FirstBlock + 100; if LastBlock>MyLastBlock then LastBlock := MyLastBlock;
MyZipFile := TZipper.Create;
ZipFileName := BlockDirectory+'Blocks_'+IntToStr(FirstBlock)+'_'+IntToStr(LastBlock)+'.zip';
MyZipFile.FileName := ZipFileName;
EnterCriticalSection(CSBlocksAccess);
   TRY
   for contador := FirstBlock to LastBlock do
      begin
      filename := BlockDirectory+IntToStr(contador)+'.blk';
      {$IFDEF WINDOWS}
      archivename:= StringReplace(filename,'\','/',[rfReplaceAll]);
      {$ENDIF}
      {$IFDEF UNIX}
      archivename:= filename;
      {$ENDIF}
      MyZipFile.Entries.AddFileEntry(filename, archivename);
      end;
   MyZipFile.ZipAllFiles;
   result := ZipFileName;
   EXCEPT ON E:Exception do
      begin
      ToExcLog('Error zipping block files: '+E.Message);
      end;
   end;
LeaveCriticalSection(CSBlocksAccess);
MyZipFile.Free;
End;

// Send Zipped blocks to peer
Procedure PTC_SendBlocks(Slot:integer;TextLine:String);
var
  FirstBlock, LastBlock : integer;
  MyZipFile: TZipper;
  contador : integer;
  MemStream   : TMemoryStream;
  filename, archivename: String;
  GetFileOk  : boolean = false;
  FileSentOk : Boolean = false;
  ZipFileName:String;
Begin
ConsoleLinesAdd('********** DEBUG CHECK **********');
SetCurrentJob('PTC_SendBlocks',true);
FirstBlock := StrToIntDef(Parameter(textline,5),-1)+1;
ZipFileName := CreateZipBlockfile(FirstBlock);
MemStream := TMemoryStream.Create;
   TRY
   MemStream.LoadFromFile(ZipFileName);
   GetFileOk := true;
   EXCEPT on E:Exception do
      begin
      GetFileOk := false;
      ToExcLog('Error on PTC_SendBlocks: '+E.Message);
      end;
   END; {TRY}
   if GetFileOk then
      begin
      if conexiones[Slot].tipo='CLI' then
         begin
            TRY
            Conexiones[Slot].context.Connection.IOHandler.WriteLn('BLOCKZIP');
            Conexiones[Slot].context.connection.IOHandler.Write(MemStream,0,true);
            FileSentOk := true;
            EXCEPT on E:Exception do
               begin
               Form1.TryCloseServerConnection(Conexiones[Slot].context);
               ToExcLog('SERVER: Error sending ZIP blocks file ('+E.Message+')');
               end;
            END; {TRY}
         end;
      if conexiones[Slot].tipo='SER' then
         begin
            TRY
            CanalCliente[Slot].IOHandler.WriteLn('BLOCKZIP');
            CanalCliente[Slot].IOHandler.Write(MemStream,0,true);
            FileSentOk := true;
            EXCEPT on E:Exception do
               begin
               ToExcLog('CLIENT: Error sending ZIP blocks file ('+E.Message+')');
               CerrarSlot(slot);
               END; {TRY}
            end;
         end;
      end;
MemStream.Free;
Trydeletefile(ZipFileName);
SetCurrentJob('PTC_SendBlocks',false);
End;

Procedure INC_PTC_Custom(TextLine:String;connection:integer);
Begin
AddCriptoOp(4,TextLine,'');
StartCriptoThread();
End;

// Procesa una solicitud de customizacion
Procedure PTC_Custom(TextLine:String);
var
  OrderInfo : OrderData;
  Address : String = '';
  OpData : String = '';
  Proceder : boolean = true;
Begin
OrderInfo := Default(OrderData);
OrderInfo := GetOrderFromString(TextLine);
Address := GetAddressFromPublicKey(OrderInfo.Sender);
if address <> OrderInfo.Address then proceder := false;
// La direccion no dispone de fondos
if GetAddressBalance(Address)-GetAddressPendingPays(Address) < Customizationfee then Proceder:=false;
if TranxAlreadyPending(OrderInfo.TrfrID ) then Proceder:=false;
if OrderInfo.TimeStamp < LastBlockData.TimeStart then Proceder:=false;
if TrxExistsInLastBlock(OrderInfo.TrfrID) then Proceder:=false;
if AddressAlreadyCustomized(Address) then Proceder:=false;
If AliasAlreadyExists(OrderInfo.Receiver) then Proceder:=false;
if not VerifySignedString('Customize this '+Address+' '+OrderInfo.Receiver,OrderInfo.Signature,OrderInfo.Sender ) then Proceder:=false;
if proceder then
   begin
   OpData := GetOpData(TextLine); // Eliminar el encabezado
   AddPendingTxs(OrderInfo);
   if form1.Server.Active then OutgoingMsjsAdd(GetPTCEcn+opdata);
   end;
End;

// Verify a transfer
function ValidateTrfr(order:orderdata;Origen:String):integer;
Begin
Result := 0;
if GetAddressBalance(Origen)-GetAddressPendingPays(Origen) < Order.AmmountFee+order.AmmountTrf then
   result:=1
else if TranxAlreadyPending(order.TrfrID ) then
   result:=2
else if Order.TimeStamp < LastBlockData.TimeStart then
   result:=3
else if Order.TimeStamp > LastBlockData.TimeEnd+600 then
   result:=4
else if TrxExistsInLastBlock(Order.TrfrID) then
   result:=5
else if not VerifySignedString(IntToStr(order.TimeStamp)+origen+order.Receiver+IntToStr(order.AmmountTrf)+
   IntToStr(order.AmmountFee)+IntToStr(order.TrxLine),
   Order.Signature,Order.Sender ) then
   result:=6
else if Order.AmmountTrf<0 then
   result := 7
else if Order.AmmountFee<0 then
   result := 8
else if Not IsValidHashAddress(Origen) then
   result := 9
else if ( (order.OrderType='TRFR') and  (Not IsValidHashAddress(Order.Receiver)) ) then
   result := 10
else result := 0;
End;

Function IsOrderIDAlreadyProcessed(OrderText:string):Boolean;
var
  OrderID : string;
  counter : integer;
Begin
result := false;
OrderId := parameter(OrderText,7);
EnterCriticalSection(CSIdsProcessed);
if length(ArrayOrderIDsProcessed) > 0 then
   begin
   for counter := 0 to length(ArrayOrderIDsProcessed)-1 do
      begin
      if ArrayOrderIDsProcessed[counter] = OrderID then
         begin
         result := true;
         break
         end;
      end;
   end;
if result = false then Insert(OrderID,ArrayOrderIDsProcessed,length(ArrayOrderIDsProcessed));
LeaveCriticalSection(CSIdsProcessed);
End;

Procedure INC_PTC_Order(TextLine:String;connection:integer);
var
  numtransfers : integer;
  TrxID : string;
Begin
if not IsOrderIDAlreadyProcessed(TextLine) then
   AddCriptoOp(5,TextLine,'');
StartCriptoThread();
End;

Function PTC_Order(TextLine:String):String;
var
  NumTransfers  : integer;
  TrxArray      : Array of orderdata;
  SenderTrx     : array of string;
  cont          : integer;
  Textbak       : string;
  SendersString : String = '';
  TodoValido    : boolean = true;
  Proceder      : boolean = true;
  ErrorCode     : integer = -1;
  TotalSent     : int64 = 0;
  TotalFee      : int64 = 0;
  RecOrderID    : string = '';
  GenOrderID    : string = '';
Begin
Result := '';
TRY
NumTransfers := StrToInt(Parameter(TextLine,5));
RecOrderId   := Parameter(TextLine,7);
GenOrderID   := Parameter(TextLine,5)+Parameter(TextLine,10);
Textbak := GetOpData(TextLine);
SetLength(TrxArray,0);SetLength(SenderTrx,0);
for cont := 0 to NumTransfers-1 do
   begin
   SetLength(TrxArray,length(TrxArray)+1);SetLength(SenderTrx,length(SenderTrx)+1);
   TrxArray[cont] := default (orderdata);
   TrxArray[cont] := GetOrderFromString(Textbak);
   Inc(TotalSent,TrxArray[cont].AmmountTrf);
   Inc(TotalFee,TrxArray[cont].AmmountFee);
   GenOrderID := GenOrderID+TrxArray[cont].TrfrID;
   if TranxAlreadyPending(TrxArray[cont].TrfrID) then
      begin
      Proceder := false;
      ErrorCode := 98;
      end;
   SenderTrx[cont] := GetAddressFromPublicKey(TrxArray[cont].Sender);
   if SenderTrx[cont] <> TrxArray[cont].Address then
      begin
      proceder := false;
      ErrorCode := 97;
      //ConsoleLinesAdd(format('error: %s <> %s',[SenderTrx[cont],TrxArray[cont].Address ]))
      end;
   if pos(SendersString,SenderTrx[cont]) > 0 then
      begin
      //ConsoleLinesAdd(LangLine(94)); //'Duplicate sender in order'
      Proceder:=false; // hay una direccion de envio repetida
      ErrorCode := 99;
      end;
   SendersString := SendersString + SenderTrx[cont];
   Textbak := copy(textBak,2,length(textbak));
   Textbak := GetOpData(Textbak);
   end;
GenOrderID := GetOrderHash(GenOrderID);
if TotalFee >= GetFee(TotalSent) then
   begin
   //ConsoleLinesAdd(Format('Order fees match : %d >= %d',[TotalFee,GetFee(TotalSent)]))
   end
else
   begin
   //ConsoleLinesAdd(Format('WRONG ORDER FEES : %d >= %d',[TotalFee,GetFee(TotalSent)]));
   TodoValido := false;
   ErrorCode := 100;
   end;
if RecOrderId<>GenOrderID then
   begin
   //ConsoleLinesAdd('<-'+RecOrderId);
   //ConsoleLinesAdd('->'+GenOrderID);
   if mylastblock >= 56000 then TodoValido := false;
   if mylastblock >= 56000 then ErrorCode := 101;
   end;
if TodoValido then
   begin
   for cont := 0 to NumTransfers-1 do
      begin
      ErrorCode := ValidateTrfr(TrxArray[cont],SenderTrx[cont]);
      if ErrorCode>0 then
         begin
         TodoValido := false;
         break;
         end;
      end;
   end;
if not todovalido then Proceder := false;
if proceder then
   begin
   Textbak := GetOpData(TextLine);
   Textbak := GetPTCEcn+'ORDER '+IntToStr(NumTransfers)+' '+Textbak;
   for cont := 0 to NumTransfers-1 do
      AddPendingTxs(TrxArray[cont]);
   if form1.Server.Active then OutgoingMsjsAdd(Textbak);
   U_DirPanel := true;
   Result := Parameter(Textbak,7); // send order ID as result
   end
else
   begin
   if ErrorCode>0 then
      if mylastblock >= 56000 then Result := 'ERROR '+ErrorCode.ToString;
   end;
EXCEPT ON E:EXCEPTION DO
   begin
   ConsoleLinesAdd('****************************************'+slinebreak+'PTC_Order:'+E.Message);
   end;
END; {TRY}
End;

Procedure PTC_AdminMSG(TextLine:String);
var
  msgtime, mensaje, firma, hashmsg : string;
  msgtoshow : string = '';
  contador : integer = 1;
  errored : boolean = false;
Begin
msgtime := parameter(TextLine,5);
mensaje := parameter(TextLine,6);
firma := parameter(TextLine,7);
hashmsg := parameter(TextLine,8);
if AnsiContainsStr(MsgsReceived,hashmsg) then errored := true
else mensaje := StringReplace(mensaje,'_',' ',[rfReplaceAll, rfIgnoreCase]);
if not VerifySignedString(msgtime+mensaje,firma,AdminPubKey) then
   begin
   ToLog('Admin msg wrong sign');
   errored := true;
   end;
if HashMD5String(msgtime+mensaje+firma) <> Hashmsg then
   begin
   ToLog('Admin msg wrong hash');
   errored :=true;
   end;
if not errored then
   begin
   MsgsReceived := MsgsReceived + Hashmsg;
   for contador := 1 to length(mensaje) do
      begin
      if mensaje[contador] = '}' then msgtoshow := msgtoshow+slinebreak
      else msgtoshow := msgtoshow +mensaje[contador];
      end;
   Tolog('Admin message'+slinebreak+
         TimestampToDate(msgtime)+slinebreak+
         msgtoshow);
   form1.MemoLog.Visible:=true;
   OutgoingMsjsAdd(TextLine);
   end;
End;

Procedure PTC_NetReqs(textline:string);
var
  request : integer;
  timestamp : string;
  Direccion : string;
  Bloque: integer;
  ReqHash, ValueHash : string;
  valor,newvalor : string;
  texttosend : string;
  NewValueHash : string;
Begin
request :=  StrToIntDef(parameter(TextLine,5),0);
timestamp :=  parameter(TextLine,6);
Direccion :=  parameter(TextLine,7);
Bloque :=  StrToIntDef(parameter(TextLine,8),0);
ReqHash :=  parameter(TextLine,9);
ValueHash :=  parameter(TextLine,10);
valor  :=  parameter(TextLine,11);
if request = 1 then // hashrate
   begin
   if ( (StrToInt64def(timestamp,0) = LastBlockData.TimeEnd) and
      (Direccion = LastBlockData.AccountMiner) and (bloque=LastBlockData.Number) and
      (RequestAlreadyexists(ReqHash)='') ) then
      begin
      //ConsoleLinesAdd('NETREQ GOT'+slinebreak+IntToStr(request)+' '+timestamp+' '+direccion+' '+IntTostr(bloque)+' '+
      //   ReqHash+' '+ValueHash+' '+valor);
      newvalor := InttoStr(StrToIntDef(valor,0)+Miner_LastHashRate);
      ConsoleLinesAdd('hashrate set to: '+newvalor);
      NewValueHash := HashMD5String(newvalor);
      TextToSend := GetPTCEcn+'NETREQ 1 '+timestamp+' '+direccion+' '+IntToStr(bloque)+' '+
         ReqHash+' '+NewValueHash+' '+newvalor;
      OutgoingMsjsAdd(texttosend);
      UpdateMyRequests(request,timestamp,bloque, ReqHash,ValueHash );
      end
   else if ( (RequestAlreadyexists(ReqHash)<>'') and  (RequestAlreadyexists(ReqHash)<>ValueHash) ) then
      begin
      NewValueHash := HashMD5String(valor);
      TextToSend := GetPTCEcn+'NETREQ 1 '+timestamp+' '+direccion+' '+IntToStr(bloque)+' '+
         ReqHash+' '+NewValueHash+' '+valor;
      OutgoingMsjsAdd(texttosend);
      ConsoleLinesAdd('Now hashrate: '+valor);
      UpdateMyRequests(request,timestamp,bloque, ReqHash,NewValueHash );
      end
   else
      begin
      networkhashrate := StrToInt64def(valor,-1);
      ConsoleLinesAdd('Final hashrate: '+valor);
      if nethashsend=false then
         begin
         TextToSend := GetPTCEcn+'NETREQ 1 '+timestamp+' '+direccion+' '+IntToStr(bloque)+' '+
            ReqHash+' '+ValueHash+' '+valor;
         OutgoingMsjsAdd(texttosend);
         nethashsend:= true;
         end;
      end;
   end
else if request = 2 then // peers
   begin
   if ( (StrToInt64def(timestamp,0) = LastBlockData.TimeEnd) and
      (Direccion = LastBlockData.AccountMiner) and (bloque=LastBlockData.Number) and
      (RequestAlreadyexists(ReqHash)='') ) then
      begin
      newvalor := InttoStr(StrToIntDef(valor,0)+1);
      ConsoleLinesAdd('peers set to: '+newvalor);
      NewValueHash := HashMD5String(newvalor);
      TextToSend := GetPTCEcn+'NETREQ 2 '+timestamp+' '+direccion+' '+IntToStr(bloque)+' '+
         ReqHash+' '+NewValueHash+' '+newvalor;
      OutgoingMsjsAdd(texttosend);
      UpdateMyRequests(request,timestamp,bloque, ReqHash,ValueHash );
      end
   else if ( (RequestAlreadyexists(ReqHash)<>'') and  (RequestAlreadyexists(ReqHash)<>ValueHash) ) then
      begin
      NewValueHash := HashMD5String(valor);
      TextToSend := GetPTCEcn+'NETREQ 2 '+timestamp+' '+direccion+' '+IntToStr(bloque)+' '+
         ReqHash+' '+NewValueHash+' '+valor;
      OutgoingMsjsAdd(texttosend);
      ConsoleLinesAdd('Now peers: '+valor);
      UpdateMyRequests(request,timestamp,bloque, ReqHash,NewValueHash );
      end
   else
      begin
      networkpeers := StrToInt64def(valor,-1);
      ConsoleLinesAdd('Final peers: '+valor);
      if netpeerssend=false then
         begin
         TextToSend := GetPTCEcn+'NETREQ 2 '+timestamp+' '+direccion+' '+IntToStr(bloque)+' '+
            ReqHash+' '+ValueHash+' '+valor;
         OutgoingMsjsAdd(texttosend);
         netpeerssend:= true;
         end;
      end;
   end;
End;

function RequestAlreadyexists(reqhash:string):string;
var
  contador : integer;
Begin
result := '';
if length(ArrayNetworkRequests) > 0 then
   begin
   for contador := 0 to length(ArrayNetworkRequests)-1 do
      begin
      if ArrayNetworkRequests[contador].hashreq = reqhash then
         begin
         result := ArrayNetworkRequests[contador].hashvalue;
         break;
         end;
      end;
   end;
End;

Procedure UpdateMyRequests(tipo:integer;timestamp:string;bloque:integer;hash,hashvalue:string);
var
  contador : integer;
  ExistiaTipo : boolean = false;
Begin
if length(ArrayNetworkRequests)>0 then
   begin
   for contador := 0 to length(ArrayNetworkRequests)-1 do
      begin
      if ArrayNetworkRequests[contador].tipo = tipo then
         begin
         ArrayNetworkRequests[contador].timestamp:=StrToInt64(timestamp);
         ArrayNetworkRequests[contador].block:=bloque;
         ArrayNetworkRequests[contador].hashreq:=hash;
         ArrayNetworkRequests[contador].hashvalue:=hashvalue;
         if tipo = 1 then nethashsend := false;
         if tipo = 2 then netpeerssend := false;
         ExistiaTipo := true;
         end;
      end;
   end;
if not ExistiaTipo then
   begin
   SetLength(ArrayNetworkRequests,length(ArrayNetworkRequests)+1);
   ArrayNetworkRequests[length(ArrayNetworkRequests)-1].tipo := tipo;
   ArrayNetworkRequests[length(ArrayNetworkRequests)-1].timestamp:=StrToInt64(timestamp);
   ArrayNetworkRequests[length(ArrayNetworkRequests)-1].block:=bloque;
   ArrayNetworkRequests[length(ArrayNetworkRequests)-1].hashreq:=hash;
   ArrayNetworkRequests[length(ArrayNetworkRequests)-1].hashvalue:=hashvalue;
   end;
End;

function GetMNfromText(LineText:String):TMasterNode;
var
  Resultado : TMasterNode;
Begin
Resultado.Ip := Parameter(linetext,1);
Resultado.Port     := Parameter(linetext,2).ToInteger;
Resultado.FundAddress     := Parameter(linetext,3);
Resultado.SignAddress     := Parameter(linetext,4);
Resultado.Block     := Parameter(linetext,5).ToInteger;
Resultado.BlockHash     := Parameter(linetext,6);
Resultado.Time     := Parameter(linetext,7);
Resultado.PublicKey     := Parameter(linetext,8);
Resultado.Signature     := Parameter(linetext,9);
Resultado.ReportHash     := Parameter(linetext,10);
result := resultado;
End;

function GetTextFromMN(node:TMasterNode):string;
Begin
result := Node.Ip+' '+
          Node.port.ToString+' '+
          Node.FundAddress+' '+
          Node.SignAddress+' '+
          Node.Block.ToString+' '+
          Node.BlockHash+' '+
          Node.Time+' '+
          Node.PublicKey+' '+
          Node.Signature+' '+
          Node.ReportHash;
End;

function NodeAlreadyadded(Node:TMasterNode):boolean;
var
  counter : integer;
Begin
result := false;
if length(MNsArray) > 0 then
   begin
   for counter := 0 to length(MNsArray)-1 do
      begin
      if MNsArray[counter].ReportHash = node.ReportHash then
         begin
         result := true;
         break;
         end;
      end;
   end;
End;

Function PTC_BestHash(Linea:string):String;
var
  miner,hash,diff,block : string;
  ResultHash : string;
  TimeStamp : string;
  Exitcode : integer = 0;
Begin
Result:= 'False '+GetNMSData.Diff;
Miner := Parameter(Linea,5);
Hash  := Parameter(Linea,6);
block  := Parameter(Linea,7);
TimeStamp  := Parameter(Linea,8);
If StrToIntDef(Block,0)<>LastBlockData.Number+1 then exitcode := 1;
if (StrToInt64Def(TimeStamp,0)) mod 600 > 585 then exitcode:=2;
if not IsValidHashAddress(Miner) then exitcode:=3;
if Hash+Miner = GetNMSData.Hash+GetNMSData.Miner then exitcode:=4;
if ((length(hash)<18) or (length(hash)>33)) then exitcode:=7;
if exitcode>0 then
   begin
   Result := Result+' '+Exitcode.ToString;
   exit;
   end;
ResultHash := NosoHash(Hash+Miner);
Diff := CheckHashDiff(MyLastBlockHash,ResultHash);
if Diff<GetNMSData.Diff then // Better hash
   begin
   SetNMSData(Diff,hash,miner);
   OutgoingMsjsAdd(GetPTCEcn+'$BESTHASH '+Miner+' '+Hash+' '+block+' '+TimeStamp);
   Result:='True '+Diff+' '+ResultHash;
   end
else
   begin
   Result := Result+' 5';
   end;
End;

Procedure PTC_SendUpdateHeaders(Slot:integer;Linea:String);
var
  Block : integer;
Begin
Block := StrToIntDef(Parameter(Linea,5),0);
PTC_SendLine(slot,ProtocolLine(headupdate)+' $'+LastHeaders(Block));
//ConsoleLinesAdd(Format('Blockheaders update sent to %s (%d)',[Conexiones[slot].ip,Block]));
//ConsoleLinesAdd('Blockheaders update sent to '+Conexiones[slot].ip);
End;

Procedure PTC_HeadUpdate(linea:String);
var
  startpos : integer;
  content : string;
  ThisHeader, blockhash, sumhash: String;
  Counter : integer = 0;
  Numero : integer;
Begin
if MyResumenHash = NetResumenHash.Value then exit;
startpos := Pos('$',Linea);
Content := Copy(Linea,Startpos+1,Length(linea));
REPEAT
   ThisHeader := Parameter(Content,counter);
   If thisheader<>'' then
      begin
      ThisHeader := StringReplace(ThisHeader,':',' ',[rfReplaceAll, rfIgnoreCase]);
      Numero := StrToIntDef(Parameter(ThisHeader,0),0);
      blockhash := Parameter(ThisHeader,1);
      sumhash := Parameter(ThisHeader,2);
      AddBlchHead(numero,blockhash,sumhash);
      end;
   inc(counter);
UNTIL ThisHeader='';
MyResumenHash := HashMD5File(ResumenFilename);
if MyResumenHash <> NetResumenHash.Value then
   begin
   ForceCompleteHeadersDownload := true;
   ConsolelinesAdd('Updated headers failed.');
   end
else
   begin
   ConsolelinesAdd('Headers Updated!');
   ForceCompleteHeadersDownload := false;
   end;
End;

Procedure SetNMSData(diff,hash,miner:string);
Begin
EnterCriticalSection(CSNMSData);
if diff = '' then diff := 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF';
NMSData.Diff:= Diff;
NMSData.Hash:=Hash;
NMSData.Miner:=Miner;
LeaveCriticalSection(CSNMSData);
End;

Function GetNMSData():TNMSData;
Begin
EnterCriticalSection(CSNMSData);
Result := NMSData;
LeaveCriticalSection(CSNMSData);
End;

END. // END UNIT

