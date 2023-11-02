object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 'Zydis(Examples)'
  ClientHeight = 576
  ClientWidth = 455
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  TextHeight = 15
  object btnDisassembler: TBitBtn
    Left = 8
    Top = 543
    Width = 129
    Height = 25
    Caption = 'Disassembler'
    TabOrder = 0
    OnClick = btnDisassemblerClick
  end
  object mmo1: TMemo
    Left = 8
    Top = 16
    Width = 433
    Height = 521
    Color = clInfoBk
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clNavy
    Font.Height = -13
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
    TabOrder = 1
  end
  object btnDisassemblerSimple: TBitBtn
    Left = 160
    Top = 543
    Width = 129
    Height = 25
    Caption = 'Disassembler Simple'
    TabOrder = 2
    OnClick = btnDisassemblerSimpleClick
  end
  object btnEncode: TBitBtn
    Left = 312
    Top = 543
    Width = 129
    Height = 25
    Caption = 'Assembler'
    TabOrder = 3
    OnClick = btnEncodeClick
  end
end
