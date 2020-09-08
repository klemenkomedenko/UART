module uart (
  i_clk,
  i_rst,
  //tx signals
  i_tx_data,
  i_tx_valid,
  o_tx_busy,
  //rx signals
  o_rx_data,
  o_rx_valid,
  // UART inteface
  o_tx,
  i_rx
  );

  parameter DATA_WIDTH = 8;
  parameter FREQ = 10000000;
  parameter BAUD = 9200;


  input  wire                  i_clk;
  input  wire                  i_rst;
  input  wire [DATA_WIDTH-1:0] i_tx_data;
  input  wire                  i_tx_valid;
  output wire                  o_tx_busy;
  output wire [DATA_WIDTH-1:0] o_rx_data;
  output wire                  o_rx_valid;
  output wire                  o_tx;
  input  wire                  i_rx;

  rx_uart #(.DATA_WIDTH(DATA_WIDTH), .FREQ(FREQ), .BAUD(BAUD)) utt_rx(
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_rx(i_rx),
    .o_data(o_rx_data),
    .o_valid(o_rx_valid)
    );

  tx_uart #(.DATA_WIDTH(DATA_WIDTH), .FREQ(FREQ), .BAUD(BAUD)) utt_tx(
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_data(i_tx_data),
    .i_valid(i_tx_valid),
    .o_busy(o_tx_busy),
    .o_tx(o_tx)
    );

endmodule // uart









