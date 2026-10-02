-- LocalScript dentro de StarterGui
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

------------------------------------------------------------
-- DONO DO PAINEL — só esse usuário consegue ver/usar o painel
------------------------------------------------------------
local NOME_DONO = "P7zINM"

------------------------------------------------------------
-- ÍCONE DO BOTÃO FLUTUANTE (o círculo que abre o painel)
-- IMAGEM_BOTAO aceita 3 formatos:
--   1) URL (https://...)      = baixa e registra automaticamente (funciona em executors)
--   2) "rbxassetid://1234..." = ID de um decal enviado no Roblox (funciona em qualquer lugar)
--   3) ""                     = usa o emoji de ICONE_FALLBACK
------------------------------------------------------------
local IMAGEM_BOTAO = "https://i.pinimg.com/736x/0f/1a/f0/0f1af0cc532c9ace8bd7172899a1ae3c.jpg"
local ICONE_FALLBACK = "📍"

------------------------------------------------------------
-- FUNDO DO PAINEL (imagem atrás de tudo)
-- IMAGEM_FUNDO aceita os mesmos 3 formatos do botão:
--   1) URL (https://...)      2) "rbxassetid://1234..."   3) "" = cor sólida
------------------------------------------------------------
local IMAGEM_FUNDO = ""
local ESCURECER_FUNDO = 0.55 -- 0 = imagem pura, 1 = some; quanto maior, mais fácil de ler o texto

if player.Name:lower() ~= NOME_DONO:lower() then
	warn("[PainelTP] Painel bloqueado: dono configurado é '" .. NOME_DONO .. "', mas seu username é '" .. player.Name .. "'. Ajuste NOME_DONO no script.")
	return -- qualquer outro jogador: o script para aqui, painel nem é criado
end

local function getCharacter(p)
	return p.Character or p.CharacterAdded:Wait()
end

------------------------------------------------------------
-- ESTADOS
------------------------------------------------------------
local espectando = false
local alvoEspectado = nil

local espAtivo = false
local espObjetos = {} -- [Player] = {highlight = ..., billboard = ...}

local noclipAtivo = false
local noclipConexao = nil
local valoresOriginaisCollide = {} -- [BasePart] = CanCollide original

local favoritos = {} -- [UserId] = true

local seguindoAlvo = nil -- Player sendo seguido (só um por vez)
local DISTANCIA_MAXIMA_SEGUIR = 3 -- studs: se afastar mais que isso, puxa de volta

local posicaoSalva = nil -- CFrame do local salvo pelo botão "Salvar Local"

-- Speed / Jump / Fly
local SPEED_NORMAL, JUMP_NORMAL, FLYSPEED_NORMAL = 16, 50, 50 -- valores padrão (botão "Normal")
local valorSpeed = SPEED_NORMAL
local valorJump = JUMP_NORMAL
local valorFlySpeed = FLYSPEED_NORMAL

local SPEED_MIN, SPEED_MAX, SPEED_PASSO = 8, 200, 4
local JUMP_MIN, JUMP_MAX, JUMP_PASSO = 20, 300, 10
local FLYSPEED_MIN, FLYSPEED_MAX, FLYSPEED_PASSO = 10, 300, 10

local flyAtivo = false
local flyBodyVelocity = nil
local flyBodyGyro = nil

------------------------------------------------------------
-- DIMENSÕES DO PAINEL (usadas para alinhar tudo certinho)
------------------------------------------------------------
local LARGURA_PAINEL = 320
local MARGEM = 8
local LARGURA_UTIL = LARGURA_PAINEL - (MARGEM * 2) -- área interna útil

------------------------------------------------------------
-- HELPERS DE ESTILO (deixa a criação de botão padronizada)
------------------------------------------------------------
local function criarUICorner(instancia, raio)
	local uic = Instance.new("UICorner")
	uic.CornerRadius = UDim.new(0, raio or 6)
	uic.Parent = instancia
	return uic
end

local function novoBotao(pai, texto, tamanho, posicao, corFundo, tamanhoFonte)
	local botao = Instance.new("TextButton")
	botao.Size = tamanho
	botao.Position = posicao
	botao.BackgroundColor3 = corFundo
	botao.Text = texto
	botao.TextColor3 = Color3.fromRGB(255, 255, 255)
	botao.Font = Enum.Font.GothamBold
	botao.TextSize = tamanhoFonte or 13
	botao.AutoButtonColor = true
	botao.Parent = pai
	criarUICorner(botao, 6)
	return botao
end

------------------------------------------------------------
-- ESTRUTURA BASE DO PAINEL
------------------------------------------------------------

-- Botão flutuante de abrir/fechar (sempre visível)
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PainelTP"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- Resolve a imagem do botão:
--  - rbxassetid:// ou "": usa direto
--  - URL (https://): baixa com validação e registra como asset (executor)
--  - arquivo já baixado antes: usa sem precisar de internet
--  - qualquer falha: volta pro emoji com aviso no console (F9)
local function ehImagemValida(conteudo)
	return type(conteudo) == "string" and #conteudo > 100 and (
		conteudo:sub(1, 3) == "\255\216\255" or -- JPEG (FF D8 FF)
		conteudo:sub(1, 4) == "\137PNG"         -- PNG  (89 50 4E 47)
	)
end

local function baixarImagem(url)
	local headers = { ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36" }

	-- funções de download existem em cada executor (tenta todas, na ordem)
	local candidatas = {}
	if type(request) == "function" then table.insert(candidatas, request) end
	if type(http_request) == "function" then table.insert(candidatas, http_request) end
	if type(syn) == "table" and type(syn.request) == "function" then table.insert(candidatas, syn.request) end

	for _, fn in ipairs(candidatas) do
		local ok, r = pcall(fn, { Url = url, Method = "GET", Headers = headers })
		if ok and type(r) == "table" and ehImagemValida(r.Body) then
			return r.Body
		end
	end

	-- último recurso: HttpGet do próprio executor
	local ok, corpo = pcall(function()
		return game:HttpGet(url, true)
	end)
	if ok and ehImagemValida(corpo) then
		return corpo
	end

	return nil
end

local function resolverImagem(url, nomeArquivo)
	if url == "" or url:sub(1, 4) ~= "http" then
		return url -- vazio ou rbxassetid://: usa direto
	end

	if type(writefile) ~= "function" or (type(getcustomasset) ~= "function" and type(getsynasset) ~= "function") then
		warn("[PainelTP] Imagem precisa de um executor (falta writefile/getcustomasset). Usando o emoji do botão.")
		return ""
	end

	local arquivo = nomeArquivo or ("PainelTP_imagem." .. (url:sub(-4):lower() == ".png" and "png" or "jpg"))

	local ok, asset = pcall(function()
		-- usa o arquivo já existente se for uma imagem válida (não precisa de internet)
		local conteudo = nil
		if type(isfile) == "function" and isfile(arquivo) and type(readfile) == "function" then
			local okLeitura, existente = pcall(readfile, arquivo)
			if okLeitura and ehImagemValida(existente) then
				conteudo = existente
			end
		end

		if not conteudo then
			conteudo = baixarImagem(url)
			if not conteudo then
				error("o download foi bloqueado ou a resposta não era uma imagem")
			end
			writefile(arquivo, conteudo)
			print("[PainelTP] Imagem baixada e salva como '" .. arquivo .. "'.")
		end

		if type(getcustomasset) == "function" then
			return getcustomasset(arquivo)
		end
		return getsynasset(arquivo)
	end)

	if ok and type(asset) == "string" and asset ~= "" then
		print("[PainelTP] Imagem do botão carregada: " .. asset)
		return asset
	end

	warn("[PainelTP] Falha ao carregar a imagem do botão: " .. tostring(asset))
	warn("[PainelTP] Jeitos de resolver: 1) use 'rbxassetid://SEU_ID' (envie a imagem como decal); 2) copie o arquivo '" .. arquivo .. "' pra pasta do executor; 3) deixe IMAGEM_BOTAO = \"\" pra usar o emoji.")
	return ""
end

local imagemToggle = resolverImagem(IMAGEM_BOTAO, "PainelTP_icone_toggle.jpg")

local botaoToggle = Instance.new("ImageButton")
botaoToggle.Size = UDim2.new(0, 50, 0, 50)
botaoToggle.Position = UDim2.new(0, 20, 0.5, -180)
botaoToggle.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
botaoToggle.Image = imagemToggle -- vazio = mostra o emoji abaixo
botaoToggle.ScaleType = Enum.ScaleType.Fit
botaoToggle.AutoButtonColor = true
botaoToggle.Parent = screenGui
criarUICorner(botaoToggle, 25)

-- Sem imagem personalizada: exibe o ícone de fallback por cima do fundo
if imagemToggle == "" then
	local iconeToggle = Instance.new("TextLabel")
	iconeToggle.Size = UDim2.new(1, -8, 1, -8)
	iconeToggle.Position = UDim2.new(0, 4, 0, 4)
	iconeToggle.BackgroundTransparency = 1
	iconeToggle.Text = ICONE_FALLBACK
	iconeToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
	iconeToggle.Font = Enum.Font.GothamBold
	iconeToggle.TextSize = 22
	iconeToggle.Parent = botaoToggle
end
-- Frame principal (painel)
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, LARGURA_PAINEL, 0, 526)
frame.Position = UDim2.new(0, 20, 0.5, -233)
frame.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
frame.BorderSizePixel = 0
frame.Visible = false -- começa fechado
frame.Parent = screenGui
criarUICorner(frame, 10)

------------------------------------------------------------
-- FUNDO DO PAINEL (imagem + camada escura pra manter a leitura)
------------------------------------------------------------
local imagemFundo = resolverImagem(IMAGEM_FUNDO, "PainelTP_fundo_painel.jpg")

-- Imagem de fundo (primeiro filho do frame = fica atrás de tudo)
local fundoPainel = Instance.new("ImageLabel")
fundoPainel.Name = "Fundo"
fundoPainel.Size = UDim2.new(1, 0, 1, 0)
fundoPainel.Position = UDim2.new(0, 0, 0, 0)
fundoPainel.BackgroundTransparency = 1
fundoPainel.BorderSizePixel = 0
fundoPainel.Image = imagemFundo -- vazio = mostra a cor sólida do frame
fundoPainel.ScaleType = Enum.ScaleType.Crop -- preenche tudo, cortando o excesso
fundoPainel.Parent = frame
criarUICorner(fundoPainel, 10)

-- Camada escura por cima da imagem (só aparece se houver imagem)
local sombraFundo = Instance.new("Frame")
sombraFundo.Name = "SombraFundo"
sombraFundo.Size = UDim2.new(1, 0, 1, 0)
sombraFundo.Position = UDim2.new(0, 0, 0, 0)
sombraFundo.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
sombraFundo.BackgroundTransparency = 1 - ESCURECER_FUNDO
sombraFundo.BorderSizePixel = 0
sombraFundo.Visible = imagemFundo ~= ""
sombraFundo.Parent = frame -- segundo filho = atrás do conteúdo, na frente da imagem
criarUICorner(sombraFundo, 10)

------------------------------------------------------------
-- CABEÇALHO — linha 1: título + fechar
------------------------------------------------------------

-- Área invisível que cobre a barra do título, usada só pra detectar o arraste
local barraArraste = Instance.new("Frame")
barraArraste.Size = UDim2.new(1, 0, 0, 34)
barraArraste.Position = UDim2.new(0, 0, 0, 0)
barraArraste.BackgroundTransparency = 1
barraArraste.Active = true -- necessário pra receber eventos de input
barraArraste.Parent = frame

local titulo = Instance.new("TextLabel")
titulo.Size = UDim2.new(1, -46, 0, 32)
titulo.Position = UDim2.new(0, MARGEM, 0, 0)
titulo.BackgroundTransparency = 1
titulo.Text = "Painel do " .. NOME_DONO
titulo.TextXAlignment = Enum.TextXAlignment.Left
titulo.TextColor3 = Color3.fromRGB(255, 255, 255)
titulo.Font = Enum.Font.GothamBold
titulo.TextSize = 16
titulo.Parent = frame

local botaoFechar = Instance.new("TextButton")
botaoFechar.Size = UDim2.new(0, 26, 0, 26)
botaoFechar.Position = UDim2.new(1, -32, 0, 3)
botaoFechar.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
botaoFechar.Text = "X"
botaoFechar.TextColor3 = Color3.fromRGB(255, 120, 120)
botaoFechar.Font = Enum.Font.GothamBold
botaoFechar.TextSize = 14
botaoFechar.Parent = frame
criarUICorner(botaoFechar, 13)

-- Linha divisória sutil abaixo do título
local divisor = Instance.new("Frame")
divisor.Size = UDim2.new(1, -MARGEM * 2, 0, 1)
divisor.Position = UDim2.new(0, MARGEM, 0, 34)
divisor.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
divisor.BorderSizePixel = 0
divisor.Parent = frame

------------------------------------------------------------
-- CABEÇALHO — linha 2: barra de ferramentas (Noclip / ESP)
------------------------------------------------------------
local Y_TOOLBAR = 42
local LARGURA_FERRAMENTA = (LARGURA_UTIL - 8) / 2

local botaoNoclip = novoBotao(
	frame,
	"Noclip: OFF",
	UDim2.new(0, LARGURA_FERRAMENTA, 0, 28),
	UDim2.new(0, MARGEM, 0, Y_TOOLBAR),
	Color3.fromRGB(55, 55, 60),
	12
)

local botaoESP = novoBotao(
	frame,
	"ESP: OFF",
	UDim2.new(0, LARGURA_FERRAMENTA, 0, 28),
	UDim2.new(0, MARGEM + LARGURA_FERRAMENTA + 8, 0, Y_TOOLBAR),
	Color3.fromRGB(55, 55, 60),
	12
)

------------------------------------------------------------
-- CABEÇALHO — linha 3: Salvar Local / Retornar ao Local
------------------------------------------------------------
local Y_TOOLBAR_LOCAL = Y_TOOLBAR + 28 + 8 -- 8px abaixo da linha Noclip/ESP

local botaoSalvarLocal = novoBotao(
	frame,
	"Salvar Local",
	UDim2.new(0, LARGURA_FERRAMENTA, 0, 28),
	UDim2.new(0, MARGEM, 0, Y_TOOLBAR_LOCAL),
	Color3.fromRGB(55, 55, 60),
	12
)

local botaoRetornarLocal = novoBotao(
	frame,
	"Retornar",
	UDim2.new(0, LARGURA_FERRAMENTA, 0, 28),
	UDim2.new(0, MARGEM + LARGURA_FERRAMENTA + 8, 0, Y_TOOLBAR_LOCAL),
	Color3.fromRGB(40, 40, 44), -- começa apagado: ainda não há local salvo
	12
)

------------------------------------------------------------
-- CABEÇALHO — linha 4: Speed / Jump / Fly (com ajuste de valor)
------------------------------------------------------------
local Y_MOVIMENTO_TITULO = Y_TOOLBAR_LOCAL + 28 + 10

local labelMovimento = Instance.new("TextLabel")
labelMovimento.Size = UDim2.new(1, 0, 0, 14)
labelMovimento.Position = UDim2.new(0, MARGEM, 0, Y_MOVIMENTO_TITULO)
labelMovimento.BackgroundTransparency = 1
labelMovimento.Text = "MOVIMENTO"
labelMovimento.TextXAlignment = Enum.TextXAlignment.Left
labelMovimento.TextColor3 = Color3.fromRGB(140, 140, 145)
labelMovimento.Font = Enum.Font.GothamBold
labelMovimento.TextSize = 11
labelMovimento.Parent = frame

local ALTURA_LINHA_MOV = 26
local GAP_LINHA_MOV = 4
local Y_LINHAS_MOV = Y_MOVIMENTO_TITULO + 18

-- Cria uma linha padrão: label + Max + Normal + botão "-" + valor + botão "+"
-- (a linha do Fly ainda recebe o toggle ON/OFF entre o Normal e o "-")
local function criarLinhaAjuste(y, textoLabel, valorInicial, sufixo)
	local linha = Instance.new("Frame")
	linha.Size = UDim2.new(1, -MARGEM * 2, 0, ALTURA_LINHA_MOV)
	linha.Position = UDim2.new(0, MARGEM, 0, y)
	linha.BackgroundColor3 = Color3.fromRGB(38, 38, 44)
	linha.Parent = frame
	criarUICorner(linha, 6)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0, 70, 1, 0)
	label.Position = UDim2.new(0, 8, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = textoLabel
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.Gotham
	label.TextSize = 12
	label.TextTruncate = Enum.TextTruncate.AtEnd -- segurança: nunca invade o botão Max
	label.Parent = linha

	local botaoMenos = novoBotao(linha, "-", UDim2.new(0, 24, 0, 20), UDim2.new(1, -104, 0.5, -10), Color3.fromRGB(70, 70, 76), 14)
	local valorLabel = Instance.new("TextLabel")
	valorLabel.Size = UDim2.new(0, 44, 1, 0)
	valorLabel.Position = UDim2.new(1, -76, 0, 0)
	valorLabel.BackgroundTransparency = 1
	valorLabel.Text = tostring(valorInicial) .. (sufixo or "")
	valorLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	valorLabel.Font = Enum.Font.GothamBold
	valorLabel.TextSize = 13
	valorLabel.Parent = linha
	local botaoMais = novoBotao(linha, "+", UDim2.new(0, 24, 0, 20), UDim2.new(1, -28, 0.5, -10), Color3.fromRGB(70, 70, 76), 14)

	-- Botão "Max": leva o valor direto pro máximo dessa linha
	local botaoMax = novoBotao(linha, "Max", UDim2.new(0, 32, 0, 20), UDim2.new(0, 82, 0.5, -10), Color3.fromRGB(46, 86, 130), 11)

	-- Botão "Normal": volta pro valor padrão dessa linha
	local botaoNormal = novoBotao(linha, "Normal", UDim2.new(0, 42, 0, 20), UDim2.new(0, 118, 0.5, -10), Color3.fromRGB(70, 70, 76), 10)

	return linha, botaoMenos, valorLabel, botaoMais, botaoMax, botaoNormal
end

-- Linha Speed
local _, botaoSpeedMenos, labelSpeedValor, botaoSpeedMais, botaoSpeedMax, botaoSpeedNormal = criarLinhaAjuste(Y_LINHAS_MOV, "Velocidade", valorSpeed, "")

-- Linha Jump
local Y_LINHA_JUMP = Y_LINHAS_MOV + ALTURA_LINHA_MOV + GAP_LINHA_MOV
local _, botaoJumpMenos, labelJumpValor, botaoJumpMais, botaoJumpMax, botaoJumpNormal = criarLinhaAjuste(Y_LINHA_JUMP, "Salto", valorJump, "")

-- Linha Fly (label + botão liga/desliga + controles de velocidade)
local Y_LINHA_FLY = Y_LINHA_JUMP + ALTURA_LINHA_MOV + GAP_LINHA_MOV
local linhaFly, botaoFlySpeedMenos, labelFlySpeedValor, botaoFlySpeedMais, botaoFlyMax, botaoFlyNormal = criarLinhaAjuste(Y_LINHA_FLY, "Voar", valorFlySpeed, "")

local botaoFlyToggle = Instance.new("TextButton")
botaoFlyToggle.Size = UDim2.new(0, 28, 0, 20)
botaoFlyToggle.Position = UDim2.new(0, 164, 0.5, -10)
botaoFlyToggle.BackgroundColor3 = Color3.fromRGB(70, 70, 76)
botaoFlyToggle.Text = "OFF"
botaoFlyToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
botaoFlyToggle.Font = Enum.Font.GothamBold
botaoFlyToggle.TextSize = 10
botaoFlyToggle.Parent = linhaFly
criarUICorner(botaoFlyToggle, 5)

------------------------------------------------------------
-- CAIXA DE BUSCA (filtra a lista por nome digitado)
------------------------------------------------------------
local Y_BUSCA = Y_LINHA_FLY + ALTURA_LINHA_MOV + 10 -- logo abaixo da seção Movimento

local caixaBusca = Instance.new("TextBox")
caixaBusca.Size = UDim2.new(1, -MARGEM * 2, 0, 28)
caixaBusca.Position = UDim2.new(0, MARGEM, 0, Y_BUSCA)
caixaBusca.BackgroundColor3 = Color3.fromRGB(38, 38, 44)
caixaBusca.PlaceholderText = "Pesquisar jogador..."
caixaBusca.PlaceholderColor3 = Color3.fromRGB(130, 130, 135)
caixaBusca.Text = ""
caixaBusca.TextColor3 = Color3.fromRGB(255, 255, 255)
caixaBusca.Font = Enum.Font.Gotham
caixaBusca.TextSize = 13
caixaBusca.ClearTextOnFocus = false
caixaBusca.Parent = frame
criarUICorner(caixaBusca, 6)

caixaBusca.TextXAlignment = Enum.TextXAlignment.Left

-- Pequena margem esquerda pro texto não colar na borda
local paddingBusca = Instance.new("UIPadding")
paddingBusca.PaddingLeft = UDim.new(0, 10)
paddingBusca.Parent = caixaBusca

------------------------------------------------------------
-- BARRA "ESPECTANDO AGORA" (só aparece quando ativo)
------------------------------------------------------------
local Y_BARRA_ESPECTANDO_REAL = Y_BUSCA + 28 + 8

local barraEspectando = Instance.new("Frame")
barraEspectando.Size = UDim2.new(1, -MARGEM * 2, 0, 28)
barraEspectando.Position = UDim2.new(0, MARGEM, 0, Y_BARRA_ESPECTANDO_REAL)
barraEspectando.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
barraEspectando.Visible = false
barraEspectando.Parent = frame
criarUICorner(barraEspectando, 6)

local labelEspectando = Instance.new("TextLabel")
labelEspectando.Size = UDim2.new(1, -86, 1, 0)
labelEspectando.Position = UDim2.new(0, 10, 0, 0)
labelEspectando.BackgroundTransparency = 1
labelEspectando.TextXAlignment = Enum.TextXAlignment.Left
labelEspectando.Text = "Espectando: -"
labelEspectando.TextColor3 = Color3.fromRGB(255, 255, 255)
labelEspectando.Font = Enum.Font.Gotham
labelEspectando.TextSize = 13
labelEspectando.Parent = barraEspectando

local botaoPararSpec = novoBotao(
	barraEspectando,
	"Parar",
	UDim2.new(0, 70, 0, 20),
	UDim2.new(1, -76, 0, 4),
	Color3.fromRGB(180, 60, 60),
	12
)

------------------------------------------------------------
-- LISTA DE JOGADORES (área com scroll)
------------------------------------------------------------
local Y_LISTA_SEM_BARRA = Y_BARRA_ESPECTANDO_REAL
local Y_LISTA_COM_BARRA = Y_BARRA_ESPECTANDO_REAL + 28 + 8

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, -MARGEM * 2, 1, -(Y_LISTA_SEM_BARRA + MARGEM))
scrollFrame.Position = UDim2.new(0, MARGEM, 0, Y_LISTA_SEM_BARRA)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 5
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(90, 90, 95)
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.Parent = frame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scrollFrame

