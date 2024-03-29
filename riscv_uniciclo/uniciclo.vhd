-- *  @autores: Letícia de Souza Soares
-- * 				 Fernanda Macedo de Sousa
--    @Matriculas: 15/0015178 - 17/0010058
-- * @disciplina: Organização e Arquitetura de Computadores
-- 
-- * Trabalho Projeto Risc-V Uniciclo

-- os valores ao lado sao tomados da saida dos modulos:
-- PC - saida do PC
-- MI - saida do modulo de memoria (e nao de IF/ID)
-- ULA - saida direta da ULA
-- MD - saida direta da memoria de dados

-- * Trabalho Final -  uniciclo  */
library	ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use work.types_components.all;

entity uniciclo is
	port(
		reset : in std_logic := '1'; -- reseta pc e banco
		clk : in std_logic := '1'; -- pc e banco
		clk_mem : in std_logic := '1'; -- clock das memorias
		instrucao	 :out	std_logic_vector(31	downto	0); -- saida da memoria de intrucoes
		pc_out: out	std_logic_vector(31	downto	0); -- saida de pc
		outULA, memDados :out	std_logic_vector(31	downto	0); -- saida da ula e saida da memoria de Dados
		prox_ins: out	std_logic_vector(31	downto	0) -- saida somador pc+4
	);

end entity;

architecture rtl of uniciclo is
	-- Sinais de todas as conexões entre os módulos
	
	SIGNAL res_somapc4, res_somaImmpc, result_mux_branch, readMemoryData : std_logic_vector(31 downto 0);
	SIGNAL address_out_pc, mem_ins_out: std_logic_vector(31 downto 0);
	SIGNAL readData1, wdata, readData2 : std_logic_vector(31 downto 0);
	SIGNAL imm32 : signed(31 DOWNTO 0);
	-- branch_and_zero_ula 
	SIGNAL branch_and_zero_ula : std_logic;
	-- saida controle ula
	SIGNAL out_c_ula : std_logic_vector(3	downto	0);
   -- ula
	SIGNAL zero : std_logic;
   SIGNAL res_mux_inB_ula ,out_ula : std_logic_vector(31 downto 0);	
	-- control signals
	SIGNAL ALUSrc, RegWrite, Branch, MemtoReg, MemWrite : std_logic;
	SIGNAL ALUOp : std_logic_vector(2 downto 0);
	--jal e jalr
	SIGNAL jal_or_jalr, jal, jalr, jump_or_branch : std_logic;
	SIGNAL res_mux_wdata_Xreg, result_mux_jalr, ula_or_neg1 : std_logic_vector(31 downto 0);
	--
	SIGNAL lui : std_logic;
	SIGNAL result_muxLui: std_logic_vector(31 downto 0);
