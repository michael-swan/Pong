`timescale 1ns / 1ps
module Pong(
	input Clock_100Mhz,
	input P1_UP,
	input P1_DOWN,
	input P2_UP,
	input P2_DOWN,
	output reg [7:0] R,
	output reg [7:0] G,
	output reg [7:0] B,
	output PIXEL_CLOCK,
	output V_SYNC,
	output H_SYNC,
	output C_SYNC,
	output VGA_BLANK
	);
	// Counters to track the state of the raster beam
	wire [8:0] H_COUNTER;
	wire [8:0] V_COUNTER;
	
	VideoSync signals(
		// Inputs
		Clock_100Mhz,
		// Output to the DAC
		PIXEL_CLOCK,
		V_SYNC,
		H_SYNC,
		C_SYNC,
		VGA_BLANK,
		// Relevant to this module
		H_COUNTER,
		V_COUNTER);

	// Screen parameters
	parameter SCREEN_TOP = 35;
	parameter SCREEN_BOTTOM = 245;
	parameter SCREEN_LEFT = 70;
	parameter SCREEN_RIGHT = 390;

	// Sizing paramters
	parameter PADDLE_HEIGHT = 40;
	parameter PADDLE_WIDTH = 10;
	parameter BALL_SIZE = 5;
	
	// Registers
	reg [9:0] PADDLE_1_X;
	reg [9:0] PADDLE_1_Y;
	reg [1:0] PADDLE_1_FRAME [9:0];
	reg [9:0] PADDLE_2_X;
	reg [9:0] PADDLE_2_Y;
	reg [1:0] PADDLE_2_FRAME [9:0];

	reg [1:0] DIRECTION;
	reg [9:0] BALL_X;
	reg [9:0] BALL_Y;
	
	// Ball side variables
	wire [9:0] BALL_LEFT = BALL_X;
	wire [9:0] BALL_RIGHT = BALL_X + BALL_SIZE;
	wire [9:0] BALL_TOP = BALL_Y;
	wire [9:0] BALL_BOTTOM = BALL_Y + BALL_SIZE;
	
	wire [9:0] PADDLE_1_LEFT = PADDLE_1_X;
	wire [9:0] PADDLE_1_RIGHT = PADDLE_1_X + PADDLE_WIDTH; // Unused
	wire [9:0] PADDLE_1_TOP = PADDLE_1_Y;
	wire [9:0] PADDLE_1_BOTTOM = PADDLE_1_Y + PADDLE_HEIGHT;
	
	wire [9:0] PADDLE_2_LEFT = PADDLE_2_X; // Unused
	wire [9:0] PADDLE_2_RIGHT = PADDLE_2_X + PADDLE_WIDTH;
	wire [9:0] PADDLE_2_TOP = PADDLE_2_Y;
	wire [9:0] PADDLE_2_BOTTOM = PADDLE_2_Y + PADDLE_HEIGHT;
	
	// Boolean variables
	wire BALL_HIT_TOP = (BALL_TOP <= SCREEN_TOP);
	wire BALL_HIT_BOTTOM = (BALL_BOTTOM >= SCREEN_BOTTOM);
	wire BALL_HIT_WALL = BALL_HIT_TOP || BALL_HIT_BOTTOM;
	wire BALL_HIT_LEFT_PADDLE = BALL_LEFT >= PADDLE_1_RIGHT - 2 && BALL_LEFT <= PADDLE_1_RIGHT &&
										 BALL_TOP <= PADDLE_1_BOTTOM && BALL_BOTTOM >= PADDLE_1_TOP && DIRECTION[1];
	wire BALL_HIT_RIGHT_PADDLE = BALL_RIGHT <= PADDLE_2_LEFT + 2 && BALL_RIGHT >= PADDLE_2_LEFT &&
										  BALL_TOP <= PADDLE_2_BOTTOM && BALL_BOTTOM >= PADDLE_2_TOP && !DIRECTION[1];
	wire BALL_HIT_PADDLE = BALL_HIT_LEFT_PADDLE || BALL_HIT_RIGHT_PADDLE;
	wire GOAL_MADE = BALL_X <= 30 || BALL_X >= 390; 
	
	// Raster beam booleans
	assign BEAM_ON_LEFT_PADDLE_HORIZONTALLY = H_COUNTER >= PADDLE_1_LEFT && H_COUNTER <= PADDLE_1_RIGHT;
	assign BEAM_ON_RIGHT_PADDLE_HORIZONTALLY = H_COUNTER >= PADDLE_2_LEFT && H_COUNTER <= PADDLE_2_RIGHT;
	assign BEAM_ON_LEFT_PADDLE_VERTICALLY = V_COUNTER >= PADDLE_1_TOP && V_COUNTER <= PADDLE_1_BOTTOM;
	assign BEAM_ON_RIGHT_PADDLE_VERTICALLY = V_COUNTER >= PADDLE_2_TOP && V_COUNTER <= PADDLE_2_BOTTOM;
	assign BEAM_ON_LEFT_PADDLE = BEAM_ON_LEFT_PADDLE_HORIZONTALLY && BEAM_ON_LEFT_PADDLE_VERTICALLY;
	assign BEAM_ON_RIGHT_PADDLE = BEAM_ON_RIGHT_PADDLE_HORIZONTALLY && BEAM_ON_RIGHT_PADDLE_VERTICALLY;
	assign BEAM_ON_PADDLE = BEAM_ON_LEFT_PADDLE || BEAM_ON_RIGHT_PADDLE;
	
	assign BEAM_ON_BALL = H_COUNTER >= BALL_LEFT && H_COUNTER <= BALL_RIGHT &&
						  V_COUNTER >= BALL_TOP && V_COUNTER <= BALL_BOTTOM;

	// Initialize registers.
	initial begin
		// Paddle positions
		PADDLE_1_X = 92;
		PADDLE_1_Y = 100;
		PADDLE_2_X = 350;
		PADDLE_2_Y = 100;
		// Paddle frame capture registers
		PADDLE_1_FRAME[0] = 0;
		PADDLE_1_FRAME[1] = 0;
		PADDLE_2_FRAME[0] = 0;
		PADDLE_2_FRAME[1] = 0;
		// Ball
		BALL_X = 180;
		BALL_Y = 150;
		// Direction
		DIRECTION = 0;
	end
	reg [22:0] clock_counter = 0;
	
	// Draw game objects.
	always @(posedge PIXEL_CLOCK) begin
		// Handle wall collisions: ball deflects vertically.
		if(BALL_HIT_WALL) begin
			DIRECTION[0] <= !DIRECTION[0];
			if(BALL_HIT_TOP) begin
				BALL_Y <= BALL_Y + 2;
			end else if(BALL_HIT_BOTTOM) begin
				BALL_Y <= BALL_Y - 2;
				//BALL_X <= BALL_X - 2;
			end
		end
		// Handle paddle collisions: ball deflects horizontally and vertically
		if(BALL_HIT_PADDLE) begin
			DIRECTION <= DIRECTION + 2;
		end
		
		// Handle ball going off screen on the sides: player score change and ball returns to center
		if(GOAL_MADE) begin
			BALL_X <= 180;
			BALL_Y <= 150;
			DIRECTION[1] <= !DIRECTION[1];
		end
		// Display the paddles and ball
		if(BEAM_ON_PADDLE || BEAM_ON_BALL) begin
			R <= 255; G <= 255; B <= 255;
		end else begin
			R <= 0; G <= 0; B	<= 0;
		end
		// Move the ball at a constant rate in its current direction
		if(clock_counter[15]) begin
			if(DIRECTION[1])
				BALL_X <= BALL_X - 1;
			else
				BALL_X <= BALL_X + 1;
				
			if(DIRECTION[0])
				BALL_Y <= BALL_Y - 1;
			else
				BALL_Y <= BALL_Y + 1;
			clock_counter <= 0;
		end else clock_counter <= clock_counter + 1;
	end
	
	// Generate lower clock signals. //
	wire Clock_48Hz = clock_counter[18];

	// Check paddle movement buttons at 48Hz
	always @(posedge clock_counter[14]) 
	begin
		if(!P1_UP && PADDLE_1_TOP > SCREEN_TOP)
			PADDLE_1_Y <= PADDLE_1_Y - 1;
		else if(!P1_DOWN && PADDLE_1_BOTTOM < SCREEN_BOTTOM)
			PADDLE_1_Y <= PADDLE_1_Y + 1;
		if(!P2_UP && PADDLE_2_TOP > SCREEN_TOP)
			PADDLE_2_Y <= PADDLE_2_Y - 1;
		else if(!P2_DOWN && PADDLE_2_BOTTOM < SCREEN_BOTTOM)
			PADDLE_2_Y <= PADDLE_2_Y + 1;
	end
endmodule
