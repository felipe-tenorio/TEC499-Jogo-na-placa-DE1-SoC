module rasterizador_multi (
    input  wire clk_pix, reset,
    input  wire signed [9:0] logico_x, logico_y,

    // Coordenadas dos vértices dos 4 polígonos
    input  wire signed [9:0] poly_vx [0:3][0:2],
    input  wire signed [9:0] poly_vy [0:3][0:2],

    // Cor de cada polígono
    input  wire [7:0] poly_cor [0:3],

    // Indica quais polígonos estão habilitados
    input  wire poly_habilitado [0:3],

    // Define se o polígono é retângulo ou triângulo
    input  wire poly_modo_retangulo [0:3],

    // Saídas do rasterizador
    output wire pixel_ativo,
    output wire [7:0] cor_indice
);

    integer i;

    // Indica se o pixel atual está dentro de cada polígono
    reg dentro [0:3];
    reg achou;
    // Índice do polígono que será desenhado
    reg [1:0] vencedor;


    // Verifica se um ponto está dentro de um triângulo
    function automatic dentro_triangulo;
        input signed [9:0] px, py;
        input signed [9:0] x0, y0, x1, y1, x2, y2;

        // Valores usados para verificar o lado de cada aresta
        reg signed [23:0] e0, e1, e2;

        begin
            e0 = (px - x0) * (y1 - y0) -
                 (py - y0) * (x1 - x0);
            e1 = (px - x1) * (y2 - y1) -
                 (py - y1) * (x2 - x1);
            e2 = (px - x2) * (y0 - y2) -
                 (py - y2) * (x0 - x2);

            // O ponto está dentro se os sinais das três arestas
            // forem todos positivos ou todos negativos
            dentro_triangulo = (e0 >= 0 && e1 >= 0 && e2 >= 0) ||
                                (e0 <= 0 && e1 <= 0 && e2 <= 0);
        end
    endfunction

    always @(*) begin
        
        for (i = 0; i < 4; i = i + 1) begin// Verifica cada um dos 4 polígonos

            // Se estiver no modo retângulo
            if (poly_modo_retangulo[i]) begin

                dentro[i] = poly_habilitado[i] &&
                            logico_x >= poly_vx[i][0] &&
                            logico_x <  poly_vx[i][1] &&
                            logico_y >= poly_vy[i][0] &&
                            logico_y <  poly_vy[i][1];

            end else begin

                //verifica se está dentro do triângulo
                dentro[i] = poly_habilitado[i] &&
                    dentro_triangulo(
                        logico_x, logico_y,
                        poly_vx[i][0], poly_vy[i][0],
                        poly_vx[i][1], poly_vy[i][1],
                        poly_vx[i][2], poly_vy[i][2]
                    );
            end
        end


        //nenhum poligono foi encontrado
        achou    = 1'b0;
        vencedor = 2'd0;


        //procura o primeiro poligono que contém o pixel
        for (i = 0; i < 4; i = i + 1) begin
            if (dentro[i] && !achou) begin
                achou    = 1'b1;
                vencedor = i[1:0];
            end
        end
    end


    //pndica se o pixel deve ser desenhado
    assign pixel_ativo = achou;

    // Retorna a cor do poligono vencedor
    assign cor_indice = poly_cor[vencedor];

endmodule