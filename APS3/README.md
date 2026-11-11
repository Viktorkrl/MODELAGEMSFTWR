# Dossiê de Arquitetura Viva e Modelagem Comportamental as-Code
### Avaliação Prática Supervisionada (APS 3) — Individual (10% da Média Semestral)
**Curso:** Engenharia de Software (4º Período) — UniSenai  
**Unidade Curricular:** Modelagem de Software  
**Docente:** Prof. Sidney L. da Silva  
**Estudante:** Vitor Silva  
**Repositório Oficial:** [GitHub - Viktorkrl/MODELAGEMSFTWR](https://github.com/Viktorkrl/MODELAGEMSFTWR)  
**Projeto Integrador:** Marketplace B2B de Sobras Industriais — Polo CIC (Cidade Industrial de Curitiba)  
**Equipe de Origem (Sprint 2):** Grupo BTM (Kauan Oliveira, Vitor Silva, João Gabriel, Yudi)  

---

## 1. Apresentação e Seleção da Funcionalidade Crítica

Na Engenharia de Software contemporânea, a documentação estática desvinculada do código fonte é uma das principais fontes de falhas estruturais em projetos de missão crítica, originando o fenômeno da **Deriva Arquitetural (*Architectural Drift*)**. O paradigma de **Diagrams-as-Code (DaC)** e **Models-as-Code (MaC)** estabelece que arquiteturas e modelos comportamentais devem ser versionados, declarativos, automatizáveis e integrados ao ciclo de vida de desenvolvimento contínuo (CI/CD).

### 1.1 Domínio e Recorte Selecionado
* **Domínio de Negócio:** Marketplace B2B para Comercialização e Permuta de Sobras Fabris e Subprodutos Industriais no Polo CIC.
* **Funcionalidade Crítica Selecionada:** **Negociação B2B — Proposta, Contraproposta, Amostra Técnica e Termo de Acordo, culminando no estado "Pronto para Liquidação"** (Englobando os Casos de Uso **UC07, UC08 e UC09**, com interface para o **UC10**).
* **Entidade de Domínio Core:** `Negociacao` (agregada à entidade `Oferta`).

### 1.2 Justificativa de Criticidade de Negócio e Governança Ambiental
A negociação de resíduos e sobras fabris não pode ser modelada como um e-commerce de varejo simplificado. No contexto de sobras químicas, poliméricas e aparas metálicas:
1. **Lotes Heterogêneos e Finitos:** Cada lote gerado na planta possui laudo laboratorial específico e volume fixo. Não há reposição automática de prateleira.
2. **Compliance Normativo Rígido:** A transação é subordinada à **Política Nacional de Resíduos Sólidos (Lei Federal nº 12.305/2010 - PNRS)** e à norma **ABNT NBR 10004** (Classificação de Resíduos Sólidos em Classe I - Perigosos, Classe IIA - Não Inertes e Classe IIB - Inertes).
3. **Prevenção contra Overbooking:** Múltiplas indústrias transformadoras concorrem pelo mesmo lote residual. Se a plataforma permitir que duas compradoras fechem acordos simultâneos que excedam o saldo físico da sobra anunciada, configura-se fraude operacional e infração ambiental passível de sanções pelo IAT e IBAMA.
4. **Validação de Amostra Prévia («extend» UC09):** Antes de firmar um acordo de toneladas de subprodutos químicos ou plásticos, a compradora pode exigir remessa de amostra física para testes em bancada de laboratório. O sistema deve congelar o fluxo sem bloquear os recursos computacionais do banco de dados.

---

## 2. Estrutura de Governança dos Artefatos (Tree as-Code)

```text
aps3-vitor-silva/
├── docs/
│   ├── architecture/
│   │   ├── workspace.dsl         <-- Código Structurizr DSL (C4 Model Nível 2)
│   │   └── adr-0001.md           <-- Registro de Decisão Arquitetural (Formato Nygard)
│   └── diagrams/
│       ├── sequencia.mmd         <-- Código Mermaid do Diagrama de Sequência UML
│       ├── atividades.mmd        <-- Código Mermaid do Diagrama de Atividades com Raias
│       └── estados.mmd            <-- Código Mermaid da Máquina de Estados (State Machine)
└── README.md                     <-- Dossiê Executivo Consolidado e Renderizado
```

---

## 3. Artefato 1: Diagrama de Sequência (UML / DaC)

### 3.1 Objetivo Técnico
Mapear a troca cronológica de mensagens entre instâncias em tempo de execução para os casos de uso **UC07 (Manifestar Interesse)**, **UC08 (Negociar Condições e Termos)** e a extensão condicional **UC09 (Solicitar Amostra Técnica)**, culminando no fechamento do **Termo de Acordo** e habilitação para liquidação.

### 3.2 Diagrama Renderizado (Mermaid)

```mermaid
sequenceDiagram
    autonumber
    actor Compradora as Indústria Compradora (Destinadora)
    actor Vendedora as Indústria Vendedora (Geradora)
    participant Controller as NegociacaoController
    participant Service as NegociacaoService
    participant Negociacao as Negociacao (Domain Entity)
    participant Oferta as Oferta (Domain Entity)
    participant TermoService as TermoAcordoService
    participant Repo as NegociacaoRepository
    participant Broker as RabbitMQ (Exchange: residuos.topic)
    participant Notifier as NotificacaoService

    %% FASE 1: MANIFESTAÇÃO DE INTERESSE E PROPOSTA INICIAL (UC07)
    rect rgb(240, 248, 255)
        Note over Compradora, Controller: Fase 1: Proposta Inicial de Aquisição/Permuta (UC07)
        Compradora->>Controller: POST /api/v1/negociacoes (PropostaRequestDTO)
        activate Controller
        Controller->>Service: processarAberturaProposta(propostaDTO)
        activate Service
        
        Service->>Oferta: validarDisponibilidade(quantidadePretendida)
        activate Oferta
        Oferta-->>Service: estoqueDisponivel: Boolean (true)
        deactivate Oferta
        
        Service->>Negociacao: new Negociacao(oferta, compradora, vendedora, valorSugerido, qtd)
        activate Negociacao
        Negociacao-->>Service: instanciaNegociacao [Status: EM_ABERTO]
        deactivate Negociacao
        
        Service->>Repo: save(instanciaNegociacao)
        activate Repo
        Repo-->>Service: Negociacao persistida (id: 1042)
        deactivate Repo
        
        %% Mensageria Assíncrona via RabbitMQ
        Service-)Broker: [Mensageria -\>] publish("negociacao.criada", EventoNegociacaoCriadaDTO)
        activate Broker
        Broker-)Notifier: [Mensageria -\>] consumirEvento(EventoNegociacaoCriadaDTO)
        deactivate Broker
        activate Notifier
        Notifier-)Vendedora: [Notificação Push/Email -\>] alertarNovaProposta(NotificacaoDTO)
        deactivate Notifier
        
        Service-->>Controller: PropostaResponseDTO(id: 1042, status: EM_ABERTO, valor, qtd)
        deactivate Service
        Controller-->>Compradora: 201 Created (PropostaResponseDTO)
        deactivate Controller
    end

    %% FASE 2: ITERAÇÕES DE CONTRAPROPOSTAS (UC08)
    rect rgb(255, 250, 240)
        Note over Vendedora, Compradora: Fase 2: Rodadas Iterativas de Contrapropostas
        loop Rodada de Contrapropostas [enquanto sem consenso e rodadas <= 3]
            Vendedora->>Controller: POST /api/v1/negociacoes/1042/contraproposta (ContrapropostaDTO)
            activate Controller
            Controller->>Service: submeterContraproposta(1042, contrapropostaDTO)
            activate Service
            
            Service->>Repo: findById(1042)
            activate Repo
            Repo-->>Service: Negociacao
            deactivate Repo
            
            Service->>Negociacao: contrapropor(novoValor, novaQuantidade)
            activate Negociacao
            Negociacao-->>Service: void [Status: CONTRAPROPOSTA_VENDEDORA]
            deactivate Negociacao
            
            Service->>Repo: save(negociacao)
            activate Repo
            Repo-->>Service: Negociacao atualizada
            deactivate Repo
            
            Service-)Broker: [Mensageria -\>] publish("negociacao.contraproposta", EventoContrapropostaDTO)
            activate Broker
            Broker-)Notifier: [Mensageria -\>] consumirEvento(EventoContrapropostaDTO)
            deactivate Broker
            activate Notifier
            Notifier-)Compradora: [Notificação Push/Email -\>] alertarContraproposta(NotificacaoDTO)
            deactivate Notifier
            
            Service-->>Controller: ContrapropostaResponseDTO(id: 1042, status, novoValor, novaQtd)
            deactivate Service
            Controller-->>Vendedora: 200 OK (ContrapropostaResponseDTO)
            deactivate Controller
        end
    end

    %% FASE 3: DECISÃO, AMOSTRA TÉCNICA OU FECHAMENTO DO ACORDO
    rect rgb(245, 255, 250)
        Note over Compradora, Vendedora: Fase 3: Amostra («extend» UC09) ou Fechamento de Acordo
        alt Fluxo de Extensão UC09: Solicitar Amostra Técnica para Validação Laboratorial
            Compradora->>Controller: POST /api/v1/negociacoes/1042/amostra (SolicitacaoAmostraDTO)
            activate Controller
            Controller->>Service: solicitarAmostraTecnica(1042, solicitacaoDTO)
            activate Service
            
            Service->>Negociacao: solicitarAmostra(justificativa, enderecoEntrega)
            activate Negociacao
            Negociacao-->>Service: void [Status: AGUARDANDO_AMOSTRA]
            deactivate Negociacao
            
            Service->>Repo: save(negociacao)
            activate Repo
            Repo-->>Service: Negociacao
            deactivate Repo
            
            Service-)Broker: [Mensageria -\>] publish("amostra.solicitada", EventoAmostraDTO)
            Service-->>Controller: AmostraResponseDTO(id: 1042, status: AGUARDANDO_AMOSTRA)
            deactivate Service
            Controller-->>Compradora: 200 OK (AmostraResponseDTO)
            deactivate Controller
            
        else Fluxo Principal: Aceite Mútuo de Termos e Conclusão do Acordo
            Compradora->>Controller: PUT /api/v1/negociacoes/1042/aceite-termos
            activate Controller
            Controller->>Service: confirmarAceiteTermos(1042, compradoraId)
            activate Service
            
            Service->>Negociacao: aceitarTermos()
            activate Negociacao
            Negociacao-->>Service: termosAceitos: Boolean (true)
            deactivate Negociacao
            
            Vendedora->>Controller: PUT /api/v1/negociacoes/1042/aceite-termos
            Controller->>Service: confirmarAceiteTermos(1042, vendedoraId)
            Service->>Negociacao: aceitarTermos()
            activate Negociacao
            Negociacao-->>Service: termosAceitos: Boolean (true - ambas partes confirmadas)
            deactivate Negociacao
            
            alt [ambasPartesAssinaram == true && saldoEstoqueSuficiente == true]
                Service->>Oferta: reservarQuantidade(quantidadeFinal)
                activate Oferta
                Oferta-->>Service: void [quantidadeDisponivel deduzida / reservada]
                deactivate Oferta
                
                Service->>TermoService: gerarMinutaTermoAcordo(negociacao)
                activate TermoService
                TermoService-->>Service: TermoAcordoDTO(hashSHA256, urlMinutaAssinada)
                deactivate TermoService
                
                Service->>Negociacao: congelarReservaEstoque()
                activate Negociacao
                Negociacao-->>Service: void [Status: PRONTO_PARA_LIQUIDACAO]
                deactivate Negociacao
                
                Service->>Repo: save(negociacao)
                activate Repo
                Repo-->>Service: Negociacao persistida
                deactivate Repo
                
                Service-)Broker: [Mensageria -\>] publish("negociacao.pronto_liquidacao", EventoProntoLiquidacaoDTO)
                activate Broker
                Broker-)Notifier: [Mensageria -\>] alertarPartesProntoLiquidacao(EventoProntoLiquidacaoDTO)
                deactivate Broker
                
                Service-->>Controller: TermoAcordoResponseDTO(id: 1042, status: PRONTO_PARA_LIQUIDACAO, hashSHA256)
                deactivate Service
                Controller-->>Compradora: 200 OK (TermoAcordoResponseDTO)
                deactivate Controller
            end
            
        else Fluxo de Exceção: Rejeição de Termos ou Desistência Formal
            Vendedora->>Controller: DELETE /api/v1/negociacoes/1042 (CancelamentoRequestDTO)
            activate Controller
            Controller->>Service: cancelarNegociacao(1042, motivo)
            activate Service
            
            Service->>Negociacao: cancelar(motivo)
            activate Negociacao
            Negociacao-->>Service: void [Status: CANCELADA]
            deactivate Negociacao
            
            Service->>Repo: save(negociacao)
            activate Repo
            Repo-->>Service: Negociacao
            deactivate Repo
            
            Service-)Broker: [Mensageria -\>] publish("negociacao.cancelada", EventoCancelamentoDTO)
            Service-->>Controller: NegociacaoStatusDTO(id: 1042, status: CANCELADA, motivo)
            deactivate Service
            Controller-->>Vendedora: 200 OK (NegociacaoStatusDTO)
            deactivate Controller
        end
    end
```

### 3.3 Catálogo de DTOs e Conformidade de Operações Públicas

| DTO Utilizado | Camada / Direção | Campos Principais | Finalidade de Domínio |
| :--- | :--- | :--- | :--- |
| `PropostaRequestDTO` | Inbound (Compradora -> Controller) | `ofertaId`, `quantidadePretendida`, `valorUnitarioSugerido`, `modalidadeFrete`, `mensagemInicial` | Início formal da negociação de compra ou permuta. |
| `PropostaResponseDTO` | Outbound (Service -> Controller -> Compradora) | `negociacaoId`, `status: EM_ABERTO`, `valorUnitarioSugerido`, `quantidadePretendida`, `dataInicio` | Retorno seguro dos metadados da negociação aberta. |
| `ContrapropostaDTO` | Inbound (Partes -> Controller) | `novoValorUnitario`, `novaQuantidade`, `modalidadeFrete`, `observacoes` | Ajuste bilateral de preço, volume ou frete. |
| `ContrapropostaResponseDTO` | Outbound (Service -> Controller) | `negociacaoId`, `status`, `valorFinalUnitario`, `quantidadeFinal`, `rodadaAtual` | Confirmação da rodada de contraproposta. |
| `SolicitacaoAmostraDTO` | Inbound (Compradora -> Controller) | `quantidadeAmostra`, `enderecoEntrega`, `justificativaTecnica` | Solicitação de ensaio prévio (UC09). |
| `TermoAcordoResponseDTO` | Outbound (Service -> Controller -> Partes) | `negociacaoId`, `status: PRONTO_PARA_LIQUIDACAO`, `hashSHA256`, `urlMinutaAssinada` | Acordo consolidado habilitado para Escrow e MTR. |

> **Regra de Consistência Absoluta:** Todas as mensagens enviadas para as entidades `Negociacao` (`contrapropor`, `aceitarTermos`, `congelarReservaEstoque`, `cancelar`) e `Oferta` (`validarDisponibilidade`, `reservarQuantidade`) correspondem com exatidão matemática às operações públicas declaradas no Diagrama de Classes e Dicionário de Domínio da Sprint 2.

---

## 4. Artefato 2: Diagrama de Atividades com Raias (UML / DaC)

### 4.1 Objetivo Técnico
Mapear o fluxo de trabalho (*workflow*) do processo de negociação, evidenciando as raias de responsabilidade (atores humanos, regras de negócio e mensageria externa), nós de decisão com condições de guarda booleanas mutuamente exclusivas e a concorrência através de uma **Barra de Fork** e **Barra de Join**.

### 4.2 Diagrama Renderizado (Mermaid)

```mermaid
flowchart TD
    %% DEFINIÇÃO DAS 4 RAIAS DE PARTIÇÃO (SWIMLANES)
    subgraph Compradora ["Raia 1: Indústria Compradora (Destinadora)"]
        node_start((● Início))
        act_manifestar["UC07: Selecionar Anúncio de Sobra e Manifestar Interesse"]
        act_proposta["Elaborar Proposta Inicial<br/>(Quantidade Pretendida, Preço e Frete CIF/FOB)"]
        act_decidir_amostra{"Solicitar Ensaio<br/>Laboratorial?"}
        act_solicitar_amostra["UC09: Solicitar Amostra Técnica<br/>(Justificativa e Endereço de Teste)"]
        act_testar_amostra["Realizar Ensaios e Testes Físico-Químicos<br/>em Bancada de Laboratório"]
        act_avaliar_contra_compradora{"Avaliar Contraproposta<br/>da Vendedora"}
        act_aceitar_compradora["Emitir Aceite Eletrônico dos Termos<br/>(Assinatura Digital Compradora)"]
        act_rejeitar_compradora["Formalizar Rejeição e Desistência"]
    end

    subgraph Engine ["Raia 2: Marketplace Engine (Back-End Core & Services)"]
        act_validar_estoque{"Validar Saldo<br/>da Oferta"}
        act_criar_negociacao["Criar Instância de Negociacao<br/>[Status: EM_ABERTO]"]
        act_rejeitar_proposta_sem_saldo["Retornar Erro de Validação<br/>(Saldo Insuficiente de Lote)"]
        act_atualizar_contraproposta["Registrar Contraproposta e<br/>Incrementar Contador de Rodadas"]
        
        %% BARRA DE FORK (DIVISÃO PARALELA CONCORRENTE)
        fork_fechamento["==================== BARRA DE FORK (DIVISÃO PARALELA) ===================="]
        
        act_reserva_lote["Oferta.reservarQuantidade(qtdFinal)<br/>[Bloqueio Transacional de Saldo no Catálogo]"]
        act_gerar_termo["TermoAcordoService.gerarTermoAcordo()<br/>[Geração de Hash SHA-256 e Minuta Jurídica PDF]"]
        act_disparar_evento["Publicar Evento de Domínio<br/>'negociacao.acordo.firmado' no RabbitMQ"]
        
        %% BARRA DE JOIN (SINCRONIZAÇÃO TRANSACIONAL)
        join_fechamento["==================== BARRA DE JOIN (SINCRONIZAÇÃO) ===================="]
        
        act_transicao_pronto["Negociacao.congelarReservaEstoque()<br/>[Status: PRONTO_PARA_LIQUIDACAO]"]
        act_encerrar_cancelada["Atualizar Negociacao<br/>[Status: CANCELADA] e Liberar Locks"]
        node_fim_pronto((◉ Pronto para Liquidação))
        node_fim_cancelada((◉ Cancelada))
    end

    subgraph Vendedora ["Raia 3: Indústria Vendedora (Geradora)"]
        act_analisar_proposta{"Decisão da Vendedora<br/>sobre Proposta"}
        act_contrapropor_vendedora["Submeter Contraproposta Estruturada<br/>(Novo Preço Unitário e Ajuste de Lote)"]
        act_rejeitar_vendedora["Rejeitar Proposta com Motivo Formal"]
        act_despachar_amostra["Despachar Amostra Física com Guia<br/>e Informar Código de Rastreio"]
        act_aceitar_vendedora["Emitir Aceite Eletrônico dos Termos<br/>(Assinatura Digital Vendedora)"]
    end

    subgraph Notificacoes ["Raia 4: Mensageria & Notificações (RabbitMQ / Push)"]
        act_notif_abertura["Consumir 'negociacao.criada'<br/>-> Notificar Vendedora via Push/Email"]
        act_notif_contra["Consumir 'negociacao.contraproposta'<br/>-> Notificar Contraparte"]
        act_notif_amostra["Consumir 'amostra.solicitada'<br/>-> Alertar Expedição da Vendedora"]
        act_notif_fechamento["Consumir 'negociacao.acordo.firmado'<br/>-> Notificar Ambas as Indústrias"]
        act_notif_cancelamento["Consumir 'negociacao.cancelada'<br/>-> Alertar Encerramento"]
    end

    %% FLUXO DO PROCESSO
    node_start --> act_manifestar
    act_manifestar --> act_proposta
    act_proposta --> act_validar_estoque

    act_validar_estoque --> |"[saldoDisponivel >= quantidadePretendida]"| act_criar_negociacao
    act_validar_estoque --> |"[saldoDisponivel < quantidadePretendida]"| act_rejeitar_proposta_sem_saldo
    act_rejeitar_proposta_sem_saldo --> node_fim_cancelada

    act_criar_negociacao --> act_notif_abertura
    act_notif_abertura --> act_analisar_proposta

    act_analisar_proposta --> |"[decisao == REJEITAR]"| act_rejeitar_vendedora
    act_rejeitar_vendedora --> act_encerrar_cancelada
    
    act_analisar_proposta --> |"[decisao == CONTRAPROPOR]"| act_contrapropor_vendedora
    act_contrapropor_vendedora --> act_atualizar_contraproposta
    act_atualizar_contraproposta --> act_notif_contra
    act_notif_contra --> act_avaliar_contra_compradora

    act_avaliar_contra_compradora --> |"[aceitaContraproposta == false]"| act_rejeitar_compradora
    act_rejeitar_compradora --> act_encerrar_cancelada
    act_encerrar_cancelada --> act_notif_cancelamento
    act_notif_cancelamento --> node_fim_cancelada

    act_avaliar_contra_compradora --> |"[aceitaContraproposta == true]"| act_decidir_amostra
    act_analisar_proposta --> |"[decisao == ACEITAR]"| act_decidir_amostra

    %% UC09: Amostra Técnica
    act_decidir_amostra --> |"[requerHomologacaoLaboratorial == true]"| act_solicitar_amostra
    act_solicitar_amostra --> act_notif_amostra
    act_notif_amostra --> act_despachar_amostra
    act_despachar_amostra --> act_testar_amostra
    act_testar_amostra --> act_aceitar_compradora

    act_decidir_amostra --> |"[requerHomologacaoLaboratorial == false]"| act_aceitar_compradora

    %% Aceite Final
    act_aceitar_compradora --> act_aceitar_vendedora
    act_aceitar_vendedora --> fork_fechamento

    %% EXECUÇÃO CONCORRENTE: FORK -> RAMOS -> JOIN
    fork_fechamento --> act_reserva_lote
    fork_fechamento --> act_gerar_termo
    fork_fechamento --> act_disparar_evento

    act_disparar_evento --> act_notif_fechamento

    act_reserva_lote --> join_fechamento
    act_gerar_termo --> join_fechamento
    act_notif_fechamento --> join_fechamento

    join_fechamento --> act_transicao_pronto
    act_transicao_pronto --> node_fim_pronto
```

### 4.3 Análise de Concorrência e Sincronização (Fork & Join)
Quando o duplo aceite eletrônico do Termo de Acordo é concluído, o sistema dispara a **Barra de Fork**, particionando três tarefas críticas que rodam de forma concorrente:
1. **Ramo A (Consistência Transacional de Estoque):** Bloqueia e subtrai atomicamente o volume acordado do saldo da `Oferta` no PostgreSQL via Bloqueio Otimista, impedindo sobreposição de compras por concorrentes.
2. **Ramo B (Conformidade Jurídica e Hash Criptográfico):** O `TermoAcordoService` consolida a minuta contratual em PDF, incluindo as cláusulas ambientais da PNRS, e gera o hash criptográfico SHA-256 da assinatura digital das partes.
3. **Ramo C (Reatividade e Mensageria Assíncrona):** Publica o evento `negociacao.acordo.firmado` no RabbitMQ para que os consumidores externos preparem o ambiente de custódia (Escrow) e as notificações push/e-mail para os diretores fabris.
* A **Barra de Join** sincroniza o término bem-sucedido dessas três frentes antes de consolidar a entidade `Negociacao` no estado definitivo `PRONTO_PARA_LIQUIDACAO`.

---

## 5. Artefato 3: Diagrama de Transição de Estados (State Machine / DaC)

### 5.1 Objetivo Técnico
Mapear o ciclo de vida rigoroso da entidade central `Negociacao`, especificando estados compostos (subestados), condições de guarda booleanas, ações de efeito e os compartimentos internos de execução (`entry /`, `do /`, `exit /`).

### 5.2 Diagrama Renderizado (Mermaid `stateDiagram-v2`)

```mermaid
stateDiagram-v2
    [*] --> Aberta : manifestarInteresse [ofertaAtiva == true] / instanciarNegociacao()

    Aberta --> EmNegociacao : submeterProposta [saldoDisponivel >= qtd && valorUnitario > 0] / registrarPropostaInicial()
    Aberta --> Cancelada : desistirAbertura [semProposta == true] / registrarDesistencia()

    %% ESTADO COMPOSTO: EM NEGOCIAÇÃO
    state EmNegociacao {
        [*] --> AguardandoAnaliseVendedora
        
        AguardandoAnaliseVendedora --> ContrapropostaVendedora : contrapropor [rodada < 3 && novoValor > 0] / registrarHistoricoContraproposta()
        ContrapropostaVendedora --> AguardandoAnaliseCompradora : notificarContraparte()
        
        AguardandoAnaliseCompradora --> ContrapropostaCompradora : contrapropor [rodada < 3 && novoValor > 0] / registrarHistoricoContraproposta()
        ContrapropostaCompradora --> AguardandoAnaliseVendedora : notificarContraparte()
        
        %% Subfluxo: Homologação de Amostra Técnica (UC09)
        AguardandoAnaliseVendedora --> AguardandoHomologacaoAmostra : solicitarAmostraTecnica [isResiduoClasseI == true && laudoExigeEnsaio == true] / emitirGuiaRemessaAmostra()
        AguardandoHomologacaoAmostra --> AguardandoAnaliseVendedora : aprovarLaudoAmostra [amostraConforme == true] / registrarHomologacaoBancada()
        AguardandoHomologacaoAmostra --> Cancelada : reprovarLaudoAmostra [amostraNaoConforme == true] / emitirParecerIncompatibilidade()

        %% Consenso das Cláusulas
        AguardandoAnaliseVendedora --> TermosConsensados : aceitarTermos [consensoPrecoVolume == true] / emitirMinutaTermoAcordo()
        AguardandoAnaliseCompradora --> TermosConsensados : aceitarTermos [consensoPrecoVolume == true] / emitirMinutaTermoAcordo()
        
        TermosConsensados --> ProntoParaLiquidacao : confirmarAceiteMutuo [ambasPartesAssinaram == true && saldoEstoqueSuficiente == true] / congelarEstoqueEGarantirSLA()
    }

    %% Compartimento de Ações Internas (entry / do / exit)
    EmNegociacao : entry / registrarAuditoriaAbertura()
    EmNegociacao : do / monitorarSlaExpiracao48h()
    EmNegociacao : exit / desarmarTimerSla()

    %% Transições de Exceção e SLA
    EmNegociacao --> Cancelada : cancelarNegociacao [motivoInformado == true] / liberarLocksConcorrentes()
    EmNegociacao --> Expirada : timeOutSla [tempoDecorrido > 48h] / notificarPartesExpiracao()
    EmNegociacao --> InterrompidaPorTerceiro : loteEsgotadoPorTerceiro [saldoRemanescente == 0] / abortarNegociacaoConcorrente()

    %% ESTADO PRONTO PARA LIQUIDAÇÃO
    state ProntoParaLiquidacao {
        [*] --> AguardandoInicioEscrow
        AguardandoInicioEscrow --> HabilitadaParaTransacao : gerarPayloadTransacao()
    }

    ProntoParaLiquidacao : entry / persistirHashContratualSHA256()
    ProntoParaLiquidacao : do / exporEndpointLiquidacaoUC10()
    ProntoParaLiquidacao : exit / instanciarTransacaoB2B()

    %% Transição para Fechamento de Transação
    ProntoParaLiquidacao --> ConcluidaParaTransacao : transicionarParaUC10 [iniciarCustodiaEscrow == true] / instanciarTransacao()

    ConcluidaParaTransacao --> [*]
    Cancelada --> [*]
    Expirada --> [*]
    InterrompidaPorTerceiro --> [*]
```

### 5.3 Formalismo Matemático das Transições e Ações Internas

$$\text{Transição Formal: } \text{Origem} \xrightarrow{\text{Gatilho } [\text{CondiçãoDeGuarda}] \ / \ \text{AçãoDeEfeito}()} \text{Destino}$$

1. **Transição de Contraproposta:**  
   $$\text{AguardandoAnalise} \xrightarrow{\text{contrapropor } [\text{rodada} < 3 \land \text{novoValor} > 0] \ / \ \text{registrarHistoricoContraproposta}()} \text{ContrapropostaPendente}$$
2. **Transição para Amostra Técnica («extend» UC09):**  
   $$\text{AguardandoAnaliseVendedora} \xrightarrow{\text{solicitarAmostraTecnica } [\text{isResiduoClasseI} == \text{true} \land \text{laudoExigeEnsaio} == \text{true}] \ / \ \text{emitirGuiaRemessaAmostra}()} \text{AguardandoHomologacaoAmostra}$$
3. **Transição de Acordo Consolidado:**  
   $$\text{TermosConsensados} \xrightarrow{\text{confirmarAceiteMutuo } [\text{ambasPartesAssinaram} == \text{true} \land \text{saldoEstoqueSuficiente} == \text{true}] \ / \ \text{congelarEstoqueEGarantirSLA}()} \text{ProntoParaLiquidacao}$$
4. **Compartimentos Internos do Estado `EmNegociacao`:**
   * `entry / registrarAuditoriaAbertura()`: Cria o snapshot imutável com carimbo de tempo para auditoria judicial.
   * `do / monitorarSlaExpiracao48h()`: Thread de background que monitora a inatividade de respostas.
   * `exit / desarmarTimerSla()`: Cancela os timers pendentes ao ocorrer decisão ou fechamento.

---

## 6. Artefato 4: Visão Arquitetural Macro C4 (Models-as-Code / DaC)

### 6.1 Objetivo Técnico
Representar a topologia física e lógica dos contêineres que compõem o sistema (**C4 Model — Nível 2**), identificando tecnologias, bancos de dados, mensageria e protocolos de integração.

### 6.2 Diagrama de Contêineres Renderizado (Mermaid C4)

```mermaid
flowchart TB
    subgraph Users ["Atores Humanos"]
        vendedora["👤 Indústria Vendedora<br/><i>[Person]</i><br/>Publica anúncios, anexa laudos e analisa propostas"]
        compradora["👤 Indústria Compradora<br/><i>[Person]</i><br/>Busca sobras, contrapropõe termos e assina acordos"]
        admin["👤 Administrador / Moderador<br/><i>[Person]</i><br/>Audita licenças ambientais (LO) e modera cadastros"]
    end

    subgraph Boundaries ["Fronteira da Aplicação: Marketplace B2B de Sobras Industriais"]
        spa["🌐 Single Page Application (SPA)<br/><i>[Container: Next.js 14, React 18, TypeScript, TailwindCSS]</i><br/>Interface web responsiva para catálogo, propostas e aceite"]
        gateway["🛡️ API Gateway & Reverse Proxy<br/><i>[Container: NGINX / Spring Cloud Gateway]</i><br/>Roteamento unificado, terminação TLS, JWT e rate limiting"]
        backend["⚙️ Core Backend Service<br/><i>[Container: Java 21, Spring Boot 3.2, Spring Data JPA]</i><br/>Regras de negócio, Máquina de Estados, Bloqueio Otimista e ACID"]
        worker["⚡ Integration & Notification Worker<br/><i>[Container: Node.js 20, NestJS, TypeScript]</i><br/>Consumo assíncrono de eventos, webhooks e alertas em tempo real"]
        broker["📬 Message Broker (RabbitMQ)<br/><i>[Container: RabbitMQ 3.13 com AMQP 0-9-1]</i><br/>Exchange topic 'residuos.topic' para eventos desacoplados"]
        redis["🚀 Cache & Distributed Locks<br/><i>[Container: Redis 7.2 com RESP]</i><br/>Sessões ativas, cache de catálogo georreferenciado e Redlock"]
        database[("🗄️ Relational Database (PostgreSQL + PostGIS)<br/><i>[Container: PostgreSQL 16 com PostGIS]</i><br/>Armazenamento ACID de usuários, ofertas, negociações e auditoria")]
    end

    subgraph External ["Sistemas Governamentais e Corporativos Externos"]
        sinir["🏛️ SINIR / MTR Digital<br/><i>[External System: Ministério do Meio Ambiente]</i><br/>Validação ambiental e emissão de Manifesto de Transporte"]
        escrow["💳 Gateway de Pagamento & Escrow<br/><i>[External System: Asaas / Pagar.me]</i><br/>Retenção financeira em garantia (Escrow) e split bancário"]
        receita["🏢 Receita Federal / API CNPJ<br/><i>[External System: Consulta Cadastral]</i><br/>Validação automatizada de CNPJ, endereço fiscal e CNAE"]
        notificacoes["📲 Serviço Externo de Notificações<br/><i>[External System: Twilio / SendGrid]</i><br/>Disparo de mensagens WhatsApp e e-mails corporativos"]
    end

    %% Conectores e Protocolos
    vendedora -->|HTTPS| spa
    compradora -->|HTTPS| spa
    admin -->|HTTPS| spa

    spa -->|HTTPS / WSS| gateway
    gateway -->|HTTP/2 REST JSON| backend

    backend -->|JDBC / TCP 5432| database
    backend -->|RESP 6379| redis
    backend -->|AMQP 0-9-1 5672| broker
    broker -->|AMQP 0-9-1| worker

    worker -->|HTTPS REST| notificacoes
    backend -->|HTTPS REST| escrow
    backend -->|HTTPS REST / XML| sinir
    backend -->|HTTPS REST| receita
```

### 6.3 Especificação dos Contêineres e Protocolos

| Contêiner / Unidade | Tecnologia Adotada | Protocolo / Porta | Responsabilidade de Arquitetura |
| :--- | :--- | :--- | :--- |
| **Single Page Application** | Next.js 14, React 18, TypeScript | HTTPS / WSS (Porta 443) | Interface com o usuário, renderização SSR/SSG e chat em tempo real via WebSockets. |
| **API Gateway** | NGINX / Spring Cloud Gateway | HTTP/2 REST (Porta 8080) | Ponto único de entrada, validação de tokens JWT (OAuth2) e prevenção contra ataques DDoS. |
| **Core Backend Service** | Java 21, Spring Boot 3.2, JPA | TCP / HTTP/2 Interno | Processamento transacional, execução da máquina de estados e controle de bloqueio otimista (`@Version`). |
| **Integration Worker** | Node.js 20, NestJS, TypeScript | AMQP 0-9-1 (Porta 5672) | Consumo assíncrono de eventos de domínio, geração de PDFs em background e despacho para webhooks. |
| **Message Broker** | RabbitMQ 3.13 | AMQP 0-9-1 (Porta 5672) | Roteamento desacoplado de eventos com Dead Letter Queues (DLQ) para tolerância a falhas. |
| **Cache & Lock Store** | Redis 7.2 | RESP (Porta 6379) | Cache georreferenciado com consultas de raio de proximidade e travas distribuídas (*Redlock*). |
| **Database Relacional** | PostgreSQL 16 + PostGIS | JDBC / TCP (Porta 5432) | Persistência relacional ACID, indexação espacial `GIST` para logística do Polo CIC. |

> O código-fonte declarativo formal para Structurizr DSL encontra-se disponível no arquivo [`docs/architecture/workspace.dsl`](./docs/architecture/workspace.dsl).

---

## 7. Artefato 5: Registro de Decisão Arquitetural (ADR 0001)

A decisão arquitetural foi documentada seguindo o rigoroso **Formato Nygard**, disponível na íntegra em [`docs/architecture/adr-0001.md`](./docs/architecture/adr-0001.md). A seguir, apresenta-se a síntese executiva:

* **Título:** ADR 0001 — Padrão State com Bloqueio Otimista (@Version) e Outbox Pattern com RabbitMQ para Negociações B2B Concorrentes de Sobras Industriais
* **Status:** **Aprovado**
* **Contexto:** Lotes finitos de sobras e subprodutos industriais (resíduos químicos Classe I, sucatas ferrosas e plásticos de engenharia do Polo CIC) atraem múltiplos compradores concorrentes. Negociações humanas duram horas ou dias (SLA de 48h). O uso de travas pessimistas no banco de dados (`SELECT FOR UPDATE`) causaria gargalos severos de conexões e deadlocks. Em contrapartida, a falta de bloqueio causaria sobreposição de vendas (*overbooking*), violando a Lei Federal nº 12.305/2010 (PNRS) e gerando severa responsabilidade cível e ambiental.
* **Decisão:**
  1. Implementação do **Padrão State (GoF)** na entidade JPA `Negociacao` para blindar transições inválidas.
  2. Adoção de **Bloqueio Otimista (`@Version`)** nas entidades `Oferta` e `Negociacao`, permitindo concorrência sem bloqueio de threads até o instante atômico do aceite mútuo dos termos. Em caso de colisão, a operação secundária é reavaliada via `@Retryable` ou abortada com aviso gracioso.
  3. Aplicação do **Transactional Outbox Pattern** associado ao message broker **RabbitMQ** para publicação garantida do evento de domínio `negociacao.acordo.firmado`, desacoplando geração de hashes SHA-256 e disparos de notificações push/e-mail.
* **Consequências:** Eliminação matemática de *overbooking*, altíssimo throughput transacional, auditoria temporal estrita para órgãos reguladores (IAT/IBAMA) e desacoplamento de integrações externas pesadas.

---

## 8. Matriz de Consistência Bidirecional entre os Modelos

| Elemento do Domínio | Diagrama de Sequência (Artefato 1) | Diagrama de Atividades (Artefato 2) | Diagrama de Estados (Artefato 3) | C4 Model Contêineres (Artefato 4) |
| :--- | :--- | :--- | :--- | :--- |
| **Manifestação de Interesse (UC07)** | `POST /api/v1/negociacoes` | Atividade: "Manifestar Interesse" na Raia Compradora | Transição `[*] --> Aberta` | SPA (Next.js) -> API Gateway -> Core Backend |
| **Contraproposta (UC08)** | `loop Rodada de Contrapropostas` com `contrapropor(v, q)` | Atividade: "Submeter Contraproposta Estruturada" | Subestado `ContrapropostaVendedora` | Core Backend (Spring Boot) -> PostgreSQL (`@Version`) |
| **Amostra Técnica («extend» UC09)** | Fragmento `alt: Solicitar Amostra Técnica` | Decisão: `[requerHomologacaoLaboratorial == true]` | Subestado `AguardandoHomologacaoAmostra` | Core Backend -> Worker (NestJS) -> Alerta de Expedição |
| **Fork / Join de Fechamento** | `reservarQuantidade(q)` + `gerarMinutaTermoAcordo()` | Barra de Fork com 3 ramos paralelos e Barra de Join | Ação de Efeito `/ congelarEstoqueEGarantirSLA()` | Core Backend + PostgreSQL + RabbitMQ (AMQP) |
| **Status Final da Funcionalidade** | Retorno de `TermoAcordoResponseDTO` | Nó de Fim: `Pronto para Liquidação` | Estado `ProntoParaLiquidacao` com `entry/`, `do/`, `exit/` | Habilita endpoints de liquidação para UC10 (Escrow / SINIR) |

---

## 9. Instruções de Compilação, Governança as-Code e Auditoria

Os diagramas deste projeto foram construídos no padrão texto puro declarativo, possibilitando validação sintática contínua por ferramentas de linha de comando:

1. **Validação de Sintaxe Mermaid:**
   ```bash
   # Instalação do compilador oficial Mermaid CLI
   npm install -g @mermaid-js/mermaid-cli

   # Compilação e renderização dos diagramas em SVG / PNG
   mmdc -i docs/diagrams/sequencia.mmd -o docs/diagrams/sequencia.svg
   mmdc -i docs/diagrams/atividades.mmd -o docs/diagrams/atividades.svg
   mmdc -i docs/diagrams/estados.mmd -o docs/diagrams/estados.svg
   ```

2. **Validação do Modelo C4 via Structurizr CLI:**
   ```bash
   # Validação do arquivo workspace.dsl
   structurizr-cli validate -w docs/architecture/workspace.dsl

   # Exportação do modelo para Mermaid / PlantUML
   structurizr-cli export -w docs/architecture/workspace.dsl -f mermaid
   ```

---
*Dossiê elaborado em conformidade estrita com as diretrizes da Unidade Curricular de Modelagem de Software (UniSenai - 2026).*
