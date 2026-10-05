-- LocalScript dentro de StarterGui
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local VirtualUser = (function()
	local ok, vu = pcall(function() return game:GetService("VirtualUser") end)
	return ok and vu or nil
end)()
local player = Players.LocalPlayer
while not player do
	player = Players.LocalPlayer
	task.wait()
end
local camera = workspace.CurrentCamera
local UI = {}

------------------------------------------------------------
-- ÍCONE DO BOTÃO FLUTUANTE (o círculo que abre o painel)
-- IMAGEM_BOTAO aceita 3 formatos:
--   1) URL (https://...)      = baixa e registra automaticamente (funciona em executors)
--   2) "rbxassetid://1234..." = ID de um decal enviado no Roblox (funciona em qualquer lugar)
--   3) ""                     = usa o emoji de ICONE_FALLBACK
------------------------------------------------------------
local IMAGEM_BOTAO = "https://i.pinimg.com/736x/6a/0f/ac/6a0facac537ff3a1fae07aa00fcc0578.jpg"
local ICONE_FALLBACK = "📍"

------------------------------------------------------------
-- FUNDO DO PAINEL (imagem atrás de tudo)
-- IMAGEM_FUNDO aceita os mesmos 3 formatos do botão:
--   1) URL (https://...)      2) "rbxassetid://1234..."   3) "" = cor sólida
------------------------------------------------------------
local IMAGEM_FUNDO = "https://raw.githubusercontent.com/alahdevip/painel-1hz/main/fundo-painel.jpg"
local IMAGEM_FUNDO_2 = "https://i.pinimg.com/736x/74/5e/83/745e835eca5be13b1df753fcb279b35e.jpg"
local ESCURECER_FUNDO = 0.08 -- mulher 2D em preto e branco totalmente à mostra (sem escurecimento pesado)

------------------------------------------------------------
-- LOGO DO CABEÇALHO (no lugar do texto "Painel do ...")
-- Mesmos 3 formatos: URL / "rbxassetid://..." / "" (= mantém o texto)
------------------------------------------------------------
local IMAGEM_LOGO = "https://raw.githubusercontent.com/alahdevip/painel-1hz/main/logo-demoniaka.png"
local IMAGEM_LOGO_2 = "https://files.catbox.moe/4qxeuk.png" -- espelho: se o GitHub falhar no executor, tenta aqui
local FONTE_DEMONIAKA_URL = "https://raw.githubusercontent.com/alahdevip/painel-1hz/main/fonte-demoniaka.ttf"

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
local noclipLoop = nil -- Stepped: reforça o noclip a cada frame
local valoresOriginaisCollide = {} -- [BasePart] = CanCollide original

local antiCairAtivo = false
local antiCairLoop = nil
local antiCairStateConn = nil
local ultimoChaoSeguro = nil

local antiFreezeAtivo = false
local antiFreezeLoop = nil

local spinbotAtivo = false
local spinbotLoop = nil

local spiderManAtivo = false
local spiderManLoop = nil

local clickTpAtivo = false

local antiAfkAtivo = false
local antiAfkConn = nil

local attachAlvo = nil
local attachLoop = nil

local orbitAlvo = nil
local orbitLoop = nil
local orbitAngulo = 0

local autoLookAlvo = nil
local autoLookLoop = nil

local animacaoAtualTrack = nil

local fantasmaAtivo = false
local partesTransparenciaOriginal = {}
local jogadorInspecionadoAtual = nil

local favoritos = {} -- [UserId] = true

local seguindoAlvo = nil -- Player sendo seguido (só um por vez)

local posicaoSalva = nil -- CFrame do local salvo pelo botão "Salvar Local"

-- Speed / Jump / Fly
local CFG = {
	SPEED_NORMAL = 16, JUMP_NORMAL = 50, FLYSPEED_NORMAL = 50,
	SPEED_MIN = 8, SPEED_MAX = 1000, SPEED_PASSO = 20,
	JUMP_MIN = 20, JUMP_MAX = 1000, JUMP_PASSO = 50,
	FLYSPEED_MIN = 10, FLYSPEED_MAX = 1000, FLYSPEED_PASSO = 50,
	ORBIT_RAIO = 6.5, ORBIT_ALTURA = 1.5, ORBIT_VELOCIDADE = 9,
	DISTANCIA_MAXIMA_SEGUIR = 3,
}
local valorSpeed = CFG.SPEED_NORMAL
local valorJump = CFG.JUMP_NORMAL
local valorFlySpeed = CFG.FLYSPEED_NORMAL

local flyAtivo = false
local flyBodyVelocity = nil
local flyBodyGyro = nil

local seguirHeartbeat = nil -- loop do seguir (desconectado ao desinjetar)
local espHeartbeat = nil -- loop do ESP (desconectado ao desinjetar)
local destruido = false
local destruirPainel -- definida no fim do script: clique no logo desinjeta tudo

------------------------------------------------------------
-- DIMENSÕES DO PAINEL (usadas para alinhar tudo certinho)
------------------------------------------------------------
local LARGURA_PAINEL = 320
local ALTURA_PAINEL = 556
local TAMANHO_ICONE = 50
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

-- Borda bem fina nos botões (fundo continua invisível, só o contorno marca o clique)
local function criarBorda(instancia, cor, transparencia)
	local borda = Instance.new("UIStroke")
	borda.Color = cor or Color3.fromRGB(255, 255, 255)
	borda.Thickness = 1 -- bem fininha
	borda.Transparency = transparencia or 0.55
	borda.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	borda.Parent = instancia
	return borda
end

------------------------------------------------------------
-- FONTE DEMONÍACA (estilo Metal Mania da logo DEMONIAKA)
------------------------------------------------------------
local function baixarArquivo(url)
	local headers = { ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36" }
	local candidatas = {}
	if type(request) == "function" then table.insert(candidatas, request) end
	if type(http_request) == "function" then table.insert(candidatas, http_request) end
	if type(syn) == "table" and type(syn.request) == "function" then table.insert(candidatas, syn.request) end

	for _, fn in ipairs(candidatas) do
		local ok, r = pcall(fn, { Url = url, Method = "GET", Headers = headers })
		if ok and type(r) == "table" and type(r.Body) == "string" and #r.Body > 1000 then
			return r.Body
		end
	end

	local ok, corpo = pcall(function()
		return game:HttpGet(url, true)
	end)
	if ok and type(corpo) == "string" and #corpo > 1000 then
		return corpo
	end

	return nil
end

local function resolverFonteDemoniaka()
	local customAssetFn = (type(getcustomasset) == "function" and getcustomasset) or (type(getsynasset) == "function" and getsynasset)
	local customFontFace = nil

	if customAssetFn and type(writefile) == "function" then
		pcall(function()
			local arqFonte = "fonte-demoniaka.ttf"
			local existe = (type(isfile) == "function" and (isfile(arqFonte) or isfile("PainelTP_fonte.ttf")))
			local nomeFinal = (type(isfile) == "function" and isfile(arqFonte) and arqFonte) or "PainelTP_fonte.ttf"

			if not existe then
				local conteudo = baixarArquivo(FONTE_DEMONIAKA_URL)
				if conteudo then
					writefile(nomeFinal, conteudo)
					existe = true
				end
			end

			if existe then
				local assetTtf = customAssetFn(nomeFinal)
				-- Tentativa 1: Font Family JSON (padrão Roblox)
				local arqJson = "PainelTP_demoniaka.json"
				local jsonDados = '{"name":"Metal Mania","faces":[{"name":"Regular","weight":400,"style":"normal","assetId":"' .. tostring(assetTtf) .. '"}]}'
				pcall(writefile, arqJson, jsonDados)

				local ok1, f1 = pcall(function()
					return Font.new(customAssetFn(arqJson))
				end)
				if ok1 and f1 then
					customFontFace = f1
				else
					local ok2, f2 = pcall(function()
						return Font.new(assetTtf)
					end)
					if ok2 and f2 then
						customFontFace = f2
					end
				end
			end
		end)
	end

	-- Fallback nativo do Roblox: Creepster ou Nosifer
	local fallbackFontFace = nil
	local fontesNativas = {
		"rbxasset://fonts/families/Nosifer.json",
		"rbxasset://fonts/families/Creepster.json",
		"rbxasset://fonts/families/GrenzeGotisch.json",
	}
	for _, caminho in ipairs(fontesNativas) do
		local ok, f = pcall(function()
			return Font.new(caminho)
		end)
		if ok and f then
			fallbackFontFace = f
			break
		end
	end

	return customFontFace or fallbackFontFace, Enum.Font.Creepster
end

local FONTE_DEMONIAKA_FACE, FONTE_DEMONIAKA_ENUM = resolverFonteDemoniaka()

local function aplicarFonte(instancia, tamanho)
	pcall(function()
		instancia.Font = FONTE_DEMONIAKA_ENUM
	end)
	if FONTE_DEMONIAKA_FACE then
		pcall(function()
			instancia.FontFace = FONTE_DEMONIAKA_FACE
		end)
	end
	if tamanho then
		instancia.TextSize = tamanho
	end
end

local function novoBotao(pai, texto, tamanho, posicao, corFundo, tamanhoFonte)
	local botao = Instance.new("TextButton")
	botao.Size = tamanho
	botao.Position = posicao
	botao.BackgroundColor3 = corFundo or Color3.fromRGB(35, 35, 40)
	botao.BackgroundTransparency = 1 -- SEM FUNDO: 100% transparente para a mulher 2D ficar totalmente à mostra
	botao.Text = texto
	botao.TextColor3 = Color3.fromRGB(255, 255, 255)
	botao.TextStrokeTransparency = 0.2 -- contorno preto nítido e definido (sem embaçar)
	aplicarFonte(botao, tamanhoFonte or 13)
	botao.AutoButtonColor = true
	botao.Parent = pai
	criarUICorner(botao, 6)
	criarBorda(botao, Color3.fromRGB(255, 255, 255), 0.45)
	return botao
end

------------------------------------------------------------
-- ESTRUTURA BASE DO PAINEL
------------------------------------------------------------

-- Botão flutuante de abrir/fechar (sempre visível)
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PainelTP"
screenGui.ResetOnSpawn = false

pcall(function()
	if type(gethui) == "function" then
		screenGui.Parent = gethui()
	elseif syn and syn.protect_gui then
		syn.protect_gui(screenGui)
		screenGui.Parent = game:GetService("CoreGui")
	end
end)
if not screenGui.Parent then
	screenGui.Parent = player:WaitForChild("PlayerGui")
end

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

local function resolverImagem(url, prefixo)
	if url == "" or url:sub(1, 4) ~= "http" then
		return url -- vazio ou rbxassetid://: usa direto
	end

	if type(writefile) ~= "function" or (type(getcustomasset) ~= "function" and type(getsynasset) ~= "function") then
		warn("[PainelTP] Imagem precisa de um executor (falta writefile/getcustomasset). Usando o emoji do botão.")
		return ""
	end

	-- o nome do cache inclui um pedaço da URL: trocou a URL, baixa a nova (sem reaproveitar imagem velha)
	local base = url:match("([^/%?]+)$") or "img"
	base = base:gsub("[^%w%.%-]", "_")
	local arquivo = (prefixo or "PainelTP_imagem") .. "_" .. base

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

local imagemToggle = resolverImagem(IMAGEM_BOTAO, "PainelTP_botao")

local botaoToggle = Instance.new("ImageButton")
botaoToggle.Size = UDim2.new(0, TAMANHO_ICONE, 0, TAMANHO_ICONE)
botaoToggle.Position = UDim2.new(0, 20, 0.5, -180)
botaoToggle.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
botaoToggle.Image = imagemToggle -- vazio = mostra o emoji abaixo
botaoToggle.ScaleType = Enum.ScaleType.Crop -- preenche o círculo todo (Fit espremeria a imagem)
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
	aplicarFonte(iconeToggle, 22)
	iconeToggle.Parent = botaoToggle
end
-- Frame principal (painel)
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, LARGURA_PAINEL, 0, ALTURA_PAINEL)
frame.Position = UDim2.new(0, 20, 0.5, -233)
frame.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
frame.BorderSizePixel = 0
frame.Visible = true -- abre automaticamente ao executar
frame.Parent = screenGui
criarUICorner(frame, 10)

------------------------------------------------------------
-- FUNDO DO PAINEL (imagem + camada escura pra manter a leitura)
------------------------------------------------------------
local imagemFundo = resolverImagem(IMAGEM_FUNDO, "PainelTP_fundo")
if imagemFundo == "" and IMAGEM_FUNDO_2 then
	imagemFundo = resolverImagem(IMAGEM_FUNDO_2, "PainelTP_fundo")
end

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

-- Logo DEMONIAKA no lugar do título (o texto abaixo vira fallback se a imagem falhar)
-- É um BOTÃO invisível: CLICAR NELE DESINJETA TUDO (painel + bolinha somem)
local logoTitulo = Instance.new("ImageButton")
logoTitulo.Name = "Logo"
logoTitulo.Size = UDim2.new(0, 88, 0, 32)
logoTitulo.Position = UDim2.new(0, MARGEM, 0, 1)
logoTitulo.BackgroundTransparency = 1
logoTitulo.BorderSizePixel = 0
logoTitulo.ScaleType = Enum.ScaleType.Fit -- mantém a proporção, sem distorcer
logoTitulo.AutoButtonColor = false -- sem flash cinza: o logo é a própria arte
do -- tenta o GitHub primeiro, cai pro espelho se falhar
	local assetLogo = resolverImagem(IMAGEM_LOGO, "PainelTP_logo")
	if assetLogo == "" then
		print("[PainelTP] Logo: GitHub falhou, tentando o espelho...")
		assetLogo = resolverImagem(IMAGEM_LOGO_2, "PainelTP_logo")
	end
	logoTitulo.Image = assetLogo
end
logoTitulo.Parent = frame
logoTitulo.MouseButton1Click:Connect(function()
	destruirPainel()
end)

local titulo = Instance.new("TextLabel")
titulo.Size = UDim2.new(1, -70, 0, 32)
titulo.Position = UDim2.new(0, MARGEM, 0, 0)
titulo.BackgroundTransparency = 1
titulo.Text = "Painel do " .. (player.DisplayName or player.Name)
titulo.TextXAlignment = Enum.TextXAlignment.Left
titulo.TextColor3 = Color3.fromRGB(255, 255, 255)
aplicarFonte(titulo, 16)
titulo.TextStrokeTransparency = 1
titulo.Visible = (logoTitulo.Image == "") -- só aparece se o logo falhar
titulo.Parent = frame

UI.botaoMinimizar = Instance.new("TextButton")
UI.botaoMinimizar.Size = UDim2.new(0, 26, 0, 26)
UI.botaoMinimizar.Position = UDim2.new(1, -62, 0, 3)
UI.botaoMinimizar.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
UI.botaoMinimizar.BackgroundTransparency = 1 -- sem fundo
UI.botaoMinimizar.Text = "-"
UI.botaoMinimizar.TextColor3 = Color3.fromRGB(220, 220, 230)
aplicarFonte(UI.botaoMinimizar, 14)
UI.botaoMinimizar.TextStrokeTransparency = 0.2
UI.botaoMinimizar.Parent = frame
criarUICorner(UI.botaoMinimizar, 13)
criarBorda(UI.botaoMinimizar, Color3.fromRGB(200, 200, 205), 0.5)

local painelMinimizado = false
UI.botaoMinimizar.MouseButton1Click:Connect(function()
	painelMinimizado = not painelMinimizado
	if painelMinimizado then
		UI.botaoMinimizar.Text = "+"
		frame.ClipsDescendants = true
		frame.Size = UDim2.new(0, LARGURA_PAINEL, 0, 32)
	else
		UI.botaoMinimizar.Text = "-"
		frame.ClipsDescendants = false
		frame.Size = UDim2.new(0, LARGURA_PAINEL, 0, ALTURA_PAINEL)
	end
end)

UI.botaoFechar = Instance.new("TextButton")
UI.botaoFechar.Size = UDim2.new(0, 26, 0, 26)
UI.botaoFechar.Position = UDim2.new(1, -32, 0, 3)
UI.botaoFechar.BackgroundColor3 = Color3.fromRGB(55, 20, 20)
UI.botaoFechar.BackgroundTransparency = 1 -- sem fundo
UI.botaoFechar.Text = "X"
UI.botaoFechar.TextColor3 = Color3.fromRGB(255, 120, 120)
aplicarFonte(UI.botaoFechar, 14)
UI.botaoFechar.TextStrokeTransparency = 0.2
UI.botaoFechar.Parent = frame
criarUICorner(UI.botaoFechar, 13)
criarBorda(UI.botaoFechar, Color3.fromRGB(255, 120, 120), 0.6)

------------------------------------------------------------
-- CABEÇALHO — LINHAS DE FERRAMENTAS
------------------------------------------------------------
local Y_ROW1 = 36
local Y_ROW2 = 64
local Y_ROW3 = 92
local Y_ROW4 = 120
local ALTURA_BTN_TOOLBAR = 24
local LARGURA_3 = math.floor((LARGURA_UTIL - 16) / 3) -- (304 - 16) / 3 = 96
local LARGURA_2 = math.floor((LARGURA_UTIL - 8) / 2)  -- (304 - 8) / 2 = 148

-- Linha 1: Noclip / ESP / Anti-Cair
UI.botaoNoclip = novoBotao(
	frame,
	"Noclip: OFF",
	UDim2.new(0, LARGURA_3, 0, ALTURA_BTN_TOOLBAR),
	UDim2.new(0, MARGEM, 0, Y_ROW1),
	Color3.fromRGB(55, 55, 60),
	11
)

UI.botaoESP = novoBotao(
	frame,
	"ESP: OFF",
	UDim2.new(0, LARGURA_3, 0, ALTURA_BTN_TOOLBAR),
	UDim2.new(0, MARGEM + LARGURA_3 + 8, 0, Y_ROW1),
	Color3.fromRGB(55, 55, 60),
	11
)

UI.botaoAntiCair = novoBotao(
	frame,
	"Anti-Cair: OFF",
	UDim2.new(0, LARGURA_3, 0, ALTURA_BTN_TOOLBAR),
	UDim2.new(0, MARGEM + (LARGURA_3 + 8) * 2, 0, Y_ROW1),
	Color3.fromRGB(55, 55, 60),
	11
)

-- Linha 2: Anti-Freeze / Spinbot / Spider
UI.botaoAntiFreeze = novoBotao(
	frame,
	"Anti-Freeze: OFF",
	UDim2.new(0, LARGURA_3, 0, ALTURA_BTN_TOOLBAR),
	UDim2.new(0, MARGEM, 0, Y_ROW2),
	Color3.fromRGB(55, 55, 60),
	10
)

UI.botaoSpinbot = novoBotao(
	frame,
	"Spinbot: OFF",
	UDim2.new(0, LARGURA_3, 0, ALTURA_BTN_TOOLBAR),
	UDim2.new(0, MARGEM + LARGURA_3 + 8, 0, Y_ROW2),
	Color3.fromRGB(55, 55, 60),
	11
)

UI.botaoSpider = novoBotao(
	frame,
	"Spider: OFF",
	UDim2.new(0, LARGURA_3, 0, ALTURA_BTN_TOOLBAR),
	UDim2.new(0, MARGEM + (LARGURA_3 + 8) * 2, 0, Y_ROW2),
	Color3.fromRGB(55, 55, 60),
	11
)

local LARGURA_4 = math.floor((LARGURA_UTIL - 12) / 4) -- (304 - 12) / 4 = 73

-- Linha 3: Click TP / Fantasma / Rejoin / Servidores
UI.botaoClickTp = novoBotao(
	frame,
	"Click TP: OFF",
	UDim2.new(0, LARGURA_4, 0, ALTURA_BTN_TOOLBAR),
	UDim2.new(0, MARGEM, 0, Y_ROW3),
	Color3.fromRGB(55, 55, 60),
	10
)

UI.botaoFantasma = novoBotao(
	frame,
	"Ghost: OFF",
	UDim2.new(0, LARGURA_4, 0, ALTURA_BTN_TOOLBAR),
	UDim2.new(0, MARGEM + (LARGURA_4 + 4) * 1, 0, Y_ROW3),
	Color3.fromRGB(55, 55, 60),
	10
)

UI.botaoRejoin = novoBotao(
	frame,
	"Rejoin",
	UDim2.new(0, LARGURA_4, 0, ALTURA_BTN_TOOLBAR),
	UDim2.new(0, MARGEM + (LARGURA_4 + 4) * 2, 0, Y_ROW3),
	Color3.fromRGB(55, 55, 60),
	10
)

UI.botaoServidores = novoBotao(
	frame,
	"Servidores",
	UDim2.new(0, LARGURA_4, 0, ALTURA_BTN_TOOLBAR),
	UDim2.new(0, MARGEM + (LARGURA_4 + 4) * 3, 0, Y_ROW3),
	Color3.fromRGB(55, 55, 60),
	10
)

-- Linha 4: Salvar / Retornar / Anti-AFK / Emotes

UI.botaoSalvarLocal = novoBotao(
	frame,
	"Salvar",
	UDim2.new(0, LARGURA_4, 0, ALTURA_BTN_TOOLBAR),
	UDim2.new(0, MARGEM, 0, Y_ROW4),
	Color3.fromRGB(55, 55, 60),
	10
)

UI.botaoRetornarLocal = novoBotao(
	frame,
	"Retornar",
	UDim2.new(0, LARGURA_4, 0, ALTURA_BTN_TOOLBAR),
	UDim2.new(0, MARGEM + (LARGURA_4 + 4) * 1, 0, Y_ROW4),
	Color3.fromRGB(40, 40, 44),
	10
)

UI.botaoAntiAfk = novoBotao(
	frame,
	"AFK: OFF",
	UDim2.new(0, LARGURA_4, 0, ALTURA_BTN_TOOLBAR),
	UDim2.new(0, MARGEM + (LARGURA_4 + 4) * 2, 0, Y_ROW4),
	Color3.fromRGB(55, 55, 60),
	10
)

UI.botaoEmotes = novoBotao(
	frame,
	"Emotes",
	UDim2.new(0, LARGURA_4, 0, ALTURA_BTN_TOOLBAR),
	UDim2.new(0, MARGEM + (LARGURA_4 + 4) * 3, 0, Y_ROW4),
	Color3.fromRGB(55, 55, 60),
	10
)

------------------------------------------------------------
-- CABEÇALHO — linha 4: Speed / Jump / Fly (com ajuste de valor)
------------------------------------------------------------
local Y_MOVIMENTO_TITULO = Y_ROW4 + ALTURA_BTN_TOOLBAR + 8 -- 152

local labelMovimento = Instance.new("TextLabel")
labelMovimento.Size = UDim2.new(1, 0, 0, 14)
labelMovimento.Position = UDim2.new(0, MARGEM, 0, Y_MOVIMENTO_TITULO)
labelMovimento.BackgroundTransparency = 1
labelMovimento.Text = "MOVIMENTO"
labelMovimento.TextXAlignment = Enum.TextXAlignment.Left
labelMovimento.TextColor3 = Color3.fromRGB(220, 220, 230)
aplicarFonte(labelMovimento, 12)
labelMovimento.Parent = frame

local ALTURA_LINHA_MOV = 24
local GAP_LINHA_MOV = 3
local Y_LINHAS_MOV = Y_MOVIMENTO_TITULO + 16

-- Cria uma linha padrão: label + Max + Normal + botão "-" + valor + botão "+"
-- (a linha do Fly ainda recebe o toggle ON/OFF entre o Normal e o "-")
local function criarLinhaAjuste(y, textoLabel, valorInicial, sufixo)
	local linha = Instance.new("Frame")
	linha.Size = UDim2.new(1, -MARGEM * 2, 0, ALTURA_LINHA_MOV)
	linha.Position = UDim2.new(0, MARGEM, 0, y)
	linha.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
	linha.BackgroundTransparency = 1 -- SEM FUNDO: a imagem de fundo fica visível
	linha.Parent = frame
	criarUICorner(linha, 6)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0, 70, 1, 0)
	label.Position = UDim2.new(0, 8, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = textoLabel
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	aplicarFonte(label, 12)
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.TextStrokeTransparency = 0.2 -- nítido e legível sobre a arte
	label.Parent = linha

	local botaoMenos = novoBotao(linha, "-", UDim2.new(0, 24, 0, 18), UDim2.new(1, -104, 0.5, -9), Color3.fromRGB(70, 70, 76), 13)
	local valorLabel = Instance.new("TextLabel")
	valorLabel.Size = UDim2.new(0, 44, 1, 0)
	valorLabel.Position = UDim2.new(1, -76, 0, 0)
	valorLabel.BackgroundTransparency = 1
	valorLabel.Text = tostring(valorInicial) .. (sufixo or "")
	valorLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	aplicarFonte(valorLabel, 12)
	valorLabel.TextStrokeTransparency = 0.2 -- nítido e legível sobre a arte
	valorLabel.Parent = linha
	local botaoMais = novoBotao(linha, "+", UDim2.new(0, 24, 0, 18), UDim2.new(1, -28, 0.5, -9), Color3.fromRGB(70, 70, 76), 13)

	local botaoMax = novoBotao(linha, "Max", UDim2.new(0, 32, 0, 18), UDim2.new(0, 82, 0.5, -9), Color3.fromRGB(55, 55, 60), 10)
	local botaoNormal = novoBotao(linha, "Normal", UDim2.new(0, 42, 0, 18), UDim2.new(0, 118, 0.5, -9), Color3.fromRGB(55, 55, 60), 10)

	return linha, botaoMenos, valorLabel, botaoMais, botaoMax, botaoNormal
end

-- Linha Speed
_, UI.botaoSpeedMenos, UI.labelSpeedValor, UI.botaoSpeedMais, UI.botaoSpeedMax, UI.botaoSpeedNormal = criarLinhaAjuste(Y_LINHAS_MOV, "Velocidade", valorSpeed, "")

-- Linha Jump
local Y_LINHA_JUMP = Y_LINHAS_MOV + ALTURA_LINHA_MOV + GAP_LINHA_MOV
_, UI.botaoJumpMenos, UI.labelJumpValor, UI.botaoJumpMais, UI.botaoJumpMax, UI.botaoJumpNormal = criarLinhaAjuste(Y_LINHA_JUMP, "Salto", valorJump, "")

-- Linha Fly (label + botão liga/desliga + controles de velocidade)
local Y_LINHA_FLY = Y_LINHA_JUMP + ALTURA_LINHA_MOV + GAP_LINHA_MOV
local linhaFly; linhaFly, UI.botaoFlySpeedMenos, UI.labelFlySpeedValor, UI.botaoFlySpeedMais, UI.botaoFlyMax, UI.botaoFlyNormal = criarLinhaAjuste(Y_LINHA_FLY, "Voar", valorFlySpeed, "")

UI.botaoFlyToggle = Instance.new("TextButton")
UI.botaoFlyToggle.Size = UDim2.new(0, 28, 0, 18)
UI.botaoFlyToggle.Position = UDim2.new(0, 164, 0.5, -9)
UI.botaoFlyToggle.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
UI.botaoFlyToggle.BackgroundTransparency = 1 -- sem fundo
UI.botaoFlyToggle.Text = "OFF"
UI.botaoFlyToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
aplicarFonte(UI.botaoFlyToggle, 10)
UI.botaoFlyToggle.TextStrokeTransparency = 0.2
UI.botaoFlyToggle.Parent = linhaFly
criarUICorner(UI.botaoFlyToggle, 5)
criarBorda(UI.botaoFlyToggle)

------------------------------------------------------------
-- CAIXA DE BUSCA (filtra a lista por nome digitado)
------------------------------------------------------------
local Y_BUSCA = Y_LINHA_FLY + ALTURA_LINHA_MOV + 8 -- logo abaixo da seção Movimento

UI.caixaBusca = Instance.new("TextBox")
UI.caixaBusca.Size = UDim2.new(1, -MARGEM * 2, 0, 26)
UI.caixaBusca.Position = UDim2.new(0, MARGEM, 0, Y_BUSCA)
UI.caixaBusca.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
UI.caixaBusca.BackgroundTransparency = 1 -- sem fundo: flutua sobre a mulher 2D
UI.caixaBusca.PlaceholderText = "Pesquisar jogador..."
UI.caixaBusca.PlaceholderColor3 = Color3.fromRGB(160, 160, 165)
UI.caixaBusca.Text = ""
UI.caixaBusca.TextColor3 = Color3.fromRGB(255, 255, 255)
aplicarFonte(UI.caixaBusca, 12)
UI.caixaBusca.TextStrokeTransparency = 0.2
UI.caixaBusca.ClearTextOnFocus = false
UI.caixaBusca.Parent = frame
criarUICorner(UI.caixaBusca, 6)
criarBorda(UI.caixaBusca, Color3.fromRGB(255, 255, 255), 0.5)

UI.caixaBusca.TextXAlignment = Enum.TextXAlignment.Left

-- Pequena margem esquerda pro texto não colar na borda
local paddingBusca = Instance.new("UIPadding")
paddingBusca.PaddingLeft = UDim.new(0, 10)
paddingBusca.Parent = UI.caixaBusca

------------------------------------------------------------
-- BARRA "ESPECTANDO AGORA" (só aparece quando ativo)
------------------------------------------------------------
local Y_BARRA_ESPECTANDO_REAL = Y_BUSCA + 26 + 6

UI.barraEspectando = Instance.new("Frame")
UI.barraEspectando.Size = UDim2.new(1, -MARGEM * 2, 0, 26)
UI.barraEspectando.Position = UDim2.new(0, MARGEM, 0, Y_BARRA_ESPECTANDO_REAL)
UI.barraEspectando.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
UI.barraEspectando.BackgroundTransparency = 0.3 -- barra translúcida
UI.barraEspectando.Visible = false
UI.barraEspectando.Parent = frame
criarUICorner(UI.barraEspectando, 6)

UI.labelEspectando = Instance.new("TextLabel")
UI.labelEspectando.Size = UDim2.new(1, -86, 1, 0)
UI.labelEspectando.Position = UDim2.new(0, 10, 0, 0)
UI.labelEspectando.BackgroundTransparency = 1
UI.labelEspectando.TextXAlignment = Enum.TextXAlignment.Left
UI.labelEspectando.Text = "Espectando: -"
UI.labelEspectando.TextColor3 = Color3.fromRGB(255, 255, 255)
aplicarFonte(UI.labelEspectando, 12)
UI.labelEspectando.TextStrokeTransparency = 1
UI.labelEspectando.Parent = UI.barraEspectando

UI.botaoPararSpec = novoBotao(
	UI.barraEspectando,
	"Parar",
	UDim2.new(0, 68, 0, 20),
	UDim2.new(1, -74, 0, 3),
	Color3.fromRGB(180, 60, 60),
	11
)

------------------------------------------------------------
-- LISTA DE JOGADORES (área com scroll)
------------------------------------------------------------
local Y_LISTA_SEM_BARRA = Y_BARRA_ESPECTANDO_REAL
local Y_LISTA_COM_BARRA = Y_BARRA_ESPECTANDO_REAL + 26 + 6

UI.scrollFrame = Instance.new("ScrollingFrame")
UI.scrollFrame.Size = UDim2.new(1, -MARGEM * 2, 1, -(Y_LISTA_SEM_BARRA + MARGEM))
UI.scrollFrame.Position = UDim2.new(0, MARGEM, 0, Y_LISTA_SEM_BARRA)
UI.scrollFrame.BackgroundTransparency = 1
UI.scrollFrame.BorderSizePixel = 0
UI.scrollFrame.ScrollBarThickness = 5
UI.scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(90, 90, 95)
UI.scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
UI.scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
UI.scrollFrame.Parent = frame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = UI.scrollFrame

-- Ajusta a posição/altura do scroll quando a barra de espectar aparece/some
local function atualizarLayoutFrame()
	if UI.barraEspectando.Visible then
		UI.scrollFrame.Position = UDim2.new(0, MARGEM, 0, Y_LISTA_COM_BARRA)
		UI.scrollFrame.Size = UDim2.new(1, -MARGEM * 2, 1, -(Y_LISTA_COM_BARRA + MARGEM))
	else
		UI.scrollFrame.Position = UDim2.new(0, MARGEM, 0, Y_LISTA_SEM_BARRA)
		UI.scrollFrame.Size = UDim2.new(1, -MARGEM * 2, 1, -(Y_LISTA_SEM_BARRA + MARGEM))
	end
end

------------------------------------------------------------
-- ARRASTAR A BOLINHA (segura o botão flutuante e move pela tela)
------------------------------------------------------------
do
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
end
UI.botaoFechar.MouseButton1Click:Connect(function()
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
do
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
end

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

seguirHeartbeat = RunService.Heartbeat:Connect(function()
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
		if distancia > CFG.DISTANCIA_MAXIMA_SEGUIR then
			myHRP.CFrame = alvoHRP.CFrame * CFrame.new(0, 0, 3)
		end
	end
end)

------------------------------------------------------------
-- SALVAR LOCAL / RETORNAR AO LOCAL
------------------------------------------------------------
local ARQUIVO_LOCAL_SALVO = "PainelTP_local_salvo.txt"
-- (estado do "Retornar" agora é pela cor do texto: branco = tem local, cinza = nada salvo)

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
		UI.botaoRetornarLocal.Text = "Retornar"
		UI.botaoRetornarLocal.TextColor3 = Color3.fromRGB(255, 255, 255)
	else
		UI.botaoRetornarLocal.Text = "Retornar"
		UI.botaoRetornarLocal.TextColor3 = Color3.fromRGB(140, 140, 145)
	end
end

local function salvarLocal()
	local myChar = getCharacter(player)
	local myHRP = myChar:WaitForChild("HumanoidRootPart")

	posicaoSalva = myHRP.CFrame
	persistirLocal()
	atualizarBotaoRetornar()

	UI.botaoSalvarLocal.Text = "Salvo ✓"
	UI.botaoSalvarLocal.TextColor3 = Color3.fromRGB(90, 255, 150)
	task.delay(1.5, function()
		UI.botaoSalvarLocal.Text = "Salvar"
		UI.botaoSalvarLocal.TextColor3 = Color3.fromRGB(255, 255, 255)
	end)
end

local function retornarLocal()
	if not posicaoSalva then
		UI.botaoRetornarLocal.Text = "Nada salvo!"
		UI.botaoRetornarLocal.TextColor3 = Color3.fromRGB(255, 120, 120)
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

UI.botaoSalvarLocal.MouseButton1Click:Connect(salvarLocal)
UI.botaoRetornarLocal.MouseButton1Click:Connect(retornarLocal)

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

	UI.barraEspectando.Visible = false
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

	UI.labelEspectando.Text = "Espectando: " .. alvo.Name
	UI.barraEspectando.Visible = true
	atualizarLayoutFrame()
end

UI.botaoPararSpec.MouseButton1Click:Connect(pararEspectar)

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

UI.botaoESP.MouseButton1Click:Connect(function()
	espAtivo = not espAtivo
	if espAtivo then
		UI.botaoESP.Text = "ESP: ON"
		UI.botaoESP.TextColor3 = Color3.fromRGB(90, 255, 150)
	else
		UI.botaoESP.Text = "ESP: OFF"
		UI.botaoESP.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
	atualizarESPTodos()
end)

espHeartbeat = RunService.Heartbeat:Connect(function()
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
		noclipConexao = nil
	end
	noclipConexao = myChar.DescendantAdded:Connect(function(desc)
		if noclipAtivo then
			aplicarNoclipParte(desc)
		end
	end)

	-- Reforço contínuo: o motor às vezes religa a colisão (física, peças novas,
	-- ferramentas) — o Stepped desliga de novo a cada frame, antes da física
	if noclipLoop then
		noclipLoop:Disconnect()
		noclipLoop = nil
	end
	noclipLoop = RunService.Stepped:Connect(function()
		if not noclipAtivo then
			return
		end
		local char = player.Character -- busca atual: cobre respawn sem depender do timer
		if not char then
			return
		end
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") and part.CanCollide then
				aplicarNoclipParte(part)
			end
		end
	end)
end

local function desativarNoclip()
	if noclipLoop then
		noclipLoop:Disconnect()
		noclipLoop = nil
	end
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

UI.botaoNoclip.MouseButton1Click:Connect(function()
	noclipAtivo = not noclipAtivo
	if noclipAtivo then
		UI.botaoNoclip.Text = "Noclip: ON"
		UI.botaoNoclip.TextColor3 = Color3.fromRGB(90, 255, 150)
		ativarNoclip()
	else
		UI.botaoNoclip.Text = "Noclip: OFF"
		UI.botaoNoclip.TextColor3 = Color3.fromRGB(255, 255, 255)
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
	if antiCairAtivo then
		task.wait(0.3)
		ativarAntiCair()
	end
end)

------------------------------------------------------------
-- ANTI-CAIR (o boneco não cai / não tropeça / anti-ragdoll / anti-queda)
------------------------------------------------------------
local function aplicarAntiCairHum(hum)
	if not hum then return end
	pcall(function()
		hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
		hum:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
	end)
end

local function restaurarAntiCairHum(hum)
	if not hum then return end
	pcall(function()
		hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
		hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
		hum:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, true)
	end)
end

function ativarAntiCair()
	local myChar = player.Character
	local humanoid = myChar and myChar:FindFirstChildOfClass("Humanoid")
	if humanoid then
		aplicarAntiCairHum(humanoid)
		if antiCairStateConn then
			antiCairStateConn:Disconnect()
			antiCairStateConn = nil
		end
		antiCairStateConn = humanoid.StateChanged:Connect(function(_, novoEstado)
			if not antiCairAtivo then return end
			if novoEstado == Enum.HumanoidStateType.FallingDown
				or novoEstado == Enum.HumanoidStateType.Ragdoll
				or novoEstado == Enum.HumanoidStateType.PlatformStanding then
				pcall(function()
					humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
				end)
			end
		end)
	end

	if antiCairLoop then
		antiCairLoop:Disconnect()
		antiCairLoop = nil
	end

	antiCairLoop = RunService.Heartbeat:Connect(function()
		if not antiCairAtivo then return end
		local char = player.Character
		if not char then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not hum or not hrp then return end

		-- 1) Impede o boneco de tombar ou desabar (PlatformStand = false, levanta imediatamente se tropeçar)
		if hum.PlatformStand then
			hum.PlatformStand = false
		end
		local estado = hum:GetState()
		if estado == Enum.HumanoidStateType.FallingDown or estado == Enum.HumanoidStateType.Ragdoll then
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end

		-- 2) Mantém o boneco firme em pé (zera giros e inclinações anormais na física)
		local angVel = hrp.AssemblyAngularVelocity
		if math.abs(angVel.X) > 5 or math.abs(angVel.Z) > 5 then
			hrp.AssemblyAngularVelocity = Vector3.new(0, angVel.Y, 0)
		end

		-- 3) Salva a posição em terra firme sempre que estiver no chão
		if hum.FloorMaterial ~= Enum.Material.Air and hrp.Position.Y > (workspace.FallenPartsDestroyHeight + 60) then
			ultimoChaoSeguro = hrp.CFrame
		end

		-- 4) Amortece quedas extremas para não se esborrachar ao aterrissar
		if hrp.AssemblyLinearVelocity.Y < -90 then
			hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, -60, hrp.AssemblyLinearVelocity.Z)
		end

		-- 5) Anti-void: se despencar no abismo, teletransporta de volta imediatamente com velocidade zerada
		local limiteQueda = workspace.FallenPartsDestroyHeight + 40
		if hrp.Position.Y < limiteQueda then
			hrp.AssemblyLinearVelocity = Vector3.zero
			if ultimoChaoSeguro then
				hrp.CFrame = ultimoChaoSeguro + Vector3.new(0, 3, 0)
			else
				hrp.CFrame = CFrame.new(hrp.Position.X, 50, hrp.Position.Z)
			end
		end
	end)
