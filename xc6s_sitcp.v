module xc6s_sitcp (
	LED		        ,
	CLK_P			,
	CLK_N			,
	PHY_RSTn		,		//out	: SITCP reset
//TX
	GMII_GTX_CLK	,		// out:	Tx clock for GbE
	GMII_TX_CLK		,		// in : Tx clock
	GMII_TX_EN		,		// out: Tx enable
	GMII_TXD		,		// out: Tx data[7:0]
	GMII_TX_ER		,		// out: TX error
//RX	
	GMII_RX_CLK		,		// in : Rx clock
	GMII_RX_DV		,		// in : Rx data valid
	GMII_RXD		,		// in : Rx data[7:0]
	GMII_RX_ER		,		// in : Rx error
	
	I2C_SDA			,
	I2C_SCL			,
	GPIO_SWITCH_0			// in : FORCE_DEFAULTn
);

//-------- Input/Output -------------
	output	[3:0]LED;
	input	CLK_P;
	input	CLK_N;
	output	PHY_RSTn;
//TX
	output	GMII_GTX_CLK;
	input	GMII_TX_CLK;			// in : Tx clock
	output	GMII_TX_EN;				// out: Tx enable
	output	[7:0]GMII_TXD;			// out: Tx data[7:0]
	output	GMII_TX_ER;				// out: TX error
//RX	
	input	GMII_RX_CLK;			// in : Rx clock
	input	GMII_RX_DV;				// in : Rx data valid
	input	[7:0]GMII_RXD;			// in : Rx data[7:0]
	input	GMII_RX_ER;				// in : Rx error

	inout	I2C_SDA;
	output	I2C_SCL;
	input	GPIO_SWITCH_0;

	IOBUF	sda_buf( .O(SDI), .I(SDO), .T(SDT), .IO(I2C_SDA) );
	wire	SiTCP_RESET;

//------Clock-----
	wire	CLK_200M_in;
	wire	CLK_100M_int;
	wire	CLK_125M_int;
	wire	CLK_100M;
	wire	CLK_125M;
	wire	PLL_CLKFB;
	wire		LOCKED;
	reg			SYS_RSTn;
	reg		[3:0]LED;
	reg		[10:0]CNT0; 

//Generate_200M//
	IBUFDS	clk_buf(.O(CLK_200M_in),.I(CLK_P),.IB(CLK_N));





