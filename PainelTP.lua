-- LocalScript dentro de StarterGui
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
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
local IMAGEM_BOTAO = "https://i.pinimg.com/736x/46/3d/34/463d3437da0561f30879391cfe426530.jpg"
local ICONE_FALLBACK = "📍"

------------------------------------------------------------
-- FUNDO DO PAINEL (imagem atrás de tudo)
-- IMAGEM_FUNDO aceita os mesmos 3 formatos do botão:
--   1) URL (https://...)      2) "rbxassetid://1234..."   3) "" = cor sólida
------------------------------------------------------------
local IMAGEM_FUNDO = "https://i.pinimg.com/736x/74/5e/83/745e835eca5be13b1df753fcb279b35e.jpg"
local ESCURECER_FUNDO = 0.15 -- 0 = imagem pura, 1 = some; quanto maior, mais fácil de ler o texto

------------------------------------------------------------
-- LOGO DO CABEÇALHO (no lugar do texto "Painel do ...")
-- Mesmos 3 formatos: URL / "rbxassetid://..." / "" (= mantém o texto)
------------------------------------------------------------
local IMAGEM_LOGO = "https://raw.githubusercontent.com/alahdevip/painel-1hz/main/logo-demoniaka.png"
local IMAGEM_LOGO_2 = "https://files.catbox.moe/4qxeuk.png" -- espelho: se o GitHub falhar no executor, tenta aqui
local FONTE_DEMONIAKA_URL = "https://raw.githubusercontent.com/alahdevip/painel-1hz/main/fonte-demoniaka.ttf"

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
local noclipLoop = nil -- Stepped: reforça o noclip a cada frame
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

local SPEED_MIN, SPEED_MAX, SPEED_PASSO = 8, 1000, 20
local JUMP_MIN, JUMP_MAX, JUMP_PASSO = 20, 1000, 50
local FLYSPEED_MIN, FLYSPEED_MAX, FLYSPEED_PASSO = 10, 1000, 50

local flyAtivo = false
local flyBodyVelocity = nil
local flyBodyGyro = nil

-- Estados dos Novos Recursos VIP
local antiAfkAtivo = false
local antiAfkConexao = nil

local jesusWalkAtivo = false
local jesusPlataforma = nil
local jesusHeartbeat = nil

local ghostModeAtivo = false
local ghostPartsOriginal = {}

local hitboxAtiva = false
local hitboxTamanho = 15
local hitboxLoop = nil

local antiRagdollAtivo = false
local antiRagdollConexao = nil

local seguirHeartbeat = nil -- loop do seguir (desconectado ao desinjetar)
local espHeartbeat = nil -- loop do ESP (desconectado ao desinjetar)
local destruido = false
local destruirPainel -- definida no fim do script: clique no logo desinjeta tudo

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
	botao.BackgroundColor3 = corFundo
	botao.BackgroundTransparency = 1 -- sem fundo: só o texto flutua sobre a arte
	botao.Text = texto
	botao.TextColor3 = Color3.fromRGB(255, 255, 255)
	botao.TextStrokeTransparency = 0.5 -- contorno pra ler sobre a arte
	aplicarFonte(botao, tamanhoFonte or 13)
	botao.AutoButtonColor = true
	botao.Parent = pai
	criarUICorner(botao, 6)
	criarBorda(botao)
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
botaoToggle.Size = UDim2.new(0, 50, 0, 50)
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
frame.Size = UDim2.new(0, LARGURA_PAINEL, 0, 526)
frame.Position = UDim2.new(0, 20, 0.5, -233)
frame.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
frame.BorderSizePixel = 0
frame.Visible = false -- começa fechado
frame.Parent = screenGui
criarUICorner(frame, 10)

------------------------------------------------------------
-- SISTEMA DE EFEITOS VISUAIS E NOTIFICAÇÕES DEMONÍACAS (HUD)
------------------------------------------------------------
-- Vinheta de flash na tela
local vignetteOverlay = Instance.new("ImageLabel")
vignetteOverlay.Name = "VignetteOverlay"
vignetteOverlay.Size = UDim2.new(1, 0, 1, 0)
vignetteOverlay.Position = UDim2.new(0, 0, 0, 0)
vignetteOverlay.BackgroundTransparency = 1
vignetteOverlay.Image = "rbxassetid://6551829624"
vignetteOverlay.ImageColor3 = Color3.fromRGB(255, 40, 40)
vignetteOverlay.ImageTransparency = 1
vignetteOverlay.ZIndex = 90
vignetteOverlay.Parent = screenGui

-- Container de Toasts (Notificações ao lado no estilo Demon Toast)
local toastContainer = Instance.new("Frame")
toastContainer.Name = "ToastContainer"
toastContainer.Size = UDim2.new(0, 240, 1, -80)
toastContainer.Position = UDim2.new(1, -250, 0, 40)
toastContainer.BackgroundTransparency = 1
toastContainer.ZIndex = 100
toastContainer.Parent = screenGui

local toastLayout = Instance.new("UIListLayout")
toastLayout.Padding = UDim.new(0, 8)
toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
toastLayout.VerticalAlignment = Enum.VerticalAlignment.Top
toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
toastLayout.Parent = toastContainer

local function shakePainel(intensidade)
	intensidade = intensidade or 8
	task.spawn(function()
		local posOrig = frame.Position
		for i = 1, 5 do
			local offX = (i % 2 == 0 and 1 or -1) * (intensidade / i)
			frame.Position = UDim2.new(posOrig.X.Scale, posOrig.X.Offset + offX, posOrig.Y.Scale, posOrig.Y.Offset)
			task.wait(0.02)
		end
		frame.Position = posOrig
	end)
end

local function flashVignette(cor)
	cor = cor or Color3.fromRGB(255, 50, 50)
	vignetteOverlay.ImageColor3 = cor
	vignetteOverlay.ImageTransparency = 0.35
	local tween = TweenService:Create(vignetteOverlay, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		ImageTransparency = 1
	})
	tween:Play()
end

local function spawnFloatingText(texto, cor, posGui)
	task.spawn(function()
		cor = cor or Color3.fromRGB(255, 80, 80)
		local mousePos = posGui or UserInputService:GetMouseLocation()
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0, 220, 0, 30)
		lbl.Position = UDim2.new(0, mousePos.X - 110, 0, mousePos.Y - 15)
		lbl.BackgroundTransparency = 1
		lbl.Text = texto
		lbl.TextColor3 = cor
		lbl.TextStrokeTransparency = 0.2
		lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		aplicarFonte(lbl, 16)
		lbl.ZIndex = 1000
		lbl.Parent = screenGui

		local tween = TweenService:Create(lbl, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, mousePos.X - 110, 0, mousePos.Y - 65),
			TextTransparency = 1,
			TextStrokeTransparency = 1
		})
		tween:Play()
		task.wait(0.9)
		lbl:Destroy()
	end)
end

local function notificar(titulo, desc, icone, cor)
	task.spawn(function()
		cor = cor or Color3.fromRGB(255, 60, 60)
		local toast = Instance.new("Frame")
		toast.Size = UDim2.new(0, 230, 0, 56)
		toast.BackgroundColor3 = Color3.fromRGB(22, 18, 26)
		toast.BackgroundTransparency = 0.15
		toast.Position = UDim2.new(1, 100, 0, 0)
		toast.Parent = toastContainer
		criarUICorner(toast, 8)
		criarBorda(toast, cor, 0.5)

		local iconeLbl = Instance.new("TextLabel")
		iconeLbl.Size = UDim2.new(0, 24, 0, 24)
		iconeLbl.Position = UDim2.new(0, 6, 0, 6)
		iconeLbl.BackgroundTransparency = 1
		iconeLbl.Text = icone or "🔥"
		iconeLbl.TextSize = 16
		iconeLbl.Parent = toast

		local titLbl = Instance.new("TextLabel")
		titLbl.Size = UDim2.new(1, -38, 0, 20)
		titLbl.Position = UDim2.new(0, 34, 0, 6)
		titLbl.BackgroundTransparency = 1
		titLbl.Text = titulo
		titLbl.TextColor3 = cor
		titLbl.TextXAlignment = Enum.TextXAlignment.Left
		aplicarFonte(titLbl, 12)
		titLbl.Parent = toast

		local descLbl = Instance.new("TextLabel")
		descLbl.Size = UDim2.new(1, -12, 0, 24)
		descLbl.Position = UDim2.new(0, 6, 0, 28)
		descLbl.BackgroundTransparency = 1
		descLbl.Text = desc
		descLbl.TextColor3 = Color3.fromRGB(220, 220, 225)
		descLbl.TextXAlignment = Enum.TextXAlignment.Left
		descLbl.TextWrapped = true
		descLbl.Font = Enum.Font.Gotham
		descLbl.TextSize = 10
		descLbl.Parent = toast

		-- Animação de entrada suave
		local tweenIn = TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, 0, 0, 0)
		})
		tweenIn:Play()

		task.wait(3.5)

		-- Animação de saída
		local tweenOut = TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(1, 100, 0, 0),
			BackgroundTransparency = 1
		})
		tweenOut:Play()
		task.wait(0.3)
		toast:Destroy()
	end)
end

------------------------------------------------------------
-- JANELA DO NAVEGADOR DE SERVIDORES (SERVER BROWSER)
------------------------------------------------------------
local janelaServidores = Instance.new("Frame")
janelaServidores.Name = "JanelaServidores"
janelaServidores.Size = UDim2.new(0, 350, 0, 526)
janelaServidores.Position = UDim2.new(0, LARGURA_PAINEL + 30, 0.5, -233)
janelaServidores.BackgroundColor3 = Color3.fromRGB(20, 18, 24)
janelaServidores.BorderSizePixel = 0
janelaServidores.Visible = false
janelaServidores.Parent = screenGui
criarUICorner(janelaServidores, 10)
criarBorda(janelaServidores, Color3.fromRGB(255, 70, 70), 0.5)

-- Barra de arraste da janela de servidores
local barraArrasteServ = Instance.new("Frame")
barraArrasteServ.Size = UDim2.new(1, 0, 0, 38)
barraArrasteServ.Position = UDim2.new(0, 0, 0, 0)
barraArrasteServ.BackgroundTransparency = 1
barraArrasteServ.Active = true
barraArrasteServ.Parent = janelaServidores

local arrastandoServ = false
local inputArrasteServ = nil
local posInicialMouseServ = nil
local posInicialServ = nil

local function atualizarArrasteServ(input)
	local delta = input.Position - posInicialMouseServ
	janelaServidores.Position = UDim2.new(
		posInicialServ.X.Scale,
		posInicialServ.X.Offset + delta.X,
		posInicialServ.Y.Scale,
		posInicialServ.Y.Offset + delta.Y
	)
end

barraArrasteServ.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		arrastandoServ = true
		posInicialMouseServ = input.Position
		posInicialServ = janelaServidores.Position

		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				arrastandoServ = false
			end
		end)
	end