-- Ajusta a posição/altura do scroll quando a barra de espectar aparece/some
local function atualizarLayoutFrame()
	if barraEspectando.Visible then
		scrollFrame.Position = UDim2.new(0, MARGEM, 0, Y_LISTA_COM_BARRA)
		scrollFrame.Size = UDim2.new(1, -MARGEM * 2, 1, -(Y_LISTA_COM_BARRA + MARGEM))
	else
		scrollFrame.Position = UDim2.new(0, MARGEM, 0, Y_LISTA_SEM_BARRA)
		scrollFrame.Size = UDim2.new(1, -MARGEM * 2, 1, -(Y_LISTA_SEM_BARRA + MARGEM))
	end
end

------------------------------------------------------------
-- ARRASTAR A BOLINHA (segura o botão flutuante e move pela tela)
------------------------------------------------------------
local bolinhaArrastando = false
local bolinhaInputArraste = nil
local bolinhaPosicaoInicialMouse = nil
local bolinhaPosicaoInicial = nil
local bolinhaMoveu = false -- true se arrastou de verdade (bloqueia o clique de abrir/fechar)
local LIMITE_MINIMO_ARRASTE = 6 -- px: abaixo disso ainda conta como clique

local function atualizarArrasteBolinha(input)
	local delta = input.Position - bolinhaPosicaoInicialMouse
	if delta.Magnitude >= LIMITE_MINIMO_ARRASTE then
		bolinhaMoveu = true
	end

	-- trava a bolinha dentro da tela pra ela nunca sumir
	local tela = camera.ViewportSize
	local tamanho = botaoToggle.AbsoluteSize
	local novoX = math.clamp(bolinhaPosicaoInicial.X.Offset + delta.X, 0, tela.X - tamanho.X)
	local novoY = math.clamp(bolinhaPosicaoInicial.Y.Offset + delta.Y, 0, tela.Y - tamanho.Y)

	botaoToggle.Position = UDim2.new(0, novoX, 0, novoY)