//PLL Primitive 200MHz -> 125MHz//
	PLL_BASE #(
		.BANDWIDTH				("LOW"),
  		.CLK_FEEDBACK			("CLKFBOUT"),
		.COMPENSATION			("INTERNAL"),
		.DIVCLK_DIVIDE			(1),
		.CLKFBOUT_MULT			(5),
		.CLKFBOUT_PHASE			(0.000),
		.CLKOUT0_DIVIDE			(8),
		.CLKOUT0_PHASE			(0.000),
		.CLKOUT0_DUTY_CYCLE		(0.500),
		.CLKOUT1_DIVIDE			(10),
		.CLKOUT1_PHASE			(0.000),
		.CLKOUT1_DUTY_CYCLE		(0.500),
		.CLKIN_PERIOD			(5.0),
		.REF_JITTER				(0.005)
	)
	SYSTEM_PLL(
		.CLKFBOUT				(PLL_CLKFB),
		.CLKOUT0				(CLK_125M_int),
		.CLKOUT1				(CLK_100M_int),
		.CLKOUT2				(),
		.CLKOUT3				(),
		.CLKOUT4				(),
		.CLKOUT5				(),
		.CLKFBIN				(PLL_CLKFB),
		.CLKIN					(CLK_200M_in),
		.LOCKED					(LOCKED),
		.RST					(1'b0)
	);

	BUFG	CLK100M_IG(.O(CLK_100M), .I(CLK_100M_int));
	BUFG	CLK125M_IG(.O(CLK_125M), .I(CLK_125M_int));

//SYS_RSTn->off//
	always@(posedge CLK_100M or negedge LOCKED)begin
		if (LOCKED == 1'b0) begin
			CNT0[10:0]	<= 11'd0;
			SYS_RSTn	<= 1'b0;
		end else begin
			CNT0[10:0] <= CNT0[10]? CNT0[10:0]:(CNT0[10:0]+11'd1);
			SYS_RSTn <= CNT0[10];
		end
	end


//------------------------------------------------------------------------------
//     Network Processor
//------------------------------------------------------------------------------
	wire		GMII_GTX_CLK;
	wire		GMII_TX_CLK;			// in : Tx clock
	wire		GMII_TX_EN;				// out: Tx enable
	wire		[7:0]GMII_TXD;			// out: Tx data[7:0]
	wire		GMII_TX_ER;				// out: TX error
//RX	
	wire		GMII_RX_CLK;			// in : Rx clock
	wire		GMII_RX_DV;				// in : Rx data valid
	wire		[7:0]GMII_RXD;			// in : Rx data[7:0]
	wire		GMII_RX_ER;				// in : Rx error
	
	wire		PHY_RSTn;				// out: Reset for PHY active lowz
	
	wire		SiTCP_RST;				// out: Reset for SiTCP and related circuits
	wire		TCP_CLOSE_REQ;			// out: Connection close request
	reg			TCP_CLOSE_ACK;
	wire		[15:0] STATUS_VECTOR;	// out: Core status.[15:0]	
	wire 		[7:0]TCP_RX_DATA;
	wire 		[7:0]TCP_TX_DATA;
	wire 		TCP_RX_WR;
	wire 		TCP_TX_FULL;
	wire		TCP_OPEN_ACK;
	wire		TCP_ERROR;
	wire		[10:0]FIFO_DATA_COUNT;
	wire		FIFO_RD_VALID;
	reg  		[31:0]OFFSET_TEST;
	wire 		[31:0]RBCP_ADDR;
	wire 		[7:0]RBCP_WD;
	reg			[7:0]RBCP_RD;
	reg			RBCP_ACK;
	

	reg		[ 1:0]	RXCNT;
	always@(posedge GMII_RX_CLK or posedge SiTCP_RESET)begin
		if (SiTCP_RESET == 1'b1) begin
			RXCNT[1:0]	<= 2'b00;
		end else begin
			RXCNT[1:0]	<= RXCNT[1:0] + 2'b01;
		end
	end
	reg		[ 2:0]	SYNC_RCT;
	reg				EDGE_DET;
	reg		[ 3:0]	SEL_CNT;
	reg				GMII_1000M;
	always@(posedge CLK_125M)begin
		SYNC_RCT[0]		<= RXCNT[1];
		SYNC_RCT[2:1]	<= SYNC_RCT[1:0];
		EDGE_DET		<= (SYNC_RCT[2:1] == 2'b10);
		SEL_CNT[3:0]	<= EDGE_DET?	4'b1000:	(SEL_CNT[3:0] + {3'b000,SEL_CNT[3]});
		GMII_1000M		<= EDGE_DET?	SEL_CNT[3]:		GMII_1000M;
	end

	wire		GMII_TCLK;
	BUFGMUX		GMIIMUX		(.O(GMII_TCLK),    .I0(GMII_TX_CLK),   .I1(CLK_125M), .S(GMII_1000M));
	ODDR2		GTXCLK_OR	(.Q(GMII_GTX_CLK), .C0(GMII_TCLK), .C1(~GMII_TCLK),  .CE(1'b1), .D0(1'b0), .D1(1'b1), .R(1'b0), .S(1'b0));


	AT93C46_M24C08 #(.SYSCLK_FREQ_IN_MHz(100)) AT93C46_M24C08(
		.AT93C46_CS_IN		(CS),
		.AT93C46_SK_IN		(SK),
		.AT93C46_DI_IN		(DI),
		.AT93C46_DO_OUT		(DO),

		.M24C08_SCL_OUT		(I2C_SCL),
		.M24C08_SDA_OUT		(SDO),
		.M24C08_SDA_IN		(SDI),
		.M24C08_SDAT_OUT	(SDT),

		.RESET_IN			(~SYS_RSTn),
		.SiTCP_RESET_OUT	(SiTCP_RESET),

		.SYSCLK_IN			(CLK_100M)
	);

	WRAP_SiTCP_GMII_XC6S_32K #(
		.TIM_PERIOD			(8'd100				)	// = System clock frequency(MHz), integer only
	)
	SiTCP(
		.CLK				(CLK_100M   	 	),	// in	: System Clock >129MHz
		.RST				(SiTCP_RESET		),	// in	: System reset
// Configuration parameters
		.FORCE_DEFAULTn		(GPIO_SWITCH_0		),	// in	: Load default parameters
		.EXT_IP_ADDR		(32'd0			  	),	// in	: IP address[31:0]
		.EXT_TCP_PORT		(16'd0			  	),	// in	: TCP port #[15:0]
		.EXT_RBCP_PORT		(16'd0				),	// in	: RBCP port #[15:0]
		.PHY_ADDR			(5'd0				),	// in	: PHY-device MIF address[4:0]
// EEPROM
		.EEPROM_CS			(CS					),	// out	: Chip select
		.EEPROM_SK			(SK					),	// out	: Serial data clock
		.EEPROM_DI			(DI					),	// out	: Serial write data
		.EEPROM_DO			(DO					),	// in	: Serial read data
	// user data, intialial values are stored in the EEPROM, 0xFFFF_FC3C-3F
		.USR_REG_X3C		(					),	// out	: Stored at 0xFFFF_FF3C
		.USR_REG_X3D		(					),	// out	: Stored at 0xFFFF_FF3D
		.USR_REG_X3E		(					),	// out	: Stored at 0xFFFF_FF3E
		.USR_REG_X3F		(					),	// out	: Stored at 0xFFFF_FF3F
// MII interface
		.GMII_RSTn			(PHY_RSTn			),	// out	: PHY reset Active low
		.GMII_1000M			(GMII_1000M			),	// in	: GMII mode (0:MII, 1:GMII)
	// TX
		.GMII_TX_CLK		(GMII_TCLK			),	// in	: Tx clock
		.GMII_TX_EN			(GMII_TX_EN			),	// out	: Tx enable
		.GMII_TXD			(GMII_TXD[7:0]		),	// out	: Tx data[7:0]
		.GMII_TX_ER			(GMII_TX_ER			),	// out	: TX error
	// RX
		.GMII_RX_CLK		(GMII_RX_CLK		),	// in	: Rx clock
		.GMII_RX_DV			(GMII_RX_DV			),	// in	: Rx data valid
		.GMII_RXD			(GMII_RXD[7:0]		),	// in	: Rx data[7:0]
		.GMII_RX_ER			(GMII_RX_ER			),	// in	: Rx error
		.GMII_CRS			(1'b0				),	// in	: Carrier sense
		.GMII_COL			(1'b0				),	// in	: Collision detected
	// Management IF
		.GMII_MDC			(					),	// out	: Clock for MDIO
		.GMII_MDIO_IN		(1'b1				),	// in	: Data
		.GMII_MDIO_OUT		(					),	// out	: Data
		.GMII_MDIO_OE		(					),	// out	: MDIO output enable
// User I/F
		.SiTCP_RST			(SiTCP_RST			),	// out	: Reset for SiTCP and related circuits
	// TCP connection control
		.TCP_OPEN_REQ		(1'b0				),	// in	: Reserved input, shoud be 0
		.TCP_OPEN_ACK		(TCP_OPEN_ACK		),	// out	: Acknowledge for open (=Socket busy)
		.TCP_ERROR			(TCP_ERROR			),	// out	: TCP error, its active period is equal to MSL
		.TCP_CLOSE_REQ		(TCP_CLOSE_REQ		),	// out	: Connection close request
		.TCP_CLOSE_ACK		(TCP_CLOSE_ACK		),	// in	: Acknowledge for closing
	// FIFO I/F
		.TCP_RX_WC			({5'b11111,FIFO_DATA_COUNT[10:0]}),	// in	: Rx FIFO write count[15:0] (Unused bits should be set 1)
		.TCP_RX_WR			(TCP_RX_WR			),	// out	: Write enable
		.TCP_RX_DATA		(TCP_RX_DATA[7:0]	),	// out	: Write data[7:0]
		.TCP_TX_FULL		(TCP_TX_FULL		),	// out	: Almost full flag
		.TCP_TX_WR			(FIFO_RD_VALID		),	// in		: Write enable
		.TCP_TX_DATA		(TCP_TX_DATA[7:0]	),	// in	: Write data[7:0]
	// RBCP
		.RBCP_ACT		(						),	// out	: RBCP active
		.RBCP_ADDR		(RBCP_ADDR[31:0]		),	// out	: Address[31:0]
		.RBCP_WD		(RBCP_WD[7:0]		),	// out	: Data[7:0]
		.RBCP_WE		(RBCP_WE			),	// out	: Write enable
		.RBCP_RE		(RBCP_RE			),	// out	: Read enable
		.RBCP_ACK	  	(RBCP_ACK				),	// in	: Access acknowledge
		.RBCP_RD		(RBCP_RD[7:0]		)	// in	: Read data[7:0]
	);	

//RBCP_test
	always@(posedge CLK_100M)begin
	
		if(RBCP_WE)begin
			OFFSET_TEST[31:0]  <= {RBCP_ADDR[31:2],2'b00}+{RBCP_WD[7:0],RBCP_WD[7:0],RBCP_WD[7:0],RBCP_WD[7:0]};
		end

		RBCP_RD[7:0]	<=  ((RBCP_ADDR[1:0]==8'h0) ? OFFSET_TEST[7:0]:8'h0)
								|((RBCP_ADDR[1:0]==8'h1) ? OFFSET_TEST[15:8]:8'h0)
								|((RBCP_ADDR[1:0]==8'h2) ? OFFSET_TEST[23:16]:8'h0)
								|((RBCP_ADDR[1:0]==8'h3) ? OFFSET_TEST[31:24]:8'h0);
		
		RBCP_ACK  <= RBCP_RE;
				
	end


//-----FIFO-----
	fifo_generator_v9_3 fifo_generator_v9_3(
	  .clk		(CLK_100M						),//in	:
	  .rst		(~TCP_OPEN_ACK					),//in	:
	  .din		(TCP_RX_DATA[7:0]				),//in	:
	  .wr_en	(TCP_RX_WR						),//in	:
	  .full		(								),//out	:
	  .dout		(TCP_TX_DATA[7:0]				),//out	:
	  .valid	(FIFO_RD_VALID					),//out	:active hi
	  .rd_en	(~TCP_TX_FULL					),//in	:
	  .empty	(								),//out	:
	  .data_count(FIFO_DATA_COUNT[10:0]			)//out	:[10:0]
	);



//-----LED_test-----

	reg [27:0]CNT4;
	reg [27:0]CNT5;
	reg [27:0]CNT6;
	reg [27:0]CNT7;
	reg [27:0]CNT8;

//LED_reset//
	always@(posedge GMII_RX_CLK or posedge SiTCP_RESET)begin
		if (SiTCP_RESET == 1'b1) begin
			CNT4[27:0]	<= 28'd0;
			CNT5[27:0]	<= 28'd0;
			CNT6[27:0]	<= 28'd0;
			CNT7[27:0]	<= 28'd0;
			CNT8[27:0]	<= 28'd0;
			LED[3:0]	<= 4'd0;
		end else begin
			CNT4[27:0]		<= (PHY_RSTn      == 1'b0)?	{1'b1,27'd0}:	(CNT4[27:0] - (CNT4[27]?	28'd1:	28'd0));
			LED[0]			<= CNT4[27];
			CNT5[27:0]		<= (TCP_OPEN_ACK  == 1'b1)?	{1'b1,27'd0}:	(CNT5[27:0] - (CNT5[27]?	28'd1:	28'd0));
			LED[1]			<= CNT5[27];
			CNT6[27:0]		<= (TCP_CLOSE_REQ == 1'b1)?	{1'b1,27'd0}:	(CNT6[27:0] - (CNT6[27]?	28'd1:	28'd0));
			LED[2]			<= CNT6[27];
			CNT7[27:0]		<= (TCP_ERROR     == 1'b1)?	{1'b1,27'd0}:	(CNT7[27:0] - (CNT7[27]?	28'd1:	28'd0));
			LED[3]			<= CNT7[27];
			CNT8[27:0]		<= CNT8[27:0] + ((TCP_CLOSE_REQ == CNT8[27])?	28'd0:	28'd1);
			TCP_CLOSE_ACK	<= CNT8[27];
		end
	end

/*
	always@(posedge CLK_100M)begin
		LED[7] <= PHY_RSTn ? 1'b1 : 1'b0;
		LED[6] <= SiTCP_RST ? 1'b1 : 1'b0;
		LED[5] <= GMII_TX_EN ? 1'b1 : 1'b0;
		LED[4] <= GMII_RX_DV ? 1'b1 : 1'b0;
		LED[3:1] <= STATUS_VECTOR[3:1];
	end
*/



endmodule

