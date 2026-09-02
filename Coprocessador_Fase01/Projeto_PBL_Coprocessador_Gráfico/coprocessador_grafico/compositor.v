module compositor (
    input  wire enable_bg, enable_sprite, enable_poly,
    input  wire [7:0] cor_bg,
    input  wire bg_valido,
    input  wire [7:0] cor_poly,   input wire poly_ativo,
    input  wire [7:0] cor_sprite, input wire sprite_ativo,
    output reg  [7:0] cor_final
);
	
	// Prioridade fixa: sprite > poligono > background
	
    always @(*) begin
        if (enable_sprite && sprite_ativo && (cor_sprite != 8'd0)) //sprite vence
            cor_final = cor_sprite;
        else if (enable_poly && poly_ativo && (cor_poly != 8'd0)) //poligono vence
            cor_final = cor_poly;
        else if (enable_bg && bg_valido) //background vence
            cor_final = cor_bg;
        else
            cor_final = 8'd0; // transparente/Preto
    end

endmodule
