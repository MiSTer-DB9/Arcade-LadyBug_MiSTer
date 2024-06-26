//============================================================================
//  Arcade: Lady Bug
//
//  Port to MiSTer
//  Copyright (C) 2017 Sorgelig
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================


module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	output	USER_OSD,
	output	[1:0] USER_MODE,
	input	[7:0] USER_IN,
	output	[7:0] USER_OUT,
	input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;

assign VGA_F1 = 0;
assign VGA_SCALER = 0;
assign VGA_DISABLE = 0;
wire         CLK_JOY = CLK_50M;         //Assign clock between 40-50Mhz
wire   [2:0] JOY_FLAG  = {status[30],status[31],status[29]}; //Assign 3 bits of status (31:29) o (63:61)
wire         JOY_CLK, JOY_LOAD, JOY_SPLIT, JOY_MDSEL;
wire   [5:0] JOY_MDIN  = JOY_FLAG[2] ? {USER_IN[6],USER_IN[3],USER_IN[5],USER_IN[7],USER_IN[1],USER_IN[2]} : '1;
wire         JOY_DATA  = JOY_FLAG[1] ? USER_IN[5] : '1;
assign       USER_OUT  = JOY_FLAG[2] ? {3'b111,JOY_SPLIT,3'b111,JOY_MDSEL} : JOY_FLAG[1] ? {6'b111111,JOY_CLK,JOY_LOAD} : '1;
assign       USER_MODE = JOY_FLAG[2:1] ;
assign       USER_OSD  = joydb_1[10] & joydb_1[6];

assign LED_USER = ioctl_download;
assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;
assign AUDIO_MIX = 0;
assign HDMI_FREEZE = 0;
assign FB_FORCE_BLANK = 0;

wire [1:0] ar = status[20:19];

assign VIDEO_ARX = (!ar) ? ((status[2] | landscape) ? 12'd400 : 12'd261) : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? ((status[2] | landscape) ? 12'd261 : 12'd400) : 12'd0;

`include "build_id.v" 
localparam CONF_STR = {
	"A.LADYBG;;",
	"H0OJK,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"H1H0O2,Orientation,Vert,Horz;",
	"H1H0O6,Vertical flip,Off,On;",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"-;",
	"H2OR,Autosave Hiscores,Off,On;",
	"-;",
	"OUV,UserIO Joystick,Off,DB9MD,DB15 ;",
	"OT,UserIO Players, 1 Player,2 Players;",
	"-;",
	"P1,Pause options;",
	"P1OP,Pause when OSD is open,On,Off;",
	"P1OQ,Dim video after 10s,On,Off;",
	"-;",
	"DIP;",
	"-;",
	"R0,Reset;",
	"J1,Fire,Bomb,Start 1P,Start 2P,Coin,Pause;",
	"jn,A,B,Start,Select,R,L;",
	"V,v",`BUILD_DATE
};

// Read DIPs from MRA
reg [7:0] m_dip[8];	// Active-LOW
always @(posedge clk_sys) if(ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3]) m_dip[ioctl_addr[2:0]] <= ioctl_dout;

// Read game index from MRA
localparam mod_ladybug			= 0;
localparam mod_snapjack			= 1;
localparam mod_cosmicavenger	= 2;
reg [7:0] mod = 0;
always @(posedge clk_sys) if (ioctl_wr & (ioctl_index==1)) mod <= ioctl_dout;

////////////////////   CLOCKS   ///////////////////

wire clk_sys,clk_40;
wire pll_locked;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_40),
	.outclk_1(clk_sys), //20
	.locked(pll_locked)
);

///////////////////////////////////////////////////

wire [31:0] status;
wire  [1:0] buttons;
wire        forced_scandoubler;
wire        direct_video;

wire        ioctl_download;
wire        ioctl_upload;
wire        ioctl_upload_req;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_din;

wire [15:0] joy1_USB,joy2_USB;
wire [15:0] joy1 = joystick_0;
wire [15:0] joy2 = joystick_1;

wire [21:0] gamma_bus;

// CO S2 S1 U D L R 
wire [31:0] joystick_0 = joydb_1ena ? {joydb_1[11]|(joydb_1[10]&joydb_1[5]),joydb_1[9],joydb_1[10],joydb_1[5:0]} : joy1_USB;
wire [31:0] joystick_1 = joydb_2ena ? {joydb_2[11]|(joydb_2[10]&joydb_2[5]),joydb_2[10],joydb_2[9],joydb_2[5:0]} : joydb_1ena ? joy1_USB : joy2_USB;

