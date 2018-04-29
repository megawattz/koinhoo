# I made some changes to support multiple environments. Basically, each environment is defined by a Dockefile.<environment> or what I called ROLE
# So when you to make, you say make ROLE=name drun, or make ROLE=name dbuild or whatever.
# If you don't define a ROLE, there is a default, so what you are used to, no ROLE, will still work.
PRODUCT=coinpredict
ROLE_DEFAULT=dev
ROLE := $(ROLE_DEFAULT)
IMAGE_NAME = $(PRODUCT)_$(ROLE)
DOCKERFILE = Dockerfile.$(ROLE)
VOLUMES = -v $(CURDIR):/app -v /data/$(PRODUCT)_$(ROLE):/data
HOME = $(shell pwd)

help:
	@echo "Please use 'make <target> ROLE=<ROLE> if you don't specify role, the default will be \"$(ROLE)\" and will use Dockerfile.$(ROLE)"
	@echo "where <target> is one of"
	@echo "Please use 'make <target> ROLE=<role>' where <target> is one of"
	@echo "  dbuild           build the docker image containing a redis cluster"
	@echo "  drebuild         rebuilds the image from scratch without using any cached layers"
	@echo "  drun             run the built docker image"
	@echo "  drestart         restarts the docker image"
	@echo "  dbash            starts bash inside a running container."
	@echo "  dclean           removes the tmp cid file on disk"
	@echo 'equivalent commands may exist for docker compose container but they start with "c" like "make cbash"'
	@echo -n "and <ROLE> is a suffix of a Dockerfile in this directory, one of these: "
	@ls Dockerfile.*
	@echo "Example: make ROLE=dev drun"

build:
	@echo "Building docker image..."
	docker build --rm=true -f ${DOCKERFILE} -t ${IMAGE_NAME} .

rebuild:
	@echo "Rebuilding docker image using: " 
	docker build --rm=true -f ${DOCKERFILE} --no-cache=true -t ${IMAGE_NAME} .

run:
	@echo "Running docker image..."  # you must stop and rm any container of the same name docker run will fail
	docker run --rm $(VOLUMES) $(PORTS) $(HOSTS) -it --name $(IMAGE_NAME) $(IMAGE_NAME) $(CMD)

restart: stop
	-docker rm ${IMAGE_NAME} 2>/dev/null
	docker run --rm $(VOLUMES) $(PORTS) $(HOSTS) -it --name ${IMAGE_NAME} ${IMAGE_NAME} $(CMD)

shell: 
	docker run $(VOLUMES) $(PORTS) $(HOSTS) -i -t ${IMAGE_NAME} /bin/bash

bash:
	docker exec -it ${IMAGE_NAME} /bin/bash

stop:
	-docker stop ${IMAGE_NAME} 2>/dev/null
	-make dclean

clean:
	# Cleanup cidfile on disk
	-rm $(CID_FILE) 2>/dev/null

