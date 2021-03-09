module spi_prog(
	//spi_signal
	input  wire i_sck,
	input  wire i_copi,
	output wire o_cipo,
	input  wire i_cs,
	input wire 	 clk,
	//open8 internals signal
	output wire [15:0] o_Address,
	output wire [7:0]  o_Wr_Data,
	output wire        o_Wr_En,
	output wire        o_Rd_En,
	input  wire [7:0]  i_Rd_Data,
	//control
	input wire         wb_rst,
	output wire        cpu_reset,
	output wire        system_reset
);
   //wire i_rst_cpu;
   //wire i_rst_system;
     
   wire         [32:0] spi_out;
   wire         [16:0] spi_in;
   
   wire  i_nrst;
   
   assign i_nrst = ~wb_rst;
   //assign i_rst_system = system_reset || wb_rst;
   //assign i_rst_cpu = cpu_reset || i_rst_system;
	
spi #(.outputs(4), .inputs (2)) spi ( //max 255
    .i_sck(i_sck),
    .i_copi(i_copi),
    .o_cipo(o_cipo),
    .i_cs(i_cs),
    .i_nrst(i_nrst),
    .rout(spi_out),
    .rin(spi_in)
    );
 
spi_slave  spi_slave(
	.clk(clk),
	.o_Address(o_Address),
	.o_Wr_Data(o_Wr_Data),
	.o_Wr_En(o_Wr_En),
	.o_Rd_En(o_Rd_En),
	.i_Rd_Data(i_Rd_Data),
	.cpu_reset(cpu_reset),
	.spi_reset(i_nrst),//i_nrst
	.system_reset(system_reset),
	.spi_out(spi_out),
	.spi_in(spi_in)
	);

endmodule 
