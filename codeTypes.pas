unit codeTypes;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fgl, strutils;

type
  TImplCategory = (icJArrayToObjectArray, icJArrayToSimpleArray, icJArrayListToList, icJHashMapToMap, icJHashSetToSet, icArrayToJArray, icListToJArrayList, icMapToJHashMap, icSetToJHashSet);

  TFieldTypeCategory = (ftcSimple, ftcString, ftcObject);

  { TFieldType }

  TFieldType = class
  public
    fieldType: string;
    fieldSignature: string;
    fieldPackageName: string;
    fieldFullPackageName: string;
    fieldCategory: TFieldTypeCategory;
    function ToString: ansistring; override;
  end;

  { TFieldInfo }

  TFieldInfo = class
  public
    fieldName: string;
    isArray: Boolean;
    isList: Boolean;
    isMap: Boolean;
    isSet: Boolean;
    baseType: TFieldType;
    genericType1: TFieldType;
    genericType2: TFieldType;
    destructor Destroy; override;
    function ToString: ansistring; override;
  end;

  TFieldList = specialize TFPGList<TFieldInfo>;
  TFieldMap = specialize TFPGMap<string, TFieldInfo>;

  { TClassInfo }

  TClassInfo = class
  public
    ktClassName: string;
    packageName: string;
    fullPackageName: string;
    constructorSig: string;
    fieldList: TFieldList;
    destructor Destroy; override;
    function ToString: ansistring; override;
  end;

type

  { TTypeConvert }

  TTypeConvert = class
  public
    // kotlin
    class function KTypeIsArray(AType: string): Boolean;
    class function KTypeIsList(AType: string): Boolean;
    class function KTypeIsMap(AType: string): Boolean;
    class function KTypeIsSet(AType: string): Boolean;
    class function KTypeToSimpleKType(AType: string): string;
    class procedure KTypeExtractMapKTypes(AType: string; out p1: string; out p2: string);

    // jni
    class function KTypeToJNIType(AType: string): string;
    class function KTypeToJObjectType(AType: string): string;
    class function KTypeToJObjectGetName(AType: string): string;
    class function KTypeToJObjectGetSig(AType: string): string;
    class function KTypeToJObjectConstructorSig(AType: string): string;

    // common
    class function KTypeIsBasicType(AType: string): Boolean;
    class function KTypeToCallMethod(AType: string): string;
    class function ToFirstUpper(AField: string): string;

    // cpp
    class function KTypeToCType(AType: string): string;
    class function KFieldToGetName(AField: string): string;
    class function KFieldToSetName(AField: string): string;

    // pas
    class function KTypeToPType(AType: string): string;

  end;

implementation

{ TFieldType }

function TFieldType.ToString: ansistring;
var
  catStr: string;
begin
  case fieldCategory of
  ftcString: catStr:= 'String';
  ftcObject: catStr:= 'Object';
  else
    catStr:= 'Simple';
  end;
  Result:= Format('    type: %s'#13#10'    sig: %s'#13#10'    pkg: %s'#13#10'    fullPkg: %s'#13#10'    category: %s'#13#10, [
    fieldType, fieldSignature, fieldPackageName, fieldFullPackageName, catStr
  ]);
end;

{ TFieldInfo }

destructor TFieldInfo.Destroy;
begin
  if (baseType <> nil) then baseType.Free;
  if (genericType1 <> nil) then genericType1.Free;
  if (genericType2 <> nil) then genericType2.Free;
  inherited Destroy;
end;

function TFieldInfo.ToString: ansistring;
var
  bstr: string = '';
  gstr1: string = '';
  gstr2: string = '';
begin
  if (baseType <> nil) then bstr:= baseType.ToString;
  if (genericType1 <> nil) then gstr1:= genericType1.ToString;
  if (genericType2 <> nil) then gstr2:= genericType2.ToString;
  Result := Format('  name: %s'#13#10'  array: %s'#13#10'  list: %s'#13#10'  map: %s'#13#10'  set: %s'#13#10'  base: '#13#10'%s'#13#10'  generic1:'#13#10'%s'#13#10'  generic2:'#13#10'%s'#13#10, [
    fieldName, IfThen(isArray, 'TRUE', 'FALSE'), IfThen(isList, 'TRUE', 'FALSE'), IfThen(isMap, 'TRUE', 'FALSE'), IfThen(isSet, 'TRUE', 'FALSE'),
    bstr, gstr1, gstr2]);
end;

{ TClassInfo }

destructor TClassInfo.Destroy;
var
  i: Integer;
begin
  if (fieldList <> nil) then begin
    for i := fieldList.Count -1 downto 0 do begin
      fieldList[i].Free;
    end;
    fieldList.Free;
  end;
  inherited Destroy;