end

botaoToggle.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		bolinhaArrastando = true
		bolinhaMoveu = false
		bolinhaPosicaoInicialMouse = input.Position
		-- converte pra offset puro (o botão começa com Scale, que quebraria a conta do arraste)
		bolinhaPosicaoInicial = UDim2.new(0, botaoToggle.AbsolutePosition.X, 0, botaoToggle.AbsolutePosition.Y)

		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				bolinhaArrastando = false
			end
		end)
	end
end)

botaoToggle.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		bolinhaInputArraste = input
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input == bolinhaInputArraste and bolinhaArrastando then
		atualizarArrasteBolinha(input)
	end
end)

------------------------------------------------------------
-- ABRIR / FECHAR PAINEL
------------------------------------------------------------
botaoToggle.MouseButton1Click:Connect(function()
	if bolinhaMoveu then -- foi arraste, não clique: só reseta a flag
		bolinhaMoveu = false
		return
	end
	frame.Visible = not frame.Visible
end)
botaoFechar.MouseButton1Click:Connect(function()
	frame.Visible = false
end)

-- Tecla B também abre/fecha o painel
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end
	if input.KeyCode == Enum.KeyCode.B then
		frame.Visible = not frame.Visible
	end
end)

------------------------------------------------------------
-- ARRASTAR O PAINEL (segurando a barra do título)
------------------------------------------------------------
local arrastando = false
local inputArraste = nil
local posicaoInicialMouse = nil
local posicaoInicialFrame = nil

