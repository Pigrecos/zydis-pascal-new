unit Main;

interface

{$POINTERMATH ON}

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.Buttons,

  Zydis.Apis,
  Zydis.Enums,
  Zydis.Types,
  Zydis.Status,
  Zydis.Decoder.Types,
  Zydis.Formatter.Types,
  Zydis.Disassembler.Types,
  Zydis.Encoder.Types;

const
  EXIT_FAILURE = 1;

type
  TRetFunc = function: ZyanU64;

type
  TForm1 = class(TForm)
    btnDisassembler: TBitBtn;
    mmo1: TMemo;
    btnDisassemblerSimple: TBitBtn;
    btnEncode: TBitBtn;
    procedure btnDisassemblerSimpleClick(Sender: TObject);
    procedure btnDisassemblerClick(Sender: TObject);
    procedure btnEncodeClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

var
  offset : ZyanUSize = 0;
  runtime_address: ZyanU64 = $007FFFFFFF400000;
  decoder : TZydisDecoder;
  Formatter : TZydisFormatter;
  instruction : TZydisDecodedInstruction;
  operands : Array [0..ZYDIS_MAX_OPERAND_COUNT -1] of TZydisDecodedOperand;
  len : ZyanUSize;
  buffer: array[0..255] of AnsiChar;
  Data: array[0..24] of ZyanU8 = ($51, $8D, $45, $FF, $50, $FF,
    $75, $0C, $FF, $75, $08, $FF, $15, $A0, $A5, $48, $76, $85, $C0,
    $0F, $88, $FC, $DA, $02, $00);



implementation

{$R *.dfm}

procedure TForm1.btnDisassemblerClick(Sender: TObject);
begin
    ZydisDecoderInit(@decoder, ZYDIS_MACHINE_MODE_LONG_64, ZYDIS_STACK_WIDTH_64);
    ZydisFormatterInit(@formatter, ZYDIS_FORMATTER_STYLE_INTEL);

    Initialize(operands);
    Initialize(instruction);
    Initialize(buffer);

    mmo1.Clear;

    len := sizeof(data);
    while (offset < Length(Data)) and (ZYAN_SUCCESS(ZydisDecoderDecodeFull(@decoder, @data[offset], len - offset,instruction, operands))) do
    begin
        // Format & print the binary instruction structure to human-readable format
        ZydisFormatterFormatInstruction(@formatter, @instruction, @operands,
            instruction.operand_count_visible, buffer, SizeOf(buffer), runtime_address, nil);

        var s := Format('%.16X  %s', [runtime_address,UTF8ToString(buffer)]);
        mmo1.Lines.Add(s);

        offset := offset + instruction.length;

        runtime_address := runtime_address +instruction.length;
    end;

end;

procedure TForm1.btnDisassemblerSimpleClick(Sender: TObject);
var
  instr : TZydisDisassembledInstruction;
begin
    Initialize(instr);

    mmo1.Clear;

    len := sizeof(data);
    while (offset < Length(Data)) and (ZYAN_SUCCESS(ZydisDisassembleIntel(ZYDIS_MACHINE_MODE_LONG_64, runtime_address, @data[offset], SizeOf(data) - offset, instr))) do
    begin
      var s := Format('%.16X  %s', [runtime_address,UTF8ToString(instr.text)]);
      mmo1.Lines.Add(s);

      offset := offset + instr.info.length;

      runtime_address := runtime_address +instruction.length;
    end;
end;

(**************)
// ENCODE
(**************)

procedure ExpectSuccess(status: ZyanStatus);
begin
    if ZYAN_FAILED(status) then
    begin
        Form1.mmo1.Lines.Add(Format('Something failed: %0x', [IntToHex(status, 8)]));
        Halt(EXIT_FAILURE);
    end;
end;

procedure AppendInstruction(req: PZydisEncoderRequest; var buffer: PZyanU8; var buffer_length: ZyanUSize);
var
  instr_length: ZyanUSize;
begin
    instr_length := buffer_length;
    ExpectSuccess(ZydisEncoderEncodeInstruction(req, buffer, @instr_length));
    Inc(buffer, instr_length);
    Dec(buffer_length, instr_length);
end;

function AssembleCode(buffer: PZyanU8; buffer_length: ZyanUSize): ZyanUSize;
var
  write_ptr: PZyanU8;
  remaining_length: ZyanUSize;
  req: TZydisEncoderRequest;
begin
    write_ptr := buffer;
    remaining_length := buffer_length;

    // Assemble `mov rax, $1337`.
    FillChar(req, SizeOf(TZydisEncoderRequest), 0);

    req.mnemonic := ZYDIS_MNEMONIC_MOV;
    req.machine_mode := ZYDIS_MACHINE_MODE_LONG_64;
    req.operand_count := 2;
    req.operands[0].type_ := ZYDIS_OPERAND_TYPE_REGISTER;
    req.operands[0].reg.Value := ZYDIS_REGISTER_RAX;
    req.operands[1].type_ := ZYDIS_OPERAND_TYPE_IMMEDIATE;
    req.operands[1].imm.u := $1337;
    AppendInstruction(@req, write_ptr, remaining_length);

    // Assemble `ret`.
    FillChar(req, SizeOf(TZydisEncoderRequest), 0);
    req.mnemonic := ZYDIS_MNEMONIC_RET;
    req.machine_mode := ZYDIS_MACHINE_MODE_LONG_64;
    AppendInstruction(@req, write_ptr, remaining_length);

    Result := buffer_length - remaining_length;
end;

procedure TForm1.btnEncodeClick(Sender: TObject);
var
  page_size, alloc_size: ZyanUSize;
  buffer, aligned: PZyanU8;
  length: ZyanUSize;
  func_ptr: TRetFunc;
  Result: ZyanU64;
  {$IFDEF  WINDOWS}OldProtection: DWORD;{$ENDIF}
  i: integer;
begin
    // Allocate 2 pages of memory. We won't need nearly as much, but it simplifies
    // re-protecting the memory to RWX later.
    page_size  := $1000;
    alloc_size := page_size * 2;
    buffer     := AllocMem(alloc_size);

    // Assemble our function.
    length := AssembleCode(buffer, alloc_size);

    mmo1.Clear;
    // Print a hex-dump of the assembled code.
    mmo1.Lines.Add('Created byte-code:');
    for i := 0 to length - 1 do
      mmo1.Lines.Add(Format('%.2X ', [buffer[i]]));
     mmo1.Lines.Add('');

    {$IFDEF CPUX64}
    // Align pointer to typical page size.
    aligned := PZyanU8(NativeUInt(buffer) and not (page_size - 1));

    { Only Enable for Dynamic linked Zydis library cuz it needs libc }
    //ExpectSuccess(ZyanMemoryVirtualProtect(aligned, alloc_size, ZYAN_PAGE_EXECUTE_READWRITE));

    // Re-protect the heap region as RWX. Don't do this at home, kids!
    {$IfDef UNIX}
    if Fpmprotect(aligned, alloc_size, PROT_EXEC or PROT_READ or PROT_WRITE) = 0 then
    {$ELSE}
    if VirtualProtect(aligned, alloc_size, PAGE_EXECUTE_READWRITE, OldProtection) then
    {$EndIf}
    begin
      // Create a function pointer for our buffer.
      func_ptr := TRetFunc(buffer);

      // Call the function!
      result := func_ptr();
      mmo1.Lines.Add(Format('Return value of JITed code: 0x%s', [IntToHex(result, 16)]));
    end;
    {$ENDIF}
    Freemem(buffer);

end;

end.
