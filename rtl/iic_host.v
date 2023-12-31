`timescale 1ns / 1ps
//
// Company: 
// Engineer: xy
// 
// Create Date:    11:48:53 08/31/2018 
// Design Name: 
// Module Name:    iic_design_host 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//
 module iic_host #(
 parameter SYSCLK = 50000000,
 parameter IICRATE =  200000
 )
 (
   input              clk, //50MHZ
   input              rst, 
   output   reg       scl, 
   inout              sda,
   
   output              sda_test,
   
   input              rd_en,
   input              wr_en,
   
   input   [7:0]      iic_id,   
   input   [7:0]      iic_addr,
   input   [7:0]      wr_data,
   output reg         wr_done,
   output reg [7:0]   rd_data,
   output reg         rd_done
   );
   
   localparam IIC_BPS = SYSCLK/IICRATE/2;  // 250K
   localparam IIC_BPS_2 = SYSCLK/IICRATE/4;
   
   reg [7:0] wr_data_tmp;

   reg sda_link; 
   reg sda_buf;
   assign sda 	= (sda_link == 1) ? sda_buf : 1'bz;
   
   assign sda_test = sda;
   
//**********scl输出***************	
   reg [9:0] clk_cnt; //499, 
   reg       clk_bps;
   reg       run_en;
   
   always @ (posedge clk) begin  //5OM驱动时钟生成模块
     if(rst) begin 
       clk_cnt   <= 0;
       clk_bps <= 0;
       end 
     else if(run_en && clk_cnt == IIC_BPS - 1) begin 
       clk_cnt   <= 0;
       clk_bps <= ~clk_bps;
       end 
     else if(run_en) begin 
       clk_cnt   <= clk_cnt + 1;
       clk_bps <= clk_bps;
       end 
     else begin 
       clk_bps <= 1;
       clk_cnt   <= 0;
       end 
   end 
   
   always @ (posedge clk) begin 
     if(rst) 
       scl <= 1;
     else if(run_en) //在有发送有效数据时，发送时钟，空闲状态保持为1
       scl <= clk_bps;
     else 
       scl <= 1;
   end 
  
   wire     scl_flag;
   assign   scl_flag = (clk_cnt == IIC_BPS_2 - 1) ? 1 : 0;
//-------------------------------------------------------------------
///************************************
   reg [31:0] cnt_5ms;
   wire       cnt_5ms_flag;
    
   always @ (posedge clk) begin 
     if(rst)
       cnt_5ms <= 0;
     else if(run_en == 1)
       cnt_5ms <= cnt_5ms + 1;
     else 
       cnt_5ms <= 0;
   end 
	
   assign cnt_5ms_flag = (cnt_5ms == 24999999) ? 1 : 0;
//--------------------------------------------------
  
//*************************IIC时序*************************  
   localparam  idle_state  	     = 'd0 ;  //空闲状态，准备发送起始位
   localparam  startwr_state      = 'd1 ;  //起始状态，发送起始位
   localparam  txidwr_state       = 'd2 ;  //发送器件ID，
   localparam  txidwr_ack_state   = 'd3 ;  //接收一个ACK
   localparam  txaddrwr_state     = 'd4 ;  //发送寄存器地址，
   localparam  txaddrwr_ack_state = 'd5 ;  //接收一个ACK
   localparam  readyrd_state      = 'd6 ;  //准备读数据
   localparam  startrd_state      = 'd7 ;  //发送一个开始信号
   localparam  txidrd_state       = 'd8 ;  //发送器件ID
   localparam  txidrd_ack_state   = 'd9 ;  //接收一个ACK
   localparam  rxaddrrd_state     = 'd10;  //接收数据
   localparam  rxaddrrd_ack_state = 'd11;  //发送读数据ACK
   localparam  readystop_state    = 'd12;  //准备停止
   localparam  stop_state         = 'd13;  //发送停止信号
   localparam  end_state          = 'd14;  //结束空闲状态
   localparam  sel_state          = 'd15;  //读写选择状态
   localparam  txdata_state       = 'd16;  //数据发送状态
   localparam  txdata_ack_state   = 'd17;  //发送ACK
   
   reg [4:0] iic_next_state     = idle_state;
   reg [4:0] iic_current_state  = idle_state;
   reg [3:0] cnt_shift          = 0;
   reg [7:0] data_reg           = 0;
   reg       rd_sel             = 0;			//这里是读写控制 0：write		1:read
   
   always @ (posedge clk) begin 
     if(rst)
       iic_current_state <= idle_state;
     else 
       iic_current_state <= iic_next_state;
   end 
   always @ (*) begin 
     if(rst) 
       iic_next_state = idle_state;
     else case(iic_current_state)
       idle_state          :  if(rd_en || wr_en) 
		                           iic_next_state = startwr_state;
                              else iic_next_state = idle_state;
                          
       startwr_state       :  if(scl == 1 && scl_flag) 							 // 做时钟同步
		                           iic_next_state = txidwr_state;
                              else iic_next_state = startwr_state;
                          
       txidwr_state        :  if(scl == 0 && scl_flag && cnt_shift == 8) 
	                               iic_next_state = txidwr_ack_state;
                              else iic_next_state = txidwr_state;
                          
       txidwr_ack_state    :  if(scl == 1 && scl_flag)  
						           					 iic_next_state = txaddrwr_state;			//应答sda == 0		(PS:其实这里没有判断是否有应答)
                              else iic_next_state = txidwr_ack_state;         
					       
       txaddrwr_state      :  if(scl == 0 && scl_flag && cnt_shift == 8) 
	                               iic_next_state = txaddrwr_ack_state;
                              else iic_next_state = txaddrwr_state; 
                       
       txaddrwr_ack_state  :  if(scl == 1 && scl_flag)  
								        				iic_next_state = sel_state;						//应答sda == 0  (PS:其实这里没有判断是否有应答)
                              else iic_next_state = txaddrwr_ack_state;   
							  
	   	sel_state            :  if(rd_sel) 
	                               iic_next_state = readyrd_state;	
							        				else 
							            			iic_next_state = txdata_state;
								   
	   	txdata_state        :  if(scl == 0 && scl_flag && cnt_shift == 8) 
	                               iic_next_state = txdata_ack_state;
                              else iic_next_state = txdata_state;  
       
       txdata_ack_state    :  if(scl == 1 && scl_flag)  
	                               iic_next_state = readystop_state;		//应答sda == 0
                              else iic_next_state = txdata_ack_state; 
       
       readyrd_state       :  if(scl == 0 && scl_flag) 
							       						iic_next_state = startrd_state;
                              else iic_next_state = readyrd_state;  
					       
       startrd_state       :  if(scl == 1 && scl_flag) 
	                               iic_next_state = txidrd_state;
                              else iic_next_state = startrd_state; 
                       
       txidrd_state        :  if(scl == 0 && scl_flag && cnt_shift == 8) 
	                               iic_next_state = txidrd_ack_state;
                              else iic_next_state = txidrd_state;  
       
       txidrd_ack_state    :  if(scl == 1 && scl_flag)  
		                           iic_next_state = rxaddrrd_state;//应答sda == 0
                              else iic_next_state = txidrd_ack_state;                 
       
       rxaddrrd_state      :  if(scl == 1 && scl_flag && cnt_shift == 7)
                                   iic_next_state = rxaddrrd_ack_state;
                              else iic_next_state = rxaddrrd_state;                
       
       rxaddrrd_ack_state  :  if(scl == 0 && scl_flag)  
                                   iic_next_state = readystop_state;
                              else iic_next_state = rxaddrrd_ack_state;  
                                 
       readystop_state     :  if(scl == 0 && scl_flag)   
	                               iic_next_state = stop_state;
                              else iic_next_state = readystop_state; 
                       
       stop_state          :  if(scl == 1 && scl_flag)   
	                               iic_next_state = end_state;
                              else iic_next_state = stop_state;    
                                   
       end_state           :       iic_next_state = idle_state;       
       
                       
       default             :       iic_next_state = idle_state;                                             
       endcase 
   end 
	
	
   always @ (posedge clk) begin 
     if(rst) begin 
       cnt_shift  <= 0; //数据移位计数器
       data_reg   <= 0; //发送数据寄存器
       sda_buf    <= 1; //发送buf
       sda_link   <= 0; //三态控制
       run_en     <= 0;
       rd_data    <= 0;
		 rd_sel     <= 0;
		 wr_done    <= 0;
		 rd_done    <= 0;
		 wr_data_tmp <= 8'd0;
       end 
     else case(iic_current_state)
      idle_state           :  if(wr_en) begin
                                cnt_shift <= 0; //数据移位计数器
                                data_reg  <= 0; //发送数据寄存器
                                sda_buf   <= 1; //发送buf
                                sda_link  <= 1; //三态控制
                                wr_data_tmp <= wr_data;
                                run_en    <= 1;
										  					rd_sel    <= 0;
										  					wr_done   <= 0;
										  					rd_done   <= 0;
                                end 
										else if(rd_en) begin 
										  					cnt_shift <= 0; //数据移位计数器
                                data_reg  <= 0; //发送数据寄存器
                                sda_buf   <= 1; //发送buf
                                sda_link  <= 1; //三态控制
                                run_en    <= 1;
										  					rd_sel    <= 1;
										  					wr_done   <= 0;
										  					rd_done   <= 0;
										  end
                              else begin 
                                cnt_shift <= 0; //数据移位计数器
                                data_reg  <= 0; //发送数据寄存器
                                sda_buf   <= 1; //发送buf
                                sda_link  <= 1; //三态控制
                                run_en    <= 0;
										  					rd_sel 		<= 0;
										  					wr_done 	<= 0;
										  					rd_done 	<= 0;
                                end 
      
      startwr_state        :  if(scl == 1 && scl_flag) begin 
                                cnt_shift <= 0; //数据移位计数器
                                data_reg  <= {iic_id[7:1],1'b0}; //发送数据寄存器
                                sda_buf   <= 0; //发送buf
                                sda_link  <= 1; //三态控制
                                run_en    <= 1;
                                end 
                              else begin 
                                cnt_shift <= 0; //数据移位计数器
                                data_reg  <= {iic_id[7:1],1'b0}; //发送数据寄存器
                                sda_buf   <= 1; //发送buf
                                sda_link  <= 1; //三态控制
                                run_en    <= 1;
                                end 
                      
      txidwr_state         :  if(scl == 0 && scl_flag && cnt_shift == 8) begin
																data_reg  <= 0;
																cnt_shift <= 0;
																sda_buf   <= 0;
																sda_link  <= 0;
																end
							  							else if(scl == 0 && scl_flag && cnt_shift < 8) begin 
																data_reg  <= {data_reg[6:0],data_reg[7]};
																cnt_shift <= cnt_shift + 1;
																sda_buf   <= data_reg[7]; 
																sda_link  <= 1;
																end 
								  						else begin 
																data_reg  <= data_reg;
																cnt_shift <= cnt_shift;
																sda_buf   <= sda_buf; 
																sda_link  <= sda_link;
															end 
      
      txidwr_ack_state     :  if(scl == 1 && scl_flag) begin 
																cnt_shift <= 0;
																data_reg  <= iic_addr;
																sda_buf   <= 0;
																sda_link  <= 0;
															end 
														  else begin  
																data_reg  <= iic_addr;
																cnt_shift <= cnt_shift;
																sda_buf   <= sda_buf; 
																sda_link  <= sda_link;
															end 
      
      txaddrwr_state       :  if(scl == 0 && scl_flag && cnt_shift == 8) begin
																data_reg  <= 0;
																cnt_shift <= 0;
																sda_buf   <= 0;
																sda_link  <= 0;
															end
														  else if(scl == 0 && scl_flag && cnt_shift < 8) begin 
																data_reg  <= {data_reg[6:0],data_reg[7]};
																cnt_shift <= cnt_shift + 1;
																sda_buf   <= data_reg[7]; 
																sda_link  <= 1;
															end 
														  else begin 
																data_reg  <= data_reg;
																cnt_shift <= cnt_shift;
																sda_buf   <= sda_buf; 
																sda_link  <= sda_link;
															end 
                      
      txaddrwr_ack_state   :  if(scl == 1 && scl_flag) begin 
																cnt_shift <= 0;
																data_reg  <= 0;
																sda_buf   <= 0;
																sda_link  <= 0;
															end 
														  else begin  
																data_reg  <= data_reg;
																cnt_shift <= cnt_shift;
																sda_buf   <= sda_buf; 
																sda_link  <= sda_link;
															end
      sel_state 	         :  if(rd_sel == 0)
                              	  data_reg <= wr_data_tmp;
							  							else 
								  								data_reg <= 0;
								
	  	txdata_state         :  if(scl == 0 && scl_flag && cnt_shift == 8) begin
                                data_reg 	<= 0;
                                cnt_shift <= 0;
                                sda_buf 	<= 0;
                                sda_link 	<= 0;
                              end
                              else if(scl == 0 && scl_flag && cnt_shift < 8) begin 
                                data_reg <= {data_reg[6:0],data_reg[7]};
                                cnt_shift <= cnt_shift + 1;
                                sda_buf <= data_reg[7]; 
                                sda_link <= 1;
                              end 
                              else begin 
                                data_reg <= data_reg;
                                cnt_shift <= cnt_shift;
                                sda_buf <= sda_buf; 
                                sda_link <= sda_link;
                              end   
       
      txdata_ack_state    :  	if(scl == 1 && scl_flag) begin 
                                cnt_shift <= 0;
                                data_reg 	<= 0;
                                sda_buf 	<= 0;
                                sda_link 	<= 0;
                              end 
                              else begin  
                                data_reg 	<= data_reg;
                                cnt_shift <= cnt_shift;
                                sda_buf 	<= sda_buf; 
                                sda_link 	<= sda_link;
                              end 
      
      readyrd_state        :  if(scl == 0 && scl_flag) begin 
								cnt_shift <= 0;
								data_reg  <= 0;
								sda_buf   <= 1;
								sda_link  <= 1;
								end 
							  else begin  
								data_reg  <= data_reg;
								cnt_shift <= cnt_shift;
								sda_buf   <= sda_buf; 
								sda_link  <= sda_link;
								end       
		
      startrd_state        :  if(scl == 1 && scl_flag) begin 
								cnt_shift <= 0;
								data_reg  <= {iic_id[7:1],1'b1}; 
								sda_buf   <= 0;
								sda_link  <= 1;
								end 
							  else begin  
								data_reg  <= {iic_id[7:1],1'b1}; 
								cnt_shift <= cnt_shift;
								sda_buf   <= sda_buf; 
								sda_link  <= sda_link;
								end   
                      
      txidrd_state         : if(scl == 0 && scl_flag && cnt_shift == 8) begin
								data_reg  <= 0;
								cnt_shift <= 0;
								sda_buf   <= 0;
								sda_link  <= 0;
								end
							  else if(scl == 0 && scl_flag && cnt_shift < 8) begin 
								data_reg  <= {data_reg[6:0],data_reg[7]};
								cnt_shift <= cnt_shift + 1;
								sda_buf   <= data_reg[7]; 
								sda_link  <= 1;
								end 
							  else begin 
								data_reg  <= data_reg;
								cnt_shift <= cnt_shift;
								sda_buf   <= sda_buf; 
								sda_link  <= sda_link;
								end   
      
      txidrd_ack_state     :  if(scl == 1 && scl_flag) begin 
							    cnt_shift <= 0;
							    data_reg  <= 0;
							    sda_buf   <= 0;
							    sda_link  <= 0;
							    end 
							  else begin  
							    data_reg  <= data_reg;
							    cnt_shift <= cnt_shift;
							    sda_buf   <= sda_buf; 
							    sda_link  <= sda_link;
							    end               
      
      rxaddrrd_state       :  if(scl == 1 && scl_flag && cnt_shift == 7) begin 
							    rd_data   <= {rd_data[6:0],sda};
							    cnt_shift <= 0;
							    sda_buf   <= 0;
							    sda_link  <= 0;
							    end
							  else if(scl == 1 && scl_flag && cnt_shift < 7) begin 
							    rd_data   <= {rd_data[6:0],sda};
							    cnt_shift <= cnt_shift + 1;
							    sda_buf   <= 0;
							    sda_link  <= 0;
							    end 
							  else begin 
							    data_reg  <= data_reg;
							    cnt_shift <= cnt_shift;
							    sda_buf   <= sda_buf; 
							    sda_link  <= sda_link; 
							    end               
      
      rxaddrrd_ack_state   :  if(scl == 0 && scl_flag) begin 
							    data_reg  <= data_reg;
							    cnt_shift <= 0;
							    sda_buf   <= 1;
							    sda_link  <= 1;
							    end 
							  else begin  
							    data_reg  <= data_reg;
							    cnt_shift <= cnt_shift;
							    sda_buf   <= sda_buf; 
							    sda_link  <= sda_link; 
							    end  
                                 
      readystop_state 	   :  if(scl == 0 && scl_flag) begin 
														    data_reg  <= data_reg;
														    cnt_shift <= 0;
														    sda_buf   <= 0;
														    sda_link  <= 1;
														    end 
														  else begin  
														    data_reg  <= data_reg;
														    cnt_shift <= cnt_shift;
														    sda_buf   <= sda_buf; 
														    sda_link  <= sda_link; 
														 	end
                   
      stop_state           :  if(scl == 1 && scl_flag) begin 
														    data_reg  <= data_reg;
														    cnt_shift <= 0;
														    sda_buf   <= 1;
														    sda_link  <= 1;
														    run_en    <= 0;
														    end 
														  else begin  
														    data_reg  <= data_reg;
														    cnt_shift <= cnt_shift;
														    sda_buf   <= sda_buf; 
														    sda_link  <= sda_link; 
														    end
                    
      end_state       :  			begin 
														    data_reg  <= data_reg;
														    cnt_shift <= 0;
														    sda_buf   <= 1;
														    sda_link  <= 1;
														    run_en    <= 0;
														    wr_data_tmp <= 8'b0;
															 if(rd_sel == 1) begin 
															   wr_done    <= 0;
															   rd_done    <= 1;
															   end
															 else begin 
															   wr_done    <= 1;
															   rd_done    <= 0;
															   end 
														  end     
							  
      endcase 
   end 
        
endmodule 