`timescale 1ns / 1ps
//
// Company: 
// Engineer: xy
// 
// Create Date: 2020/08/28 13:37:07
// Design Name: 
// Module Name: iic_slave_design
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
//
module iic_rx (
    //external port 
    input                   clk,
    input                   rst,
	input					iic_scl,
	inout					iic_sda,
	//test port
	output     [7:0]        ot_iddata,
	output     [7:0]        ot_addr,
	output     [7:0]        ot_datareg,
	output                  ot_iic_sda,
	output                  ot_iic_scl,
	output     [3:0]        ot_state,
	//internal data port
	input      [7:0]        tx_data,
	output     [7:0]        rx_addr,
	output     [7:0]        rx_data,
	output  				rx_data_en
);
	
	reg sda_link = 0; 
	reg sda_buf  = 0;
	assign iic_sda 	= (sda_link == 1) ? sda_buf : 1'bz;
	
//****************************IIC data detection*******************************************************	
    
	reg sda_r1=0,sda_r2=0;
	reg scl_r1=0,scl_r2=0;
	wire iic_riseing;
	wire iic_falling;
	wire scl_riseing; 
	wire scl_falling; 
	reg  [31:0]  time_cnt;
	wire         time_flag;
	
	
	always @ (posedge clk) begin 
	    scl_r1 <= iic_scl;
	    scl_r2 <= scl_r1;
	    
		sda_r1 <= iic_sda;
		sda_r2 <= sda_r1;
	end 
	assign iic_riseing = !sda_r2 && sda_r1; //scl posedge 
	assign iic_falling = sda_r2 && !sda_r1; //scl negedge 
	assign scl_riseing = !scl_r2 && scl_r1;
	assign scl_falling = scl_r2 && !scl_r1;
	
	always @ (posedge clk) begin  //timeout control
		if(rst) 
			time_cnt <= 0;
		else if(scl_riseing || scl_falling || time_flag) 
			time_cnt <= 0;
		else 
			time_cnt <= time_cnt + 1;	
	end 
	
	assign time_flag = (time_cnt == 499999) ? 1 : 0; // 10ms
//------------------------------------------------------------------------------------------------------
	localparam [3:0] ildestate      = 0; 
	localparam [3:0] startwrstate   = 1; 
	localparam [3:0] wr_state       = 2;
	localparam [3:0] wrok_state     = 3; 
	localparam [3:0] wrack_state    = 4;
	localparam [3:0] startrdstate   = 5; 
	localparam [3:0] rdid_state     = 6;
	localparam [3:0] rdidok_state   = 7; 
	localparam [3:0] rdidack_state  = 8;
	localparam [3:0] ready_rdstate  = 9; 
	localparam [3:0] rdda_state     = 10;
	localparam [3:0] rddaok_state   = 11;
	localparam [3:0] rddaack_state  = 12;    
	localparam [3:0] rddasel_state  = 13;    
	reg [3:0] iic_next_state     = ildestate;
	reg [3:0] iic_current_state  = ildestate;
	
	reg [3:0] shift_cnt  = 0; //sda data shift count   
	reg [7:0] iic_sel  = 0;   //data count; 0-ID£¬1-addr  default : data
	reg [7:0] shift_reg = 0;  //sda data shift reg 
	reg [7:0] data_reg  = 0;  //rxdata reg 
	reg       data_reg_en = 0; //rxdata enable
	
	reg [7:0] id_data  = 0;  //ID
	reg [7:0] iic_addr = 0; //iic reg addr 
	wire [7:0] iic_data; //iic reg data 
	assign iic_data = tx_data;
//***********************************IIC Slave FSM ***********************************
	always @ (posedge clk) begin :  FSM_1
		if(rst) 
			iic_current_state <= ildestate;
		else 
			iic_current_state <= iic_next_state;
	end 
	always @ (*) begin  :  FSM_2
		if(rst)
			iic_next_state = ildestate;
	 else case(iic_current_state)
					
			ildestate : if(scl_r2 && iic_falling)       //waiting start 
					iic_next_state = startwrstate;
				else 
					iic_next_state = ildestate;	
					
			startwrstate : if(time_flag)
					iic_next_state = ildestate;
				else if(scl_r2 == 0)           	    	
					iic_next_state = wr_state;
				else if(iic_sel == 2 && scl_r2 && iic_falling)  
                    iic_next_state = startrdstate;
				else if(scl_r2 && iic_riseing)       			
					iic_next_state = ildestate;
				else 
					iic_next_state = startwrstate;	
					
			wr_state : if(time_flag)
					iic_next_state = ildestate;
				else if(scl_r2 && shift_cnt == 7) 			
					iic_next_state = wrok_state;
				else if(scl_r2 && shift_cnt < 7)
					iic_next_state = startwrstate;	
				else 
					iic_next_state = wr_state;	
					
			wrok_state : if(time_flag)
					iic_next_state = ildestate;
				else if(scl_r2 == 0)           	     
					iic_next_state = wrack_state;
				else if(scl_r2 && iic_falling)  		
                    iic_next_state = startwrstate;
				else if(scl_r2 && iic_riseing)           
					iic_next_state = ildestate;
				else 
					iic_next_state = wrok_state;	
					
			wrack_state : if(time_flag)
					iic_next_state = ildestate;
				else if(scl_r2 == 1) 		         
					iic_next_state = startwrstate;
				else 
					iic_next_state = wrack_state;	
					
			
			startrdstate : if(time_flag)
					iic_next_state = ildestate;
				else if(scl_r2 == 0)           	 
					iic_next_state = rdid_state;
				else if(scl_r2 && iic_falling)  		
                    iic_next_state = startwrstate;
				else if(scl_r2 && iic_riseing)           
					iic_next_state = ildestate;
				else 
					iic_next_state = startrdstate;		
					
			rdid_state : if(time_flag)
					iic_next_state = ildestate;
				else if(scl_r2 && shift_cnt == 7)    
					iic_next_state = rdidok_state;
				else if(scl_r2 && shift_cnt < 7)
					iic_next_state = startrdstate;	
				else 
					iic_next_state = rdid_state;	
			
			rdidok_state: if(time_flag)
					iic_next_state = ildestate;
				else if(scl_r2 == 0)           	   
					iic_next_state = rdidack_state;
				else if(scl_r2 && iic_falling)  		   
                    iic_next_state = startwrstate;
				else if(scl_r2 && iic_riseing)             
					iic_next_state = ildestate;
				else 
					iic_next_state = rdidok_state;	
					
			rdidack_state: if(time_flag)
					iic_next_state = ildestate;
				else if(scl_r2 == 1 && id_data[0] == 1)
					iic_next_state = ready_rdstate;
				else if(scl_r2 == 1)
					iic_next_state = ildestate;
				else 
					iic_next_state = rdidack_state;
					
			ready_rdstate: if(time_flag)
					iic_next_state = ildestate;
				else if(scl_r2 == 0)           	     
					iic_next_state = rdda_state;
				else if(scl_r2 && iic_falling)  		  
                    iic_next_state = startwrstate;
				else if(scl_r2 && iic_riseing)            
					iic_next_state = ildestate;
				else 
					iic_next_state = ready_rdstate;
			
			rdda_state:  if(time_flag)
					iic_next_state = ildestate;
				else if(scl_r2 && shift_cnt == 7)         
					iic_next_state = rddaok_state;
				else if(scl_r2 && shift_cnt < 7)
					iic_next_state = ready_rdstate;	
				else 
					iic_next_state = rdda_state;	
					
			rddaok_state: if(time_flag)
					iic_next_state = ildestate;
				else if(scl_r2 == 0)           	
					iic_next_state = rddaack_state; 
				else 
					iic_next_state = rddaok_state;	
					
			rddaack_state: if(time_flag)
					iic_next_state = ildestate;
				else if(scl_r2 == 1 && sda_r2 == 1)
					iic_next_state = ildestate;
				else if(scl_r2 == 1 && sda_r2 == 0) 		        
					iic_next_state = ready_rdstate;
				else 
					iic_next_state = rddaack_state;
		endcase 
	end 
   
	always @ (posedge clk) begin 
		if(rst) begin 
			sda_link <= 0; 
			sda_buf  <= 0;
			
			shift_cnt  <= 0; 
			iic_sel  <= 0; 
			shift_reg <= 0; 
			
			id_data  <= 0; 
			iic_addr <= 0; 
			data_reg  <= 0;
			data_reg_en <= 0;
			end
		else case(iic_current_state)
			ildestate : begin
						sda_link <= 0; 
						sda_buf  <= 0; 
						iic_sel  <= 0;
						shift_cnt  <= 0; 
						shift_reg <= 0; 
						data_reg_en <= 0;
						end 
					
					
			startwrstate : if(scl_r2 == 0) begin          	     
						sda_link <= 0; 
						sda_buf  <= 0; 
						iic_sel  <= iic_sel;
						shift_cnt  <= shift_cnt; 
						shift_reg <= shift_reg; 
						end 
					else if(iic_sel == 2 && scl_r2 && iic_falling) begin  
						sda_link <= 0; 
						sda_buf  <= 0; 
						iic_sel  <= 0;
						shift_cnt  <= 0; 
						shift_reg <= 0; 
						end 
					else if(scl_r2 && iic_riseing) begin 
						sda_link <= 0; 
						sda_buf  <= 0; 
						shift_cnt  <= 0; 
						iic_sel  <= 0; 
						shift_reg <= 0; 
						end 
					else begin 
						sda_link <= sda_link; 
                        sda_buf  <= sda_buf; 
                        iic_sel  <= iic_sel;
                        shift_cnt  <= shift_cnt;
                        shift_reg <= shift_reg;
						data_reg_en <= 0;
						end 
					
			wr_state : if(scl_r2 && shift_cnt == 7) begin 
							sda_link <= 0; 
							sda_buf  <= 0; 
							iic_sel  <= iic_sel + 1;
							shift_cnt  <= 0; 
							shift_reg <= {shift_reg[6:0],iic_sda}; 
							end 
						else if(scl_r2 && shift_cnt < 7) begin 
							sda_link <= 0; 
							sda_buf  <= 0; 
							iic_sel  <= iic_sel;
							shift_cnt  <= shift_cnt + 1; 
							shift_reg <= {shift_reg[6:0],iic_sda}; 
							end 
						else begin 
							sda_link <= sda_link; 
							sda_buf  <= sda_buf; 
							iic_sel  <= iic_sel;
							shift_cnt  <= shift_cnt;
							shift_reg <= shift_reg;
							data_reg_en <= 0;
							end 
							
					
			wrok_state : if(scl_r2 == 0) begin 
							sda_link <= 1; 
							sda_buf  <= 0; 
							shift_cnt  <= 0; 
							case(iic_sel)
                               1 : id_data  <= shift_reg;
                               2 : iic_addr <= shift_reg;
                               3 : begin data_reg  <= shift_reg; data_reg_en <= 1; end 
							   default : begin iic_addr <= iic_addr + 1; data_reg  <= shift_reg; data_reg_en <= 1;  end 
                            endcase
							end 
						else if(scl_r2 && iic_falling) begin  
							sda_link <= 0; 
							sda_buf  <= 0; 
							iic_sel  <= 0;
							shift_cnt  <= 0; 
							shift_reg <= 0; 
							end 
						else if(scl_r2 && iic_riseing) begin 
							sda_link <= 0; 
							sda_buf  <= 0; 
							shift_cnt  <= 0; 
							iic_sel  <= 0; 
							shift_reg <= 0; 
							end 
						else begin 
							sda_link <= sda_link; 
                            sda_buf  <= sda_buf; 
                            id_data  <= id_data;
                            iic_addr <= iic_addr;
                            data_reg  <= data_reg;
							end 
					
			wrack_state :  begin 
						sda_link <= 1; 
						sda_buf  <= 0; 
						iic_sel  <= iic_sel;
						shift_cnt  <= 0; 
						shift_reg <= 0;
						data_reg_en <= 0;
						end 	
					
			startrdstate: if(scl_r2 == 0) begin          	    
						sda_link <= 0; 
						sda_buf  <= 0; 
						shift_cnt  <= shift_cnt; 
						shift_reg <= shift_reg; 
						end 
					else if(scl_r2 && iic_falling) begin 
						sda_link <= 0; 
						sda_buf  <= 0; 
						iic_sel  <= 0;
						shift_cnt  <= 0; 
						shift_reg <= 0; 
						end 
					else if(scl_r2 && iic_riseing) begin 
						sda_link <= 0; 
						sda_buf  <= 0; 
						shift_cnt  <= 0; 
						iic_sel  <= 0; 
						shift_reg <= 0; 
						end 
					else begin 
						sda_link <= sda_link; 
                        sda_buf  <= sda_buf; 
                        iic_sel  <= 0;
                        shift_cnt  <= shift_cnt;
                        shift_reg <= shift_reg;
						data_reg_en <= 0;
						end 		
					
			rdid_state : if(scl_r2 && shift_cnt == 7) begin
							sda_link <= 0; 
							sda_buf  <= 0; 
							shift_cnt  <= 0; 
							shift_reg <= {shift_reg[6:0],iic_sda}; 
							end 
						else if(scl_r2 && shift_cnt < 7) begin 
							sda_link <= 0; 
							sda_buf  <= 0; 
							shift_cnt  <= shift_cnt + 1; 
							shift_reg <= {shift_reg[6:0],iic_sda}; 
							end 
						else begin 
							sda_link <= sda_link; 
                            sda_buf  <= sda_buf; 
                            iic_sel  <= 0;
                            shift_cnt  <= shift_cnt;
                            shift_reg <= shift_reg;
							data_reg_en <= 0;
							end  
							
			rdidok_state : if(scl_r2 == 0) begin          	     
						sda_link <= 1; 
						sda_buf  <= 0; 
						shift_cnt  <= 0; 
						id_data  <= shift_reg;
						end 
					else if(scl_r2 && iic_falling) begin  
						sda_link <= 0; 
						sda_buf  <= 0; 
						iic_sel  <= 0;
						shift_cnt  <= 0; 
						shift_reg <= 0; 
						end 
					else if(scl_r2 && iic_riseing) begin
						sda_link <= 0; 
						sda_buf  <= 0; 
						shift_cnt  <= 0; 
						iic_sel  <= 0; 
						shift_reg <= 0; 
						end 
					else begin 
						sda_link <= sda_link; 
                        sda_buf  <= sda_buf; 
                        iic_sel  <= 0;
                        shift_cnt  <= shift_cnt;
                        shift_reg <= shift_reg; 
						data_reg_en <= 0;
						end 
					
			rdidack_state:  begin 
						sda_link <= 1; 
						sda_buf  <= 0; 
						iic_sel  <= 0;
						shift_cnt  <= 0; 
						shift_reg <= iic_data;
						data_reg_en <= 0;
						end 
					
			ready_rdstate: if(scl_r2 == 0) begin          	     
						sda_link <= 1; 
						sda_buf  <= shift_reg[7]; 
						shift_cnt  <= shift_cnt; 
						shift_reg <= shift_reg;
						end 
					else if(scl_r2 && iic_falling) begin 
						sda_link <= 0; 
						sda_buf  <= 0; 
						iic_sel  <= 0;
						shift_cnt  <= 0; 
						shift_reg <= 0; 
						end 
					else if(scl_r2 && iic_riseing) begin 
						sda_link <= 0; 
						sda_buf  <= 0; 
						shift_cnt  <= 0; 
						iic_sel  <= 0; 
						shift_reg <= 0; 
						end 
					else begin 
						sda_link <= sda_link; 
                        sda_buf  <= sda_buf; 
                        iic_sel  <= 0;
                        shift_cnt  <= shift_cnt;
                        shift_reg <= shift_reg;
						data_reg_en <= 0;
						end 
			
			rdda_state: if(scl_r2 && shift_cnt == 7) begin 
							sda_link <= 1; 
							sda_buf  <= sda_buf; 
							shift_cnt  <= 0; 
							shift_reg <= {shift_reg[6:0],1'b0}; 
							end 
						else if(scl_r2 && shift_cnt < 7) begin 
							sda_link <= 1; 
							sda_buf  <= sda_buf;
							shift_cnt  <= shift_cnt + 1; 
							shift_reg <= {shift_reg[6:0],1'b0}; 
							end 
						else begin 
							sda_link <= sda_link; 
                            sda_buf  <= sda_buf; 
                            iic_sel  <= 0;
                            shift_cnt  <= shift_cnt;
                            shift_reg <= shift_reg;
							data_reg_en <= 0;
							end 	
					
			rddaok_state: if(scl_r2 == 0) begin          	     
						sda_link <= 0; 
						sda_buf  <= 0; 
						shift_cnt  <= 0; 
						shift_reg <= shift_reg;
						iic_addr <= iic_addr + 8'd1;
						end 
					else begin 
						sda_link <= sda_link; 
                        sda_buf  <= sda_buf; 
                        iic_sel  <= 0;
                        shift_cnt  <= shift_cnt;
                        shift_reg <= shift_reg;
						data_reg_en <= 0;
						end 
 
			rddaack_state: begin
						sda_link <= 0; 
						sda_buf  <= 0; 
						shift_cnt  <= 0; 
						iic_sel  <= 0; 
						shift_reg <= iic_data;
						data_reg_en <= 0;
						end 
			endcase 	
	end 
//--------------------------------------------------------------------------------------------------------------	
	assign  rx_addr = iic_addr;
	assign  rx_data = data_reg;
	assign  rx_data_en = data_reg_en;
	
	assign ot_iddata = id_data;
	assign ot_addr   = iic_addr;
	assign ot_datareg = shift_reg;
	assign ot_iic_sda = sda_r2;
	assign ot_iic_scl = scl_r2;
	assign ot_state = iic_next_state;
	
endmodule 