# Windows Deep Cleaner (PowerShell + WPF)

Aplicação desktop para limpeza profunda e segura de disco no Windows, construída inteiramente em PowerShell com interface gráfica WPF (XAML).

## Problema
Scripts de limpeza tradicionais rodam no console, não possuem interface amigável para o usuário final e, muitas vezes, travam o terminal ou apresentam riscos ao sistema (como seguir links simbólicos acidentalmente).

## Solução
Uma ferramenta visual (GUI) completa que permite ao usuário escolher o nível de limpeza (Rápida, Padrão, Profunda ou Personalizada) e gerenciar perfis de usuário obsoletos. 

### Destaques Técnicos e Segurança

1. **Interface Gráfica (WPF/XAML):** Construída diretamente no PowerShell, com animações, barras de progresso e design responsivo.
2. **Execução Assíncrona (Runspaces):** Uso de `[runspacefactory]` para rodar tarefas pesadas (como o DISM e o cálculo de tamanho de pastas) em background, evitando o congelamento da interface.
3. **Proteção contra Junction Points:** O script ignora links simbólicos nativos do Windows (`-Attributes !ReparsePoint`), evitando a exclusão acidental de arquivos do sistema.
4. **Blacklist de Serviços:** Proteção nativa que impede a exclusão de perfis de serviço cruciais (SQL, IIS, systemprofile, etc.).
5. **Ponto de Restauração:** Criação automática de um checkpoint do sistema antes de qualquer operação destrutiva.
6. **Limpeza via DISM:** Executa rotinas de `StartComponentCleanup` para remover arquivos obsoletos do Windows Update.

## Funcionalidades
- Limpeza de arquivos temporários (Sistema e Usuários).
- Limpeza de caches de navegadores (Chrome, Edge).
- Esvaziamento da Lixeira e logs do Windows Error Reporting (WER).
- Cache do Windows Update e BITS.
- Gerenciamento visual de perfis de usuário (com cálculo de espaço em tempo real).
- Limpeza de componentes obsoletos via DISM.

## Como usar
Requer privilégios de Administrador.

```powershell
# Executar o script
.\Cleaner.ps1