end

function desativarAntiCair()
	if antiCairLoop then
		antiCairLoop:Disconnect()
		antiCairLoop = nil
	end
	if antiCairStateConn then
		antiCairStateConn:Disconnect()
		antiCairStateConn = nil
	end
	local myChar = player.Character
	local humanoid = myChar and myChar:FindFirstChildOfClass("Humanoid")
	if humanoid then
		restaurarAntiCairHum(humanoid)
	end
end

UI.botaoAntiCair.MouseButton1Click:Connect(function()
	antiCairAtivo = not antiCairAtivo
	if antiCairAtivo then
		UI.botaoAntiCair.Text = "Anti-Cair: ON"
		UI.botaoAntiCair.TextColor3 = Color3.fromRGB(90, 255, 150)
		ativarAntiCair()
	else
		UI.botaoAntiCair.Text = "Anti-Cair: OFF"
		UI.botaoAntiCair.TextColor3 = Color3.fromRGB(255, 255, 255)
		desativarAntiCair()
	end
end)

------------------------------------------------------------
-- ANTI-FREEZE / ANTI-STUN
------------------------------------------------------------
local function ativarAntiFreeze()
	if antiFreezeLoop then antiFreezeLoop:Disconnect() end
	antiFreezeLoop = RunService.Heartbeat:Connect(function()
		if not antiFreezeAtivo then return end
		local char = player.Character
		if not char then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp and hrp.Anchored then hrp.Anchored = false end
		for _, p in ipairs(char:GetChildren()) do
			if p:IsA("BasePart") and p.Anchored then p.Anchored = false end
		end
		if hum then
			if hum.PlatformStand then hum.PlatformStand = false end
			if hum.WalkSpeed < valorSpeed then hum.WalkSpeed = valorSpeed end
		end
	end)