end;

function TClassInfo.ToString: ansistring;
var
  i: Integer;
  s: string = '';
begin
  // to string
  for i := 0 to fieldList.Count - 1 do begin
    s += fieldList[i].ToString;
  end;
  Result := Format('ClassName: %s'#13#10'Package: %s'#13#10'Full Package: %s'#13#10'Fields:'#13#10'%s'#13#10'constructor: %s'#13#10, [
  ktClassName, packageName, fullPackageName, s, constructorSig
  ]);
end;

{ TTypeConvert }

class function TTypeConvert.KTypeIsArray(AType: string): Boolean;
begin
  Result := AType.StartsWith('Array<');
end;

class function TTypeConvert.KTypeIsList(AType: string): Boolean;
begin
  Result := AType.Contains('List<');
end;

class function TTypeConvert.KTypeIsMap(AType: string): Boolean;
begin
  Result := AType.Contains('Map<');
end;

class function TTypeConvert.KTypeIsSet(AType: string): Boolean;
begin
  Result := AType.Contains('Set<');
end;

class function TTypeConvert.KTypeToSimpleKType(AType: string): string;
begin
  AType:= AType.Substring(AType.IndexOf('<')).Trim.Trim(['<', '>']);
  Exit(AType.Trim)
end;

class procedure TTypeConvert.KTypeExtractMapKTypes(AType: string; out
  p1: string; out p2: string);
var
  arr: TStringArray;
begin
  AType:= AType.Substring(AType.IndexOf('<')).Trim.Trim(['<', '>']);
  arr := AType.Split([',']);
  p1 := arr[0].Trim;
  p2 := arr[1].Trim;
end;

class function TTypeConvert.KTypeToJNIType(AType: string): string;
var
  r: string = '';
begin
  if (AType = 'Int') then r := 'int';
  if (AType = 'Double') then r := 'double';
  if (AType = 'Boolean') then r := 'boolean';
  if (AType = 'Byte') then r := 'byte';
  if (AType = 'Char') then r := 'char';
  if (AType = 'Short') then r := 'short';
  if (AType = 'Long') then r := 'long';
  if (AType = 'Float') then r := 'float';
  Exit(r);
end;

class function TTypeConvert.KTypeToJObjectType(AType: string): string;
var
  r: string = '';
begin
  if (AType = 'Int') then r := 'java.lang.Integer';
  if (AType = 'Double') then r := 'java.lang.Double';
  if (AType = 'Boolean') then r := 'java.lang.Boolean';
  if (AType = 'Byte') then r := 'java.lang.Byte';
  if (AType = 'Char') then r := 'java.lang.Character';
  if (AType = 'Short') then r := 'java.lang.Short';
  if (AType = 'Long') then r := 'java.lang.Long';
  if (AType = 'Float') then r := 'java.lang.Float';
  if (r = '') then r := AType;
  Exit(r);
end;

class function TTypeConvert.KTypeToJObjectGetName(AType: string): string;
var
  r: string = '';
begin
  if (AType = 'Int') then r := 'intValue';
  if (AType = 'Double') then r := 'doubleValue';
  if (AType = 'Boolean') then r := 'booleanValue';
  if (AType = 'Byte') then r := 'byteValue';
  if (AType = 'Char') then r := 'charValue';
  if (AType = 'Short') then r := 'shortValue';
  if (AType = 'Long') then r := 'longValue';
  if (AType = 'Float') then r := 'floatValue';
  Exit(r);
end;

class function TTypeConvert.KTypeToJObjectGetSig(AType: string): string;
var
  r: string = '';
begin
  if (AType = 'Int') then r := '()I';
  if (AType = 'Double') then r := '()D';
  if (AType = 'Boolean') then r := '()Z';
  if (AType = 'Byte') then r := '()B';
  if (AType = 'Char') then r := '()C';
  if (AType = 'Short') then r := '()S';
  if (AType = 'Long') then r := '()J';
  if (AType = 'Float') then r := '()F';
  Exit(r);
end;

class function TTypeConvert.KTypeToJObjectConstructorSig(AType: string): string;
var
  r: string = '';
begin
  if (AType = 'Int') then r := '(I)V';
  if (AType = 'Double') then r := '(D)V';
  if (AType = 'Boolean') then r := '(Z)V';
  if (AType = 'Byte') then r := '(B)V';
  if (AType = 'Char') then r := '(C)V';
  if (AType = 'Short') then r := '(S)V';
  if (AType = 'Long') then r := '(J)V';
  if (AType = 'Float') then r := '(F)V';
  Exit(r);
end;

class function TTypeConvert.KTypeIsBasicType(AType: string): Boolean;
var
  r: Boolean = False;
