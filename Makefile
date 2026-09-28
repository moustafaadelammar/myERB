install:
	npm install

dev:
	npm run dev

build:
	npm run build

test:
	npm test

lint:
	npm run lint

docker-build:
	docker build -t myerb:local .

docker-up:
	docker compose up -d --build

docker-down:
	docker compose down

k8s-validate:
	kubectl apply --dry-run=client -f k8s/

helm-lint:
	helm lint helm/myerb
