build:
	@docker-compose -p jenkins build
run:
	@docker-compose -p jenkins up -d haproxy master proxy nexus
stop:
	@docker-compose -p jenkins down
ps:
	@docker-compose -p jenkins ps