begin
	imm : genImm32 PORT MAP ( instr => mem_ins_out , imm32 => imm32 ); -- instancia um gerador de imediatos, a entrada está conectada com a saida da memoria de instrucao
	
   contr_ula: c_ula PORT MAP ( bit5funct7 => mem_ins_out(30), -- controlador da ULA
					funct3 => mem_ins_out(14 downto 12), -- o bit 5 do funct 7 (unico que difere nesse campo) é o bit 30 da instrucao que sai da memória 
					ulaOp  => ALUOp,
					ctr_ula => out_c_ula);
	
	alu : ula PORT MAP ( opCula => out_c_ula, A => result_muxLui, 
	B => res_mux_inB_ula, ulaout => out_ula, zero => zero );
	
	mux_inB_ula : multiplexador_32_bits port map( -- multiplexador que define qual a entrada b da ULA (se imediato ou registrador)
		opt0 => readData2,
		opt1 => std_logic_vector(imm32),
		selector => AluSrc,
		result => res_mux_inB_ula);
	
	X_regis: xreg port MAP (clk => clk, -- Banco de Registradores
				--escrita
				wren => RegWrite, -- habilita escrita
				rd => mem_ins_out(11 downto 7), --endereço do reg para escrita
				data => res_mux_wdata_Xreg, --valor para escrever no rd
				--leitura
				rs1 => mem_ins_out(19 downto 15), --  endereço do reg a ser lido em ro1
	         rs2 => mem_ins_out(24 downto 20), -- endereço do reg a ser lido em ro2
				ro1 => readData1, -- saída ler reg endereçado por rs1
				ro2 => readData2,-- saída ler reg endereçado por rs2
				--reset
				rst => reset); -- sinal de reset, zera todos regs
	
	PC_P : pc port map( -- instancia do PC
		clk => clk,
		reset => reset,
		address_in => result_mux_jalr,
		address_out => address_out_pc
	);
	
	sum_pc_4: somador port map ( -- instancia do somador para o PC
		A => address_out_pc,
		B => X"00000004",
		result => res_somapc4
	);
	
	mi : memory_instruction port map( -- instancia da memoria de instrucoes
    	address		 => address_out_pc(9 downto 2), -- 7 bits 
		q           => mem_ins_out, 
		clock       => clk_mem
	);
	
	ctrl : control port map ( -- nao tem mem MemRead porque a memoria vai sempre ler com clk_mem 
		opcode => mem_ins_out(6 downto 0),
		Branch => Branch,
		MemtoReg => MemtoReg,
		MemWrite => MemWrite,
		ALUOp => ALUOp,
		RegWrite => RegWrite,
		ALUSrc => ALUSrc,
		jump => jal,
		jalr => jalr,
		lui => lui
	);
	
	mux_md_Xreg : multiplexador_32_bits port map(
		opt0 => out_ula,
		opt1 => readMemoryData,
		selector => MemtoReg,
		result => wdata 
	);

	sum_imm_pc: somador port map ( -- instancia do somador para a soma do imediato com o PC
		A => address_out_pc,
		B => std_logic_vector(imm32), --não tem shift 1 
		result => res_somaImmpc
	);
	
	md : data_memory port map(
		address    => out_ula(9 downto 2),
	   q          => readMemoryData,                      
	   clock      => clk_mem,  -- nao tem mem MemRead porque a memoria vai sempre ler com clk_mem, dito clock rapido 
	   data       => readData2,
	   wren       => MemWrite
	);

	mux_jump_or_branch : multiplexador_32_bits port map(
		opt0 => res_somapc4,
		opt1 => res_somaImmpc,
		selector => jump_or_branch,
		result => result_mux_branch
	);
	 -- mux quando jal ou jalr, entao, escrive no banco de registradores p+4 
	mux_jal_jalr_Xreg : multiplexador_32_bits port map(
		opt0 => wdata,
		opt1 => res_somapc4,
		selector => jal_or_jalr,
		result => res_mux_wdata_Xreg
	);
	
	mux_jalr_pc : multiplexador_32_bits port map(
		opt0 => result_mux_branch,
		opt1 => ula_or_neg1,
		selector => jalr,
		result => result_mux_jalr
	);
	muxlui_inA_ula: multiplexador_32_bits port map(
		opt0 => readData1,
		opt1 => x"00000000",
		selector => lui,
		result => result_muxLui
	);
	
	--se jalr, entao, pc = saida da ula e neg 1
	ula_or_neg1 <= out_ula and not(x"00000001");
	
	--seletor do mux da entrada do wdata de Xreg
	jal_or_jalr <= jalr or jal;
	
	--para seletor do mux branch ou jump
	branch_and_zero_ula <= Branch and zero;
	jump_or_branch <= branch_and_zero_ula or jal;
	
   --testbench	
	instrucao <= mem_ins_out;
	pc_out <= address_out_pc;
	prox_ins <= result_mux_jalr;
	memDados <= readMemoryData;
	outULA <= out_ula;

end architecture;


