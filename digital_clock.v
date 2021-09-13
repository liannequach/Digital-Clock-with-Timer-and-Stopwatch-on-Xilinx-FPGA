`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: final project CECS 361
// Engineer: Len Quach, Gita Temelkova, Jorel Caoile
// 
// Create Date: 11/01/2020 03:10:34 PM
// Design Name: 
// Module Name: digital_clock
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


module digital_clock (
 input rst,  //set the time to the input hour and minute and the second to 00
 input clk,  //100MHz input clock is used to generate each real-time second
 input set_H1, //set the most significant hour digit of the clock 
 input set_H0, //set the least significant hour digit of the clock
 input set_M1, //set the most significant minute digit of the clock
 input set_M0, //set the least significant minute digit of the clock
 input load,  //set to the values on the inputs set_H and set_M. The second time should be set to 0. Turn off when done.
 input load_counter, //hold button to increase the number of the specified digit of the clock
 input clock_format, //switch from military format to standard format or vice versa
 input stopwatch,  // the stopwatch function which counts up from 0. Has a limit of 24 hours
 input timer,      // the timer function; set a time and it will count down to 0
 input stop,       // hold button to stop the stopwatch
 input start,      // hold button to start the timer
 output reg [1:0] LED,   //flashing LED at every new hour
 output reg [5:0] anode,  //anode signals of ssd
 output reg [7:0] cathode //cathode signals of ssd
 );

 localparam N = 100000000; //100 million

 // internal signal
 reg clk_1s; // 1-s clock
 reg [26:0] tmp_1s; // count for creating 1-s clock 
 reg [5:0]  tmp_hour, tmp_minute, tmp_second; // counter for clock hour, minute and second
 reg [5:0]  func_hour, func_minute, func_second; // seconds/time displayed for stopwatch and timer functions
 reg [21:0] displayed_num; // number to be displayed
 reg [19:0] refresh_counter; //20-bit for creating 10.5 ms refresh period or 380Hz refresh rate
 reg [3:0]  LED_BCD;
 reg        LED_signal; //signal for LED to flash
 reg        pause; //signal to stop updating display for stopwatch and timer functions
 reg        go;    //signal to start the countdown of the timer
 
 wire [2:0] LED_activating_counter; //counts and activates the LEDS for the anodes
 
//function mod_10
 function [3:0] mod_10;
 input [5:0] number;
 begin
    mod_10 = (number >= 50) ? 5 : ((number >= 40)? 4 :((number >= 30)? 3 :((number >= 20)? 2 :((number >= 10)? 1 :0))));
 end
 endfunction
 
 //refresh the clock
 //the first 3 MSB are for creating 6 LED activating signals
 always@(posedge clk, posedge rst) 
 begin
    if(rst)
        refresh_counter <= 0;
    else if(refresh_counter >= 20'b10111111111111111111) //forces LED_activating_counter to only reach up to 101
        refresh_counter <= 0;
    else
        refresh_counter <= refresh_counter + 1;
 end
 assign LED_activating_counter = refresh_counter[19:17]; //anode activating signals for 6 LEDs, digit period of 2.6ms
 
//Clock Operation and Functions
 always @(posedge clk_1s or posedge rst)
     begin
     if(rst) begin // rst high => clock to set_H and set_M and S to 00
        tmp_hour <= 0;
        tmp_minute <= 0;
        tmp_second <= 0;
        func_hour <= 0;
        func_minute <= 0;
        func_second <= 0;
        pause <= 0;
        go <= 0;
        LED_signal <= 0;
     end 
     else begin  // load =0 , clock operates normally 
        tmp_second <= tmp_second + 1;
        if(tmp_minute >= 1)
            LED_signal <= 0;
        if(tmp_second >= 59) begin // second > 59 then minute increases
            tmp_minute <= tmp_minute + 1;
            tmp_second <= 0;
            if(tmp_minute >= 59) begin // minute > 59 then hour increases
                 tmp_hour <= tmp_hour + 1;
                 tmp_minute <= 0;
                 LED_signal <= 1;
                 end
        end
        if(tmp_hour >= 24) begin // hour > 23 then set hour to 0
            tmp_hour <= 0;
        end
        if(load) begin // load =1 => set time to set_H, set_M
            if(load_counter) begin// if button is pressed, increase the count
                if(set_H1)
                    if(tmp_hour/10 >= 2)
                        tmp_hour <= tmp_hour - 20;
                    else
                        tmp_hour <= tmp_hour + 1*10;
                else if(set_H0)
                    if(tmp_hour >= 23)
                        tmp_hour <= tmp_hour - 3;
                    else if(tmp_hour%10 >= 9)
                        tmp_hour <= tmp_hour - 9;
                    else
                        tmp_hour <= tmp_hour + 1;
                else if(set_M1)
                    if(tmp_minute/10 >= 5)
                        tmp_minute <= tmp_minute - 50;
                    else
                        tmp_minute <= tmp_minute + 1*10;
                else if(set_M0)
                    if(tmp_minute%10 >= 9)
                        tmp_minute <= tmp_minute - 9;
                    else
                        tmp_minute <= tmp_minute + 1;
            end
            displayed_num <= tmp_hour*10000 + tmp_minute*100 + tmp_second;
         end
         else if(clock_format) begin // switching from 24-hour format to 12-hour format
              if (tmp_hour == 0) 
                  displayed_num <= 12*10000 + tmp_minute*100 + tmp_second;
              else if (tmp_hour >= 13) 
                  displayed_num <= (tmp_hour - 12)*10000 + tmp_minute*100 + tmp_second;
         end
         else if(stopwatch) begin
            func_second <= func_second + 1;
            if(func_second >=59) begin // second > 59 then minute increases
                func_minute <= func_minute + 1;
                func_second <= 0;
                end
            if(func_minute >=59) begin // minute > 59 then hour increases
                func_hour <= func_hour + 1;
                func_minute <= 0;
                end
            if((func_hour==23)&&(func_minute==59)&&(func_second==59)) //stopwatch limit
                displayed_num <= 23*10000 + 59*100 + 59;  
            if(stop)
                pause <= 1;
            if(pause)
                displayed_num <= displayed_num;  //displays the current time when stop is pressed
            else
                displayed_num <= func_hour*10000 + func_minute*100 + func_second;
         end
         else if(timer) begin
            if(load_counter) begin// if button is pressed, increase the count
                if(set_H1)
                    if(func_hour/10 >= 2)
                        func_hour <= func_hour - 20;
                    else
                        func_hour <= func_hour + 1*10;
                else if(set_H0)
                    if(func_hour >= 23)
                        func_hour <= func_hour - 3;
                    else if(func_hour%10 >= 9)
                        func_hour <= func_hour - 9;
                    else
                        func_hour <= func_hour + 1;
                else if(set_M1)
                    if(func_minute/10 >= 5)
                        func_minute <= func_minute - 50;
                    else
                        func_minute <= func_minute + 1*10;
                else if(set_M0)
                    if(func_minute%10 >= 9)
                       func_minute <= func_minute - 9;
                    else
                       func_minute <= func_minute + 1;
            displayed_num <= func_hour*10000 + func_minute*100 + func_second;
            end
            else if((func_hour==0)&&(func_minute==0)&&(func_second==0)) begin  //timer reaches 0
                displayed_num <= 0;
                LED_signal <= 1;
            end
            else begin
                if(start)
                    go <= 1;
                if(go) begin
                    if(func_second <= 0) begin // second < 0 then minute decreases
                        func_minute <= func_minute - 1;
                        func_second <= 59;
                        end
                    else
                        func_second <= func_second - 1;
                    if(func_minute <= 0) begin // minute < 0 then hour decreases
                        if(func_hour == 0)
                            func_minute <= 0;
                        else begin
                            func_hour <= func_hour - 1;
                            func_minute <= 59;
                        end
                    end
                end
                displayed_num <= func_hour*10000 + func_minute*100 + func_second;
                LED_signal <= 0;
            end
         end
        else begin
            displayed_num <= tmp_hour*10000 + tmp_minute*100 + tmp_second;
            //               LEDs 1 & 2,      LEDs 3 & 4,      LEDs 5 & 6
            func_hour <= 0;
            func_minute <= 0;
            func_second <= 0;
            pause <= 0;
            go <= 0;
        end
     end
     end 
 
//Create 1 second clock
 always @(posedge clk or posedge rst)
 begin
 if(rst) begin
    tmp_1s <= 0;
    clk_1s <= 0;
 end
 else begin
    tmp_1s <= tmp_1s + 1;
    if(tmp_1s <= N/2 - 1) //50 MHz 
        clk_1s <= 0;
    else if (tmp_1s >= N - 1) begin  //100 MHz
        clk_1s <= 1;
        tmp_1s <= 0;
    end
    else
        clk_1s <= 1;
 end
 end
 
//Anodes and Cathodes of the SSD
 always @(*)
    begin
        case(LED_activating_counter) //decoder to generate anode signals
        3'b000: begin
            anode = 6'b011111; // activate LED1 
            LED_BCD = displayed_num/100000; //first digit of SSD , H1
            end
        3'b001: begin
            anode = 6'b101111; // activate LED2 
            LED_BCD = (displayed_num%100000)/10000; //second digit of SSD, H0
            end
        3'b010: begin
            anode = 6'b110111; // activate LED3 
            LED_BCD = ((displayed_num%100000)%10000)/1000; //third digit of SSD, M1
            end
        3'b011: begin
            anode = 6'b111011; // activate LED4
            LED_BCD = (((displayed_num%100000)%10000)%1000)/100; //fourth digit of SSD, M0
            end   
        3'b100: begin
            anode = 6'b111101; // activate LED5
            LED_BCD = ((((displayed_num%100000)%10000)%1000)%100)/10; //fifth digit of SSD, most significant second digit
            end
        3'b101: begin
            anode = 6'b111110; // activate LED6
            LED_BCD = ((((displayed_num%100000)%10000)%1000)%100)%10; //sixth digit of SSD, least significant second digit
            end
        endcase
    end
    
always @ (*)
   case (LED_BCD) 
		4'h0: cathode[7:0] = 8'hC0;
        4'h1: cathode[7:0] = 8'hF9;
        4'h2: cathode[7:0] = 8'hA4;
        4'h3: cathode[7:0] = 8'hB0;
        4'h4: cathode[7:0] = 8'h99;
        4'h5: cathode[7:0] = 8'h92;
        4'h6: cathode[7:0] = 8'h82;
        4'h7: cathode[7:0] = 8'hF8;
        4'h8: cathode[7:0] = 8'h80;
        4'h9: cathode[7:0] = 8'h90;
      default: cathode[7:0] = 8'hC0; //default is 0 
   endcase
 
//LED Flash Functions
 always @(*) begin   
     if(LED_signal == 1 && tmp_second%2 == 1) //flashes the LED every second for a minute every new hour
        if(timer)
            LED = 2'b01;  //red when timer reaches 0
        else 
            LED = 2'b10;  //blue on every new clock hour
     else
        LED = 0;
 end
 
endmodule 
