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
    git clone git@github.com:novaexperiment/jointfit_novat2k

    # Build container using the default Dockerfile
    # If you are trying to pick up an updated external repository you may need --no-cache
    docker build -t novaexperiment/nova-sl7-novat2k .

    # Upload the resulting image to dockerhub
    docker login docker.io
    docker push docker.io/novaexperiment/nova-sl7-novat2k:latest
    docker logout
