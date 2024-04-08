job "registrator-deploy-live-sepolia" {
    datacenters = ["ator-fin"]
    type = "batch"

    reschedule {
        attempts = 0
    }

    task "deploy-registrator-live-task" {
        driver = "docker"

        config {
            network_mode = "host"
            image = "ghcr.io/ator-development/registrator:0.2.1"
            entrypoint = ["npx"]
            command = "hardhat"
            args = ["run", "--network", "sepolia", "scripts/deploy.ts"]
        }

        vault {
            policies = ["registrator-live-sepolia"]
        }

        template {
            data = <<EOH
            {{with secret "kv/registrator/sepolia/live"}}
                REGISTRATOR_DEPLOYER_KEY="{{.Data.data.REGISTRATOR_DEPLOYER_KEY}}"
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
            REGISTRATOR_CONSUL_KEY="registrator/sepolia/live/address"
            ATOR_TOKEN_CONSUL_KEY="ator-token/sepolia/live/address"
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
