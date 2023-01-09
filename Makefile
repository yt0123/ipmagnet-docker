.PHONY: build run stop clean

IMAGE_NAME := ipmagnet
IMAGE_TAG := php8-lighttpd-alpine

CONTAINER_NAME := ipmagnet
CONTAINER_PORT := 8080

TRACKER := http://localhost:8080/ipmagnet/

build:
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) --build-arg TRACKER=$(TRACKER) .

run:
	docker run -d -p $(CONTAINER_PORT):80 --name $(CONTAINER_NAME) $(IMAGE_NAME):$(IMAGE_TAG)

stop:
	docker stop $(CONTAINER_NAME)

clean:
	docker rm $(CONTAINER_NAME)
