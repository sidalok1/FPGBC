`default_nettype none
module CondCheck ( cc, flags, result );

	`include "Cond_params.vh"

	input wire [1:0] cc;
	input wire [3:0] flags;
	output wire result;

	wire conds [0:3];
	assign conds[NZERO ] = ~flags[3];
	assign conds[ ZERO ] =  flags[3];
	assign conds[NCARRY] = ~flags[0];
	assign conds[ CARRY] =  flags[0];

	assign result = conds[cc];

endmodule