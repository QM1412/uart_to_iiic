`timescale  1ns/1ps
module tb_uart_iic();

reg       sys_clk;
reg       rst_n;
reg       rx;
wire [7:0]rx_data;
wire      rx_data_valid;

wire tx;
wire scl;
wire sda;



initial begin
    sys_clk =1'b1;
    rst_n = 1'b0;
    rx = 1'b1;
    #100;
    rst_n = 1'b1;
    tx_bit(8'h55);
    tx_bit(8'h45);
    tx_bit(8'h77);
    tx_bit(8'h99);
end

always #10 sys_clk = ~sys_clk;

task tx_bit(input [7:0] data);
    integer i;
    for (i = 0 ;i<10 ;i=i+1 ) begin
        case (i)
            0:rx <= 1'b0;
            1:rx <= data[0];
            2:rx <= data[1];
            3:rx <= data[2];
            4:rx <= data[3];
            5:rx <= data[4];
            6:rx <= data[5];
            7:rx <= data[6];
            8:rx <= data[7];
            9:rx <= 1'b1;
            default: rx = 1'b1;
        endcase        
          #(5280*20);
//          #(434*20);
    end
endtask



uart_iic_top  uart_iic_top_initial(
   .sys_clk(sys_clk),
    .sys_rst(rst_n),
    
    .rx(rx),
    
    .sda(sda),
    .scl(scl),
    
    .led()
 );




endmodule