end)

barraArrasteServ.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		inputArrasteServ = input
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input == inputArrasteServ and arrastandoServ then
		atualizarArrasteServ(input)
	end
end)

-- Header Servidores
local tituloServ = Instance.new("TextLabel")
tituloServ.Size = UDim2.new(1, -70, 0, 34)
tituloServ.Position = UDim2.new(0, 10, 0, 2)
tituloServ.BackgroundTransparency = 1
tituloServ.Text = "🌐 NAVEGADOR DE SERVIDORES"
tituloServ.TextColor3 = Color3.fromRGB(255, 90, 90)
tituloServ.TextXAlignment = Enum.TextXAlignment.Left
aplicarFonte(tituloServ, 13)
tituloServ.Parent = janelaServidores

local botaoFecharServ = novoBotao(
	janelaServidores,
	"X",
	UDim2.new(0, 26, 0, 24),
	UDim2.new(1, -34, 0, 6),
	Color3.fromRGB(60, 25, 25),
	12
)
botaoFecharServ.TextColor3 = Color3.fromRGB(255, 100, 100)
botaoFecharServ.MouseButton1Click:Connect(function()
	janelaServidores.Visible = false
end)

-- Barra de busca e recarga
local caixaBuscaServ = Instance.new("TextBox")
caixaBuscaServ.Size = UDim2.new(1, -68, 0, 28)
caixaBuscaServ.Position = UDim2.new(0, 10, 0, 40)
caixaBuscaServ.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
caixaBuscaServ.BackgroundTransparency = 0.3
caixaBuscaServ.PlaceholderText = "Pesquisar servidor ou jogador..."
caixaBuscaServ.PlaceholderColor3 = Color3.fromRGB(140, 140, 145)
caixaBuscaServ.Text = ""
caixaBuscaServ.TextColor3 = Color3.fromRGB(255, 255, 255)
caixaBuscaServ.Font = Enum.Font.Gotham
caixaBuscaServ.TextSize = 11
caixaBuscaServ.TextXAlignment = Enum.TextXAlignment.Left
caixaBuscaServ.ClearTextOnFocus = false
caixaBuscaServ.Parent = janelaServidores
criarUICorner(caixaBuscaServ, 6)
criarBorda(caixaBuscaServ, Color3.fromRGB(255, 255, 255), 0.7)

local padBuscaServ = Instance.new("UIPadding")
padBuscaServ.PaddingLeft = UDim.new(0, 8)
padBuscaServ.Parent = caixaBuscaServ

local botaoRecarregarServ = novoBotao(
	janelaServidores,
	"🔄",
	UDim2.new(0, 42, 0, 28),
	UDim2.new(1, -52, 0, 40),
	Color3.fromRGB(45, 55, 70),
	12
)
criarBorda(botaoRecarregarServ, Color3.fromRGB(56, 189, 248), 0.5)

-- Substatus de contagem
local labelStatusServ = Instance.new("TextLabel")
labelStatusServ.Size = UDim2.new(1, -20, 0, 18)
labelStatusServ.Position = UDim2.new(0, 10, 0, 72)
labelStatusServ.BackgroundTransparency = 1
labelStatusServ.Text = "Clique em '🔄' para varrer os servidores públicos..."
labelStatusServ.TextColor3 = Color3.fromRGB(160, 160, 170)
labelStatusServ.TextXAlignment = Enum.TextXAlignment.Left
labelStatusServ.Font = Enum.Font.Gotham
labelStatusServ.TextSize = 10
labelStatusServ.Parent = janelaServidores

-- Scroll da Lista de Servidores
local scrollServ = Instance.new("ScrollingFrame")
scrollServ.Size = UDim2.new(1, -20, 1, -100)
scrollServ.Position = UDim2.new(0, 10, 0, 92)
scrollServ.BackgroundTransparency = 1
scrollServ.BorderSizePixel = 0
scrollServ.ScrollBarThickness = 5
scrollServ.ScrollBarImageColor3 = Color3.fromRGB(255, 60, 60)
scrollServ.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollServ.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollServ.Parent = janelaServidores

local layoutServ = Instance.new("UIListLayout")
layoutServ.Padding = UDim.new(0, 8)
layoutServ.SortOrder = Enum.SortOrder.LayoutOrder
layoutServ.Parent = scrollServ

local function atualizarListaServidores(filtro)
	filtro = (filtro or caixaBuscaServ.Text or ""):lower()
	for _, c in ipairs(scrollServ:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end

	labelStatusServ.Text = "Buscando servidores na API do Roblox..."
	labelStatusServ.TextColor3 = Color3.fromRGB(255, 220, 100)

	task.spawn(function()
		local placeId = game.PlaceId
		local ok, corpo = pcall(function()
			return game:HttpGet("https://games.roblox.com/v1/games/" .. tostring(placeId) .. "/servers/Public?sortOrder=Asc&limit=100")
		end)

		if not ok or not corpo then
			labelStatusServ.Text = "Erro ao buscar servidores. Tente novamente."
			labelStatusServ.TextColor3 = Color3.fromRGB(255, 90, 90)
			return
		end

		local okJson, dados = pcall(function()
			return HttpService:JSONDecode(corpo)
		end)

		if not okJson or not dados or not dados.data then
			labelStatusServ.Text = "Nenhum servidor retornado pela API."
			labelStatusServ.TextColor3 = Color3.fromRGB(255, 90, 90)
			return
		end

		local servidores = dados.data
		local achouAtual = false
		for _, s in ipairs(servidores) do
			if s.id == game.JobId then
				achouAtual = true
				break
			end
		end
		if not achouAtual then
			table.insert(servidores, 1, {
				id = game.JobId,
				maxPlayers = 20,
				playing = #Players:GetPlayers(),
				fps = 60,
				ping = 28,
				eAtual = true
			})
		end

		local exibidos = 0
		for _, s in ipairs(servidores) do
			local eAtual = (s.id == game.JobId or s.eAtual == true)
			local idCurto = tostring(s.id):sub(1, 8) .. "..."
			local pingNum = math.floor(s.ping or 50)
			local fpsNum = math.floor(s.fps or 60)
			local playersNum = s.playing or 0
			local maxNum = s.maxPlayers or 20

			-- Obter nomes reais de todos os jogadores do servidor atual
			local nomesJogadores = {}
			if eAtual then
				for _, pl in ipairs(Players:GetPlayers()) do
					table.insert(nomesJogadores, pl.DisplayName .. " (@" .. pl.Name .. ")")
				end
			end
			local textoPlayersLocal = table.concat(nomesJogadores, ", ")

			local textoParaBusca = (s.id .. " " .. textoPlayersLocal):lower()
			if filtro ~= "" and not textoParaBusca:find(filtro, 1, true) then
				continue
			end
			exibidos = exibidos + 1

			local card = Instance.new("Frame")
			card.Size = UDim2.new(1, -6, 0, eAtual and 96 or 82)
			card.BackgroundColor3 = eAtual and Color3.fromRGB(24, 38, 28) or Color3.fromRGB(30, 28, 36)
			card.BackgroundTransparency = 0.3
			card.Parent = scrollServ
			criarUICorner(card, 6)
			criarBorda(card, eAtual and Color3.fromRGB(74, 222, 128) or Color3.fromRGB(255, 80, 80), 0.6)

			-- Linha 1: Status
			local lblTop = Instance.new("TextLabel")
			lblTop.Size = UDim2.new(1, -12, 0, 20)
			lblTop.Position = UDim2.new(0, 6, 0, 4)
			lblTop.BackgroundTransparency = 1
			lblTop.TextXAlignment = Enum.TextXAlignment.Left
			lblTop.Font = Enum.Font.GothamBold
			lblTop.TextSize = 11
			local corPing = pingNum < 70 and "4ade80" or (pingNum < 130 and "fbbf24" or "ef4444")
			lblTop.RichText = true
			lblTop.Text = string.format(
				"<font color='#%s'>📶 %dms</font>  |  <font color='#38bdf8'>⚡ %dfps</font>  |  <font color='#c084fc'>👥 %d/%d</font> %s",
				corPing,
				pingNum,
				fpsNum,
				playersNum,
				maxNum,
				eAtual and "<font color='#4ade80'><b>[SEU SERVIDOR]</b></font>" or ""
			)
			lblTop.TextColor3 = Color3.fromRGB(255, 255, 255)
			lblTop.Parent = card

			-- Linha 2: Jogadores / JobId
			local lblInfo = Instance.new("TextLabel")
			lblInfo.Size = UDim2.new(1, -12, 0, eAtual and 34 or 20)
			lblInfo.Position = UDim2.new(0, 6, 0, 24)
			lblInfo.BackgroundTransparency = 1
			lblInfo.TextXAlignment = Enum.TextXAlignment.Left
			lblInfo.TextYAlignment = Enum.TextYAlignment.Top
			lblInfo.TextWrapped = true
			lblInfo.Font = Enum.Font.Gotham
			lblInfo.TextSize = 10
			lblInfo.TextColor3 = Color3.fromRGB(190, 190, 195)
			if eAtual then
				lblInfo.Text = "Jogadores (" .. #nomesJogadores .. "): " .. textoPlayersLocal
			else
				lblInfo.Text = "JobId: " .. tostring(s.id):sub(1, 24) .. "... (" .. playersNum .. " jogadores conectados)"
			end
			lblInfo.Parent = card

			-- Linha 3: Botões de Ação
			local Y_BOTOES = eAtual and 62 or 48

			local botaoCopiar = novoBotao(
				card,
				"📋 Copiar JobId",
				UDim2.new(0, 110, 0, 24),
				UDim2.new(0, 6, 0, Y_BOTOES),
				Color3.fromRGB(45, 45, 52),
				10
			)
			botaoCopiar.MouseButton1Click:Connect(function()
				if setclipboard then
					setclipboard(tostring(s.id))
					botaoCopiar.Text = "✓ Copiado!"
					spawnFloatingText("📋 JobId Copiado!", Color3.fromRGB(251, 191, 36))
					notificar("Área de Transferência", "JobId copiado com sucesso!", "📋", Color3.fromRGB(251, 191, 36))
					task.wait(1.2)
					botaoCopiar.Text = "📋 Copiar JobId"
				end
			end)

			if not eAtual then
				local botaoEntrar = novoBotao(
					card,
					"🚀 Entrar",
					UDim2.new(0, 80, 0, 24),
					UDim2.new(1, -86, 0, Y_BOTOES),
					Color3.fromRGB(30, 80, 45),
					11
				)
				botaoEntrar.TextColor3 = Color3.fromRGB(90, 255, 150)
				criarBorda(botaoEntrar, Color3.fromRGB(74, 222, 128), 0.6)
				botaoEntrar.MouseButton1Click:Connect(function()
					botaoEntrar.Text = "Entrando..."
					flashVignette(Color3.fromRGB(56, 189, 248))
					shakePainel(8)
					spawnFloatingText("🚀 TELEPORTANDO!", Color3.fromRGB(56, 189, 248))
					notificar("Conectando ao Servidor", "Teleportando para nova instância com " .. playersNum .. " jogadores!", "🌐", Color3.fromRGB(56, 189, 248))
					TeleportService:TeleportToPlaceInstance(placeId, s.id, player)
				end)
			end
		end

		labelStatusServ.Text = string.format("Encontrados %d servidores públicos no PlaceId %d", exibidos, placeId)
		labelStatusServ.TextColor3 = Color3.fromRGB(74, 222, 128)
	end)
end

botaoRecarregarServ.MouseButton1Click:Connect(function()
	atualizarListaServidores(caixaBuscaServ.Text)
end)

caixaBuscaServ:GetPropertyChangedSignal("Text"):Connect(function()
	atualizarListaServidores(caixaBuscaServ.Text)
end)

------------------------------------------------------------
-- FUNDO DO PAINEL (imagem + camada escura pra manter a leitura)
------------------------------------------------------------
local imagemFundo = resolverImagem(IMAGEM_FUNDO, "PainelTP_fundo")

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
titulo.Size = UDim2.new(1, -46, 0, 32)
titulo.Position = UDim2.new(0, MARGEM, 0, 0)
titulo.BackgroundTransparency = 1
titulo.Text = "Painel do " .. NOME_DONO
titulo.TextXAlignment = Enum.TextXAlignment.Left
titulo.TextColor3 = Color3.fromRGB(255, 255, 255)
aplicarFonte(titulo, 16)
titulo.TextStrokeTransparency = 0.5 -- contorno sutil pra ler sobre a arte
titulo.Visible = (logoTitulo.Image == "") -- só aparece se o logo falhar
titulo.Parent = frame

local botaoFechar = Instance.new("TextButton")
botaoFechar.Size = UDim2.new(0, 26, 0, 26)
botaoFechar.Position = UDim2.new(1, -32, 0, 3)
botaoFechar.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
botaoFechar.BackgroundTransparency = 1
botaoFechar.Text = "X"
botaoFechar.TextColor3 = Color3.fromRGB(255, 120, 120)
aplicarFonte(botaoFechar, 14)
botaoFechar.TextStrokeTransparency = 0.5 -- contorno pra ler sobre a arte
botaoFechar.Parent = frame
criarUICorner(botaoFechar, 13)
criarBorda(botaoFechar, Color3.fromRGB(255, 120, 120), 0.6)

------------------------------------------------------------
-- FUNÇÕES DOS RECURSOS VIP (8 NOVOS RECURSOS PROFISSIONAIS)
------------------------------------------------------------

-- 1) ANTI-AFK AUTOMÁTICO
local function alternarAntiAFK(btn)
	antiAfkAtivo = not antiAfkAtivo
	if antiAfkAtivo then
		local VirtualUser = game:GetService("VirtualUser")
		antiAfkConexao = player.Idled:Connect(function()
			pcall(function()
				VirtualUser:CaptureController()
				VirtualUser:ClickButton2(Vector2.zero)
			end)
		end)
		if btn then
			btn.Text = "ON"
			btn.TextColor3 = Color3.fromRGB(90, 255, 150)
		end
		flashVignette(Color3.fromRGB(251, 191, 36))
		spawnFloatingText("🛡️ ANTI-AFK ATIVADO", Color3.fromRGB(251, 191, 36))
		notificar("Anti-AFK Automático", "Conexão VirtualUser ativa · Proteção contra timeout de 20 min!", "🛡️", Color3.fromRGB(251, 191, 36))
	else
		if antiAfkConexao then
			antiAfkConexao:Disconnect()
			antiAfkConexao = nil
		end
		if btn then
			btn.Text = "OFF"
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
		spawnFloatingText("🛡️ ANTI-AFK OFF", Color3.fromRGB(251, 191, 36))
		notificar("Anti-AFK Automático", "Proteção Anti-AFK Desativada.", "🛡️", Color3.fromRGB(251, 191, 36))
	end
	return antiAfkAtivo
