module coprocessador (
    input  wire CLOCK_50,
    input  wire [9:0] SW,
    input  wire [3:0] KEY,
    output wire [7:0] VGA_R, VGA_G, VGA_B,
    output wire VGA_HS, VGA_VS, VGA_CLK, VGA_BLANK_N, VGA_SYNC_N,
    output wire [9:0] LEDR,
	 output wire [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5
);

    // Clocks e reset
    wire reset = ~KEY[3] | ~pll_locked | ~pll_locked_100;
    wire clk_pix, pll_locked;
	 wire clk_pll_100, pll_locked_100;

    meu_pll u_pll (
        .refclk(CLOCK_50),
        .outclk_0(clk_pix),
        .locked(pll_locked)
    );

    pllpara100 pllmhz (
        .refclk(CLOCK_50),
        .rst(~KEY[3]),
        .outclk_0(clk_pll_100),
        .locked(pll_locked_100)
    );

    // Debounce dos botoes
    wire p_key0, p_key1, p_key2;
    debounce_edge u_db0 (.clk(CLOCK_50), .reset(reset), .tecla_bruta(KEY[0]), .pulso(p_key0));
    debounce_edge u_db1 (.clk(CLOCK_50), .reset(reset), .tecla_bruta(KEY[1]), .pulso(p_key1));
    debounce_edge u_db2 (.clk(CLOCK_50), .reset(reset), .tecla_bruta(KEY[2]), .pulso(p_key2));

    // Porta de estimulo para Banco de registradores
    wire wr_en_regs;
    wire [15:0] endereco_regs;
    wire [8:0]  dado_regs;
    wire [2:0]  cenario_ativo;
    wire estimulo_invalido;
	 wire [6:0] hex0_w, hex1_w, hex2_w, hex3_w, hex4_w, hex5_w;


    porta_estimulo u_estimulo (
        .clk_sys(CLOCK_50),
        .reset(reset),
        .SW(SW),
        .pulso_key0(p_key0), //botoes
        .pulso_key1(p_key1),
        .pulso_key2(p_key2),
        .wr_en(wr_en_regs),
        .endereco(endereco_regs), //sinais para registradores
        .dado(dado_regs),
        .cenario_ativo(cenario_ativo),
        .estimulo_invalido(estimulo_invalido),
		  .HEX0(hex0_w),
        .HEX1(hex1_w),
        .HEX2(hex2_w),
        .HEX3(hex3_w),
        .HEX4(hex4_w),
        .HEX5(hex5_w)
    
    );
	 

    wire [7:0] bg_scroll_x, bg_scroll_y; //Deslocamento do background
    wire [4:0] sprite_sel;

    wire [8:0] sprite_x       [0:31]; //Posiçao
    wire [8:0] sprite_y       [0:31];
    wire [4:0] sprite_padrao  [0:31];
    wire       sprite_en      [0:31];
    wire [2:0] sprite_pri     [0:31];
    wire       sprite_fliph   [0:31]; //Espelhamento
    wire       sprite_flipv   [0:31];

    wire enable_bg, enable_sprite, enable_poly; //Flags

    wire [8:0] ovr_spr1_x;
    wire ovr_prioridade;
    wire swap_request;
		
	//Poligonos
    wire signed [9:0] poly_vx [0:3][0:2]; //Posiçoes
    wire signed [9:0] poly_vy [0:3][0:2];
    wire [7:0] poly_cor [0:3]; //Opcao de cores (Vermelho, Verde, Azul, Amarelo)
    wire poly_habilitado [0:3];
    wire poly_modo_retangulo [0:3];
    wire [7:0] status;
    wire endereco_invalido;

    banco_registradores u_regs (
        .clk_sys(clk_pll_100),
        .reset(reset),
        .wr_en(wr_en_regs),
        .endereco(endereco_regs),
        .dado_in(dado_regs),
        .bg_scroll_x(bg_scroll_x), //Scroll bg
        .bg_scroll_y(bg_scroll_y),
        .sprite_sel(sprite_sel),   //Indice da sprite selecionada
        .sprite_x(sprite_x),			//Posiçao da sprite selecionada
        .sprite_y(sprite_y),
        .sprite_padrao(sprite_padrao),
        .sprite_en(sprite_en),
        .sprite_pri(sprite_pri),
        .sprite_fliph(sprite_fliph), //Espelhamento
        .sprite_flipv(sprite_flipv),
        .enable_bg(enable_bg),       //Flags
        .enable_sprite(enable_sprite),
        .enable_poly(enable_poly),
        .ovr_spr1_x(ovr_spr1_x),
        .ovr_prioridade(ovr_prioridade),
        .swap_request(swap_request),
        .poly_vx(poly_vx), //Posiçao do poligono
        .poly_vy(poly_vy),
        .poly_cor(poly_cor),
        .poly_habilitado(poly_habilitado),
        .poly_modo_retangulo(poly_modo_retangulo),
        .status(status),
        .estimulo_invalido(estimulo_invalido), //Entrada invalida
        .buffer_pronto(pll_locked_100),
        .endereco_invalido(endereco_invalido)
    );

    // Fios memorias ram 2-Port 
    wire [10:0] tilemap_addr;
    wire [7:0]  tilemap_data_a, tilemap_data_b, tilemap_data;

	 wire [12:0] padrao_addr_sprite;
    wire [7:0]  padrao_data_sprite;
	 	
    wire [13:0] padrao_addr;
    wire [7:0]  padrao_data;
	
	//Memorias para o tile map
	
	ram_tilemap ramA( //8 bits de entrada e saida, 2048
	.clock(clk_pll_100),
	.data(8'd0),
	.rdaddress(tilemap_addr),
	.wraddress(11'd0),
	.wren(1'b0),
	.q(tilemap_data_a)
	);
		
	ram_tilemapB ramB(  //8 bits de entrada e saida, 2048
	.clock(clk_pll_100),
	.data(8'd0),
	.rdaddress(tilemap_addr),
	.wraddress(11'd0),
	.wren(1'b0),
	.q(tilemap_data_b)
	);
	 
	//Ram das sprites
 ram_sprites rspt( //8 bits de entrada e saida, 8192
	.clock(clk_pll_100),
	.data(8'd0),
	.rdaddress(padrao_addr_sprite),
	.wraddress(13'd0),
	.wren(1'b0),
	.q(padrao_data_sprite));
	
	//Ram do padrao de tiles
  ram_padrao_tiles ramtp ( //8 bits de entrada e saida, 16384
	.clock(clk_pll_100),
	.data(8'd0),
	.rdaddress(padrao_addr),
	.wraddress(14'd0),
	.wren(1'b0),
	.q(padrao_data));

    wire vga_vs_int;
    reg  vsync_pix_ff1, vsync_pix_ff2;
    wire vsync_borda_pix = vsync_pix_ff2 & ~vsync_pix_ff1; // borda de subida

    always @(posedge clk_pix) begin
        vsync_pix_ff1 <= vga_vs_int;
        vsync_pix_ff2 <= vsync_pix_ff1;
    end

    // Troca de buffer somente na borda de vsync
    reg buffer_ativo;
    reg [2:0] swap_sync;
    reg swap_pendente;

    always @(posedge clk_pix) begin
        swap_sync <= {swap_sync[1:0], swap_request};
    end
    wire swap_pulso_pix = swap_sync[1] & ~swap_sync[2];

    always @(posedge clk_pix) begin
        if (reset) begin
            buffer_ativo  <= 1'b0;
            swap_pendente <= 1'b0;
        end else begin
            if (vsync_borda_pix && swap_pendente) begin
                buffer_ativo  <= ~buffer_ativo;
                swap_pendente <= 1'b0;
            end
            if (swap_pulso_pix)
                swap_pendente <= 1'b1;
        end
    end

    assign tilemap_data = buffer_ativo ? tilemap_data_b : tilemap_data_a;

    // Sincroniza bg_scroll_x/y,clk_pix e só confirma o valor usado pelo motor na borda de vsync.
    reg [7:0] bg_scroll_x_sync1, bg_scroll_x_sync2;
    reg [7:0] bg_scroll_y_sync1, bg_scroll_y_sync2;
    reg [7:0] bg_scroll_x_quadro, bg_scroll_y_quadro;

    always @(posedge clk_pix) begin
        bg_scroll_x_sync1 <= bg_scroll_x;
        bg_scroll_x_sync2 <= bg_scroll_x_sync1;
        bg_scroll_y_sync1 <= bg_scroll_y;
        bg_scroll_y_sync2 <= bg_scroll_y_sync1;

        if (reset) begin
            bg_scroll_x_quadro <= 8'd0;
            bg_scroll_y_quadro <= 8'd0;
        end else if (vsync_borda_pix) begin
            bg_scroll_x_quadro <= bg_scroll_x_sync2;
            bg_scroll_y_quadro <= bg_scroll_y_sync2;
        end
    end
	
	//Pipeline
	// Durante a area ativa a coordenadas vindas do (vgadriver)
    wire [9:0] next_x, next_y;    
	 
    // Contadores auxiliares so para prefetch no BACK PORCH
    reg hs_d, vs_d;
    reg [9:0] hc, vc;

    localparam H_BACK_CYC = 10'd48;
    localparam H_ACT_CYC  = 10'd640;
    localparam H_TOTAL    = 10'd800;
    localparam V_BACK_CYC = 10'd33;
    localparam V_ACT_CYC  = 10'd480;
    localparam V_TOTAL    = 10'd525;

    always @(posedge clk_pix or posedge reset) begin
        if (reset) begin
            hs_d <= 1'b1;
            vs_d <= 1'b1;
            hc   <= 10'd0;
            vc   <= 10'd0;
        end else begin
            hs_d <= VGA_HS;
            vs_d <= vga_vs_int;

            // X reinicia no fim do pulso HSYNC (inicio do back porch)
            if (VGA_HS && !hs_d)
                hc <= 10'd0;
            else
                hc <= (hc == H_TOTAL - 10'd1) ? 10'd0 : hc + 10'd1;

            // Y reinicia no fim do pulso VSYNC; +1 a cada fim de linha
            if (vga_vs_int && !vs_d)
                vc <= 10'd0;
            else if (VGA_HS && !hs_d)
                vc <= (vc == V_TOTAL - 10'd1) ? 10'd0 : vc + 10'd1;
        end
    end

    // next_x=0 no primeiro pixel e ambiguo com blank; usamos tambem o
    // contador hc sabe se ainda estamos no back porch ou ja na ativa.
    wire in_h_active = (hc >= H_BACK_CYC) && (hc < H_BACK_CYC + H_ACT_CYC);
    wire in_v_active = (vc >= V_BACK_CYC) && (vc < V_BACK_CYC + V_ACT_CYC);
    wire video_on    = in_h_active & in_v_active;

    // Coordenada do pixel que o VGA esta pintando agora, priorizando o next_x, se for 0 usa hc
    wire [9:0] draw_x = in_h_active? ((next_x != 10'd0) ? next_x : (hc - H_BACK_CYC)): 10'd0;
    wire [9:0] draw_y = in_v_active ? ((next_y != 10'd0) ? next_y : (vc - V_BACK_CYC)): 10'd0;

    wire [10:0] raw_x_bg  = {1'b0, hc} + 11'd2; // + latencia BG
    wire [10:0] raw_y_bg  = {1'b0, vc} + 11'd2;
    wire [10:0] raw_x_spr = {1'b0, hc} + 11'd1; // + latencia SPR
    wire [10:0] raw_y_spr = {1'b0, vc} + 11'd1;

    wire [10:0] adj_x_bg  = (raw_x_bg  >= {1'b0, H_BACK_CYC}) ? (raw_x_bg  - {1'b0, H_BACK_CYC}) : 11'd0;
    wire [10:0] adj_y_bg  = (raw_y_bg  >= {1'b0, V_BACK_CYC}) ? (raw_y_bg  - {1'b0, V_BACK_CYC}) : 11'd0;
    wire [10:0] adj_x_spr = (raw_x_spr >= {1'b0, H_BACK_CYC}) ? (raw_x_spr - {1'b0, H_BACK_CYC}) : 11'd0;
    wire [10:0] adj_y_spr = (raw_y_spr >= {1'b0, V_BACK_CYC}) ? (raw_y_spr - {1'b0, V_BACK_CYC}) : 11'd0;

    // valido so se a coordenada pedida ainda esta na area ativa
    wire req_valid_bg  = (adj_x_bg  < {1'b0, H_ACT_CYC}) && (adj_y_bg  < {1'b0, V_ACT_CYC});
    wire req_valid_spr = (adj_x_spr < {1'b0, H_ACT_CYC}) && (adj_y_spr < {1'b0, V_ACT_CYC});

    // Dentro do range: usa a coordenada; fora: 0 (o valid=0 descarta o dado)
    wire [9:0] px_bg  = req_valid_bg  ? adj_x_bg[9:0]  : 10'd0;
    wire [9:0] py_bg  = req_valid_bg  ? adj_y_bg[9:0]  : 10'd0;
    wire [9:0] px_spr = req_valid_spr ? adj_x_spr[9:0] : 10'd0;
    wire [9:0] py_spr = req_valid_spr ? adj_y_spr[9:0] : 10'd0;

    // Logico 320x240: divide por 2 (pixel logico = 2x2 fisicos)
    wire [8:0] logico_x_bg  = px_bg[9:1];
    wire [8:0] logico_y_bg  = py_bg[9:1];
    wire [8:0] logico_x_spr = px_spr[9:1];
    wire [8:0] logico_y_spr = py_spr[9:1];
    wire [8:0] logico_x_poly = draw_x[9:1];
    wire [8:0] logico_y_poly = draw_y[9:1];

    wire [7:0] cor_bg;
    wire       bg_valido;

    motor_background u_motor_bg (
        .clk_pix(clk_pix),
        .reset(reset),
        .logico_x(logico_x_bg),
        .logico_y(logico_y_bg),
        .req_valid(req_valid_bg),   // invalida pipeline fora da area
        .scroll_x(bg_scroll_x_quadro),
        .scroll_y(bg_scroll_y_quadro),
        .tilemap_addr(tilemap_addr),
        .tilemap_data(tilemap_data),
        .padrao_addr(padrao_addr),
        .padrao_data(padrao_data),
        .cor_indice(cor_bg),
        .cor_valida(bg_valido)
    );

    wire [7:0] cor_sprite;
    wire       sprite_ativo;

    motor_sprites u_motor_sprites (
        .clk_pix(clk_pix),
        .reset(reset),
        .logico_x(logico_x_spr),
        .logico_y(logico_y_spr),
        .req_valid(req_valid_spr),  // invalida pipeline fora da area
        .attr_x(sprite_x),
        .attr_y(sprite_y),
        .attr_padrao(sprite_padrao),
        .attr_en(sprite_en),
        .attr_pri(sprite_pri),
        .attr_fliph(sprite_fliph),
        .attr_flipv(sprite_flipv),
        .padrao_addr_sprite(padrao_addr_sprite),
        .padrao_data_sprite(padrao_data_sprite),
        .cor_indice(cor_sprite),
        .pixel_ativo(sprite_ativo)
    );

    // Poligonos coordenada de desenho atual
    wire [7:0] cor_poly;
    wire       poly_ativo;

    rasterizador_multi u_rasterizador (
        .clk_pix(clk_pix),
        .reset(reset),
        .logico_x($signed({1'b0, logico_x_poly})),
        .logico_y($signed({1'b0, logico_y_poly})),
        .poly_vx(poly_vx),
        .poly_vy(poly_vy),
        .poly_cor(poly_cor),
        .poly_habilitado(poly_habilitado),
        .poly_modo_retangulo(poly_modo_retangulo),
        .pixel_ativo(poly_ativo),
        .cor_indice(cor_poly)
    );

    wire [7:0] color_rrggbb;

    compositor u_compositor (
        .enable_bg(enable_bg),
        .enable_sprite(enable_sprite),
        .enable_poly(enable_poly),
        .cor_bg(cor_bg),
        .bg_valido(bg_valido),
        .cor_poly(cor_poly),
        .poly_ativo(poly_ativo & video_on),
        .cor_sprite(cor_sprite),
        .sprite_ativo(sprite_ativo),
        .cor_final(color_rrggbb)
    );

    // RRRGGGBB direto,preto fora da area ativa
    wire [7:0] color_final = video_on ? color_rrggbb : 8'd0;

    vga_driver u_vga (
        .clock(clk_pix),
        .reset(reset),
        .color_in(color_final),
        .next_x(next_x),
        .next_y(next_y),
        .hsync(VGA_HS),
        .vsync(vga_vs_int),
        .red(VGA_R),
        .green(VGA_G),
        .blue(VGA_B),
        .sync(VGA_SYNC_N),
        .clk(VGA_CLK),
        .blank(VGA_BLANK_N)
    );
    assign VGA_VS = vga_vs_int;

    // Depuracao visual
    // LEDR[2:0] acesos quando estímulo inválido (cenários 101/110/111)
    // LEDR[1] = buffer ativo, LEDR[0] também indica erro de endereço
    assign LEDR[2:0] = estimulo_invalido ? 3'b111 : {1'b0, buffer_ativo, (estimulo_invalido | endereco_invalido)};
    assign LEDR[9:3] = 7'd0;
	 
	 //Atribuiçao dos displays de 7 segmentos
	 assign HEX0 = hex0_w;
    assign HEX1 = hex1_w;
    assign HEX2 = hex2_w;
    assign HEX3 = hex3_w;
    assign HEX4 = hex4_w;
    assign HEX5 = hex5_w;

endmodule