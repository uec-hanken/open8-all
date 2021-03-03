module spi_slave
     (
      input wire 	 clk,
      output wire [15:0] o_Address,
      output wire [7:0]  o_Wr_Data,
      output wire        o_Wr_En,
     	output wire        o_Rd_En,
    	input  wire [7:0]  i_Rd_Data,
      output wire        cpu_reset,
      output wire        system_reset,
      input wire         [32:0] spi_out,
      output wire        [16:0] spi_in,
      input wire         spi_reset
    );

      wire [15:0] addr;
      wire [7:0] data_out;
      reg  start;
      wire pulse_start;
      wire we;
      wire re;
      wire reset_cpu;
      wire reset_system;

      wire [7:0] data_in;
      wire is_busy;
      wire enable;
		wire re_enable;

      reg [7:0]data;
      reg [2:0]status;

      assign addr = spi_out[31:16];
      assign data_out = spi_out[15:8];
      assign reset_cpu = spi_out[0];
      assign reset_system = spi_out[1];
      assign we = spi_out[3];
      assign re = ~spi_out[3];
      //assign start = spi_out[2];

      assign o_Address = addr;
      assign o_Wr_Data = data_out;
      assign o_Wr_En  = we & enable;
      assign o_Rd_En  = re & enable;

      assign cpu_reset  = reset_cpu;
      assign system_reset  = reset_system;

      always @(posedge clk)
      begin
               start <=spi_out[2];
      end
		

      always @(posedge clk or negedge spi_reset)
      begin
          if (spi_reset == 1'b0) begin
               data <= 8'h0;
               status <= 3'h0;
          end else begin
               status <={is_busy, system_reset,reset_cpu};
               if (re_enable == 1 && re == 1) 
               begin
               data <= i_Rd_Data;
               end
          end
      end

      assign spi_in = {data,5'd0,status};
      assign pulse_start = spi_out[2] &  ~start;

      fsm fsm
	(
	.clk(clk), 
	.rst(spi_reset), 
	.i_start(pulse_start), 
	.i_cpu_reset(reset_cpu), 
	.o_enable(enable),
	.o_re_enable(re_enable),
	.o_busy(is_busy)
	);


endmodule