local function atualizarArraste(input)
	local delta = input.Position - posicaoInicialMouse
	frame.Position = UDim2.new(
		posicaoInicialFrame.X.Scale,
		posicaoInicialFrame.X.Offset + delta.X,
		posicaoInicialFrame.Y.Scale,
		posicaoInicialFrame.Y.Offset + delta.Y
	)
end

barraArraste.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		arrastando = true
		posicaoInicialMouse = input.Position
		posicaoInicialFrame = frame.Position

		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				arrastando = false
			end
		end)
	end
end)

barraArraste.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		inputArraste = input
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input == inputArraste and arrastando then
		atualizarArraste(input)
	end
end)

------------------------------------------------------------
-- TELEPORTE
------------------------------------------------------------
local function teleportarAte(alvo)
	local myChar = getCharacter(player)
	local myHRP = myChar:WaitForChild("HumanoidRootPart")

	local alvoChar = alvo.Character
	if not alvoChar then
		return
	end
	local alvoHRP = alvoChar:FindFirstChild("HumanoidRootPart")
	if alvoHRP then
		myHRP.CFrame = alvoHRP.CFrame * CFrame.new(0, 0, 3)
	end
end

------------------------------------------------------------
-- AUTO TP / SEGUIR (fica colado no alvo pra sempre)
------------------------------------------------------------
local function pararSeguir()
	seguindoAlvo = nil
