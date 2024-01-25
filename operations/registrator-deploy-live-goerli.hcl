job "registrator-deploy-live-goerli" {
    datacenters = ["ator-fin"]
    type = "batch"

    reschedule {
        attempts = 0
    }

    task "deploy-registrator-live-task" {
        driver = "docker"

        config {
            network_mode = "host"
            image = "ghcr.io/ator-development/registrator:0.1.0"
            entrypoint = ["npx"]
            command = "hardhat"
            args = ["run", "--network", "goerli", "scripts/deploy.ts"]
        }

        vault {
            policies = ["registrator-live-goerli"]
        }

        template {
            data = <<EOH
            {{with secret "kv/registrator/goerli/live"}}
                DEPLOYER_PRIVATE_KEY="{{.Data.data.DEPLOYER_PRIVATE_KEY}}"
                CONSUL_TOKEN="{{.Data.data.CONSUL_TOKEN}}"
                JSON_RPC="{{.Data.data.JSON_RPC}}"
                REGISTRATOR_OPERATOR_ADDRESS="{{.Data.data.REGISTRATOR_OPERATOR_ADDRESS}}"
            {{end}}
            EOH
            destination = "secrets/file.env"
            env         = true
        }

        env {
            PHASE="live"
            CONSUL_IP="127.0.0.1"
            CONSUL_PORT="8500"
            REGISTRATOR_CONSUL_KEY="registrator/goerli/live/address"
            ATOR_TOKEN_CONSUL_KEY="ator-token/goerli/live/address"
        }

        restart {
            attempts = 0
            mode = "fail"
        }

        resources {
            cpu    = 4096
            memory = 4096
        }
    }
}