wire [15:0] joydb_1 = JOY_FLAG[2] ? JOYDB9MD_1 : JOY_FLAG[1] ? JOYDB15_1 : '0;
wire [15:0] joydb_2 = JOY_FLAG[2] ? JOYDB9MD_2 : JOY_FLAG[1] ? JOYDB15_2 : '0;
wire        joydb_1ena = |JOY_FLAG[2:1]              ;
wire        joydb_2ena = |JOY_FLAG[2:1] & JOY_FLAG[0];

//----BA 9876543210
//----MS ZYXCBAUDLR
reg [15:0] JOYDB9MD_1,JOYDB9MD_2;
joy_db9md joy_db9md
(
  .clk       ( CLK_JOY    ), //40-50MHz
  .joy_split ( JOY_SPLIT  ),
  .joy_mdsel ( JOY_MDSEL  ),
  .joy_in    ( JOY_MDIN   ),
  .joystick1 ( JOYDB9MD_1 ),
  .joystick2 ( JOYDB9MD_2 )	  
);

//----BA 9876543210
//----LS FEDCBAUDLR
reg [15:0] JOYDB15_1,JOYDB15_2;
joy_db15 joy_db15
(
  .clk       ( CLK_JOY   ), //48MHz
  .JOY_CLK   ( JOY_CLK   ),
  .JOY_DATA  ( JOY_DATA  ),
  .JOY_LOAD  ( JOY_LOAD  ),
  .joystick1 ( JOYDB15_1 ),
  .joystick2 ( JOYDB15_2 )	  
);

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.buttons(buttons),
	.status(status),
	.status_menumask({~hs_configured,landscape,direct_video}),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),
	.direct_video(direct_video),
	.video_rotated(video_rotated),

	.ioctl_download(ioctl_download),
	.ioctl_upload(ioctl_upload),
	.ioctl_upload_req(ioctl_upload_req),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_din(ioctl_din),
	.ioctl_index(ioctl_index),

	.joystick_0(joy1_USB),
	.joystick_1(joy2_USB),
	.joy_raw(joydb_1[5:0] | joydb_2[5:0]),
);


wire m_up		= joy1[3];
wire m_down		= joy1[2];
wire m_left		= joy1[1];
wire m_right	= joy1[0];
wire m_fire		= joy1[4];
wire m_bomb		= joy1[5];
wire m_up_2		= joy2[3];
wire m_down_2	= joy2[2];
wire m_left_2	= joy2[1];
wire m_right_2	= joy2[0];
wire m_fire_2	= joy2[5];
wire m_bomb_2	= joy2[6];
wire m_start1	= joy1[6] | joy2[6];
wire m_start2	= joy1[7] | joy2[7];
wire m_coin		= joy1[8] | joy2[8];
wire m_pause	= joy1[9] | joy2[9];
reg [1:0] but_up_s;
reg [1:0] but_down_s;
reg [1:0] but_left_s;
reg [1:0] but_right_s;