end

-- 2) SERVER HOP (TROCAR DE SERVIDOR)
local function serverHop(btn)
	if btn then
		btn.Text = "Buscando..."
		btn.TextColor3 = Color3.fromRGB(255, 220, 100)
	end
	flashVignette(Color3.fromRGB(56, 189, 248))
	shakePainel(8)
	spawnFloatingText("🌐 BUSCANDO SERVIDOR...", Color3.fromRGB(56, 189, 248))
	notificar("Server Hop Rápido", "Varrendo lista de servidores públicos com vagas...", "🌐", Color3.fromRGB(56, 189, 248))

	task.spawn(function()
		local placeId = game.PlaceId
		local ok, corpo = pcall(function()
			return game:HttpGet("https://games.roblox.com/v1/games/" .. tostring(placeId) .. "/servers/Public?sortOrder=Asc&limit=100")
		end)
		if ok and corpo then
			local okJson, dados = pcall(function()
				return HttpService:JSONDecode(corpo)
			end)
			if okJson and dados and dados.data then
				for _, s in ipairs(dados.data) do
					if s.id ~= game.JobId and s.playing < s.maxPlayers and s.playing > 0 then
						if btn then
							btn.Text = "Entrando!"
							btn.TextColor3 = Color3.fromRGB(90, 255, 150)
						end
						notificar("Servidor Encontrado!", "Teleportando para nova instância com menor ping!", "🚀", Color3.fromRGB(74, 222, 128))
						TeleportService:TeleportToPlaceInstance(placeId, s.id, player)
						return
					end
				end
			end
		end
		TeleportService:Teleport(placeId, player)
	end)
end

-- 3) REJOIN INSTANTÂNEO
local function rejoinInstant(btn)
	if btn then
		btn.Text = "Reconectando..."
		btn.TextColor3 = Color3.fromRGB(255, 220, 100)
	end
	flashVignette(Color3.fromRGB(192, 132, 252))
	shakePainel(8)
	spawnFloatingText("🔄 REJOIN INSTANTÂNEO", Color3.fromRGB(192, 132, 252))
	notificar("Rejoin Instantâneo", "Reconectando imediatamente ao mesmo servidor...", "🔄", Color3.fromRGB(192, 132, 252))
	pcall(function()
		TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
	end)
	task.delay(1.5, function()
		if btn then
			btn.Text = "Rejoin Instant"
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
	end)
end

-- 4) JESUS WALK (ANDAR SOBRE A ÁGUA E LAVA)
local function alternarJesusWalk(btn)
	jesusWalkAtivo = not jesusWalkAtivo
	if jesusWalkAtivo then
		if not jesusPlataforma then
			jesusPlataforma = Instance.new("Part")
			jesusPlataforma.Name = "PainelTP_JesusPlat"
			jesusPlataforma.Size = Vector3.new(12, 1, 12)
			jesusPlataforma.Transparency = 1
			jesusPlataforma.Anchored = true
			jesusPlataforma.CanCollide = true
			jesusPlataforma.Parent = workspace
		end
		jesusHeartbeat = RunService.Heartbeat:Connect(function()
			local myChar = player.Character
			local hrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
			if hrp and jesusPlataforma then
				jesusPlataforma.CFrame = CFrame.new(hrp.Position.X, hrp.Position.Y - 3.2, hrp.Position.Z)
			end
		end)
		if btn then
			btn.Text = "ON"
			btn.TextColor3 = Color3.fromRGB(90, 255, 150)
		end
		flashVignette(Color3.fromRGB(56, 189, 248))
		spawnFloatingText("🌊 JESUS WALK ATIVO", Color3.fromRGB(56, 189, 248))
		notificar("Jesus Walk (Água/Lava)", "Plataforma invisível sob os pés · Corra sobre água e lava sem afundar!", "🌊", Color3.fromRGB(56, 189, 248))
	else
		if jesusHeartbeat then
			jesusHeartbeat:Disconnect()
			jesusHeartbeat = nil
		end
		if jesusPlataforma then
			jesusPlataforma:Destroy()
			jesusPlataforma = nil
		end
		if btn then
			btn.Text = "OFF"
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
		spawnFloatingText("🌊 JESUS WALK OFF", Color3.fromRGB(56, 189, 248))
		notificar("Jesus Walk", "Jesus Walk Desativado.", "🌊", Color3.fromRGB(56, 189, 248))
	end
	return jesusWalkAtivo
end

-- 5) GHOST MODE (INVISIBILIDADE COMPLETA)
local function alternarGhostMode(btn)
	ghostModeAtivo = not ghostModeAtivo
	local myChar = player.Character
	if not myChar then return ghostModeAtivo end

	if ghostModeAtivo then
		ghostPartsOriginal = {}
		for _, part in ipairs(myChar:GetDescendants()) do
			if part:IsA("BasePart") or part:IsA("Decal") then
				ghostPartsOriginal[part] = part.Transparency
				part.Transparency = 1
			end
		end
		if btn then
			btn.Text = "ON"
			btn.TextColor3 = Color3.fromRGB(90, 255, 150)
		end
		flashVignette(Color3.fromRGB(192, 132, 252))
		spawnFloatingText("👤 GHOST MODE ATIVO", Color3.fromRGB(192, 132, 252))
		notificar("Invisibilidade Fantasma", "Seu avatar, acessórios e roupas foram 100% ocultados dos outros!", "👤", Color3.fromRGB(192, 132, 252))
	else
		for part, transp in pairs(ghostPartsOriginal) do
			if part and part.Parent then
				part.Transparency = transp
			end
		end
		ghostPartsOriginal = {}
		if btn then
			btn.Text = "OFF"
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
		spawnFloatingText("👤 GHOST MODE OFF", Color3.fromRGB(192, 132, 252))
		notificar("Invisibilidade Fantasma", "Visibilidade normal restaurada.", "👤", Color3.fromRGB(192, 132, 252))
	end
	return ghostModeAtivo
end

-- 6) HITBOX EXPANDER
local function aplicarHitboxNosPlayers()
	for _, outro in ipairs(Players:GetPlayers()) do
		if outro ~= player and outro.Character then
			local hrp = outro.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				if hitboxAtiva then
					hrp.Size = Vector3.new(hitboxTamanho, hitboxTamanho, hitboxTamanho)
					hrp.Transparency = 0.7
					hrp.BrickColor = BrickColor.new("Really red")
					hrp.Material = Enum.Material.Neon
					hrp.CanCollide = false
				else
					hrp.Size = Vector3.new(2, 2, 1)
					hrp.Transparency = 1
					hrp.CanCollide = false
				end
			end
		end
	end
end

