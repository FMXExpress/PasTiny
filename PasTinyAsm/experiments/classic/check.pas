program check;
uses TNYNET;
var crc,t:longint; e:integer; q,a:string;
begin
 val(paramstr(2),crc,e);
 if (e<>0) or not TryModel(paramstr(1),crc) then halt(1);
 AllocMemory; Creativity:=0;
 while not eof do begin readln(q);Think(q,a,t,nil,nil);writeln(a) end;
 ReleaseMemory
end.
