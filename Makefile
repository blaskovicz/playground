default: build

.PHONY: update-deps docker test build

build:
	go build

update-deps:
	go get golang.org/x/build/cmd/gitlock
	go install golang.org/x/build/cmd/gitlock
	gitlock --update=Dockerfile github.com/blaskovicz/playground-golang

docker: Dockerfile
	docker build -t playground .
	docker build -t func_playground -f Dockerfile.function .

test: docker
	go test
	docker run --rm playground test
