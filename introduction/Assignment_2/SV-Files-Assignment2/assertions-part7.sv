////////////////////////////////////////////////////////////////////////////////
//
// File name    :   assertions.sv
// Project name :   SV_basics
// Author       :
// Date Created :
// Company      :   Team Training
//
////////////////////////////////////////////////////////////////////////////////
//
// Description: Part 7
//
////////////////////////////////////////////////////////////////////////////////

module assertions();

logic a,b,c,d,e,f,g,h,i;
logic clk = 0;


	always begin
		#5ns clk = ~clk;
	end


	initial begin
		a = 0;
		b = 0;
		c = 0;
		d = 0;
		e = 0;
		f = 0;
		g = 0;
		fork
			automatic int clks_to_wait = 0;

			// Ex. 1 generation
			repeat(10) begin

				clks_to_wait = $urandom_range(0,50);

				repeat(clks_to_wait) @(posedge clk) begin
					b <= $random();
				end


				repeat(2) @(posedge clk);
				a <= 1;
				b <= 1;
				repeat(3) @(posedge clk);
				a <= 0;
				b <= 0;
				repeat(5) @(posedge clk);


			end

			// Ex. 2 generation
			repeat(10) begin

				int clks_c_high = $urandom_range(1,10);
				int clk_to_raise_d = $urandom_range(0,clks_c_high);
				clks_to_wait = $urandom_range(0,50);

				repeat(clks_to_wait) @(posedge clk) begin
					d <= $random();
				end

				d <= 0;
				repeat(1) @(posedge clk);
				c <= 1;
				repeat(clk_to_raise_d) @(posedge clk);
				d <= 1;
				repeat(clks_c_high - clk_to_raise_d) @(posedge clk);
				c <= 0;
			end

			// Ex. 3 generation
			repeat(10) begin

				int clks_c_high = $urandom_range(1,10);
				int clk_to_raise_d = $urandom_range(0,clks_c_high);
				clks_to_wait = $urandom_range(0,50);

				repeat(clks_to_wait) @(posedge clk) begin
					g <= $random();
				end

				e <= 1;
				f <= 1;
				repeat(clk_to_raise_d) @(posedge clk);
				f <= 0;
				repeat(clks_c_high - clk_to_raise_d) @(posedge clk);
				e <= 0;

			end

		join

		$finish();
	end

	logic[4:0] temp;

	// Ex. 4 generation
	always_ff @(posedge clk) begin
		h <= $random();
		temp[0] <= h;
		temp[4:1] <= temp[3:0];
		i <= temp[4];
	end




	/*--------------------------------------------
								      	|
		Fill the assertions below		|
										V
	---------------------------------------------*/
	assert property (@(posedge clk)
		// Assertions 1:
	) begin
		$display("assertion 1: %0d",$time());
	end

	assert property (@(posedge clk)
		// Assertion 2:
	) begin
		$display("assertion 2: %0d",$time());
	end

	assert property (@(posedge clk)
		// Assertions 3:
	) begin
		$display("assertion 3: %0d",$time());
	end

	assert property (@(posedge clk)
		// Assertions 4:
	) begin
		$display("assertion 4: %0d",$time());
	end



endmodule