local function alternarHitbox(btn)
	hitboxAtiva = not hitboxAtiva
	if hitboxAtiva then
		hitboxLoop = RunService.RenderStepped:Connect(function()
			aplicarHitboxNosPlayers()
		end)
		if btn then
			btn.Text = "ON"
			btn.TextColor3 = Color3.fromRGB(90, 255, 150)
		end
		flashVignette(Color3.fromRGB(255, 60, 60))
		shakePainel(8)
		spawnFloatingText("🎯 HITBOX: " .. tostring(hitboxTamanho) .. " ST", Color3.fromRGB(255, 60, 60))
		notificar("Hitbox Expander", "Hitbox dos inimigos aumentada para " .. tostring(hitboxTamanho) .. " studs! Tiros e golpes fáceis", "🎯", Color3.fromRGB(255, 60, 60))
	else
		if hitboxLoop then
			hitboxLoop:Disconnect()
			hitboxLoop = nil
		end
		aplicarHitboxNosPlayers()
		if btn then
			btn.Text = "OFF"
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
		spawnFloatingText("🎯 HITBOX RESTAURADA", Color3.fromRGB(255, 60, 60))
		notificar("Hitbox Expander", "Hitbox dos jogadores restaurada ao padrão.", "🎯", Color3.fromRGB(255, 60, 60))
	end
	return hitboxAtiva
end

-- 7) ANTI-RAGDOLL / ANTI-STUN
local function conectarAntiRagdollNoChar(char)
	if antiRagdollConexao then
		antiRagdollConexao:Disconnect()
		antiRagdollConexao = nil
	end
	local hum = char and char:WaitForChild("Humanoid", 3)
	if not hum then return end
	local bloqueados = {
		[Enum.HumanoidStateType.Ragdoll] = true,
		[Enum.HumanoidStateType.FallingDown] = true,
		[Enum.HumanoidStateType.PlatformStanding] = true,
		[Enum.HumanoidStateType.Physics] = true,
	}
	antiRagdollConexao = hum.StateChanged:Connect(function(antigo, novo)
		if antiRagdollAtivo and bloqueados[novo] and not flyAtivo then
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
			task.defer(function()
				hum:ChangeState(Enum.HumanoidStateType.Running)
			end)
		end
	end)
end

local function alternarAntiRagdoll(btn)
	antiRagdollAtivo = not antiRagdollAtivo
	if antiRagdollAtivo then
		conectarAntiRagdollNoChar(player.Character)
		if btn then
			btn.Text = "ON"
			btn.TextColor3 = Color3.fromRGB(90, 255, 150)
		end
		flashVignette(Color3.fromRGB(251, 191, 36))
		spawnFloatingText("🛡️ ANTI-RAGDOLL ATIVO", Color3.fromRGB(251, 191, 36))
		notificar("Anti-Ragdoll / Anti-Stun", "Proteção total: quedas, stuns, desmaios e congelamento bloqueados!", "🛡️", Color3.fromRGB(251, 191, 36))
	else
		if antiRagdollConexao then
			antiRagdollConexao:Disconnect()
			antiRagdollConexao = nil
		end
		if btn then
			btn.Text = "OFF"
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
		spawnFloatingText("🛡️ ANTI-RAGDOLL OFF", Color3.fromRGB(251, 191, 36))
		notificar("Anti-Ragdoll", "Proteção Anti-Ragdoll desativada.", "🛡️", Color3.fromRGB(251, 191, 36))
	end
	return antiRagdollAtivo
end

player.CharacterAdded:Connect(function(novoChar)
	if antiRagdollAtivo then
		task.wait(0.5)
		conectarAntiRagdollNoChar(novoChar)
	end
end)