end

local function seguirAte(alvo)
	seguindoAlvo = alvo
	teleportarAte(alvo)
end

RunService.Heartbeat:Connect(function()
	if not seguindoAlvo then
		return
	end
	if not seguindoAlvo.Parent then
		pararSeguir()
		return
	end

	local myChar = player.Character
	local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
	local alvoChar = seguindoAlvo.Character
	local alvoHRP = alvoChar and alvoChar:FindFirstChild("HumanoidRootPart")

	if myHRP and alvoHRP then
		local distancia = (alvoHRP.Position - myHRP.Position).Magnitude
		if distancia > DISTANCIA_MAXIMA_SEGUIR then
			myHRP.CFrame = alvoHRP.CFrame * CFrame.new(0, 0, 3)
		end
	end
end)

------------------------------------------------------------
-- SALVAR LOCAL / RETORNAR AO LOCAL
------------------------------------------------------------
local ARQUIVO_LOCAL_SALVO = "PainelTP_local_salvo.txt"
local corBotaoRetornarAtiva = Color3.fromRGB(50, 120, 200)
local corBotaoRetornarApagada = Color3.fromRGB(40, 40, 44)

-- Grava a posição em arquivo (só funciona em executors que têm writefile; ignora se não existir)
local function persistirLocal()
	if type(writefile) ~= "function" then
		return
	end
	pcall(function()
		local comps = { posicaoSalva:GetComponents() }
		writefile(ARQUIVO_LOCAL_SALVO, table.concat(comps, ","))
	end)
end

-- Lê a posição salva anteriormente (se o executor tiver readfile)
local function carregarLocalPersistido()
	if type(readfile) ~= "function" then
		return
	end
	pcall(function()
		if type(isfile) == "function" and not isfile(ARQUIVO_LOCAL_SALVO) then
			return
		end
		local texto = readfile(ARQUIVO_LOCAL_SALVO)
		if not texto or texto == "" then
			return
		end
		local nums = {}
		for token in texto:gmatch("[^,]+") do
			table.insert(nums, tonumber(token))
		end
		if #nums == 12 then
			posicaoSalva = CFrame.new(unpack(nums))
		end
	end)
end

carregarLocalPersistido()

-- Atualiza a aparência do botão "Retornar" conforme há ou não local salvo
local function atualizarBotaoRetornar()
	if posicaoSalva then
		botaoRetornarLocal.Text = "Retornar"
		botaoRetornarLocal.BackgroundColor3 = corBotaoRetornarAtiva
	else
		botaoRetornarLocal.Text = "Retornar"
		botaoRetornarLocal.BackgroundColor3 = corBotaoRetornarApagada
	end
end

local function salvarLocal()
	local myChar = getCharacter(player)
	local myHRP = myChar:WaitForChild("HumanoidRootPart")

	posicaoSalva = myHRP.CFrame
	persistirLocal()
	atualizarBotaoRetornar()

	botaoSalvarLocal.Text = "Salvo ✓"
	botaoSalvarLocal.BackgroundColor3 = Color3.fromRGB(60, 160, 90)
	task.delay(1.5, function()
		botaoSalvarLocal.Text = "Salvar Local"
		botaoSalvarLocal.BackgroundColor3 = Color3.fromRGB(55, 55, 60)
	end)
end

local function retornarLocal()
	if not posicaoSalva then
		botaoRetornarLocal.Text = "Nada salvo!"
		botaoRetornarLocal.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
		task.delay(1.2, function()
			atualizarBotaoRetornar()
		end)
		return
	end

	-- Para o seguir, senão o Heartbeat puxaria o personagem de volta pro alvo
	if seguindoAlvo then
		pararSeguir()
	end

	local myChar = getCharacter(player)
	local myHRP = myChar:WaitForChild("HumanoidRootPart")
	myHRP.CFrame = posicaoSalva
end

botaoSalvarLocal.MouseButton1Click:Connect(salvarLocal)
botaoRetornarLocal.MouseButton1Click:Connect(retornarLocal)

atualizarBotaoRetornar()

------------------------------------------------------------
-- ESPECTAR
------------------------------------------------------------
local function pararEspectar()
	if not espectando then
		return
	end
	espectando = false
	alvoEspectado = nil

	local myChar = player.Character
	local humanoid = myChar and myChar:FindFirstChildOfClass("Humanoid")

	camera.CameraSubject = humanoid
	camera.CameraType = Enum.CameraType.Custom

	barraEspectando.Visible = false
	atualizarLayoutFrame()
end

