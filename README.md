# VideoGrabber

App iOS (SwiftUI, iOS 17+) + backend pessoal (FastAPI + yt-dlp + ffmpeg) para baixar vídeos do YouTube que você tem direito de baixar e assisti-los offline no iPhone.

> **Aviso legal.** Este projeto é para **uso pessoal**, com conteúdo que você tem direito de baixar (próprio, licenciado ou com permissão). Baixar vídeos do YouTube pode violar os Termos de Serviço da plataforma e direitos autorais. O projeto não contorna DRM nem acessa conteúdo privado, com login ou pago. **Não** será publicado na App Store: a instalação é direta pelo Xcode no seu aparelho (com conta gratuita o app expira em 7 dias) ou por assinatura pessoal.

## Estado

| Fase | Situação |
|---|---|
| 1 — Backend | ✅ Concluída: pytest + imagem Docker no CI; download real (720p H.264/AAC e M4A, Range 206) validado |
| 2 — Esqueleto do app | ✅ Build + testes verdes no CI, 0 warnings. Falta testar no iPhone |
| 3 — Resolver e baixar | ✅ Build + 52 testes + XCUITest do fluxo verdes no CI, 0 warnings. Falta testar no iPhone |
| 4–7 — App iOS | ⏳ |

O app é compilado num Mac na nuvem (GitHub Actions). Cada build bem-sucedido gera o artefato **VideoGrabber-ipa**, que é instalado no iPhone pelo [Sideloadly](https://sideloadly.io) (veja "Instalar no iPhone sem Mac", abaixo).

## Backend

### Rodar com Docker

```bash
cd backend
cp .env.example .env
# edite .env e defina API_TOKEN (gere com: python -c "import secrets; print(secrets.token_urlsafe(32))")
docker compose up --build
```

O serviço fica em `http://<ip-da-máquina>:8080`. Teste rápido:

```bash
TOKEN=...   # o mesmo do .env
curl http://localhost:8080/health
curl -X POST http://localhost:8080/v1/resolve -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" -d '{"url":"https://www.youtube.com/watch?v=jNQXAC9IVRw"}'
JOB=$(curl -s -X POST http://localhost:8080/v1/jobs -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" -d '{"url":"https://www.youtube.com/watch?v=jNQXAC9IVRw","preset_id":"mp4_720"}' \
     | python3 -c "import sys,json; print(json.load(sys.stdin)['job_id'])")
curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/v1/jobs/$JOB          # repita até status=ready
curl -H "Authorization: Bearer $TOKEN" -H "Range: bytes=0-1023" -o parte.bin -D - \
     http://localhost:8080/v1/jobs/$JOB/file                                       # 206 Partial Content
curl -X DELETE -H "Authorization: Bearer $TOKEN" http://localhost:8080/v1/jobs/$JOB
```

O contrato completo está em [docs/API.md](docs/API.md).

### Rodar no Windows sem Docker

Com o `.venv` criado (veja "Testes" abaixo), o `.env` preenchido e o **ffmpeg** instalado (`winget install Gyan.FFmpeg`), dê dois cliques em [backend/iniciar-servidor.bat](backend/iniciar-servidor.bat). Ele sobe o servidor na porta 8080 e mostra o endereço para usar no app.

> Não exponha a porta 8080 na internet (port forwarding no roteador). Para acessar de fora de casa, use uma VPN como o Tailscale.

### Testes

```bash
cd backend
python -m venv .venv
.venv/bin/pip install -r requirements-dev.txt     # Windows: .venv\Scripts\pip
.venv/bin/pytest
```

Os testes substituem o yt-dlp por um falso e não acessam a rede.

### Atualizar o yt-dlp

O yt-dlp quebra com frequência quando o YouTube muda. Sintoma: `502 extractor_failed`. Para atualizar:

1. Troque a versão em `backend/requirements.txt` (`yt-dlp[default,deno]==<nova>`). Veja as versões em https://github.com/yt-dlp/yt-dlp/releases.
2. `docker compose up --build -d`
3. Confira a versão em `GET /health` (ou em Ajustes → "Testar conexão" no app).

## App iOS

### Build e testes

Num Mac com Xcode e XcodeGen:

```bash
cd ios && xcodegen generate
xcodebuild -scheme VideoGrabber -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Sem Mac, o workflow [.github/workflows/ios.yml](.github/workflows/ios.yml) faz o mesmo a cada push em `ios/` e publica o `.ipa`.

### Instalar no iPhone sem Mac

1. Instale no Windows o **iTunes** e o **iCloud** (versões do site da Apple, não precisa entrar na conta) e o **Sideloadly**.
2. Baixe o artefato **VideoGrabber-ipa** do último build verde em *Actions → iOS* e descompacte o `.zip`.
3. Ligue o iPhone no cabo, toque em **Confiar** no iPhone, arraste o `VideoGrabber.ipa` para o Sideloadly, digite seu Apple ID e clique em **Start**.
4. Na primeira vez, no iPhone: *Ajustes → Privacidade e Segurança → Modo de Desenvolvedor* (ativar e reiniciar) e *Ajustes → Geral → VPN e Gerenciamento de Dispositivo → seu e-mail → Confiar*.
5. Com Apple ID gratuito o app expira em **7 dias**: repita o passo 3 (os dados do app são mantidos).

## Documentação

- [HOW-TO-USE.md](HOW-TO-USE.md): **guia para leigos**, da instalação no iPhone ao uso do app
- [docs/API.md](docs/API.md): contrato do backend
- [docs/DECISIONS.md](docs/DECISIONS.md): decisões tomadas durante a implementação
- [CLAUDE.md](CLAUDE.md): especificação do projeto
