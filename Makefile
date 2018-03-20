default: docker

.PHONY: update-deps docker test

update-deps:
	go install golang.org/x/build/cmd/gitlock
	gitlock --update=Dockerfile golang.org/x/playground
	gitlock --update=Dockerfile.function golang.org/x/playground

docker: Dockerfile
	docker build -t playground .
	docker build -t func_playground -f Dockerfile.function .

test: docker
	go test
	docker run --rm playground test
