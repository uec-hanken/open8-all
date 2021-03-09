module spi #(parameter outputs = 9, parameter inputs = 5)( //max 255
    input  wire i_sck,
    input  wire i_copi,
    output wire o_cipo,
    input  wire i_cs,
    input  wire i_nrst,
    output reg  [outputs*8-1:0] rout,
    input  wire [inputs*8-1:0]  rin
    );
    //read  00000001
    //write 00000010
    genvar i;
    genvar unpk_idx;
    
    wire [7:0] wdata;
    reg  [7:0] rdata;
    wire [7:0] addr;
    wire we ;
    wire re ;
    reg re_reg;
    
    wire [outputs-1:0]		en_o;		// The enables for Output
	wire [inputs-1:0]		en_i;		// The enables for Input
    
    wire [8-1:0] inputs_a [0:inputs-1];
    
    reg [23:0] copi_buffer; 
    reg [4:0] bit_count;
    
    always @(posedge i_sck or negedge i_nrst)
     if (i_nrst == 1'b0) re_reg <= 1'd0;
     //else if (i_cs == 1'b1) re_reg <= 1'd0;//????
     else           re_reg <= re;
    
    always @(posedge i_sck or negedge i_nrst)
     if (i_nrst == 1'b0) copi_buffer <= 24'd0;
     else if (i_cs == 1'b1) copi_buffer <= 24'd0;
     else if (re_reg == 1'b1) copi_buffer <= {copi_buffer[22:8],rdata[0],rdata[1],rdata[2],rdata[3],rdata[4],rdata[5],rdata[6],rdata[7],i_copi};
     else           copi_buffer <= {copi_buffer[22:0],i_copi};
     
    always @(posedge i_sck or negedge i_nrst)
     if (i_nrst == 1'b0)    bit_count <= 5'd0;
     else if (i_cs == 1'b1) bit_count <= 5'd0;
     else if (bit_count >= 5'd23) bit_count <= 5'd0;
     else                   bit_count <= bit_count + 5'd1;
     
    always @(posedge i_sck or negedge i_nrst)
     if (i_nrst == 1'b0)    rdata <= 8'd0;
     else if (re == 1'b1)   rdata <=  inputs_a[addr[2:0]]; //inputs_a[addr];  //to avoid a warning
     else                   rdata <= rdata;
     
	generate 
		for (unpk_idx=0; unpk_idx<(inputs); unpk_idx=unpk_idx+1) begin : inputs_to_array // <-- example block name
			assign inputs_a[unpk_idx][(8-1):0] = rin[(8*unpk_idx+(8-1)):(8*unpk_idx)]; 
		end 
	endgenerate
	
    generate
		for (i = 0; i < outputs; i = i + 1)
		begin : decoder_outputs
			always @ (posedge i_sck or negedge i_nrst) begin
				if ( i_nrst == 1'b0 )         rout[(i+1)*8 - 1:i*8] <= 8'b0; // RESET
				else if(en_o[i] == 1'b1)      rout[(i+1)*8 - 1:i*8] <= wdata; // WRITE
				else rout[(i+1)*8 - 1:i*8] <= rout[(i+1)*8 - 1:i*8]; // NOTHING
			end
		end
	endgenerate
	
    assign we = (bit_count == 5'd23) && copi_buffer[22:21]== 2'b01; //flip due to shift register
    assign re = (bit_count == 5'd23) && copi_buffer[22:21]== 2'b10; //flip due to shift register
    assign addr ={copi_buffer[7],copi_buffer[8],copi_buffer[9],copi_buffer[10],copi_buffer[11],copi_buffer[12],copi_buffer[13],copi_buffer[14]};
    assign wdata ={i_copi,copi_buffer[0],copi_buffer[1],copi_buffer[2],copi_buffer[3],copi_buffer[4],copi_buffer[5],copi_buffer[6]};
    assign en_o = we ? (1 << addr):{outputs{1'b0}};
    assign en_i = re ?(1 <<  addr):{inputs{1'b0}};
    
    `ifndef VERILATOR
    	assign o_cipo = (i_cs== 1'b1 || i_nrst == 1'b0 )? 1'bz : copi_buffer[23]; 
    `else
    	assign o_cipo = (i_cs== 1'b1 || i_nrst == 1'b0 )? 1'b0 : copi_buffer[23];  //simulation on verilator cant drive z state
    `endif
endmodule