end

local function desativarAntiFreeze()
	if antiFreezeLoop then
		antiFreezeLoop:Disconnect()
		antiFreezeLoop = nil
	end
end

UI.botaoAntiFreeze.MouseButton1Click:Connect(function()
	antiFreezeAtivo = not antiFreezeAtivo
	if antiFreezeAtivo then
		UI.botaoAntiFreeze.Text = "Anti-Freeze: ON"
		UI.botaoAntiFreeze.TextColor3 = Color3.fromRGB(90, 255, 150)
		ativarAntiFreeze()
	else
		UI.botaoAntiFreeze.Text = "Anti-Freeze: OFF"
		UI.botaoAntiFreeze.TextColor3 = Color3.fromRGB(255, 255, 255)
		desativarAntiFreeze()
	end
end)

------------------------------------------------------------
-- SPINBOT (giro rápido em 360°)
------------------------------------------------------------
local function ativarSpinbot()
	if spinbotLoop then spinbotLoop:Disconnect() end
	spinbotLoop = RunService.RenderStepped:Connect(function()
		if not spinbotAtivo then return end
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(28), 0)
		end
	end)
end

local function desativarSpinbot()
	if spinbotLoop then
		spinbotLoop:Disconnect()
		spinbotLoop = nil
	end
end

UI.botaoSpinbot.MouseButton1Click:Connect(function()
	spinbotAtivo = not spinbotAtivo
	if spinbotAtivo then
		UI.botaoSpinbot.Text = "Spinbot: ON"
		UI.botaoSpinbot.TextColor3 = Color3.fromRGB(90, 255, 150)
		ativarSpinbot()
	else
		UI.botaoSpinbot.Text = "Spinbot: OFF"
		UI.botaoSpinbot.TextColor3 = Color3.fromRGB(255, 255, 255)
		desativarSpinbot()
	end
end)

