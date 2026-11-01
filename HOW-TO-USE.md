# Como usar o VideoGrabber

Guia passo a passo, sem termos técnicos, para instalar o VideoGrabber no iPhone e usá-lo no dia a dia.

> 📌 **Situação atual do app:** já dá para instalar o app, configurar e **testar a conexão** com o computador. A parte de **colar um link e baixar vídeos** está sendo construída agora; este guia mostra como ela vai funcionar e será atualizado quando ela chegar.

---

## Sumário

1. [Como o VideoGrabber funciona](#1-como-o-videograbber-funciona)
2. [Antes de começar: aviso importante](#2-antes-de-começar-aviso-importante)
3. [O que você precisa](#3-o-que-você-precisa)
4. [Preparar o computador (só uma vez)](#4-preparar-o-computador-só-uma-vez)
5. [Ligar o servidor (toda vez que for baixar)](#5-ligar-o-servidor-toda-vez-que-for-baixar)
6. [Instalar o app no iPhone](#6-instalar-o-app-no-iphone)
7. [Conectar o app ao computador](#7-conectar-o-app-ao-computador)
8. [Usar o app](#8-usar-o-app)
9. [A cada 7 dias: renovar o app](#9-a-cada-7-dias-renovar-o-app)
10. [Deu problema? Veja aqui](#10-deu-problema-veja-aqui)
11. [Cuidados de segurança](#11-cuidados-de-segurança)
12. [Pequeno dicionário](#12-pequeno-dicionário)

---

## 1. Como o VideoGrabber funciona

O VideoGrabber tem **duas partes** que trabalham juntas:

```
   📱 iPhone (app VideoGrabber)          💻 Computador (servidor)
   ─────────────────────────────         ──────────────────────────
   Você cola o link do YouTube   ──▶     Busca o vídeo no YouTube
                                         e prepara o arquivo
   Recebe o vídeo pronto         ◀──     Entrega o arquivo ao iPhone
   e guarda na Biblioteca
```

- O **iPhone** não consegue baixar do YouTube sozinho (a Apple não permite). Por isso quem faz o trabalho pesado é o **computador**.
- O computador precisa estar **ligado**, com o **servidor aberto**, e os dois precisam estar **no mesmo Wi-Fi** enquanto você baixa.
- Depois que o vídeo está no iPhone, você assiste **sem internet** e com o computador desligado.

---

## 2. Antes de começar: aviso importante

⚠️ Use o VideoGrabber **somente** com vídeos que você tem direito de baixar: vídeos seus, com licença livre ou com permissão do autor.

Baixar vídeos do YouTube pode violar as regras do YouTube e os direitos autorais de quem fez o vídeo. O app **não** baixa vídeos privados, pagos, ao vivo ou protegidos.

---

## 3. O que você precisa

| Item | Para quê |
|---|---|
| 💻 Um computador com **Windows** | Roda o servidor |
| 📱 Um **iPhone** com iOS 17 ou mais novo | Onde o app fica |
| 🔌 O **cabo** do iPhone | Para instalar o app (só na instalação) |
| 📶 Um **Wi-Fi** | O iPhone e o computador conversam por ele |
| 🍎 Um **Apple ID** | A conta da Apple (a mesma da App Store). Ela "assina" o app para o iPhone aceitar |

Não precisa pagar nada.

> 💡 **Como ver a versão do iOS:** no iPhone, abra **Ajustes › Geral › Sobre** e veja "Versão do iOS".

---

## 4. Preparar o computador (só uma vez)

Você faz esta parte **uma única vez**. Se alguém já preparou o computador para você, pule para a [seção 5](#5-ligar-o-servidor-toda-vez-que-for-baixar).

### 4.1 Instalar iTunes e iCloud (versões "do site")

O programa que instala o app no iPhone (o Sideloadly) precisa de peças que vêm junto com o **iTunes** e o **iCloud**.

- ⚠️ Use as versões **baixadas do site da Apple** (instalador `.exe`), **não** as da Microsoft Store. As da Store ficam "trancadas" e o Sideloadly não consegue usá-las.
- Os links certos estão na página de download do Sideloadly: **sideloadly.io**.
- Se você já tiver o iCloud da Microsoft Store, desinstale primeiro: **Configurações do Windows › Aplicativos › iCloud › Desinstalar**.
- **Não precisa entrar na sua conta** no iTunes nem no iCloud. Só precisam estar instalados.
- Depois de instalar, **reinicie o computador**.

### 4.2 Instalar o Sideloadly

Baixe e instale o **Sideloadly** em **sideloadly.io** (use sempre a versão mais recente).

### 4.3 O servidor

O servidor fica na pasta do projeto, em `backend`. Ele já vem com:

- o arquivo **`iniciar-servidor.bat`**, que liga o servidor com dois cliques;
- o arquivo **`.env`**, que guarda o seu **token** (a "senha" que o app usa para falar com o servidor).

> 🔧 Se for montar o servidor do zero em outro computador, quem for instalar deve seguir a seção "Backend" do `README.md`.

---

## 5. Ligar o servidor (toda vez que for baixar)

1. Abra a pasta do projeto e entre em **`backend`**.
2. Dê **dois cliques** em **`iniciar-servidor.bat`**.
3. Vai abrir uma janela preta mostrando algo assim:

   ```
     No app do iPhone, em Ajustes, use um destes enderecos:
         192.168.1.120:8080    (Ethernet)
   ```

   Esse é o **endereço do servidor**. Anote: você vai usá-lo no iPhone.
4. **Deixe essa janela aberta** enquanto estiver usando o app. Pode minimizar, mas não feche.
5. Para desligar o servidor, é só **fechar a janela**.

> 🛡️ **Na primeira vez**, o Windows pode mostrar o aviso **"O Firewall do Windows Defender bloqueou alguns recursos deste aplicativo"**. Marque **Redes privadas** e clique em **Permitir acesso**. Sem isso, o iPhone não consegue falar com o computador.

> 💡 O endereço pode mudar se o roteador for reiniciado. Se o app parar de conectar, confira o endereço nessa janela e atualize no app.

---

## 6. Instalar o app no iPhone

### 6.1 Pegar o arquivo do app (`VideoGrabber.ipa`)

O arquivo do app se chama **`VideoGrabber.ipa`**.

- Se alguém já te entregou o arquivo (por exemplo, na pasta `dist` do projeto), use esse.
- Para pegar a versão mais nova na internet:
  1. Acesse **github.com/Vanelli-afk/video-grabber**.
  2. Clique na aba **Actions** e depois em **iOS**, na lista da esquerda.
  3. Clique na execução mais recente que tenha um **✓ verde**.
  4. Role até **Artifacts** e clique em **VideoGrabber-ipa**. Vai baixar um `.zip`. Isso exige estar logado no GitHub.
  5. Abra o `.zip` e tire de dentro o arquivo **`VideoGrabber.ipa`**.

### 6.2 Instalar com o Sideloadly

1. Ligue o iPhone no computador **pelo cabo** e desbloqueie a tela.
2. Se aparecer no iPhone **"Confiar neste computador?"**, toque em **Confiar** e digite o código do iPhone.
3. Abra o **Sideloadly**. O seu iPhone deve aparecer no campo de dispositivos.
4. **Arraste** o arquivo `VideoGrabber.ipa` para dentro da janela do Sideloadly.
5. No campo **Apple ID**, digite o e-mail da sua conta Apple.
6. Clique em **Start**.
7. Digite a **senha** do Apple ID quando pedir. Se você usa verificação em duas etapas, digite também o **código de 6 dígitos** que aparece nos seus aparelhos Apple.
8. Aguarde até aparecer **"Done"**. O ícone do VideoGrabber aparece no iPhone.

### 6.3 Liberar o app no iPhone (só na primeira vez)

O iPhone bloqueia apps que não vieram da App Store até você liberar.

1. **Ativar o Modo de Desenvolvedor**
   - Abra **Ajustes › Privacidade e Segurança**.
   - Role até o fim e toque em **Modo de Desenvolvedor**.
   - Ative a chave. O iPhone vai pedir para **reiniciar**: aceite.
   - Depois de reiniciar, confirme tocando em **Ativar** e digite o código do iPhone.
   - 💡 Essa opção só aparece **depois** da primeira instalação pelo Sideloadly.
2. **Confiar no seu perfil**
   - Abra **Ajustes › Geral › VPN e Gerenciamento de Dispositivo**.
   - Toque no seu e-mail (em "App de Desenvolvedor").
   - Toque em **Confiar** e confirme.

Pronto: agora o app abre normalmente.

---

## 7. Conectar o app ao computador

### 7.1 Passar o token para o iPhone

O token é uma senha longa, com letras e números misturados (algo como `Xk3vQ9pL...`). Ele fica no computador, no arquivo **`backend\.env`**, na linha que começa com `API_TOKEN=`.

Para não precisar digitar letra por letra:

1. No computador, abra o arquivo `.env` com o **Bloco de Notas** (clique com o botão direito › Abrir com › Bloco de Notas).
2. Copie **só o que vem depois** de `API_TOKEN=`.
3. Mande para você mesmo, por exemplo pelo **WhatsApp ("Mensagem para mim")**, por e-mail ou pelas Notas do iCloud.
4. No iPhone, abra a mensagem e **copie** o token.

> 🔒 Depois de configurar, você pode apagar essa mensagem. O app guarda o token em um cofre seguro do iPhone (o Keychain).

### 7.2 Preencher os Ajustes

1. Confirme que o iPhone está **no mesmo Wi-Fi** do computador.
2. Abra o **VideoGrabber**.
3. Na aba **Adicionar**, toque na **engrenagem ⚙️** no canto superior direito.
4. Em **Endereço do servidor**, digite o endereço que apareceu na janela do servidor (ex.: `192.168.1.120:8080`).
5. Em **Token de acesso**, toque e **cole** o token.
6. Toque em **Testar conexão**.

### 7.3 A permissão de "Rede Local"

Na primeira vez, o iPhone pergunta se o VideoGrabber pode **"encontrar e se conectar a dispositivos na rede local"**. Toque em **Permitir**: é assim que ele acha o computador.

> 💡 Se o teste falhar **logo depois** de aparecer essa pergunta, é normal: toque em **Testar conexão** de novo.

### 7.4 O resultado

| O app mostra | Significado |
|---|---|
| ✅ **Conectado · yt-dlp 2026.10.26** | Tudo certo! O número é a versão da ferramenta que baixa os vídeos |
| ⚠️ Uma mensagem em vermelho | Veja a [seção 10](#10-deu-problema-veja-aqui) |

---

## 8. Usar o app

O app tem **três abas** na parte de baixo da tela:

| Aba | Para que serve |
|---|---|
| ➕ **Adicionar** | Colar um link do YouTube e escolher como baixar. A engrenagem ⚙️ abre os **Ajustes** |
| ⬇️ **Fila** | Acompanhar os downloads em andamento |
| ▶️ **Biblioteca** | Ver e assistir os vídeos já baixados |

### Ajustes ⚙️ (já funciona)

- **Endereço do servidor** e **Token de acesso**: veja a [seção 7](#7-conectar-o-app-ao-computador).
- **Testar conexão**: confere se o app está falando com o computador.
- **Qualidade padrão**: a qualidade sugerida em todo download:
  - **Melhor qualidade (até 1080p)**: imagem mais bonita, arquivo maior.
  - **720p**: boa imagem, arquivo menor. Bom para economizar espaço.
  - **Somente áudio (M4A)**: só o som. Ótimo para músicas, aulas e podcasts.

### Baixar um vídeo (em construção 🚧)

Quando essa parte chegar, o caminho será:

1. No **YouTube**, toque em **Compartilhar › Copiar link**.
2. No VideoGrabber, aba **Adicionar**, toque em **Colar da área de transferência** e depois em **Buscar**.
3. Confira a miniatura, o título e a duração. Escolha a qualidade e toque em **Baixar**.
4. Acompanhe na aba **Fila**. Pode sair do app, que o download continua e você recebe um aviso quando terminar.
5. O vídeo aparece na **Biblioteca**. Toque para assistir. Segure o dedo sobre ele para **Salvar em Fotos**, **Compartilhar** ou **Apagar**.

Também vai dar para mandar o link direto do YouTube ou do Safari: **Compartilhar › VideoGrabber**.

> Por enquanto, o VideoGrabber aparece no menu "Compartilhar" do iPhone, mas ainda não faz nada ao ser tocado. Isso é esperado nesta versão.

---

## 9. A cada 7 dias: renovar o app

Com um Apple ID gratuito, a Apple permite usar o app por **7 dias**. Depois disso ele **não abre mais** até ser renovado.

**Para renovar**, repita a [seção 6.2](#62-instalar-com-o-sideloadly) com o mesmo arquivo `VideoGrabber.ipa`:

- ✅ Seus vídeos e ajustes **não se perdem**.
- ✅ Não precisa repetir a seção 6.3 (Modo de Desenvolvedor).

> 💡 O Sideloadly tem uma opção de **renovação automática** pelo Wi-Fi, que funciona com o computador ligado e no mesmo Wi-Fi. Procure por "Automatic refresh" nas opções do Sideloadly.

---

## 10. Deu problema? Veja aqui

### Mensagens do app

| Mensagem | O que fazer |
|---|---|
| **"Não foi possível alcançar o servidor"** | 1) O servidor está ligado (janela preta aberta)? 2) O endereço está igual ao da janela do servidor? 3) iPhone e computador estão no mesmo Wi-Fi? 4) O Firewall do Windows está liberado? (veja a [seção 5](#5-ligar-o-servidor-toda-vez-que-for-baixar)) |
| **"Sem conexão…"** | Confira o Wi-Fi do iPhone. Depois abra **Ajustes do iPhone › Privacidade e Segurança › Rede Local** e confirme que o **VideoGrabber** está **ligado** |
| **"Token de acesso inválido"** | O token está errado. Copie de novo do arquivo `.env` (sem espaços antes ou depois) e cole no app |
| **"Configure o endereço do servidor e o token em Ajustes"** | Falta preencher algum campo nos Ajustes |
| **"Vídeo indisponível, privado ou com restrição de acesso"** | O vídeo foi apagado, é privado, exige login ou idade. Não dá para baixar |
| **"Conteúdo não suportado"** | É uma playlist, uma transmissão ao vivo ou um conteúdo protegido. Use o link de **um único vídeo** |
| **"O YouTube bloqueou temporariamente este servidor"** | O YouTube desconfiou do computador. Espere algumas horas ou use outra internet |
| **"Falha ao extrair o vídeo. Tente atualizar o yt-dlp"** | O YouTube mudou algo e a ferramenta precisa ser atualizada. Veja "Atualizar o yt-dlp" no `README.md` ou peça para quem instalou |

### Problemas na instalação

| Problema | O que fazer |
|---|---|
| O Sideloadly diz que precisa da **"versão web" do iTunes/iCloud** | Você está com as versões da Microsoft Store. Veja a [seção 4.1](#41-instalar-itunes-e-icloud-versões-do-site) |
| O Sideloadly **não mostra o iPhone** | Desbloqueie o iPhone, toque em **Confiar**, troque o cabo ou a porta USB e reinicie o computador |
| O iPhone diz **"Desenvolvedor não confiável"** | Faça a [seção 6.3, passo 2](#63-liberar-o-app-no-iphone-só-na-primeira-vez) |
| O app **parou de abrir** depois de alguns dias | Passaram os 7 dias. Veja a [seção 9](#9-a-cada-7-dias-renovar-o-app) |
| O Sideloadly mostra erro com a **senha** | Confira o Apple ID e a senha. Se você usa verificação em duas etapas, tenha o outro aparelho Apple por perto para ver o código |

---

## 11. Cuidados de segurança

- 🔑 **O token é como uma senha.** Não publique e não mande para outras pessoas. Quem tiver o token e estiver na sua rede pode usar o seu servidor.
- 🏠 **Use em casa, numa rede de confiança.** Não "abra a porta 8080" no roteador para acessar de fora: o servidor não foi feito para ficar exposto na internet.
- 🍎 **Sobre o Apple ID no Sideloadly:** o Sideloadly é um programa de terceiros e recebe a sua senha da Apple para assinar o app. Muita gente usa um **Apple ID secundário**, criado só para isso, por precaução. Funciona igual.
- ⚖️ Lembre-se do [aviso da seção 2](#2-antes-de-começar-aviso-importante): baixe apenas o que você tem direito.

---

## 12. Pequeno dicionário

| Palavra | O que significa |
|---|---|
| **Servidor** | O programa que roda no computador e faz o download do YouTube para o app |
| **Token** | Uma senha longa que prova ao servidor que é o seu app pedindo |
| **Endereço (IP)** | O "número da casa" do computador na sua rede Wi-Fi, como `192.168.1.120:8080` |
| **`.ipa`** | O arquivo de instalação de um app de iPhone |
| **Sideloadly** | O programa do Windows que instala o `.ipa` no iPhone sem a App Store |
| **Apple ID** | A sua conta da Apple (a mesma da App Store e do iCloud) |
| **Modo de Desenvolvedor** | Uma opção do iPhone que permite abrir apps instalados fora da App Store |
| **yt-dlp** | A ferramenta que o servidor usa para buscar vídeos no YouTube |
| **Keychain** | O cofre seguro do iPhone onde o app guarda o token |
