# =============================================================================
# run_all_modelsim.do
# Script ModelSim/Questa para compilar e rodar todos os testbenches
#
# Uso (a partir da pasta do projeto Quartus, com testbenches/ ao lado dos .v):
#   vsim -do testbenches/run_all_modelsim.do
#
# Ajuste SRC_DIR se a estrutura de pastas for diferente.
# =============================================================================

set SRC_DIR  "."
set TB_DIR   "testbenches"
set WORK     work

if {[file exists $WORK]} {
    file delete -force $WORK
}
vlib $WORK
vmap work $WORK

puts "=== Compilando RTL ==="
vlog -work work $SRC_DIR/debounce_edge.v
vlog -work work $SRC_DIR/banco_registradores.v
vlog -work work $SRC_DIR/compositor.v
vlog -work work $SRC_DIR/Motores/motor_background.v
vlog -work work $SRC_DIR/Motores/motor_sprites.v
vlog -work work $SRC_DIR/Motores/rasterizador_multi.v
vlog -work work $SRC_DIR/Modulo_VGA/vga_driver.v
vlog -work work $SRC_DIR/Modulo_VGA/mov_continuo.v
vlog -work work $SRC_DIR/porta_estimulo.v

puts "=== Compilando testbenches ==="
vlog -work work $TB_DIR/tb_debounce_edge.v
vlog -work work $TB_DIR/tb_banco_registradores.v
vlog -work work $TB_DIR/tb_compositor.v
vlog -work work $TB_DIR/tb_rasterizador_multi.v
vlog -work work $TB_DIR/tb_motor_background.v
vlog -work work $TB_DIR/tb_motor_sprites.v
vlog -work work $TB_DIR/tb_vga_driver.v
vlog -work work $TB_DIR/tb_porta_estimulo.v
vlog -work work $TB_DIR/tb_coprocessador_top.v

proc run_tb {name} {
    puts "\n######## Rodando $name ########"
    vsim -c work.$name
    run -all
    quit -sim
}

run_tb tb_compositor
run_tb tb_rasterizador_multi
run_tb tb_banco_registradores
run_tb tb_motor_background
run_tb tb_motor_sprites
run_tb tb_porta_estimulo
run_tb tb_debounce_edge
run_tb tb_vga_driver
run_tb tb_coprocessador_top

puts "\n=== Todos os testbenches finalizados ==="
quit -f
