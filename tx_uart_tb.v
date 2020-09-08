module tx_uart_tb ();


parameter SYSCLK_PERIOD_16MHz = 100;// 20MHZ
parameter DATA_WIDTH = 8;
parameter FREQ = 10000000;
parameter BAUD = 9200;

reg i_clk;
reg i_rst;
reg [DATA_WIDTH-1:0] i_data;
reg i_send;
wire o_busy;
wire o_tx;

wire [7:0] o_data;
wire o_valid;


//////////////////////////////////////////////////////////////////////
// Reset Pulse
//////////////////////////////////////////////////////////////////////
initial
begin
     i_rst = 1'b1;
     i_clk = 1'b0;
     i_data = 0;
     i_send = 0;
     #(SYSCLK_PERIOD_16MHz * 10 );
     i_rst = 1'b0;
     #(SYSCLK_PERIOD_16MHz * 20 );
     i_data = 8'hF0;
     i_send = 1;
     #(SYSCLK_PERIOD_16MHz);
     i_send = 0;
     @(negedge o_busy);
     #(SYSCLK_PERIOD_16MHz);
     i_data = 8'h5A;
     i_send = 1;
     #(SYSCLK_PERIOD_16MHz);
     i_send = 0;



end


//////////////////////////////////////////////////////////////////////
// Clock Driver
//////////////////////////////////////////////////////////////////////
always @(i_clk)
    #((SYSCLK_PERIOD_16MHz / 2.0)) i_clk <= !i_clk;
//
// tx_uart #(.DATA_WIDTH(DATA_WIDTH), .FREQ(FREQ), .BAUD(BAUD)) utt(
//   .i_clk(i_clk),
//   .i_rst(i_rst),
//   .i_data(i_data),
//   .i_send(i_send),
//   .o_busy(o_busy),
//   .o_tx(tx)
//   );

  uart utt_uart(
    .i_clk(i_clk),
    .i_rst(i_rst),
    //tx signals
    .i_tx_data(i_data),
    .i_tx_valid(i_send),
    .o_tx_busy(o_busy),
    //rx signals
    .o_rx_data(o_data),
    .o_rx_valid(o_valid),
    // UART inteface
    .o_tx(tx),
    .i_rx(tx)
    );

endmodule // tx_uart_tb