// One-directional control generators for Lady Bug
wire [3:0] m_joyod_1;
wire [3:0] m_joyod_2;
joyonedir jod_1(clk_sys,1'b0,{m_up,m_down,m_left,m_right},m_joyod_1);
joyonedir jod_2(clk_sys,1'b0,{m_up_2,m_down_2,m_left_2,m_right_2},m_joyod_2);

// Set game specific options
reg landscape;
always @(*) begin
	landscape <= 1'b0;
	but_up_s		<= {m_up_2,m_up};
	but_down_s	<= {m_down_2,m_down};
	but_left_s	<= {m_left_2,m_left};
	but_right_s	<= {m_right_2,m_right};

	case (mod)
		mod_ladybug:
			begin
				but_up_s		<= {m_joyod_2[3],m_joyod_1[3]};
				but_down_s	<= {m_joyod_2[2],m_joyod_1[2]};
				but_left_s	<= {m_joyod_2[1],m_joyod_1[1]};
				but_right_s	<= {m_joyod_2[0],m_joyod_1[0]};
			end
		mod_snapjack:
			begin
				landscape	<= 1'b1;
			end
		mod_cosmicavenger:
			begin
				landscape	<= 1'b1;
			end
		default: ;
	endcase
end

wire no_rotate = status[2] | direct_video | landscape;


// PAUSE SYSTEM
wire				pause_cpu;
wire [5:0]		rgb_out;
pause #(2,2,2,20) pause (
	.*,
	.user_button(m_pause),
	.pause_request(hs_pause),
	.options(~status[26:25])
);

wire hblank, vblank;
wire hs, vs;
wire ce_vid;
wire [1:0] r,g, b;

reg ce_pix;
always @(posedge clk_40) begin
        reg [2:0] div;

        div <= div + 1'd1;
        ce_pix <= !div;
end

wire rotate_ccw = 1;
wire video_rotated;
wire flip = status[6];
screen_rotate screen_rotate (.*);

arcade_video #(240,6) arcade_video
(
        .*,
        .clk_video(clk_40),

        .RGB_in(rgb_out),
        .HBlank(hblank),
        .VBlank(vblank),
        .HSync(hs),
        .VSync(vs),

        .fx(status[5:3])
);

wire [7:0] audio;
assign AUDIO_L = {audio, 8'd0};
assign AUDIO_R = AUDIO_L;
assign AUDIO_S = 1;

wire rom_download = ioctl_download & (ioctl_index==2'd1|| ioctl_index==2'd2);
wire reset = RESET | status[0] | buttons[1] | rom_download;

ladybug ladybug
(
	.CLK_IN(clk_sys),
	.I_RESET(reset),
	.O_PIXCE(ce_vid),

	.O_VIDEO_R(r),
	.O_VIDEO_G(g),
	.O_VIDEO_B(b),
	.O_VSYNC(vs),
	.O_HSYNC(hs),
	.O_VBLANK(vblank),
	.O_HBLANK(hblank),

	.dn_addr(ioctl_addr[15:0]),
	.dn_data(ioctl_dout),
	.dn_wr(ioctl_wr),
	.dn_index(ioctl_index),

	.O_AUDIO(audio),
	
	.but_coin_s(~{1'b0,m_coin}),
	.but_fire_s(~{m_fire_2,m_fire}),
	.but_bomb_s(~{m_bomb_2,m_bomb}),
	.but_tilt_s(~{1'b0,1'b0}),
	.but_select_s(~{m_start2,m_start1}),
	.but_up_s(~but_up_s),
	.but_down_s(~but_down_s),
	.but_left_s(~but_left_s),
	.but_right_s(~but_right_s),
	.dip_block_1_s(~m_dip[0]),

	.pause(pause_cpu),

	.hs_address(hs_address),
	.hs_data_out(hs_data_out),
	.hs_data_in(hs_data_in),
	.hs_write(hs_write_enable),
	.hs_access(hs_access_read|hs_access_write)
);

// HISCORE SYSTEM
// --------------
wire [15:0]hs_address;
wire [7:0] hs_data_in;
wire [7:0] hs_data_out;
wire hs_write_enable;
wire hs_access_read;
wire hs_access_write;
wire hs_pause;
wire hs_configured;

hiscore #(
	.HS_ADDRESSWIDTH(16),
	.CFG_ADDRESSWIDTH(3),
	.CFG_LENGTHWIDTH(2)
) hi (
	.*,
	.clk(clk_sys),
	.paused(pause_cpu),
	.autosave(status[27]),
	.ram_address(hs_address),
	.data_from_ram(hs_data_out),
	.data_to_ram(hs_data_in),
	.data_from_hps(ioctl_dout),
	.data_to_hps(ioctl_din),
	.ram_write(hs_write_enable),
	.ram_intent_read(hs_access_read),
	.ram_intent_write(hs_access_write),
	.pause_cpu(hs_pause),
	.configured(hs_configured)
);

endmodule


module joyonedir
(
        input        clk,
        input        dis,
        input  [3:0] indir,
        output [3:0] outdir
);

reg  [3:0] mask = 0;
reg  [3:0] in1,in2;
wire [3:0] innew = in1 & ~in2;

assign outdir = in1 & mask;

always @(posedge clk) begin

        in1 <= indir;
        in2 <= in1;

        if(innew[0]) mask <= 1;
        if(innew[1]) mask <= 2;
        if(innew[2]) mask <= 4;
        if(innew[3]) mask <= 8;

        if(!(indir & mask) || dis) mask <= '1;
end


endmodule
