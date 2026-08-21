# nova-sl7-novat2k

Dockerfile for the packaging the jointfit_novat2k repository and various glue
code into a container providing the NOvA likelihood evaluation for the nova/t2k
joint fit.

# Instructions for building docker image locally

You may also use podman by simply replacing "docker" with "podman" throughout.

    # Clone this repository
    git clone git@github.com:novaexperiment/nova-sl7-novat2k.git
    cd nova-sl7-novat2k

    # Fetch the fitting code which we are packaging, among other things
    git clone -b feature/nudock_2024Ana git@github.com:novaexperiment/jointfit_novat2k 

    # Build container using the default Dockerfile
    # If you are trying to pick up an updated external repository you may need --no-cache
    docker build -t ghcr.io/novaexperiment/nova-sl7-novat2k .

    # Upload the resulting image to dockerhub
    docker login ghcr.io
    docker push ghcr.io/novaexperiment/nova-sl7-novat2k:latest
    docker logout

To create a .sif file without going via dockerhub:

    docker save <image_id> -o img.tar
    singularity build img.sif img.tar

# Quicl local run & test
For a quick run locally:

```bash
# Fetch everything
git clone git@github.com:novaexperiment/nova-sl7-novat2k.git
cd nova-sl7-novat2k
git clone git@github.com:novaexperiment/jointfit_novat2k

# Build container & a writable image
docker build --no-cache -t novat1k_test .
singularity build --sandbox image.sif docker-daemon://novat2k_test:latest
```

The created `image.sif` will be a folder that you can easily edit if needed (swap out the schemas, recompile the software etc).

You can run test by starting the server:

```bash
./run_container.sh
```

And the client:

```bash
./run_client.sh
```

to enter the container environment (can be useful if you want to e.g. rebuild software for tests):

```bash
singularity shell --writable image.sif
```
