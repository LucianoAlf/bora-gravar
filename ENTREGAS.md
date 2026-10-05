# Entregas multi-eventos — LA Music

Esta é a plataforma padrão para entregar fotos e vídeos de qualquer evento novo. Ela usa o
mesmo projeto Supabase do Camarim, mas tabelas, arquivos, painel e rotas separados. O fluxo
antigo do Julina Rock Fest permanece intacto.

## Como funciona

1. O CRM continua sendo a fonte comercial: interessado, contato, contrato e pagamento.
2. A Mesa de Entregas consulta o CRM e importa apenas alunos com contrato fechado. No Vocal
   Kids, isso acontece ao entrar, a cada cinco minutos enquanto o painel estiver aberto e ao
   voltar para a aba; o botão de atualização manual continua disponível.
3. Cada aluno ou família recebe uma entrega própria. Irmãos podem ficar no mesmo link.
4. A equipe envia fotos e vídeos já separados para aquela entrega.
5. Depois de revisar, publica e libera a entrega.
6. O responsável abre `https://camarim-la-music.vercel.app/e/<chave>/` e vê somente aquele
   conteúdo, sem criar conta ou digitar senha.

O CRM nunca recebe alterações desta plataforma. A integração é de leitura e só devolve os
campos necessários para a entrega: aluno, responsável, telefone, unidade, foto, contrato e
pagamento.

## Componentes

| Componente | Função |
|---|---|
| `mesa-de-entregas.html` | Painel privado para sincronizar, subir material e liberar links |
| `site/entrega.html` | Página simples dos pais, otimizada para celular |
| `functions/entrega` | Valida a chave e cria links temporários para arquivos privados |
| `functions/entregas-admin` | Consulta o endpoint privado do CRM e atualiza os rascunhos |
| bucket `entregas` | Arquivos privados, organizados por evento e entrega |

As tabelas novas são `eventos`, `entregas`, `entrega_participantes`, `entrega_midias` e
`entrega_acessos`. O acesso direto anônimo está bloqueado por RLS. O visitante só chega ao
conteúdo pela Edge Function e por uma chave longa e não sequencial. Os links dos arquivos
expiram em uma hora.

## Operação do Vocal Kids

1. Abra `mesa-de-entregas.html` e entre com um dos logins administrativos do Camarim.
2. Selecione **Vocal Kids Sandy e Junior**.
3. Clique em **Consultar CRM** para trazer novos contratantes e atualizar os já existentes.
4. Abra o aluno, confirme nome, unidade e eventuais irmãos.
5. Envie as fotos e os vídeos separados daquele aluno.
6. Clique em **Publicar** quando a página estiver revisada.
7. Clique em **Liberar entrega** quando ela puder ser enviada à família.
8. Use **Copiar link** e envie pelo WhatsApp.

O sincronizador não apaga entregas nem sobrescreve participantes extras adicionados
manualmente. Eventos novos começam sem integração para não receberem alunos do evento errado.
Divergências devem ser revisadas no painel antes da publicação.

## Criar o próximo evento

Na Mesa de Entregas, use **Novo evento** e informe nome, data e local. O restante do fluxo é o
mesmo. Só será preciso uma integração adicional se o novo evento usar outra fonte de clientes;
para cadastro manual, não há trabalho de programação.

## Segurança e segredos

- A `service_role`, o token de administração e os segredos da integração nunca entram no
  navegador nem no Git.
- `CAMARIM_SYNC_SECRET`, `CRM_SITES_BYPASS_TOKEN` e `CRM_API_URL` vivem somente nos segredos
  das Edge Functions.
- O bucket `entregas` é privado.
- O link da família é uma credencial: deve ser enviado somente ao responsável.
- Revogar uma entrega bloqueia imediatamente a página, sem apagar os arquivos.

## Publicação

O `vercel.json` publica somente `site/` e reescreve `/e/<chave>/` para `entrega.html`. O painel
administrativo não é publicado e continua sendo aberto localmente pela equipe.

Para alterações de banco, crie uma migration nova. Para alterações de funções, publique apenas
a função modificada e repita os testes de acesso anônimo e de pertencimento do arquivo.