local function espectarAte(alvo)
	local alvoChar = alvo.Character
	if not alvoChar then
		return
	end
	local humanoidAlvo = alvoChar:FindFirstChildOfClass("Humanoid")
	if not humanoidAlvo then
		return
	end

	espectando = true
	alvoEspectado = alvo

	camera.CameraSubject = humanoidAlvo
	camera.CameraType = Enum.CameraType.Custom

	labelEspectando.Text = "Espectando: " .. alvo.Name
	barraEspectando.Visible = true
	atualizarLayoutFrame()
end

botaoPararSpec.MouseButton1Click:Connect(pararEspectar)

Players.PlayerRemoving:Connect(function(saindo)
	if espectando and alvoEspectado == saindo then
		pararEspectar()
	end
	if seguindoAlvo == saindo then
		pararSeguir()
	end
end)

local function conectarRespawnEspectado(alvo)
	alvo.CharacterAdded:Connect(function(novoChar)
		if espectando and alvoEspectado == alvo then
			task.wait(0.5)
			local hum = novoChar:WaitForChild("Humanoid", 5)
			if hum then
				camera.CameraSubject = hum
			end
		end
	end)
end

player.CharacterAdded:Connect(function(novoChar)
	if not espectando then
		task.wait(0.2)
		local hum = novoChar:WaitForChild("Humanoid", 5)
		camera.CameraType = Enum.CameraType.Custom
		if hum then
			camera.CameraSubject = hum
		end
	end
end)

------------------------------------------------------------
-- ESP (contorno + nome/distância através de paredes)
------------------------------------------------------------
local function removerESP(alvo)
	local dados = espObjetos[alvo]
	if dados then
		if dados.highlight then
			dados.highlight:Destroy()
		end
		if dados.billboard then
			dados.billboard:Destroy()
		end
		espObjetos[alvo] = nil
	end
end

local function criarESP(alvo)
	if alvo == player then
		return
	end
	removerESP(alvo)

	local alvoChar = alvo.Character
	if not alvoChar then
		return
	end
	local hrp = alvoChar:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "ESP_Highlight"
	highlight.FillColor = Color3.fromRGB(255, 60, 60)
	highlight.FillTransparency = 0.7
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = alvoChar

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ESP_Billboard"
	billboard.Size = UDim2.new(0, 150, 0, 36)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = hrp
	billboard.Parent = alvoChar

	local nomeLabel = Instance.new("TextLabel")
	nomeLabel.Size = UDim2.new(1, 0, 0, 18)
	nomeLabel.BackgroundTransparency = 1
	nomeLabel.Text = alvo.Name
	nomeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nomeLabel.Font = Enum.Font.GothamBold
	nomeLabel.TextSize = 14
	nomeLabel.TextStrokeTransparency = 0
	nomeLabel.Parent = billboard

	local distLabel = Instance.new("TextLabel")
	distLabel.Name = "Distancia"
	distLabel.Size = UDim2.new(1, 0, 0, 16)
	distLabel.Position = UDim2.new(0, 0, 0, 18)
	distLabel.BackgroundTransparency = 1
	distLabel.Text = ""
	distLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
	distLabel.Font = Enum.Font.Gotham
	distLabel.TextSize = 12
	distLabel.TextStrokeTransparency = 0
	distLabel.Parent = billboard

	espObjetos[alvo] = { highlight = highlight, billboard = billboard }
end

local function atualizarESPTodos()
	if espAtivo then
		for _, outroPlayer in ipairs(Players:GetPlayers()) do
			criarESP(outroPlayer)
		end
	else
		for outroPlayer, _ in pairs(espObjetos) do
			removerESP(outroPlayer)
		end
	end
end

botaoESP.MouseButton1Click:Connect(function()
	espAtivo = not espAtivo
	if espAtivo then
		botaoESP.Text = "ESP: ON"
		botaoESP.BackgroundColor3 = Color3.fromRGB(60, 160, 90)
	else
		botaoESP.Text = "ESP: OFF"
		botaoESP.BackgroundColor3 = Color3.fromRGB(55, 55, 60)
	end
	atualizarESPTodos()
end)

RunService.Heartbeat:Connect(function()
	if not espAtivo then
		return
	end
	local myChar = player.Character
	local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
	if not myHRP then
		return
	end

	for outroPlayer, dados in pairs(espObjetos) do
		local alvoChar = outroPlayer.Character
		local alvoHRP = alvoChar and alvoChar:FindFirstChild("HumanoidRootPart")
		if alvoHRP and dados.billboard then
			local distLabel = dados.billboard:FindFirstChild("Distancia")
			if distLabel then
				local distancia = (alvoHRP.Position - myHRP.Position).Magnitude
				distLabel.Text = math.floor(distancia) .. "m"
			end
		end
	end
end)

Players.PlayerAdded:Connect(function(novoPlayer)
	novoPlayer.CharacterAdded:Connect(function()
		if espAtivo then
			task.wait(0.5)
			criarESP(novoPlayer)
		end
	end)
end)
for _, p in ipairs(Players:GetPlayers()) do
	p.CharacterAdded:Connect(function()
		if espAtivo then
			task.wait(0.5)
			criarESP(p)
		end
	end)
end

Players.PlayerRemoving:Connect(function(saindo)
	removerESP(saindo)
end)

------------------------------------------------------------
-- NOCLIP (atravessar paredes)
------------------------------------------------------------
local function aplicarNoclipParte(part)
	if part:IsA("BasePart") then
		if valoresOriginaisCollide[part] == nil then
			valoresOriginaisCollide[part] = part.CanCollide
		end
		part.CanCollide = false
	end
end

local function ativarNoclip()
	local myChar = player.Character
	if not myChar then
		return
	end

	for _, part in ipairs(myChar:GetDescendants()) do
		aplicarNoclipParte(part)
	end

	if noclipConexao then
		noclipConexao:Disconnect()
	end
	noclipConexao = myChar.DescendantAdded:Connect(function(desc)
		if noclipAtivo then
			aplicarNoclipParte(desc)
		end
	end)
end

local function desativarNoclip()
	if noclipConexao then
		noclipConexao:Disconnect()
		noclipConexao = nil
	end
	for part, valorOriginal in pairs(valoresOriginaisCollide) do
		if part and part.Parent then
			part.CanCollide = valorOriginal
		end
	end
	valoresOriginaisCollide = {}
end

botaoNoclip.MouseButton1Click:Connect(function()
	noclipAtivo = not noclipAtivo
	if noclipAtivo then
		botaoNoclip.Text = "Noclip: ON"
		botaoNoclip.BackgroundColor3 = Color3.fromRGB(60, 160, 90)
		ativarNoclip()
	else
		botaoNoclip.Text = "Noclip: OFF"
		botaoNoclip.BackgroundColor3 = Color3.fromRGB(55, 55, 60)
		desativarNoclip()
	end
end)