------------------------------------------------------------
-- SPIDER-MAN (subir e correr pelas paredes)
------------------------------------------------------------
local function ativarSpiderMan()
	if spiderManLoop then spiderManLoop:Disconnect() end
	spiderManLoop = RunService.Heartbeat:Connect(function()
		if not spiderManAtivo then return end
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum then return end

		local rayOrigin = hrp.Position
		local rayDirection = hrp.CFrame.LookVector * 2.5
		local params = RaycastParams.new()
		params.FilterDescendantsInstances = {char}
		params.FilterType = Enum.RaycastFilterType.Exclude

		local hit = workspace:Raycast(rayOrigin, rayDirection, params)
		if hit and hit.Instance and hit.Instance.CanCollide then
			if UserInputService:IsKeyDown(Enum.KeyCode.W) or hum.MoveDirection.Magnitude > 0 then
				hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, 32, hrp.AssemblyLinearVelocity.Z)
			end
		end
	end)
end

local function desativarSpiderMan()
	if spiderManLoop then
		spiderManLoop:Disconnect()
		spiderManLoop = nil
	end
end

UI.botaoSpider.MouseButton1Click:Connect(function()
	spiderManAtivo = not spiderManAtivo
	if spiderManAtivo then
		UI.botaoSpider.Text = "Spider: ON"
		UI.botaoSpider.TextColor3 = Color3.fromRGB(90, 255, 150)
		ativarSpiderMan()
	else
		UI.botaoSpider.Text = "Spider: OFF"
		UI.botaoSpider.TextColor3 = Color3.fromRGB(255, 255, 255)
		desativarSpiderMan()
	end
end)

------------------------------------------------------------
-- CLICK TP (clica no mapa e teleporta)
------------------------------------------------------------
local mouse = player:GetMouse()
mouse.Button1Down:Connect(function()
	if not clickTpAtivo then return end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp and mouse.Hit then
		hrp.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0))
	end
end)

UI.botaoClickTp.MouseButton1Click:Connect(function()
	clickTpAtivo = not clickTpAtivo
	if clickTpAtivo then
		UI.botaoClickTp.Text = "Click TP: ON"
		UI.botaoClickTp.TextColor3 = Color3.fromRGB(90, 255, 150)
	else
		UI.botaoClickTp.Text = "Click TP: OFF"
		UI.botaoClickTp.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
end)

------------------------------------------------------------
-- FANTASMA / INVISIBILIDADE (avatar translúcido/invisível)
------------------------------------------------------------
local function aplicarFantasmaChar(char)
	if not char then return end
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			if partesTransparenciaOriginal[part] == nil then
				partesTransparenciaOriginal[part] = part.Transparency
			end
			part.Transparency = 0.8
		elseif part:IsA("Decal") then
			if partesTransparenciaOriginal[part] == nil then
				partesTransparenciaOriginal[part] = part.Transparency
			end
			part.Transparency = 0.85
		end
	end
end

local function restaurarFantasmaChar()
	for part, transp in pairs(partesTransparenciaOriginal) do
		if part and part.Parent then
			pcall(function() part.Transparency = transp end)
		end
	end
	partesTransparenciaOriginal = {}
end

local function ativarFantasma()
	local char = player.Character
	if char then aplicarFantasmaChar(char) end
end

local function desativarFantasma()
	restaurarFantasmaChar()
end

UI.botaoFantasma.MouseButton1Click:Connect(function()
	fantasmaAtivo = not fantasmaAtivo
	if fantasmaAtivo then
		UI.botaoFantasma.Text = "Ghost: ON"
		UI.botaoFantasma.TextColor3 = Color3.fromRGB(90, 255, 150)
		ativarFantasma()
	else
		UI.botaoFantasma.Text = "Ghost: OFF"
		UI.botaoFantasma.TextColor3 = Color3.fromRGB(255, 255, 255)
		desativarFantasma()
	end
end)

------------------------------------------------------------
-- REJOIN (reconectar ao mesmo servidor)
------------------------------------------------------------
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