module rx_uart (
  i_clk,
  i_rst,
  i_rx,
  o_data,
  o_valid
  );

  parameter DATA_WIDTH = 8;
  parameter FREQ = 10000000;
  parameter BAUD = 9200;

  input wire                  i_clk;
  input wire                  i_rst;
  input wire                  i_rx;
  output reg  [DATA_WIDTH-1:0] o_data;
  output reg                  o_valid;


  parameter
  IDLE       = 6'b000001,
  WAIT_START = 6'b000010,
  START      = 6'b000100,
  DATA       = 6'b001000,
  STOP       = 6'b010000,
  END        = 6'b100000;

  reg [5:0] next_rx_uart;
  reg [5:0] rx_uart;

  reg [1:0] r_rx_ed;
  wire w_rx_ed;
  reg r_baud_clk;
  reg [31:0] r_baud_cnt;
  reg [DATA_WIDTH-1:0] r_dataBuff;

  reg r_en_rx;
  reg r_en_data_rx;

  always @ (posedge i_clk) begin
    if (i_rst) begin
      r_rx_ed <= 2'b11;
    end else begin
      r_rx_ed[0] <= i_rx;
      r_rx_ed[1] <= r_rx_ed[0];
    end
  end

  assign w_rx_ed = !r_rx_ed[0] & r_rx_ed[1];

  always @ (posedge i_clk) begin
    if (i_rst) begin
      r_baud_cnt <= 0;
      r_baud_clk <= 1'b0;
    end else begin
      if (w_rx_ed & !r_en_rx) begin
        r_baud_cnt <= FREQ/BAUD/2;
        r_baud_clk <= 1'b0;
      end else if (r_en_rx) begin
        if (!r_baud_cnt) begin
          r_baud_cnt <= FREQ/BAUD;
          r_baud_clk <= 1'b1;
        end else begin
          r_baud_cnt <= r_baud_cnt - 1'b1;
          r_baud_clk <= 1'b0;
        end
      end else begin
        r_baud_cnt <= r_baud_cnt;
        r_baud_clk <= 1'b0;
      end
    end
  end


  always @ ( * ) begin
    next_rx_uart <= rx_uart;
    r_en_rx <= 1'b0;
    r_en_data_rx <= 1'b0;
    o_valid <= 1'b0;
    case (rx_uart)
      IDLE: begin
        next_rx_uart <= WAIT_START;
      end

      WAIT_START: begin
        if (w_rx_ed) begin
          next_rx_uart <= START;
        end else begin
          next_rx_uart <= WAIT_START;
        end
      end

      START: begin
        r_en_rx <= 1'b1;
        if (r_baud_clk) begin
          next_rx_uart <= DATA;
        end else begin
          next_rx_uart <= START;
        end
      end

      DATA: begin
        r_en_rx <= 1'b1;
        r_en_data_rx <= 1'b1;
        if ((r_dataBuff == 1) & r_baud_clk) begin
          next_rx_uart <= STOP;
        end  else begin
          next_rx_uart <= DATA;
        end
      end

      STOP: begin
        r_en_rx <= 1'b1;
        if (r_baud_clk & i_rx) begin
          next_rx_uart <= END;
        end else begin
          next_rx_uart <= STOP;
        end
      end

      END : begin
        o_valid <= 1'b1;
        next_rx_uart <= WAIT_START;
      end

      default: begin
        next_rx_uart <= IDLE;
      end
    endcase
  end

  always @ (posedge i_clk) begin
    if (i_rst) begin
      rx_uart <= IDLE;
    end else begin
      rx_uart <= next_rx_uart;
    end
  end

  always @ (posedge i_clk) begin
    if (i_rst) begin
      r_dataBuff <= 0;
      o_data <= 0;
    end else begin
      if (w_rx_ed & !r_en_rx) begin
        r_dataBuff <= {DATA_WIDTH{1'b1}};
        o_data <= 0;
      end else begin
        if (r_en_data_rx & r_baud_clk) begin
          r_dataBuff <= {1'b0, r_dataBuff[DATA_WIDTH-1:1]};
          o_data <= {r_rx_ed[1], o_data[DATA_WIDTH-1:1]};
        end else begin
          r_dataBuff <= r_dataBuff;
          o_data <= o_data;
        end
      end
    end
  end

  // This code allows you to see state names in simulation
`ifndef SYNTHESIS
  reg [127:0] rx_statename;
  always @* begin
    case (rx_uart)
      IDLE     :
        rx_statename = "IDLE";
      WAIT_START     :
        rx_statename = "WAIT_START";
      START     :
        rx_statename = "START";
      DATA     :
        rx_statename = "DATA";
      STOP     :
        rx_statename = "STOP";
      END     :
        rx_statename = "END";
      default  :
        rx_statename = "IDLE";
    endcase
  end
`endif

endmodule // rx_uart










module tx_uart (
  i_clk,
  i_rst,
  i_data,
  i_valid,
  o_tx,
  o_busy
  );

  parameter DATA_WIDTH = 8;
  parameter FREQ = 10000000;
  parameter BAUD = 9200;

  input wire                  i_clk;
  input wire                  i_rst;
  input wire [DATA_WIDTH-1:0] i_data;
  input wire                  i_valid;
  output reg                  o_tx;
  output wire                 o_busy;

  parameter
  IDLE      = 5'b00001,
  WAIT_DATA = 5'b00010,
  START     = 5'b00100,
  DATA      = 5'b01000,
  STOP      = 5'b10000;

  reg [4:0] next_tx_uart;
  reg [4:0] tx_uart;
  reg       tx_run;
  reg       tx_data;

  reg        r_baud_clk;
  reg [31:0] r_baud_cnt;

  reg [DATA_WIDTH-1:0] r_dataBuff;
  reg [DATA_WIDTH-1:0] r_data;

  always @ (posedge i_clk) begin
    if (i_rst) begin
      r_baud_clk <= 0;
      r_baud_cnt <= FREQ/BAUD;
    end else begin
      if (tx_run) begin
        if (!r_baud_cnt) begin
          r_baud_cnt <= FREQ/BAUD;
          r_baud_clk <= 1'b1;
        end else begin
          r_baud_cnt <= r_baud_cnt - 1'b1;
          r_baud_clk <= 1'b0;
        end
      end else begin
        r_baud_cnt <= FREQ/BAUD;
        r_baud_clk <= 1'b0;
      end
    end
  end

  always @ ( * ) begin
    next_tx_uart <= tx_uart;
    tx_run <= 1'b0;
    tx_data <= 1'b0;
    o_tx <= 1'b1;

    case (tx_uart)
      IDLE: begin
        next_tx_uart <= WAIT_DATA;
      end

      WAIT_DATA: begin
        if (i_valid) begin
          next_tx_uart <= START;
        end else begin
          next_tx_uart <= WAIT_DATA;
        end
      end

      START: begin
        tx_run <= 1'b1;
        o_tx <= 1'b0;
        if (r_baud_clk) begin
          next_tx_uart <= DATA;
        end else begin
          next_tx_uart <= START;
        end
      end

      DATA: begin
        tx_run <= 1'b1;
        tx_data <= 1'b1;
        o_tx <= r_data[0];
        if (r_baud_clk & (!r_dataBuff)) begin
          next_tx_uart <= STOP;
        end else begin
          next_tx_uart <= DATA;
        end
      end

      STOP: begin
        tx_run <= 1'b1;
        o_tx <= 1'b1;
        if (r_baud_clk) begin
          next_tx_uart <= WAIT_DATA;
        end else begin
          next_tx_uart <= STOP;
        end
      end

      default: begin
        next_tx_uart <= IDLE;
      end
    endcase
  end

  always @ (posedge i_clk) begin
    if (i_rst) begin
      tx_uart <= IDLE;
    end else begin
      tx_uart <= next_tx_uart;
    end
  end

  always @ (posedge i_clk) begin
    if (i_rst) begin
      r_dataBuff <= 0;
      r_data <= 0;
    end else begin
      if (tx_run) begin
        if (r_baud_clk & tx_data) begin
          r_dataBuff <= {1'b0, r_dataBuff[DATA_WIDTH-1:1]};
          r_data <= {1'b0, r_data[DATA_WIDTH-1:1]};
        end else begin
          r_dataBuff <= r_dataBuff;
          r_data <= r_data;
        end
      end else begin
        if (i_valid) begin
          r_dataBuff <= {DATA_WIDTH{1'b1}};
          r_data <= i_data;
        end else begin
          r_dataBuff <= r_dataBuff;
          r_data <= r_data;
        end
      end
    end
  end

  assign o_busy = tx_run;

endmodule // tx_uart
