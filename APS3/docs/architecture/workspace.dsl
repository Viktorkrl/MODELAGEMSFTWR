workspace "Marketplace B2B de Sobras Industriais" "Dossiê de Arquitetura Viva - C4 Nível 2 (Contêineres) para o Ecossistema do CIC" {

    model {
        // =====================================================================
        // ATORES HUMANOS (PEOPLE)
        // =====================================================================
        vendedora = person "Indústria Vendedora (Geradora)" "Empresa que gera sobras fabris, publica anúncios de lotes, anexa laudos e analisa propostas." "Person"
        compradora = person "Indústria Compradora (Destinadora)" "Indústria transformadora que busca matéria-prima secundária, negocia termos e realiza acordos." "Person"
        admin = person "Administrador / Moderador" "Equipe de governança responsável por auditar licenças ambientais (LO) e moderar anúncios." "Person"

        // =====================================================================
        // SISTEMA PRINCIPAL E SEUS CONTÊINERES (C4 NÍVEL 2)
        // =====================================================================
        marketplace = softwareSystem "Marketplace B2B de Sobras Industriais" "Plataforma central de simbiose industrial e economia circular para indústrias do Polo CIC." {
            
            spa = container "Single Page Application (SPA)" "Interface web responsiva para consulta ao catálogo, propostas, chat de negociação e aceite contratual." "Next.js 14, React 18, TypeScript, TailwindCSS" "Web Browser"
            
            apiGateway = container "API Gateway & Reverse Proxy" "Ponto de entrada unificado, roteamento de rotas, terminação TLS, autenticação JWT e rate limiting." "NGINX / Spring Cloud Gateway" "Gateway"
            
            coreBackend = container "Core Backend Service" "Executa as regras de domínio, máquina de estados da Negociação, bloqueio concorrente e geração do Termo de Acordo." "Java 21, Spring Boot 3.2, Spring Data JPA, Hibernate" "Backend"
            
            workerService = container "Integration & Notification Worker" "Processamento em segundo plano, consumo de eventos da fila, despacho de e-mails/push e webhooks." "Node.js 20, NestJS, TypeScript" "Worker"
            
            messageBroker = container "Message Broker (RabbitMQ)" "Gerenciador de filas e tópicos para comunicação assíncrona desacoplada entre micro-unidades." "RabbitMQ 3.13 (AMQP 0-9-1)" "Queue"
            
            cacheStore = container "Cache & Distributed Locks (Redis)" "Armazena sessões ativas, cache de catálogo georreferenciado e travas distribuídas (Redlock)." "Redis 7.2 (RESP)" "Cache"
            
            database = container "Database Relacional (PostgreSQL + PostGIS)" "Armazenamento persistente ACID de usuários, ofertas, negociações, termos de acordo e auditoria." "PostgreSQL 16 com extensão PostGIS" "Database"
        }

        // =====================================================================
        // SISTEMAS EXTERNOS INTEGRADOS
        // =====================================================================
        gatewayPagamento = softwareSystem "Gateway de Pagamento & Escrow" "Instituição financeira parceira responsável por retenção em custódia (Escrow) e split bancário." "External System"
        sinir = softwareSystem "SINIR / MTR Digital" "Sistema governamental (Ministério do Meio Ambiente) para validação e emissão de Manifesto de Transporte." "External System"
        receitaFederal = softwareSystem "Receita Federal / API CNPJ" "Serviço governamental para verificação automatizada de regularidade do CNPJ e CNAE industrial." "External System"
        servicoNotificacoes = softwareSystem "Serviço Externo de Notificações" "Serviço de mensageria em nuvem para disparo de WhatsApp e e-mails transacionais (Twilio/SendGrid)." "External System"

        // =====================================================================
        // RELACIONAMENTOS DE INTERAÇÃO E PROTOCOLOS
        // =====================================================================
        vendedora -> spa "Acessa anúncios, avalia propostas e assina termos" "HTTPS"
        compradora -> spa "Busca insumos, envia propostas e solicita amostras" "HTTPS"
        admin -> spa "Audita licenças ambientais e modera cadastros" "HTTPS"

        spa -> apiGateway "Encaminha requisições REST e subscreve a canais WebSocket" "HTTPS / WSS"
        
        apiGateway -> coreBackend "Encaminha chamadas de API autenticadas" "HTTP/2 REST JSON"
        
        coreBackend -> database "Executa consultas e transações relacionais ACID" "JDBC / PostgreSQL TCP (Porta 5432)"
        coreBackend -> cacheStore "Lê/escreve dados em cache e gerencia locks concorrentes" "RESP (Porta 6379)"
        coreBackend -> messageBroker "Publica eventos de domínio ('negociacao.acordo.firmado')" "AMQP 0-9-1 (Porta 5672)"
        
        messageBroker -> workerService "Entrega mensagens assíncronas aos consumidores" "AMQP 0-9-1"
        workerService -> servicoNotificacoes "Dispara alertas push, WhatsApp e e-mail transacional" "HTTPS REST API"
        
        coreBackend -> gatewayPagamento "Inicializa intenção de custódia em Escrow (UC11)" "HTTPS REST API / Webhooks"
        coreBackend -> sinir "Sincroniza dados da carga para emissão de MTR Digital (UC12)" "HTTPS REST XML/JSON"
        coreBackend -> receitaFederal "Consulta situação cadastral e CNAE industrial" "HTTPS REST API"
    }

    views {
        systemContext marketplace "SystemContext" {
            include *
            autoLayout lr
        }

        container marketplace "Containers_Overview" {
            include *
            autoLayout lr
        }

        styles {
            element "Person" {
                background #1A365D
                color #FFFFFF
                shape Person
            }
            element "Software System" {
                background #2B6CB0
                color #FFFFFF
            }
            element "External System" {
                background #718096
                color #FFFFFF
            }
            element "Container" {
                background #2B6CB0
                color #FFFFFF
            }
            element "Web Browser" {
                shape WebBrowser
            }
            element "Database" {
                shape Cylinder
                background #2C5282
            }
            element "Queue" {
                shape Pipe
                background #D69E2E
                color #000000
            }
            element "Cache" {
                shape Cylinder
                background #9B2C2C
            }
        }
    }
}