begin
  if (AType = 'Int') then r := True;
  if (AType = 'Double') then r := True;
  if (AType = 'Boolean') then r := True;
  if (AType = 'Byte') then r := True;
  if (AType = 'Char') then r := True;
  if (AType = 'Short') then r := True;
  if (AType = 'Long') then r := True;
  if (AType = 'Float') then r := True;
  Exit(r);
end;

class function TTypeConvert.KTypeToCType(AType: string): string;
const
  HEAD_ARRAY = 'Array<';
  HEAD_LIST = 'List<';
  HEAD_MAP = 'Map<';
  HEAD_SET = 'Set<';
var
  r: string = '';
begin
  if (AType.StartsWith(HEAD_ARRAY)) then AType:= AType.Replace(HEAD_ARRAY, '', [rfIgnoreCase, rfReplaceAll]).Trim.Trim(['>']);
  if (AType.Contains(HEAD_LIST)) then AType:= AType.Substring(AType.IndexOf(HEAD_LIST) + HEAD_LIST.Length).Trim.Trim(['>']);
  if (AType.Contains(HEAD_MAP)) then AType:= AType.Substring(AType.IndexOf(HEAD_MAP) + HEAD_MAP.Length).Trim.Trim(['>']);
  if (AType.Contains(HEAD_SET)) then AType:= AType.Substring(AType.IndexOf(HEAD_SET) + HEAD_SET.Length).Trim.Trim(['>']);
  if (AType = 'Int') then r := 'int';
  if (AType = 'Double') then r := 'double';
  if (AType = 'Boolean') then r := 'bool';
  if (AType = 'Byte') then r := 'unsigned char';
  if (AType = 'Char') then r := 'char';
  if (AType = 'Short') then r := 'short';
  if (AType = 'Long') then r := 'long long';
  if (AType = 'Float') then r := 'float';
  if (AType = 'String') then r := 'string';
  if (r = '') then r := AType + '*';
  Exit(r);
end;

class function TTypeConvert.KTypeToPType(AType: string): string;
const
  HEAD_ARRAY = 'Array<';
  HEAD_LIST = 'List<';
  HEAD_MAP = 'Map<';
  HEAD_SET = 'Set<';
var
  r: string = '';
begin
  if (AType.StartsWith(HEAD_ARRAY)) then AType:= AType.Replace(HEAD_ARRAY, '', [rfIgnoreCase, rfReplaceAll]).Trim.Trim(['>']);
  if (AType.Contains(HEAD_LIST)) then AType:= AType.Substring(AType.IndexOf(HEAD_LIST) + HEAD_LIST.Length).Trim.Trim(['>']);
  if (AType.Contains(HEAD_MAP)) then AType:= AType.Substring(AType.IndexOf(HEAD_MAP) + HEAD_MAP.Length).Trim.Trim(['>']);
  if (AType.Contains(HEAD_SET)) then AType:= AType.Substring(AType.IndexOf(HEAD_SET) + HEAD_SET.Length).Trim.Trim(['>']);
  if (AType = 'Int') then r := 'Integer';
  if (AType = 'Double') then r := 'Double';
  if (AType = 'Boolean') then r := 'Boolean';
  if (AType = 'Byte') then r := 'Byte';
  if (AType = 'Char') then r := 'Char';
  if (AType = 'Short') then r := 'ShortInt';
  if (AType = 'Long') then r := 'Int64';
  if (AType = 'Float') then r := 'Extended';
  if (AType = 'String') then r := 'String';
  if (r = '') then r := 'T' + AType;
  Exit(r);
end;

class function TTypeConvert.KTypeToCallMethod(AType: string): string;
var
  r: string = '';
begin
  if (AType = 'Int') then r := 'CallIntMethod';
  if (AType = 'Double') then r := 'CallDoubleMethod';
  if (AType = 'Boolean') then r := 'CallBooleanMethod';
  if (AType = 'Byte') then r := 'CallByteMethod';
  if (AType = 'Char') then r := 'CallCharMethod';
  if (AType = 'Short') then r := 'CallShortMethod';
  if (AType = 'Long') then r := 'CallLongMethod';
  if (AType = 'Float') then r := 'CallFloatMethod';
  if (r = '') then r := 'CallObjectMethod';
  Exit(r);
end;

class function TTypeConvert.KFieldToGetName(AField: string): string;
begin
  Result := 'get' + UpperCase(AField[1]) + AField.Substring(1);
end;

class function TTypeConvert.KFieldToSetName(AField: string): string;
begin
  Result := 'set' + UpperCase(AField[1]) + AField.Substring(1);
end;

class function TTypeConvert.ToFirstUpper(AField: string): string;
begin
  Result := UpperCase(AField[1]) + AField.Substring(1);
end;

end.