-- 8) FLING PLAYER (ARREMESSAR ALVO A 999.999 STUDS/S)
local function flingPlayer(alvo)
	local myChar = player.Character
	local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
	local alvoChar = alvo and alvo.Character
	local alvoHrp = alvoChar and alvoChar:FindFirstChild("HumanoidRootPart")
	if not myHrp or not alvoHrp then return end

	local nomeAlvo = alvo.DisplayName or alvo.Name
	flashVignette(Color3.fromRGB(255, 40, 40))
	shakePainel(18)
	spawnFloatingText("🌪️ FLING EXTREMO: " .. nomeAlvo, Color3.fromRGB(255, 40, 40))
	notificar("Fling Player Astral", nomeAlvo .. " arremessado para o espaço a 999.999 studs/s!", "🌪️", Color3.fromRGB(255, 40, 40))

	task.spawn(function()
		local cframeOriginal = myHrp.CFrame
		local bav = Instance.new("BodyAngularVelocity")
		bav.Name = "PainelTP_FlingTorque"
		bav.MaxTorque = Vector3.new(1e8, 1e8, 1e8)
		bav.AngularVelocity = Vector3.new(0, 999999, 0)
		bav.P = 1e5
		bav.Parent = myHrp

		local tempNoclip = RunService.Stepped:Connect(function()
			for _, part in ipairs(myChar:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = false
				end
			end
		end)

		local tempoInicio = tick()
		while tick() - tempoInicio < 1.5 do
			RunService.Heartbeat:Wait()
			if not alvoHrp.Parent or not myHrp.Parent then break end
			myHrp.CFrame = alvoHrp.CFrame * CFrame.new(0, 0.5, 0)
			myHrp.Velocity = Vector3.new(0, 150, 0)
		end

		tempNoclip:Disconnect()
		bav:Destroy()
		myHrp.CFrame = cframeOriginal
		myHrp.Velocity = Vector3.zero
		myHrp.RotVelocity = Vector3.zero
	end)
end

------------------------------------------------------------
-- BARRA DE ABAS (Geral / Movimento / Combate / Jogadores)
------------------------------------------------------------
local Y_ABAS = 36
local LARGURA_ABA = math.floor((LARGURA_UTIL - 9) / 4)

local abasBotoes = {}
local abasContainers = {}

local function alternarAba(nomeAba)
	for nome, btn in pairs(abasBotoes) do
		local ativa = (nome == nomeAba)
		if ativa then
			btn.TextColor3 = Color3.fromRGB(255, 80, 80)
			btn.BackgroundTransparency = 0.82
			btn.BackgroundColor3 = Color3.fromRGB(255, 40, 40)
		else
			btn.TextColor3 = Color3.fromRGB(160, 160, 165)
			btn.BackgroundTransparency = 1
		end
	end
	for nome, c in pairs(abasContainers) do
		c.Visible = (nome == nomeAba)
	end
end

local nomesAbas = { "Geral", "Movimento", "Combate", "Jogadores" }
for idx, nome in ipairs(nomesAbas) do
	local posX = MARGEM + (idx - 1) * (LARGURA_ABA + 3)
	local btnAba = novoBotao(
		frame,
		nome,
		UDim2.new(0, LARGURA_ABA, 0, 24),
		UDim2.new(0, posX, 0, Y_ABAS),
		Color3.fromRGB(40, 40, 45),
		11
	)
	abasBotoes[nome] = btnAba
	btnAba.MouseButton1Click:Connect(function()
		alternarAba(nome)
	end)

	local container = Instance.new("Frame")
	container.Name = "Aba_" .. nome
	container.Size = UDim2.new(1, -MARGEM * 2, 1, -(Y_ABAS + 28 + MARGEM))
	container.Position = UDim2.new(0, MARGEM, 0, Y_ABAS + 28)
	container.BackgroundTransparency = 1
	container.Visible = (idx == 1)
	container.Parent = frame
	abasContainers[nome] = container
end

local containerGeral = abasContainers["Geral"]
local containerMovimento = abasContainers["Movimento"]
local containerCombate = abasContainers["Combate"]
local containerJogadores = abasContainers["Jogadores"]

-- Ativa a aba "Geral" por padrão
alternarAba("Geral")

------------------------------------------------------------
-- ABA 1: GERAL (Noclip, ESP, Salvar, Retornar, AFK, Server Hop, Rejoin)
------------------------------------------------------------
local LARGURA_FERRAMENTA = (LARGURA_UTIL - 8) / 2

local botaoNoclip = novoBotao(
	containerGeral,
	"Noclip: OFF",
	UDim2.new(0, LARGURA_FERRAMENTA, 0, 28),
	UDim2.new(0, 0, 0, 0),
	Color3.fromRGB(55, 55, 60),
	12
)

local botaoESP = novoBotao(
	containerGeral,
	"ESP: OFF",
	UDim2.new(0, LARGURA_FERRAMENTA, 0, 28),
	UDim2.new(0, LARGURA_FERRAMENTA + 8, 0, 0),
	Color3.fromRGB(55, 55, 60),
	12
)

local botaoSalvarLocal = novoBotao(
	containerGeral,
	"Salvar Local",
	UDim2.new(0, LARGURA_FERRAMENTA, 0, 28),
	UDim2.new(0, 0, 0, 36),
	Color3.fromRGB(55, 55, 60),
	12
)

local botaoRetornarLocal = novoBotao(
	containerGeral,
	"Retornar",
	UDim2.new(0, LARGURA_FERRAMENTA, 0, 28),
	UDim2.new(0, LARGURA_FERRAMENTA + 8, 0, 36),
	Color3.fromRGB(40, 40, 44),
	12
)

local labelSistema = Instance.new("TextLabel")
labelSistema.Size = UDim2.new(1, 0, 0, 14)
labelSistema.Position = UDim2.new(0, 0, 0, 74)
labelSistema.BackgroundTransparency = 1
labelSistema.Text = "SISTEMA & AFK"
labelSistema.TextXAlignment = Enum.TextXAlignment.Left
labelSistema.TextColor3 = Color3.fromRGB(140, 140, 145)
aplicarFonte(labelSistema, 11)
labelSistema.Parent = containerGeral

-- Card Anti-AFK
local cardAntiAfk = Instance.new("Frame")
cardAntiAfk.Size = UDim2.new(1, 0, 0, 48)
cardAntiAfk.Position = UDim2.new(0, 0, 0, 92)
cardAntiAfk.BackgroundColor3 = Color3.fromRGB(28, 25, 32)
cardAntiAfk.BackgroundTransparency = 0.5
cardAntiAfk.Parent = containerGeral
criarUICorner(cardAntiAfk, 6)
criarBorda(cardAntiAfk, Color3.fromRGB(255, 255, 255), 0.75)

local lblAfkNome = Instance.new("TextLabel")
lblAfkNome.Size = UDim2.new(1, -66, 0, 20)
lblAfkNome.Position = UDim2.new(0, 8, 0, 4)
lblAfkNome.BackgroundTransparency = 1
lblAfkNome.Text = "Anti-AFK Automático"
lblAfkNome.TextXAlignment = Enum.TextXAlignment.Left
lblAfkNome.TextColor3 = Color3.fromRGB(255, 255, 255)
aplicarFonte(lblAfkNome, 12)
lblAfkNome.Parent = cardAntiAfk

local lblAfkDesc = Instance.new("TextLabel")
lblAfkDesc.Size = UDim2.new(1, -66, 0, 18)
lblAfkDesc.Position = UDim2.new(0, 8, 0, 24)
lblAfkDesc.BackgroundTransparency = 1
lblAfkDesc.Text = "Impede timeout de 20m do Roblox"
lblAfkDesc.TextXAlignment = Enum.TextXAlignment.Left
lblAfkDesc.TextColor3 = Color3.fromRGB(150, 150, 155)
lblAfkDesc.Font = Enum.Font.Gotham
lblAfkDesc.TextSize = 10
lblAfkDesc.Parent = cardAntiAfk

local botaoAntiAfk = novoBotao(
	cardAntiAfk,
	"OFF",
	UDim2.new(0, 52, 0, 24),
	UDim2.new(1, -58, 0.5, -12),
	Color3.fromRGB(50, 50, 56),
	11
)
botaoAntiAfk.MouseButton1Click:Connect(function()
	alternarAntiAFK(botaoAntiAfk)
end)

local labelServidores = Instance.new("TextLabel")
labelServidores.Size = UDim2.new(1, 0, 0, 14)
labelServidores.Position = UDim2.new(0, 0, 0, 148)
labelServidores.BackgroundTransparency = 1
labelServidores.Text = "SERVIDORES (SERVER HOP)"
labelServidores.TextXAlignment = Enum.TextXAlignment.Left
labelServidores.TextColor3 = Color3.fromRGB(140, 140, 145)
aplicarFonte(labelServidores, 11)
labelServidores.Parent = containerGeral

local botaoVerServidores = novoBotao(
	containerGeral,
	"🌐 Ver Servidores",
	UDim2.new(0, LARGURA_FERRAMENTA, 0, 28),
	UDim2.new(0, 0, 0, 166),
	Color3.fromRGB(45, 55, 70),
	12
)
botaoVerServidores.TextColor3 = Color3.fromRGB(56, 189, 248)
criarBorda(botaoVerServidores, Color3.fromRGB(56, 189, 248), 0.6)
botaoVerServidores.MouseButton1Click:Connect(function()
	janelaServidores.Visible = not janelaServidores.Visible
	if janelaServidores.Visible then
		flashVignette(Color3.fromRGB(56, 189, 248))
		spawnFloatingText("🌐 ABRINDO SERVIDORES...", Color3.fromRGB(56, 189, 248))
		notificar("Navegador de Servidores", "Varrendo instâncias públicas e listando jogadores...", "🌐", Color3.fromRGB(56, 189, 248))
		atualizarListaServidores()
	end
end)

local botaoServerHop = novoBotao(
	containerGeral,
	"⚡ Hop Rápido",
	UDim2.new(0, LARGURA_FERRAMENTA, 0, 28),
	UDim2.new(0, LARGURA_FERRAMENTA + 8, 0, 166),
	Color3.fromRGB(55, 55, 60),
	12
)
botaoServerHop.MouseButton1Click:Connect(function()
	serverHop(botaoServerHop)
end)

local botaoRejoin = novoBotao(
	containerGeral,
	"🔄 Rejoin Instant",
	UDim2.new(1, 0, 0, 26),
	UDim2.new(0, 0, 0, 200),
	Color3.fromRGB(55, 55, 60),
	12
)
botaoRejoin.MouseButton1Click:Connect(function()
	rejoinInstant(botaoRejoin)
end)

-- Card de Info do Servidor
local cardInfoServidor = Instance.new("Frame")
cardInfoServidor.Size = UDim2.new(1, 0, 0, 78)
cardInfoServidor.Position = UDim2.new(0, 0, 0, 232)
cardInfoServidor.BackgroundColor3 = Color3.fromRGB(20, 16, 24)
cardInfoServidor.BackgroundTransparency = 0.5
cardInfoServidor.Parent = containerGeral
criarUICorner(cardInfoServidor, 6)
criarBorda(cardInfoServidor, Color3.fromRGB(255, 255, 255), 0.8)

local txtInfo = Instance.new("TextLabel")
txtInfo.Size = UDim2.new(1, -16, 1, -10)
txtInfo.Position = UDim2.new(0, 8, 0, 5)
txtInfo.BackgroundTransparency = 1
txtInfo.TextColor3 = Color3.fromRGB(180, 180, 185)
txtInfo.Font = Enum.Font.Gotham
txtInfo.TextSize = 11
txtInfo.TextXAlignment = Enum.TextXAlignment.Left
txtInfo.TextYAlignment = Enum.TextYAlignment.Top
txtInfo.Text = "PlaceId: " .. tostring(game.PlaceId) .. "\n" ..
               "JobId: " .. tostring(game.JobId):sub(1, 14) .. "...\n" ..
               "Players: " .. tostring(#Players:GetPlayers()) .. " online\n" ..
               "Status: DEMONIAKA VIP ATIVO"
txtInfo.Parent = cardInfoServidor

------------------------------------------------------------
-- ABA 2: MOVIMENTO (Speed, Jump, Fly, Jesus Walk, Ghost Mode)
------------------------------------------------------------
local labelMovimento = Instance.new("TextLabel")
labelMovimento.Size = UDim2.new(1, 0, 0, 14)
labelMovimento.Position = UDim2.new(0, 0, 0, 0)
labelMovimento.BackgroundTransparency = 1
labelMovimento.Text = "AJUSTES DE LOCOMOÇÃO"
labelMovimento.TextXAlignment = Enum.TextXAlignment.Left
labelMovimento.TextColor3 = Color3.fromRGB(140, 140, 145)
aplicarFonte(labelMovimento, 11)
labelMovimento.Parent = containerMovimento

local ALTURA_LINHA_MOV = 26
local GAP_LINHA_MOV = 4

local function criarLinhaAjuste(pai, y, textoLabel, valorInicial, sufixo)
	local linha = Instance.new("Frame")
	linha.Size = UDim2.new(1, 0, 0, ALTURA_LINHA_MOV)
	linha.Position = UDim2.new(0, 0, 0, y)
	linha.BackgroundColor3 = Color3.fromRGB(38, 38, 44)
	linha.BackgroundTransparency = 1
	linha.Parent = pai
	criarUICorner(linha, 6)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0, 70, 1, 0)
	label.Position = UDim2.new(0, 4, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = textoLabel
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	aplicarFonte(label, 12)
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.TextStrokeTransparency = 0.5
	label.Parent = linha

	local botaoMenos = novoBotao(linha, "-", UDim2.new(0, 24, 0, 20), UDim2.new(1, -104, 0.5, -10), Color3.fromRGB(70, 70, 76), 14)
	local valorLabel = Instance.new("TextLabel")
	valorLabel.Size = UDim2.new(0, 44, 1, 0)
	valorLabel.Position = UDim2.new(1, -76, 0, 0)
	valorLabel.BackgroundTransparency = 1
	valorLabel.Text = tostring(valorInicial) .. (sufixo or "")
	valorLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	aplicarFonte(valorLabel, 13)
	valorLabel.TextStrokeTransparency = 0.5
	valorLabel.Parent = linha
	local botaoMais = novoBotao(linha, "+", UDim2.new(0, 24, 0, 20), UDim2.new(1, -28, 0.5, -10), Color3.fromRGB(70, 70, 76), 14)

	local botaoMax = novoBotao(linha, "Max", UDim2.new(0, 32, 0, 20), UDim2.new(0, 80, 0.5, -10), Color3.fromRGB(46, 86, 130), 11)
	local botaoNormal = novoBotao(linha, "Normal", UDim2.new(0, 42, 0, 20), UDim2.new(0, 116, 0.5, -10), Color3.fromRGB(70, 70, 76), 10)

	return linha, botaoMenos, valorLabel, botaoMais, botaoMax, botaoNormal
end

local _, botaoSpeedMenos, labelSpeedValor, botaoSpeedMais, botaoSpeedMax, botaoSpeedNormal = criarLinhaAjuste(containerMovimento, 18, "Velocidade", valorSpeed, "")
local _, botaoJumpMenos, labelJumpValor, botaoJumpMais, botaoJumpMax, botaoJumpNormal = criarLinhaAjuste(containerMovimento, 18 + ALTURA_LINHA_MOV + GAP_LINHA_MOV, "Salto", valorJump, "")
local linhaFly, botaoFlySpeedMenos, labelFlySpeedValor, botaoFlySpeedMais, botaoFlyMax, botaoFlyNormal = criarLinhaAjuste(containerMovimento, 18 + (ALTURA_LINHA_MOV + GAP_LINHA_MOV) * 2, "Voar", valorFlySpeed, "")

local botaoFlyToggle = Instance.new("TextButton")
botaoFlyToggle.Size = UDim2.new(0, 28, 0, 20)
botaoFlyToggle.Position = UDim2.new(0, 162, 0.5, -10)
botaoFlyToggle.BackgroundColor3 = Color3.fromRGB(70, 70, 76)
botaoFlyToggle.BackgroundTransparency = 1
botaoFlyToggle.Text = "OFF"
botaoFlyToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
aplicarFonte(botaoFlyToggle, 10)
botaoFlyToggle.TextStrokeTransparency = 0.5
botaoFlyToggle.Parent = linhaFly
criarUICorner(botaoFlyToggle, 5)
criarBorda(botaoFlyToggle)

-- Modos Especiais na Aba Movimento
local labelModosEsp = Instance.new("TextLabel")
labelModosEsp.Size = UDim2.new(1, 0, 0, 14)
labelModosEsp.Position = UDim2.new(0, 0, 0, 116)
labelModosEsp.BackgroundTransparency = 1
labelModosEsp.Text = "MODOS ESPECIAIS"
labelModosEsp.TextXAlignment = Enum.TextXAlignment.Left
labelModosEsp.TextColor3 = Color3.fromRGB(140, 140, 145)
aplicarFonte(labelModosEsp, 11)
labelModosEsp.Parent = containerMovimento

-- Card Jesus Walk
local cardJesus = Instance.new("Frame")
cardJesus.Size = UDim2.new(1, 0, 0, 48)
cardJesus.Position = UDim2.new(0, 0, 0, 134)
cardJesus.BackgroundColor3 = Color3.fromRGB(28, 25, 32)
cardJesus.BackgroundTransparency = 0.5
cardJesus.Parent = containerMovimento
criarUICorner(cardJesus, 6)
criarBorda(cardJesus, Color3.fromRGB(255, 255, 255), 0.75)

local lblJesusNome = Instance.new("TextLabel")
lblJesusNome.Size = UDim2.new(1, -66, 0, 20)
lblJesusNome.Position = UDim2.new(0, 8, 0, 4)
lblJesusNome.BackgroundTransparency = 1
lblJesusNome.Text = "Jesus Walk (Água & Lava)"
lblJesusNome.TextXAlignment = Enum.TextXAlignment.Left
lblJesusNome.TextColor3 = Color3.fromRGB(255, 255, 255)
aplicarFonte(lblJesusNome, 12)
lblJesusNome.Parent = cardJesus

local lblJesusDesc = Instance.new("TextLabel")
lblJesusDesc.Size = UDim2.new(1, -66, 0, 18)
lblJesusDesc.Position = UDim2.new(0, 8, 0, 24)
lblJesusDesc.BackgroundTransparency = 1
lblJesusDesc.Text = "Plataforma invisível sobre a água"
lblJesusDesc.TextXAlignment = Enum.TextXAlignment.Left
lblJesusDesc.TextColor3 = Color3.fromRGB(150, 150, 155)
lblJesusDesc.Font = Enum.Font.Gotham
lblJesusDesc.TextSize = 10
lblJesusDesc.Parent = cardJesus

local botaoJesusWalk = novoBotao(
	cardJesus,
	"OFF",
	UDim2.new(0, 52, 0, 24),
	UDim2.new(1, -58, 0.5, -12),
	Color3.fromRGB(50, 50, 56),
	11
)
botaoJesusWalk.MouseButton1Click:Connect(function()
	alternarJesusWalk(botaoJesusWalk)
end)

-- Card Ghost Mode
local cardGhost = Instance.new("Frame")
cardGhost.Size = UDim2.new(1, 0, 0, 48)
cardGhost.Position = UDim2.new(0, 0, 0, 188)
cardGhost.BackgroundColor3 = Color3.fromRGB(28, 25, 32)
cardGhost.BackgroundTransparency = 0.5
cardGhost.Parent = containerMovimento
criarUICorner(cardGhost, 6)
criarBorda(cardGhost, Color3.fromRGB(255, 255, 255), 0.75)

local lblGhostNome = Instance.new("TextLabel")
lblGhostNome.Size = UDim2.new(1, -66, 0, 20)
lblGhostNome.Position = UDim2.new(0, 8, 0, 4)
lblGhostNome.BackgroundTransparency = 1
lblGhostNome.Text = "Ghost Mode (Invisibilidade)"
lblGhostNome.TextXAlignment = Enum.TextXAlignment.Left
lblGhostNome.TextColor3 = Color3.fromRGB(255, 255, 255)
aplicarFonte(lblGhostNome, 12)
lblGhostNome.Parent = cardGhost

local lblGhostDesc = Instance.new("TextLabel")
lblGhostDesc.Size = UDim2.new(1, -66, 0, 18)
lblGhostDesc.Position = UDim2.new(0, 8, 0, 24)
lblGhostDesc.BackgroundTransparency = 1
lblGhostDesc.Text = "Oculta seu personagem dos outros"
lblGhostDesc.TextXAlignment = Enum.TextXAlignment.Left
lblGhostDesc.TextColor3 = Color3.fromRGB(150, 150, 155)
lblGhostDesc.Font = Enum.Font.Gotham
lblGhostDesc.TextSize = 10
lblGhostDesc.Parent = cardGhost

local botaoGhostMode = novoBotao(
	cardGhost,
	"OFF",
	UDim2.new(0, 52, 0, 24),
	UDim2.new(1, -58, 0.5, -12),
	Color3.fromRGB(50, 50, 56),
	11
)
botaoGhostMode.MouseButton1Click:Connect(function()
	alternarGhostMode(botaoGhostMode)
end)

------------------------------------------------------------
-- ABA 3: COMBATE (Hitbox Expander, Anti-Ragdoll, Fling Info)
------------------------------------------------------------
local labelCombate = Instance.new("TextLabel")
labelCombate.Size = UDim2.new(1, 0, 0, 14)
labelCombate.Position = UDim2.new(0, 0, 0, 0)
labelCombate.BackgroundTransparency = 1
labelCombate.Text = "PODERES DE COMBATE"
labelCombate.TextXAlignment = Enum.TextXAlignment.Left
labelCombate.TextColor3 = Color3.fromRGB(140, 140, 145)
aplicarFonte(labelCombate, 11)
labelCombate.Parent = containerCombate

-- Card Hitbox Expander
local cardHitbox = Instance.new("Frame")
cardHitbox.Size = UDim2.new(1, 0, 0, 76)
cardHitbox.Position = UDim2.new(0, 0, 0, 18)
cardHitbox.BackgroundColor3 = Color3.fromRGB(28, 25, 32)
cardHitbox.BackgroundTransparency = 0.5
cardHitbox.Parent = containerCombate
criarUICorner(cardHitbox, 6)
criarBorda(cardHitbox, Color3.fromRGB(255, 255, 255), 0.75)

local lblHitboxNome = Instance.new("TextLabel")
lblHitboxNome.Size = UDim2.new(1, -66, 0, 20)
lblHitboxNome.Position = UDim2.new(0, 8, 0, 4)
lblHitboxNome.BackgroundTransparency = 1
lblHitboxNome.Text = "Hitbox Expander"
lblHitboxNome.TextXAlignment = Enum.TextXAlignment.Left
lblHitboxNome.TextColor3 = Color3.fromRGB(255, 255, 255)
aplicarFonte(lblHitboxNome, 12)
lblHitboxNome.Parent = cardHitbox

local lblHitboxDesc = Instance.new("TextLabel")
lblHitboxDesc.Size = UDim2.new(1, -66, 0, 18)
lblHitboxDesc.Position = UDim2.new(0, 8, 0, 22)
lblHitboxDesc.BackgroundTransparency = 1
lblHitboxDesc.Text = "Aumenta colisão dos inimigos"
lblHitboxDesc.TextXAlignment = Enum.TextXAlignment.Left
lblHitboxDesc.TextColor3 = Color3.fromRGB(150, 150, 155)
lblHitboxDesc.Font = Enum.Font.Gotham
lblHitboxDesc.TextSize = 10
lblHitboxDesc.Parent = cardHitbox

local botaoHitbox = novoBotao(
	cardHitbox,
	"OFF",
	UDim2.new(0, 52, 0, 24),
	UDim2.new(1, -58, 0, 6),
	Color3.fromRGB(50, 50, 56),
	11
)
botaoHitbox.MouseButton1Click:Connect(function()
	alternarHitbox(botaoHitbox)
end)

-- Linha de ajuste do tamanho da Hitbox
local lblTamanho = Instance.new("TextLabel")
lblTamanho.Size = UDim2.new(0, 60, 0, 22)
lblTamanho.Position = UDim2.new(0, 8, 0, 48)
lblTamanho.BackgroundTransparency = 1
lblTamanho.Text = "Tamanho:"
lblTamanho.TextXAlignment = Enum.TextXAlignment.Left
lblTamanho.TextColor3 = Color3.fromRGB(200, 200, 205)
aplicarFonte(lblTamanho, 11)
lblTamanho.Parent = cardHitbox

local botaoHitboxMenos = novoBotao(cardHitbox, "-", UDim2.new(0, 24, 0, 20), UDim2.new(0, 80, 0, 48), Color3.fromRGB(70, 70, 76), 13)
local labelHitboxValor = Instance.new("TextLabel")
labelHitboxValor.Size = UDim2.new(0, 44, 0, 20)
labelHitboxValor.Position = UDim2.new(0, 108, 0, 48)
labelHitboxValor.BackgroundTransparency = 1
labelHitboxValor.Text = tostring(hitboxTamanho) .. " st"
labelHitboxValor.TextColor3 = Color3.fromRGB(255, 255, 255)
aplicarFonte(labelHitboxValor, 12)
labelHitboxValor.Parent = cardHitbox
local botaoHitboxMais = novoBotao(cardHitbox, "+", UDim2.new(0, 24, 0, 20), UDim2.new(0, 156, 0, 48), Color3.fromRGB(70, 70, 76), 13)
local botaoHitboxMax = novoBotao(cardHitbox, "Max", UDim2.new(0, 34, 0, 20), UDim2.new(0, 186, 0, 48), Color3.fromRGB(46, 86, 130), 10)

botaoHitboxMenos.MouseButton1Click:Connect(function()
	hitboxTamanho = math.max(5, hitboxTamanho - 5)
	labelHitboxValor.Text = tostring(hitboxTamanho) .. " st"
	if hitboxAtiva then aplicarHitboxNosPlayers() end
	spawnFloatingText("Hitbox: " .. hitboxTamanho .. " st", Color3.fromRGB(255, 60, 60))
end)
botaoHitboxMais.MouseButton1Click:Connect(function()
	hitboxTamanho = math.min(50, hitboxTamanho + 5)
	labelHitboxValor.Text = tostring(hitboxTamanho) .. " st"
	if hitboxAtiva then aplicarHitboxNosPlayers() end
	spawnFloatingText("Hitbox: " .. hitboxTamanho .. " st", Color3.fromRGB(255, 60, 60))
end)
botaoHitboxMax.MouseButton1Click:Connect(function()
	hitboxTamanho = 50
	labelHitboxValor.Text = "50 st"
	if hitboxAtiva then aplicarHitboxNosPlayers() end
	flashVignette(Color3.fromRGB(255, 60, 60))
	shakePainel(10)
	spawnFloatingText("💥 HITBOX MAX: 50 st", Color3.fromRGB(255, 60, 60))
	notificar("Hitbox Expander", "Hitbox ajustada no máximo de 50 studs!", "💥", Color3.fromRGB(255, 60, 60))
end)

-- Card Anti-Ragdoll / Anti-Stun
local cardRagdoll = Instance.new("Frame")
cardRagdoll.Size = UDim2.new(1, 0, 0, 48)
cardRagdoll.Position = UDim2.new(0, 0, 0, 102)
cardRagdoll.BackgroundColor3 = Color3.fromRGB(28, 25, 32)
cardRagdoll.BackgroundTransparency = 0.5
cardRagdoll.Parent = containerCombate
criarUICorner(cardRagdoll, 6)
criarBorda(cardRagdoll, Color3.fromRGB(255, 255, 255), 0.75)

local lblRagNome = Instance.new("TextLabel")
lblRagNome.Size = UDim2.new(1, -66, 0, 20)
lblRagNome.Position = UDim2.new(0, 8, 0, 4)
lblRagNome.BackgroundTransparency = 1
lblRagNome.Text = "Anti-Ragdoll / Anti-Stun"
lblRagNome.TextXAlignment = Enum.TextXAlignment.Left
lblRagNome.TextColor3 = Color3.fromRGB(255, 255, 255)
aplicarFonte(lblRagNome, 12)
lblRagNome.Parent = cardRagdoll

local lblRagDesc = Instance.new("TextLabel")
lblRagDesc.Size = UDim2.new(1, -66, 0, 18)
lblRagDesc.Position = UDim2.new(0, 8, 0, 24)
lblRagDesc.BackgroundTransparency = 1
lblRagDesc.Text = "Bloqueia quedas, stuns e desmaios"
lblRagDesc.TextXAlignment = Enum.TextXAlignment.Left
lblRagDesc.TextColor3 = Color3.fromRGB(150, 150, 155)
lblRagDesc.Font = Enum.Font.Gotham
lblRagDesc.TextSize = 10
lblRagDesc.Parent = cardRagdoll

local botaoAntiRagdoll = novoBotao(
	cardRagdoll,
	"OFF",
	UDim2.new(0, 52, 0, 24),
	UDim2.new(1, -58, 0.5, -12),
	Color3.fromRGB(50, 50, 56),
	11
)
botaoAntiRagdoll.MouseButton1Click:Connect(function()
	alternarAntiRagdoll(botaoAntiRagdoll)
end)

-- Card informativo de Fling Player
local cardFlingInfo = Instance.new("Frame")
cardFlingInfo.Size = UDim2.new(1, 0, 0, 68)
cardFlingInfo.Position = UDim2.new(0, 0, 0, 158)
cardFlingInfo.BackgroundColor3 = Color3.fromRGB(30, 15, 20)
cardFlingInfo.BackgroundTransparency = 0.5
cardFlingInfo.Parent = containerCombate
criarUICorner(cardFlingInfo, 6)
criarBorda(cardFlingInfo, Color3.fromRGB(255, 80, 80), 0.6)

local lblFlingTitulo = Instance.new("TextLabel")
lblFlingTitulo.Size = UDim2.new(1, -16, 0, 20)
lblFlingTitulo.Position = UDim2.new(0, 8, 0, 4)
lblFlingTitulo.BackgroundTransparency = 1
lblFlingTitulo.Text = "🌪️ Fling Player (Arremessar Alvo)"
lblFlingTitulo.TextXAlignment = Enum.TextXAlignment.Left
lblFlingTitulo.TextColor3 = Color3.fromRGB(255, 90, 90)
aplicarFonte(lblFlingTitulo, 12)
lblFlingTitulo.Parent = cardFlingInfo

local lblFlingDesc = Instance.new("TextLabel")
lblFlingDesc.Size = UDim2.new(1, -16, 0, 36)
lblFlingDesc.Position = UDim2.new(0, 8, 0, 24)
lblFlingDesc.BackgroundTransparency = 1
lblFlingDesc.Text = "Disponível na aba 'Jogadores'. Clique em 'Fling' no cartão do alvo para arremessá-lo a 999.999 studs/s!"
lblFlingDesc.TextXAlignment = Enum.TextXAlignment.Left
lblFlingDesc.TextWrapped = true
lblFlingDesc.TextColor3 = Color3.fromRGB(220, 180, 185)
lblFlingDesc.Font = Enum.Font.Gotham
lblFlingDesc.TextSize = 10
lblFlingDesc.Parent = cardFlingInfo

------------------------------------------------------------
-- ABA 4: JOGADORES (Busca, Barra Espectando, Lista com Scroll)
------------------------------------------------------------
local caixaBusca = Instance.new("TextBox")
caixaBusca.Size = UDim2.new(1, 0, 0, 28)
caixaBusca.Position = UDim2.new(0, 0, 0, 0)
caixaBusca.BackgroundColor3 = Color3.fromRGB(38, 38, 44)
caixaBusca.BackgroundTransparency = 1
caixaBusca.PlaceholderText = "Pesquisar jogador..."
caixaBusca.PlaceholderColor3 = Color3.fromRGB(130, 130, 135)
caixaBusca.Text = ""
caixaBusca.TextColor3 = Color3.fromRGB(255, 255, 255)
aplicarFonte(caixaBusca, 13)
caixaBusca.ClearTextOnFocus = false
caixaBusca.Parent = containerJogadores
criarUICorner(caixaBusca, 6)
caixaBusca.TextXAlignment = Enum.TextXAlignment.Left

local paddingBusca = Instance.new("UIPadding")
paddingBusca.PaddingLeft = UDim.new(0, 10)
paddingBusca.Parent = caixaBusca

-- Barra "Espectando Agora"
local barraEspectando = Instance.new("Frame")
barraEspectando.Size = UDim2.new(1, 0, 0, 28)
barraEspectando.Position = UDim2.new(0, 0, 0, 34)
barraEspectando.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
barraEspectando.BackgroundTransparency = 1
barraEspectando.Visible = false
barraEspectando.Parent = containerJogadores
criarUICorner(barraEspectando, 6)

local labelEspectando = Instance.new("TextLabel")
labelEspectando.Size = UDim2.new(1, -86, 1, 0)
labelEspectando.Position = UDim2.new(0, 10, 0, 0)
labelEspectando.BackgroundTransparency = 1
labelEspectando.TextXAlignment = Enum.TextXAlignment.Left
labelEspectando.Text = "Espectando: -"
labelEspectando.TextColor3 = Color3.fromRGB(255, 255, 255)
aplicarFonte(labelEspectando, 13)
labelEspectando.Parent = barraEspectando

local botaoPararSpec = novoBotao(
	barraEspectando,
	"Parar",
	UDim2.new(0, 70, 0, 20),
	UDim2.new(1, -76, 0, 4),
	Color3.fromRGB(180, 60, 60),
	12
)

-- Scroll da Lista de Jogadores
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, 0, 1, -34)
scrollFrame.Position = UDim2.new(0, 0, 0, 34)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 5
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(90, 90, 95)
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.Parent = containerJogadores

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scrollFrame

-- Ajusta a posição e altura do scroll quando a barra de espectar aparece/some
local function atualizarLayoutFrame()
	if barraEspectando.Visible then
		scrollFrame.Position = UDim2.new(0, 0, 0, 68)
		scrollFrame.Size = UDim2.new(1, 0, 1, -68)
	else
		scrollFrame.Position = UDim2.new(0, 0, 0, 34)
		scrollFrame.Size = UDim2.new(1, 0, 1, -34)
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
local function teleportarAte(alvo, silencioso)
	local myChar = getCharacter(player)
	local myHRP = myChar:WaitForChild("HumanoidRootPart")

	local alvoChar = alvo.Character
	if not alvoChar then
		return
	end
	local alvoHRP = alvoChar:FindFirstChild("HumanoidRootPart")
	if alvoHRP then
		myHRP.CFrame = alvoHRP.CFrame * CFrame.new(0, 0, 3)
		if not silencioso then
			local nomeAlvo = alvo.DisplayName or alvo.Name
			flashVignette(Color3.fromRGB(56, 189, 248))
			shakePainel(6)
			spawnFloatingText("🌀 TP -> " .. nomeAlvo, Color3.fromRGB(56, 189, 248))
			notificar("Teleporte Dimensional", "Viajou instantaneamente até " .. nomeAlvo, "🌀", Color3.fromRGB(56, 189, 248))
		end
	end
end

------------------------------------------------------------
-- AUTO TP / SEGUIR (fica colado no alvo pra sempre)
------------------------------------------------------------
local function pararSeguir()
	if seguindoAlvo then
		local nomeAlvo = seguindoAlvo.DisplayName or seguindoAlvo.Name
		spawnFloatingText("👥 PAROU DE SEGUIR", Color3.fromRGB(52, 211, 153))
		notificar("Rastro de Sombra", "Perseguição encerrada para " .. nomeAlvo, "👥", Color3.fromRGB(52, 211, 153))
	end
	seguindoAlvo = nil
end

local function seguirAte(alvo)
	seguindoAlvo = alvo
	teleportarAte(alvo, true)
	local nomeAlvo = alvo.DisplayName or alvo.Name
	flashVignette(Color3.fromRGB(52, 211, 153))
	spawnFloatingText("👥 SEGUINDO: " .. nomeAlvo, Color3.fromRGB(52, 211, 153))
	notificar("Rastro de Sombra", "Travado em " .. nomeAlvo .. "! Você acompanhará cada passo.", "👥", Color3.fromRGB(52, 211, 153))
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
		if distancia > DISTANCIA_MAXIMA_SEGUIR then
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
		botaoRetornarLocal.Text = "Retornar"
		botaoRetornarLocal.TextColor3 = Color3.fromRGB(255, 255, 255)
	else
		botaoRetornarLocal.Text = "Retornar"
		botaoRetornarLocal.TextColor3 = Color3.fromRGB(140, 140, 145)
	end
end

local function salvarLocal()
	local myChar = getCharacter(player)
	local myHRP = myChar:WaitForChild("HumanoidRootPart")

	posicaoSalva = myHRP.CFrame
	persistirLocal()
	atualizarBotaoRetornar()

	flashVignette(Color3.fromRGB(74, 222, 128))
	spawnFloatingText("🌀 LOCAL SALVO!", Color3.fromRGB(74, 222, 128))
	notificar("Coordenadas Gravadas", "Posição dimensional salva com sucesso!", "🌀", Color3.fromRGB(74, 222, 128))

	botaoSalvarLocal.Text = "Salvo ✓"
	botaoSalvarLocal.TextColor3 = Color3.fromRGB(90, 255, 150)
	task.delay(1.5, function()
		botaoSalvarLocal.Text = "Salvar Local"
		botaoSalvarLocal.TextColor3 = Color3.fromRGB(255, 255, 255)
	end)
end

local function retornarLocal()
	if not posicaoSalva then
		botaoRetornarLocal.Text = "Nada salvo!"
		botaoRetornarLocal.TextColor3 = Color3.fromRGB(255, 120, 120)
		spawnFloatingText("⚠️ NADA SALVO!", Color3.fromRGB(255, 120, 120))
		notificar("Teleporte Dimensional", "Nenhuma coordenada gravada anteriormente!", "⚠️", Color3.fromRGB(255, 120, 120))
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

	flashVignette(Color3.fromRGB(56, 189, 248))
	spawnFloatingText("🌀 RETORNADO!", Color3.fromRGB(56, 189, 248))
	notificar("Teleporte Dimensional", "Você foi puxado de volta às suas coordenadas salvas!", "🌀", Color3.fromRGB(56, 189, 248))
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

	spawnFloatingText("👁️ CÂMERA NORMAL", Color3.fromRGB(168, 85, 247))
	notificar("Modo Espectador", "Câmera retornada ao seu personagem.", "👁️", Color3.fromRGB(168, 85, 247))
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

	local nomeAlvo = alvo.DisplayName or alvo.Name
	flashVignette(Color3.fromRGB(168, 85, 247))
	spawnFloatingText("👁️ ESPECTANDO: " .. nomeAlvo, Color3.fromRGB(168, 85, 247))
	notificar("Modo Espectador", "Observando visão de " .. nomeAlvo, "👁️", Color3.fromRGB(168, 85, 247))
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
		botaoESP.TextColor3 = Color3.fromRGB(90, 255, 150)
		flashVignette(Color3.fromRGB(192, 132, 252))
		spawnFloatingText("👁️ ESP ATIVADO", Color3.fromRGB(192, 132, 252))
		notificar("Visão Espectral (ESP)", "Todos os jogadores revelados através de paredes!", "👁️", Color3.fromRGB(192, 132, 252))
	else
		botaoESP.Text = "ESP: OFF"
		botaoESP.TextColor3 = Color3.fromRGB(255, 255, 255)
		spawnFloatingText("👁️ ESP OFF", Color3.fromRGB(192, 132, 252))
		notificar("Visão Espectral", "ESP Desativado.", "👁️", Color3.fromRGB(192, 132, 252))
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

botaoNoclip.MouseButton1Click:Connect(function()
	noclipAtivo = not noclipAtivo
	if noclipAtivo then
		botaoNoclip.Text = "Noclip: ON"
		botaoNoclip.TextColor3 = Color3.fromRGB(90, 255, 150)
		flashVignette(Color3.fromRGB(56, 189, 248))
		spawnFloatingText("👻 NOCLIP ATIVO", Color3.fromRGB(56, 189, 248))
		notificar("Noclip Dimensional", "Paredes e pisos agora são ilusão!", "👻", Color3.fromRGB(56, 189, 248))
		ativarNoclip()
	else
		botaoNoclip.Text = "Noclip: OFF"
		botaoNoclip.TextColor3 = Color3.fromRGB(255, 255, 255)
		spawnFloatingText("👻 NOCLIP OFF", Color3.fromRGB(56, 189, 248))
		notificar("Noclip Dimensional", "Colisões normais restauradas.", "👻", Color3.fromRGB(56, 189, 248))
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
	spawnFloatingText("Velocidade: " .. valorSpeed, Color3.fromRGB(255, 120, 120))
end)

botaoSpeedMais.MouseButton1Click:Connect(function()
	valorSpeed = math.min(SPEED_MAX, valorSpeed + SPEED_PASSO)
	labelSpeedValor.Text = tostring(valorSpeed)
	aplicarSpeed()
	spawnFloatingText("Velocidade: " .. valorSpeed, Color3.fromRGB(255, 120, 120))
end)

-- Max: Speed direto pro limite máximo
botaoSpeedMax.MouseButton1Click:Connect(function()
	valorSpeed = SPEED_MAX
	labelSpeedValor.Text = tostring(valorSpeed)
	aplicarSpeed()
	flashVignette(Color3.fromRGB(251, 191, 36))
	shakePainel(10)
	spawnFloatingText("🔥 SPEED OVERDRIVE: " .. SPEED_MAX, Color3.fromRGB(251, 191, 36))
	notificar("SPEED OVERDRIVE", "Velocidade no limite máximo de " .. SPEED_MAX .. "!", "🔥", Color3.fromRGB(251, 191, 36))
end)

-- Normal: Speed de volta pro padrão
botaoSpeedNormal.MouseButton1Click:Connect(function()
	valorSpeed = SPEED_NORMAL
	labelSpeedValor.Text = tostring(valorSpeed)
	aplicarSpeed()
	spawnFloatingText("Velocidade: Normal (16)", Color3.fromRGB(200, 200, 200))
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
	spawnFloatingText("Salto: " .. valorJump, Color3.fromRGB(255, 120, 120))
end)

botaoJumpMais.MouseButton1Click:Connect(function()
	valorJump = math.min(JUMP_MAX, valorJump + JUMP_PASSO)
	labelJumpValor.Text = tostring(valorJump)
	aplicarJump()
	spawnFloatingText("Salto: " .. valorJump, Color3.fromRGB(255, 120, 120))
end)

-- Max: Salto direto pro limite máximo
botaoJumpMax.MouseButton1Click:Connect(function()
	valorJump = JUMP_MAX
	labelJumpValor.Text = tostring(valorJump)
	aplicarJump()
	flashVignette(Color3.fromRGB(251, 191, 36))
	shakePainel(10)
	spawnFloatingText("🔥 SALTO OVERDRIVE: " .. JUMP_MAX, Color3.fromRGB(251, 191, 36))
	notificar("SALTO OVERDRIVE", "Salto no limite máximo de " .. JUMP_MAX .. "!", "🔥", Color3.fromRGB(251, 191, 36))
end)

-- Normal: Salto de volta pro padrão
botaoJumpNormal.MouseButton1Click:Connect(function()
	valorJump = JUMP_NORMAL
	labelJumpValor.Text = tostring(valorJump)
	aplicarJump()
	spawnFloatingText("Salto: Normal (50)", Color3.fromRGB(200, 200, 200))
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
	botaoFlyToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
	spawnFloatingText("🦅 FLY OFF", Color3.fromRGB(56, 189, 248))
	notificar("Modo Voo", "Voo desativado.", "🦅", Color3.fromRGB(56, 189, 248))
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
	botaoFlyToggle.TextColor3 = Color3.fromRGB(90, 255, 150)

	flashVignette(Color3.fromRGB(56, 189, 248))
	spawnFloatingText("🦅 FLY ATIVADO", Color3.fromRGB(56, 189, 248))
	notificar("Modo Voo (Fly)", "Use WASD, Espaço e Ctrl para voar livremente!", "🦅", Color3.fromRGB(56, 189, 248))

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
	spawnFloatingText("Voo: " .. valorFlySpeed, Color3.fromRGB(56, 189, 248))
end)

botaoFlySpeedMais.MouseButton1Click:Connect(function()
	valorFlySpeed = math.min(FLYSPEED_MAX, valorFlySpeed + FLYSPEED_PASSO)
	labelFlySpeedValor.Text = tostring(valorFlySpeed)
	spawnFloatingText("Voo: " .. valorFlySpeed, Color3.fromRGB(56, 189, 248))
end)

-- Max: velocidade do fly direto pro limite máximo
botaoFlyMax.MouseButton1Click:Connect(function()
	valorFlySpeed = FLYSPEED_MAX
	labelFlySpeedValor.Text = tostring(valorFlySpeed)
	flashVignette(Color3.fromRGB(56, 189, 248))
	shakePainel(10)
	spawnFloatingText("🚀 VOO OVERDRIVE: " .. FLYSPEED_MAX, Color3.fromRGB(56, 189, 248))
	notificar("VOO OVERDRIVE", "Velocidade de voo no máximo de " .. FLYSPEED_MAX .. "!", "🚀", Color3.fromRGB(56, 189, 248))
end)

-- Normal: velocidade do fly de volta pro padrão
botaoFlyNormal.MouseButton1Click:Connect(function()
	valorFlySpeed = FLYSPEED_NORMAL
	labelFlySpeedValor.Text = tostring(valorFlySpeed)
	spawnFloatingText("Voo: Normal (50)", Color3.fromRGB(200, 200, 200))
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
local LARGURA_BOTAO_ACAO = math.floor((LARGURA_LINHA_INTERNA - 12) / 4) -- 4 botões (TP, Spec, Seguir, Fling)

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
		linha.BackgroundTransparency = 1 -- cartão invisível: foto, nome e botões flutuam sobre a arte
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
		aplicarFonte(nomeLabel, 15)
		nomeLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nomeLabel.TextStrokeTransparency = 0.5 -- contorno sutil pra ler sobre a arte
		nomeLabel.Parent = linha

		-- Estrela de favorito, no canto superior direito do cartão
		local ehFavorito = favoritos[outroPlayer.UserId] == true
		local botaoFavorito = Instance.new("TextButton")
		botaoFavorito.Size = UDim2.new(0, LARGURA_ESTRELA, 0, LARGURA_ESTRELA)
		botaoFavorito.Position = UDim2.new(1, -(LARGURA_ESTRELA + 6), 0, 6)
		botaoFavorito.BackgroundTransparency = 1
		botaoFavorito.TextStrokeTransparency = 0.5 -- contorno pra ler sobre a arte
		botaoFavorito.Text = ehFavorito and "★" or "☆"
		botaoFavorito.TextColor3 = ehFavorito and Color3.fromRGB(255, 210, 60) or Color3.fromRGB(140, 140, 145)
		botaoFavorito.Font = Enum.Font.GothamBold
		botaoFavorito.TextSize = 20
		botaoFavorito.Parent = linha

		-- Linha de botões de ação (TP / Spec / Seguir / Fling), largura igual entre os quatro
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
		botaoSeguir.TextColor3 = seguindoEsse and Color3.fromRGB(90, 255, 150) or Color3.fromRGB(255, 255, 255)

		local botaoFling = novoBotao(
			linha,
			"Fling",
			UDim2.new(0, LARGURA_BOTAO_ACAO, 0, 26),
			UDim2.new(0, 6 + (LARGURA_BOTAO_ACAO + 4) * 3, 0, Y_ACOES),
			Color3.fromRGB(150, 40, 40),
			12
		)
		botaoFling.TextColor3 = Color3.fromRGB(255, 90, 90)
		criarBorda(botaoFling, Color3.fromRGB(255, 60, 60), 0.6)

		botaoTP.MouseButton1Click:Connect(function()
			teleportarAte(outroPlayer)
		end)

		botaoSpec.MouseButton1Click:Connect(function()
			espectarAte(outroPlayer)
		end)

		botaoFavorito.MouseButton1Click:Connect(function()
			local nomeAlvo = outroPlayer.DisplayName or outroPlayer.Name
			if favoritos[outroPlayer.UserId] then
				favoritos[outroPlayer.UserId] = nil
				spawnFloatingText("☆ DESAFIXADO", Color3.fromRGB(160, 160, 170))
				notificar("Lista de Favoritos", nomeAlvo .. " removido dos favoritos.", "☆", Color3.fromRGB(160, 160, 170))
			else
				favoritos[outroPlayer.UserId] = true
				flashVignette(Color3.fromRGB(250, 204, 21))
				spawnFloatingText("★ FAVORITO FIXADO!", Color3.fromRGB(250, 204, 21))
				notificar("Lista de Favoritos", nomeAlvo .. " fixado no topo da lista!", "★", Color3.fromRGB(250, 204, 21))
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

		botaoFling.MouseButton1Click:Connect(function()
			flingPlayer(outroPlayer)
		end)

		conectarRespawnEspectado(outroPlayer)
	end
end

Players.PlayerAdded:Connect(atualizarLista)
Players.PlayerRemoving:Connect(atualizarLista)

-- Atualiza a lista em tempo real conforme a pessoa digita na busca
caixaBusca:GetPropertyChangedSignal("Text"):Connect(atualizarLista)

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

	-- Limpeza dos Novos Recursos VIP
	if antiAfkConexao then
		antiAfkConexao:Disconnect()
		antiAfkConexao = nil
	end
	if jesusHeartbeat then
		jesusHeartbeat:Disconnect()
		jesusHeartbeat = nil
	end
	if jesusPlataforma then
		jesusPlataforma:Destroy()
		jesusPlataforma = nil
	end
	if ghostModeAtivo then
		alternarGhostMode()
	end
	if hitboxAtiva then
		alternarHitbox()
	end
	if antiRagdollConexao then
		antiRagdollConexao:Disconnect()
		antiRagdollConexao = nil
	end

	-- 3) some com tudo (painel + botão flutuante + navegador de servidores + toasts)
	if janelaServidores and janelaServidores.Parent then
		janelaServidores:Destroy()
	end
	if toastContainer and toastContainer.Parent then
		toastContainer:Destroy()
	end
	if screenGui then
		screenGui:Destroy()
	end

	print("[PainelTP] Painel desinjetado. Rode o loadstring de novo pra reabrir.")
end
