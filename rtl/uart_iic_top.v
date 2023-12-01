`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/11/28 20:59:18
// Design Name: 
// Module Name: uart_iic_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module uart_iic_top(
    input sys_clk,
    input sys_rst,
    
    input rx,
    
    output tx,
    inout sda,
    output scl,
    output reg led
    );
    
    
//    clk_wiz_0 clock_inist
//   (
//    // Clock out ports
//    .clk_out1(sys_clk),     // output clk_out1
//   // Clock in ports
//    .clk_in1(sys_clk_1));      // input clk_in1
parameter   UART_BPS    =   'd9600;

wire [7:0] po_data;
wire po_flag;
wire temp;
reg po_flag_1;
reg po_flag_2;

wire    [7:0] fifo_out;
wire fifo_out_vld;

assign temp = ~po_flag_1 && po_flag_2;

always@(posedge sys_clk or negedge sys_rst) begin
    if(~sys_rst)begin
        po_flag_1 <=1'b0;
        po_flag_2 <= 1'b0;
    end
    else begin
        po_flag_1 <= wr_done;
        po_flag_2 <= po_flag_1;
    end
end

always@(posedge sys_clk or negedge sys_rst) begin
    if(~sys_rst)
        led <=1'b0;
     else begin
        if(temp)
            led <= ~led;
     
     end
        
end

uart_rx 
#(.UART_BPS(UART_BPS))
uart_rx_initial

(
    .sys_clk    (sys_clk) ,   //系统时钟50MHz
    .sys_rst_n   (sys_rst),   //全局复位
    .rx          (rx),   //串口接收数据

    .po_data     (po_data),   //串转并后的8bit数据
    .po_flag      (po_flag)   //串转并后的数据有效标志信号
);    

control control_initial (
    .sys_clk      (sys_clk)  ,
    .rst_n     (sys_rst) ,

    .fifo_in    (po_data)   ,
    .fifo_in_vld  (po_flag) ,

    .ready     (wr_done) , 

    .fifo_out      (fifo_out)  ,
    .fifo_out_vld    (fifo_out_vld)      
);

iic_host iic_tx_initial
 (
   .clk     (sys_clk)  , //50MHZ
   .rst     (~sys_rst)  , 
   .scl     (scl)  , 
   .sda     (sda)  ,
   .sda_test     (),
   
   .rd_en   (1'b0)    ,
   .wr_en   (fifo_out_vld)    ,
   
   .iic_id    (8'h53)  ,   
   .iic_addr  (8'h36)    ,
   .wr_data   (fifo_out)  ,
   .wr_done   (wr_done)  ,
   .rd_data   ()  ,
   .rd_done()
);

wire  [7:0]rx_data_iic;
wire rx_data_en;

iic_rx iic_rx_initial (
    //external port 
    .clk		(sys_clk)	,
    .rst		(~sys_rst)	,
	.iic_scl	(scl)	,
	.iic_sda	(sda)	,
	
	.ot_iddata	()	,
	.ot_addr	()	,
	.ot_datareg	()	,	
	.ot_iic_sda	()	,
	.ot_iic_scl	()	,
	.ot_state	()	,
	
	.tx_data	(8'd0)	,
	.rx_addr	()	,
	.rx_data	(rx_data_iic)	,
	.rx_data_en (rx_data_en)
);


wire    tx_done;

uart_tx  uart_tx_initial
(
     .sys_clk    (sys_clk) ,   //系统时钟50MHz
     .sys_rst_n   (sys_rst),   //全局复位
     .pi_data     (rx_data_iic),   //模块输入的8bit数据
     .pi_flag     (rx_data_en),   //并行数据有效标志信号
     . tx          (tx)   , //串转并后的1bit数据
     .tx_done(tx_done)
);


endmodule
