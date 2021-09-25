`timescale 1ns/10ps
module SME ( clk, reset, case_insensitive, pattern_no, match_addr, valid, finish, T_data, T_addr, P_data, P_addr);
input         clk;
input         reset;
input         case_insensitive;
output [3:0]  pattern_no;
output [11:0] match_addr;
output        valid;
output        finish;
input  [7:0]  T_data;
output [11:0] T_addr;
input  [7:0]  P_data;
output [6:0]  P_addr;
//--------------------------------------------------------------------------
reg        valid, finish;
reg [3:0]  pattern_no;
reg [6:0]  P_addr;
reg [11:0] match_addr, T_addr, T_count, T_count_ex;

reg [2:0] state;
reg [3:0] pattern_count,
          pattern_count_max,
          pattern_letter_count,
          pattern_letter_count_ex,
          pattern_letter_skip;
reg [7:0] all_letter_count, T_data_case;
reg [7:0] pattern_array [14:0][13:0];
reg [7:0] string_mem [4095:0];

parameter receive_p = 3'b000, read_s = 3'b001, pendding = 3'b010, compare = 3'b011, compare_question = 3'b100;
//--------------------------------------------------------------------------
always@(posedge clk or posedge reset) begin
    if(reset)begin
        valid = 0; finish = 0;
        state = receive_p;
        all_letter_count = 0;
        pattern_count = 0; pattern_count_max = 0;
        pattern_letter_count = 0;
    end else begin
        case (state)
            receive_p:begin
                if(pattern_letter_count == 0 && P_data == 0) begin
                    state = read_s;
                    T_addr = 0;
                end else begin
                    state = receive_p;
                    P_addr = all_letter_count;
                    all_letter_count = all_letter_count + 1;
                    if(P_data || P_data == 0) begin
                        if(case_insensitive == 1 && (P_data >= 8'h41 && P_data <= 8'h5A))
                            pattern_array[pattern_count][pattern_letter_count] = P_data + 8'h20;
                        else if(case_insensitive == 0 && (P_data >= 8'h41 && P_data <= 8'h5A))
                            pattern_array[pattern_count][pattern_letter_count] = P_data;
                        else pattern_array[pattern_count][pattern_letter_count] = P_data;
                        if(P_data == 0) begin
                            pattern_letter_count = 0;
                            pattern_count = pattern_count + 1;
                        end else begin
                            pattern_letter_count = pattern_letter_count + 1;
                            pattern_count = pattern_count;
                        end
                    end
                end
            end
            read_s: begin
                if(T_data >= 0) begin
                    string_mem[T_addr - 1] = T_data;
                    if(T_data == 0) state = pendding;
                    else state = read_s;
                    T_addr = T_addr + 1;
                end else T_addr = T_addr + 1;
            end
            compare: begin
                if(case_insensitive == 1 && string_mem[T_count] >= 8'h41 && string_mem[T_count] <= 8'h5A)
                    T_data_case = string_mem[T_count] + 8'h20;
                else if(case_insensitive == 0 && string_mem[T_count] >= 8'h41 && string_mem[T_count] <= 8'h5A)
                    T_data_case = string_mem[T_count];
                else T_data_case = string_mem[T_count];
                valid = 0;
                if(T_data_case !== 0) begin
                    if(pattern_array[pattern_count][pattern_letter_count] == 0
                            || ((pattern_array[pattern_count][pattern_letter_count] == 8'h3F)
                                && (pattern_array[pattern_count][pattern_letter_count + 1] == 0))
                            || ((pattern_array[pattern_count][pattern_letter_count + 1] == 8'h3F)
                                && (pattern_array[pattern_count][pattern_letter_count + 2] == 0))) begin
                        valid = 1;
                        pattern_no = pattern_count;
                        if(pattern_array[pattern_count][0] == 8'h5E) match_addr = T_count - pattern_letter_count + pattern_letter_skip + 1;
                        else match_addr = T_count - pattern_letter_count + pattern_letter_skip;

                        if(pattern_letter_skip > 0) T_count = T_count + 1;
                        else T_count = T_count - pattern_letter_count + pattern_letter_skip + 1;
                        pattern_letter_count = 0;
                        pattern_letter_skip = 0;

                    end else if(T_data_case == pattern_array[pattern_count][pattern_letter_count]
                            || ((pattern_array[pattern_count][pattern_letter_count] == 8'h2E) && (T_data_case !== 8'h0A))
                            || ((pattern_array[pattern_count][pattern_letter_count] == 8'h2E) && (T_data_case !== 8'h0A))
                            || ((pattern_array[pattern_count][pattern_letter_count] == 8'h5E) && (T_data_case == 8'h0A))
                            || ((pattern_array[pattern_count][pattern_letter_count] == 8'h24) && (T_data_case == 8'h0A))) begin
                            pattern_letter_count = pattern_letter_count + 1;
                            T_count = T_count + 1;
                    end else if(pattern_array[pattern_count][pattern_letter_count] == 8'h3F
                                || pattern_array[pattern_count][pattern_letter_count + 1] == 8'h3F) begin
                        state = compare_question;
                        T_count_ex = T_count;
                        pattern_letter_count_ex = pattern_letter_count;
                    end else begin
                        T_count = T_count - pattern_letter_count + pattern_letter_skip + 1;
                        pattern_letter_count = 0;
                        pattern_letter_skip = 0;
                    end
                end else begin
                    if(pattern_count == pattern_count_max) finish = 1;
                    else begin
                        finish = 0;
                        T_count = 0;
                        pattern_letter_count = 0;
                        pattern_letter_skip = 0;
                        pattern_count = pattern_count + 1;
                    end
                end
            end
            compare_question: begin
                if(case_insensitive == 1 && string_mem[T_count_ex] >= 8'h41 && string_mem[T_count_ex] <= 8'h5A)
                    T_data_case = string_mem[T_count_ex] + 8'h20;
                else if(case_insensitive == 0 && string_mem[T_count_ex] >= 8'h41 && string_mem[T_count_ex] <= 8'h5A)
                    T_data_case = string_mem[T_count_ex];
                else T_data_case = string_mem[T_count_ex];

                if(T_data_case == pattern_array[pattern_count][pattern_letter_count_ex]
                        || ((pattern_array[pattern_count][pattern_letter_count_ex] == 8'h2E) && (T_data_case !== 8'h0A))
                        || ((pattern_array[pattern_count][pattern_letter_count_ex] == 8'h2E) && (T_data_case !== 8'h0A))
                        || ((pattern_array[pattern_count][pattern_letter_count_ex] == 8'h5E) && (T_data_case == 8'h0A))
                        || ((pattern_array[pattern_count][pattern_letter_count_ex] == 8'h24) && (T_data_case == 8'h0A))) begin
                    pattern_letter_count_ex = pattern_letter_count_ex + 1;
                    pattern_letter_skip = pattern_letter_skip;
                    T_count_ex = T_count_ex + 1;
                end else if(pattern_array[pattern_count][pattern_letter_count_ex] == 8'h3F) begin
                    pattern_letter_count_ex = pattern_letter_count_ex + 1;
                    pattern_letter_skip = pattern_letter_skip + 1;
                    T_count_ex = T_count_ex;
                end else if(pattern_array[pattern_count][pattern_letter_count_ex + 1] == 8'h3F) begin
                    pattern_letter_count_ex = pattern_letter_count_ex + 2;
                    pattern_letter_skip = pattern_letter_skip + 2;
                    T_count_ex = T_count_ex;
                end else  begin
                    state = compare;
                    T_count = T_count_ex;
                    pattern_letter_count = pattern_letter_count_ex;
                    T_count_ex = 0;
                    pattern_letter_count_ex = 0;
                end
            end
            pendding: begin
                state = compare;
                pattern_count_max = pattern_count;
                T_count = 0; valid = 0;
                all_letter_count = 0;
                pattern_count = 0;
                pattern_letter_count = 0;
                pattern_letter_skip = 0;
            end
        endcase
    end
end
//--------------------------------------------------------------------------
endmodule
