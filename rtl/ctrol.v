module control (
    input   	        sys_clk        ,
    input       	    rst_n      ,

    input	[7:0]       fifo_in       ,
    input               fifo_in_vld   ,

    input               ready      , 

    output  [7:0]       fifo_out        ,
    output	            fifo_out_vld          
);
wire     [7:0]      data ;
wire     	        rdreq;
wire             	wrreq;
wire            	empty;
wire          	    full ;
reg                 flag ;
wire              [7:0]  q;
wire              valid;


//assign fifo_out_vld = rd_en_test;
assign fifo_out = q;


assign data=fifo_in;
assign wrreq=fifo_in_vld&&~full;

assign rdreq=ready&&~empty;  

reg sata;

//assign fifo_out_vld =(sata==1'b0)?(~valid_reg[1] && valid_reg[0]):valid_reg_1[1];
assign fifo_out_vld =~valid_reg[1] && valid_reg[0];
//assign fifo_out_vld = valid_reg[1];
reg [1:0]valid_reg;
always @(posedge sys_clk or negedge rst_n) begin
    if (!rst_n) begin
        valid_reg <= 2'b0;
    end
    else /*if(sata==1'b0)*/ begin
       valid_reg[0] <= valid;
       valid_reg[1] <= valid_reg[0];
    end
end

//reg [1:0]valid_reg_1;


//always @(posedge sys_clk or negedge rst_n) begin
//    if (!rst_n) begin
//        valid_reg_1 <= 2'b0;
//    end
//    else if(sata== 1'b1 && ~empty )begin
//       valid_reg_1[0] <= rd_en_test;
//       valid_reg_1[1] <= valid_reg_1[0];
//       end
//end

//reg [7:0] fifo_out_1;
//reg [7:0] fifo_out_2;
//assign fifo_out=fifo_out_2;
//always @(posedge sys_clk or negedge rst_n) begin
//    if (!rst_n) begin
//        fifo_out_1 <= 'd0;
//        fifo_out_2 <= 'd0;
//    end
//    else begin
//       fifo_out_1 <= q;
//       fifo_out_2 <= fifo_out_1;
//    end
//end

// ¼ÆÊý
//reg [15:0]  count;
//reg empty_1;
//reg empty_2;
//wire r_empty;
//wire f_empty;

//assign r_empty = empty_1 && ~empty_2;
//assign f_empty = ~empty_1 && empty_2;

//reg     count_signal;

//always @(posedge sys_clk or negedge rst_n) begin
//    if (!rst_n) begin
//        empty_1 <= 'd0;
//        empty_2 <= 'd0;
//    end
//    else begin
//        empty_1 <= empty;
//        empty_2 <=empty_1;
//    end
//end

//always @(posedge sys_clk or negedge rst_n) begin
//    if (!rst_n) begin
//        count_signal <= 1'b0;
//    end
//    else if(f_empty) begin
//        count_signal<= 1'b1;
//    end
//    else if(r_empty) 
//        count_signal<= 1'b0;
//    else
//        count_signal<= count_signal;
//end

reg rd_en_test;

//always @(posedge sys_clk or negedge rst_n) begin
//    if (!rst_n) begin
//        count <= 'd0;
//    end
//    else if(count_signal)begin
//        if(count == 'd200000)begin
//            count <= 'd0;
//        end
//        else
//            count <= count +1'b1;   
//    end
//    else 
//        count <= 'd0;
//end

always @(posedge sys_clk or negedge rst_n) begin
    if (!rst_n) begin
        rd_en_test<= 1'b0;
//        sata<=1'b0;
    end
    else if(ready)begin
        rd_en_test <= 1'b1;
//        sata<=1'b1;
    end
    else 
        rd_en_test <= 1'b0;
end
	
fifo_generator_0 fifO_initial (
  .clk(sys_clk),      // input wire clk
  .srst(~rst_n),    // input wire srst
  
  .din(data),      // input wire [7 : 0] din
  .wr_en(wrreq),  // input wire wr_en
  
  .rd_en(rd_en_test),  // input wire rd_en
  
  .dout(q),    // output wire [7 : 0] dout
  .full(full),    // output wire full
  .empty(empty),  // output wire empty
  .valid(valid)  // output wire valid
);

endmodule