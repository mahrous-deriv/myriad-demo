ROOT_DIR :=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

help:
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

restart: ## restart services
	docker-compose restart

logs:  ## follow logs for services
	docker-compose logs --tail=50 -f

down: ## bring down and stop services
	docker-compose down --remove-orphans

redis-cli: which ?= main
redis-cli: node ?= 0
redis-cli: ## redis-cli for any needed instance. (which=name_of_redis  node=instance)
	docker exec -it support-redis-${which}-${node} redis-cli -c
redis-cluster-rejoin: ## rejoin redis cluster nodes
	docker run --rm -v $(ROOT_DIR):/repo --entrypoint /bin/bash --network myriad-demo_support-redis-main deriv/myriad -c '/repo/bin/redis-cluster-rejoin.pl'
