`timescale  1ns/1ns
////////////////////////////////////////////////////////////////////////
// Author        : EmbedFire
// Create Date   : 2019/06/12
// Module Name   : uart_tx
// Project Name  : rs232
// Target Devices: Altera EP4CE10F17C8N
// Tool Versions : Quartus 13.0
// Description   : 
// 
// Revision      : V1.0
// Additional Comments:
// 
// ʵ��ƽ̨: Ұ��_��;Pro_FPGA������
// ��˾    : http://www.embedfire.com
// ��̳    : http://www.firebbs.cn
// �Ա�    : https://fire-stm32.taobao.com
////////////////////////////////////////////////////////////////////////

module  uart_tx
#(
    parameter   UART_BPS    =   'd9600,         //���ڲ�����
    parameter   CLK_FREQ    =   'd50_000_000    //ʱ��Ƶ��
)
(
     input   wire            sys_clk     ,   //ϵͳʱ��50MHz
     input   wire            sys_rst_n   ,   //ȫ�ָ�λ
     input   wire    [7:0]   pi_data     ,   //ģ�������8bit����
     input   wire            pi_flag     ,   //����������Ч��־�ź�
 
     output  reg             tx     ,         //��ת�����1bit����
     output reg              tx_done
);

//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//
//localparam    define
localparam  BAUD_CNT_MAX    =   CLK_FREQ/UART_BPS   ;

//reg   define
reg [12:0]  baud_cnt;
reg         bit_flag;
reg [3:0]   bit_cnt ;
reg         work_en ;

//********************************************************************//
//***************************** Main Code ****************************//
//********************************************************************//
//work_en:�������ݹ���ʹ���ź�
always@(posedge sys_clk or negedge sys_rst_n)
        if(sys_rst_n == 1'b0)
            work_en <= 1'b0;
        else    if(pi_flag == 1'b1)
            work_en <= 1'b1;
        else    if((bit_flag == 1'b1) && (bit_cnt == 4'd9))
            work_en <= 1'b0;

//baud_cnt:�����ʼ�������������0������BAUD_CNT_MAX - 1
always@(posedge sys_clk or negedge sys_rst_n)
        if(sys_rst_n == 1'b0)
            baud_cnt <= 13'b0;
        else    if((baud_cnt == BAUD_CNT_MAX - 1) || (work_en == 1'b0))
            baud_cnt <= 13'b0;
        else    if(work_en == 1'b1)
            baud_cnt <= baud_cnt + 1'b1;

//bit_flag:��baud_cnt������������1ʱ��bit_flag����һ��ʱ�ӵĸߵ�ƽ
always@(posedge sys_clk or negedge sys_rst_n)
        if(sys_rst_n == 1'b0)
            bit_flag <= 1'b0;
        else    if(baud_cnt == 13'd1)
            bit_flag <= 1'b1;
        else
            bit_flag <= 1'b0;

//bit_cnt:����λ������������10����Ч���ݣ�����ʼλ��ֹͣλ�����������������
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        bit_cnt <= 4'b0;
    else    if((bit_flag == 1'b1) && (bit_cnt == 4'd9))
        bit_cnt <= 4'b0;
    else    if((bit_flag == 1'b1) && (work_en == 1'b1))
        bit_cnt <= bit_cnt + 1'b1;

//tx:�������������rs232Э�飨��ʼλΪ0��ֹͣλΪ1���������һλһλ���
always@(posedge sys_clk or negedge sys_rst_n)
        if(sys_rst_n == 1'b0)
            tx <= 1'b1; //����״̬ʱΪ�ߵ�ƽ
        else    if(bit_flag == 1'b1)
            case(bit_cnt)
                0       : tx <= 1'b0;
                1       : tx <= pi_data[0];
                2       : tx <= pi_data[1];
                3       : tx <= pi_data[2];
                4       : tx <= pi_data[3];
                5       : tx <= pi_data[4];
                6       : tx <= pi_data[5];
                7       : tx <= pi_data[6];
                8       : tx <= pi_data[7];
                9       : tx <= 1'b1;
                default : tx <= 1'b1;
            endcase




always@(posedge sys_clk or negedge sys_rst_n)begin
    if(sys_rst_n == 1'b0)begin
        tx_done <=1'b0;
    end 
    else if(bit_cnt == 'd9)
        tx_done <= 1'b1;
    else 
        tx_done <=1'b0;

end

endmodule