player.CharacterAdded:Connect(function(novoChar)
	valoresOriginaisCollide = {}
	if noclipConexao then
		noclipConexao:Disconnect()
		noclipConexao = nil
	end
	if noclipAtivo then
		task.wait(0.3)
		ativarNoclip()
	end
end)

------------------------------------------------------------
-- SPEED (velocidade de andar ajustável)
------------------------------------------------------------
local function aplicarSpeed()
	local myChar = player.Character
	local humanoid = myChar and myChar:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = valorSpeed
	end
end

botaoSpeedMenos.MouseButton1Click:Connect(function()
	valorSpeed = math.max(SPEED_MIN, valorSpeed - SPEED_PASSO)
	labelSpeedValor.Text = tostring(valorSpeed)
	aplicarSpeed()
end)

botaoSpeedMais.MouseButton1Click:Connect(function()
	valorSpeed = math.min(SPEED_MAX, valorSpeed + SPEED_PASSO)
	labelSpeedValor.Text = tostring(valorSpeed)
	aplicarSpeed()
end)

-- Max: Speed direto pro limite máximo
botaoSpeedMax.MouseButton1Click:Connect(function()
	valorSpeed = SPEED_MAX
	labelSpeedValor.Text = tostring(valorSpeed)
	aplicarSpeed()
end)

-- Normal: Speed de volta pro padrão
botaoSpeedNormal.MouseButton1Click:Connect(function()
	valorSpeed = SPEED_NORMAL
	labelSpeedValor.Text = tostring(valorSpeed)
	aplicarSpeed()
end)

------------------------------------------------------------
-- SALTO (JumpPower ajustável)
------------------------------------------------------------
local function aplicarJump()
	local myChar = player.Character
	local humanoid = myChar and myChar:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.UseJumpPower = true
		humanoid.JumpPower = valorJump
	end
end

botaoJumpMenos.MouseButton1Click:Connect(function()
	valorJump = math.max(JUMP_MIN, valorJump - JUMP_PASSO)
	labelJumpValor.Text = tostring(valorJump)
	aplicarJump()
end)

botaoJumpMais.MouseButton1Click:Connect(function()
	valorJump = math.min(JUMP_MAX, valorJump + JUMP_PASSO)
	labelJumpValor.Text = tostring(valorJump)
	aplicarJump()
end)

-- Max: Salto direto pro limite máximo
botaoJumpMax.MouseButton1Click:Connect(function()
	valorJump = JUMP_MAX
	labelJumpValor.Text = tostring(valorJump)
	aplicarJump()
end)

-- Normal: Salto de volta pro padrão
botaoJumpNormal.MouseButton1Click:Connect(function()
	valorJump = JUMP_NORMAL
	labelJumpValor.Text = tostring(valorJump)
	aplicarJump()
end)

-- Reaplica Speed e Salto automaticamente quando o personagem respawna
player.CharacterAdded:Connect(function(novoChar)
	task.wait(0.3)
	aplicarSpeed()
	aplicarJump()
end)

------------------------------------------------------------
-- FLY (voar livremente com WASD + Espaço/Ctrl, velocidade ajustável)
------------------------------------------------------------
local function pararFly()
	if not flyAtivo then
		return
	end
	flyAtivo = false

	RunService:UnbindFromRenderStep("PainelTP_Fly")

	if flyBodyVelocity then
		flyBodyVelocity:Destroy()
		flyBodyVelocity = nil
	end
	if flyBodyGyro then
		flyBodyGyro:Destroy()
		flyBodyGyro = nil
	end

	local myChar = player.Character
	local humanoid = myChar and myChar:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = false
	end

	botaoFlyToggle.Text = "OFF"
	botaoFlyToggle.BackgroundColor3 = Color3.fromRGB(70, 70, 76)
end

local function iniciarFly()
	local myChar = player.Character
	if not myChar then
		return
	end
	local hrp = myChar:FindFirstChild("HumanoidRootPart")
	local humanoid = myChar:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid then
		return
	end

	flyAtivo = true
	humanoid.PlatformStand = true

	flyBodyVelocity = Instance.new("BodyVelocity")
	flyBodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
	flyBodyVelocity.Parent = hrp

	flyBodyGyro = Instance.new("BodyGyro")
	flyBodyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
	flyBodyGyro.P = 3000
	flyBodyGyro.D = 100
	flyBodyGyro.Parent = hrp

	botaoFlyToggle.Text = "ON"
	botaoFlyToggle.BackgroundColor3 = Color3.fromRGB(60, 160, 90)

	RunService:BindToRenderStep("PainelTP_Fly", Enum.RenderPriority.Character.Value, function()
		if not flyBodyVelocity or not flyBodyGyro then
			return
		end

		local direcao = Vector3.new(0, 0, 0)
		local camCFrame = camera.CFrame

		if UserInputService:IsKeyDown(Enum.KeyCode.W) then
			direcao = direcao + camCFrame.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then
			direcao = direcao - camCFrame.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then
			direcao = direcao - camCFrame.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then
			direcao = direcao + camCFrame.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			direcao = direcao + Vector3.new(0, 1, 0)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
			direcao = direcao - Vector3.new(0, 1, 0)
		end

		if direcao.Magnitude > 0 then
			direcao = direcao.Unit
		end

		flyBodyVelocity.Velocity = direcao * valorFlySpeed
		flyBodyGyro.CFrame = camCFrame
	end)
end

botaoFlyToggle.MouseButton1Click:Connect(function()
	if flyAtivo then
		pararFly()
	else
		iniciarFly()
	end
end)

botaoFlySpeedMenos.MouseButton1Click:Connect(function()
	valorFlySpeed = math.max(FLYSPEED_MIN, valorFlySpeed - FLYSPEED_PASSO)
	labelFlySpeedValor.Text = tostring(valorFlySpeed)
end)

botaoFlySpeedMais.MouseButton1Click:Connect(function()
	valorFlySpeed = math.min(FLYSPEED_MAX, valorFlySpeed + FLYSPEED_PASSO)
	labelFlySpeedValor.Text = tostring(valorFlySpeed)
end)

-- Max: velocidade do fly direto pro limite máximo
botaoFlyMax.MouseButton1Click:Connect(function()
	valorFlySpeed = FLYSPEED_MAX
	labelFlySpeedValor.Text = tostring(valorFlySpeed)
end)

-- Normal: velocidade do fly de volta pro padrão
botaoFlyNormal.MouseButton1Click:Connect(function()
	valorFlySpeed = FLYSPEED_NORMAL
	labelFlySpeedValor.Text = tostring(valorFlySpeed)
end)