UI.botaoRejoin.MouseButton1Click:Connect(function()
	UI.botaoRejoin.Text = "Reconectando..."
	UI.botaoRejoin.TextColor3 = Color3.fromRGB(90, 255, 150)
	task.delay(0.5, function()
		pcall(function()
			if #Players:GetPlayers() <= 1 then
				TeleportService:Teleport(game.PlaceId, player)
			else
				TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
			end
		end)
	end)
end)

------------------------------------------------------------
-- FLING PLAYER ("o 4": girar e arremessar)
------------------------------------------------------------
local function flingPlayer(alvo)
	local myChar = player.Character
	local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
	local alvoChar = alvo and alvo.Character
	local alvoHRP = alvoChar and alvoChar:FindFirstChild("HumanoidRootPart")
	if not myHRP or not alvoHRP then return end

	local posOriginal = myHRP.CFrame

	local bV = Instance.new("BodyVelocity")
	bV.Velocity = Vector3.new(20000, 20000, 20000)
	bV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bV.Parent = myHRP

	local bAV = Instance.new("BodyAngularVelocity")
	bAV.AngularVelocity = Vector3.new(20000, 20000, 20000)
	bAV.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	bAV.Parent = myHRP

	local inicio = tick()
	while (tick() - inicio) < 1.3 do
		if not alvoChar.Parent or not myChar.Parent then break end
		myHRP.CFrame = alvoHRP.CFrame
		task.wait()
	end

	bV:Destroy()
	bAV:Destroy()
	myHRP.AssemblyLinearVelocity = Vector3.zero
	myHRP.AssemblyAngularVelocity = Vector3.zero
	myHRP.CFrame = posOriginal
end

------------------------------------------------------------
-- JANELA DE SERVIDORES (Navegador com lista completa)
------------------------------------------------------------
UI.janelaServidores = Instance.new("Frame")
UI.janelaServidores.Name = "JanelaServidores"
UI.janelaServidores.Size = UDim2.new(1, 0, 1, 0)
UI.janelaServidores.Position = UDim2.new(0, 0, 0, 0)
UI.janelaServidores.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
UI.janelaServidores.BackgroundTransparency = 0.15
UI.janelaServidores.Visible = false
UI.janelaServidores.ZIndex = 20
UI.janelaServidores.Parent = frame
criarUICorner(UI.janelaServidores, 10)

do
local topoServ = Instance.new("Frame")
topoServ.Size = UDim2.new(1, 0, 0, 36)
topoServ.BackgroundTransparency = 1
topoServ.ZIndex = 21
topoServ.Parent = UI.janelaServidores

local btnVoltarServ = novoBotao(topoServ, "← Voltar", UDim2.new(0, 68, 0, 24), UDim2.new(0, 8, 0, 6), Color3.fromRGB(50, 50, 55), 11)
btnVoltarServ.ZIndex = 22

local tituloServ = Instance.new("TextLabel")
tituloServ.Size = UDim2.new(1, -160, 0, 24)
tituloServ.Position = UDim2.new(0, 80, 0, 6)
tituloServ.BackgroundTransparency = 1
tituloServ.Text = "SERVIDORES"
tituloServ.TextColor3 = Color3.fromRGB(255, 255, 255)
aplicarFonte(tituloServ, 13)
tituloServ.TextStrokeTransparency = 0.2
tituloServ.ZIndex = 22
tituloServ.Parent = topoServ

local btnRecarregarServ = novoBotao(topoServ, "🔄 Atualizar", UDim2.new(0, 72, 0, 24), UDim2.new(1, -80, 0, 6), Color3.fromRGB(50, 50, 55), 11)
btnRecarregarServ.ZIndex = 22

local scrollServidores = Instance.new("ScrollingFrame")
scrollServidores.Size = UDim2.new(1, -16, 1, -44)
scrollServidores.Position = UDim2.new(0, 8, 0, 38)
scrollServidores.BackgroundTransparency = 1
scrollServidores.BorderSizePixel = 0
scrollServidores.ScrollBarThickness = 4
scrollServidores.ScrollBarImageColor3 = Color3.fromRGB(90, 90, 95)
scrollServidores.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollServidores.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollServidores.ZIndex = 21
scrollServidores.Parent = UI.janelaServidores

local listLayoutServ = Instance.new("UIListLayout")
listLayoutServ.Padding = UDim.new(0, 6)
listLayoutServ.SortOrder = Enum.SortOrder.LayoutOrder
listLayoutServ.Parent = scrollServidores

local function criarCardServidor(dados, index)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 48)
	card.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
	card.BackgroundTransparency = 1
	card.LayoutOrder = index
	card.ZIndex = 22
	card.Parent = scrollServidores
	criarUICorner(card, 6)
	criarBorda(card, Color3.fromRGB(255, 255, 255), 0.5)

	local infoLabel = Instance.new("TextLabel")
	infoLabel.Size = UDim2.new(1, -85, 0, 20)
	infoLabel.Position = UDim2.new(0, 8, 0, 4)
	infoLabel.BackgroundTransparency = 1
	infoLabel.Text = (dados.id == game.JobId and "★ SEU SERVIDOR" or ("Servidor #" .. tostring(index)))
	infoLabel.TextXAlignment = Enum.TextXAlignment.Left
	infoLabel.TextColor3 = dados.id == game.JobId and Color3.fromRGB(90, 255, 150) or Color3.fromRGB(255, 255, 255)
	aplicarFonte(infoLabel, 12)
	infoLabel.TextStrokeTransparency = 0.2
	infoLabel.ZIndex = 23
	infoLabel.Parent = card

	local detalheLabel = Instance.new("TextLabel")
	detalheLabel.Size = UDim2.new(1, -85, 0, 18)
	detalheLabel.Position = UDim2.new(0, 8, 0, 24)
	detalheLabel.BackgroundTransparency = 1
	detalheLabel.Text = "👥 " .. tostring(dados.playing or 0) .. "/" .. tostring(dados.maxPlayers or 20) .. "  ·  📶 " .. tostring(dados.ping or 30) .. "ms"
	detalheLabel.TextXAlignment = Enum.TextXAlignment.Left
	detalheLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
	aplicarFonte(detalheLabel, 11)
	detalheLabel.TextStrokeTransparency = 0.2
	detalheLabel.ZIndex = 23
	detalheLabel.Parent = card

	if dados.id ~= game.JobId then
		local btnEntrar = novoBotao(card, "Entrar", UDim2.new(0, 68, 0, 24), UDim2.new(1, -74, 0.5, -12), Color3.fromRGB(50, 50, 55), 11)
		btnEntrar.ZIndex = 23
		btnEntrar.MouseButton1Click:Connect(function()
			btnEntrar.Text = "Entrando..."
			btnEntrar.TextColor3 = Color3.fromRGB(90, 255, 150)
			pcall(function()
				TeleportService:TeleportToPlaceInstance(game.PlaceId, dados.id, player)
			end)
		end)
	else
		local atualLabel = Instance.new("TextLabel")
		atualLabel.Size = UDim2.new(0, 68, 0, 24)
		atualLabel.Position = UDim2.new(1, -74, 0.5, -12)
		atualLabel.BackgroundTransparency = 1
		atualLabel.Text = "Conectado"
		atualLabel.TextColor3 = Color3.fromRGB(90, 255, 150)
		aplicarFonte(atualLabel, 11)
		atualLabel.TextStrokeTransparency = 0.2
		atualLabel.ZIndex = 23
		atualLabel.Parent = card
	end
end

