// Register Addresses

localparam JOYP		= 16'hFF00;

localparam SB		= 16'hFF01;
localparam SC		= 16'hFF02;

localparam DIV      = 16'hFF04;
localparam TIMA     = 16'hFF05;
localparam TMA      = 16'hFF06;
localparam TAC      = 16'hFF07;

localparam IF       = 16'hFF0F;

localparam NR10     = 16'hFF10;
localparam NR11     = 16'hFF11;
localparam NR12     = 16'hFF12;
localparam NR13     = 16'hFF13;
localparam NR14     = 16'hFF14;
localparam UNUSED0	= 16'hFF15;

localparam NR21     = 16'hFF16;
localparam NR22     = 16'hFF17;
localparam NR23     = 16'hFF18;
localparam NR24     = 16'hFF19;

localparam NR30     = 16'hFF1A;
localparam NR31     = 16'hFF1B;
localparam NR32     = 16'hFF1C;
localparam NR33     = 16'hFF1D;
localparam NR34     = 16'hFF1E;
localparam UNUSED1 	= 16'hFF1F;
localparam SRAM_LOW = 16'hFF30;
localparam SRAM_HIGH= 16'hFF3F;

localparam NR41     = 16'hFF20;
localparam NR42     = 16'hFF21;
localparam NR43     = 16'hFF22;
localparam NR44     = 16'hFF23;

localparam NR50     = 16'hFF24;
localparam NR51     = 16'hFF25;
localparam NR52     = 16'hFF26;
localparam UNUSED2  = 16'hFF27;
localparam UNUSED3  = 16'hFF28;
localparam UNUSED4  = 16'hFF29;
localparam UNUSED5  = 16'hFF2A;
localparam UNUSED6  = 16'hFF2B;
localparam UNUSED7  = 16'hFF2C;
localparam UNUSED8  = 16'hFF2D;
localparam UNUSED9  = 16'hFF2E;
localparam UNUSEDA  = 16'hFF2F;

localparam LCDC     = 16'hFF40;
localparam STAT     = 16'hFF41;
localparam SCY      = 16'hFF42;
localparam SCX      = 16'hFF43;
localparam LY       = 16'hFF44;
localparam LYC      = 16'hFF45;
localparam DMA      = 16'hFF46;
localparam BGP      = 16'hFF47;
localparam OBP0     = 16'hFF48;
localparam OBP1     = 16'hFF49;
localparam WY       = 16'hFF4A;
localparam WX       = 16'hFF4B;
localparam KEY0     = 16'hFF4C;
localparam KEY1     = 16'hFF4D;
localparam VBK      = 16'hFF4F;
localparam BANK     = 16'hFF50;

localparam HDMA1    = 16'hFF51;
localparam HDMA2    = 16'hFF52;
localparam HDMA3    = 16'hFF53;
localparam HDMA4    = 16'hFF54;
localparam HDMA5    = 16'hFF55;

localparam BGPI     = 16'hFF68;
localparam BGPD     = 16'hFF69;
localparam OBPI     = 16'hFF6A;
localparam OBPD     = 16'hFF6B;
localparam OPRI     = 16'hFF6C;

localparam SVBK     = 16'hFF70;

localparam PCM12    = 16'hFF76;
localparam PCM34    = 16'hFF77;

localparam IE       = 16'hFFFF;