-- Se o personagem respawnar enquanto voando, desliga o fly (evita bug com o novo boneco)
player.CharacterAdded:Connect(function(novoChar)
	if flyAtivo then
		pararFly()
	end
end)

-- Tecla F liga/desliga o fly (ignora se estiver digitando na busca)
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end
	if input.KeyCode == Enum.KeyCode.F then
		if flyAtivo then
			pararFly()
		else
			iniciarFly()
		end
	end
end)

------------------------------------------------------------
-- LISTA DE JOGADORES (favoritos primeiro, cartão organizado)
------------------------------------------------------------
local ALTURA_LINHA = 78
local LARGURA_FOTO = 40
local LARGURA_ESTRELA = 26
local LARGURA_LINHA_INTERNA = LARGURA_UTIL - 4 -- pequena folga p/ scrollbar
local LARGURA_BOTAO_ACAO = math.floor((LARGURA_LINHA_INTERNA - 8) / 3) -- 3 botões, 2 espaços

local function atualizarLista()
	for _, child in ipairs(scrollFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	-- Monta a lista (sem o próprio jogador, e filtrando pelo texto da busca) e ordena: favoritos primeiro, depois por nome
	local textoFiltro = caixaBusca.Text:lower()

	local listaJogadores = {}
	for _, outroPlayer in ipairs(Players:GetPlayers()) do
		if outroPlayer ~= player then
			if textoFiltro == "" or outroPlayer.Name:lower():find(textoFiltro, 1, true) or outroPlayer.DisplayName:lower():find(textoFiltro, 1, true) then
				table.insert(listaJogadores, outroPlayer)
			end
		end
	end

	table.sort(listaJogadores, function(a, b)
		local favA = favoritos[a.UserId] == true
		local favB = favoritos[b.UserId] == true
		if favA ~= favB then
			return favA
		end
		return a.Name:lower() < b.Name:lower()
	end)

	for i, outroPlayer in ipairs(listaJogadores) do
		-- Cartão do jogador
		local linha = Instance.new("Frame")
		linha.Size = UDim2.new(1, 0, 0, ALTURA_LINHA)
		linha.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
		linha.LayoutOrder = i
		linha.Parent = scrollFrame
		criarUICorner(linha, 8)

		-- Foto do boneco
		local foto = Instance.new("ImageLabel")
		foto.Size = UDim2.new(0, LARGURA_FOTO, 0, LARGURA_FOTO)
		foto.Position = UDim2.new(0, 6, 0, 6)
		foto.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
		foto.Parent = linha
		criarUICorner(foto, 6)

		local success, content = pcall(function()
			return Players:GetUserThumbnailAsync(
				outroPlayer.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size100x100
			)
		end)
		if success then
			foto.Image = content
		end

		-- Nome do jogador
		local nomeLabel = Instance.new("TextLabel")
		nomeLabel.Size = UDim2.new(1, -(LARGURA_FOTO + LARGURA_ESTRELA + 18), 0, LARGURA_FOTO)
		nomeLabel.Position = UDim2.new(0, LARGURA_FOTO + 12, 0, 6)
		nomeLabel.BackgroundTransparency = 1
		nomeLabel.Text = outroPlayer.Name
		nomeLabel.TextXAlignment = Enum.TextXAlignment.Left
		nomeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nomeLabel.Font = Enum.Font.GothamBold
		nomeLabel.TextSize = 15
		nomeLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nomeLabel.Parent = linha

		-- Estrela de favorito, no canto superior direito do cartão
		local ehFavorito = favoritos[outroPlayer.UserId] == true
		local botaoFavorito = Instance.new("TextButton")
		botaoFavorito.Size = UDim2.new(0, LARGURA_ESTRELA, 0, LARGURA_ESTRELA)
		botaoFavorito.Position = UDim2.new(1, -(LARGURA_ESTRELA + 6), 0, 6)
		botaoFavorito.BackgroundTransparency = 1
		botaoFavorito.Text = ehFavorito and "★" or "☆"
		botaoFavorito.TextColor3 = ehFavorito and Color3.fromRGB(255, 210, 60) or Color3.fromRGB(140, 140, 145)
		botaoFavorito.Font = Enum.Font.GothamBold
		botaoFavorito.TextSize = 20
		botaoFavorito.Parent = linha

		-- Linha de botões de ação (TP / Spec / Seguir), largura igual entre os três
		local Y_ACOES = LARGURA_FOTO + 12

		local botaoTP = novoBotao(
			linha,
			"TP",
			UDim2.new(0, LARGURA_BOTAO_ACAO, 0, 26),
			UDim2.new(0, 6, 0, Y_ACOES),
			Color3.fromRGB(50, 120, 200),
			12
		)

		local botaoSpec = novoBotao(
			linha,
			"Spec",
			UDim2.new(0, LARGURA_BOTAO_ACAO, 0, 26),
			UDim2.new(0, 6 + LARGURA_BOTAO_ACAO + 4, 0, Y_ACOES),
			Color3.fromRGB(90, 90, 95),
			12
		)

		local seguindoEsse = seguindoAlvo == outroPlayer
		local botaoSeguir = novoBotao(
			linha,
			seguindoEsse and "Seguindo" or "Seguir",
			UDim2.new(0, LARGURA_BOTAO_ACAO, 0, 26),
			UDim2.new(0, 6 + (LARGURA_BOTAO_ACAO + 4) * 2, 0, Y_ACOES),
			seguindoEsse and Color3.fromRGB(60, 160, 90) or Color3.fromRGB(90, 90, 95),
			12
		)

		botaoTP.MouseButton1Click:Connect(function()
			teleportarAte(outroPlayer)
		end)

		botaoSpec.MouseButton1Click:Connect(function()
			espectarAte(outroPlayer)
		end)

		botaoFavorito.MouseButton1Click:Connect(function()
			if favoritos[outroPlayer.UserId] then
				favoritos[outroPlayer.UserId] = nil
			else
				favoritos[outroPlayer.UserId] = true
			end
			atualizarLista()
		end)

		botaoSeguir.MouseButton1Click:Connect(function()
			if seguindoAlvo == outroPlayer then
				pararSeguir()
			else
				seguirAte(outroPlayer)
			end
			atualizarLista()
		end)

		conectarRespawnEspectado(outroPlayer)
	end
end

Players.PlayerAdded:Connect(atualizarLista)
Players.PlayerRemoving:Connect(atualizarLista)

-- Atualiza a lista em tempo real conforme a pessoa digita na busca
caixaBusca:GetPropertyChangedSignal("Text"):Connect(atualizarLista)

atualizarLista()