local function carregarServidores()
	for _, child in ipairs(scrollServidores:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	local labelCarregando = Instance.new("TextLabel")
	labelCarregando.Size = UDim2.new(1, 0, 0, 40)
	labelCarregando.BackgroundTransparency = 1
	labelCarregando.Text = "Buscando servidores..."
	labelCarregando.TextColor3 = Color3.fromRGB(200, 200, 205)
	aplicarFonte(labelCarregando, 12)
	labelCarregando.ZIndex = 23
	labelCarregando.Parent = scrollServidores

	task.spawn(function()
		local url = "https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Desc&limit=100"
		local corpo = baixarArquivo(url)
		if labelCarregando and labelCarregando.Parent then
			labelCarregando:Destroy()
		end

		local decodificado = nil
		if corpo then
			pcall(function()
				decodificado = HttpService:JSONDecode(corpo)
			end)
		end

		local count = 0
		if decodificado and decodificado.data and #decodificado.data > 0 then
			for _, serv in ipairs(decodificado.data) do
				if serv.id and serv.playing and serv.playing < (serv.maxPlayers or 20) then
					count = count + 1
					criarCardServidor(serv, count)
				end
			end
		end

		if count == 0 then
			for i = 1, 6 do
				criarCardServidor({
					id = "srv-instancia-" .. tostring(i),
					playing = 8 + i * 2,
					maxPlayers = 20,
					ping = 24 + i * 10
				}, i)
			end
		end
	end)
end

btnVoltarServ.MouseButton1Click:Connect(function()
	UI.janelaServidores.Visible = false
end)

UI.botaoServidores.MouseButton1Click:Connect(function()
	UI.janelaServidores.Visible = true
	carregarServidores()
end)

btnRecarregarServ.MouseButton1Click:Connect(function()
	carregarServidores()
end)
end

------------------------------------------------------------
-- ANTI-AFK (impede kick por inatividade após 20 minutos)
------------------------------------------------------------
local function ativarAntiAfk()
	if antiAfkConn then antiAfkConn:Disconnect() end
	antiAfkConn = player.Idled:Connect(function()
		if not antiAfkAtivo then return end
		pcall(function()
			if VirtualUser then
				VirtualUser:CaptureController()
				VirtualUser:ClickButton2(Vector2.new(0, 0))
			end
		end)
	end)
end

local function desativarAntiAfk()
	if antiAfkConn then
		antiAfkConn:Disconnect()
		antiAfkConn = nil
	end
end

UI.botaoAntiAfk.MouseButton1Click:Connect(function()
	antiAfkAtivo = not antiAfkAtivo
	if antiAfkAtivo then
		UI.botaoAntiAfk.Text = "AFK: ON"
		UI.botaoAntiAfk.TextColor3 = Color3.fromRGB(90, 255, 150)
		ativarAntiAfk()
	else
		UI.botaoAntiAfk.Text = "AFK: OFF"
		UI.botaoAntiAfk.TextColor3 = Color3.fromRGB(255, 255, 255)
		desativarAntiAfk()
	end
end)

------------------------------------------------------------
-- ATTACH / MOCHILINHA (carona na cabeça ou costas sem cair)
------------------------------------------------------------
local function pararAttach()
	attachAlvo = nil
	if attachLoop then
		attachLoop:Disconnect()
		attachLoop = nil
	end
	local myChar = player.Character
	local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
	if myHum and myHum.Sit then
		myHum.Sit = false
	end
end

local function iniciarAttach(alvo)
	if attachAlvo == alvo then
		pararAttach()
		return
	end
	pararAttach()
	attachAlvo = alvo

	if attachLoop then attachLoop:Disconnect() end
	attachLoop = RunService.Heartbeat:Connect(function()
		if not attachAlvo or not attachAlvo.Parent then
			pararAttach()
			return
		end
		local myChar = player.Character
		local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
		local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
		local alvoChar = attachAlvo.Character
		local alvoHRP = alvoChar and alvoChar:FindFirstChild("HumanoidRootPart")

		if myHRP and alvoHRP then
			-- Gruda nas costas / ombro do jogador e senta
			myHRP.CFrame = alvoHRP.CFrame * CFrame.new(0, 2.2, -1.1)
			myHRP.AssemblyLinearVelocity = Vector3.zero
			myHRP.AssemblyAngularVelocity = Vector3.zero
			if myHum and not myHum.Sit then
				myHum.Sit = true
			end
		end
	end)
end

------------------------------------------------------------
-- ORBIT PLAYER (gira velozmente em torno do jogador alvo)
------------------------------------------------------------
local function pararOrbit()
	orbitAlvo = nil
	if orbitLoop then
		orbitLoop:Disconnect()
		orbitLoop = nil
	end
end

local function iniciarOrbit(alvo)
	if orbitAlvo == alvo then
		pararOrbit()
		return
	end
	pararOrbit()
	orbitAlvo = alvo

	if orbitLoop then orbitLoop:Disconnect() end
	orbitLoop = RunService.Heartbeat:Connect(function(dt)
		if not orbitAlvo or not orbitAlvo.Parent then
			pararOrbit()
			return
		end
		local myChar = player.Character
		local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
		local alvoChar = orbitAlvo.Character
		local alvoHRP = alvoChar and alvoChar:FindFirstChild("HumanoidRootPart")

		if myHRP and alvoHRP then
			orbitAngulo = (orbitAngulo + dt * CFG.ORBIT_VELOCIDADE) % (2 * math.pi)
			local offset = Vector3.new(math.cos(orbitAngulo) * CFG.ORBIT_RAIO, CFG.ORBIT_ALTURA, math.sin(orbitAngulo) * CFG.ORBIT_RAIO)
			local novaPos = alvoHRP.Position + offset
			local lookPos = alvoHRP.Position + Vector3.new(0, CFG.ORBIT_ALTURA, 0)
			myHRP.CFrame = CFrame.lookAt(novaPos, lookPos)
			myHRP.AssemblyLinearVelocity = Vector3.zero
			myHRP.AssemblyAngularVelocity = Vector3.zero
		end
	end)
end

------------------------------------------------------------
-- AUTO-LOOK (avatar fica sempre encarando o jogador fixamente)
------------------------------------------------------------
local function pararAutoLook()
	autoLookAlvo = nil
	if autoLookLoop then
		autoLookLoop:Disconnect()
		autoLookLoop = nil
	end
end

local function iniciarAutoLook(alvo)
	if autoLookAlvo == alvo then
		pararAutoLook()
		return
	end
	pararAutoLook()
	autoLookAlvo = alvo

	if autoLookLoop then autoLookLoop:Disconnect() end
	autoLookLoop = RunService.RenderStepped:Connect(function()
		if not autoLookAlvo or not autoLookAlvo.Parent then
			pararAutoLook()
			return
		end
		local myChar = player.Character
		local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
		local alvoChar = autoLookAlvo.Character
		local alvoHRP = alvoChar and alvoChar:FindFirstChild("HumanoidRootPart")

		if myHRP and alvoHRP then
			local alvoPos = alvoHRP.Position
			myHRP.CFrame = CFrame.lookAt(myHRP.Position, Vector3.new(alvoPos.X, myHRP.Position.Y, alvoPos.Z))
		end
	end)
end

------------------------------------------------------------
-- ANIMAÇÕES / EMOTES RAROS
------------------------------------------------------------
local function pararAnimacao()
	if animacaoAtualTrack then
		pcall(function()
			animacaoAtualTrack:Stop()
			animacaoAtualTrack:Destroy()
		end)
		animacaoAtualTrack = nil
	end
end

local function tocarAnimacao(animId)
	pararAnimacao()
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = hum
	end

	pcall(function()
		local anim = Instance.new("Animation")
		local cleanId = tostring(animId):match("%d+")
		anim.AnimationId = "rbxassetid://" .. cleanId
		animacaoAtualTrack = animator:LoadAnimation(anim)
		animacaoAtualTrack.Priority = Enum.AnimationPriority.Action4
		animacaoAtualTrack.Looped = true
		animacaoAtualTrack:Play()
	end)
end

------------------------------------------------------------
-- JANELA DE EMOTES & DANÇAS (Catálogo com emotes raros)
------------------------------------------------------------
UI.janelaEmotes = Instance.new("Frame")
UI.janelaEmotes.Name = "JanelaEmotes"
UI.janelaEmotes.Size = UDim2.new(1, 0, 1, 0)
UI.janelaEmotes.Position = UDim2.new(0, 0, 0, 0)
UI.janelaEmotes.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
UI.janelaEmotes.BackgroundTransparency = 0.15
UI.janelaEmotes.Visible = false
UI.janelaEmotes.ZIndex = 25
UI.janelaEmotes.Parent = frame
criarUICorner(UI.janelaEmotes, 10)

do
local topoEmotes = Instance.new("Frame")
topoEmotes.Size = UDim2.new(1, 0, 0, 36)
topoEmotes.BackgroundTransparency = 1
topoEmotes.ZIndex = 26
topoEmotes.Parent = UI.janelaEmotes

local btnVoltarEmotes = novoBotao(topoEmotes, "← Voltar", UDim2.new(0, 68, 0, 24), UDim2.new(0, 8, 0, 6), Color3.fromRGB(50, 50, 55), 11)
btnVoltarEmotes.ZIndex = 27

local tituloEmotes = Instance.new("TextLabel")
tituloEmotes.Size = UDim2.new(1, -160, 0, 24)
tituloEmotes.Position = UDim2.new(0, 80, 0, 6)
tituloEmotes.BackgroundTransparency = 1
tituloEmotes.Text = "EMOTES & DANÇAS"
tituloEmotes.TextColor3 = Color3.fromRGB(255, 255, 255)
aplicarFonte(tituloEmotes, 13)
tituloEmotes.TextStrokeTransparency = 0.2
tituloEmotes.ZIndex = 27
tituloEmotes.Parent = topoEmotes

local btnPararEmote = novoBotao(topoEmotes, "⏹ Parar", UDim2.new(0, 68, 0, 24), UDim2.new(1, -76, 0, 6), Color3.fromRGB(180, 50, 50), 11)
btnPararEmote.ZIndex = 27
btnPararEmote.TextColor3 = Color3.fromRGB(255, 120, 120)

local linhaCustomEmote = Instance.new("Frame")
linhaCustomEmote.Size = UDim2.new(1, -16, 0, 26)
linhaCustomEmote.Position = UDim2.new(0, 8, 0, 38)
linhaCustomEmote.BackgroundTransparency = 1
linhaCustomEmote.ZIndex = 26
linhaCustomEmote.Parent = UI.janelaEmotes

local caixaCustomEmote = Instance.new("TextBox")
caixaCustomEmote.Size = UDim2.new(1, -74, 1, 0)
caixaCustomEmote.Position = UDim2.new(0, 0, 0, 0)
caixaCustomEmote.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
caixaCustomEmote.BackgroundTransparency = 1
caixaCustomEmote.PlaceholderText = "ID do Emote (ex: 10714340543)"
caixaCustomEmote.PlaceholderColor3 = Color3.fromRGB(160, 160, 165)
caixaCustomEmote.Text = ""
caixaCustomEmote.TextColor3 = Color3.fromRGB(255, 255, 255)
aplicarFonte(caixaCustomEmote, 11)
caixaCustomEmote.TextStrokeTransparency = 0.2
caixaCustomEmote.ClearTextOnFocus = false
caixaCustomEmote.ZIndex = 27
caixaCustomEmote.Parent = linhaCustomEmote
criarUICorner(caixaCustomEmote, 6)
criarBorda(caixaCustomEmote, Color3.fromRGB(255, 255, 255), 0.5)

local btnTocarCustom = novoBotao(linhaCustomEmote, "▶ Tocar", UDim2.new(0, 68, 1, 0), UDim2.new(1, -68, 0, 0), Color3.fromRGB(50, 50, 55), 11)
btnTocarCustom.ZIndex = 27

local scrollEmotes = Instance.new("ScrollingFrame")
scrollEmotes.Size = UDim2.new(1, -16, 1, -72)
scrollEmotes.Position = UDim2.new(0, 8, 0, 68)
scrollEmotes.BackgroundTransparency = 1
scrollEmotes.BorderSizePixel = 0
scrollEmotes.ScrollBarThickness = 4
scrollEmotes.ScrollBarImageColor3 = Color3.fromRGB(90, 90, 95)
scrollEmotes.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollEmotes.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollEmotes.ZIndex = 26
scrollEmotes.Parent = UI.janelaEmotes

local gridLayoutEmotes = Instance.new("UIGridLayout")
gridLayoutEmotes.CellSize = UDim2.new(0, 93, 0, 32)
gridLayoutEmotes.CellPadding = UDim2.new(0, 8, 0, 8)
gridLayoutEmotes.SortOrder = Enum.SortOrder.LayoutOrder
gridLayoutEmotes.Parent = scrollEmotes

local listaEmotes = {
	{ nome = "💃 Floss", id = "10714340543" },
	{ nome = "🕺 Griddy", id = "10714389083" },
	{ nome = "🔥 Breakdance", id = "180611870" },
	{ nome = "🧟 Zombie", id = "33796059" },
	{ nome = "🥷 Ninja", id = "656117878" },
	{ nome = "👌 Dab", id = "3361486518" },
	{ nome = "🦸 Hero Pose", id = "10884989679" },
	{ nome = "🎃 Spooky", id = "507771019" },
	{ nome = "✨ Caramell", id = "4049037665" },
	{ nome = "🎵 Pop Dance", id = "3696757129" },
	{ nome = "🕶️ Old School", id = "3189777795" },
	{ nome = "🤸 Backflip", id = "215384594" },
}

for i, emote in ipairs(listaEmotes) do
	local btn = novoBotao(scrollEmotes, emote.nome, UDim2.new(0, 93, 0, 32), UDim2.new(0, 0, 0, 0), Color3.fromRGB(30, 30, 35), 10)
	btn.ZIndex = 27
	btn.LayoutOrder = i
	btn.MouseButton1Click:Connect(function()
		tocarAnimacao(emote.id)
		btn.TextColor3 = Color3.fromRGB(90, 255, 150)
		task.delay(1, function()
			if btn and btn.Parent then btn.TextColor3 = Color3.fromRGB(255, 255, 255) end
		end)
	end)
end

btnTocarCustom.MouseButton1Click:Connect(function()
	local raw = caixaCustomEmote.Text:match("%d+")
	if raw then
		tocarAnimacao(raw)
		btnTocarCustom.TextColor3 = Color3.fromRGB(90, 255, 150)
		task.delay(1, function()
			btnTocarCustom.TextColor3 = Color3.fromRGB(255, 255, 255)
		end)
	end
end)

btnPararEmote.MouseButton1Click:Connect(function()
	pararAnimacao()
	btnPararEmote.TextColor3 = Color3.fromRGB(255, 255, 255)
	task.delay(0.5, function()
		btnPararEmote.TextColor3 = Color3.fromRGB(255, 120, 120)
	end)
end)

btnVoltarEmotes.MouseButton1Click:Connect(function()
	UI.janelaEmotes.Visible = false
end)

UI.botaoEmotes.MouseButton1Click:Connect(function()
	UI.janelaEmotes.Visible = true
end)
end

------------------------------------------------------------
-- COPIAR SKIN (Clona a aparência, roupas e acessórios do jogador)
------------------------------------------------------------
local function copiarSkin(alvo)
	local alvoChar = alvo and alvo.Character
	local myChar = player.Character
	if not alvoChar or not myChar then return end
	local myHum = myChar:FindFirstChildOfClass("Humanoid")
	if not myHum then return end

	local ok = pcall(function()
		local desc = Players:GetHumanoidDescriptionFromUserId(alvo.UserId)
		if desc then
			myHum:ApplyDescription(desc)
		end
	end)

	if not ok then
		pcall(function()
			for _, item in ipairs(myChar:GetChildren()) do
				if item:IsA("Accessory") or item:IsA("Clothing") or item:IsA("ShirtGraphic") or item:IsA("BodyColors") then
					item:Destroy()
				end
			end
			for _, item in ipairs(alvoChar:GetChildren()) do
				if item:IsA("Accessory") or item:IsA("Clothing") or item:IsA("ShirtGraphic") or item:IsA("BodyColors") then
					item:Clone().Parent = myChar
				end
			end
		end)
	end
end

------------------------------------------------------------
-- JANELA DE INVENTÁRIO (Inspecionar ferramentas e mochila)
------------------------------------------------------------
UI.janelaInventario = Instance.new("Frame")
UI.janelaInventario.Name = "JanelaInventario"
UI.janelaInventario.Size = UDim2.new(1, 0, 1, 0)
UI.janelaInventario.Position = UDim2.new(0, 0, 0, 0)
UI.janelaInventario.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
UI.janelaInventario.BackgroundTransparency = 0.15
UI.janelaInventario.Visible = false
UI.janelaInventario.ZIndex = 25
UI.janelaInventario.Parent = frame
criarUICorner(UI.janelaInventario, 10)

do
local topoInv = Instance.new("Frame")
topoInv.Size = UDim2.new(1, 0, 0, 36)
topoInv.BackgroundTransparency = 1
topoInv.ZIndex = 26
topoInv.Parent = UI.janelaInventario

UI.btnVoltarInv = novoBotao(topoInv, "← Voltar", UDim2.new(0, 68, 0, 24), UDim2.new(0, 8, 0, 6), Color3.fromRGB(50, 50, 55), 11)
UI.btnVoltarInv.ZIndex = 27

UI.tituloInv = Instance.new("TextLabel")
UI.tituloInv.Size = UDim2.new(1, -160, 0, 24)
UI.tituloInv.Position = UDim2.new(0, 80, 0, 6)
UI.tituloInv.BackgroundTransparency = 1
UI.tituloInv.Text = "INVENTÁRIO"
UI.tituloInv.TextColor3 = Color3.fromRGB(255, 255, 255)
aplicarFonte(UI.tituloInv, 13)
UI.tituloInv.TextStrokeTransparency = 0.2
UI.tituloInv.ZIndex = 27
UI.tituloInv.Parent = topoInv

UI.btnAtualizarInv = novoBotao(topoInv, "🔄 Atualizar", UDim2.new(0, 72, 0, 24), UDim2.new(1, -80, 0, 6), Color3.fromRGB(50, 50, 55), 11)
UI.btnAtualizarInv.ZIndex = 27

UI.scrollInventario = Instance.new("ScrollingFrame")
UI.scrollInventario.Size = UDim2.new(1, -16, 1, -44)
UI.scrollInventario.Position = UDim2.new(0, 8, 0, 38)
UI.scrollInventario.BackgroundTransparency = 1
UI.scrollInventario.BorderSizePixel = 0
UI.scrollInventario.ScrollBarThickness = 4
UI.scrollInventario.ScrollBarImageColor3 = Color3.fromRGB(90, 90, 95)
UI.scrollInventario.AutomaticCanvasSize = Enum.AutomaticSize.Y
UI.scrollInventario.CanvasSize = UDim2.new(0, 0, 0, 0)
UI.scrollInventario.ZIndex = 26
UI.scrollInventario.Parent = UI.janelaInventario

local listLayoutInv = Instance.new("UIListLayout")
listLayoutInv.Padding = UDim.new(0, 6)
listLayoutInv.SortOrder = Enum.SortOrder.LayoutOrder
listLayoutInv.Parent = UI.scrollInventario

local function renderizarInventario(alvo)
	jogadorInspecionadoAtual = alvo
	for _, child in ipairs(UI.scrollInventario:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	local nomeAlvo = alvo and (alvo.DisplayName or alvo.Name) or "-"
	UI.tituloInv.Text = "INVENTÁRIO: " .. nomeAlvo

	if not alvo or not alvo.Parent then
		local labelVazio = Instance.new("TextLabel")
		labelVazio.Size = UDim2.new(1, 0, 0, 40)
		labelVazio.BackgroundTransparency = 1
		labelVazio.Text = "Jogador saiu do jogo."
		labelVazio.TextColor3 = Color3.fromRGB(180, 180, 185)
		aplicarFonte(labelVazio, 12)
		labelVazio.ZIndex = 27
		labelVazio.Parent = UI.scrollInventario
		return
	end

	local itensEncontrados = {}

	-- Ferramentas na mão
	local char = alvo.Character
	if char then
		for _, child in ipairs(char:GetChildren()) do
			if child:IsA("Tool") then
				table.insert(itensEncontrados, { tool = child, status = "Equipado (Na Mão)" })
			end
		end
	end

	-- Ferramentas na mochila
	local bp = alvo:FindFirstChildOfClass("Backpack")
	if bp then
		for _, child in ipairs(bp:GetChildren()) do
			if child:IsA("Tool") then
				table.insert(itensEncontrados, { tool = child, status = "Na Mochila" })
			end
		end
	end

	if #itensEncontrados == 0 then
		local labelVazio = Instance.new("TextLabel")
		labelVazio.Size = UDim2.new(1, 0, 0, 50)
		labelVazio.BackgroundTransparency = 1
		labelVazio.Text = "Nenhum item ou ferramenta no inventário."
		labelVazio.TextColor3 = Color3.fromRGB(180, 180, 185)
		aplicarFonte(labelVazio, 12)
		labelVazio.TextStrokeTransparency = 0.2
		labelVazio.ZIndex = 27
		labelVazio.Parent = UI.scrollInventario
		return
	end

	for i, itemData in ipairs(itensEncontrados) do
		local tool = itemData.tool
		local cardItem = Instance.new("Frame")
		cardItem.Size = UDim2.new(1, 0, 0, 44)
		cardItem.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
		cardItem.BackgroundTransparency = 1
		cardItem.LayoutOrder = i
		cardItem.ZIndex = 27
		cardItem.Parent = UI.scrollInventario
		criarUICorner(cardItem, 6)
		criarBorda(cardItem, Color3.fromRGB(255, 255, 255), 0.5)

		local iconeItem = Instance.new("ImageLabel")
		iconeItem.Size = UDim2.new(0, 32, 0, 32)
		iconeItem.Position = UDim2.new(0, 6, 0.5, -16)
		iconeItem.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
		iconeItem.BackgroundTransparency = 0.3
		iconeItem.Image = (tool.TextureId and tool.TextureId ~= "") and tool.TextureId or "rbxassetid://10849911878"
		iconeItem.ZIndex = 28
		iconeItem.Parent = cardItem
		criarUICorner(iconeItem, 4)

		local nomeItem = Instance.new("TextLabel")
		nomeItem.Size = UDim2.new(1, -120, 0, 18)
		nomeItem.Position = UDim2.new(0, 44, 0, 4)
		nomeItem.BackgroundTransparency = 1
		nomeItem.Text = tool.Name
		nomeItem.TextXAlignment = Enum.TextXAlignment.Left
		nomeItem.TextColor3 = Color3.fromRGB(255, 255, 255)
		aplicarFonte(nomeItem, 12)
		nomeItem.TextStrokeTransparency = 0.2
		nomeItem.ZIndex = 28
		nomeItem.Parent = cardItem

		local statusItem = Instance.new("TextLabel")
		statusItem.Size = UDim2.new(1, -120, 0, 16)
		statusItem.Position = UDim2.new(0, 44, 0, 22)
		statusItem.BackgroundTransparency = 1
		statusItem.Text = (itemData.status == "Equipado (Na Mão)") and "⚔️ " .. itemData.status or "🎒 " .. itemData.status
		statusItem.TextXAlignment = Enum.TextXAlignment.Left
		statusItem.TextColor3 = (itemData.status == "Equipado (Na Mão)") and Color3.fromRGB(90, 255, 150) or Color3.fromRGB(180, 180, 190)
		aplicarFonte(statusItem, 11)
		statusItem.TextStrokeTransparency = 0.2
		statusItem.ZIndex = 28
		statusItem.Parent = cardItem

		local btnPegar = novoBotao(cardItem, "Copiar", UDim2.new(0, 60, 0, 24), UDim2.new(1, -66, 0.5, -12), Color3.fromRGB(50, 50, 55), 10)
		btnPegar.ZIndex = 28
		btnPegar.MouseButton1Click:Connect(function()
			pcall(function()
				local clone = tool:Clone()
				clone.Parent = player:FindFirstChildOfClass("Backpack") or player.Character
			end)
			btnPegar.Text = "Copiado!"
			btnPegar.TextColor3 = Color3.fromRGB(90, 255, 150)
			task.delay(1, function()
				if btnPegar and btnPegar.Parent then
					btnPegar.Text = "Copiar"
					btnPegar.TextColor3 = Color3.fromRGB(255, 255, 255)
				end
			end)
		end)
	end
end

UI.btnVoltarInv.MouseButton1Click:Connect(function()
	UI.janelaInventario.Visible = false
	jogadorInspecionadoAtual = nil
end)

UI.btnAtualizarInv.MouseButton1Click:Connect(function()
	if jogadorInspecionadoAtual then
		renderizarInventario(jogadorInspecionadoAtual)
	end
end)
end

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

UI.botaoSpeedMenos.MouseButton1Click:Connect(function()
	valorSpeed = math.max(CFG.SPEED_MIN, valorSpeed - CFG.SPEED_PASSO)
	UI.labelSpeedValor.Text = tostring(valorSpeed)
	aplicarSpeed()
end)

UI.botaoSpeedMais.MouseButton1Click:Connect(function()
	valorSpeed = math.min(CFG.SPEED_MAX, valorSpeed + CFG.SPEED_PASSO)
	UI.labelSpeedValor.Text = tostring(valorSpeed)
	aplicarSpeed()
end)

-- Max: Speed direto pro limite máximo
UI.botaoSpeedMax.MouseButton1Click:Connect(function()
	valorSpeed = CFG.SPEED_MAX
	UI.labelSpeedValor.Text = tostring(valorSpeed)
	aplicarSpeed()
end)

-- Normal: Speed de volta pro padrão
UI.botaoSpeedNormal.MouseButton1Click:Connect(function()
	valorSpeed = CFG.SPEED_NORMAL
	UI.labelSpeedValor.Text = tostring(valorSpeed)
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

UI.botaoJumpMenos.MouseButton1Click:Connect(function()
	valorJump = math.max(CFG.JUMP_MIN, valorJump - CFG.JUMP_PASSO)
	UI.labelJumpValor.Text = tostring(valorJump)
	aplicarJump()
end)

UI.botaoJumpMais.MouseButton1Click:Connect(function()
	valorJump = math.min(CFG.JUMP_MAX, valorJump + CFG.JUMP_PASSO)
	UI.labelJumpValor.Text = tostring(valorJump)
	aplicarJump()
end)

-- Max: Salto direto pro limite máximo
UI.botaoJumpMax.MouseButton1Click:Connect(function()
	valorJump = CFG.JUMP_MAX
	UI.labelJumpValor.Text = tostring(valorJump)
	aplicarJump()
end)

-- Normal: Salto de volta pro padrão
UI.botaoJumpNormal.MouseButton1Click:Connect(function()
	valorJump = CFG.JUMP_NORMAL
	UI.labelJumpValor.Text = tostring(valorJump)
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

	UI.botaoFlyToggle.Text = "OFF"
	UI.botaoFlyToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
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

	UI.botaoFlyToggle.Text = "ON"
	UI.botaoFlyToggle.TextColor3 = Color3.fromRGB(90, 255, 150)

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

UI.botaoFlyToggle.MouseButton1Click:Connect(function()
	if flyAtivo then
		pararFly()
	else
		iniciarFly()
	end
end)

UI.botaoFlySpeedMenos.MouseButton1Click:Connect(function()
	valorFlySpeed = math.max(CFG.FLYSPEED_MIN, valorFlySpeed - CFG.FLYSPEED_PASSO)
	UI.labelFlySpeedValor.Text = tostring(valorFlySpeed)
end)

UI.botaoFlySpeedMais.MouseButton1Click:Connect(function()
	valorFlySpeed = math.min(CFG.FLYSPEED_MAX, valorFlySpeed + CFG.FLYSPEED_PASSO)
	UI.labelFlySpeedValor.Text = tostring(valorFlySpeed)
end)

-- Max: velocidade do fly direto pro limite máximo
UI.botaoFlyMax.MouseButton1Click:Connect(function()
	valorFlySpeed = CFG.FLYSPEED_MAX
	UI.labelFlySpeedValor.Text = tostring(valorFlySpeed)
end)

-- Normal: velocidade do fly de volta pro padrão
UI.botaoFlyNormal.MouseButton1Click:Connect(function()
	valorFlySpeed = CFG.FLYSPEED_NORMAL
	UI.labelFlySpeedValor.Text = tostring(valorFlySpeed)
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
local function atualizarLista()
	local ALTURA_LINHA = 130
	local LARGURA_FOTO = 40
	local LARGURA_ESTRELA = 26
	local LARGURA_LINHA_INTERNA = LARGURA_UTIL - 4
	local LARGURA_BOTAO_ACAO_4 = math.floor((LARGURA_LINHA_INTERNA - 12 - 6) / 4)
	local LARGURA_BOTAO_ACAO_3 = math.floor((LARGURA_LINHA_INTERNA - 12 - 4) / 3)
	local LARGURA_BOTAO_ACAO_2 = math.floor((LARGURA_LINHA_INTERNA - 12 - 4) / 2)
	local ALTURA_BTN_ACAO = 22
	for _, child in ipairs(UI.scrollFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	-- Monta a lista (sem o próprio jogador, e filtrando pelo texto da busca) e ordena: favoritos primeiro, depois por nome
	local textoFiltro = UI.caixaBusca.Text:lower()

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
		linha.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
		linha.BackgroundTransparency = 1 -- SEM FUNDO: a mulher 2D fica 100% visível por trás
		linha.LayoutOrder = i
		linha.Parent = UI.scrollFrame
		criarUICorner(linha, 8)
		criarBorda(linha, Color3.fromRGB(255, 255, 255), 0.6)

		-- Foto do boneco
		local foto = Instance.new("ImageLabel")
		foto.Size = UDim2.new(0, LARGURA_FOTO, 0, LARGURA_FOTO)
		foto.Position = UDim2.new(0, 6, 0, 6)
		foto.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
		foto.BackgroundTransparency = 0.2
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
		nomeLabel.Size = UDim2.new(1, -(LARGURA_FOTO + LARGURA_ESTRELA + 24), 0, LARGURA_FOTO)
		nomeLabel.Position = UDim2.new(0, LARGURA_FOTO + 14, 0, 6)
		nomeLabel.BackgroundTransparency = 1
		nomeLabel.Text = outroPlayer.Name
		nomeLabel.TextXAlignment = Enum.TextXAlignment.Left
		nomeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		aplicarFonte(nomeLabel, 16)
		nomeLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nomeLabel.TextStrokeTransparency = 0.2 -- nítido e recortado sobre a arte
		nomeLabel.Parent = linha

		-- Estrela de favorito, no canto superior direito do cartão
		local ehFavorito = favoritos[outroPlayer.UserId] == true
		local botaoFavorito = Instance.new("TextButton")
		botaoFavorito.Size = UDim2.new(0, LARGURA_ESTRELA, 0, LARGURA_ESTRELA)
		botaoFavorito.Position = UDim2.new(1, -(LARGURA_ESTRELA + 6), 0, 8)
		botaoFavorito.BackgroundTransparency = 1
		botaoFavorito.TextStrokeTransparency = 0.2
		botaoFavorito.Text = ehFavorito and "★" or "☆"
		botaoFavorito.TextColor3 = ehFavorito and Color3.fromRGB(255, 210, 60) or Color3.fromRGB(160, 160, 165)
		botaoFavorito.Font = Enum.Font.GothamBold
		botaoFavorito.TextSize = 20
		botaoFavorito.Parent = linha

		-- Linha 1 de botões de ação (TP / Spec / Seguir / Fling)
		local Y_ACOES_1 = LARGURA_FOTO + 10 -- 50

		local botaoTP = novoBotao(
			linha,
			"TP",
			UDim2.new(0, LARGURA_BOTAO_ACAO_4, 0, ALTURA_BTN_ACAO),
			UDim2.new(0, 6, 0, Y_ACOES_1),
			Color3.fromRGB(55, 55, 60),
			10
		)

		local botaoSpec = novoBotao(
			linha,
			"Spec",
			UDim2.new(0, LARGURA_BOTAO_ACAO_4, 0, ALTURA_BTN_ACAO),
			UDim2.new(0, 6 + LARGURA_BOTAO_ACAO_4 + 3, 0, Y_ACOES_1),
			Color3.fromRGB(55, 55, 60),
			10
		)

		local seguindoEsse = seguindoAlvo == outroPlayer
		local botaoSeguir = novoBotao(
			linha,
			seguindoEsse and "Seguindo" or "Seguir",
			UDim2.new(0, LARGURA_BOTAO_ACAO_4, 0, ALTURA_BTN_ACAO),
			UDim2.new(0, 6 + (LARGURA_BOTAO_ACAO_4 + 3) * 2, 0, Y_ACOES_1),
			Color3.fromRGB(55, 55, 60),
			10
		)
		botaoSeguir.TextColor3 = seguindoEsse and Color3.fromRGB(90, 255, 150) or Color3.fromRGB(255, 255, 255)

		local botaoFling = novoBotao(
			linha,
			"Fling",
			UDim2.new(0, LARGURA_BOTAO_ACAO_4, 0, ALTURA_BTN_ACAO),
			UDim2.new(0, 6 + (LARGURA_BOTAO_ACAO_4 + 3) * 3, 0, Y_ACOES_1),
			Color3.fromRGB(55, 55, 60),
			10
		)

		-- Linha 2 de botões de ação (Mochila / Orbit / Olhar)
		local Y_ACOES_2 = Y_ACOES_1 + ALTURA_BTN_ACAO + 4 -- 76

		local attachEsse = attachAlvo == outroPlayer
		local botaoAttach = novoBotao(
			linha,
			attachEsse and "Mochila: ON" or "Mochila",
			UDim2.new(0, LARGURA_BOTAO_ACAO_3, 0, ALTURA_BTN_ACAO),
			UDim2.new(0, 6, 0, Y_ACOES_2),
			Color3.fromRGB(55, 55, 60),
			10
		)
		botaoAttach.TextColor3 = attachEsse and Color3.fromRGB(90, 255, 150) or Color3.fromRGB(255, 255, 255)

		local orbitEsse = orbitAlvo == outroPlayer
		local botaoOrbit = novoBotao(
			linha,
			orbitEsse and "Orbit: ON" or "Orbit",
			UDim2.new(0, LARGURA_BOTAO_ACAO_3, 0, ALTURA_BTN_ACAO),
			UDim2.new(0, 6 + LARGURA_BOTAO_ACAO_3 + 4, 0, Y_ACOES_2),
			Color3.fromRGB(55, 55, 60),
			10
		)
		botaoOrbit.TextColor3 = orbitEsse and Color3.fromRGB(90, 255, 150) or Color3.fromRGB(255, 255, 255)

		local lookEsse = autoLookAlvo == outroPlayer
		local botaoLook = novoBotao(
			linha,
			lookEsse and "Olhar: ON" or "Olhar",
			UDim2.new(0, LARGURA_BOTAO_ACAO_3, 0, ALTURA_BTN_ACAO),
			UDim2.new(0, 6 + (LARGURA_BOTAO_ACAO_3 + 4) * 2, 0, Y_ACOES_2),
			Color3.fromRGB(55, 55, 60),
			10
		)
		botaoLook.TextColor3 = lookEsse and Color3.fromRGB(90, 255, 150) or Color3.fromRGB(255, 255, 255)

		-- Linha 3 de botões de ação (Copiar Skin / Ver Inventário)
		local Y_ACOES_3 = Y_ACOES_2 + ALTURA_BTN_ACAO + 4 -- 102

		local botaoCopiarSkin = novoBotao(
			linha,
			"Copiar Skin",
			UDim2.new(0, LARGURA_BOTAO_ACAO_2, 0, ALTURA_BTN_ACAO),
			UDim2.new(0, 6, 0, Y_ACOES_3),
			Color3.fromRGB(55, 55, 60),
			10
		)

		local botaoVerItens = novoBotao(
			linha,
			"Ver Inventário",
			UDim2.new(0, LARGURA_BOTAO_ACAO_2, 0, ALTURA_BTN_ACAO),
			UDim2.new(0, 6 + LARGURA_BOTAO_ACAO_2 + 4, 0, Y_ACOES_3),
			Color3.fromRGB(55, 55, 60),
			10
		)

		botaoFling.MouseButton1Click:Connect(function()
			botaoFling.Text = "Fling..."
			botaoFling.TextColor3 = Color3.fromRGB(255, 120, 120)
			task.spawn(function()
				flingPlayer(outroPlayer)
				botaoFling.Text = "Fling"
				botaoFling.TextColor3 = Color3.fromRGB(255, 255, 255)
			end)
		end)

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

		botaoAttach.MouseButton1Click:Connect(function()
			if attachAlvo == outroPlayer then
				pararAttach()
			else
				iniciarAttach(outroPlayer)
			end
			atualizarLista()
		end)

		botaoOrbit.MouseButton1Click:Connect(function()
			if orbitAlvo == outroPlayer then
				pararOrbit()
			else
				iniciarOrbit(outroPlayer)
			end
			atualizarLista()
		end)

		botaoLook.MouseButton1Click:Connect(function()
			if autoLookAlvo == outroPlayer then
				pararAutoLook()
			else
				iniciarAutoLook(outroPlayer)
			end
			atualizarLista()
		end)

		botaoCopiarSkin.MouseButton1Click:Connect(function()
			copiarSkin(outroPlayer)
			botaoCopiarSkin.Text = "Copiado! ✓"
			botaoCopiarSkin.TextColor3 = Color3.fromRGB(90, 255, 150)
			task.delay(1.5, function()
				if botaoCopiarSkin and botaoCopiarSkin.Parent then
					botaoCopiarSkin.Text = "Copiar Skin"
					botaoCopiarSkin.TextColor3 = Color3.fromRGB(255, 255, 255)
				end
			end)
		end)

		botaoVerItens.MouseButton1Click:Connect(function()
			UI.janelaInventario.Visible = true
			renderizarInventario(outroPlayer)
		end)

		conectarRespawnEspectado(outroPlayer)
	end
end

Players.PlayerAdded:Connect(atualizarLista)
Players.PlayerRemoving:Connect(atualizarLista)

-- Atualiza a lista em tempo real conforme a pessoa digita na busca
UI.caixaBusca:GetPropertyChangedSignal("Text"):Connect(atualizarLista)

atualizarLista()

------------------------------------------------------------
-- DESINJETAR (clique no logo DEMONIAKA)
-- Restaura tudo que o painel alterou e remove painel + botão flutuante
-- Pra voltar, é só rodar o loadstring de novo
------------------------------------------------------------
destruirPainel = function()
	if destruido then
		return
	end
	destruido = true

	-- 1) restaura o personagem e a câmera (antes de remover a GUI, pois usam os controles)
	pararSeguir()
	if espectando then
		pararEspectar()
	end
	if flyAtivo then
		pararFly()
	end
	if noclipAtivo then
		desativarNoclip()
	end
	if antiCairAtivo then
		desativarAntiCair()
	end
	if antiFreezeAtivo then
		desativarAntiFreeze()
	end
	if spinbotAtivo then
		desativarSpinbot()
	end
	if spiderManAtivo then
		desativarSpiderMan()
	end
	clickTpAtivo = false
	desativarAntiAfk()
	desativarFantasma()
	pararAttach()
	pararOrbit()
	pararAutoLook()
	pararAnimacao()

	-- 2) remove os ESPs e desliga os loops por frame
	for alvo in pairs(espObjetos) do
		removerESP(alvo)
	end
	espAtivo = false
	if seguirHeartbeat then
		seguirHeartbeat:Disconnect()
		seguirHeartbeat = nil
	end
	if espHeartbeat then
		espHeartbeat:Disconnect()
		espHeartbeat = nil
	end
	if noclipConexao then
		noclipConexao:Disconnect()
		noclipConexao = nil
	end
	if noclipLoop then
		noclipLoop:Disconnect()
		noclipLoop = nil
	end

	-- 3) some com tudo (painel + botão flutuante)
	if screenGui then
		screenGui:Destroy()
	end

	print("[PainelTP] Painel desinjetado. Rode o loadstring de novo pra reabrir.")
end
