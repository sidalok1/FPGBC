`include "Cond_headers.vh"
module CondCheck ( cc, flags, result );
	input wire [1:0] cc;
	input wire [3:0] flags;
	output wire result;

	wire conds [0:3];
	assign conds[`nzero ] = ~flags[3];
	assign conds[ `zero ] =  flags[3];
	assign conds[`ncarry] = ~flags[0];
	assign conds[ `carry] =  flags[0];

	assign result = conds[cc];

endmodule